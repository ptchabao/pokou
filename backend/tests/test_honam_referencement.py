"""« Référencer votre officine » (maquettes Officine 14 à 16, migration
0027_officine_referencement) : le dossier envoyé depuis l'application, son
état lu par le pharmacien, puis la décision du support — refus motivé ou
validation qui crée l'officine et son titulaire."""
from app.models import AuditLog, Pharmacy, PharmacyStaff, ServiceNotification, User, UserRole
from tests.helpers import console_bearer
from tests.test_honam import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _pharmacy,
    _prescription,
    _signup,
    client,
    stub_mobile_money,
)

_URL = "/api/v1/honam/pharmacy/registration"


def _team(client):
    headers, uid = _signup(client)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == uid).update({User.role: UserRole.ADMIN})
        db.commit()
    return console_bearer(TestingSessionLocal, uid)


def _dossier(client, headers, **extra):
    body = {
        "name": "Pharmacie Démo", "address": "Tokoin, rue 254, Lomé", "license_number": "ARR-2019-0412",
        "wallet_phone": "96000012", "authorization_media_id": _prescription(client, headers),
        "plan": "EPE", "latitude": 6.14, "longitude": 1.21,
    }
    body.update(extra)
    return client.post(_URL, json=body, headers=headers)


def test_rien_envoye_puis_dossier_en_verification(client):
    pharmacist, _ = _signup(client)
    empty = client.get(_URL, headers=pharmacist).json()
    assert empty["status"] == "NONE" and empty["has_pharmacy"] is False
    # Les prix de l'écran 2/3 viennent du pays.
    assert empty["prices_ht"] == {"WETRI": 5000, "EPE": 50000} and empty["vat_rate"] == 0.18
    assert empty["review_hours"] == 48

    sent = _dossier(client, pharmacist)
    assert sent.status_code == 201, sent.text
    data = sent.json()
    assert data["status"] == "PENDING" and data["plan"] == "EPE"
    assert data["wallet_phone"] == "+22896000012" and data["has_authorization"] is True
    assert "authorization_media_id" not in data  # l'arrêté reste au support
    assert client.get(_URL, headers=pharmacist).json()["status"] == "PENDING"
    # Pas de second dossier pendant la vérification.
    assert _dossier(client, pharmacist).status_code == 409


def test_dossier_incomplet_ou_compte_deja_officine(client):
    pharmacist, _ = _signup(client)
    assert _dossier(client, pharmacist, authorization_media_id=None).status_code == 422
    assert _dossier(client, pharmacist, wallet_phone="12").status_code == 422
    assert _dossier(client, pharmacist, plan="GOLD").status_code == 422
    # L'arrêté d'un autre compte ne passe pas.
    other, _ = _signup(client)
    assert _dossier(client, pharmacist, authorization_media_id=_prescription(client, other)).status_code == 422
    staff, staff_id = _signup(client)
    _pharmacy(staff_id)
    assert client.get(_URL, headers=staff).json()["has_pharmacy"] is True
    assert _dossier(client, staff).status_code == 409


def test_refus_motive_puis_renvoi(client):
    pharmacist, uid = _signup(client)
    _dossier(client, pharmacist)
    team = _team(client)
    pending = client.get("/api/v1/admin/honam/pharmacy-applications", headers=team).json()["items"]
    assert [a["user_id"] for a in pending] == [uid]
    application_id = pending[0]["id"]
    review = f"/api/v1/admin/honam/pharmacy-applications/{application_id}/review"
    # Un refus sans motif n'est pas une décision.
    assert client.post(review, json={"decision": "REJECT"}, headers=team).status_code == 422
    # Le pharmacien n'administre pas son propre dossier.
    assert client.post(review, json={"decision": "APPROVE"}, headers=pharmacist).status_code in (401, 403)
    refused = client.post(review, json={"decision": "REJECT", "note": "Arrêté illisible"}, headers=team)
    assert refused.status_code == 200 and refused.json()["status"] == "REJECTED"
    state = client.get(_URL, headers=pharmacist).json()
    assert state["status"] == "REJECTED" and state["review_note"] == "Arrêté illisible"
    with TestingSessionLocal() as db:
        assert db.query(ServiceNotification).filter(ServiceNotification.user_id == uid).count() == 1
        assert db.query(Pharmacy).count() == 0
    # Renvoi : le même arrêté sert si aucun autre n'est joint.
    again = _dossier(client, pharmacist, authorization_media_id=None, license_number="ARR-2019-0413")
    assert again.status_code == 201 and again.json()["status"] == "PENDING"
    assert again.json()["review_note"] is None


def test_validation_cree_l_officine_et_son_titulaire(client):
    pharmacist, uid = _signup(client)
    _dossier(client, pharmacist, latitude=None, longitude=None)
    team = _team(client)
    application_id = client.get("/api/v1/admin/honam/pharmacy-applications", headers=team).json()["items"][0]["id"]
    review = f"/api/v1/admin/honam/pharmacy-applications/{application_id}/review"
    # Sans position, l'annuaire ne saurait pas la placer.
    assert client.post(review, json={"decision": "APPROVE"}, headers=team).status_code == 422
    approved = client.post(review, json={"decision": "APPROVE", "latitude": 6.15, "longitude": 1.22}, headers=team)
    assert approved.status_code == 200, approved.text
    pharmacy_id = approved.json()["pharmacy_id"]
    assert approved.json()["status"] == "APPROVED"
    # Une décision ne se prend qu'une fois.
    assert client.post(review, json={"decision": "REJECT", "note": "Trop tard"}, headers=team).status_code == 404
    with TestingSessionLocal() as db:
        pharmacy = db.get(Pharmacy, pharmacy_id)
        assert pharmacy.name == "Pharmacie Démo" and pharmacy.wallet_verified is True
        assert pharmacy.wallet_phone == "+22896000012" and pharmacy.subscription_until is None
        staff = db.query(PharmacyStaff).filter(PharmacyStaff.pharmacy_id == pharmacy_id).one()
        assert staff.user_id == uid and staff.role == "TITULAIRE"
        assert db.query(AuditLog).filter(AuditLog.action == "pharmacy_application_review").count() == 1
    state = client.get(_URL, headers=pharmacist).json()
    assert state["status"] == "APPROVED" and state["has_pharmacy"] is True and state["pharmacy_id"] == pharmacy_id
    # L'espace officine s'ouvre ; l'officine reste hors annuaire jusqu'au paiement.
    me = client.get("/api/v1/honam/pharmacy/me", headers=pharmacist).json()
    assert me["pharmacy"]["id"] == pharmacy_id and me["visible"] is False
