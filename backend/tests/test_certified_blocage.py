"""« Je ne peux pas avancer dans ma demande de certification. »

Reproduction du blocage signalé par les testeurs (numéros français) :

1. hors du Togo, le module était FERMÉ : /certified/offer répondait 404 et
   l'app montrait « échec, vérifie le réseau » ;
2. le paiement CashPay ne peut pas aboutir en test : sans webhook, aucun
   nom de titulaire, et un paiement confirmé à la main tombait en « noms
   différents » sans issue possible.

Le pays de test ouvre le module et simule le paiement avec le nom déclaré.
"""
from app.models import MarketplacePayment, User
from tests.test_certified import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _signup,
    client,
    stub_mobile_money,
)


def test_offre_ouverte_pour_un_numero_du_pays_de_test(client):
    headers, _ = _signup(client, "+33612340001", name="Ama Mensah")
    offer = client.get("/api/v1/certified/offer", headers=headers)
    assert offer.status_code == 200
    assert {p["code"] for p in offer.json()["plans"]} >= {"PARTICULIER_MONTHLY", "PRO_MONTHLY"}


def test_un_pays_sans_le_module_repond_404(client):
    headers, _ = _signup(client, "+447911000001")
    assert client.get("/api/v1/certified/me", headers=headers).status_code == 404


def test_paiement_simule_active_le_badge_avec_le_nom_declare(client, stub_mobile_money):
    headers, user_id = _signup(client, "+33612340002", name="Ama Mensah")
    paid = client.post("/api/v1/certified/subscribe", json={
        "plan": "PARTICULIER_MONTHLY", "full_name": "Ama Mensah"}, headers=headers).json()
    assert paid["test_mode"] is True and paid["status"] == "confirmed"
    stub_mobile_money.create_order.assert_not_called()
    me = client.get("/api/v1/certified/me", headers=headers).json()
    assert me["status"] == "ACTIVE" and me["badge_visible"] is True
    assert me["wallet_operator"] == "Mode test"
    with TestingSessionLocal() as db:
        assert db.query(User).get(user_id).is_verified is True
        assert db.query(MarketplacePayment).one().metadata_json["test_mode"] is True


def test_au_togo_le_paiement_reste_reel(client, stub_mobile_money):
    headers, _ = _signup(client, "+22890410001", name="Kossi Amegan")
    paid = client.post("/api/v1/certified/subscribe", json={"plan": "PARTICULIER_MONTHLY"}, headers=headers).json()
    assert paid["test_mode"] is False and paid["status"] == "pending" and paid["payment_url"]
    assert client.get("/api/v1/certified/me", headers=headers).json()["status"] == "NONE"
