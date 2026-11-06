"""Reçus de nouvel essai : un message illisible est re-livré par l'expéditeur."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DirectMessage
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_e2ee_retry.db"
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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def test_un_message_illisible_est_reliv_re_par_l_expediteur(client):
    alice, alice_id = _signup(client, "+22890000701")
    bob, bob_id = _signup(client, "+22890000702")
    _, eve_id = _signup(client, "+22890000703")
    with TestingSessionLocal() as db:
        msg = DirectMessage(sender_id=alice_id, recipient_id=bob_id, encryption="v1", ciphertext="x", envelope={})
        db.add(msg)
        db.commit()
        message_id = msg.id

    # Seul le destinataire peut demander.
    assert client.post("/api/v1/e2ee/retries", json={"kind": "direct", "message_id": message_id}, headers=alice).status_code == 404
    asked = client.post("/api/v1/e2ee/retries", json={"kind": "direct", "message_id": message_id}, headers=bob).json()
    assert asked["status"] == "PENDING" and asked["sender_id"] == alice_id

    todo = client.get("/api/v1/e2ee/retries", headers=alice).json()["to_fulfill"]
    assert [t["id"] for t in todo] == [asked["id"]]
    # Rien en clair n'est accepté.
    assert client.post(f"/api/v1/e2ee/retries/{asked['id']}/fulfill", json={"ciphertext": "clair"}, headers=alice).status_code == 400
    done = client.post(
        f"/api/v1/e2ee/retries/{asked['id']}/fulfill",
        json={"encryption": "v1", "ciphertext": "rescelle", "envelope": {"sid": "s"}},
        headers=alice,
    )
    assert done.json()["status"] == "DELIVERED"

    to_open = client.get("/api/v1/e2ee/retries", headers=bob).json()["to_open"]
    assert to_open[0]["ciphertext"] == "rescelle"
    assert client.post(f"/api/v1/e2ee/retries/{asked['id']}/ack", headers=bob).json()["status"] == "DONE"
    assert client.get("/api/v1/e2ee/retries", headers=bob).json()["to_open"] == []
    assert eve_id  # un tiers n'a rien vu passer
