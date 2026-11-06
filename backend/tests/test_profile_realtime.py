"""Le profil en temps réel, et le carnet à sens unique.

- Changer de nom ou de photo prévient tout de suite ceux qui affichent ce
  profil (`user:profile_updated`), sans rien leur pousser d'autre que
  l'identifiant : chacun relit par l'API, qui applique la confidentialité.
- Avoir le numéro de quelqu'un suffit à le voir dans son carnet, même s'il
  n'a pas le nôtre.
"""
import re
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.api.v1.messaging.ws import manager
from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_profile_realtime.db"
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
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def test_un_contact_a_sens_unique_apparait_dans_mon_carnet(client):
    moi, _ = _signup(client, "+22890000101")
    _, lui_id = _signup(client, "+22890000102")

    # J'ai son numéro, il n'a pas le mien.
    reponse = client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [{"phone": "+228 90 00 01 02", "name": "Kofi"}]},
        headers=moi,
    )
    assert reponse.status_code == 200, reponse.text
    carnet = client.get("/api/v1/contacts", headers=moi).json()["items"]
    assert [c["contact_user_id"] for c in carnet] == [lui_id]
    assert carnet[0]["is_registered"] is True


def test_changer_de_profil_previent_ceux_qui_m_affichent(client):
    moi, moi_id = _signup(client, "+22890000201")
    ami, ami_id = _signup(client, "+22890000202")
    _, inconnu_id = _signup(client, "+22890000203")

    # L'ami m'a dans son carnet ; l'inconnu ne me connaît pas.
    client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [{"phone": "+22890000201", "name": "Moi"}]},
        headers=ami,
    )

    with patch.object(manager, "send_to_user", new=AsyncMock(return_value=True)) as envoi:
        reponse = client.put(
            "/api/v1/users/me/profile", json={"full_name": "Afi K."}, headers=moi
        )
    assert reponse.status_code == 200, reponse.text

    destinataires = {appel.args[0] for appel in envoi.await_args_list}
    assert ami_id in destinataires
    assert inconnu_id not in destinataires
    assert moi_id not in destinataires
    # Rien d'autre que l'identifiant : la photo et le nom se relisent par
    # l'API, qui applique la confidentialité.
    for appel in envoi.await_args_list:
        assert appel.args[1] == {"type": "user:profile_updated", "user_id": moi_id}
