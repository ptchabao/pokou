"""Honam, conformité à la maquette : repère, référence de paiement, délai du
produit manquant, inscription coursier en 6 étapes, disponibilité, gains,
défauts datés, incidents de course, code de remise borné."""
import re
from datetime import date, datetime, timedelta
from unittest.mock import patch

from app.models import CourierProfile, HonamOrder
from app.services.auth import otp_service
from app.services.honam import rules
from tests.test_honam import (  # noqa: F401 — fixtures réutilisées
    TestingSessionLocal,
    _courier,
    _pharmacy,
    _quote,
    _signup,
    _submit,
    client,
    stub_mobile_money,
)


def _paid_order(client, patient, pharmacist, pharmacy_id):
    order = client.post("/api/v1/honam/orders", json={
        "pharmacy_id": pharmacy_id,
        "prescription_media_id": client.post(
            "/api/v1/media/upload", data={"message_type": "IMAGE"},
            files={"file": ("o.jpg", b"\xff\xd8\xff\xfake", "image/jpeg")}, headers=patient,
        ).json()["id"],
        "delivery_address": "Bè-Kpota, rue des Cocotiers", "landmark": "portail bleu face au kiosque",
        "delivery_latitude": 6.14, "delivery_longitude": 1.21, "note": "À livrer avant 13 h",
    }, headers=patient).json()
    _quote(client, pharmacist, order["id"])
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    return order


def test_repere_et_reference_de_paiement(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _paid_order(client, patient, pharmacist, pharmacy_id)
    assert order["delivery_landmark"] == "portail bleu face au kiosque"
    assert order["patient_note"] == "À livrer avant 13 h"
    assert order["prescription_media_id"]
    declared = client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid",
                           json={"reference": "7kx4-2190"}, headers=patient).json()
    assert declared["payment_reference"] == "7KX4-2190"
    seen = client.get(f"/api/v1/honam/pharmacy/orders/{order['id']}", headers=pharmacist).json()
    assert seen["payment_reference"] == "7KX4-2190"
    # Sans corps : l'ancien client marche encore.
    assert client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid", headers=patient).status_code == 200


def test_devis_conditionnement_et_generique(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _submit(client, patient, pharmacy_id).json()
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/quote", json={"items": [
        {"name": "Sirop antitussif", "quantity": 1, "unit_price": 2200, "packaging": "Flacon 125 ml", "generic": True},
    ]}, headers=pharmacist)
    item = client.get(f"/api/v1/honam/orders/{order['id']}", headers=patient).json()["quote_items"][0]
    assert item["packaging"] == "Flacon 125 ml" and item["generic"] is True


def test_produit_manquant_sans_reponse_sous_15_minutes(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _paid_order(client, patient, pharmacist, pharmacy_id)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/missing-product",
                json={"amount": 500, "reason": "Plus de sirop"}, headers=pharmacist)
    with TestingSessionLocal() as db:
        row = db.query(HonamOrder).get(order["id"])
        row.missing_reported_at = datetime.utcnow() - timedelta(minutes=16)
        db.commit()
    seen = client.get(f"/api/v1/honam/orders/{order['id']}", headers=patient).json()
    assert seen["status"] == "CANCELLED" and seen["missing_choice"] == "CANCEL"
    assert seen["refund_due"] == 4000


def _otp_code(mock_send):
    return re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)


def test_inscription_en_6_etapes_et_wallet_verifie(client):
    headers, user_id = _signup(client)
    selfie = client.post("/api/v1/media/upload", data={"message_type": "IMAGE"},
                         files={"file": ("s.jpg", b"\xff\xd8\xff\xfake", "image/jpeg")}, headers=headers).json()["id"]
    # Trop jeune : refusé.
    young = client.post("/api/v1/honam/courier/join", json={
        "wallet_phone": "+22890777777", "accept_rules": True, "zones_list": ["Bè"],
        "birth_date": str(date.today().replace(year=date.today().year - 16)),
    }, headers=headers)
    assert young.status_code == 422
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        assert client.post("/api/v1/honam/courier/wallet/send-code",
                           json={"wallet_phone": "+22890777777"}, headers=headers).status_code == 200
    assert client.post("/api/v1/honam/courier/wallet/verify",
                       json={"wallet_phone": "+22890777777", "code": _otp_code(mock_send)},
                       headers=headers).json()["verified"] is True
    me = client.post("/api/v1/honam/courier/join", json={
        "wallet_phone": "+22890777777", "accept_rules": True, "quiz_passed": True,
        "birth_date": "1999-03-12", "transport": "MOTO", "id_doc_type": "CNI", "selfie_media_id": selfie,
        "zones_list": ["Bè", "Tokoin"], "days": ["MON", "XXX"], "moments": ["EVENING"],
    }, headers=headers).json()
    assert me["status"] == "PENDING" and me["wallet_verified"] is True
    assert me["zones_list"] == ["Bè", "Tokoin"] and me["days"] == ["MON"] and me["transport"] == "MOTO"
    assert me["zones"] == "Bè, Tokoin" and me["has_selfie"] is True
    # Le support demande de reprendre le selfie : « à compléter ».
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()
        courier.status = "INCOMPLETE"
        courier.incomplete_item = "SELFIE"
        courier.incomplete_reason = "Selfie flou"
        db.commit()
    me = client.get("/api/v1/honam/courier/me", headers=headers).json()
    assert me["incomplete_item"] == "SELFIE" and me["incomplete_reason"] == "Selfie flou"
    again = client.post("/api/v1/honam/courier/identity", json={"selfie_media_id": selfie}, headers=headers).json()
    assert again["status"] == "PENDING" and again["incomplete_item"] is None


def test_disponibilite_bienvenue_et_offre(client):
    headers, _ = _signup(client)
    offer = client.get("/api/v1/honam/courier/offer", headers=headers).json()
    assert offer["trial_rides"] == 5 and offer["membership_price_ht"] == 1000
    assert offer["dismissed"] is False
    client.post("/api/v1/honam/courier/offer/dismiss", headers=headers)
    assert client.get("/api/v1/honam/cities", headers=headers).json()["courier_offer_dismissed"] is True
    _courier(client, headers)
    me = client.post("/api/v1/honam/courier/availability", json={"available": True}, headers=headers).json()
    assert me["available"] is True and me["welcomed"] is False
    assert client.post("/api/v1/honam/courier/welcomed", headers=headers).json()["welcomed"] is True
    # Le lien de parrainage d'un coursier validé est reconnu par l'ami.
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).first()
        courier.referral_code = "KODJO7"
        courier.validated_at = datetime.utcnow()
        db.commit()
    friend, _ = _signup(client)
    inviter = client.get("/api/v1/honam/courier/offer?code=kodjo7", headers=friend).json()["inviter"]
    assert inviter["code"] == "KODJO7" and inviter["verified"] is True


def _ride_in_delivery(client):
    patient, _ = _signup(client)
    pharmacist, pid = _signup(client)
    courier_headers, _ = _signup(client)
    pharmacy_id = _pharmacy(pid)
    order = _paid_order(client, patient, pharmacist, pharmacy_id)
    client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/ready", headers=pharmacist)
    _courier(client, courier_headers)
    client.post(f"/api/v1/honam/courier/rides/{order['id']}/accept", headers=courier_headers)
    client.post(f"/api/v1/honam/courier/rides/{order['id']}/pickup", headers=courier_headers)
    return patient, pharmacist, courier_headers, order


def test_code_de_remise_5_essais_au_plus(client):
    patient, _, courier_headers, order = _ride_in_delivery(client)
    code = client.get(f"/api/v1/honam/orders/{order['id']}", headers=patient).json()["delivery_code"]
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(rules.MAX_CODE_ATTEMPTS):
        assert client.post(f"/api/v1/honam/courier/rides/{order['id']}/deliver",
                           json={"code": wrong}, headers=courier_headers).status_code == 422
    assert client.post(f"/api/v1/honam/courier/rides/{order['id']}/deliver",
                       json={"code": code}, headers=courier_headers).status_code == 429


def test_patient_injoignable_puis_colis_rapporte_sans_defaut(client):
    patient, _, courier_headers, order = _ride_in_delivery(client)
    ride = client.get("/api/v1/honam/courier/rides", headers=courier_headers).json()["mine"][0]
    assert "patient_name" in ride and ride["patient_user_id"] and ride["delivery_landmark"] == "portail bleu face au kiosque"
    assert ride["picked_up_at"]
    tracking = client.get(f"/api/v1/honam/orders/{order['id']}/tracking", headers=patient).json()
    assert tracking["pharmacy_latitude"] is not None and tracking["courier_user_id"]
    client.post(f"/api/v1/honam/courier/rides/{order['id']}/incident", json={"kind": "NO_ANSWER"}, headers=courier_headers)
    early = client.post(f"/api/v1/honam/courier/rides/{order['id']}/return", headers=courier_headers)
    assert early.status_code == 409
    with TestingSessionLocal() as db:
        row = db.query(HonamOrder).get(order["id"])
        row.incident_at = datetime.utcnow() - timedelta(minutes=11)
        db.commit()
    back = client.post(f"/api/v1/honam/courier/rides/{order['id']}/return", headers=courier_headers).json()
    assert back["status"] == "READY"
    me = client.get("/api/v1/honam/courier/me", headers=courier_headers).json()
    assert me["defaults_count"] == 0 and me["rides_left"] == 5


def test_defaut_date_contestable_et_gains_du_mois(client):
    patient, pharmacist, courier_headers, order = _ride_in_delivery(client)
    reported = client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/courier-default",
                           json={"reason": "Retard important"}, headers=pharmacist)
    assert reported.status_code == 200
    me = client.get("/api/v1/honam/courier/me", headers=courier_headers).json()
    default = me["unacknowledged_default"]
    assert default["reason"] == "Retard important" and default["can_contest"] is True
    contested = client.post(f"/api/v1/honam/courier/defaults/{default['id']}/contest",
                            json={"note": "J'ai appelé"}, headers=courier_headers).json()
    assert contested["status"] == "CONTESTED"
    assert client.get("/api/v1/honam/courier/me", headers=courier_headers).json()["unacknowledged_default"] is None
    listed = client.get("/api/v1/honam/courier/defaults", headers=courier_headers).json()
    assert len(listed["items"]) == 1 and listed["max_defaults"] == 3
    earnings = client.get("/api/v1/honam/courier/earnings", headers=courier_headers).json()
    assert earnings["rides"] == 0 and earnings["defaults"] == 1 and earnings["months"]
    assert client.get("/api/v1/honam/courier/earnings?month=2026-13", headers=courier_headers).status_code == 422


def test_liste_d_attente_compte_les_inscrits(client):
    a, _ = _signup(client)
    b, _ = _signup(client)
    client.post("/api/v1/honam/waitlist", json={"city": "Kara"}, headers=a)
    joined = client.post("/api/v1/honam/waitlist", json={"city": "kara", "role": "PATIENT"}, headers=b).json()
    assert joined["count"] == 2
    assert client.get("/api/v1/honam/waitlist/count?city=KARA", headers=a).json()["count"] == 2


def test_l_offre_coursier_annonce_toujours_un_vrai_gain(client):
    """Un numéro d'un pays sans tarif Honam (+33) voyait « Tu gagnes 0 FCFA
    par course ». L'offre reprend alors celle du marché de lancement."""
    togo, _ = _signup(client)
    assert client.get("/api/v1/honam/courier/offer", headers=togo).json()["delivery_price"] == 1000

    phone = "+33612345678"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    abroad = {"Authorization": f"Bearer {body['access_token']}"}
    offer = client.get("/api/v1/honam/courier/offer", headers=abroad).json()
    assert offer["delivery_price"] == 1000 and offer["country"] == "TG"
    assert offer["served_cities"] == ["Lomé"]
