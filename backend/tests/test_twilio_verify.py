"""Codes de connexion par Twilio Verify : Twilio génère, envoie et vérifie
le code ; Pokou garde la limite de débit et le verrouillage. Twilio est
simulé — aucun appel réseau."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from unittest.mock import MagicMock, patch

from app.core.database import Base, get_db
from app.main import app
from app.models import PhoneOTP
from app.services.auth import otp_service, twilio_verify

engine = create_engine("sqlite:///./test_pokou_verify.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


class FakeTwilio:
    """Le strict nécessaire de l'API Verify : un code par numéro."""

    def __init__(self, fail_start=False, down=False):
        self.codes = {}
        self.started = []
        self.fail_start = fail_start
        self.down = down

    def _resp(self, status, body):
        r = MagicMock()
        r.status_code = status
        r.json.return_value = body
        r.raise_for_status.side_effect = None if status < 400 else Exception(f"HTTP {status}")
        return r

    def post(self, url, data=None, auth=None, timeout=None):
        if self.down:
            raise ConnectionError("Twilio injoignable")
        if url.endswith("/Verifications"):
            if self.fail_start:
                return self._resp(400, {"code": 60200, "message": "Invalid parameter"})
            self.codes[data["To"]] = "424242"
            self.started.append((data["To"], data["Channel"]))
            return self._resp(201, {"status": "pending"})
        if url.endswith("/VerificationCheck"):
            code = self.codes.get(data["To"])
            if code is None:
                return self._resp(404, {"code": 20404})
            if data["Code"] == code:
                del self.codes[data["To"]]
                return self._resp(200, {"status": "approved"})
            return self._resp(200, {"status": "pending"})
        raise AssertionError(url)


@pytest.fixture
def client(monkeypatch):
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _db
    monkeypatch.setattr(twilio_verify, "configured", lambda: True)
    monkeypatch.setattr(twilio_verify, "service_sid", lambda db: "VA_test")
    yield TestClient(app)
    if previous is None:
        app.dependency_overrides.pop(get_db, None)
    else:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _request(client, phone, **body):
    return client.post("/api/v1/auth/phone/request-otp", json={"phone": phone, **body})


def test_le_code_part_par_twilio_verify_et_s_y_verifie(client):
    fake = FakeTwilio()
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post), \
         patch.object(otp_service.sms_service, "send_sms") as sms:
        assert _request(client, "+22890700001").status_code == 200
        sms.assert_not_called()  # pas de SMS maison : Twilio s'en charge
        assert fake.started == [("+22890700001", "sms")]

        wrong = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700001", "code": "000000"})
        assert wrong.status_code == 400
        assert "4 essais" in wrong.json()["detail"]

        ok = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700001", "code": "424242"})
        assert ok.status_code == 200, ok.text
        assert ok.json()["access_token"]

    with TestingSessionLocal() as db:
        row = db.query(PhoneOTP).filter(PhoneOTP.phone == "+22890700001").one()
        assert row.code_hash == otp_service.VERIFY_MARKER  # Pokou ne connaît pas le code
        assert row.consumed_at is not None


def test_le_renvoi_par_whatsapp_passe_par_verify(client):
    fake = FakeTwilio()
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post):
        assert _request(client, "+22890700002", channel="whatsapp").status_code == 200
    assert fake.started == [("+22890700002", "whatsapp")]


def test_si_verify_refuse_l_envoi_le_code_pokou_part_par_sms(client):
    fake = FakeTwilio(fail_start=True)
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post), \
         patch.object(otp_service.sms_service, "send_sms", return_value=True) as sms:
        assert _request(client, "+22890700003", channel="sms").status_code == 200
    assert sms.call_count == 1
    import re
    code = re.search(r"\b(\d{6})\b", sms.call_args.args[2]).group(1)
    ok = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700003", "code": code})
    assert ok.status_code == 200, ok.text


def test_twilio_injoignable_a_la_verification_ne_compte_pas_comme_une_erreur(client):
    fake = FakeTwilio()
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post):
        _request(client, "+22890700004")
    fake.down = True
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post):
        r = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700004", "code": "424242"})
    assert r.status_code == 400
    with TestingSessionLocal() as db:
        assert db.query(PhoneOTP).filter(PhoneOTP.phone == "+22890700004").one().attempts == 0


def test_cinq_erreurs_verrouillent_le_numero_meme_avec_verify(client):
    fake = FakeTwilio()
    with patch.object(twilio_verify.httpx, "post", side_effect=fake.post):
        _request(client, "+22890700005")
        for _ in range(5):
            r = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700005", "code": "111111"})
        assert r.status_code == 429
        # Même le bon code ne passe plus : le verrou est le nôtre.
        r = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890700005", "code": "424242"})
        assert r.status_code == 429
