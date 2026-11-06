"""Baba répond — par un modèle de langage s'il y en a un, sinon par la FAQ."""
import re
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service
from app.services.baba import baba_service

TEST_DATABASE_URL = "sqlite:///./test_baba.db"
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


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}


def test_sans_modele_baba_repond_par_la_faq(client):
    me = _signup(client, "+22890000501")
    with patch.object(baba_service, "_providers", return_value=[]):
        sent = client.post("/api/v1/baba/messages", json={"text": "Pokou touche-t-il mon argent ?"}, headers=me)
    assert sent.status_code == 200, sent.text
    items = sent.json()["items"]
    assert [i["direction"] for i in items] == ["in", "out"]
    assert "wallet" in items[1]["body"]
    assert sent.json()["provider"] == "faq"
    thread = client.get("/api/v1/baba/thread", headers=me).json()["items"]
    assert len(thread) == 2


def test_baba_utilise_le_premier_modele_qui_repond(client):
    me = _signup(client, "+22890000502")
    broken = AsyncMock(side_effect=RuntimeError("quota"))
    working = AsyncMock(return_value="Bonjour, je suis Baba.")
    with patch.object(baba_service, "_providers", return_value=[("gemini", broken), ("groq", working)]):
        sent = client.post("/api/v1/baba/messages", json={"text": "Salut"}, headers=me)
    assert sent.json()["provider"] == "groq"
    assert sent.json()["items"][1]["body"] == "Bonjour, je suis Baba."
    # La consigne système part en tête, et seul ce fil sert de contexte.
    messages = working.await_args.args[0]
    assert messages[0]["role"] == "system" and "Baba" in messages[0]["content"]
    assert messages[-1] == {"role": "user", "content": "Salut"}


def test_status_au_format_attendu_par_l_application(client):
    me = _signup(client, "+22890000503")
    status = client.get("/api/v1/baba/status", headers=me).json()
    assert status["mode"] == "messaging" and status["monitors"] == []
