"""Le créateur supprime son groupe — et lui seul."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Group, GroupMember, GroupMessage
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_group_delete.db"
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


def _group_with_member(client):
    owner, _ = _signup(client, "+22890000401")
    member, member_id = _signup(client, "+22890000402")
    client.post("/api/v1/contacts", json={"phone": "+22890000402", "display_name": "M"}, headers=owner)
    group = client.post("/api/v1/groups", json={"name": "carttel", "member_user_ids": [member_id]}, headers=owner).json()
    for inv in client.get("/api/v1/groups/invitations", headers=member).json()["items"]:
        client.post(f"/api/v1/groups/invitations/{inv['id']}/accept", headers=member)
    current = client.get(f"/api/v1/groups/{group['id']}", headers=owner).json()
    client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"encryption": "sender-key-v1", "ciphertext": "x", "crypto_epoch": current["crypto_epoch"]},
        headers=owner,
    )
    return owner, member, group["id"]


def test_seul_le_createur_supprime_le_groupe(client):
    owner, member, group_id = _group_with_member(client)

    refused = client.delete(f"/api/v1/groups/{group_id}", headers=member)
    assert refused.status_code == 403

    done = client.delete(f"/api/v1/groups/{group_id}", headers=owner)
    assert done.status_code == 200, done.text
    with TestingSessionLocal() as db:
        assert db.query(Group).filter(Group.id == group_id).count() == 0
        assert db.query(GroupMember).filter(GroupMember.group_id == group_id).count() == 0
        assert db.query(GroupMessage).filter(GroupMessage.group_id == group_id).count() == 0
    assert client.get(f"/api/v1/groups/{group_id}", headers=member).status_code in (403, 404)


def test_un_groupe_en_mode_preuve_ne_se_supprime_pas(client):
    owner, _, group_id = _group_with_member(client)
    with TestingSessionLocal() as db:
        db.query(Group).filter(Group.id == group_id).update({"proof_mode": True})
        db.commit()
    assert client.delete(f"/api/v1/groups/{group_id}", headers=owner).status_code == 409
