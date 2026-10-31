"""La session ouverte par la connexion téléphone : révocable au logout, et
portée aussi par un cookie httpOnly pour les clients web (portail Business,
administration)."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_sessions.db"

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
    # Posé PAR TEST : pytest importe tous les fichiers avant d'en exécuter un,
    # un override au niveau module serait écrasé par le dernier importé.
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _login(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    return client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})


def test_logout_revokes_access_token(client):
    token = _login(client, "+22890000101").json()["access_token"]
    client.cookies.clear()
    headers = {"Authorization": f"Bearer {token}"}

    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 200
    # Le même jeton est désormais refusé : la ligne de session est révoquée.
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401


def test_login_sets_httponly_cookie(client):
    response = _login(client, "+22890000102")
    assert response.status_code == 200
    set_cookie = response.headers.get("set-cookie", "")
    assert "access_token=" in set_cookie
    assert "httponly" in set_cookie.lower()


def test_get_current_user_accepts_cookie_without_header(client):
    assert _login(client, "+22890000103").status_code == 200
    # Le TestClient garde les cookies d'une requête à l'autre.
    me = client.get("/api/v1/auth/me")
    assert me.status_code == 200
    assert me.json()["phone"] == "+22890000103"


def test_password_routes_do_not_exist(client):
    """Pokou n'a pas de mot de passe : seules les routes téléphone existent."""
    assert client.post("/api/v1/auth/login", json={"email": "a@b.c", "password": "x" * 8}).status_code in (404, 405)
    assert client.post("/api/v1/auth/register", json={"email": "a@b.c", "password": "x" * 8}).status_code in (404, 405)
