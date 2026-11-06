"""DIS-26 · Gérer le groupe : qui modifie le nom, approbation des entrées."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_group_settings.db"
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


def _group(client):
    owner, _ = _signup(client, "+22890000601")
    member, member_id = _signup(client, "+22890000602")
    client.post("/api/v1/contacts", json={"phone": "+22890000602", "display_name": "M"}, headers=owner)
    group = client.post("/api/v1/groups", json={"name": "Famille", "member_user_ids": [member_id]}, headers=owner).json()
    for inv in client.get("/api/v1/groups/invitations", headers=member).json()["items"]:
        client.post(f"/api/v1/groups/invitations/{inv['id']}/accept", headers=member)
    return owner, member, group["id"]


def test_un_membre_renomme_seulement_si_le_groupe_l_autorise(client):
    owner, member, gid = _group(client)
    assert client.patch(f"/api/v1/groups/{gid}", json={"name": "X"}, headers=member).status_code == 403

    on = client.patch(f"/api/v1/groups/{gid}", json={"members_can_edit_info": True}, headers=owner)
    assert on.status_code == 200 and on.json()["members_can_edit_info"] is True

    renamed = client.patch(f"/api/v1/groups/{gid}", json={"name": "Famille Koffi"}, headers=member)
    assert renamed.status_code == 200 and renamed.json()["name"] == "Famille Koffi"
    assert renamed.json()["can_edit_info"] is True
    # Les réglages, eux, restent aux administrateurs.
    assert client.patch(f"/api/v1/groups/{gid}", json={"admins_only_messages": True}, headers=member).status_code == 403


def test_une_entree_par_lien_attend_l_approbation(client):
    owner, _, gid = _group(client)
    client.patch(f"/api/v1/groups/{gid}", json={"join_approval": True}, headers=owner)
    code = client.post(f"/api/v1/groups/{gid}/invite-link", headers=owner).json()["invite_code"]
    newcomer, newcomer_id = _signup(client, "+22890000603")

    asked = client.post(f"/api/v1/groups/invite/{code}/join", headers=newcomer)
    assert asked.status_code == 202 and asked.json()["pending_approval"] is True
    assert client.get(f"/api/v1/groups/{gid}", headers=newcomer).status_code in (403, 404)

    pending = client.get(f"/api/v1/groups/{gid}/join-requests", headers=owner).json()["items"]
    assert [p["user_id"] for p in pending] == [newcomer_id]
    ok = client.post(f"/api/v1/groups/{gid}/join-requests/{pending[0]['id']}", json={"approve": True}, headers=owner)
    assert ok.json()["status"] == "APPROVED"
    assert client.get(f"/api/v1/groups/{gid}", headers=newcomer).status_code == 200
