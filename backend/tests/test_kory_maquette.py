"""Kory : les données que la maquette du 11 novembre 2026 ajoute aux écrans.

Opérateur de l'envoi (écrans 4 et 5), jour d'échéance d'une cotisation
(17, 19, 21), rappels par membre (21), frais Kory Plus réglés pour les
autres (8). Toujours un journal, jamais un portefeuille (BM-01).
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_kory_maquette.db"

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
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


_PHONE = iter(range(1000, 9999))


def _signup(client, phone=None):
    phone = phone or f"+2289{next(_PHONE)}000"[:12]
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def test_numero_masque_de_l_auteur_pour_reconnaitre_son_operateur(client):
    """Écran 4 : « Flooz · réf. … » sous chaque déclaration. Le numéro de
    l'auteur, masqué, va au collecteur et à l'auteur ; pas au reste du groupe."""
    organizer, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    author, _ = _signup(client, "+22896112233")
    other, _ = _signup(client)
    for headers in (author, other):
        client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=headers)
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 1000, "wallet_reference": "REF-1"},
        headers=author,
    )
    seen_by = lambda h: client.get(f"/api/v1/kory/pots/{pot['id']}", headers=h).json()["entries"][0]  # noqa: E731
    assert seen_by(organizer)["contributor_phone_masked"] == "+228 96 •• •• 33"
    assert seen_by(author)["contributor_phone_masked"] == "+228 96 •• •• 33"
    assert "contributor_phone_masked" not in seen_by(other)
