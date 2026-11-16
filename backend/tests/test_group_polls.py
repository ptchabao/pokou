"""Sondages de groupe chiffrés : le sondage est un message POLL chiffré,
chaque membre y dépose UN vote chiffré, que le serveur ne lit pas."""
import re
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import GroupMessage, GroupPollVote
from app.services.auth import otp_service


engine = create_engine("sqlite:///./test_group_polls.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def _db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _db
    yield TestClient(app)
    if previous is None:
        app.dependency_overrides.pop(get_db, None)
    else:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send_sms:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send_sms.call_args.args[2]).group(1)
    response = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {response['access_token']}"}, response["user"]["id"]


def _family(client):
    """A crée un groupe avec B et C, qui acceptent ; D reste dehors. A a remis
    sa clé d'expéditeur à B, ce qui l'autorise à écrire."""
    headers_a, user_a = _signup(client, "+22894000001")
    headers_b, user_b = _signup(client, "+22894000002")
    headers_c, user_c = _signup(client, "+22894000003")
    headers_d, _ = _signup(client, "+22894000004")
    for phone, name in (("+22894000002", "B"), ("+22894000003", "C")):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers_a)
    group = client.post(
        "/api/v1/groups", json={"name": "Famille", "member_user_ids": [user_b, user_c]}, headers=headers_a
    ).json()
    for headers in (headers_b, headers_c):
        for invitation in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers)
    epoch = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()["crypto_epoch"]
    distribution = {"recipient_id": user_b, "encryption": "v1", "ciphertext": "k", "envelope": {"sid": "s"}}
    assert client.post(
        f"/api/v1/groups/{group['id']}/sender-key-distributions",
        json={"epoch": epoch, "distributions": [distribution]},
        headers=headers_a,
    ).status_code == 200
    return group["id"], epoch, (headers_a, user_a), (headers_b, user_b), (headers_c, user_c), headers_d


def _send_poll(client, group_id, epoch, headers):
    return client.post(
        f"/api/v1/groups/{group_id}/messages",
        json={
            "message_type": "POLL",
            "encryption": "sender-key-v1",
            "ciphertext": "question-et-reponses-chiffrees",
            "crypto_epoch": epoch,
        },
        headers=headers,
    )


def _vote(client, group_id, message_id, headers, ciphertext):
    return client.put(
        f"/api/v1/groups/{group_id}/messages/{message_id}/poll-vote",
        json={"encryption": "poll-key-v1", "ciphertext": ciphertext},
        headers=headers,
    )


def test_un_membre_cree_un_sondage_chiffre_diffuse_comme_un_message(client):
    group_id, epoch, (headers_a, user_a), (_, user_b), (_, user_c), _ = _family(client)
    sent_to = []

    async def fake_send(user_id, event):
        sent_to.append((user_id, event["type"]))
        return True

    with patch("app.api.v1.messaging.groups.manager.send_to_user", new=AsyncMock(side_effect=fake_send)), patch(
        "app.api.v1.messaging.groups.send_push"
    ) as push:
        created = _send_poll(client, group_id, epoch, headers_a)

    assert created.status_code == 200, created.text
    body = created.json()
    assert body["message_type"] == "POLL"
    assert body["content"] is None
    assert (user_b, "group:message:new") in sent_to
    assert (user_c, "group:message:new") in sent_to
    # Même canal de notification que les autres messages, sans le contenu.
    assert {call.args[1] for call in push.call_args_list} == {user_b, user_c}
    with TestingSessionLocal() as db:
        row = db.query(GroupMessage).filter_by(id=body["id"]).one()
        assert row.poll_id is None and row.content is None


def test_chaque_membre_vote_et_les_resultats_se_lisent(client):
    group_id, epoch, (headers_a, user_a), (headers_b, user_b), (headers_c, user_c), _ = _family(client)
    message_id = _send_poll(client, group_id, epoch, headers_a).json()["id"]

    events = []

    async def fake_send(user_id, event):
        events.append((user_id, event))
        return True

    with patch("app.api.v1.messaging.groups.manager.send_to_user", new=AsyncMock(side_effect=fake_send)):
        voted = _vote(client, group_id, message_id, headers_b, "choix-de-b")
    assert voted.status_code == 200, voted.text
    assert voted.json()["vote"]["voter_id"] == user_b
    # Les autres membres l'apprennent en direct, avec le chiffré à ouvrir.
    received = {user_id for user_id, event in events if event["type"] == "group:poll:vote"}
    assert received == {user_a, user_c}
    assert events[0][1]["vote"]["ciphertext"] == "choix-de-b"

    assert _vote(client, group_id, message_id, headers_c, "choix-de-c").status_code == 200
    assert _vote(client, group_id, message_id, headers_a, "choix-de-a").status_code == 200

    results = client.get(f"/api/v1/groups/{group_id}/messages/{message_id}/poll-votes", headers=headers_c)
    assert results.status_code == 200
    items = results.json()["items"]
    assert [item["voter_id"] for item in items] == [user_b, user_c, user_a]
    assert {item["ciphertext"] for item in items} == {"choix-de-a", "choix-de-b", "choix-de-c"}


def test_revoter_remplace_le_vote_une_voix_par_membre(client):
    group_id, epoch, (headers_a, _), (headers_b, user_b), _, _ = _family(client)
    message_id = _send_poll(client, group_id, epoch, headers_a).json()["id"]

    assert _vote(client, group_id, message_id, headers_b, "premier").status_code == 200
    assert _vote(client, group_id, message_id, headers_b, "second").status_code == 200

    items = client.get(
        f"/api/v1/groups/{group_id}/messages/{message_id}/poll-votes", headers=headers_a
    ).json()["items"]
    assert len(items) == 1
    assert items[0] == {**items[0], "voter_id": user_b, "ciphertext": "second"}
    with TestingSessionLocal() as db:
        assert db.query(GroupPollVote).filter_by(message_id=message_id).count() == 1

    # Retirer son vote, deux fois de suite : pas d'erreur, plus de ligne.
    url = f"/api/v1/groups/{group_id}/messages/{message_id}/poll-vote"
    assert client.delete(url, headers=headers_b).status_code == 200
    assert client.delete(url, headers=headers_b).status_code == 200
    assert client.get(
        f"/api/v1/groups/{group_id}/messages/{message_id}/poll-votes", headers=headers_a
    ).json()["items"] == []


def test_un_non_membre_ne_vote_ni_ne_lit_ni_ne_cree(client):
    group_id, epoch, (headers_a, _), _, _, headers_d = _family(client)
    message_id = _send_poll(client, group_id, epoch, headers_a).json()["id"]

    assert _vote(client, group_id, message_id, headers_d, "intrus").status_code == 403
    assert client.get(
        f"/api/v1/groups/{group_id}/messages/{message_id}/poll-votes", headers=headers_d
    ).status_code == 403
    assert client.delete(
        f"/api/v1/groups/{group_id}/messages/{message_id}/poll-vote", headers=headers_d
    ).status_code == 403
    assert _send_poll(client, group_id, epoch, headers_d).status_code == 403
    with TestingSessionLocal() as db:
        assert db.query(GroupPollVote).count() == 0


def test_un_vote_exige_un_sondage_et_un_chiffre_connu(client):
    group_id, epoch, (headers_a, _), (headers_b, _), _, _ = _family(client)
    text = client.post(
        f"/api/v1/groups/{group_id}/messages",
        json={"encryption": "sender-key-v1", "ciphertext": "texte", "crypto_epoch": epoch},
        headers=headers_a,
    ).json()["id"]
    assert _vote(client, group_id, text, headers_b, "x").status_code == 400

    poll = _send_poll(client, group_id, epoch, headers_a).json()["id"]
    clear = client.put(
        f"/api/v1/groups/{group_id}/messages/{poll}/poll-vote",
        json={"encryption": "none", "ciphertext": "Oui"},
        headers=headers_b,
    )
    assert clear.status_code == 422
    assert _vote(client, group_id, "inconnu", headers_b, "x").status_code == 404


def test_le_sondage_en_clair_reste_refuse_en_groupe(client):
    group_id, _, (headers_a, _), _, _, _ = _family(client)
    response = client.post(
        "/api/v1/polls",
        json={"kind": "group", "target_id": group_id, "question": "En clair ?", "options": ["Oui", "Non"]},
        headers=headers_a,
    )
    assert response.status_code == 409
