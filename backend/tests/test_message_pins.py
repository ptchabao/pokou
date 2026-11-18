"""Messages épinglés — discussions à deux et groupes.

Le serveur ne tient que des identifiants : ces tests vérifient aussi qu'aucun
contenu ne sort jamais dans une épingle.
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import (
    DirectMessagePin,
    GroupInvitation,
    GroupInvitationStatus,
    GroupMessagePin,
)
from app.services.auth import otp_service
from app.services.messaging import group_invitation_service
from app.services.messaging.sync_service import DURABLE_EVENT_TYPES
from tests.helpers import GroupCryptoClient

TEST_DATABASE_URL = "sqlite:///./test_pokou_pins.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


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
    yield GroupCryptoClient(TestClient(app))
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"], body["access_token"]


def _linked_pair(client, phone_a, phone_b):
    headers_a, user_id_a, token_a = _signup(client, phone_a)
    headers_b, user_id_b, token_b = _signup(client, phone_b)
    client.post("/api/v1/contacts", json={"phone": phone_b, "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": phone_a, "display_name": "Alice"}, headers=headers_b)
    return (headers_a, user_id_a, token_a), (headers_b, user_id_b, token_b)


def _send(client, headers, recipient_id, text="bonjour"):
    response = client.post(
        "/api/v1/messages", json={"recipient_id": recipient_id, "content": text}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def _pin(client, message_id, headers, seconds=86400):
    return client.put(
        f"/api/v1/messages/{message_id}/pin", json={"duration_seconds": seconds}, headers=headers
    )


# ─── Discussion à deux ────────────────────────────────────────────────────────

def test_epingler_un_message_le_montre_aux_deux_cotes(client):
    (headers_a, user_a, _), (headers_b, user_b, _) = _linked_pair(client, "+22893100001", "+22893100002")
    sent = _send(client, headers_a, user_b, "rdv 18h au marché")

    response = _pin(client, sent["id"], headers_b, 604800)
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    assert [p["message_id"] for p in items] == [sent["id"]]
    assert items[0]["pinned_by"] == user_b
    # Jamais de contenu dans une épingle : le message est chiffré.
    assert set(items[0]) == {"message_id", "pinned_by", "pinned_at", "expires_at"}

    for headers, other in ((headers_a, user_b), (headers_b, user_a)):
        pins = client.get(f"/api/v1/messages/{other}/pins", headers=headers).json()["items"]
        assert [p["message_id"] for p in pins] == [sent["id"]]
        conversation = client.get(f"/api/v1/messages/{other}", headers=headers).json()
        assert [p["message_id"] for p in conversation["pins"]] == [sent["id"]]


def test_une_duree_non_proposee_est_refusee(client):
    (headers_a, _, _), (_, user_b, _) = _linked_pair(client, "+22893100003", "+22893100004")
    sent = _send(client, headers_a, user_b)
    assert _pin(client, sent["id"], headers_a, 5).status_code == 400


def test_un_tiers_ne_peut_ni_epingler_ni_desepingler(client):
    (headers_a, _, _), (_, user_b, _) = _linked_pair(client, "+22893100005", "+22893100006")
    headers_c, _, _ = _signup(client, "+22893100007")
    sent = _send(client, headers_a, user_b)

    assert _pin(client, sent["id"], headers_c).status_code == 404
    assert _pin(client, sent["id"], headers_a).status_code == 200
    assert client.delete(f"/api/v1/messages/{sent['id']}/pin", headers=headers_c).status_code == 404
    with TestingSessionLocal() as db:
        assert db.query(DirectMessagePin).count() == 1


def test_au_plus_trois_epingles_la_plus_ancienne_cede_sa_place(client):
    (headers_a, _, _), (_, user_b, _) = _linked_pair(client, "+22893100008", "+22893100009")
    sent = [_send(client, headers_a, user_b, f"message {i}") for i in range(4)]
    for message in sent[:3]:
        assert _pin(client, message["id"], headers_a).status_code == 200
    with TestingSessionLocal() as db:
        # Les trois premières épinglées à des instants distincts.
        for offset, message in enumerate(sent[:3]):
            db.query(DirectMessagePin).filter(DirectMessagePin.message_id == message["id"]).update(
                {"pinned_at": datetime.utcnow() - timedelta(minutes=10 - offset)}
            )
        db.commit()

    items = _pin(client, sent[3]["id"], headers_a).json()["items"]
    assert [p["message_id"] for p in items] == [sent[3]["id"], sent[2]["id"], sent[1]["id"]]


def test_une_epingle_echue_disparait_a_la_lecture(client):
    (headers_a, _, _), (_, user_b, _) = _linked_pair(client, "+22893100010", "+22893100011")
    sent = _send(client, headers_a, user_b)
    _pin(client, sent["id"], headers_a)
    with TestingSessionLocal() as db:
        db.query(DirectMessagePin).update({"expires_at": datetime.utcnow() - timedelta(seconds=1)})
        db.commit()
    assert client.get(f"/api/v1/messages/{user_b}/pins", headers=headers_a).json()["items"] == []


def test_desepingler_retire_l_epingle(client):
    (headers_a, _, _), (headers_b, user_b, _) = _linked_pair(client, "+22893100012", "+22893100013")
    sent = _send(client, headers_a, user_b)
    _pin(client, sent["id"], headers_a)
    response = client.delete(f"/api/v1/messages/{sent['id']}/pin", headers=headers_b)
    assert response.status_code == 200
    assert response.json()["items"] == []
    # Bascule : désépingler deux fois n'est pas une erreur.
    assert client.delete(f"/api/v1/messages/{sent['id']}/pin", headers=headers_b).status_code == 200


def test_supprimer_pour_tous_retire_l_epingle(client):
    (headers_a, _, _), (_, user_b, _) = _linked_pair(client, "+22893100014", "+22893100015")
    sent = _send(client, headers_a, user_b)
    _pin(client, sent["id"], headers_a)
    assert client.delete(f"/api/v1/messages/{sent['id']}", headers=headers_a).status_code == 200
    with TestingSessionLocal() as db:
        assert db.query(DirectMessagePin).count() == 0
    assert client.get(f"/api/v1/messages/{user_b}/pins", headers=headers_a).json()["items"] == []


def test_l_epingle_est_poussee_a_l_autre_partie(client):
    assert "message:pinned" in DURABLE_EVENT_TYPES
    (headers_a, user_a, token_a), (headers_b, user_b, _) = _linked_pair(client, "+22893100016", "+22893100017")
    sent = _send(client, headers_a, user_b)

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws:
        assert _pin(client, sent["id"], headers_b).status_code == 200
        event = ws.receive_json()
        assert event["type"] == "message:pinned"
        # Du point de vue de celui qui reçoit : la conversation avec B.
        assert event["peer_id"] == user_b
        assert [p["message_id"] for p in event["pins"]] == [sent["id"]]
        assert event.get("sync_event_id")


# ─── Groupes ──────────────────────────────────────────────────────────────────

def _make_group(client, headers, members):
    for phone, _ in members:
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers)
    group = client.post(
        "/api/v1/groups",
        json={"name": "Marché", "member_user_ids": [user_id for _, user_id in members]},
        headers=headers,
    ).json()
    with TestingSessionLocal() as db:
        for _, user_id in members:
            invitation = db.query(GroupInvitation).filter(
                GroupInvitation.group_id == group["id"],
                GroupInvitation.user_id == user_id,
                GroupInvitation.status == GroupInvitationStatus.PENDING,
            ).first()
            if invitation is not None:
                group_invitation_service.accepter(db, invitation)
        db.commit()
    return group


def _group_setup(client, prefix):
    headers_a, user_a, token_a = _signup(client, f"{prefix}1")
    headers_b, user_b, token_b = _signup(client, f"{prefix}2")
    group = _make_group(client, headers_a, [(f"{prefix}2", user_b)])
    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "réunion samedi"}, headers=headers_b
    )
    assert sent.status_code == 200, sent.text
    return group, sent.json(), (headers_a, user_a, token_a), (headers_b, user_b, token_b)


def _group_pin(client, group_id, message_id, headers, seconds=86400):
    return client.put(
        f"/api/v1/groups/{group_id}/messages/{message_id}/pin",
        json={"duration_seconds": seconds},
        headers=headers,
    )


def test_un_admin_epingle_pour_tout_le_groupe(client):
    group, sent, (headers_a, user_a, _), (headers_b, _, _) = _group_setup(client, "+2289320000")
    response = _group_pin(client, group["id"], sent["id"], headers_a)
    assert response.status_code == 200, response.text
    assert response.json()["items"][0]["pinned_by"] == user_a
    assert set(response.json()["items"][0]) == {"message_id", "pinned_by", "pinned_at", "expires_at"}

    pins = client.get(f"/api/v1/groups/{group['id']}/pins", headers=headers_b).json()["items"]
    assert [p["message_id"] for p in pins] == [sent["id"]]
    page = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_b).json()
    assert [p["message_id"] for p in page["pins"]] == [sent["id"]]


def test_un_membre_n_epingle_que_si_le_groupe_le_permet(client):
    group, sent, (headers_a, _, _), (headers_b, _, _) = _group_setup(client, "+2289320001")
    refused = _group_pin(client, group["id"], sent["id"], headers_b)
    assert refused.status_code == 403
    assert "administrateurs" in refused.json()["detail"]

    opened = client.patch(
        f"/api/v1/groups/{group['id']}", json={"members_can_edit_info": True}, headers=headers_a
    )
    assert opened.status_code == 200, opened.text
    assert _group_pin(client, group["id"], sent["id"], headers_b).status_code == 200
    assert client.delete(
        f"/api/v1/groups/{group['id']}/messages/{sent['id']}/pin", headers=headers_b
    ).status_code == 200


def test_un_non_membre_ne_peut_ni_epingler_ni_lire_les_epingles(client):
    group, sent, _, _ = _group_setup(client, "+2289320002")
    headers_c, _, _ = _signup(client, "+22893200029")
    assert _group_pin(client, group["id"], sent["id"], headers_c).status_code == 403
    assert client.get(f"/api/v1/groups/{group['id']}/pins", headers=headers_c).status_code == 403


def test_groupe_limite_expiration_et_suppression(client):
    group, sent, (headers_a, _, _), _ = _group_setup(client, "+2289320003")
    others = [
        client.post(
            f"/api/v1/groups/{group['id']}/messages", json={"content": f"m{i}"}, headers=headers_a
        ).json()
        for i in range(3)
    ]
    assert _group_pin(client, group["id"], sent["id"], headers_a).status_code == 200
    with TestingSessionLocal() as db:
        db.query(GroupMessagePin).update({"pinned_at": datetime.utcnow() - timedelta(hours=1)})
        db.commit()
    for message in others:
        assert _group_pin(client, group["id"], message["id"], headers_a).status_code == 200
    pins = client.get(f"/api/v1/groups/{group['id']}/pins", headers=headers_a).json()["items"]
    assert len(pins) == 3
    assert sent["id"] not in [p["message_id"] for p in pins]

    # Suppression pour tous : l'épingle part avec le message.
    deleted = client.delete(f"/api/v1/groups/{group['id']}/messages/{others[0]['id']}", headers=headers_a)
    assert deleted.status_code == 200
    with TestingSessionLocal() as db:
        assert db.query(GroupMessagePin).filter(GroupMessagePin.message_id == others[0]["id"]).count() == 0

    # Échéance : filtrée à la lecture.
    with TestingSessionLocal() as db:
        db.query(GroupMessagePin).update({"expires_at": datetime.utcnow() - timedelta(seconds=1)})
        db.commit()
    assert client.get(f"/api/v1/groups/{group['id']}/pins", headers=headers_a).json()["items"] == []


def test_l_epingle_de_groupe_est_poussee_aux_membres(client):
    assert "group:message:pinned" in DURABLE_EVENT_TYPES
    group, sent, (headers_a, _, _), (_, _, token_b) = _group_setup(client, "+2289320004")
    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        assert _group_pin(client, group["id"], sent["id"], headers_a).status_code == 200
        event = ws.receive_json()
        while event["type"] != "group:message:pinned":
            event = ws.receive_json()
        assert event["group_id"] == group["id"]
        assert [p["message_id"] for p in event["pins"]] == [sent["id"]]


def test_un_message_d_un_autre_groupe_est_introuvable(client):
    group, _, (headers_a, _, _), _ = _group_setup(client, "+2289320005")
    other_group, other_sent, _, _ = _group_setup(client, "+2289320006")
    assert _group_pin(client, group["id"], other_sent["id"], headers_a).status_code == 404
    assert _group_pin(client, group["id"], "inexistant", headers_a).status_code == 404
