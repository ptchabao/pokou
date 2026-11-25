"""Correctifs de la messagerie signalés par l'équipe de test.

- vue unique : ni transférable, ni resservie après ouverture, en tête-à-tête
  comme en groupe (chaque membre l'ouvre une fois) ;
- réactions : l'auteur du message est prévenu (événement durable À JOUR et
  notification « X a réagi ❤️ à ton message », sans le texte) ;
- sondages : réponse modifiable 15 minutes, puis définitive ; « une seule
  réponse » imposée aussi en groupe, où les choix sont chiffrés.
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Contact, PollVoteWindow, SyncEvent
from app.services.auth import otp_service

engine = create_engine("sqlite:///./test_messagerie_correctifs.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


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
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _pair(client, phone_a="+22895000001", phone_b="+22895000002"):
    headers_a, user_a = _signup(client, phone_a)
    headers_b, user_b = _signup(client, phone_b)
    client.post("/api/v1/contacts", json={"phone": phone_b, "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": phone_a, "display_name": "Awa"}, headers=headers_b)
    return (headers_a, user_a), (headers_b, user_b)


def _upload(client, headers, *, mime="image/jpeg", name="photo.jpg", message_type="IMAGE"):
    response = client.post(
        "/api/v1/media/upload",
        data={"message_type": message_type},
        files={"file": (name, b"\xff\xd8\xff-octets", mime)},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


# ─── Vue unique, tête-à-tête ─────────────────────────────────────────────────

def _view_once(client, headers, recipient_id):
    uploaded = _upload(client, headers)
    sent = client.post(
        "/api/v1/messages",
        json={"recipient_id": recipient_id, "message_type": "IMAGE", "media_asset_id": uploaded["id"], "view_once": True},
        headers=headers,
    )
    assert sent.status_code == 200, sent.text
    return uploaded, sent.json()


def test_une_vue_unique_ne_se_transfere_ni_par_l_expediteur_ni_par_le_destinataire(client):
    (headers_a, user_a), (headers_b, user_b) = _pair(client)
    headers_c, user_c = _signup(client, "+22895000003")
    for headers in (headers_a, headers_b):
        client.post("/api/v1/contacts", json={"phone": "+22895000003", "display_name": "C"}, headers=headers)
    _, message = _view_once(client, headers_a, user_b)

    for headers in (headers_a, headers_b):
        refused = client.post(
            f"/api/v1/messages/{message['id']}/forward", json={"recipient_id": user_c}, headers=headers
        )
        assert refused.status_code == 403, refused.text
    assert client.get(f"/api/v1/messages/{user_a}", headers=headers_c).json()["items"] == []


def test_une_vue_unique_ouverte_n_est_plus_servie_au_destinataire(client):
    (headers_a, _), (headers_b, user_b) = _pair(client)
    uploaded, message = _view_once(client, headers_a, user_b)
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200
    viewed = client.post(f"/api/v1/messages/{message['id']}/viewed", headers=headers_b)
    assert viewed.status_code == 200 and viewed.json()["viewed_at"]
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 404
    # L'expéditeur garde son propre fichier.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_a).status_code == 200


# ─── Réactions ───────────────────────────────────────────────────────────────

def _text(client, headers, recipient_id, content="Le rendez-vous est à 18 h"):
    sent = client.post("/api/v1/messages", json={"recipient_id": recipient_id, "content": content}, headers=headers)
    assert sent.status_code == 200, sent.text
    return sent.json()


def test_l_evenement_durable_d_une_reaction_porte_la_reaction(client):
    """La session ne vide pas ses écritures d'elle-même : l'événement que
    l'auteur rattrape après une coupure était calculé AVANT la réaction."""
    (headers_a, user_a), (headers_b, user_b) = _pair(client)
    message = _text(client, headers_a, user_b)
    assert client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "❤️"}, headers=headers_b).status_code == 200

    db = TestingSessionLocal()
    try:
        events = [e for e in db.query(SyncEvent).filter(SyncEvent.user_id == user_a).all() if e.event_type == "message:reaction"]
    finally:
        db.close()
    assert events, "aucun événement durable pour l'auteur"
    reactions = events[-1].payload["message"]["reactions"]
    assert [(r["emoji"], r["count"]) for r in reactions] == [("❤️", 1)]


def test_l_auteur_est_notifie_d_une_reaction_sans_le_texte_du_message(client):
    (headers_a, user_a), (headers_b, user_b) = _pair(client)
    message = _text(client, headers_a, user_b, content="Code du portail 4589")
    with patch("app.api.v1.messaging.messages.send_push") as push:
        client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "❤️"}, headers=headers_b)
    assert push.call_count == 1
    args, kwargs = push.call_args
    assert args[1] == user_a
    assert kwargs["body"] == "Bob a réagi ❤️ à ton message"
    assert kwargs["data"]["type"] == "reaction"
    assert kwargs["data"]["contact_user_id"] == str(user_b)
    everything = repr((args, kwargs))
    assert "4589" not in everything and "portail" not in everything


def test_pas_de_notification_pour_sa_propre_reaction_ni_pour_un_emoji_repose(client):
    (headers_a, _), (headers_b, user_b) = _pair(client)
    message = _text(client, headers_a, user_b)
    with patch("app.api.v1.messaging.messages.send_push") as push:
        client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "👍"}, headers=headers_a)
        client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)
        client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)
    assert push.call_count == 1


def test_une_conversation_en_sourdine_ne_notifie_pas_les_reactions(client):
    (headers_a, user_a), (headers_b, user_b) = _pair(client)
    message = _text(client, headers_a, user_b)
    db = TestingSessionLocal()
    try:
        contact = db.query(Contact).filter(Contact.owner_user_id == user_a, Contact.contact_user_id == user_b).one()
        contact.muted_until = datetime.utcnow() + timedelta(hours=8)
        db.commit()
    finally:
        db.close()
    with patch("app.api.v1.messaging.messages.send_push") as push:
        client.put(f"/api/v1/messages/{message['id']}/reaction", json={"emoji": "😂"}, headers=headers_b)
    assert push.call_count == 0


# ─── Sondages en tête-à-tête ────────────────────────────────────────────────

def _poll(client, headers, target_id, *, multiple=False):
    response = client.post(
        "/api/v1/polls",
        json={"kind": "contact", "target_id": target_id, "question": "On mange où ?", "options": ["Ici", "Là"], "allows_multiple": multiple},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


def _backdate_window(poll_key, user_id, minutes):
    db = TestingSessionLocal()
    try:
        window = db.query(PollVoteWindow).filter(PollVoteWindow.poll_key == poll_key, PollVoteWindow.user_id == user_id).one()
        window.first_voted_at = datetime.utcnow() - timedelta(minutes=minutes)
        db.commit()
    finally:
        db.close()


def test_une_reponse_reste_modifiable_quinze_minutes_puis_devient_definitive(client):
    (headers_a, user_a), (headers_b, user_b) = _pair(client)
    message = _poll(client, headers_a, user_b)
    poll = message["poll"]
    first, second = [o["id"] for o in poll["options"]]
    assert poll["my_locks_at"] is None and poll["edit_window_seconds"] == 900

    voted = client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_b)
    assert voted.status_code == 200
    locks_at = datetime.fromisoformat(voted.json()["my_locks_at"])
    assert timedelta(minutes=14) < locks_at - datetime.utcnow() <= timedelta(minutes=15)

    # Dans la fenêtre : changer d'avis, et même se rétracter puis revoter.
    assert client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [second]}, headers=headers_b).status_code == 200
    assert client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": []}, headers=headers_b).status_code == 200
    again = client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_b)
    # Revoter ne rouvre PAS une fenêtre neuve.
    assert again.json()["my_locks_at"] == voted.json()["my_locks_at"]

    _backdate_window(poll["id"], user_b, minutes=16)
    late = client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [second]}, headers=headers_b)
    assert late.status_code == 409
    retract = client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": []}, headers=headers_b)
    assert retract.status_code == 409
    # Rejouer exactement l'état enregistré n'est pas un changement.
    assert client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": [first]}, headers=headers_b).status_code == 200

    # Le créateur voit les résultats dans l'historique.
    history = client.get(f"/api/v1/messages/{user_b}", headers=headers_a).json()["items"]
    shown = next(m for m in history if m["id"] == message["id"])
    assert {o["id"]: o["vote_count"] for o in shown["poll"]["options"]} == {first: 1, second: 0}


def test_un_sondage_a_reponse_unique_refuse_deux_reponses(client):
    (headers_a, _), (headers_b, user_b) = _pair(client)
    poll = _poll(client, headers_a, user_b)["poll"]
    ids = [o["id"] for o in poll["options"]]
    assert client.post(f"/api/v1/polls/{poll['id']}/vote", json={"option_ids": ids}, headers=headers_b).status_code == 400
    multiple = _poll(client, headers_a, user_b, multiple=True)["poll"]
    ids = [o["id"] for o in multiple["options"]]
    assert client.post(f"/api/v1/polls/{multiple['id']}/vote", json={"option_ids": ids}, headers=headers_b).status_code == 200


# ─── Groupes ─────────────────────────────────────────────────────────────────

def _family(client):
    headers_a, user_a = _signup(client, "+22895100001")
    headers_b, user_b = _signup(client, "+22895100002")
    headers_c, user_c = _signup(client, "+22895100003")
    for phone, name in (("+22895100002", "B"), ("+22895100003", "C")):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers_a)
    group = client.post(
        "/api/v1/groups", json={"name": "Famille", "member_user_ids": [user_b, user_c]}, headers=headers_a
    ).json()
    for headers in (headers_b, headers_c):
        for invitation in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers)
    epoch = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()["crypto_epoch"]
    client.post(
        f"/api/v1/groups/{group['id']}/sender-key-distributions",
        json={"epoch": epoch, "distributions": [
            {"recipient_id": uid, "encryption": "v1", "ciphertext": "k", "envelope": {"sid": "s"}} for uid in (user_b, user_c)
        ]},
        headers=headers_a,
    )
    return group["id"], epoch, (headers_a, user_a), (headers_b, user_b), (headers_c, user_c)


def _group_send(client, group_id, epoch, headers, **extra):
    body = {"message_type": "TEXT", "encryption": "sender-key-v1", "ciphertext": "chiffre", "crypto_epoch": epoch}
    body.update(extra)
    return client.post(f"/api/v1/groups/{group_id}/messages", json=body, headers=headers)


def test_vue_unique_en_groupe_chaque_membre_l_ouvre_une_fois(client):
    group_id, epoch, (headers_a, user_a), (headers_b, _), (headers_c, _) = _family(client)
    blob = _upload(client, headers_a, mime="application/octet-stream", name="pokou.bin", message_type="DOCUMENT")
    sent = _group_send(client, group_id, epoch, headers_a, message_type="IMAGE", media_asset_id=blob["id"], view_once=True)
    assert sent.status_code == 200, sent.text
    message = sent.json()
    assert message["view_once"] is True and message["viewed_at"] is None

    viewed = client.post(f"/api/v1/groups/{group_id}/messages/{message['id']}/viewed", headers=headers_b)
    assert viewed.status_code == 200 and viewed.json()["viewed_at"]
    again = client.post(f"/api/v1/groups/{group_id}/messages/{message['id']}/viewed", headers=headers_b)
    assert again.json()["viewed_at"] == viewed.json()["viewed_at"]

    # B l'a ouverte : plus de fichier pour lui. C ne l'a pas ouverte, A l'a envoyée.
    assert client.get(f"/api/v1/media/{blob['id']}", headers=headers_b).status_code == 404
    assert client.get(f"/api/v1/media/{blob['id']}", headers=headers_c).status_code == 200
    assert client.get(f"/api/v1/media/{blob['id']}", headers=headers_a).status_code == 200

    # Chacun lit SA consommation dans l'historique.
    def seen_by(headers):
        items = client.get(f"/api/v1/groups/{group_id}/messages", headers=headers).json()["items"]
        return next(m for m in items if m["id"] == message["id"])["viewed_at"]

    assert seen_by(headers_b) is not None
    assert seen_by(headers_c) is None
    # L'expéditeur ne « consomme » pas sa propre vue unique.
    assert client.post(f"/api/v1/groups/{group_id}/messages/{message['id']}/viewed", headers=headers_a).status_code == 400


def test_vue_unique_en_groupe_reservee_aux_photos_et_videos(client):
    group_id, epoch, (headers_a, _), _, _ = _family(client)
    assert _group_send(client, group_id, epoch, headers_a, view_once=True).status_code == 400


def test_sondage_de_groupe_reponse_unique_et_fenetre_de_quinze_minutes(client):
    group_id, epoch, (headers_a, _), (headers_b, user_b), _ = _family(client)
    poll = _group_send(client, group_id, epoch, headers_a, message_type="POLL", poll_allows_multiple=False)
    assert poll.status_code == 200, poll.text
    assert poll.json()["poll_allows_multiple"] is False
    url = f"/api/v1/groups/{group_id}/messages/{poll.json()['id']}/poll-vote"

    two = client.put(url, json={"encryption": "poll-key-v1", "ciphertext": "x", "choice_count": 2}, headers=headers_b)
    assert two.status_code == 400
    one = client.put(url, json={"encryption": "poll-key-v1", "ciphertext": "x", "choice_count": 1}, headers=headers_b)
    assert one.status_code == 200 and one.json()["my_locks_at"]
    assert client.put(url, json={"encryption": "poll-key-v1", "ciphertext": "y", "choice_count": 1}, headers=headers_b).status_code == 200

    _backdate_window(poll.json()["id"], user_b, minutes=16)
    assert client.put(url, json={"encryption": "poll-key-v1", "ciphertext": "z", "choice_count": 1}, headers=headers_b).status_code == 409
    assert client.delete(url, headers=headers_b).status_code == 409
    listed = client.get(f"/api/v1/groups/{group_id}/messages/{poll.json()['id']}/poll-votes", headers=headers_b).json()
    assert listed["my_locks_at"] is not None and listed["edit_window_seconds"] == 900


def test_l_auteur_d_un_message_de_groupe_est_notifie_d_une_reaction(client):
    group_id, epoch, (headers_a, user_a), (headers_b, _), _ = _family(client)
    message = _group_send(client, group_id, epoch, headers_a).json()
    with patch("app.api.v1.messaging.groups.send_push") as push:
        client.put(f"/api/v1/groups/{group_id}/messages/{message['id']}/reaction", json={"emoji": "🙏"}, headers=headers_b)
    assert push.call_count == 1
    args, kwargs = push.call_args
    assert args[1] == user_a
    assert "🙏" in kwargs["body"] and kwargs["data"]["type"] == "reaction"
    assert "chiffre" not in repr((args, kwargs))
