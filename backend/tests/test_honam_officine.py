"""Espace officine sur téléphone (migration 0024_officine_mobile) : remise
du colis, course payée au coursier, original rapporté, annulation par
l'officine, remboursement déclaré, historique du mois, défaut après la
livraison. Chaque geste est refusé dans le mauvais état et à une autre
officine."""
from datetime import datetime

from app.models import CourierProfile, HonamOrder, Pharmacy
from tests.test_honam import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _courier,
    _pharmacy,
    _quote,
    _signup,
    _submit,
    client,
    stub_mobile_money,
)


def _paid_order(client, *, original=False):
    """Une commande payée : patiente, officine (et une autre officine)."""
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    other, other_id = _signup(client)
    pharmacy_id = _pharmacy(pid)
    _pharmacy(other_id, name="Autre officine")
    order = _submit(client, patient, pharmacy_id).json()
    _quote(client, pharmacist, order["id"], original_required=original)
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    return patient, pharmacist, other, order["id"]


def _act(client, headers, order_id, action, **body):
    return client.post(f"/api/v1/honam/pharmacy/orders/{order_id}/{action}", json=body, headers=headers)


def test_remise_course_payee_original_et_defaut_apres_livraison(client):
    patient, pharmacist, other, oid = _paid_order(client, original=True)
    courier_headers, _ = _signup(client)
    _act(client, pharmacist, oid, "ready")
    # Pas de remise avant qu'un coursier ait accepté.
    assert _act(client, pharmacist, oid, "handed-over").status_code == 409
    _courier(client, courier_headers)
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier_headers)
    # Une autre officine ne touche pas à la commande.
    assert _act(client, other, oid, "handed-over").status_code == 404
    handed = _act(client, pharmacist, oid, "handed-over")
    assert handed.status_code == 200 and handed.json()["status"] == "IN_DELIVERY"
    assert handed.json()["courier_wallet_phone"] is None  # pas avant la livraison
    assert _act(client, pharmacist, oid, "handed-over").status_code == 409
    # Avant la livraison : ni course payée, ni original.
    assert _act(client, pharmacist, oid, "courier-paid").status_code == 409
    assert _act(client, pharmacist, oid, "original-received").status_code == 409

    code = client.get(f"/api/v1/honam/orders/{oid}", headers=patient).json()["delivery_code"]
    client.post(f"/api/v1/honam/courier/rides/{oid}/deliver", json={"code": code}, headers=courier_headers)
    seen = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()
    assert seen["courier_wallet_phone"] == "+22890777777" and seen["original_collected_at"]
    # Le wallet du coursier ne part qu'à l'officine.
    assert "courier_wallet_phone" not in client.get(f"/api/v1/honam/orders/{oid}", headers=patient).json()

    assert _act(client, other, oid, "courier-paid").status_code == 404
    paid = _act(client, pharmacist, oid, "courier-paid").json()
    assert paid["courier_paid_declared_at"] and paid["courier_paid_at"] is None
    ride = next(r for r in client.get("/api/v1/honam/courier/rides", headers=courier_headers).json()["mine"] if r["id"] == oid)
    assert ride["courier_paid_declared_at"]
    assert _act(client, other, oid, "original-received").status_code == 404
    assert _act(client, pharmacist, oid, "original-received").json()["original_returned_at"]

    # Défaut signalé après la livraison : compté, la commande ne bouge pas.
    default = _act(client, pharmacist, oid, "courier-default", reason="Original non rapporté").json()
    assert default["order"]["status"] == "DELIVERED"
    with TestingSessionLocal() as db:
        assert db.query(CourierProfile).first().defaults_count == 1
        assert db.query(HonamOrder).get(oid).courier_id is not None


def test_original_non_demande_refuse(client):
    _, pharmacist, _, oid = _paid_order(client)
    with TestingSessionLocal() as db:
        db.query(HonamOrder).filter(HonamOrder.id == oid).update({"status": "DELIVERED"})
        db.commit()
    assert _act(client, pharmacist, oid, "original-received").status_code == 409


def test_annulation_dune_commande_payee_et_remboursement_declare(client):
    patient, pharmacist, other, oid = _paid_order(client)
    assert _act(client, other, oid, "cancel", reason="Rupture").status_code == 404
    # Rien à rembourser tant que rien n'est annulé.
    assert _act(client, pharmacist, oid, "refund-sent", reference="X").status_code == 409
    cancelled = _act(client, pharmacist, oid, "cancel", reason="Rupture de stock").json()
    assert cancelled["status"] == "CANCELLED" and cancelled["refund_due"] == 4000
    assert cancelled["refund_requested_at"] and cancelled["refund_to_phone"]
    # Une commande close ne s'annule pas deux fois.
    assert _act(client, pharmacist, oid, "cancel", reason="Encore").status_code == 409
    assert _act(client, other, oid, "refund-sent", reference="X").status_code == 404
    sent = _act(client, pharmacist, oid, "refund-sent", reference="9QB2-6635").json()
    assert sent["refund_sent_at"] and sent["refund_reference"] == "9QB2-6635"
    # La patiente voit la référence, puis confirme.
    assert client.get(f"/api/v1/honam/orders/{oid}", headers=patient).json()["refund_reference"] == "9QB2-6635"
    client.post(f"/api/v1/honam/orders/{oid}/refund-received", headers=patient)
    assert _act(client, pharmacist, oid, "refund-sent", reference="X").status_code == 409


def test_annulation_dun_paiement_jamais_recu_sans_remboursement(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _submit(client, patient, pharmacy_id).json()
    # Avant l'acceptation du devis : pas d'annulation par l'officine.
    assert _act(client, pharmacist, order["id"], "cancel", reason="Non reçu").status_code == 409
    _quote(client, pharmacist, order["id"])
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    cancelled = _act(client, pharmacist, order["id"], "cancel", reason="Paiement non reçu").json()
    assert cancelled["status"] == "CANCELLED" and cancelled["refund_due"] == 0
    with TestingSessionLocal() as db:
        assert db.query(Pharmacy).get(pharmacy_id).credit_balance == 5000


def test_historique_du_mois(client):
    patient, pharmacist, other, oid = _paid_order(client)
    _act(client, pharmacist, oid, "cancel", reason="Rupture de stock")
    month = datetime.utcnow().strftime("%Y-%m")
    history = client.get(f"/api/v1/honam/pharmacy/history?month={month}", headers=pharmacist).json()
    assert [o["id"] for o in history["items"]] == [oid]
    assert history["stats"] == {"delivered": 0, "collected": 0, "cancelled": 1}
    # Une autre officine ne voit pas cette commande ; un mois vide, rien.
    assert client.get(f"/api/v1/honam/pharmacy/history?month={month}", headers=other).json()["items"] == []
    assert client.get("/api/v1/honam/pharmacy/history?month=2001-01", headers=pharmacist).json()["items"] == []
    assert client.get("/api/v1/honam/pharmacy/history?month=2026-13", headers=pharmacist).status_code == 422
    # Sans officine : refusé.
    assert client.get("/api/v1/honam/pharmacy/history", headers=patient).status_code == 403
