"""Pokou — sondages, position partagée et carte de visite (routes/polls.py).

Ce qui est vérifié ici tient à ce qui distingue ces contenus d'un message
texte : la façon dont un vote remplace ou cumule les précédents, le fait que
connaître l'identifiant d'un sondage ne donne aucun droit dessus, les bornes
des coordonnées, et ce qu'il advient d'une position en direct terminée.
"""
import re
import time
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_polls.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _add_contact(client, headers, phone):
    response = client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers
    )
    assert response.status_code in (200, 409), response.text


def _pair(client, phone_a, phone_b):
    """Deux comptes qui se sont mutuellement ajoutés : le carnet d'adresses
    est asymétrique dans Pokou, et seul le sens A→B est exigé à l'envoi — on
    inscrit les deux sens pour que chacun puisse initier."""
    headers_a, user_a = _signup(client, phone_a)
    headers_b, user_b = _signup(client, phone_b)
    _add_contact(client, headers_a, phone_b)
    _add_contact(client, headers_b, phone_a)
    return (headers_a, user_a), (headers_b, user_b)


def _accepter_invitations(client, user_ids):
    """Depuis que Pokou INVITE au lieu d'ajouter (migration 20260928), créer un
    groupe avec des membres ne les y met plus : ils reçoivent une invitation.
    Ces tests portent sur le comportement du groupe une fois constitué, pas sur
    le flux d'invitation (test_group_invitations.py) : on rend donc aux membres
    leur place, en acceptant pour eux."""
    from app.core.security import create_access_token

    for user_id in user_ids:
        headers = {"Authorization": f"Bearer {create_access_token({'user_id': user_id})}"}
        for invitation in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers)


def _group_with(client, headers, name, member_ids):
    response = client.post(
        "/api/v1/groups", json={"name": name, "member_user_ids": list(member_ids)}, headers=headers
    )
    assert response.status_code == 200, response.text
    _accepter_invitations(client, list(member_ids))
    return response.json()


def _create_poll(client, headers, *, kind, target_id, question="On mange où ?", options=None, multiple=False):
    return client.post(
        "/api/v1/polls",
        json={
            "kind": kind,
            "target_id": target_id,
            "question": question,
            "options": options if options is not None else ["Chez Fatou", "À la maison"],
            "allows_multiple": multiple,
        },
        headers=headers,
    )


def _option_ids(poll):
    return [option["id"] for option in poll["options"]]


# ─── Sondages ─────────────────────────────────────────────────────────────────

def test_a_single_choice_vote_replaces_the_previous_one(client):
    """Le cœur du choix unique : l'unicité en base porte sur (option, votant),
    donc rien n'empêcherait d'empiler deux réponses — c'est la route qui doit
    remplacer, comme WhatsApp."""
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000101", "+228897000102")
    created = _create_poll(client, headers_a, kind="contact", target_id=user_b)
    assert created.status_code == 200, created.text
    poll = created.json()["poll"]
    first, second = _option_ids(poll)

    client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_b)
    changed = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [second]}, headers=headers_b
    )

    assert changed.status_code == 200, changed.text
    counts = {option["id"]: option["vote_count"] for option in changed.json()["options"]}
    assert counts == {first: 0, second: 1}
    assert changed.json()["total_voters"] == 1
    mine = {option["id"]: option["mine"] for option in changed.json()["options"]}
    assert mine == {first: False, second: True}


def test_a_single_choice_poll_refuses_two_options_at_once(client):
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000103", "+228897000104")
    poll = _create_poll(client, headers_a, kind="contact", target_id=user_b).json()["poll"]

    refused = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": _option_ids(poll)}, headers=headers_b
    )
    assert refused.status_code == 400


def test_a_multiple_choice_poll_accepts_two_options(client):
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000105", "+228897000106")
    poll = _create_poll(
        client,
        headers_a,
        kind="contact",
        target_id=user_b,
        options=["Riz", "Pâte", "Fufu"],
        multiple=True,
    ).json()["poll"]
    riz, pate, _fufu = _option_ids(poll)

    voted = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [riz, pate]}, headers=headers_b
    )

    assert voted.status_code == 200, voted.text
    counts = {option["text"]: option["vote_count"] for option in voted.json()["options"]}
    assert counts == {"Riz": 1, "Pâte": 1, "Fufu": 0}
    # Deux voix mais une seule personne : c'est ce nombre qui sert de
    # dénominateur aux pourcentages affichés.
    assert voted.json()["total_voters"] == 1


def test_the_option_list_replaces_the_whole_vote(client):
    """Le deuxième appel n'ajoute pas, il redéfinit — sinon un client qui
    rejoue sa requête après une coupure réseau voterait deux fois."""
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000107", "+228897000108")
    poll = _create_poll(
        client, headers_a, kind="contact", target_id=user_b, options=["A", "B", "C"], multiple=True
    ).json()["poll"]
    a, b, c = _option_ids(poll)

    client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [a, b]}, headers=headers_b)
    final = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [c]}, headers=headers_b
    )

    counts = {option["id"]: option["vote_count"] for option in final.json()["options"]}
    assert counts == {a: 0, b: 0, c: 1}


def test_knowing_a_poll_id_is_not_the_right_to_vote_in_it(client):
    """Le point qui compte : l'identifiant d'un sondage circule (capture
    d'écran, journal client), il ne doit jamais suffire — c'est l'accès à la
    CONVERSATION qui porte le sondage qui autorise."""
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000109", "+228897000110")
    headers_c, _ = _signup(client, "+228897000111")
    poll = _create_poll(client, headers_a, kind="contact", target_id=user_b).json()["poll"]

    refused = client.post(
        f"/api/v1/polls/{poll['id']}/vote",
        json={"option_ids": [_option_ids(poll)[0]]},
        headers=headers_c,
    )
    # 404 et non 403 : on ne confirme même pas que ce sondage existe.
    assert refused.status_code == 404
    assert client.get(f"/api/v1/polls/{poll['id']}", headers=headers_c).status_code == 404
    # Et le sondage reste intact pour ceux qui y ont droit.
    assert client.get(f"/api/v1/polls/{poll['id']}", headers=headers_b).status_code == 200


def test_a_poll_needs_at_least_two_options(client):
    """Une seule option n'est pas un sondage, et les champs laissés vides par
    le formulaire ne comptent pas comme des options."""
    (headers_a, _), (_, user_b) = _pair(client, "+228897000112", "+228897000113")

    assert _create_poll(
        client, headers_a, kind="contact", target_id=user_b, options=["Seulement moi"]
    ).status_code == 400
    assert _create_poll(
        client, headers_a, kind="contact", target_id=user_b, options=["Oui", "   "]
    ).status_code == 400
    assert _create_poll(
        client, headers_a, kind="contact", target_id=user_b, options=[f"#{i}" for i in range(13)]
    ).status_code == 400


def test_a_poll_to_someone_outside_the_address_book_is_refused(client):
    headers_a, _ = _signup(client, "+228897000114")
    _, user_b = _signup(client, "+228897000115")

    assert _create_poll(client, headers_a, kind="contact", target_id=user_b).status_code == 403


def test_a_group_poll_is_open_to_every_member(client):
    (headers_a, user_a), (headers_b, user_b) = _pair(client, "+228897000116", "+228897000117")
    group = _group_with(client, headers_a, "Tontine", [user_b])

    created = _create_poll(client, headers_a, kind="group", target_id=group["id"])
    assert created.status_code == 200, created.text
    assert created.json()["group_id"] == group["id"]
    poll = created.json()["poll"]
    first = _option_ids(poll)[0]

    client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_a)
    voted = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_b
    )

    assert voted.status_code == 200, voted.text
    assert voted.json()["options"][0]["vote_count"] == 2
    assert voted.json()["total_voters"] == 2
    # Les votants sont publics, comme chez WhatsApp : un sondage de groupe sert
    # d'abord à savoir QUI vient.
    assert voted.json()["options"][0]["voters"] == [user_a, user_b]

    seen = client.get(f"/api/v1/polls/{poll['id']}", headers=headers_b).json()
    # `reveals_voters` vaut vrai ici et faux sur une chaîne : c'est ce qui
    # permet à un client de dire « liste masquée » au lieu de laisser croire
    # à zéro votant (voir polls.py::_serialize_poll).
    assert seen["reveals_voters"] is True
    assert set(seen) == {
        "id", "question", "allows_multiple", "reveals_voters", "options", "total_voters",
    }
    assert set(seen["options"][0]) == {
        "id", "text", "position", "vote_count", "voters", "mine",
    }


def test_sending_to_a_group_you_are_not_in_is_refused(client):
    """Vaut pour les trois contenus : l'autorisation est mutualisée, une
    régression sur l'un se verrait sur les autres."""
    headers_a, _ = _signup(client, "+228897000118")
    headers_b, _ = _signup(client, "+228897000119")
    group = _group_with(client, headers_a, "Famille", [])

    assert _create_poll(client, headers_b, kind="group", target_id=group["id"]).status_code == 403
    assert client.post(
        "/api/v1/polls/location",
        json={"kind": "group", "target_id": group["id"], "latitude": 6.13, "longitude": 1.22},
        headers=headers_b,
    ).status_code == 403
    assert client.post(
        "/api/v1/polls/contact-card",
        json={
            "kind": "group",
            "target_id": group["id"],
            "contacts": [{"display_name": "Fatou", "phone": "+22890123456"}],
        },
        headers=headers_b,
    ).status_code == 403


def test_a_poll_lands_in_the_conversation_history(client):
    """Le sondage n'est pas une entité à côté de la conversation : il arrive
    comme un message, à sa place dans le fil."""
    (headers_a, user_a), (headers_b, user_b) = _pair(client, "+228897000120", "+228897000121")
    _create_poll(
        client, headers_a, kind="contact", target_id=user_b, question="On part à quelle heure ?"
    )

    history = client.get(f"/api/v1/messages/{user_a}", headers=headers_b)

    assert history.status_code == 200, history.text
    bubble = history.json()["items"][-1]
    assert bubble["message_type"] == "POLL"
    # La question est aussi recopiée dans `content` : c'est ce qui rend le
    # sondage lisible dans un historique qui ne sait pas encore lire `payload`,
    # et retrouvable par la recherche de conversation.
    assert bubble["content"] == "On part à quelle heure ?"


# ─── Position partagée ────────────────────────────────────────────────────────

def _share_location(client, headers, target_id, **extra):
    return client.post(
        "/api/v1/polls/location",
        json={"kind": "contact", "target_id": target_id, "latitude": 6.1319, "longitude": 1.2228, **extra},
        headers=headers,
    )


def test_a_shared_position_carries_its_coordinates(client):
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000122", "+228897000123")

    sent = _share_location(client, headers_a, user_b, label="Grand marché")

    assert sent.status_code == 200, sent.text
    assert sent.json()["message_type"] == "LOCATION"
    payload = sent.json()["payload"]
    assert payload["latitude"] == 6.1319
    assert payload["longitude"] == 1.2228
    assert payload["label"] == "Grand marché"
    assert payload["live_until"] is None


def test_out_of_range_coordinates_are_refused(client):
    """Une latitude de 91 vient d'un capteur ou d'une conversion cassée ;
    stockée, elle ferait échouer l'affichage de la carte chez tous les
    destinataires sans moyen de corriger le message."""
    (headers_a, _), (_, user_b) = _pair(client, "+228897000124", "+228897000125")

    assert client.post(
        "/api/v1/polls/location",
        json={"kind": "contact", "target_id": user_b, "latitude": 91.0, "longitude": 1.22},
        headers=headers_a,
    ).status_code == 400
    assert client.post(
        "/api/v1/polls/location",
        json={"kind": "contact", "target_id": user_b, "latitude": 6.13, "longitude": -181.0},
        headers=headers_a,
    ).status_code == 400


def test_a_live_position_can_be_moved_by_its_author(client):
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000126", "+228897000127")
    sent = _share_location(client, headers_a, user_b, live_until=3600)

    moved = client.put(
        f"/api/v1/polls/location/{sent.json()['id']}",
        json={"latitude": 6.2, "longitude": 1.3},
        headers=headers_a,
    )

    assert moved.status_code == 200, moved.text
    assert moved.json()["payload"]["latitude"] == 6.2
    assert moved.json()["payload"]["updated_at"]


def test_only_the_author_can_move_a_live_position(client):
    """403 et non 404 : le destinataire VOIT ce message, le lui cacher
    mentirait sur un état qu'il connaît."""
    (headers_a, _), (headers_b, user_b) = _pair(client, "+228897000128", "+228897000129")
    sent = _share_location(client, headers_a, user_b, live_until=3600)

    refused = client.put(
        f"/api/v1/polls/location/{sent.json()['id']}",
        json={"latitude": 0.0, "longitude": 0.0},
        headers=headers_b,
    )
    assert refused.status_code == 403


def test_a_position_that_was_never_live_cannot_be_moved(client):
    (headers_a, _), (_, user_b) = _pair(client, "+228897000130", "+228897000131")
    sent = _share_location(client, headers_a, user_b)

    refused = client.put(
        f"/api/v1/polls/location/{sent.json()['id']}",
        json={"latitude": 6.2, "longitude": 1.3},
        headers=headers_a,
    )
    assert refused.status_code == 409


def test_an_expired_live_position_stops_moving_but_stays_readable(client):
    """Deux exigences en une, parce qu'elles sont les deux moitiés de la même
    décision : le partage s'arrête, le message reste. Une dernière position
    connue est une information utile — l'effacer ferait disparaître une bulle
    de la conversation sous les yeux du lecteur."""
    (headers_a, user_a), (headers_b, user_b) = _pair(client, "+228897000132", "+228897000133")
    sent = _share_location(client, headers_a, user_b, label="En route", live_until=1)
    message_id = sent.json()["id"]

    time.sleep(1.2)

    refused = client.put(
        f"/api/v1/polls/location/{message_id}",
        json={"latitude": 6.2, "longitude": 1.3},
        headers=headers_a,
    )
    assert refused.status_code == 409

    still_there = client.get(f"/api/v1/polls/location/{message_id}", headers=headers_b)
    assert still_there.status_code == 200
    assert still_there.json()["live_expired"] is True
    assert still_there.json()["payload"]["latitude"] == 6.1319

    history = client.get(f"/api/v1/messages/{user_a}", headers=headers_b)
    assert [item["message_type"] for item in history.json()["items"]] == ["LOCATION"]


def test_a_live_position_cannot_be_shared_endlessly(client):
    (headers_a, _), (_, user_b) = _pair(client, "+228897000134", "+228897000135")

    assert _share_location(client, headers_a, user_b, live_until=90000).status_code == 400
    assert _share_location(client, headers_a, user_b, live_until=0).status_code == 400
    assert _share_location(client, headers_a, user_b, live_until="pas-une-date").status_code == 400


# ─── Carte de visite ──────────────────────────────────────────────────────────

def test_shared_numbers_are_normalized(client):
    """Le destinataire doit pouvoir appeler d'un geste : « 90 12 34 56 » ne
    veut rien dire hors du pays où il a été saisi."""
    (headers_a, _), (_, user_b) = _pair(client, "+228897000136", "+228897000137")

    sent = client.post(
        "/api/v1/polls/contact-card",
        json={
            "kind": "contact",
            "target_id": user_b,
            "contacts": [
                {"display_name": "Fatou", "phone": "90 12 34 56"},
                {"display_name": "Kodjo", "phone": "00228 91 22 33 44"},
            ],
        },
        headers=headers_a,
    )

    assert sent.status_code == 200, sent.text
    assert sent.json()["message_type"] == "CONTACT"
    assert [card["phone"] for card in sent.json()["payload"]["contacts"]] == [
        "+22890123456",
        "+22891223344",
    ]


def test_an_unusable_number_is_refused_rather_than_stored(client):
    (headers_a, _), (_, user_b) = _pair(client, "+228897000138", "+228897000139")

    response = client.post(
        "/api/v1/polls/contact-card",
        json={
            "kind": "contact",
            "target_id": user_b,
            "contacts": [{"display_name": "Fatou", "phone": "12"}],
        },
        headers=headers_a,
    )
    assert response.status_code == 400

    empty = client.post(
        "/api/v1/polls/contact-card",
        json={"kind": "contact", "target_id": user_b, "contacts": []},
        headers=headers_a,
    )
    assert empty.status_code == 400


def test_rich_content_requires_authentication(client):
    assert client.post("/api/v1/polls", json={}).status_code in (401, 403)
    assert client.post("/api/v1/polls/location", json={}).status_code in (401, 403)
    assert client.post("/api/v1/polls/contact-card", json={}).status_code in (401, 403)
