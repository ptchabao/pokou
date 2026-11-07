import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import GroupMessage
from app.services.auth import otp_service


engine = create_engine("sqlite:///./test_group_sender_keys.db", connect_args={"check_same_thread": False})
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


def _create_group(client, headers, name="sender keys"):
    return client.post(
        "/api/v1/groups", json={"name": name, "member_user_ids": []}, headers=headers
    ).json()


def test_group_rejects_plaintext_and_serializes_only_ciphertext(client):
    headers, user_id = _signup(client, "+22893000001")
    group = _create_group(client, headers)
    url = f"/api/v1/groups/{group['id']}/messages"

    rejected = client.post(url, json={"content": "secret"}, headers=headers)
    assert rejected.status_code == 400

    written = client.post(
        url,
        json={
            "encryption": "sender-key-v1",
            "ciphertext": "opaque-signal-ciphertext",
            "crypto_epoch": group["crypto_epoch"],
        },
        headers=headers,
    )
    assert written.status_code == 200, written.text
    assert written.json()["content"] is None
    assert written.json()["ciphertext"] == "opaque-signal-ciphertext"
    listed = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers)
    assert listed.json()["items"][0]["content"] is None

    with TestingSessionLocal() as db:
        row = db.query(GroupMessage).filter_by(id=written.json()["id"]).one()
        assert row.sender_id == user_id
        assert row.content is None


def test_distribution_requires_exact_current_members_and_rejects_stale_epoch(client):
    headers_a, _ = _signup(client, "+22893000002")
    headers_b, user_b = _signup(client, "+22893000003")
    client.post(
        "/api/v1/contacts",
        json={"phone": "+22893000003", "display_name": "B"},
        headers=headers_a,
    )
    group = client.post(
        "/api/v1/groups",
        json={"name": "two members", "member_user_ids": [user_b]},
        headers=headers_a,
    ).json()
    invitation = client.get("/api/v1/groups/invitations", headers=headers_b).json()["items"][0]
    client.post(
        f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers_b
    )
    current = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()
    endpoint = f"/api/v1/groups/{group['id']}/sender-key-distributions"
    stale = client.post(
        endpoint,
        json={"epoch": group["crypto_epoch"], "distributions": []},
        headers=headers_a,
    )
    assert stale.status_code == 409

    accepted = client.post(
        endpoint,
        json={
            "epoch": current["crypto_epoch"],
            "distributions": [
                {
                    "recipient_id": user_b,
                    "encryption": "v1",
                    "ciphertext": "pairwise-ciphertext",
                    "envelope": {"sid": "pairwise-session"},
                }
            ],
        },
        headers=headers_a,
    )
    assert accepted.status_code == 200, accepted.text

    message = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={
            "encryption": "sender-key-v1",
            "ciphertext": "group-ciphertext",
            "crypto_epoch": current["crypto_epoch"] - 1,
        },
        headers=headers_a,
    )
    assert message.status_code == 409

    recipient = client.get(endpoint, headers=headers_b)
    assert recipient.json()["epoch"] == current["crypto_epoch"]
    assert recipient.json()["items"][0]["sender_id"] == current["created_by"]
    assert recipient.json()["items"][0]["ciphertext"] == "pairwise-ciphertext"

    removed = client.delete(
        f"/api/v1/groups/{group['id']}/members/{user_b}", headers=headers_b
    )
    assert removed.status_code == 200
    rotated = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()
    assert rotated["crypto_epoch"] == current["crypto_epoch"] + 1
    assert client.get(endpoint, headers=headers_b).status_code == 403
    assert client.get(endpoint, headers=headers_a).json()["items"] == []


def test_group_poll_fails_closed(client):
    headers, _ = _signup(client, "+22893000004")
    group = _create_group(client, headers, "no clear polls")
    response = client.post(
        "/api/v1/polls",
        json={
            "kind": "group",
            "target_id": group["id"],
            "question": "Should not persist",
            "options": ["yes", "no"],
        },
        headers=headers,
    )
    assert response.status_code == 409


def test_un_membre_sans_cle_ne_bloque_pas_les_messages_du_groupe(client):
    """Avant : un seul membre sans clé (application ancienne) empêchait tout
    envoi — les messages restaient « en attente d'envoi »."""
    headers_a, _ = _signup(client, "+22893000101")
    headers_b, user_b = _signup(client, "+22893000102")
    headers_c, user_c = _signup(client, "+22893000103")
    for phone, name in (("+22893000102", "B"), ("+22893000103", "C")):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers_a)
    group = client.post(
        "/api/v1/groups", json={"name": "trois", "member_user_ids": [user_b, user_c]}, headers=headers_a
    ).json()
    for headers in (headers_b, headers_c):
        for inv in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{inv['id']}/accept", headers=headers)
    epoch = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()["crypto_epoch"]

    # Clé envoyée à B seulement (C ne peut pas encore la recevoir).
    endpoint = f"/api/v1/groups/{group['id']}/sender-key-distributions"
    one = {"recipient_id": user_b, "encryption": "v1", "ciphertext": "x", "envelope": {"sid": "s"}}
    assert client.post(endpoint, json={"epoch": epoch, "distributions": [one]}, headers=headers_a).status_code == 200
    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"encryption": "sender-key-v1", "ciphertext": "c", "crypto_epoch": epoch},
        headers=headers_a,
    )
    assert sent.status_code == 200, sent.text

    # Une enveloppe renvoyée remplace l'ancienne (B a réinstallé).
    again = {**one, "ciphertext": "y"}
    client.post(endpoint, json={"epoch": epoch, "distributions": [again]}, headers=headers_a)
    item = client.get(endpoint, headers=headers_b).json()["items"][0]
    assert item["ciphertext"] == "y"


def _bundle():
    import base64
    import os

    def key(size=32):
        return base64.b64encode(os.urandom(size)).decode()

    return {
        "device_id": "device-x",
        "identity_key": key(),
        "signing_key": key(),
        "signed_prekey": key(),
        "signed_prekey_signature": key(64),
        "one_time_prekeys": [],
    }


def test_nouvel_appareil_la_cle_de_groupe_lui_est_redemandee(client):
    """Un membre qui change d'appareil ne peut plus ouvrir les clés scellées
    pour l'ancien : le serveur les efface, et l'expéditeur le voit manquant."""
    headers_a, _ = _signup(client, "+22893000011")
    headers_b, user_b = _signup(client, "+22893000012")
    client.post(
        "/api/v1/contacts",
        json={"phone": "+22893000012", "display_name": "B"},
        headers=headers_a,
    )
    group = client.post(
        "/api/v1/groups",
        json={"name": "appareils", "member_user_ids": [user_b]},
        headers=headers_a,
    ).json()
    invitation = client.get("/api/v1/groups/invitations", headers=headers_b).json()["items"][0]
    client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers_b)
    assert client.put("/api/v1/e2ee/bundle", json=_bundle(), headers=headers_b).status_code == 200
    epoch = client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()["crypto_epoch"]
    status = f"/api/v1/groups/{group['id']}/sender-key-distributions/status?epoch={epoch}"

    assert client.get(status, headers=headers_a).json()["missing"] == [user_b]
    client.post(
        f"/api/v1/groups/{group['id']}/sender-key-distributions",
        json={
            "epoch": epoch,
            "distributions": [
                {
                    "recipient_id": user_b,
                    "encryption": "v1",
                    "ciphertext": "pour-l-ancien-appareil",
                    "envelope": {"sid": "s"},
                }
            ],
        },
        headers=headers_a,
    )
    assert client.get(status, headers=headers_a).json()["missing"] == []

    # B se reconnecte sur un autre téléphone : nouvelle identité.
    assert client.put("/api/v1/e2ee/bundle", json=_bundle(), headers=headers_b).json()[
        "identity_changed"
    ]
    assert client.get(status, headers=headers_a).json()["missing"] == [user_b]


def test_une_ancienne_application_ne_peut_plus_ecrire_dans_un_groupe(client):
    headers, _ = _signup(client, "+22893000013")
    group = _create_group(client, headers)
    body = {
        "encryption": "sender-key-v1",
        "ciphertext": "opaque",
        "crypto_epoch": group["crypto_epoch"],
    }
    url = f"/api/v1/groups/{group['id']}/messages"
    old = client.post(url, json=body, headers={**headers, "User-Agent": "Dart/3.5 (dart:io)"})
    assert old.status_code == 426
    current = client.post(
        url,
        json=body,
        headers={**headers, "User-Agent": "Dart/3.9 (dart:io)", "X-Pokou-Crypto": "2"},
    )
    assert current.status_code == 200, current.text
