"""Mode preuve à deux, Pokou certifié Pro, suivi et parrainage Honam,
« Vos coursiers », liste d'attente, favoris et alertes Assimé, statut
sponsorisé, tontine Kory Plus."""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import (
    CertifiedSubscription,
    CourierLedgerEntry,
    CourierProfile,
    DirectMessage,
    MarketplaceBoost,
    MarketplacePayment,
    Pharmacy,
    PharmacyStaff,
    SystemSetting,
    User,
    UserRole,
)
from app.services.auth import otp_service
from app.services.honam import rules
from app.services.marketplace.marketplace_monetization_service import confirm_payment
from tests.helpers import console_bearer

TEST_DATABASE_URL = "sqlite:///./test_pokou_finalisation.db"

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
        db.add(SystemSetting(
            key="country.TG",
            value='{"modules": ["discussions", "kory", "kory_plus", "honam", "certified"], "kory_plus_fee_ht": 0}',
        ))
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


def _signup(client, name="Kossi"):
    phone = f"+22890400{next(_PHONE)}"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    client.patch("/api/v1/auth/me", json={"full_name": name}, headers=headers)
    return headers, body["user"]["id"], phone


def _make_admin(user_id):
    """Rend le compte membre de l'équipe et renvoie sa session de CONSOLE :
    l'administration ne s'ouvre pas avec la session de l'app."""
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == user_id).update({User.role: UserRole.ADMIN})
        db.commit()
    return console_bearer(TestingSessionLocal, user_id)


def _confirm(payment_id):
    with TestingSessionLocal() as db:
        reference = db.query(MarketplacePayment).get(payment_id).provider_reference
    confirm_payment(TestingSessionLocal(), reference)


def _upload(client, headers, name="piece.jpg"):
    return client.post(
        "/api/v1/media/upload", data={"message_type": "IMAGE"},
        files={"file": (name, b"\xff\xd8\xff\xfake", "image/jpeg")}, headers=headers,
    ).json()["id"]


# ── Mode preuve à deux ──────────────────────────────────────────────────


def _pair(client):
    a, a_id, a_phone = _signup(client, "Afi")
    b, b_id, b_phone = _signup(client, "Kodjo")
    client.post("/api/v1/contacts", json={"phone": b_phone, "display_name": "Kodjo"}, headers=a)
    client.post("/api/v1/contacts", json={"phone": a_phone, "display_name": "Afi"}, headers=b)
    return a, a_id, b, b_id


def test_mode_preuve_a_deux(client):
    a, a_id, b, b_id = _pair(client)
    refused = client.put(f"/api/v1/messages/{b_id}/proof-mode", json={"enabled": True}, headers=a)
    assert refused.status_code == 403

    client.post("/api/v1/certified/trial", headers=a)
    on = client.put(f"/api/v1/messages/{b_id}/proof-mode", json={"enabled": True}, headers=a).json()
    assert on["enabled"] and on["can_disable"]
    assert on["notice"]["payload"] == {"kind": "proof_mode", "enabled": True}
    # Le mode vaut pour les deux côtés.
    seen_by_b = client.get(f"/api/v1/messages/{a_id}/proof-mode", headers=b).json()
    assert seen_by_b["enabled"] and not seen_by_b["can_disable"]

    sent = client.post("/api/v1/messages", json={"recipient_id": a_id, "content": "Je te rembourse lundi"}, headers=b).json()
    assert sent["proof_mode"] is True
    edited = client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "Je te rembourse mardi"}, headers=b).json()
    assert edited["original_content"] == "Je te rembourse lundi"
    deleted = client.delete(f"/api/v1/messages/{sent['id']}", headers=b).json()
    assert deleted["kept_as_proof"] is True
    with TestingSessionLocal() as db:
        kept = db.query(DirectMessage).filter(DirectMessage.id == sent["id"]).first()
        assert kept is not None and kept.deleted_at is not None

    # À deux, seule la personne qui l'a activé peut le couper.
    assert client.put(f"/api/v1/messages/{a_id}/proof-mode", json={"enabled": False}, headers=b).status_code == 403
    off = client.put(f"/api/v1/messages/{b_id}/proof-mode", json={"enabled": False}, headers=a).json()
    assert off["enabled"] is False

    # Hors mode preuve, « Supprimer pour tous » efface vraiment.
    plain = client.post("/api/v1/messages", json={"recipient_id": a_id, "content": "Oups"}, headers=b).json()
    assert plain["proof_mode"] is False
    assert client.delete(f"/api/v1/messages/{plain['id']}", headers=b).json()["deleted"] is True
    with TestingSessionLocal() as db:
        assert db.query(DirectMessage).filter(DirectMessage.id == plain["id"]).first() is None


# ── Pokou certifié Pro ──────────────────────────────────────────────────


def test_pro_justificatif_puis_validation_puis_paiement(client):
    pro, pro_id, _ = _signup(client, "Kossi Amégan")
    team, team_id, _ = _signup(client, "Support")
    team = _make_admin(team_id)

    # On ne paie qu'après la validation.
    early = client.post("/api/v1/certified/subscribe", json={"plan": "PRO_MONTHLY"}, headers=pro)
    assert early.status_code == 409

    document = _upload(client, pro, "registre.jpg")
    sent = client.post("/api/v1/certified/pro/apply", json={
        "business_name": "Boutique Amégan", "activity": "Couture", "city": "Lomé", "document_media_id": document,
    }, headers=pro).json()
    assert sent["status"] == "PENDING"
    due = datetime.fromisoformat(sent["review_due_at"]) - datetime.fromisoformat(sent["submitted_at"])
    assert due == timedelta(hours=48)

    # Le justificatif n'est visible que du support.
    stranger, _, _ = _signup(client, "Curieux")
    assert client.get(f"/api/v1/media/{document}", headers=stranger).status_code in (403, 404)

    pending = client.get("/api/v1/admin/certified/pro/pending", headers=team).json()["items"]
    application_id = pending[0]["id"]
    # « Justificatif à corriger » doit dire quoi corriger.
    assert client.post(f"/api/v1/admin/certified/pro/{application_id}/review", json={"decision": "CORRECTION"},
                       headers=team).status_code == 422
    client.post(f"/api/v1/admin/certified/pro/{application_id}/review",
                json={"decision": "CORRECTION", "note": "Photo illisible"}, headers=team)
    corrected = client.get("/api/v1/certified/pro/me", headers=pro).json()
    assert corrected["status"] == "CORRECTION" and corrected["review_note"] == "Photo illisible"

    client.post("/api/v1/certified/pro/apply", json={
        "business_name": "Boutique Amégan", "activity": "Couture", "document_media_id": _upload(client, pro),
    }, headers=pro)
    client.post(f"/api/v1/admin/certified/pro/{application_id}/review", json={"decision": "APPROVE"}, headers=team)

    payment = client.post("/api/v1/certified/subscribe", json={"plan": "PRO_MONTHLY"}, headers=pro).json()
    with TestingSessionLocal() as db:
        db_payment = db.query(MarketplacePayment).get(payment["payment_id"])
        db_payment.metadata_json = {**db_payment.metadata_json, "payer_name": "AMEGAN Kossi"}
        db.commit()
    _confirm(payment["payment_id"])
    profile = client.get(f"/api/v1/certified/profile/{pro_id}", headers=stranger).json()
    assert profile == {
        "user_id": pro_id, "badge": "PRO", "display_name": "Boutique Amégan",
        "managed_by": "Kossi Amégan", "activity": "Couture",
    }


def test_officine_abonnee_a_le_badge_pro(client):
    pharmacist, pharmacist_id, _ = _signup(client, "Dr Ama")
    _pharmacy(pharmacist_id)
    profile = client.get(f"/api/v1/certified/profile/{pharmacist_id}", headers=pharmacist).json()
    assert profile["badge"] == "PRO" and profile["display_name"] == "Pharmacie du Bè"
    assert profile["managed_by"] == "Dr Ama"


# ── Honam ───────────────────────────────────────────────────────────────


def _pharmacy(user_id):
    with TestingSessionLocal() as db:
        pharmacy = Pharmacy(
            country="TG", name="Pharmacie du Bè", address="Bè, Lomé", phone="+22822000000",
            latitude=6.13, longitude=1.22, wallet_phone="+22890999999", wallet_verified=True,
            subscription_plan="WETRI", subscription_until=datetime.utcnow() + timedelta(days=30),
            credit_balance=5000,
        )
        db.add(pharmacy)
        db.flush()
        db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=user_id, role="TITULAIRE"))
        db.commit()
        return pharmacy.id


def _validated_courier(client, headers, user_id, **extra):
    response = client.post("/api/v1/honam/courier/join", json={
        "zones": "Bè — soirs", "wallet_phone": "+22890777777", "accept_rules": True, **extra,
    }, headers=headers)
    assert response.status_code == 200, response.text
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()
        courier.validated_at = datetime.utcnow()
        courier.referral_code = rules.new_referral_code(db)
        rules.start_trial(db, courier)
        db.commit()
        return courier.referral_code


def _ready_order(client, patient, pharmacist, pharmacy_id):
    order = client.post("/api/v1/honam/orders", json={
        "pharmacy_id": pharmacy_id, "prescription_media_id": _upload(client, patient),
        "delivery_address": "Rue 12, Tokoin", "delivery_latitude": 6.14, "delivery_longitude": 1.21,
    }, headers=patient).json()
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/quote", json={
        "items": [{"name": "Amoxicilline", "quantity": 1, "unit_price": 1500}],
    }, headers=pharmacist)
    client.post(f"/api/v1/honam/orders/{order['id']}/accept", headers=patient)
    client.post(f"/api/v1/honam/orders/{order['id']}/declare-paid", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{order['id']}/ready", headers=pharmacist)
    return order["id"]


def test_ville_non_desservie_liste_d_attente(client):
    person, _, _ = _signup(client, "Yao")
    refused = client.post("/api/v1/honam/courier/join", json={
        "zones": "Centre", "wallet_phone": "+22890777777", "accept_rules": True, "city": "Kara",
    }, headers=person)
    assert refused.status_code == 409 and refused.json()["detail"]["code"] == "waitlist"
    client.post("/api/v1/honam/waitlist", json={"city": "Kara"}, headers=person)
    info = client.get("/api/v1/honam/cities", headers=person).json()
    assert info["served_cities"] == ["Lomé"] and info["waitlist"]["city"] == "Kara"
    team, team_id, _ = _signup(client, "Équipe")
    team = _make_admin(team_id)
    counts = client.get("/api/v1/admin/honam/waitlist", headers=team).json()["items"]
    assert counts == [{"country": "TG", "city": "Kara", "role": "COURIER", "count": 1}]
    # « lome » vaut « Lomé ».
    assert client.post("/api/v1/honam/courier/join", json={
        "zones": "Bè", "wallet_phone": "+22890777777", "accept_rules": True, "city": "lome",
    }, headers=person).status_code == 200


def test_suivi_parrainage_et_vos_coursiers(client):
    pharmacist, pharmacist_id, _ = _signup(client, "Dr Ama")
    pharmacy_id = _pharmacy(pharmacist_id)
    patient, _, _ = _signup(client, "Afi")
    sponsor, sponsor_id, _ = _signup(client, "Parrain")
    code = _validated_courier(client, sponsor, sponsor_id)
    rider, rider_id, rider_phone = _signup(client, "Filleul")
    _validated_courier(client, rider, rider_id, referral_code=code)

    # Vos coursiers : le filleul est rattaché, il voit la course seul d'abord.
    attached = client.post("/api/v1/honam/pharmacy/couriers", json={"phone": rider_phone}, headers=pharmacist)
    assert attached.status_code == 201
    order_id = _ready_order(client, patient, pharmacist, pharmacy_id)
    assert [o["id"] for o in client.get("/api/v1/honam/courier/rides", headers=rider).json()["available"]] == [order_id]
    assert client.get("/api/v1/honam/courier/rides", headers=sponsor).json()["available"] == []

    client.post(f"/api/v1/honam/courier/rides/{order_id}/accept", headers=rider)
    client.post(f"/api/v1/honam/courier/rides/{order_id}/pickup", headers=rider)
    client.post(f"/api/v1/honam/courier/rides/{order_id}/location", json={"latitude": 6.135, "longitude": 1.215}, headers=rider)
    tracking = client.get(f"/api/v1/honam/orders/{order_id}/tracking", headers=patient).json()
    assert tracking["active"] and tracking["latitude"] == 6.135 and tracking["distance_km"] is not None
    assert client.get(f"/api/v1/honam/pharmacy/orders/{order_id}/tracking", headers=pharmacist).json()["active"]

    code_patient = client.get(f"/api/v1/honam/orders/{order_id}", headers=patient).json()["delivery_code"]
    client.post(f"/api/v1/honam/courier/rides/{order_id}/deliver", json={"code": code_patient}, headers=rider)
    # Jamais conservée après la livraison.
    after = client.get(f"/api/v1/honam/orders/{order_id}/tracking", headers=patient).json()
    assert after["active"] is False and after["latitude"] is None
    assert client.post(f"/api/v1/honam/courier/rides/{order_id}/location", json={"latitude": 6, "longitude": 1},
                       headers=rider).status_code == 409

    # Le parrain reçoit ses courses offertes, une seule fois.
    me = client.get("/api/v1/honam/courier/me", headers=sponsor).json()
    assert me["rides_left"] == rules.COURIER_TRIAL_RIDES + rules.REFERRAL_GIFT_RIDES
    assert me["referrals_count"] == 1 and me["recommended_pack"] == "ABLAVI"
    with TestingSessionLocal() as db:
        assert db.query(CourierLedgerEntry).filter(CourierLedgerEntry.kind == "GIFT").count() == 1

    couriers = client.get("/api/v1/honam/pharmacy/couriers", headers=pharmacist).json()["items"]
    assert couriers[0]["delivered_count"] == 1 and couriers[0]["unpaid_count"] == 1
    client.delete(f"/api/v1/honam/pharmacy/couriers/{rider_id}", headers=pharmacist)
    assert client.get("/api/v1/honam/pharmacy/couriers", headers=pharmacist).json()["items"] == []


# ── Assimé ──────────────────────────────────────────────────────────────


def _product(client, headers, **extra):
    return client.post("/api/v1/marketplace", json={
        "name": "Pagne wax", "price": "8000", "category": "MODE", "location": "Lomé", **extra,
    }, headers=headers).json()


def test_favoris_et_alertes(client):
    buyer, buyer_id, _ = _signup(client, "Acheteuse")
    seller, _, _ = _signup(client, "Vendeur")
    assert client.post("/api/v1/marketplace/alerts", json={}, headers=buyer).status_code == 422
    alert = client.post("/api/v1/marketplace/alerts", json={"query": "wax", "max_price": 10000}, headers=buyer).json()
    with patch("app.api.v1.marketplace.assime.send_push") as push:
        product = _product(client, seller)
        _product(client, seller, name="Pagne wax de luxe", price="50000")
    assert push.call_count == 1 and push.call_args.args[1] == buyer_id
    assert client.get("/api/v1/marketplace/alerts", headers=buyer).json()["items"][0]["matches_count"] == 1

    client.put(f"/api/v1/marketplace/{product['id']}/favorite", headers=buyer)
    client.put(f"/api/v1/marketplace/{product['id']}/favorite", headers=buyer)
    assert [p["id"] for p in client.get("/api/v1/marketplace/favorites", headers=buyer).json()["items"]] == [product["id"]]
    client.delete(f"/api/v1/marketplace/{product['id']}/favorite", headers=buyer)
    assert client.get("/api/v1/marketplace/favorites", headers=buyer).json()["items"] == []
    client.delete(f"/api/v1/marketplace/alerts/{alert['id']}", headers=buyer)
    assert client.get("/api/v1/marketplace/alerts", headers=buyer).json()["items"] == []


def test_statut_sponsorise_modere_reserve_au_badge_payant_et_bilan(client):
    seller, seller_id, _ = _signup(client, "Vendeur")
    viewer, _, _ = _signup(client, "Passante")
    team, team_id, _ = _signup(client, "Modération")
    team = _make_admin(team_id)
    product = _product(client, seller)
    boost = client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 7}, headers=seller).json()
    _confirm(boost["payment_id"])

    # Relue par la modération avant d'apparaître.
    assert client.get("/api/v1/marketplace/sponsored-status", headers=viewer).json()["item"] is None
    pending = client.get("/api/v1/admin/marketplace/sponsored-statuses", headers=team).json()["items"]
    boost_id = pending[0]["boost_id"]
    assert pending[0]["city"] == "Lomé"
    client.put(f"/api/v1/admin/marketplace/sponsored-statuses/{boost_id}", json={"approve": True}, headers=team)
    # Réservée aux vendeurs au badge payant.
    assert client.get("/api/v1/marketplace/sponsored-status", headers=viewer).json()["item"] is None
    with TestingSessionLocal() as db:
        db.add(CertifiedSubscription(user_id=seller_id, status="ACTIVE", first_paid_at=datetime.utcnow(),
                                     current_period_end=datetime.utcnow() + timedelta(days=30)))
        db.commit()
    shown = client.get("/api/v1/marketplace/sponsored-status?city=Lomé", headers=viewer).json()
    assert shown["item"]["label"] == "Sponsorisé" and shown["every"] == 5
    assert "jamais à partir de vos messages" in shown["item"]["why"]["text"]
    # Ciblage par ville.
    assert client.get("/api/v1/marketplace/sponsored-status?city=Kara", headers=viewer).json()["item"] is None

    client.get("/api/v1/marketplace", headers=viewer)
    client.post(f"/api/v1/marketplace/boosts/{boost_id}/contact", headers=viewer)
    report = client.get(f"/api/v1/marketplace/{product['id']}/boost/report", headers=seller).json()["items"][0]
    assert (report["days"], report["impressions"], report["status_views"], report["contacts"]) == (7, 1, 1, 1)
    assert client.get(f"/api/v1/marketplace/{product['id']}/why", headers=viewer).json()["sponsored"] is True


def test_filtre_vendeurs_certifies(client):
    seller, seller_id, _ = _signup(client, "Vendeur")
    other, _, _ = _signup(client, "Autre")
    _product(client, seller, name="Certifié")
    _product(client, other, name="Ordinaire")
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == seller_id).update({User.is_verified: True})
        db.commit()
    names = [p["name"] for p in client.get("/api/v1/marketplace?certified_only=true", headers=other).json()["items"]]
    assert names == ["Certifié"]


def test_boost_trois_jours_sans_place_dans_les_statuts(client):
    seller, _, _ = _signup(client, "Vendeur")
    product = _product(client, seller)
    boost = client.post(f"/api/v1/marketplace/{product['id']}/boost", json={"days": 3}, headers=seller).json()
    _confirm(boost["payment_id"])
    with TestingSessionLocal() as db:
        row = db.query(MarketplaceBoost).first()
        assert row.days == 3 and row.status_moderation is None


# ── Kory Plus ───────────────────────────────────────────────────────────


def _group(client, size=3):
    members = [_signup(client, f"Membre {i}") for i in range(size)]
    owner = members[0]
    for _, _, phone in members[1:]:
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": "M"}, headers=owner[0])
    group = client.post("/api/v1/groups", json={
        "name": "Tontine du quartier", "member_user_ids": [m[1] for m in members[1:]],
    }, headers=owner[0]).json()
    for headers, _, _ in members[1:]:
        for invitation in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers)
    return group["id"], members


def test_tontine_en_rotation(client):
    group_id, members = _group(client)
    (a, a_id, _), (b, b_id, _), (c, c_id, _) = members
    pot = client.post("/api/v1/kory/pots", json={
        "kind": "TONTINE", "title": "Tontine du quartier", "group_id": group_id,
        "amount_per_member": 5000, "period": "MONTHLY", "rotation": [b_id, c_id, a_id],
        "draw_mode": "FIXED",
    }, headers=a).json()
    # Kory-8 : la tontine attend que chacun accepte, puis démarre seule.
    assert pot["status"] == "PENDING" and pot["rounds"] == []
    client.post(f"/api/v1/kory/pots/{pot['id']}/accept", headers=b)
    pot = client.post(f"/api/v1/kory/pots/{pot['id']}/accept", headers=c).json()
    assert pot["status"] == "OPEN"
    assert [r["beneficiary_id"] for r in pot["rounds"]] == [b_id, c_id, a_id]
    assert pot["current_round"] == 1 and pot["collector_id"] == b_id and pot["join_code"] is None
    assert pot["rounds"][0]["expected_total"] == 10000

    # Le bénéficiaire du tour reçoit, il ne mise pas.
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 5000}, headers=b).status_code == 409
    entry = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 5000}, headers=c).json()
    assert entry["round_number"] == 1

    after = client.post(f"/api/v1/kory/pots/{pot['id']}/next-round", headers=a).json()
    assert after["current_round"] == 2 and after["collector_id"] == c_id
    # La contribution du tour 1 se confirme toujours par SON bénéficiaire.
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
                       json={"decision": "CONFIRM"}, headers=c).status_code == 403
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
                       json={"decision": "CONFIRM"}, headers=b).json()["status"] == "CONFIRMED"

    assert client.post(f"/api/v1/kory/pots/{pot['id']}/next-round", headers=b).status_code == 403
    client.post(f"/api/v1/kory/pots/{pot['id']}/next-round", headers=a)
    closed = client.post(f"/api/v1/kory/pots/{pot['id']}/next-round", headers=a).json()
    assert closed["status"] == "CLOSED" and closed["rounds"][0]["confirmed_total"] == 5000


def test_tontine_refuse_un_inconnu_dans_l_ordre(client):
    group_id, members = _group(client, size=2)
    (a, a_id, _), (_, b_id, _) = members
    _, stranger_id, _ = _signup(client, "Inconnu")
    response = client.post("/api/v1/kory/pots", json={
        "kind": "TONTINE", "title": "Tontine", "group_id": group_id,
        "amount_per_member": 5000, "period": "WEEKLY", "rotation": [a_id, stranger_id],
    }, headers=a)
    assert response.status_code == 422
