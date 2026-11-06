"""REG-4 (changer de numéro) et REG-6 (code PIN oublié)."""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Contact, PhoneOTP, User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_phone_change.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
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


def _code_for(client, url, json, headers=None):
    # Simule l'attente entre deux demandes : les limites de débit par
    # numéro ne sont pas le sujet de ces tests.
    with TestingSessionLocal() as db:
        db.query(PhoneOTP).delete()
        db.commit()
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        response = client.post(url, json=json, headers=headers)
    assert response.status_code == 200, response.text
    return re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)


def _login(client, phone):
    code = _code_for(client, "/api/v1/auth/phone/request-otp", {"phone": phone})
    return client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()


def _signup(client, phone):
    body = _login(client, phone)
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


# ── REG-4 ────────────────────────────────────────────────────────────────


def test_changer_de_numero_garde_le_compte_et_previent_qui_on_choisit(client):
    moi, moi_id = _signup(client, "+22890000301")
    ami, _ = _signup(client, "+22890000302")
    lointain, _ = _signup(client, "+22890000303")
    # L'ami et le lointain m'ont dans leur carnet ; je n'ai écrit qu'à l'ami.
    for headers in (ami, lointain):
        client.post("/api/v1/contacts/sync", json={"contacts": [{"phone": "+22890000301", "name": "Moi"}]}, headers=headers)
    with TestingSessionLocal() as db:
        ami_id = db.query(User.id).filter(User.phone == "+22890000302").scalar()
    client.post("/api/v1/contacts", json={"phone": "+22890000302", "display_name": "Ami"}, headers=moi)
    client.post("/api/v1/messages", json={"recipient_id": ami_id, "content": "salut"}, headers=moi)

    code = _code_for(client, "/api/v1/account/phone/change/request", {"new_phone": "+22890000399"}, moi)
    wrong = client.post(
        "/api/v1/account/phone/change/confirm",
        json={"new_phone": "+22890000399", "code": "000000", "notify": "chatted"},
        headers=moi,
    )
    assert wrong.status_code == 400
    done = client.post(
        "/api/v1/account/phone/change/confirm",
        json={"new_phone": "+22890000399", "code": code, "notify": "chatted"},
        headers=moi,
    )
    assert done.status_code == 200, done.text
    assert done.json()["phone"] == "+22890000399"

    with TestingSessionLocal() as db:
        me = db.query(User).filter(User.id == moi_id).one()
        assert me.phone == "+22890000399"
        # Aucun second compte n'a été ouvert pour le nouveau numéro.
        assert db.query(User).filter(User.phone == "+22890000399").count() == 1
        fiches = {
            c.owner_user_id: c.phone
            for c in db.query(Contact).filter(Contact.contact_user_id == moi_id)
        }
    assert fiches[ami_id] == "+22890000399"  # prévenu : a discuté avec moi
    assert "+22890000301" in fiches.values()  # le lointain garde l'ancien

    # Le compte suit : on se reconnecte avec le nouveau numéro.
    assert _login(client, "+22890000399")["user"]["id"] == moi_id


def test_on_ne_prend_pas_le_numero_d_un_autre_compte(client):
    moi, _ = _signup(client, "+22890000311")
    _signup(client, "+22890000312")
    taken = client.post(
        "/api/v1/account/phone/change/request",
        json={"new_phone": "+22890000312"},
        headers=moi,
    )
    assert taken.status_code == 409


# ── REG-6 ────────────────────────────────────────────────────────────────


def _with_pin(client, phone):
    headers, user_id = _signup(client, phone)
    assert client.post("/api/v1/account-privacy/two-step", json={"pin": "123456"}, headers=headers).status_code == 200
    return user_id


def test_pin_oublie_se_leve_apres_sept_jours_seulement(client):
    user_id = _with_pin(client, "+22890000321")
    pending = _login(client, "+22890000321")
    assert pending["two_step_required"] is True

    asked = client.post(
        "/api/v1/auth/phone/two-step/forgot",
        json={"verification_token": pending["verification_token"]},
    )
    assert asked.status_code == 200, asked.text

    # Avant le délai : le code PIN est toujours exigé.
    assert _login(client, "+22890000321")["two_step_required"] is True

    with TestingSessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).one()
        user.two_step_reset_requested_at = datetime.utcnow() - timedelta(days=7, minutes=1)
        db.commit()

    # Après : le code SMS seul suffit, et le PIN est retiré.
    after = _login(client, "+22890000321")
    assert after.get("access_token"), after
    with TestingSessionLocal() as db:
        assert db.query(User.two_step_pin_hash).filter(User.id == user_id).scalar() is None


def test_une_connexion_avec_le_pin_annule_la_demande(client):
    user_id = _with_pin(client, "+22890000331")
    pending = _login(client, "+22890000331")
    client.post("/api/v1/auth/phone/two-step/forgot", json={"verification_token": pending["verification_token"]})

    again = _login(client, "+22890000331")
    ok = client.post(
        "/api/v1/auth/phone/two-step",
        json={"verification_token": again["verification_token"], "pin": "123456"},
    )
    assert ok.status_code == 200, ok.text
    with TestingSessionLocal() as db:
        assert db.query(User.two_step_reset_requested_at).filter(User.id == user_id).scalar() is None
