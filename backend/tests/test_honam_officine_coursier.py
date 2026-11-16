"""Espace officine, maquettes p.93 et p.94 (migration 0027_officine_coursier) :
recherche de coursier (nombre de disponibles, rayon, relance, annulation),
retrait à l'officine, discussion avec le coursier (accusé de lecture,
fermeture 24 h après la livraison), compte de l'officine (horaires, garde,
fermeture temporaire, wallet, téléphones du comptoir, sonnerie)."""
from datetime import datetime, timedelta
from unittest.mock import patch

from app.models import CourierProfile, HonamOrder, Pharmacy, PharmacyStaff
from app.services.honam import order_notifications
from tests.test_honam import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _courier,
    _pharmacy,
    _signup,
    _submit,
    client,
    stub_mobile_money,
)
from tests.test_honam_officine import _act, _paid_order


def _ready_order(client):
    patient, pharmacist, other, oid = _paid_order(client)
    _act(client, pharmacist, oid, "ready")
    return patient, pharmacist, other, oid


def _available_courier(client, *, lat=None, lng=None):
    headers, user_id = _signup(client)
    _courier(client, headers)
    client.post("/api/v1/honam/courier/availability", json={"available": True}, headers=headers)
    if lat is not None:
        client.get(f"/api/v1/honam/courier/rides?lat={lat}&lng={lng}", headers=headers)
    return headers, user_id


def _offered(client, headers, oid):
    return any(r["id"] == oid for r in client.get("/api/v1/honam/courier/rides", headers=headers).json()["available"])


def test_recherche_compte_les_coursiers_et_elargit_la_zone(client):
    _, pharmacist, other, oid = _ready_order(client)
    near, _ = _available_courier(client, lat=6.131, lng=1.221)
    # À environ 7 km de l'officine (6.13, 1.22) : hors des 5 km.
    far, _ = _available_courier(client, lat=6.19, lng=1.24)
    order = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()
    dispatch = order["dispatch"]
    assert order["delivery_distance_km"] is not None
    assert dispatch["radius_km"] == 5 and dispatch["available_count"] == 1
    assert dispatch["area"] == "Bè" and dispatch["started_at"]
    assert _offered(client, near, oid) and not _offered(client, far, oid)

    # Une autre officine n'élargit pas la recherche d'une commande qui
    # n'est pas la sienne.
    assert _act(client, other, oid, "dispatch/widen").status_code == 404
    widened = _act(client, pharmacist, oid, "dispatch/widen").json()
    assert widened["dispatch"]["radius_km"] == 8 and widened["dispatch"]["available_count"] == 2
    assert _offered(client, far, oid)
    assert _act(client, pharmacist, oid, "dispatch/widen").status_code == 409

    # À l'arrêt, la position du coursier est effacée.
    client.post("/api/v1/honam/courier/availability", json={"available": False}, headers=far)
    with TestingSessionLocal() as db:
        assert all(c.latitude is None for c in db.query(CourierProfile).filter(CourierProfile.available.is_(False)))


def test_annuler_puis_relancer_la_recherche(client):
    _, pharmacist, _, oid = _ready_order(client)
    courier, _ = _available_courier(client)
    with TestingSessionLocal() as db:
        db.query(HonamOrder).filter(HonamOrder.id == oid).update(
            {"dispatch_started_at": datetime.utcnow() - timedelta(minutes=12)})
        db.commit()
    cancelled = _act(client, pharmacist, oid, "dispatch/cancel").json()
    assert cancelled["dispatch"]["cancelled_at"]
    assert not _offered(client, courier, oid)
    assert client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier).status_code == 409
    assert _act(client, pharmacist, oid, "dispatch/cancel").status_code == 409

    relaunched = _act(client, pharmacist, oid, "dispatch/relaunch").json()["dispatch"]
    assert relaunched["cancelled_at"] is None
    # La relance remet le compteur à zéro.
    started = datetime.fromisoformat(relaunched["started_at"])
    assert datetime.utcnow() - started < timedelta(minutes=1)
    assert _offered(client, courier, oid)
    assert client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier).status_code == 200
    # Un coursier a accepté : plus de recherche à relancer.
    assert _act(client, pharmacist, oid, "dispatch/relaunch").status_code == 409


def test_livreur_habituel_sans_reponse(client):
    _, pharmacist, _, oid = _ready_order(client)
    attached, _ = _signup(client)
    _courier(client, attached)
    client.post("/api/v1/honam/courier/availability", json={"available": True}, headers=attached)
    with TestingSessionLocal() as db:
        phone = db.query(CourierProfile).first().wallet_phone
    from app.models import User
    with TestingSessionLocal() as db:
        courier_user = db.query(User).filter(User.id == db.query(CourierProfile).first().user_id).first()
        courier_user.full_name = "Kodjo Amegah"
        db.commit()
        courier_phone = courier_user.phone
    assert phone
    client.post("/api/v1/honam/pharmacy/couriers", json={"phone": courier_phone}, headers=pharmacist)
    dispatch = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()["dispatch"]
    assert dispatch["unanswered"] == []  # pendant son avance
    with TestingSessionLocal() as db:
        db.query(HonamOrder).filter(HonamOrder.id == oid).update(
            {"dispatch_started_at": datetime.utcnow() - timedelta(minutes=6)})
        db.commit()
    dispatch = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()["dispatch"]
    assert dispatch["unanswered"] == ["Kodjo"]


def test_retrait_a_lofficine(client):
    patient, pharmacist, other, oid = _ready_order(client)
    courier, _ = _available_courier(client)
    proposed = _act(client, pharmacist, oid, "pickup/propose", message="Venez la retirer au comptoir").json()
    assert proposed["pickup_proposed_at"] and proposed["dispatch"]["cancelled_at"]
    assert not _offered(client, courier, oid)
    # La patiente reçoit le message dans sa discussion avec l'officine.
    messages = client.get(f"/api/v1/honam/orders/{oid}/messages?channel=patient", headers=patient).json()["items"]
    assert messages[-1]["body"] == "Venez la retirer au comptoir"

    # Pas de remise au comptoir avant l'accord de la patiente.
    assert _act(client, pharmacist, oid, "pickup/hand-over", code="000000").status_code == 409
    assert _act(client, other, oid, "pickup/confirm").status_code == 404
    confirmed = _act(client, pharmacist, oid, "pickup/confirm").json()
    assert confirmed["pickup_at_pharmacy"] is True and confirmed["dispatch"] is None
    assert confirmed["refund_due"] == confirmed["delivery_price"] and confirmed["refund_requested_at"]
    assert client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier).status_code == 409

    code = client.get(f"/api/v1/honam/orders/{oid}", headers=patient).json()["delivery_code"]
    wrong = "111111" if code != "111111" else "222222"
    assert _act(client, pharmacist, oid, "pickup/hand-over", code=wrong).status_code == 422
    done = _act(client, pharmacist, oid, "pickup/hand-over", code=code).json()
    assert done["status"] == "DELIVERED" and done["delivered_at"]


def test_discussion_coursier_lu_et_fermee_24h_apres_livraison(client):
    patient, pharmacist, _, oid = _ready_order(client)
    courier, courier_id = _available_courier(client)
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier)
    order = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()
    # L'appel relayé : l'identifiant du coursier, jamais son numéro.
    assert order["courier_user_id"] == courier_id and "courier_phone" not in order

    sent = client.post(f"/api/v1/honam/orders/{oid}/messages", json={"body": "Le colis est prêt", "channel": "coursier"},
                       headers=pharmacist).json()
    assert sent["read_at"] is None
    client.get(f"/api/v1/honam/orders/{oid}/messages?channel=coursier", headers=courier)
    items = client.get(f"/api/v1/honam/orders/{oid}/messages?channel=coursier", headers=pharmacist).json()["items"]
    assert items[0]["read_at"]

    with TestingSessionLocal() as db:
        db.query(HonamOrder).filter(HonamOrder.id == oid).update(
            {"status": "DELIVERED", "delivered_at": datetime.utcnow() - timedelta(hours=25)})
        db.commit()
    closed = client.post(f"/api/v1/honam/orders/{oid}/messages", json={"body": "Encore ?", "channel": "coursier"},
                         headers=pharmacist)
    assert closed.status_code == 409
    order = client.get(f"/api/v1/honam/pharmacy/orders/{oid}", headers=pharmacist).json()
    assert order["courier_user_id"] is None and order["courier_chat_closes_at"]
    # La discussion avec la patiente, elle, reste ouverte.
    assert client.post(f"/api/v1/honam/orders/{oid}/messages", json={"body": "Merci", "channel": "patient"},
                       headers=pharmacist).status_code == 201


def test_compte_horaires_garde_et_fermeture_temporaire(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    tomorrow = (datetime.utcnow() + timedelta(days=2)).date().isoformat()
    me = client.patch("/api/v1/honam/pharmacy/me", json={
        "opening_hours": "Lun.–sam., 8 h–21 h", "address": "Tokoin, rue 254, Lomé", "next_duty_on": tomorrow,
    }, headers=pharmacist).json()
    assert me["pharmacy"]["opening_hours"] == "Lun.–sam., 8 h–21 h"
    assert me["pharmacy"]["address"] == "Tokoin, rue 254, Lomé"
    assert me["pharmacy"]["next_duty_on"] == tomorrow
    assert client.patch("/api/v1/honam/pharmacy/me", json={"next_duty_on": "2001-01-01"},
                        headers=pharmacist).status_code == 422
    # Un patient n'a pas de compte d'officine.
    assert client.patch("/api/v1/honam/pharmacy/me", json={"opening_hours": "x"}, headers=patient).status_code == 403

    closed = client.patch("/api/v1/honam/pharmacy/me", json={"temporarily_closed": True}, headers=pharmacist).json()
    assert closed["pharmacy"]["temporarily_closed"] is True and closed["visible"] is False
    names = [p["id"] for p in client.get("/api/v1/honam/pharmacies", headers=patient).json()["items"]]
    assert pharmacy_id not in names
    assert _submit(client, patient, pharmacy_id).status_code == 404

    client.patch("/api/v1/honam/pharmacy/me", json={"temporarily_closed": False}, headers=pharmacist)
    assert _submit(client, patient, pharmacy_id).status_code == 201


def test_sonnerie_coupee_sur_ce_telephone(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    me = client.patch("/api/v1/honam/pharmacy/me", json={"ring_on_order": False}, headers=pharmacist).json()
    assert me["staff"]["ring_on_order"] is False
    with patch.object(order_notifications, "send_push") as push:
        _submit(client, patient, pharmacy_id)
    calls = [c for c in push.call_args_list if c.args[1] == pid]
    assert calls and calls[0].kwargs["data"]["muted"] == "1"


def test_wallet_a_verifier_et_telephones_du_comptoir(client):
    from app.api.v1.honam import honam as honam_api

    collaborator, collaborator_id = _signup(client)
    stranger, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)

    me = client.post("/api/v1/honam/pharmacy/wallet", json={"phone": "+22896000012"}, headers=pharmacist).json()
    # L'ancien wallet reçoit les paiements jusqu'à la vérification.
    assert me["pharmacy"]["wallet_phone"] == "+22890999999"
    assert me["pharmacy"]["wallet_phone_pending"] == "+22896000012" and me["visible"] is True
    with TestingSessionLocal() as db:
        honam_api.verify_wallet(pharmacy_id, {"user_id": pid}, db)
        pharmacy = db.query(Pharmacy).get(pharmacy_id)
        assert pharmacy.wallet_phone == "+22896000012" and pharmacy.wallet_phone_pending is None

    with TestingSessionLocal() as db:
        from app.models import User
        collaborator_phone = db.query(User).get(collaborator_id).phone
    phones = client.post("/api/v1/honam/pharmacy/phones", json={"phone": collaborator_phone}, headers=pharmacist)
    assert phones.status_code == 201 and len(phones.json()["items"]) == 2
    # Les numéros restent masqués.
    assert all("••" in p["phone_masked"] for p in phones.json()["items"])
    assert client.post("/api/v1/honam/pharmacy/phones", json={"phone": collaborator_phone},
                       headers=pharmacist).status_code == 409
    # Un collaborateur ne change ni le wallet ni les téléphones.
    assert client.post("/api/v1/honam/pharmacy/wallet", json={"phone": "+22896000013"},
                       headers=collaborator).status_code == 403
    assert client.get("/api/v1/honam/pharmacy/me", headers=collaborator).json()["phones_count"] == 2
    # Le titulaire seul ne se déconnecte pas : l'officine resterait sans gérant.
    assert client.delete("/api/v1/honam/pharmacy/phones/me", headers=pharmacist).status_code == 409
    # « Se déconnecter de ce téléphone » : le collaborateur perd l'accès.
    assert client.delete("/api/v1/honam/pharmacy/phones/me", headers=collaborator).status_code == 200
    assert client.get("/api/v1/honam/pharmacy/me", headers=collaborator).status_code == 403
    assert client.get("/api/v1/honam/pharmacy/phones", headers=stranger).status_code == 403
    with TestingSessionLocal() as db:
        assert db.query(PharmacyStaff).filter(PharmacyStaff.pharmacy_id == pharmacy_id).count() == 1
