"""Pokou certifié et mode preuve."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.api.v1.certified.certified import names_match
from app.core.database import Base, get_db
from app.main import app
from app.models import MarketplacePayment, User
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import attach_payer_name, confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_pokou_certified.db"

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
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def stub_mobile_money():
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.side_effect = lambda db, **kw: {
            "order_reference": kw["merchant_reference"],
            "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


def _signup(client, phone, name=None):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    if name:
        client.patch("/api/v1/auth/me", json={"full_name": name}, headers=headers)
    return headers, body["user"]["id"]


def _pay(client, headers, payer_name, plan="PARTICULIER_MONTHLY"):
    payment = client.post("/api/v1/certified/subscribe", json={"plan": plan}, headers=headers).json()
    with TestingSessionLocal() as db:
        reference = db.query(MarketplacePayment).get(payment["payment_id"]).provider_reference
        attach_payer_name(db, reference, payer_name)
        db.commit()
    confirm_payment(TestingSessionLocal(), reference)
    return payment


def test_noms_compares_sans_accents_casse_ni_ordre():
    assert names_match("Kossi Amégan", "AMEGAN KOSSI")
    assert not names_match("Kossi Amégan", "AMEGAN Afi")
    assert not names_match("Kossi", None)


def test_offre_affiche_ht_et_ttc(client):
    headers, _ = _signup(client, "+22890200001")
    plans = {p["code"]: p for p in client.get("/api/v1/certified/offer", headers=headers).json()["plans"]}
    assert plans["PARTICULIER_MONTHLY"]["price_ht"] == 500
    assert plans["PARTICULIER_MONTHLY"]["price_ttc"] == 590
    assert plans["PARTICULIER_YEARLY"]["price_ht"] == 5000
    assert plans["PRO_MONTHLY"]["price_ht"] == 2500


def test_essai_ouvre_le_mode_preuve_sans_badge(client):
    headers, _ = _signup(client, "+22890200002", "Afi Mensah")
    status = client.post("/api/v1/certified/trial", headers=headers).json()
    assert status["status"] == "TRIAL"
    assert status["proof_mode_allowed"] is True
    assert status["badge_visible"] is False
    assert client.post("/api/v1/certified/trial", headers=headers).status_code == 409


def test_paiement_avec_noms_concordants_allume_le_badge(client):
    headers, user_id = _signup(client, "+22890200003", "Kossi Amégan")
    _pay(client, headers, "AMEGAN KOSSI")
    status = client.get("/api/v1/certified/me", headers=headers).json()
    assert status["status"] == "ACTIVE" and status["badge_visible"] is True
    with TestingSessionLocal() as db:
        assert db.query(User).get(user_id).is_verified is True


def test_noms_differents_sans_jamais_reveler_le_titulaire(client):
    headers, _ = _signup(client, "+22890200004", "King K")
    _pay(client, headers, "AMEGAN KOSSI")
    response = client.get("/api/v1/certified/me", headers=headers)
    status = response.json()
    assert status["status"] == "NAME_MISMATCH" and status["badge_visible"] is False
    assert "AMEGAN" not in response.text.upper()
    still = client.post("/api/v1/certified/resolve-name", json={"full_name": "Kossi Mensah"}, headers=headers)
    assert still.status_code == 422 and "AMEGAN" not in still.text.upper()
    resolved = client.post("/api/v1/certified/resolve-name", json={"full_name": "Kossi Amégan"}, headers=headers).json()
    assert resolved["status"] == "ACTIVE" and resolved["badge_visible"] is True


def _group_with_member(client):
    admin, admin_id = _signup(client, "+22890200010", "Admin")
    member, member_id = _signup(client, "+22890200011", "Membre")
    client.post("/api/v1/contacts", json={"phone": "+22890200011", "display_name": "Membre"}, headers=admin)
    group = client.post("/api/v1/groups", json={"name": "Tontine", "member_user_ids": [member_id]}, headers=admin).json()
    for invitation in client.get("/api/v1/groups/invitations", headers=member).json()["items"]:
        client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=member)
    return admin, member, group["id"]


def test_mode_preuve_reserve_aux_certifies(client):
    admin, _, group_id = _group_with_member(client)
    refused = client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": True}, headers=admin)
    assert refused.status_code == 403
    client.post("/api/v1/certified/trial", headers=admin)
    ok = client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": True}, headers=admin)
    assert ok.status_code == 200 and ok.json()["proof_mode"] is True


def _send_encrypted(client, group_id, sender, recipient_id, text="chiffre"):
    """Un message de groupe tel que l'app l'envoie : chiffré, après avoir
    remis sa clé d'expéditeur aux autres membres."""
    epoch = client.get(f"/api/v1/groups/{group_id}", headers=sender).json()["crypto_epoch"]
    client.post(
        f"/api/v1/groups/{group_id}/sender-key-distributions",
        json={"epoch": epoch, "distributions": [{
            "recipient_id": recipient_id, "encryption": "v1",
            "ciphertext": "cle", "envelope": {"sid": "s"},
        }]},
        headers=sender,
    )
    response = client.post(
        f"/api/v1/groups/{group_id}/messages",
        json={"encryption": "sender-key-v1", "ciphertext": text, "crypto_epoch": epoch},
        headers=sender,
    )
    assert response.status_code == 200, response.text
    return response.json()


def _admin_id(client, headers):
    return client.get("/api/v1/auth/me", headers=headers).json()["id"]


def test_en_mode_preuve_un_message_supprime_reste_visible(client):
    admin, member, group_id = _group_with_member(client)
    client.post("/api/v1/certified/trial", headers=admin)
    client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": True}, headers=admin)
    sent = _send_encrypted(client, group_id, member, _admin_id(client, admin), "Je paie demain (chiffré)")

    deleted = client.delete(f"/api/v1/groups/{group_id}/messages/{sent['id']}", headers=member).json()
    assert deleted["kept_as_proof"] is True

    messages = client.get(f"/api/v1/groups/{group_id}/messages", headers=admin).json()
    items = messages["items"] if isinstance(messages, dict) else messages
    kept = next(m for m in items if m["id"] == sent["id"])
    # Conservé, marqué supprimé — et toujours chiffré : le serveur garde la
    # trace sans pouvoir la lire.
    assert kept["deleted_at"] is not None and kept["content"] is None


def test_hors_mode_preuve_la_suppression_efface(client):
    admin, member, group_id = _group_with_member(client)
    sent = _send_encrypted(client, group_id, member, _admin_id(client, admin), "Oups")
    deleted = client.delete(f"/api/v1/groups/{group_id}/messages/{sent['id']}", headers=member).json()
    assert deleted["kept_as_proof"] is False
    messages = client.get(f"/api/v1/groups/{group_id}/messages", headers=admin).json()
    items = messages["items"] if isinstance(messages, dict) else messages
    assert all(m["id"] != sent["id"] for m in items)


def test_tout_titulaire_active_desactivation_reservee(client):
    admin, member, group_id = _group_with_member(client)
    # Un membre NON administrateur, en essai, peut activer.
    client.post("/api/v1/certified/trial", headers=member)
    assert client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": True}, headers=member).status_code == 200
    # Un administrateur en essai ne peut pas couper ce qu'un autre a activé.
    client.post("/api/v1/certified/trial", headers=admin)
    refused = client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": False}, headers=admin)
    assert refused.status_code == 403
    # La personne qui l'a activé, si.
    assert client.post(f"/api/v1/groups/{group_id}/proof-mode", json={"enabled": False}, headers=member).json()["proof_mode"] is False


def test_paiement_manque_grace_de_7_jours_puis_badge_en_pause():
    from datetime import datetime, timedelta

    from app.api.v1.certified.certified import refresh_status
    from app.models import CertifiedSubscription

    now = datetime(2026, 12, 10)
    sub = CertifiedSubscription(user_id=1, status="ACTIVE", current_period_end=datetime(2026, 11, 27))
    # Le 30 nov. : encore dans les 7 jours de grâce, le badge reste.
    assert refresh_status(sub, datetime(2026, 11, 30)) == "ACTIVE"
    # Après le 4 déc. : en pause (pas expiré : rien n'est effacé).
    assert refresh_status(sub, now) == "PAUSED"
    trial = CertifiedSubscription(user_id=2, status="TRIAL", trial_ends_at=now - timedelta(days=1))
    assert refresh_status(trial, now) == "EXPIRED"
