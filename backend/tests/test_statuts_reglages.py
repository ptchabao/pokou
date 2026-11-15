"""Statuts et réglages — ce que les écrans de la maquette ajoutent au serveur.

- le cœur posé sur un statut, que seul l'auteur voit dans « Vu par » ;
- « Couper les appels d'inconnus » : l'appel ne sonne pas, il reste au
  journal ;
- les push des services coupés par module (Réglages · Notifications) ;
- « Télécharger mes données » ;
- « Code PIN oublié » depuis Compte et sécurité.
"""
import base64
import re
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import CallLog, CallParticipant, ServiceNotification, User
from app.api.v1.account import account_privacy
from app.services.auth import otp_service
from app.services.notifications import inbox

TEST_DATABASE_URL = "sqlite:///./test_pokou_statuts_reglages.db"

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
    account_privacy._two_step_failures.clear()
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    account_privacy._two_step_failures.clear()
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _contact(client, headers, phone, name):
    response = client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers
    )
    assert response.status_code in (200, 201), response.text


def _post_text_status(client, headers):
    audience = client.get("/api/v1/status/audience", headers=headers).json()["recipient_ids"]
    recipients = [
        {
            "user_id": user_id,
            "encryption": "v1",
            "ciphertext": base64.b64encode(b"\x00" * 32).decode(),
            "envelope": {
                "v": 1,
                "sid": f"test-{user_id}",
                "n": 0,
                "iv": base64.b64encode(b"\x00" * 12).decode(),
            },
        }
        for user_id in audience
    ]
    response = client.post(
        "/api/v1/status",
        json={"content_type": "TEXT", "recipients": recipients},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()["id"]


# ─── Le cœur sur un statut ────────────────────────────────────────────────────


def test_a_heart_is_seen_by_the_author_only_in_viewed_by(client):
    headers_a, _ = _signup(client, "+22895100001")
    headers_b, user_b = _signup(client, "+22895100002")
    _contact(client, headers_a, "+22895100002", "Bob")
    _contact(client, headers_b, "+22895100001", "Ama")
    status_id = _post_text_status(client, headers_a)

    # Aimer sans avoir « vu » : la vue est créée au passage.
    liked = client.post(f"/api/v1/status/{status_id}/like", json={"liked": True}, headers=headers_b)
    assert liked.status_code == 200, liked.text
    assert liked.json() == {"liked": True}

    views = client.get(f"/api/v1/status/{status_id}/views", headers=headers_a).json()
    assert views["view_count"] == 1
    assert views["items"][0]["viewer_id"] == user_b
    assert views["items"][0]["liked"] is True

    # Le spectateur retrouve son cœur dans le fil.
    feed = client.get("/api/v1/status/feed", headers=headers_b).json()["items"]
    status = next(item for item in feed if item["statuses"][0]["id"] == status_id)
    assert status["statuses"][0]["liked_by_me"] is True

    # Et peut le retirer.
    client.post(f"/api/v1/status/{status_id}/like", json={"liked": False}, headers=headers_b)
    views = client.get(f"/api/v1/status/{status_id}/views", headers=headers_a).json()
    assert views["items"][0]["liked"] is False


def test_nobody_can_like_a_status_they_cannot_see_nor_their_own(client):
    headers_a, _ = _signup(client, "+22895100003")
    headers_c, _ = _signup(client, "+22895100004")
    status_id = _post_text_status(client, headers_a)

    stranger = client.post(f"/api/v1/status/{status_id}/like", json={"liked": True}, headers=headers_c)
    assert stranger.status_code == 404
    mine = client.post(f"/api/v1/status/{status_id}/like", json={"liked": True}, headers=headers_a)
    assert mine.status_code == 404


# ─── Couper les appels d'inconnus ─────────────────────────────────────────────


def _patched_livekit():
    settings = MagicMock()
    settings.livekit_enabled = True
    settings.livekit_api_key = "fake-key"
    settings.livekit_api_secret = "fake-secret-fake-secret-32bytes!"
    settings.livekit_url = "wss://fake.livekit.cloud"
    settings.livekit_token_ttl_minutes = 15
    settings.call_max_group_ring = 8
    return (
        patch("app.services.calls.livekit_service.get_settings", return_value=settings),
        patch("app.api.v1.calls.calls.get_settings", return_value=settings),
    )


def test_the_setting_is_off_by_default_and_saved_with_the_privacy_screen(client):
    headers, _ = _signup(client, "+22895200001")
    assert client.get("/api/v1/account-privacy/privacy", headers=headers).json()[
        "silence_unknown_calls"
    ] is False
    saved = client.put(
        "/api/v1/account-privacy/privacy",
        json={"silence_unknown_calls": True},
        headers=headers,
    ).json()
    assert saved["silence_unknown_calls"] is True
    # Envoi partiel : le reste ne bouge pas.
    assert saved["read_receipts"] is True


def test_a_call_from_an_unknown_does_not_ring_but_stays_in_the_log(client):
    headers_a, _ = _signup(client, "+22895200002")
    headers_b, user_b = _signup(client, "+22895200003")
    # A connaît B ; B ne connaît pas A.
    _contact(client, headers_a, "+22895200003", "Bob")
    client.put(
        "/api/v1/account-privacy/privacy",
        json={"silence_unknown_calls": True},
        headers=headers_b,
    )

    patch_service, patch_route = _patched_livekit()
    send = AsyncMock(return_value=True)
    with patch_service, patch_route, patch(
        "app.api.v1.calls.calls.manager.send_to_user", send
    ), patch("app.api.v1.calls.calls.send_push") as push:
        response = client.post(
            "/api/v1/calls/token", json={"contact_ids": [user_b]}, headers=headers_a
        )
    assert response.status_code == 200, response.text
    send.assert_not_called()
    push.assert_not_called()

    db = TestingSessionLocal()
    try:
        call = db.query(CallLog).filter(CallLog.room == response.json()["room"]).one()
        participant = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call.id
        ).one()
        assert participant.user_id == user_b
    finally:
        db.close()


def test_a_call_from_a_contact_still_rings(client):
    headers_a, _ = _signup(client, "+22895200004")
    headers_b, user_b = _signup(client, "+22895200005")
    _contact(client, headers_a, "+22895200005", "Bob")
    _contact(client, headers_b, "+22895200004", "Ama")
    client.put(
        "/api/v1/account-privacy/privacy",
        json={"silence_unknown_calls": True},
        headers=headers_b,
    )

    patch_service, patch_route = _patched_livekit()
    send = AsyncMock(return_value=True)
    with patch_service, patch_route, patch(
        "app.api.v1.calls.calls.manager.send_to_user", send
    ):
        response = client.post(
            "/api/v1/calls/token", json={"contact_ids": [user_b]}, headers=headers_a
        )
    assert response.status_code == 200, response.text
    assert send.await_count == 1
    assert send.await_args.args[0] == user_b


# ─── Push des services, module par module ─────────────────────────────────────


def test_a_muted_service_keeps_its_line_but_sends_no_push(client):
    headers, user_id = _signup(client, "+22895300001")
    assert client.get("/api/v1/notifications/preferences", headers=headers).json() == {
        "kory": True,
        "honam": True,
        "assime": True,
    }
    saved = client.put(
        "/api/v1/notifications/preferences", json={"kory": False}, headers=headers
    ).json()
    assert saved == {"kory": False, "honam": True, "assime": True}

    db = TestingSessionLocal()
    try:
        with patch("app.services.notifications.inbox.send_push") as push:
            inbox.notify(db, [user_id], service="kory", title="Kory", body="Rappel")
            inbox.notify(db, [user_id], service="honam", title="Honam", body="Devis")
            db.commit()
        assert push.call_count == 1
        assert push.call_args.kwargs["data"]["service"] == "honam"
        # Les deux lignes sont dans le centre de notifications.
        assert db.query(ServiceNotification).filter(
            ServiceNotification.user_id == user_id
        ).count() == 2
    finally:
        db.close()


# ─── Télécharger mes données ──────────────────────────────────────────────────


def test_the_export_holds_profile_contacts_and_settings_never_the_pin(client):
    headers, _ = _signup(client, "+22895400001")
    _contact(client, headers, "+22895400002", "Maman")
    client.post("/api/v1/account-privacy/two-step", json={"pin": "123456"}, headers=headers)

    response = client.get("/api/v1/account-privacy/export", headers=headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["profile"]["phone"] == "+22895400001"
    assert [c["name"] for c in body["contacts"]] == ["Maman"]
    assert body["settings"]["two_step_enabled"] is True
    assert "123456" not in response.text
    db = TestingSessionLocal()
    try:
        pin_hash = db.query(User.two_step_pin_hash).filter(User.phone == "+22895400001").scalar()
    finally:
        db.close()
    assert pin_hash not in response.text


# ─── Code PIN oublié, depuis les réglages ─────────────────────────────────────


def test_forgot_pin_from_settings_opens_the_seven_day_delay_once(client):
    headers, _ = _signup(client, "+22895500001")
    refused = client.post("/api/v1/account-privacy/two-step/forgot", headers=headers)
    assert refused.status_code == 409

    client.post("/api/v1/account-privacy/two-step", json={"pin": "123456"}, headers=headers)
    first = client.post("/api/v1/account-privacy/two-step/forgot", headers=headers)
    assert first.status_code == 200, first.text
    second = client.post("/api/v1/account-privacy/two-step/forgot", headers=headers)
    # Redemander ne relance pas le délai.
    assert second.json()["available_at"] == first.json()["available_at"]
