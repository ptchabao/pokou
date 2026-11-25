"""Assimé : la vente en main propre, close par le code de l'acheteur."""
from datetime import datetime, timedelta

from app.models import MarketplaceHandover, MarketplaceProduct, ServiceNotification
from tests.test_assime_maquette import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _publish,
    _signup,
    client,
    stub_mobile_money,
)


def _setup(client):
    seller, _ = _signup(client, "+22890510001")
    buyer, buyer_id = _signup(client, "+22890510002")
    other, _ = _signup(client, "+22890510003")
    product_id = _publish(client, seller)["id"]
    return seller, buyer, buyer_id, other, product_id


def _start(client, seller, product_id, buyer_id, **extra):
    return client.post(f"/api/v1/marketplace/{product_id}/handover",
                       json={"buyer_id": buyer_id, **extra}, headers=seller)


def test_parcours_complet_code_puis_cloture_puis_note(client):
    seller, buyer, buyer_id, other, pid = _setup(client)
    started = _start(client, seller, pid, buyer_id, final_price=11500)
    assert started.status_code == 201
    assert "code" not in started.json()  # le vendeur ne voit jamais le code
    # L'acheteur, lui, le voit ; un tiers ne voit rien.
    seen = client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()
    assert seen["role"] == "buyer" and len(seen["code"]) == 6
    assert client.get(f"/api/v1/marketplace/{pid}/handover", headers=other).status_code == 404
    assert "code" not in client.get(f"/api/v1/marketplace/{pid}/handover", headers=seller).json()
    # Seul le vendeur clôture.
    assert client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": seen["code"]},
                       headers=buyer).status_code == 404
    done = client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": seen["code"]}, headers=seller)
    assert done.status_code == 200 and done.json()["status"] == "DONE"
    with TestingSessionLocal() as db:
        product = db.query(MarketplaceProduct).get(pid)
        assert product.sold_at and product.buyer_id == buyer_id and product.final_price == 11500
        routes = [n.route for n in db.query(ServiceNotification).filter(ServiceNotification.user_id == buyer_id)]
        assert routes == [f"assime/handover/{pid}", f"assime/review/{pid}"]
    # Usage unique : le code ne ressert pas, et l'acheteur peut noter.
    assert client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": seen["code"]},
                       headers=seller).status_code == 409
    assert "code" not in client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()
    sale = client.get(f"/api/v1/marketplace/{pid}/sale", headers=buyer).json()
    assert sale["final_price"] == 11500 and sale["reviewed"] is False


def test_essais_limites_puis_verrou(client):
    seller, buyer, buyer_id, _, pid = _setup(client)
    _start(client, seller, pid, buyer_id)
    code = client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()["code"]
    wrong = "000000" if code != "000000" else "111111"
    for left in (4, 3, 2, 1):
        r = client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": wrong}, headers=seller)
        assert r.status_code == 422 and r.json()["detail"]["attempts_left"] == left
    r = client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": wrong}, headers=seller)
    assert r.status_code == 429 and r.json()["detail"]["code"] == "handover_locked"
    # Même le bon code ne marche plus : il faut recommencer.
    assert client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": code},
                       headers=seller).status_code == 409
    with TestingSessionLocal() as db:
        assert db.query(MarketplaceProduct).get(pid).sold_at is None


def test_code_expire(client):
    seller, buyer, buyer_id, _, pid = _setup(client)
    _start(client, seller, pid, buyer_id)
    code = client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()["code"]
    with TestingSessionLocal() as db:
        db.query(MarketplaceHandover).update({"expires_at": datetime.utcnow() - timedelta(minutes=1)})
        db.commit()
    r = client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": code}, headers=seller)
    assert r.status_code == 410 and r.json()["detail"]["code"] == "handover_expired"
    assert client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()["status"] == "EXPIRED"


def test_nouveau_code_remplace_l_ancien_et_nombre_limite(client):
    seller, buyer, buyer_id, _, pid = _setup(client)
    _start(client, seller, pid, buyer_id)
    first = client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()["code"]
    _start(client, seller, pid, buyer_id)
    with TestingSessionLocal() as db:
        statuses = [h.status for h in db.query(MarketplaceHandover).order_by(MarketplaceHandover.id)]
        assert statuses == ["CANCELLED", "PENDING"]
    second = client.get(f"/api/v1/marketplace/{pid}/handover", headers=buyer).json()["code"]
    if first != second:
        assert client.post(f"/api/v1/marketplace/{pid}/handover/confirm", json={"code": first},
                           headers=seller).status_code == 422
    for _ in range(3):
        _start(client, seller, pid, buyer_id)
    assert _start(client, seller, pid, buyer_id).status_code == 429


def test_refus(client):
    seller, buyer, buyer_id, other, pid = _setup(client)
    assert _start(client, other, pid, buyer_id).status_code == 404  # pas son annonce
    assert _start(client, seller, pid, 999999).status_code == 422
    seller_id = client.get("/api/v1/auth/me", headers=seller).json()["id"]
    assert _start(client, seller, pid, seller_id).status_code == 422
    _start(client, seller, pid, buyer_id)
    assert client.delete(f"/api/v1/marketplace/{pid}/handover", headers=seller).json()["status"] == "CANCELLED"
    assert client.delete(f"/api/v1/marketplace/{pid}/handover", headers=seller).status_code == 404
