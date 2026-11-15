"""Assimé, maquette : filtres, état, expiration, statistiques du vendeur,
signalement, annonces masquées, avis détaillés et bilan journalier."""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AbuseReport, MarketplacePayment, MarketplaceProduct
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_pokou_assime_maquette.db"

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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _publish(client, headers, **overrides):
    payload = {"name": "Pagne wax 6 yards", "price": "12000", "currency": "XOF", "location": "Lomé, Bè"}
    payload.update(overrides)
    response = client.post("/api/v1/marketplace", json=payload, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_etat_prix_a_debattre_et_expiration(client):
    seller, _ = _signup(client, "+22890100001")
    product = _publish(client, seller, condition="VERY_GOOD", negotiable=True)
    assert product["condition"] == "VERY_GOOD" and product["negotiable"] is True
    expires = datetime.fromisoformat(product["expires_at"])
    assert timedelta(days=29) < expires - datetime.utcnow() <= timedelta(days=30)
    refused = client.post(
        "/api/v1/marketplace", json={"name": "x", "price": "1", "condition": "BROKEN"}, headers=seller
    )
    assert refused.status_code == 422


def test_filtres_prix_etat_date_et_tri(client):
    seller, _ = _signup(client, "+22890100002")
    buyer, _ = _signup(client, "+22890100003")
    _publish(client, seller, name="Pagne neuf", price="12000", condition="NEW")
    _publish(client, seller, name="Pagne usé", price="5000", condition="GOOD")
    _publish(client, seller, name="Robe", price="30000", condition="NEW")
    url = "/api/v1/marketplace"
    body = client.get(f"{url}?max_price=15000&condition=NEW,VERY_GOOD", headers=buyer).json()
    assert [i["name"] for i in body["items"]] == ["Pagne neuf"] and body["total"] == 1
    body = client.get(f"{url}?min_price=6000&sort=price_asc", headers=buyer).json()
    assert [i["name"] for i in body["items"]] == ["Pagne neuf", "Robe"]
    assert client.get(f"{url}?published_days=7", headers=buyer).json()["total"] == 3


def test_une_annonce_expiree_quitte_le_marche_et_se_renouvelle(client):
    seller, _ = _signup(client, "+22890100004")
    buyer, _ = _signup(client, "+22890100005")
    product = _publish(client, seller)
    db = TestingSessionLocal()
    db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product["id"]).update(
        {MarketplaceProduct.expires_at: datetime.utcnow() - timedelta(days=1)}
    )
    db.commit()
    db.close()
    assert client.get("/api/v1/marketplace", headers=buyer).json()["total"] == 0
    renewed = client.post(f"/api/v1/marketplace/{product['id']}/renew", headers=seller)
    assert renewed.status_code == 200
    assert client.post(f"/api/v1/marketplace/{product['id']}/renew", headers=buyer).status_code == 404
    assert client.get("/api/v1/marketplace", headers=buyer).json()["total"] == 1


def test_vues_favoris_et_messages_visibles_du_seul_vendeur(client):
    seller, _ = _signup(client, "+22890100006")
    buyer, _ = _signup(client, "+22890100007")
    product = _publish(client, seller)
    detail = client.get(f"/api/v1/marketplace/{product['id']}", headers=buyer).json()
    assert "stats" not in detail and detail["is_favorite"] is False
    client.put(f"/api/v1/marketplace/{product['id']}/favorite", headers=buyer)
    client.post(f"/api/v1/marketplace/{product['id']}/share", json={"message": "Toujours disponible ?"},
                headers=buyer)
    mine = client.get("/api/v1/marketplace/mine", headers=seller).json()["items"][0]
    assert mine["stats"]["views"] == 1
    assert mine["stats"]["favorites"] == 1
    assert mine["stats"]["contacts"] == 1
    # Le vendeur qui ouvre sa fiche ne compte pas de vue.
    own = client.get(f"/api/v1/marketplace/{product['id']}", headers=seller).json()
    assert own["stats"]["views"] == 1


def test_un_medicament_dans_le_titre_renvoie_vers_honam(client):
    seller, _ = _signup(client, "+22890100008")
    response = client.post(
        "/api/v1/marketplace",
        json={"name": "Paracétamol 500 mg, boîte de 16", "price": "1000", "category": "MODE"},
        headers=seller,
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "use_honam"


def test_signaler_une_annonce_la_masque_apres_trois_personnes(client):
    seller, _ = _signup(client, "+22890100009")
    product = _publish(client, seller)
    url = f"/api/v1/marketplace/{product['id']}/report"
    assert client.post(url, json={"reason": "scam"}, headers=seller).status_code == 400
    assert client.post(url, json={"reason": "nimporte"}, headers=seller).status_code == 422
    reporters = [_signup(client, f"+2289010002{i}")[0] for i in range(3)]
    first = client.post(url, json={"reason": "scam"}, headers=reporters[0]).json()
    # Signaler deux fois ne compte qu'une fois.
    client.post(url, json={"reason": "scam"}, headers=reporters[0])
    assert first == {"reported": True, "hidden": False}
    assert client.post(url, json={"reason": "counterfeit"}, headers=reporters[1]).json()["hidden"] is False
    assert client.post(url, json={"reason": "other"}, headers=reporters[2]).json()["hidden"] is True
    assert client.get("/api/v1/marketplace", headers=reporters[0]).json()["total"] == 0
    db = TestingSessionLocal()
    assert db.query(AbuseReport).count() == 3
    db.close()


def test_masquer_une_annonce_ou_un_vendeur(client):
    seller, seller_id = _signup(client, "+22890100010")
    other, _ = _signup(client, "+22890100011")
    buyer, _ = _signup(client, "+22890100012")
    first = _publish(client, seller, name="Pagne")
    _publish(client, seller, name="Robe")
    _publish(client, other, name="Sac")
    client.post(f"/api/v1/marketplace/{first['id']}/hide", headers=buyer)
    names = {i["name"] for i in client.get("/api/v1/marketplace", headers=buyer).json()["items"]}
    assert names == {"Robe", "Sac"}
    client.post(f"/api/v1/marketplace/sellers/{seller_id}/hide", headers=buyer)
    names = {i["name"] for i in client.get("/api/v1/marketplace", headers=buyer).json()["items"]}
    assert names == {"Sac"}


def test_avis_detailles_reponse_du_vendeur_et_signalement(client):
    seller, seller_id = _signup(client, "+22890100013")
    buyer, buyer_id = _signup(client, "+22890100014")
    stranger, _ = _signup(client, "+22890100015")
    product = _publish(client, seller)
    # Pas de vente confirmée, pas de note (Assimé 101).
    refused = client.put(f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 5}, headers=buyer)
    assert refused.status_code == 403
    client.post(f"/api/v1/marketplace/{product['id']}/sold", json={"buyer_id": buyer_id, "final_price": 11500},
                headers=seller)
    review = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review",
        json={"rating": 4, "comment": "Tissu de belle qualité", "tags": ["as_described", "punctual"]},
        headers=buyer,
    ).json()
    assert client.put(f"/api/v1/marketplace/reviews/{review['id']}/reply", json={"reply": "Merci !"},
                      headers=stranger).status_code == 404
    reply = client.put(f"/api/v1/marketplace/reviews/{review['id']}/reply", json={"reply": "Merci !"},
                       headers=seller)
    assert reply.status_code == 200 and reply.json()["seller_reply"] == "Merci !"
    listing = client.get(f"/api/v1/marketplace/sellers/{seller_id}/reviews", headers=stranger).json()
    assert listing["histogram"] == {"1": 0, "2": 0, "3": 0, "4": 1, "5": 0}
    assert listing["tags"] == {"as_described": 1, "punctual": 1}
    assert listing["items"][0]["seller_reply"] == "Merci !"
    assert client.post(f"/api/v1/marketplace/reviews/{review['id']}/report",
                       headers=stranger).json() == {"reported": True}
    # Le profil du vendeur : son quartier, son ancienneté, ses annonces
    # vendues comprises.
    profile = client.get(f"/api/v1/marketplace/sellers/{seller_id}", headers=stranger).json()
    assert profile["area"] == "Lomé, Bè" and profile["member_since"]
    products = client.get(f"/api/v1/marketplace/sellers/{seller_id}/products", headers=stranger).json()
    assert products["items"][0]["sold_at"] is not None


def test_couper_une_alerte_sans_la_perdre(client):
    seller, _ = _signup(client, "+22890100016")
    buyer, _ = _signup(client, "+22890100017")
    alert = client.post("/api/v1/marketplace/alerts", json={"query": "pagne"}, headers=buyer).json()
    paused = client.patch(f"/api/v1/marketplace/alerts/{alert['id']}", json={"paused": True}, headers=buyer)
    assert paused.json()["paused"] is True
    with patch("app.api.v1.marketplace.assime.send_push") as push:
        _publish(client, seller, name="Pagne wax")
    push.assert_not_called()


def test_bilan_journalier_de_la_mise_en_avant(client):
    seller, _ = _signup(client, "+22890100018")
    buyer, _ = _signup(client, "+22890100019")
    product = _publish(client, seller)
    client.post(f"/api/v1/marketplace/{product['id']}/share", json={}, headers=buyer)
    client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 3}, headers=seller)
    db = TestingSessionLocal()
    reference = db.query(MarketplacePayment).first().provider_reference
    db.close()
    confirm_payment(TestingSessionLocal(), reference)
    client.get("/api/v1/marketplace", headers=buyer)
    other, _ = _signup(client, "+22890100020")
    client.post(f"/api/v1/marketplace/{product['id']}/share", json={}, headers=other)
    report = client.get(f"/api/v1/marketplace/{product['id']}/boost/report", headers=seller).json()["items"][0]
    assert report["messages_before"] == 1 and report["messages"] == 1
    assert report["daily"][0]["results"] == 1 and report["daily"][0]["status"] == 0
