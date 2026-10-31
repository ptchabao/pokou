"""Assimé : la mise en avant d'une annonce (BM-14) et le numéro du vendeur."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import MarketplaceBoost, MarketplacePayment
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_pokou_assime.db"

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


@pytest.fixture(autouse=True)
def stub_mobile_money():
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.side_effect = lambda db, **kw: {
            "order_reference": kw["merchant_reference"], "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}


def test_mise_en_avant_3_ou_7_jours_sponsorisee(client):
    seller = _signup(client, "+22890400001")
    product = client.post("/api/v1/marketplace", json={"name": "Pagne wax", "price": "8000", "currency": "XOF"}, headers=seller).json()
    assert product["seller_name"] == "Vendeur"  # jamais le numéro en repli
    three = client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 3}, headers=seller).json()
    assert three["amount"] == 600 and three["duration_hours"] == 72
    assert client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 5}, headers=seller).status_code == 422
    boost = client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 7}, headers=seller).json()
    assert boost["amount"] == 1300 and boost["duration_hours"] == 168
    with TestingSessionLocal() as db:
        reference = db.query(MarketplacePayment).get(boost["payment_id"]).provider_reference
    confirm_payment(TestingSessionLocal(), reference)
    with TestingSessionLocal() as db:
        row = db.query(MarketplaceBoost).filter(MarketplaceBoost.payment_id == boost["payment_id"]).one()
        assert (row.expires_at - row.starts_at).days == 7
    listed = client.get("/api/v1/marketplace", headers=seller).json()["items"]
    assert listed[0]["is_boosted"] and listed[0]["boost_label"] == "Sponsorisé"


def test_medicaments_renvoient_vers_honam(client):
    seller = _signup(client, "+22890400002")
    refused = client.post(
        "/api/v1/marketplace",
        json={"name": "Paracétamol", "price": "500", "currency": "XOF", "category": "medicaments"},
        headers=seller,
    )
    assert refused.status_code == 422 and refused.json()["detail"]["code"] == "use_honam"


def test_deux_sponsorisees_au_plus_par_ecran(client):
    seller = _signup(client, "+22890400003")
    ids = []
    for i in range(4):
        product = client.post("/api/v1/marketplace", json={"name": f"Article {i}", "price": "1000", "currency": "XOF"}, headers=seller).json()
        payment = client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 3}, headers=seller).json()
        with TestingSessionLocal() as db:
            reference = db.query(MarketplacePayment).get(payment["payment_id"]).provider_reference
        confirm_payment(TestingSessionLocal(), reference)
        ids.append(product["id"])
    page = client.get("/api/v1/marketplace?limit=10", headers=seller).json()["items"]
    assert sum(1 for item in page if item["boost_label"]) == 2
    assert len(page) == 4
