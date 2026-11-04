"""HONAM de bout en bout : ordonnance → devis → paiement à l'officine →
coursier → code de remise, et les cas particuliers."""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import CourierLedgerEntry, CourierProfile, HonamOrder, MarketplacePayment, Pharmacy, PharmacyStaff, SystemSetting
from app.services.auth import otp_service
from app.services.honam import rules
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_pokou_honam.db"

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
    with TestingSessionLocal() as db:
        db.add(SystemSetting(key="country.TG", value='{"modules": ["discussions", "kory", "honam"]}'))
        db.commit()
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


_PHONE = iter(range(100, 999))


def _signup(client):
    phone = f"+22890300{next(_PHONE)}"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _pharmacy(user_id, *, name="Pharmacie du Bè", lat=6.13, lng=1.22, subscribed=True, credit=5000):
    with TestingSessionLocal() as db:
        pharmacy = Pharmacy(
            country="TG", name=name, address="Bè, Lomé", phone="+22822000000",
            latitude=lat, longitude=lng, wallet_phone="+22890999999", wallet_verified=True,
            subscription_plan="WETRI" if subscribed else None,
            subscription_until=datetime.utcnow() + timedelta(days=30) if subscribed else None,
            credit_balance=credit,
        )
        db.add(pharmacy)
        db.flush()
        db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=user_id, role="TITULAIRE"))
        db.commit()
        return pharmacy.id


def _courier(client, headers):
    """Candidature, puis validation par l'équipe (comme l'admin la ferait)."""
    client.post("/api/v1/honam/courier/join", json={
        "zones": "Bè, Tokoin — soirs", "wallet_phone": "+22890777777", "accept_rules": True,
    }, headers=headers)
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).filter(CourierProfile.status == "PENDING").first()
        rules.start_trial(db, courier)
        db.commit()


def _prescription(client, headers):
    return client.post(
        "/api/v1/media/upload", data={"message_type": "IMAGE"},
        files={"file": ("ordonnance.jpg", b"\xff\xd8\xff\xfake", "image/jpeg")}, headers=headers,
    ).json()["id"]


def _submit(client, patient, pharmacy_id):
    return client.post("/api/v1/honam/orders", json={
        "pharmacy_id": pharmacy_id, "prescription_media_id": _prescription(client, patient),
        "delivery_address": "Rue 12, Tokoin", "delivery_latitude": 6.14, "delivery_longitude": 1.21,
    }, headers=patient)


def _quote(client, pharmacist, order_id, **extra):
    return client.post(f"/api/v1/honam/pharmacy/orders/{order_id}/quote", json={
        "items": [{"name": "Amoxicilline 500", "quantity": 2, "unit_price": 1500},
                  {"name": "Paracétamol", "quantity": 1, "unit_price": 500, "available": False}],
        **extra,
    }, headers=pharmacist)


def test_annuaire_trie_par_distance_sans_officine_non_abonnee(client):
    patient, _ = _signup(client)
    a, a_id = _signup(client)
    b, b_id = _signup(client)
    c, c_id = _signup(client)
    _pharmacy(a_id, name="Loin", lat=6.30, lng=1.30)
    _pharmacy(b_id, name="Près", lat=6.141, lng=1.211)
    _pharmacy(c_id, name="Pas abonnée", subscribed=False)
    items = client.get("/api/v1/honam/pharmacies?lat=6.14&lng=1.21", headers=patient).json()["items"]
    assert [p["name"] for p in items] == ["Près", "Loin"]
    # Format annuaire : les mêmes champs pour toutes, rien qui classe.
    assert set(items[0]) == set(items[1])
    assert "wallet_phone" not in items[0]


def test_parcours_complet(client):
    patient, patient_id = _signup(client)
    pharmacist, pharmacist_id = _signup(client)
    courier_headers, courier_id = _signup(client)
    pharmacy_id = _pharmacy(pharmacist_id)

    order = _submit(client, patient, pharmacy_id).json()
    assert order["status"] == "SUBMITTED"

    # L'officine voit l'ordonnance, et peut l'ouvrir.
    seen = client.get(f"/api/v1/honam/pharmacy/orders/{order['id']}", headers=pharmacist).json()
    assert client.get(f"/api/v1/media/{seen['prescription_media_id']}", headers=pharmacist).status_code == 200
    # Un coursier, non.
    assert client.get(f"/api/v1/media/{seen['prescription_media_id']}", headers=courier_headers).status_code in (403, 404)

    quoted = _quote(client, pharmacist, order["id"], original_required=True).json()
    assert quoted["medicines_total"] == 3000 and quoted["delivery_price"] == 1000

    accepted = client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient).json()
    assert accepted["total"] == 4000 and accepted["pay_to_phone"] == "+22890999999"
    client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid", headers=patient)

    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    code = client.get(f"/api/v1/honam/orders/{order['id']}", headers=patient).json()["delivery_code"]
    assert code and len(code) == 6
    # Le code ne part ni à l'officine ni au coursier.
    assert "delivery_code" not in client.get(f"/api/v1/honam/pharmacy/orders/{order['id']}", headers=pharmacist).json()
    with TestingSessionLocal() as db:
        assert db.query(Pharmacy).get(pharmacy_id).credit_balance == 4900  # BM-11

    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/ready", headers=pharmacist)

    _courier(client, courier_headers)
    rides = client.get("/api/v1/honam/courier/rides", headers=courier_headers).json()
    ride = next(r for r in rides["available"] if r["id"] == order["id"])
    assert "quote_items" not in ride and "prescription_media_id" not in ride and "delivery_code" not in ride

    client.post(f"/api/v1/honam/courier/rides/{order['id']}/accept", headers=courier_headers)
    client.post(f"/api/v1/honam/courier/rides/{order['id']}/pickup", headers=courier_headers)
    wrong = client.post(f"/api/v1/honam/courier/rides/{order['id']}/deliver", json={"code": "000000" if code != "000000" else "111111"}, headers=courier_headers)
    assert wrong.status_code == 422
    assert client.get("/api/v1/honam/courier/me", headers=courier_headers).json()["rides_left"] == 5
    done = client.post(f"/api/v1/honam/courier/rides/{order['id']}/deliver", json={"code": code}, headers=courier_headers).json()
    assert done["status"] == "DELIVERED"
    # BM-04 : la course n'est décomptée qu'à la remise.
    assert client.get("/api/v1/honam/courier/me", headers=courier_headers).json()["rides_left"] == 4

    timeline = [e["status"] for e in client.get(f"/api/v1/honam/orders/{order['id']}", headers=patient).json()["timeline"]]
    assert timeline[0] == "SUBMITTED" and timeline[-1] == "DELIVERED"


def test_refus_puis_renvoi_a_une_autre_officine(client):
    patient, _ = _signup(client)
    p1, p1_id = _signup(client)
    _, p2_id = _signup(client)
    first = _pharmacy(p1_id)
    second = _pharmacy(p2_id, name="Autre")
    order = _submit(client, patient, first).json()
    rejected = client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/reject", json={"reason": "Ordonnance illisible"}, headers=p1).json()
    assert rejected["status"] == "REJECTED"
    again = client.post(f"/api/v1/honam/orders/{order['id']}/resend", json={"pharmacy_id": second}, headers=patient).json()
    assert again["status"] == "SUBMITTED" and again["pharmacy"]["id"] == second


def test_paiement_non_recu_et_devis_refuse_ne_coutent_rien(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _submit(client, patient, pharmacy_id).json()
    _quote(client, pharmacist, order["id"])
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid", headers=patient)
    back = client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/payment-not-received", headers=pharmacist).json()
    assert back["status"] == "ACCEPTED" and back["payment_not_received_at"]
    client.post(f"/api/v1/honam/orders/{order['id']}/cancel", headers=patient)
    with TestingSessionLocal() as db:
        assert db.query(Pharmacy).get(pharmacy_id).credit_balance == 5000


def test_produit_manquant_choix_de_la_patiente_et_remboursement_sous_2h(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _submit(client, patient, pharmacy_id).json()
    _quote(client, pharmacist, order["id"])
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/missing-product",
                json={"amount": 1500, "reason": "Rupture"}, headers=pharmacist)
    # Tant que la patiente n'a pas choisi, la commande ne part pas.
    assert client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/ready", headers=pharmacist).status_code == 409
    kept = client.post(f"/api/v1/honam/orders/{order['id']}/missing-choice", json={"choice": "KEEP"}, headers=patient).json()
    assert kept["refund_due"] == 1500 and kept["status"] == "PAID"
    seen = client.get(f"/api/v1/honam/pharmacy/orders/{order['id']}", headers=pharmacist).json()
    assert seen["refund_to_phone"]  # le seul numéro qui a payé
    with TestingSessionLocal() as db:
        db.query(HonamOrder).filter(HonamOrder.id == order["id"]).update(
            {"refund_requested_at": datetime.utcnow() - timedelta(hours=3)})
        db.commit()
    items = client.get("/api/v1/honam/pharmacies", headers=patient).json()["items"]
    assert all(p["id"] != pharmacy_id for p in items)
    client.post(f"/api/v1/honam/orders/{order['id']}/refund-received", headers=patient)
    items = client.get("/api/v1/honam/pharmacies", headers=patient).json()["items"]
    assert any(p["id"] == pharmacy_id for p in items)


def test_produit_manquant_tout_annuler_rembourse_tout(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _submit(client, patient, pharmacy_id).json()
    _quote(client, pharmacist, order["id"])
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/missing-product",
                json={"amount": 1500, "reason": "Rupture"}, headers=pharmacist)
    cancelled = client.post(f"/api/v1/honam/orders/{order['id']}/missing-choice", json={"choice": "CANCEL"}, headers=patient).json()
    assert cancelled["status"] == "CANCELLED" and cancelled["refund_due"] == 4000


def test_periode_de_lancement_sans_pack(client):
    with TestingSessionLocal() as db:
        db.query(SystemSetting).filter(SystemSetting.key == "country.TG").update({"value": (
            '{"modules": ["discussions", "honam"], "honam_launch_until": "%s"}'
            % (datetime.utcnow() + timedelta(days=30)).isoformat())})
        db.commit()
    courier_headers, _ = _signup(client)
    client.post("/api/v1/honam/courier/join", json={"zones": "Bè", "wallet_phone": "+22890777778", "accept_rules": True}, headers=courier_headers)
    pending = client.get("/api/v1/honam/courier/me", headers=courier_headers).json()
    assert pending["status"] == "PENDING" and pending["launch_period"] is True
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).one()
        courier.status = "ENDED"  # ni essai ni adhésion
        db.commit()
        assert rules.courier_can_accept(db, courier) == (True, None)


def test_credit_epuise_sept_jours_puis_pause(client):
    patient, _ = _signup(client)
    _, pid = _signup(client)
    pharmacy_id = _pharmacy(pid, credit=0)
    with TestingSessionLocal() as db:
        db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).update(
            {"credit_exhausted_at": datetime.utcnow() - timedelta(days=6)})
        db.commit()
    assert any(p["id"] == pharmacy_id for p in client.get("/api/v1/honam/pharmacies", headers=patient).json()["items"])
    with TestingSessionLocal() as db:
        db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).update(
            {"credit_exhausted_at": datetime.utcnow() - timedelta(days=8)})
        db.commit()
    assert all(p["id"] != pharmacy_id for p in client.get("/api/v1/honam/pharmacies", headers=patient).json()["items"])


def test_coursier_suspendu_au_troisieme_defaut(client):
    with TestingSessionLocal() as db:
        courier = CourierProfile(user_id=1, country="TG")
        db.add(courier)
        db.flush()
        order = HonamOrder(patient_id=1, pharmacy_id=1, delivery_address="x")
        for _ in range(2):
            assert rules.record_default(db, courier, order) is False
        assert rules.record_default(db, courier, order) is True
        assert courier.status == "SUSPENDED"
        db.rollback()


def test_registre_coursier_et_pack_superieur(client):
    courier_headers, _ = _signup(client)
    _courier(client, courier_headers)
    me = client.get("/api/v1/honam/courier/me", headers=courier_headers).json()
    assert me["status"] == "TRIAL" and me["rides_left"] == 5
    packs = {p["code"]: p for p in me["packs"]}
    assert packs["ABLAVI"]["price_ht"] == 500 and packs["QUEEN"]["price_ht"] == 3000

    def pay(kind_path, body=None):
        payment = client.post(f"/api/v1/honam/courier/{kind_path}", json=body, headers=courier_headers).json()
        with TestingSessionLocal() as db:
            reference = db.query(MarketplacePayment).get(payment["payment_id"]).provider_reference
        confirm_payment(TestingSessionLocal(), reference)
        return payment

    # Pack sans adhésion : refusé.
    assert client.post("/api/v1/honam/courier/pack", json={"pack": "ABLAVI"}, headers=courier_headers).status_code == 402
    pay("membership")
    pay("pack", {"pack": "ABLAVI"})
    # Packs non cumulables ; le supérieur coûte la différence.
    assert client.post("/api/v1/honam/courier/pack", json={"pack": "ABLAVI"}, headers=courier_headers).status_code == 409
    upgrade = pay("pack", {"pack": "POKOU_VI"})
    assert upgrade["amount"] == round((900 - 500) * 1.18)
    me = client.get("/api/v1/honam/courier/me", headers=courier_headers).json()
    assert me["status"] == "MEMBER" and me["current_pack"] == "POKOU_VI"
    assert me["rides_left"] == 5 + 10  # essai + pack de 10 (5 achetées + 5 de différence)
    with TestingSessionLocal() as db:
        kinds = [e.kind for e in db.query(CourierLedgerEntry).order_by(CourierLedgerEntry.id)]
    assert kinds == ["TRIAL", "PURCHASE", "UPGRADE"]
    # Queen Pokou : refusé après un défaut le mois précédent.
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).one()
        last_month = datetime.utcnow().replace(day=1) - timedelta(days=3)
        db.add(CourierLedgerEntry(courier_id=courier.id, kind="DEFAULT", rides=0, created_at=last_month))
        db.commit()
    assert client.post("/api/v1/honam/courier/pack", json={"pack": "QUEEN"}, headers=courier_headers).status_code == 403


def test_honam_ferme_hors_pays_lance(client):
    with TestingSessionLocal() as db:
        db.query(SystemSetting).filter(SystemSetting.key == "country.TG").delete()
        db.commit()
    patient, _ = _signup(client)
    assert client.get("/api/v1/honam/pharmacies", headers=patient).status_code == 404


def test_push_etats_commande_limites_aux_participants_et_sans_donnees_sensibles(client):
    patient, patient_id = _signup(client)
    pharmacist, pharmacist_id = _signup(client)
    colleague, colleague_id = _signup(client)
    outsider, outsider_id = _signup(client)
    pharmacy_id = _pharmacy(pharmacist_id)
    with TestingSessionLocal() as db:
        db.add(PharmacyStaff(pharmacy_id=pharmacy_id, user_id=colleague_id, role="COLLABORATEUR"))
        db.commit()

    with patch("app.services.honam.order_notifications.send_push") as send_push:
        submitted = _submit(client, patient, pharmacy_id)
        assert submitted.status_code == 201
        assert {call.args[1] for call in send_push.call_args_list} == {pharmacist_id, colleague_id}

        order_id = submitted.json()["id"]
        send_push.reset_mock()
        quoted = _quote(client, pharmacist, order_id)
        assert quoted.status_code == 200
        assert {call.args[1] for call in send_push.call_args_list} == {patient_id, colleague_id}
        quote_calls = send_push.call_args_list[:]

        with TestingSessionLocal() as db:
            db.query(HonamOrder).filter(HonamOrder.id == order_id).update(
                {"quote_expires_at": datetime.utcnow() - timedelta(seconds=1)}
            )
            db.commit()
        send_push.reset_mock()
        expired = client.get(f"/api/v1/honam/orders/{order_id}", headers=patient)
        assert expired.status_code == 200 and expired.json()["status"] == "EXPIRED"
        assert {call.args[1] for call in send_push.call_args_list} == {
            patient_id,
            pharmacist_id,
            colleague_id,
        }
        expiration_calls = send_push.call_args_list[:]

    for calls, expected_status in ((quote_calls, "QUOTED"), (expiration_calls, "EXPIRED")):
        assert outsider_id not in {call.args[1] for call in calls}
        for call in calls:
            _, _, title, body = call.args[:4]
            payload = call.kwargs["data"]
            assert title == "Mise à jour HONAM"
            assert "ordonnance" not in body.lower()
            assert payload == {
                "type": "honam_order_status",
                "order_id": str(order_id),
                "status": expected_status,
                "priority": "normal",
                "muted": "0",
            }
            assert not any(
                sensitive in str(payload) + title + body
                for sensitive in ("Amoxicilline", "Tokoin", "ordonnance.jpg", "prescription_media_id")
            )


def test_messages_commande_visibles_aux_participants_seulement(client):
    patient, patient_id = _signup(client)
    pharmacist, pharmacist_id = _signup(client)
    outsider, _ = _signup(client)
    pharmacy_id = _pharmacy(pharmacist_id)
    order_id = _submit(client, patient, pharmacy_id).json()["id"]

    sent = client.post(
        f"/api/v1/honam/orders/{order_id}/messages",
        json={"body": "Votre commande est prête"},
        headers=patient,
    )
    assert sent.status_code == 201
    assert sent.json()["sender_id"] == patient_id
    assert sent.json()["sender_role"] == "PATIENT"

    received = client.get(
        f"/api/v1/honam/orders/{order_id}/messages",
        headers=pharmacist,
    )
    assert received.status_code == 200
    assert [message["body"] for message in received.json()["items"]] == [
        "Votre commande est prête"
    ]

    assert client.get(
        f"/api/v1/honam/orders/{order_id}/messages",
        headers=outsider,
    ).status_code == 404
    assert client.post(
        f"/api/v1/honam/orders/{order_id}/messages",
        json={"body": "Accès indu"},
        headers=outsider,
    ).status_code == 404

    assert client.post(
        f"/api/v1/honam/orders/{order_id}/messages",
        json={"body": " "},
        headers=patient,
    ).status_code == 422
