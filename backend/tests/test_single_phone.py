"""Un seul téléphone par compte : se connecter depuis l'application ferme
les sessions des autres téléphones, pas celles du web ni de la console."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DeviceToken, User, UserRole
from app.services.auth import otp_service
from tests.helpers import console_bearer

engine = create_engine("sqlite:///./test_pokou_single_phone.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

APP = {"X-Pokou-Crypto": "2"}


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


def _login(client, phone, headers=None):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone}, headers=headers or {})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}, headers=headers or {}
    ).json()
    client.cookies.clear()
    return body


def _bearer(body):
    return {"Authorization": f"Bearer {body['access_token']}"}


def test_un_nouveau_telephone_deconnecte_l_ancien(client):
    old = _login(client, "+22890600001", APP)
    assert client.get("/api/v1/auth/me", headers=_bearer(old)).status_code == 200
    with TestingSessionLocal() as db:
        db.add(DeviceToken(user_id=old["user"]["id"], token="fcm-ancien", platform="android"))
        db.commit()

    new = _login(client, "+22890600001", APP)

    assert client.get("/api/v1/auth/me", headers=_bearer(new)).status_code == 200
    # L'ancien téléphone : session fermée, impossible à prolonger, et il ne
    # sonne plus.
    assert client.get("/api/v1/auth/me", headers=_bearer(old)).status_code == 401
    refreshed = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {old['refresh_token']}"}
    )
    assert refreshed.status_code in (401, 403)
    with TestingSessionLocal() as db:
        assert db.query(DeviceToken).filter(DeviceToken.token == "fcm-ancien").count() == 0


def test_le_web_et_la_console_ne_sont_pas_fermes(client):
    web = _login(client, "+22890600002")  # officine : pas d'en-tête de l'app
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == web["user"]["id"]).update({User.role: UserRole.ADMIN})
        db.commit()
    console = console_bearer(TestingSessionLocal, web["user"]["id"])

    _login(client, "+22890600002", APP)

    assert client.get("/api/v1/auth/me", headers=_bearer(web)).status_code == 200
    assert client.get("/api/v1/admin/me", headers=console).status_code == 200


def test_une_connexion_web_ne_deconnecte_pas_le_telephone(client):
    phone = _login(client, "+22890600003", APP)
    _login(client, "+22890600003")
    assert client.get("/api/v1/auth/me", headers=_bearer(phone)).status_code == 200


def test_la_session_garde_son_type_apres_rafraichissement(client):
    """Sinon, au premier rafraîchissement, le téléphone deviendrait une
    session « inconnue » — et la règle ne le reconnaîtrait plus."""
    first = _login(client, "+22890600004", APP)
    rotated = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {first['refresh_token']}", **APP}
    ).json()
    _login(client, "+22890600004", APP)
    assert client.get("/api/v1/auth/me", headers=_bearer(rotated)).status_code == 401
