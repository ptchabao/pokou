"""Aide et support : « Écrire au support » et « Signaler un problème »."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_support_tickets.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

REPORT_KEY = "kKz2uM5r0mJm6nqvC3m1tYbq7Q8pXq0yWnB9Ys5mH2E="


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client(monkeypatch):
    monkeypatch.setenv("REPORTS_ENCRYPTION_KEY", REPORT_KEY)
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
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _make_admin(user_id):
    from app.models import User, UserRole
    from tests.helpers import console_bearer

    session = TestingSessionLocal()
    try:
        session.query(User).filter(User.id == user_id).update({User.role: UserRole.SUPPORT})
        session.commit()
    finally:
        session.close()
    return console_bearer(TestingSessionLocal, user_id)


def _upload(client, headers):
    response = client.post(
        "/api/v1/media/upload", data={"message_type": "IMAGE"},
        files={"file": ("capture.jpg", b"\xff\xd8\xff\xfake", "image/jpeg")}, headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()["id"]


def _problem(**extra):
    return {
        "kind": "PROBLEM",
        "category": "CALLS",
        "description": "L'appel se coupe au bout de dix secondes.",
        "app_version": "1.30.0+130",
        "platform": "Android",
        **extra,
    }


def test_signaler_un_probleme_chiffre_et_lu_par_l_equipe(client):
    from app.models import SupportTicket

    headers, _ = _signup(client, "+22890700001")
    media_id = _upload(client, headers)
    response = client.post(
        "/api/v1/support/tickets", json=_problem(screenshot_media_id=media_id), headers=headers
    )
    assert response.status_code == 200, response.text
    ticket = response.json()
    assert ticket["status"] == "OPEN"
    assert ticket["category"] == "CALLS"
    assert ticket["has_screenshot"] is True
    assert ticket["description"].startswith("L'appel se coupe")

    session = TestingSessionLocal()
    try:
        row = session.query(SupportTicket).one()
        # Au repos : un jeton chiffré, jamais le texte.
        assert "appel" not in row.description_encrypted
        assert row.platform == "android"
        assert row.app_version == "1.30.0+130"
    finally:
        session.close()

    # Un inconnu ne voit pas la capture ; l'équipe, si.
    other, _ = _signup(client, "+22890700002")
    assert client.get(f"/api/v1/media/{media_id}", headers=other).status_code == 404
    _, admin_id = _signup(client, "+22890700099")
    admin = _make_admin(admin_id)
    assert client.get(f"/api/v1/media/{media_id}", headers=admin).status_code == 200

    # La liste ne déchiffre pas ; la fiche, si.
    listing = client.get("/api/v1/admin/support/search", headers=admin).json()
    assert listing["total"] == 1
    assert "description" not in listing["items"][0]
    detail = client.get(f"/api/v1/admin/support/{ticket['id']}", headers=admin).json()
    assert detail["description"] == "L'appel se coupe au bout de dix secondes."
    assert detail["screenshot_media_id"] == media_id

    queues = client.get("/api/v1/admin/queues", headers=admin).json()["items"]
    assert any(q["key"] == "support" and q["count"] == 1 for q in queues)


def test_ecrire_au_support_puis_lire_la_reponse(client):
    headers, user_id = _signup(client, "+22890700003")
    created = client.post(
        "/api/v1/support/tickets",
        json={"kind": "SUPPORT", "category": "CRASH", "description": "Comment changer mon numéro ?"},
        headers=headers,
    ).json()
    # Une demande au support est une question, quelle que soit la catégorie.
    assert created["category"] == "QUESTION"

    _, admin_id = _signup(client, "+22890700098")
    admin = _make_admin(admin_id)
    replied = client.post(
        f"/api/v1/admin/support/{created['id']}/reply",
        json={"message": "Réglages › Compte › Changer de numéro."},
        headers=admin,
    )
    assert replied.status_code == 200, replied.text
    assert replied.json()["status"] == "ANSWERED"

    mine = client.get("/api/v1/support/tickets", headers=headers).json()["items"]
    assert mine[0]["status"] == "ANSWERED"
    assert mine[0]["reply"] == "Réglages › Compte › Changer de numéro."
    assert mine[0]["replied_at"] is not None

    closed = client.post(f"/api/v1/admin/support/{created['id']}/close", headers=admin)
    assert closed.status_code == 200
    assert client.post(f"/api/v1/admin/support/{created['id']}/close", headers=admin).status_code == 409
    assert client.get("/api/v1/support/tickets", headers=headers).json()["items"][0]["status"] == "CLOSED"


def test_chacun_ne_voit_que_ses_demandes(client):
    alice, _ = _signup(client, "+22890700004")
    bob, _ = _signup(client, "+22890700005")
    client.post("/api/v1/support/tickets", json=_problem(), headers=alice)
    assert client.get("/api/v1/support/tickets", headers=bob).json()["items"] == []
    assert len(client.get("/api/v1/support/tickets", headers=alice).json()["items"]) == 1
    # Ni la console à un compte ordinaire.
    assert client.get("/api/v1/admin/support/search", headers=bob).status_code in (401, 403)


def test_capture_d_un_autre_refusee(client):
    alice, _ = _signup(client, "+22890700006")
    bob, _ = _signup(client, "+22890700007")
    media_bob = _upload(client, bob)
    response = client.post(
        "/api/v1/support/tickets", json=_problem(screenshot_media_id=media_bob), headers=alice
    )
    assert response.status_code == 400


def test_limite_de_debit_par_personne(client):
    from app.api.v1.support.support import MAX_PER_HOUR

    headers, _ = _signup(client, "+22890700008")
    for _ in range(MAX_PER_HOUR):
        assert client.post("/api/v1/support/tickets", json=_problem(), headers=headers).status_code == 200
    assert client.post("/api/v1/support/tickets", json=_problem(), headers=headers).status_code == 429


def test_sans_cle_rien_n_est_stocke_en_clair(client, monkeypatch):
    from app.models import SupportTicket

    headers, _ = _signup(client, "+22890700009")
    monkeypatch.delenv("REPORTS_ENCRYPTION_KEY", raising=False)
    monkeypatch.setattr("app.core.report_crypto._fernet", lambda: None)
    response = client.post("/api/v1/support/tickets", json=_problem(), headers=headers)
    assert response.status_code == 503
    session = TestingSessionLocal()
    try:
        assert session.query(SupportTicket).count() == 0
    finally:
        session.close()


def test_description_trop_courte_refusee(client):
    headers, _ = _signup(client, "+22890700010")
    response = client.post(
        "/api/v1/support/tickets", json=_problem(description="   court   "), headers=headers
    )
    assert response.status_code == 422
