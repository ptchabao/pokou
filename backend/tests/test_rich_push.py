"""Notifications de message construites par l'appareil.

Un appareil qui le déclare (`capabilities: ["rich_message_push"]`) reçoit
un push de DONNÉES et construit lui-même une notification groupée par
conversation, avec le contenu qu'il va chercher. Les versions antérieures
gardent le push « notification » — sinon elles deviendraient muettes.
"""
import re
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DeviceToken
from app.services.auth import otp_service
from app.services.notifications import push_service

TEST_DATABASE_URL = "sqlite:///./test_rich_push.db"
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
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _envois_captures():
    """Remplace Firebase : rend la liste des messages qui seraient partis."""
    envoyes = []

    def send_each(messages, app=None):
        envoyes.extend(messages)
        return SimpleNamespace(
            success_count=len(messages),
            failure_count=0,
            responses=[SimpleNamespace(success=True, exception=None) for _ in messages],
        )

    return envoyes, send_each


def test_l_appareil_declare_construire_ses_notifications(client):
    headers, _ = _signup(client, "+22890200001")
    client.post("/api/v1/devices/register", json={"token": "ancien"}, headers=headers)
    client.post(
        "/api/v1/devices/register",
        json={"token": "nouveau", "capabilities": ["rich_message_push"]},
        headers=headers,
    )
    with TestingSessionLocal() as db:
        lignes = {t.token: t.rich_message_push for t in db.query(DeviceToken).all()}
    assert lignes == {"ancien": False, "nouveau": True}


def test_chaque_appareil_recoit_le_push_qu_il_sait_afficher(client):
    headers_a, _ = _signup(client, "+22890200002")
    headers_b, user_id_b = _signup(client, "+22890200003")
    client.post("/api/v1/contacts", json={"phone": "+22890200003", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/devices/register", json={"token": "ancien"}, headers=headers_b)
    client.post(
        "/api/v1/devices/register",
        json={"token": "nouveau", "capabilities": ["rich_message_push"]},
        headers=headers_b,
    )

    envoyes, send_each = _envois_captures()
    with patch.object(push_service, "_get_firebase_app", return_value=object()), patch(
        "firebase_admin.messaging.send_each", side_effect=send_each
    ):
        reponse = client.post(
            "/api/v1/messages",
            json={"recipient_id": user_id_b, "content": "Le colis part demain"},
            headers=headers_a,
        )
    assert reponse.status_code == 200, reponse.text

    par_jeton = {m.token: m for m in envoyes}
    # L'ancienne version : le push « notification » qu'elle sait afficher.
    assert par_jeton["ancien"].notification is not None
    assert "rich" not in par_jeton["ancien"].data
    # La nouvelle : des données, que l'appareil met en forme lui-même...
    assert par_jeton["nouveau"].notification is None
    assert par_jeton["nouveau"].data["rich"] == "1"
    assert par_jeton["nouveau"].data["message_id"] == reponse.json()["id"]
    # ... et le texte en clair ne voyage jamais par Firebase.
    for m in envoyes:
        assert "Le colis part demain" not in str(m.data)


def test_un_message_se_relit_par_son_identifiant_entre_les_deux_seulement(client):
    headers_a, _ = _signup(client, "+22890200004")
    headers_b, user_id_b = _signup(client, "+22890200005")
    headers_c, _ = _signup(client, "+22890200006")
    client.post("/api/v1/contacts", json={"phone": "+22890200005", "display_name": "Bob"}, headers=headers_a)
    message_id = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "Bonjour"}, headers=headers_a
    ).json()["id"]

    lu = client.get(f"/api/v1/messages/by-id/{message_id}", headers=headers_b)
    assert lu.status_code == 200
    assert lu.json()["content"] == "Bonjour"
    assert client.get(f"/api/v1/messages/by-id/{message_id}", headers=headers_c).status_code == 404


def test_un_message_de_groupe_se_relit_par_son_identifiant(client):
    headers_a, _ = _signup(client, "+22890200007")
    headers_c, _ = _signup(client, "+22890200008")
    groupe = client.post("/api/v1/groups", json={"name": "Équipe", "member_user_ids": []}, headers=headers_a).json()
    # Les messages de groupe sont chiffrés : le serveur ne relit que le chiffré.
    message = client.post(
        f"/api/v1/groups/{groupe['id']}/messages",
        json={
            "encryption": "sender-key-v1",
            "ciphertext": "chiffre-opaque",
            "crypto_epoch": groupe["crypto_epoch"],
        },
        headers=headers_a,
    ).json()

    lu = client.get(f"/api/v1/groups/{groupe['id']}/messages/{message['id']}", headers=headers_a)
    assert lu.status_code == 200
    assert lu.json()["ciphertext"] == "chiffre-opaque"
    assert lu.json()["content"] is None
    assert client.get(f"/api/v1/groups/{groupe['id']}/messages/{message['id']}", headers=headers_c).status_code == 403
