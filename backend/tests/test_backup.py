"""Sauvegarde chiffrée (MSG-12) : le serveur ne range qu'un bloc opaque."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

engine = create_engine("sqlite:///./test_pokou_backup.db", connect_args={"check_same_thread": False})
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
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}


def _upload(client, headers):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": "DOCUMENT"},
        files={"file": ("pokou-backup.bin", b"\x00chiffre", "application/octet-stream")},
        headers=headers,
    ).json()["id"]


def test_sauvegarde_puis_relecture(client):
    me = _signup(client, "+22890300001")
    assert client.get("/api/v1/backup", headers=me).json() == {"exists": False}
    media_id = _upload(client, me)
    saved = client.put(
        "/api/v1/backup",
        json={"media_id": media_id, "salt": "a" * 24, "iterations": 120000, "discussions": 12, "messages": 300},
        headers=me,
    ).json()
    assert saved["exists"] and saved["discussions"] == 12
    assert client.get("/api/v1/backup", headers=me).json()["media_id"] == media_id
    # Le bloc ne se lit que par son auteur.
    other = _signup(client, "+22890300002")
    assert client.get(f"/api/v1/media/{media_id}", headers=other).status_code in (403, 404)


def test_on_ne_pointe_pas_sa_sauvegarde_sur_le_fichier_d_un_autre(client):
    me = _signup(client, "+22890300003")
    other = _signup(client, "+22890300004")
    foreign = _upload(client, other)
    refused = client.put(
        "/api/v1/backup", json={"media_id": foreign, "salt": "b" * 24, "iterations": 120000}, headers=me
    )
    assert refused.status_code == 403
