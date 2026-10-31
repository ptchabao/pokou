"""Pokou — confidentialité du compte : accusés de lecture, vérification en
deux étapes, suppression du compte.

Ce qui est vérifié ici tient surtout à ce qui pourrait passer inaperçu tout
en vidant le réglage de son sens : la RÉCIPROCITÉ des accusés de lecture
(sans elle, le réglage est un cadeau à sens unique), le fait que le code du
compte ne ressorte JAMAIS de l'API, et le périmètre exact de la suppression
(ce qui est effacé, ce qui est anonymisé, ce qui reste chez les autres).
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Contact, DeviceToken, DirectMessage, User
from app.api.v1.account import account_privacy
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_account_privacy.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

BASE = "/api/v1/account-privacy"


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
    # Le compteur d'échecs du code en deux étapes vit en mémoire du module et
    # survit donc au drop_all : comme les ids repartent de 1 à chaque test, un
    # compteur oublié se rattacherait à l'utilisateur d'un AUTRE test et le
    # ferait échouer en 429 sans rapport.
    account_privacy._two_step_failures.clear()
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    account_privacy._two_step_failures.clear()
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _delete(client, path, headers, payload):
    """httpx ne laisse pas passer de corps sur `.delete()` — il faut
    `.request()`. Les routes concernées exigent bien un corps (numéro retapé,
    code actuel) : c'est le garde-fou lui-même."""
    return client.request("DELETE", path, json=payload, headers=headers)


def _enable_two_step(client, headers, pin="123456"):
    response = client.post(f"{BASE}/two-step", json={"pin": pin}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


# ─── Accusés de lecture ───────────────────────────────────────────────────────

def test_read_receipts_are_on_by_default_and_can_be_turned_off(client):
    headers, _ = _signup(client, "+228898000111")

    assert client.get(f"{BASE}/read-receipts", headers=headers).json()["enabled"] is True

    updated = client.put(f"{BASE}/read-receipts", json={"enabled": False}, headers=headers)
    assert updated.status_code == 200, updated.text
    assert updated.json()["enabled"] is False
    assert client.get(f"{BASE}/read-receipts", headers=headers).json()["enabled"] is False


def test_read_receipts_reciprocity_cuts_both_ways(client):
    """Le cœur du réglage : couper ses accusés prive AUSSI de ceux des autres.
    Sans ce sens-là, on saurait quand on est lu sans jamais dire quand on
    lit — et la fonctionnalité perdrait sa raison d'être."""
    headers_a, user_id_a = _signup(client, "+228898000112")
    headers_b, user_id_b = _signup(client, "+228898000113")

    db = TestingSessionLocal()
    try:
        # Les deux activés : chacun voit ceux de l'autre.
        assert account_privacy.read_receipts_visible_between(db, user_id_a, user_id_b) is True
        assert account_privacy.read_receipts_visible_between(db, user_id_b, user_id_a) is True

        client.put(f"{BASE}/read-receipts", json={"enabled": False}, headers=headers_a)
        db.expire_all()

        # Sens 1 : A ne reçoit plus les accusés de B.
        assert account_privacy.read_receipts_visible_between(db, user_id_a, user_id_b) is False
        # Sens 2 : et B ne reçoit plus ceux de A, même en les ayant gardés.
        assert account_privacy.read_receipts_visible_between(db, user_id_b, user_id_a) is False

        # Réactiver rétablit les deux sens.
        client.put(f"{BASE}/read-receipts", json={"enabled": True}, headers=headers_a)
        db.expire_all()
        assert account_privacy.read_receipts_visible_between(db, user_id_a, user_id_b) is True
        assert account_privacy.read_receipts_visible_between(db, user_id_b, user_id_a) is True
    finally:
        db.close()


def test_read_receipts_are_never_hidden_from_myself(client):
    headers, user_id = _signup(client, "+228898000114")
    client.put(f"{BASE}/read-receipts", json={"enabled": False}, headers=headers)

    db = TestingSessionLocal()
    try:
        assert account_privacy.read_receipts_visible_between(db, user_id, user_id) is True
    finally:
        db.close()


def test_read_receipts_of_an_unknown_account_are_not_assumed(client):
    """Un compte introuvable (supprimé entre-temps) ne doit pas hériter du
    défaut « activés » : on se taît."""
    _, user_id = _signup(client, "+228898000115")

    db = TestingSessionLocal()
    try:
        assert account_privacy.read_receipts_visible_between(db, user_id, 999_999) is False
    finally:
        db.close()


# ─── Vérification en deux étapes ──────────────────────────────────────────────

def test_the_pin_never_leaves_the_api_in_any_form(client):
    """Ni en clair, ni haché : un haché sorti de la base se casse hors ligne,
    là où aucun compteur d'échecs ne gêne."""
    headers, user_id = _signup(client, "+228898000116")

    enabled = _enable_two_step(client, headers, "482913")
    state = client.get(f"{BASE}/two-step", headers=headers)

    db = TestingSessionLocal()
    try:
        stored_hash = db.query(User.two_step_pin_hash).filter(User.id == user_id).scalar()
    finally:
        db.close()
    assert stored_hash and stored_hash != "482913"

    for body in (enabled, state.json()):
        serialized = str(body)
        assert "482913" not in serialized
        assert stored_hash not in serialized
        assert "pin" not in serialized

    assert state.json() == {"enabled": True}


def test_two_step_is_off_until_it_is_enabled(client):
    headers, user_id = _signup(client, "+228898000117")

    assert client.get(f"{BASE}/two-step", headers=headers).json()["enabled"] is False
    db = TestingSessionLocal()
    try:
        assert account_privacy.two_step_required(db, user_id) is False
    finally:
        db.close()

    _enable_two_step(client, headers)

    assert client.get(f"{BASE}/two-step", headers=headers).json()["enabled"] is True
    db = TestingSessionLocal()
    try:
        # Ce que le flux de connexion interrogera après l'OTP.
        assert account_privacy.two_step_required(db, user_id) is True
    finally:
        db.close()


def test_a_pin_that_is_not_six_digits_is_refused(client):
    headers, _ = _signup(client, "+228898000118")

    for bad in ("123", "abcdef", "12345", "12345a", "1234567", "", "  "):
        response = client.post(f"{BASE}/two-step", json={"pin": bad}, headers=headers)
        assert response.status_code == 400, f"{bad!r} → {response.status_code}"

    assert client.get(f"{BASE}/two-step", headers=headers).json()["enabled"] is False


def test_enabling_twice_is_a_state_conflict(client):
    headers, _ = _signup(client, "+228898000119")
    _enable_two_step(client, headers)

    response = client.post(f"{BASE}/two-step", json={"pin": "654321"}, headers=headers)
    assert response.status_code == 409


def test_changing_the_pin_requires_the_current_one(client):
    """Un téléphone déverrouillé laissé sur une table suffirait sinon à
    remplacer le code du compte, donc à s'en emparer."""
    headers, _ = _signup(client, "+228898000120")
    _enable_two_step(client, headers, "111111")

    missing = client.put(f"{BASE}/two-step", json={"new_pin": "222222"}, headers=headers)
    assert missing.status_code == 400

    wrong = client.put(
        f"{BASE}/two-step",
        json={"current_pin": "999999", "new_pin": "222222"},
        headers=headers,
    )
    assert wrong.status_code == 403

    # Le code n'a pas bougé.
    assert client.post(f"{BASE}/two-step/verify", json={"pin": "111111"}, headers=headers).status_code == 200

    account_privacy._two_step_failures.clear()
    changed = client.put(
        f"{BASE}/two-step",
        json={"current_pin": "111111", "new_pin": "222222"},
        headers=headers,
    )
    assert changed.status_code == 200
    assert client.post(f"{BASE}/two-step/verify", json={"pin": "222222"}, headers=headers).status_code == 200
    assert client.post(f"{BASE}/two-step/verify", json={"pin": "111111"}, headers=headers).status_code == 403


def test_disabling_requires_the_current_pin(client):
    """Désactiver, c'est retirer la protection : c'est l'opération la plus
    intéressante pour qui n'est pas le propriétaire du compte."""
    headers, _ = _signup(client, "+228898000121")
    _enable_two_step(client, headers, "333333")

    missing = _delete(client, f"{BASE}/two-step", headers, {})
    assert missing.status_code == 400

    wrong = _delete(client, f"{BASE}/two-step", headers, {"current_pin": "444444"})
    assert wrong.status_code == 403
    assert client.get(f"{BASE}/two-step", headers=headers).json()["enabled"] is True

    account_privacy._two_step_failures.clear()
    removed = _delete(client, f"{BASE}/two-step", headers, {"current_pin": "333333"})
    assert removed.status_code == 200
    assert client.get(f"{BASE}/two-step", headers=headers).json()["enabled"] is False


def test_verifying_or_changing_without_two_step_enabled_is_a_conflict(client):
    headers, _ = _signup(client, "+228898000122")

    assert client.post(f"{BASE}/two-step/verify", json={"pin": "123456"}, headers=headers).status_code == 409
    assert client.put(
        f"{BASE}/two-step", json={"current_pin": "123456", "new_pin": "654321"}, headers=headers
    ).status_code == 409
    assert _delete(client, f"{BASE}/two-step", headers, {"current_pin": "123456"}).status_code == 409


def test_five_failures_then_the_pin_is_refused_for_a_while(client):
    headers, _ = _signup(client, "+228898000123")
    _enable_two_step(client, headers, "555555")

    for attempt in range(5):
        response = client.post(f"{BASE}/two-step/verify", json={"pin": "000000"}, headers=headers)
        assert response.status_code == 403, f"tentative {attempt} → {response.status_code}"

    throttled = client.post(f"{BASE}/two-step/verify", json={"pin": "000000"}, headers=headers)
    assert throttled.status_code == 429

    # Même le BON code est refusé pendant la pénalité — sinon la limite ne
    # servirait à rien contre qui finit par tomber juste.
    assert client.post(f"{BASE}/two-step/verify", json={"pin": "555555"}, headers=headers).status_code == 429

    # Et la même pénalité couvre le changement/la désactivation, qui seraient
    # sinon un oracle de devinage à volume illimité.
    assert client.put(
        f"{BASE}/two-step", json={"current_pin": "000000", "new_pin": "111111"}, headers=headers
    ).status_code == 429


def test_a_successful_verification_clears_the_failure_counter(client):
    headers, _ = _signup(client, "+228898000124")
    _enable_two_step(client, headers, "666666")

    for _ in range(4):
        assert client.post(f"{BASE}/two-step/verify", json={"pin": "000000"}, headers=headers).status_code == 403

    assert client.post(f"{BASE}/two-step/verify", json={"pin": "666666"}, headers=headers).status_code == 200

    # Le compteur est reparti de zéro : quatre échecs de plus restent des 403.
    for _ in range(4):
        assert client.post(f"{BASE}/two-step/verify", json={"pin": "000000"}, headers=headers).status_code == 403


# ─── Suppression de compte ────────────────────────────────────────────────────

def test_deletion_is_refused_when_the_retyped_phone_does_not_match(client):
    headers, user_id = _signup(client, "+228898000125")

    refused = _delete(client, f"{BASE}/account", headers, {"confirm_phone": "+228898000199"})
    assert refused.status_code == 400

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        assert user.phone == "+228898000125"
        assert user.is_active is True
    finally:
        db.close()


def test_deletion_clears_the_identity_and_the_device_tokens(client):
    headers, user_id = _signup(client, "+228898000126")
    client.put("/api/v1/users/me/profile", json={"full_name": "Kodjo"}, headers=headers)
    client.post("/api/v1/devices/register", json={"token": "fcm-jeton-de-test"}, headers=headers)
    client.post(
        "/api/v1/contacts", json={"phone": "+228898000127", "display_name": "Ami"}, headers=headers
    )

    removed = _delete(client, f"{BASE}/account", headers, {"confirm_phone": "+228898000126"})
    assert removed.status_code == 200, removed.text
    recap = removed.json()
    assert recap["deleted"] is True
    assert recap["removed"]["device_tokens"] == 1
    assert recap["removed"]["contacts"] == 1

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        # La LIGNE survit (des messages reçus par d'autres la référencent par
        # une clé étrangère non nulle) mais plus rien n'y identifie personne.
        assert user is not None
        assert user.phone is None
        assert user.full_name is None
        assert user.is_active is False
        assert user.two_step_pin_hash is None
        assert db.query(DeviceToken).filter(DeviceToken.user_id == user_id).count() == 0
        assert db.query(Contact).filter(Contact.owner_user_id == user_id).count() == 0
    finally:
        db.close()


def test_a_deleted_account_can_no_longer_be_used_and_frees_its_number(client):
    headers, user_id = _signup(client, "+228898000128")
    _delete(client, f"{BASE}/account", headers, {"confirm_phone": "+228898000128"})

    # La session est révoquée : le jeton d'accès ne vaut plus rien.
    assert client.get(f"{BASE}/two-step", headers=headers).status_code in (401, 403)

    # Le numéro est libre, et s'y réinscrire donne un compte NEUF plutôt que
    # de ressusciter l'ancien.
    new_headers, new_user_id = _signup(client, "+228898000128")
    assert new_user_id != user_id
    assert client.get(f"{BASE}/two-step", headers=new_headers).json()["enabled"] is False


def test_deletion_keeps_the_messages_already_received_by_others(client):
    """On ne peut pas effacer un message reçu : ici une seule ligne sert les
    deux côtés de la conversation, donc l'effacer effacerait aussi le message
    de l'autre personne."""
    headers_a, user_id_a = _signup(client, "+228898000129")
    headers_b, user_id_b = _signup(client, "+228898000130")
    client.post(
        "/api/v1/contacts", json={"phone": "+228898000130", "display_name": "B"}, headers=headers_a
    )
    client.post(
        "/api/v1/contacts", json={"phone": "+228898000129", "display_name": "A"}, headers=headers_b
    )
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "bonjour"}, headers=headers_a
    )
    assert sent.status_code == 200, sent.text

    removed = _delete(client, f"{BASE}/account", headers_a, {"confirm_phone": "+228898000129"})
    assert removed.status_code == 200, removed.text
    assert removed.json()["kept"]["direct_messages"] == 1

    db = TestingSessionLocal()
    try:
        message = db.query(DirectMessage).filter(DirectMessage.recipient_id == user_id_b).first()
        assert message is not None
        assert message.content == "bonjour"
        # Le carnet d'adresses de B reste le sien, mais le lien vers un
        # compte mort est coupé : sinon son app croirait pouvoir écrire encore.
        contact = db.query(Contact).filter(Contact.owner_user_id == user_id_b).first()
        assert contact is not None
        assert contact.contact_user_id is None
    finally:
        db.close()


# ─── Authentification ────────────────────────────────────────────────────────

def test_every_endpoint_requires_authentication(client):
    assert client.get(f"{BASE}/read-receipts").status_code in (401, 403)
    assert client.put(f"{BASE}/read-receipts", json={"enabled": False}).status_code in (401, 403)
    assert client.get(f"{BASE}/two-step").status_code in (401, 403)
    assert client.post(f"{BASE}/two-step", json={"pin": "123456"}).status_code in (401, 403)
    assert client.post(f"{BASE}/two-step/verify", json={"pin": "123456"}).status_code in (401, 403)
    assert client.request(
        "DELETE", f"{BASE}/account", json={"confirm_phone": "+228898000131"}
    ).status_code in (401, 403)


# ─── Seconde étape à la CONNEXION (branchement dans auth.py) ─────────────────

def _request_and_extract_code(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        assert client.post("/api/v1/auth/phone/request-otp", json={"phone": phone}).status_code == 200
    return re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)


def test_login_without_two_step_still_returns_a_session_directly(client):
    """Non-régression : le compte sans code du compte se connecte comme avant."""
    phone = "+22898000190"
    code = _request_and_extract_code(client, phone)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    assert body.get("access_token")
    assert "two_step_required" not in body


def test_otp_alone_no_longer_opens_a_session_when_two_step_is_on(client):
    """Le point de toute la fonctionnalité : le SMS ne suffit plus."""
    phone = "+22898000191"
    headers, _ = _signup(client, phone)
    assert client.post(
        "/api/v1/account-privacy/two-step", json={"pin": "246810"}, headers=headers
    ).status_code in (200, 201)

    code = _request_and_extract_code(client, phone)
    response = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})

    assert response.status_code == 200
    body = response.json()
    assert body["two_step_required"] is True
    assert body["verification_token"]
    # Aucune session délivrée : sinon la seconde étape serait décorative.
    assert "access_token" not in body


def test_the_account_pin_completes_the_login(client):
    phone = "+22898000192"
    headers, _ = _signup(client, phone)
    client.post("/api/v1/account-privacy/two-step", json={"pin": "135790"}, headers=headers)

    code = _request_and_extract_code(client, phone)
    challenge = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()

    completed = client.post(
        "/api/v1/auth/phone/two-step",
        json={"verification_token": challenge["verification_token"], "pin": "135790"},
    )
    assert completed.status_code == 200, completed.text
    assert completed.json()["access_token"]

    # La session obtenue fonctionne vraiment.
    token = completed.json()["access_token"]
    assert client.get(
        "/api/v1/account-privacy/two-step", headers={"Authorization": f"Bearer {token}"}
    ).json() == {"enabled": True}


def test_a_wrong_account_pin_does_not_open_the_session(client):
    phone = "+22898000193"
    headers, _ = _signup(client, phone)
    client.post("/api/v1/account-privacy/two-step", json={"pin": "111222"}, headers=headers)

    code = _request_and_extract_code(client, phone)
    challenge = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()

    refused = client.post(
        "/api/v1/auth/phone/two-step",
        json={"verification_token": challenge["verification_token"], "pin": "999999"},
    )
    assert refused.status_code == 403
    assert "access_token" not in refused.json()


def test_an_access_token_cannot_be_used_as_a_two_step_pass(client):
    """Types de jeton distincts : un jeton d'accès normal ne doit pas valoir
    laissez-passer de seconde étape."""
    phone = "+22898000194"
    headers, _ = _signup(client, phone)
    client.post("/api/v1/account-privacy/two-step", json={"pin": "333444"}, headers=headers)
    stolen_access_token = headers["Authorization"].removeprefix("Bearer ")

    response = client.post(
        "/api/v1/auth/phone/two-step",
        json={"verification_token": stolen_access_token, "pin": "333444"},
    )
    assert response.status_code == 400


def test_login_attempts_share_the_lockout_with_the_settings_route(client):
    """Compteur partagé : sinon la route de connexion serait une porte de
    devinage sans limite alors que l'autre est protégée."""
    phone = "+22898000195"
    headers, _ = _signup(client, phone)
    client.post("/api/v1/account-privacy/two-step", json={"pin": "555666"}, headers=headers)

    code = _request_and_extract_code(client, phone)
    challenge = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    token = challenge["verification_token"]

    for _ in range(5):
        client.post("/api/v1/auth/phone/two-step", json={"verification_token": token, "pin": "000000"})

    # Épuisé côté connexion → la route de réglages refuse aussi.
    assert client.post(
        "/api/v1/account-privacy/two-step/verify", json={"pin": "555666"}, headers=headers
    ).status_code == 429
