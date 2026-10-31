"""Pokou — chaînes (api/app/routes/channels.py), façon chaînes WhatsApp.

Une chaîne est une diffusion à SENS UNIQUE et PUBLIQUE : n'importe qui la
trouve et la lit, seuls le créateur et ses admins publient. Les tests portent
donc surtout sur cette asymétrie — c'est elle qui distingue une chaîne d'un
groupe, et c'est elle qu'un bug d'autorisation ferait tomber.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import ChannelPost, User
from app.services.auth import otp_service
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_channels.db"

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


@pytest.fixture()
def admin_headers(client):
    """Un compte d'équipe, connecté par mot de passe.

    Les chaînes s'utilisent avec un compte téléphone (OTP) ; l'examen des
    dossiers, lui, passe par un compte d'administration — ce sont deux
    portes distinctes, et c'est voulu.
    """
    from app.models import UserRole

    email = "equipe@pok.app"
    db = TestingSessionLocal()
    try:
        if db.query(User).filter(User.email == email).first() is None:
            db.add(
                User(
                    email=email,
                    full_name="Équipe Pokou",
                    role=UserRole.SUPER_ADMIN,
                )
            )
            db.commit()
    finally:
        db.close()
    client.cookies.clear()
    return bearer_for_email(TestingSessionLocal, email)


def _create_channel(client, headers, name="Prix du ciment", description="Cours quotidiens"):
    return client.post(
        "/api/v1/channels", json={"name": name, "description": description}, headers=headers
    )


def _upload(client, headers, filename="photo.jpg"):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": (filename, b"des-octets", "image/jpeg")},
        headers=headers,
    ).json()["id"]


def _publish(client, headers, channel_id, **body):
    payload = {"text_content": "Le sac est à 4500 FCFA"}
    payload.update(body)
    return client.post(f"/api/v1/channels/{channel_id}/posts", json=payload, headers=headers)


# ─── Publier : réservé au créateur et aux admins ──────────────────────────────

def test_the_creator_can_publish_and_is_admin_by_nature(client):
    headers, user_id = _signup(client, "+22899100001")
    channel = _create_channel(client, headers).json()
    assert channel["is_admin"] is True

    posted = _publish(client, headers, channel["id"])
    assert posted.status_code == 200, posted.text
    assert posted.json()["text_content"] == "Le sac est à 4500 FCFA"
    assert posted.json()["author_id"] == user_id


def test_a_mere_follower_cannot_publish(client):
    """C'est TOUTE la différence avec un groupe : la parole est à sens unique."""
    headers_owner, _ = _signup(client, "+22899100002")
    headers_follower, _ = _signup(client, "+22899100003")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_follower)

    refused = _publish(client, headers_follower, channel_id)
    assert refused.status_code == 403


def test_a_promoted_admin_can_publish(client):
    headers_owner, _ = _signup(client, "+22899100004")
    headers_helper, helper_id = _signup(client, "+22899100005")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_helper)

    promoted = client.put(
        f"/api/v1/channels/{channel_id}/members/{helper_id}/role",
        json={"role": "ADMIN"},
        headers=headers_owner,
    )
    assert promoted.status_code == 200, promoted.text
    assert _publish(client, headers_helper, channel_id).status_code == 200

    # Rétrogradé, il reperd la parole.
    client.put(
        f"/api/v1/channels/{channel_id}/members/{helper_id}/role",
        json={"role": "FOLLOWER"},
        headers=headers_owner,
    )
    assert _publish(client, headers_helper, channel_id).status_code == 403


def test_only_the_creator_manages_admins(client):
    """Un admin qui pourrait nommer d'autres admins diluerait la propriété de
    la chaîne sans l'accord de son créateur."""
    headers_owner, _ = _signup(client, "+22899100006")
    headers_admin, admin_id = _signup(client, "+22899100007")
    headers_third, third_id = _signup(client, "+22899100008")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_admin)
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_third)
    client.put(
        f"/api/v1/channels/{channel_id}/members/{admin_id}/role",
        json={"role": "ADMIN"},
        headers=headers_owner,
    )

    refused = client.put(
        f"/api/v1/channels/{channel_id}/members/{third_id}/role",
        json={"role": "ADMIN"},
        headers=headers_admin,
    )
    assert refused.status_code == 403


def test_a_post_needs_a_text_or_an_attachment(client):
    headers, _ = _signup(client, "+22899100009")
    channel_id = _create_channel(client, headers).json()["id"]
    assert _publish(client, headers, channel_id, text_content="   ").status_code == 400


def test_cannot_publish_someone_elses_upload(client):
    headers_owner, _ = _signup(client, "+22899100010")
    headers_other, _ = _signup(client, "+22899100011")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    media_of_other = _upload(client, headers_other, "prive.jpg")

    refused = _publish(client, headers_owner, channel_id, text_content=None, media_asset_id=media_of_other)
    assert refused.status_code == 404


# ─── Lire : public, sans abonnement ───────────────────────────────────────────

def test_a_channel_is_readable_without_following_it(client):
    """On juge une chaîne sur son contenu AVANT de la suivre — sinon
    personne ne s'abonnerait jamais."""
    headers_owner, _ = _signup(client, "+22899100020")
    headers_stranger, _ = _signup(client, "+22899100021")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    _publish(client, headers_owner, channel_id, text_content="Annonce publique")

    feed = client.get(f"/api/v1/channels/{channel_id}/posts", headers=headers_stranger)
    assert feed.status_code == 200
    assert [item["text_content"] for item in feed.json()["items"]] == ["Annonce publique"]


def test_the_feed_is_newest_first(client):
    headers, _ = _signup(client, "+22899100022")
    channel_id = _create_channel(client, headers).json()["id"]
    _publish(client, headers, channel_id, text_content="ancien")
    _publish(client, headers, channel_id, text_content="récent")

    items = client.get(f"/api/v1/channels/{channel_id}/posts", headers=headers).json()["items"]
    assert [item["text_content"] for item in items] == ["récent", "ancien"]


# ─── Abonnement ───────────────────────────────────────────────────────────────

def test_following_is_idempotent_and_counted(client):
    headers_owner, _ = _signup(client, "+22899100030")
    headers_follower, _ = _signup(client, "+22899100031")
    channel_id = _create_channel(client, headers_owner).json()["id"]

    for _ in range(3):
        followed = client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_follower)
    assert followed.json()["is_following"] is True
    # L'abonné compté une seule fois, le créateur n'étant pas un abonné.
    assert followed.json()["follower_count"] == 1

    unfollowed = client.delete(f"/api/v1/channels/{channel_id}/follow", headers=headers_follower)
    assert unfollowed.json()["is_following"] is False
    assert unfollowed.json()["follower_count"] == 0


def test_the_creator_stays_admin_even_after_unfollowing(client):
    """Quitter sa propre liste de lecture ne doit pas faire perdre sa chaîne."""
    headers, _ = _signup(client, "+22899100032")
    channel_id = _create_channel(client, headers).json()["id"]

    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers)
    after = client.delete(f"/api/v1/channels/{channel_id}/follow", headers=headers).json()
    assert after["is_admin"] is True
    assert _publish(client, headers, channel_id).status_code == 200


# ─── Recherche ────────────────────────────────────────────────────────────────

def test_search_finds_channels_by_name_and_description(client):
    headers, _ = _signup(client, "+22899100040")
    _create_channel(client, headers, name="Prix du CIMENT", description="Cours")
    _create_channel(client, headers, name="Transport", description="Camions et ciment")
    _create_channel(client, headers, name="Météo", description="Pluies")

    found = client.get("/api/v1/channels/search", params={"q": "ciment"}, headers=headers).json()["items"]
    assert {item["name"] for item in found} == {"Prix du CIMENT", "Transport"}


def test_search_treats_wildcards_as_plain_text(client):
    headers, _ = _signup(client, "+22899100041")
    _create_channel(client, headers, name="Chaîne A", description="rien")
    _create_channel(client, headers, name="Promo 100%", description="soldes")

    found = client.get("/api/v1/channels/search", params={"q": "100%"}, headers=headers).json()["items"]
    assert [item["name"] for item in found] == ["Promo 100%"]
    assert client.get("/api/v1/channels/search", params={"q": "_"}, headers=headers).json()["items"] == []


def test_search_finds_a_channel_i_do_not_follow(client):
    headers_owner, _ = _signup(client, "+22899100042")
    headers_stranger, _ = _signup(client, "+22899100043")
    _create_channel(client, headers_owner, name="Découvrable")

    found = client.get(
        "/api/v1/channels/search", params={"q": "Découvrable"}, headers=headers_stranger
    ).json()["items"]
    assert len(found) == 1
    assert found[0]["is_following"] is False
    assert found[0]["is_admin"] is False


# ─── Réactions et vues ────────────────────────────────────────────────────────

def test_a_reaction_replaces_the_previous_one(client):
    headers_owner, _ = _signup(client, "+22899100050")
    headers_reader, reader_id = _signup(client, "+22899100051")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    post_id = _publish(client, headers_owner, channel_id).json()["id"]

    client.put(
        f"/api/v1/channels/{channel_id}/posts/{post_id}/reaction",
        json={"emoji": "👍"},
        headers=headers_reader,
    )
    changed = client.put(
        f"/api/v1/channels/{channel_id}/posts/{post_id}/reaction",
        json={"emoji": "🔥"},
        headers=headers_reader,
    ).json()

    # Remplacée, pas empilée.
    assert len(changed["reactions"]) == 1
    assert changed["reactions"][0]["emoji"] == "🔥"
    assert changed["reactions"][0]["count"] == 1
    assert changed["reactions"][0]["mine"] is True


def test_a_reaction_can_be_removed(client):
    headers_owner, _ = _signup(client, "+22899100052")
    headers_reader, _ = _signup(client, "+22899100053")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    post_id = _publish(client, headers_owner, channel_id).json()["id"]
    client.put(
        f"/api/v1/channels/{channel_id}/posts/{post_id}/reaction",
        json={"emoji": "👍"},
        headers=headers_reader,
    )

    after = client.delete(
        f"/api/v1/channels/{channel_id}/posts/{post_id}/reaction", headers=headers_reader
    ).json()
    assert after["reactions"] == []


def test_views_are_counted_once_per_person(client):
    headers_owner, _ = _signup(client, "+22899100054")
    headers_a, _ = _signup(client, "+22899100055")
    headers_b, _ = _signup(client, "+22899100056")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    post_id = _publish(client, headers_owner, channel_id).json()["id"]

    for _ in range(3):
        client.post(f"/api/v1/channels/{channel_id}/posts/{post_id}/view", headers=headers_a)
    last = client.post(f"/api/v1/channels/{channel_id}/posts/{post_id}/view", headers=headers_b)

    assert last.json()["view_count"] == 2


# ─── Modification et suppression ──────────────────────────────────────────────

def test_a_post_can_be_edited_within_the_window_and_is_marked_edited(client):
    headers, _ = _signup(client, "+22899100060")
    channel_id = _create_channel(client, headers).json()["id"]
    post_id = _publish(client, headers, channel_id).json()["id"]

    edited = client.patch(
        f"/api/v1/channels/{channel_id}/posts/{post_id}",
        json={"text_content": "Correction : 4700 FCFA"},
        headers=headers,
    ).json()
    assert edited["text_content"] == "Correction : 4700 FCFA"
    assert edited["edited_at"] is not None


def test_editing_after_the_window_is_refused(client):
    headers, _ = _signup(client, "+22899100061")
    channel_id = _create_channel(client, headers).json()["id"]
    post_id = _publish(client, headers, channel_id).json()["id"]

    # On vieillit la publication en base plutôt que d'attendre. Le décalage
    # se dérive de la constante : l'écrire à la main fait casser ce test le
    # jour où la fenêtre change, pour une raison sans rapport avec ce qu'il
    # vérifie.
    from datetime import datetime, timedelta

    from app.utils.editing import MESSAGE_EDIT_WINDOW

    db = TestingSessionLocal()
    try:
        db.query(ChannelPost).filter(ChannelPost.id == post_id).update(
            {
                ChannelPost.created_at: datetime.utcnow()
                - (MESSAGE_EDIT_WINDOW + timedelta(minutes=1))
            }
        )
        db.commit()
    finally:
        db.close()

    refused = client.patch(
        f"/api/v1/channels/{channel_id}/posts/{post_id}",
        json={"text_content": "trop tard"},
        headers=headers,
    )
    assert refused.status_code == 409


def test_a_follower_cannot_delete_a_post(client):
    headers_owner, _ = _signup(client, "+22899100062")
    headers_follower, _ = _signup(client, "+22899100063")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    post_id = _publish(client, headers_owner, channel_id).json()["id"]
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_follower)

    assert client.delete(
        f"/api/v1/channels/{channel_id}/posts/{post_id}", headers=headers_follower
    ).status_code == 403
    assert client.delete(
        f"/api/v1/channels/{channel_id}/posts/{post_id}", headers=headers_owner
    ).json() == {"deleted": True}
    assert client.get(f"/api/v1/channels/{channel_id}/posts", headers=headers_owner).json()["items"] == []


def test_admins_can_change_the_channel_image_and_description(client):
    headers, _ = _signup(client, "+22899100064")
    channel_id = _create_channel(client, headers).json()["id"]
    media_id = _upload(client, headers, "logo.jpg")

    updated = client.patch(
        f"/api/v1/channels/{channel_id}",
        json={"description": "Nouvelle description", "avatar_media_id": media_id},
        headers=headers,
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["description"] == "Nouvelle description"
    assert updated.json()["avatar"]["id"] == media_id


# ─── Sondages ─────────────────────────────────────────────────────────────────
#
# Un sondage de chaîne réutilise la table `polls` et la route de vote des
# sondages de conversation (voir channels.py et polls.py). Ce qui CHANGE d'une
# conversation, et que ces tests verrouillent : seuls les admins créent le
# sondage, tout lecteur peut voter (comme pour une réaction), et la liste des
# votants n'est JAMAIS publiée — une chaîne est publique.

def _publish_poll(client, headers, channel_id, **poll):
    body = {"question": "Le ciment va-t-il monter ?", "options": ["Oui", "Non"]}
    body.update(poll)
    return client.post(
        f"/api/v1/channels/{channel_id}/posts", json={"poll": body}, headers=headers
    )


def test_an_admin_publishes_a_poll_and_it_comes_back_with_the_post(client):
    headers, _ = _signup(client, "+22899100070")
    channel_id = _create_channel(client, headers).json()["id"]

    created = _publish_poll(client, headers, channel_id)
    assert created.status_code == 200, created.text
    poll = created.json()["poll"]
    assert poll["question"] == "Le ciment va-t-il monter ?"
    # Ordre voulu par l'auteur, pas celui de la base.
    assert [option["text"] for option in poll["options"]] == ["Oui", "Non"]
    assert poll["total_voters"] == 0

    listed = client.get(f"/api/v1/channels/{channel_id}/posts", headers=headers).json()["items"]
    assert listed[0]["poll"]["id"] == poll["id"]


def test_a_follower_cannot_publish_a_poll(client):
    headers_owner, _ = _signup(client, "+22899100071")
    headers_follower, _ = _signup(client, "+22899100072")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    client.post(f"/api/v1/channels/{channel_id}/follow", headers=headers_follower)

    assert _publish_poll(client, headers_follower, channel_id).status_code == 403


def test_a_poll_needs_at_least_two_options(client):
    headers, _ = _signup(client, "+22899100073")
    channel_id = _create_channel(client, headers).json()["id"]

    refused = _publish_poll(client, headers, channel_id, options=["Oui", "   "])
    assert refused.status_code == 400
    assert "au moins" in refused.json()["detail"]


def test_anyone_who_can_read_the_channel_can_vote(client):
    """Voter n'exige pas l'abonnement — comme réagir. Le fil d'une chaîne se
    lit sans être abonné, exiger l'abonnement pour voter en ferait la seule
    interaction de chaîne à le demander."""
    headers_owner, _ = _signup(client, "+22899100074")
    headers_stranger, stranger_id = _signup(client, "+22899100075")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    poll = _publish_poll(client, headers_owner, channel_id).json()["poll"]
    option_id = poll["options"][0]["id"]

    voted = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [option_id]}, headers=headers_stranger
    )
    assert voted.status_code == 200, voted.text
    assert voted.json()["total_voters"] == 1
    assert voted.json()["options"][0]["vote_count"] == 1
    assert voted.json()["options"][0]["mine"] is True


def test_a_channel_poll_never_reveals_who_voted(client):
    """La différence de fond avec un sondage de groupe : une chaîne peut avoir
    des milliers d'abonnés qui ne se connaissent pas. Publier « qui a voté
    quoi » y exposerait une opinion ET l'identifiant du compte qui la porte."""
    headers_owner, _ = _signup(client, "+22899100076")
    headers_voter, voter_id = _signup(client, "+22899100077")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    poll = _publish_poll(client, headers_owner, channel_id).json()["poll"]
    option_id = poll["options"][0]["id"]
    client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [option_id]}, headers=headers_voter
    )

    # Ni pour un lecteur quelconque, ni pour l'auteur de la chaîne, ni sur la
    # route du sondage lui-même.
    for headers in (headers_owner, headers_voter):
        listed = client.get(f"/api/v1/channels/{channel_id}/posts", headers=headers).json()["items"]
        served = listed[0]["poll"]
        assert served["reveals_voters"] is False
        assert all(option["voters"] == [] for option in served["options"])
        # Le comptage, lui, reste public : c'est le résultat du sondage.
        assert served["options"][0]["vote_count"] == 1

    direct = client.get(f"/api/v1/polls/{poll['id']}", headers=headers_owner).json()
    assert direct["reveals_voters"] is False
    assert all(option["voters"] == [] for option in direct["options"])


def test_a_single_choice_vote_replaces_the_previous_one(client):
    headers_owner, _ = _signup(client, "+22899100078")
    headers_voter, _ = _signup(client, "+22899100079")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    poll = _publish_poll(client, headers_owner, channel_id).json()["poll"]
    first, second = poll["options"][0]["id"], poll["options"][1]["id"]

    client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_voter
    )
    changed = client.post(
        f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [second]}, headers=headers_voter
    ).json()

    # Remplacé, pas empilé : une seule voix au total.
    assert changed["total_voters"] == 1
    assert [option["vote_count"] for option in changed["options"]] == [0, 1]

    refused = client.post(
        f"/api/v1/polls/{poll['id']}/vote",
        json={"option_ids": [first, second]},
        headers=headers_voter,
    )
    assert refused.status_code == 400


def test_deleting_a_poll_post_takes_the_poll_with_it(client):
    """Sans geste explicite côté route, la ligne `polls`, ses options et ses
    votes resteraient en base sans plus rien pour les afficher : la cascade de
    la base va dans l'autre sens."""
    headers, _ = _signup(client, "+22899100080")
    channel_id = _create_channel(client, headers).json()["id"]
    created = _publish_poll(client, headers, channel_id).json()
    poll_id = created["poll"]["id"]

    assert client.delete(
        f"/api/v1/channels/{channel_id}/posts/{created['id']}", headers=headers
    ).json() == {"deleted": True}
    # 404 et non une réponse vide : le sondage n'existe plus du tout.
    assert client.get(f"/api/v1/polls/{poll_id}", headers=headers).status_code == 404


def test_a_post_still_needs_text_media_or_a_poll(client):
    headers, _ = _signup(client, "+22899100081")
    channel_id = _create_channel(client, headers).json()["id"]

    empty = client.post(f"/api/v1/channels/{channel_id}/posts", json={}, headers=headers)
    assert empty.status_code == 400
    assert "sondage" in empty.json()["detail"]


# ─── Visibilité des images (le trou du 404) ───────────────────────────────────
#
# Une chaîne est PUBLIQUE : son logo et les images de ses publications
# doivent se charger pour tout le monde. Sans branche dédiée dans
# media.py::_can_access, seul l'admin qui les avait téléversées y accédait —
# tous les autres voyaient des cadres cassés, et les journaux de production
# un 404 sur GET /media/{id} juste après GET /channels.

def test_the_channel_logo_loads_for_everyone(client):
    headers_owner, _ = _signup(client, "+22899100090")
    headers_stranger, _ = _signup(client, "+22899100091")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    media_id = _upload(client, headers_owner, "logo.jpg")
    client.patch(
        f"/api/v1/channels/{channel_id}", json={"avatar_media_id": media_id}, headers=headers_owner
    )

    # Le logo est bien annoncé dans la fiche…
    listed = client.get("/api/v1/channels/search?q=Prix", headers=headers_stranger).json()
    assert listed["items"][0]["avatar"]["id"] == media_id
    # …et il se télécharge, même sans être abonné.
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_stranger).status_code == 200


def test_an_image_published_in_a_channel_loads_for_readers(client):
    headers_owner, _ = _signup(client, "+22899100092")
    headers_reader, _ = _signup(client, "+22899100093")
    channel_id = _create_channel(client, headers_owner).json()["id"]
    media_id = _upload(client, headers_owner, "ciment.jpg")
    _publish(client, headers_owner, channel_id, media_asset_id=media_id)

    assert client.get(f"/api/v1/media/{media_id}", headers=headers_reader).status_code == 200


def test_an_unpublished_upload_stays_private(client):
    """La contrepartie : rendre les images de chaîne publiques ne doit pas
    ouvrir tout le stockage. Un fichier téléversé et jamais publié reste au
    seul auteur — 404 et non 403, pour ne pas confirmer qu'il existe."""
    headers_owner, _ = _signup(client, "+22899100094")
    headers_stranger, _ = _signup(client, "+22899100095")
    _create_channel(client, headers_owner)
    media_id = _upload(client, headers_owner, "brouillon.jpg")

    assert client.get(f"/api/v1/media/{media_id}", headers=headers_stranger).status_code == 404
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_owner).status_code == 200


# ─── Suggestions : de quoi remplir un écran vide ─────────────────────────────

def test_suggested_channels_exclude_what_i_already_follow(client):
    """Recommander ce qu'on lit déjà ferait douter que la suggestion regarde
    quoi que ce soit."""
    headers_owner, _ = _signup(client, "+22899900001")
    headers_me, _ = _signup(client, "+22899900002")
    followed = _create_channel(client, headers_owner, name="Déjà suivie").json()
    other = _create_channel(client, headers_owner, name="Pas encore").json()
    client.post(f"/api/v1/channels/{followed['id']}/follow", headers=headers_me)

    items = client.get("/api/v1/channels/suggested", headers=headers_me).json()["items"]

    names = [c["name"] for c in items]
    assert other["name"] in names
    assert followed["name"] not in names


def test_suggested_channels_exclude_my_own(client):
    """On ne se suggère pas à soi-même."""
    headers, _ = _signup(client, "+22899900003")
    mine = _create_channel(client, headers, name="La mienne").json()

    items = client.get("/api/v1/channels/suggested", headers=headers).json()["items"]

    assert mine["name"] not in [c["name"] for c in items]


def test_suggested_channels_put_verified_first(client):
    """Dans une application neuve, le nombre d'abonnés est un signal faible :
    la certification est la seule garantie qu'on ne recommande pas n'importe
    quoi à quelqu'un qui découvre."""
    headers_owner, _ = _signup(client, "+22899900004")
    headers_me, _ = _signup(client, "+22899900005")
    _create_channel(client, headers_owner, name="Anonyme")
    verified = _create_channel(client, headers_owner, name="Certifiée").json()

    db = TestingSessionLocal()
    from app.models import Channel
    db.query(Channel).filter(Channel.id == verified["id"]).update({"is_verified": True})
    db.commit()
    db.close()

    items = client.get("/api/v1/channels/suggested", headers=headers_me).json()["items"]

    assert items[0]["name"] == "Certifiée"


def test_suggested_channels_are_not_yet_followed(client):
    """Le client affiche un bouton « S'abonner » sur chacune : les renvoyer
    déjà marquées comme suivies afficherait le mauvais bouton."""
    headers_owner, _ = _signup(client, "+22899900006")
    headers_me, _ = _signup(client, "+22899900007")
    _create_channel(client, headers_owner, name="À découvrir")

    items = client.get("/api/v1/channels/suggested", headers=headers_me).json()["items"]

    assert items, "il y a bien une chaîne à suggérer"
    assert all(c["is_following"] is False for c in items)


def test_suggested_channels_respect_the_limit(client):
    headers_owner, _ = _signup(client, "+22899900008")
    headers_me, _ = _signup(client, "+22899900009")
    for index in range(5):
        _create_channel(client, headers_owner, name=f"Chaîne {index}")

    items = client.get(
        "/api/v1/channels/suggested?limit=2", headers=headers_me
    ).json()["items"]

    assert len(items) == 2


# ─── Certification : un abonnement, et un dossier examiné ────────────────────

def _request_certification(client, headers, channel_id, plan="MONTHLY"):
    return client.post(
        f"/api/v1/channels/{channel_id}/certification",
        json={"plan": plan},
        headers=headers,
    )


def test_only_the_owner_can_ask_for_certification(client):
    headers_owner, _ = _signup(client, "+22899910001")
    headers_other, _ = _signup(client, "+22899910002")
    channel_id = _create_channel(client, headers_owner).json()["id"]

    refused = _request_certification(client, headers_other, channel_id)
    assert refused.status_code == 403


def test_the_price_comes_from_the_server_not_the_client(client):
    """La leçon d'ad_amount_for : un tarif ne se demande pas au payeur."""
    from app.services.marketplace.marketplace_monetization_service import CHANNEL_CERTIFICATION_ANNUAL_AMOUNT, CHANNEL_CERTIFICATION_MONTHLY_AMOUNT
    headers, _ = _signup(client, "+22899910003")
    monthly = _create_channel(client, headers, name="Mensuelle").json()["id"]
    annual = _create_channel(client, headers, name="Annuelle").json()["id"]

    assert _request_certification(client, headers, monthly).json()["amount"] == (
        CHANNEL_CERTIFICATION_MONTHLY_AMOUNT
    )
    assert _request_certification(client, headers, annual, plan="ANNUAL").json()[
        "amount"
    ] == CHANNEL_CERTIFICATION_ANNUAL_AMOUNT


def test_an_unknown_plan_is_refused(client):
    headers, _ = _signup(client, "+22899910004")
    channel_id = _create_channel(client, headers).json()["id"]

    refused = _request_certification(client, headers, channel_id, plan="LIFETIME")
    assert refused.status_code == 400


def test_paying_does_not_grant_the_badge(client):
    """Un badge qui s'achète sans regard ne vaut rien."""
    headers, _ = _signup(client, "+22899910005")
    channel_id = _create_channel(client, headers).json()["id"]

    _request_certification(client, headers, channel_id)

    channel = client.get("/api/v1/channels", headers=headers).json()["items"][0]
    assert channel["is_verified"] is False


def test_two_pending_requests_are_refused(client):
    headers, _ = _signup(client, "+22899910006")
    channel_id = _create_channel(client, headers).json()["id"]
    _request_certification(client, headers, channel_id)

    again = _request_certification(client, headers, channel_id)
    assert again.status_code == 409


def _confirmer_paiement(application_id):
    """Marque comme CONFIRMÉ le paiement du dossier. L'approbation l'exige
    désormais (409 sinon) : en test, Semoa n'est pas joignable et le paiement
    reste donc en échec, ce que ces tests ne cherchent pas à vérifier."""
    from app.models import ChannelCertificationApplication, MarketplacePayment

    db = TestingSessionLocal()
    application = db.query(ChannelCertificationApplication).filter(ChannelCertificationApplication.id == application_id).one()
    db.query(MarketplacePayment).filter(MarketplacePayment.id == application.payment_id).update({"status": "CONFIRMED"})
    db.commit()
    db.close()


def test_approval_requires_a_confirmed_payment(client, admin_headers):
    headers, _ = _signup(client, "+22899910090")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()["application_id"]

    refused = client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": True},
        headers=admin_headers,
    )

    assert refused.status_code == 409
    channel = client.get("/api/v1/channels", headers=headers).json()["items"][0]
    assert channel["is_verified"] is False


def test_approval_grants_the_badge_with_an_expiry(client, admin_headers):
    headers, _ = _signup(client, "+22899910007")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()[
        "application_id"
    ]

    _confirmer_paiement(application_id)
    review = client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": True},
        headers=admin_headers,
    )

    assert review.status_code == 200, review.text
    assert review.json()["verified_until"] is not None
    channel = client.get("/api/v1/channels", headers=headers).json()["items"][0]
    assert channel["is_verified"] is True


def test_a_refusal_leaves_the_channel_plain(client, admin_headers):
    headers, _ = _signup(client, "+22899910008")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()[
        "application_id"
    ]

    client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": False, "note": "Chaîne trop récente"},
        headers=admin_headers,
    )

    channel = client.get("/api/v1/channels", headers=headers).json()["items"][0]
    assert channel["is_verified"] is False


def test_an_expired_certification_stops_showing(client, admin_headers):
    """Sans tâche de fond : la comparaison se fait à la LECTURE, donc un
    abonnement échu s'éteint tout seul même si rien ne tourne."""
    from datetime import datetime, timedelta
    from app.models import Channel

    headers, _ = _signup(client, "+22899910009")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()[
        "application_id"
    ]
    _confirmer_paiement(application_id)
    client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": True},
        headers=admin_headers,
    )

    db = TestingSessionLocal()
    db.query(Channel).filter(Channel.id == channel_id).update(
        {"verified_until": datetime.utcnow() - timedelta(days=1)}
    )
    db.commit()
    db.close()

    channel = client.get("/api/v1/channels", headers=headers).json()["items"][0]
    assert channel["is_verified"] is False


def test_renewing_early_extends_instead_of_replacing(client, admin_headers):
    """Renouveler avant l'échéance ne doit pas faire perdre le reliquat."""
    headers, _ = _signup(client, "+22899910010")
    channel_id = _create_channel(client, headers).json()["id"]

    first = _request_certification(client, headers, channel_id).json()["application_id"]
    _confirmer_paiement(first)
    after_first = client.put(
        f"/api/v1/channels/certifications/{first}",
        json={"approved": True},
        headers=admin_headers,
    ).json()["verified_until"]

    second = _request_certification(client, headers, channel_id).json()["application_id"]
    _confirmer_paiement(second)
    after_second = client.put(
        f"/api/v1/channels/certifications/{second}",
        json={"approved": True},
        headers=admin_headers,
    ).json()["verified_until"]

    assert after_second > after_first


def test_a_reviewed_file_cannot_be_reviewed_twice(client, admin_headers):
    headers, _ = _signup(client, "+22899910011")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()[
        "application_id"
    ]
    _confirmer_paiement(application_id)
    client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": True},
        headers=admin_headers,
    )

    again = client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": False},
        headers=admin_headers,
    )
    assert again.status_code == 409


def test_an_ordinary_user_cannot_review(client):
    headers, _ = _signup(client, "+22899910012")
    channel_id = _create_channel(client, headers).json()["id"]
    application_id = _request_certification(client, headers, channel_id).json()[
        "application_id"
    ]

    _confirmer_paiement(application_id)
    refused = client.put(
        f"/api/v1/channels/certifications/{application_id}",
        json={"approved": True},
        headers=headers,
    )
    assert refused.status_code in (401, 403)


def test_the_admin_list_shows_pending_files(client, admin_headers):
    headers, _ = _signup(client, "+22899910013")
    channel_id = _create_channel(client, headers, name="À certifier").json()["id"]
    _request_certification(client, headers, channel_id, plan="ANNUAL")

    items = client.get(
        "/api/v1/channels/certifications", headers=admin_headers
    ).json()["items"]

    assert len(items) == 1
    assert items[0]["channel_name"] == "À certifier"
    assert items[0]["plan"] == "ANNUAL"

