"""Console : les actions des pages de services (admin_services.py et les
routes d'administration des services qu'elles appellent). Pour chaque
geste : droit refusé, validation, ligne d'audit, effet."""
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import (
    AbuseReport, AuditLog, CertifiedProApplication, CertifiedSubscription, CourierProfile, HonamOrder,
    HonamOrderEvent, KoryEntry, KoryMember, KoryPot, KoryRound, MarketplaceAd, MarketplaceBoost,
    MarketplacePayment, MarketplaceProduct, MediaAsset, Pharmacy, PharmacyStaff, SellerReview,
    ServiceNotification, User, UserRole,
)
from tests.helpers import console_bearer

engine = create_engine("sqlite:///./test_admin_services.db", connect_args={"check_same_thread": False})
Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
API = "/api/v1/admin"


def _db():
    db = Session()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _db
    with patch("app.services.notifications.inbox.send_push"):
        yield TestClient(app)
    if previous is None:
        app.dependency_overrides.pop(get_db, None)
    else:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


_n = [0]


def _user(role=UserRole.USER, name="Ama"):
    _n[0] += 1
    with Session() as db:
        u = User(phone=f"+2289070{_n[0]:04d}", full_name=f"{name} {_n[0]}", role=role, is_active=True)
        db.add(u)
        db.commit()
        return u.id


def _team(role):
    uid = _user(role, "Equipe")
    return console_bearer(Session, uid), uid


def _audits(action):
    with Session() as db:
        return db.query(AuditLog).filter(AuditLog.action == action).all()


def _notified(user_id):
    with Session() as db:
        return [n.body for n in db.query(ServiceNotification).filter(ServiceNotification.user_id == user_id)]


# ── Accès ───────────────────────────────────────────────────────────────

def test_session_de_l_app_refusee(client):
    from fastapi import Response
    from app.api.v1.auth.auth import _issue_session
    uid = _user(UserRole.SUPER_ADMIN)
    with Session() as db:
        token, _, _ = _issue_session(db, Response(), db.get(User, uid))
    assert client.get(f"{API}/queues", headers={"Authorization": f"Bearer {token}"}).status_code == 403


def test_files_d_attente_filtrees_par_role(client):
    admin, _ = _team(UserRole.ADMIN)
    ai, _ = _team(UserRole.AI_OPERATOR)
    with Session() as db:
        target = User(phone="+22890799999", full_name="Cible", is_active=True)
        db.add(target)
        db.flush()
        db.add(AbuseReport(target_user_id=target.id, reason="spam", status="OPEN"))
        db.commit()
    keys = {q["key"]: q for q in client.get(f"{API}/queues", headers=admin).json()["items"]}
    assert keys["reports"]["count"] == 1 and "kory_contested" in keys and "couriers" in keys
    ai_keys = {q["key"] for q in client.get(f"{API}/queues", headers=ai).json()["items"]}
    assert "kory_contested" not in ai_keys and "ads" in ai_keys


def test_permissions_des_roles():
    from app.core.permissions import ALL, ROLE_PERMISSIONS
    assert "kory.manage" in ALL
    assert "kory.manage" in ROLE_PERMISSIONS[UserRole.ADMIN]
    assert {"reports.manage", "honam.manage"} <= ROLE_PERMISSIONS[UserRole.SUPPORT]
    assert "kory.manage" not in ROLE_PERMISSIONS[UserRole.SUPPORT]
    assert {"certified.manage", "reports.manage", "assime.manage"} <= ROLE_PERMISSIONS[UserRole.AI_OPERATOR]
    assert not any(p.endswith(".manage") for p in ROLE_PERMISSIONS[UserRole.VIEWER])


# ── Signalements ────────────────────────────────────────────────────────

def _report():
    target = _user()
    with Session() as db:
        r = AbuseReport(target_user_id=target, reason="insultes", status="OPEN")
        db.add(r)
        db.commit()
        return r.id, target


def test_avertir_le_compte_signale(client):
    viewer, _ = _team(UserRole.VIEWER)
    support, _ = _team(UserRole.SUPPORT)
    rid, target = _report()
    assert client.post(f"{API}/reports/{rid}/warn", json={"message": "Reste courtois"}, headers=viewer).status_code == 403
    assert client.post(f"{API}/reports/{rid}/warn", json={"message": "x"}, headers=support).status_code == 422
    done = client.post(f"{API}/reports/{rid}/warn", json={"message": "Reste courtois"}, headers=support)
    assert done.status_code == 200 and done.json()["status"] == "ACTIONED"
    assert any("Reste courtois" in b for b in _notified(target))
    assert _audits("report_warn")
    assert client.post(f"{API}/reports/{rid}/warn", json={"message": "encore"}, headers=support).status_code == 409
    detail = client.get(f"{API}/reports/{rid}", headers=viewer).json()
    assert detail["resolved_by"] and detail["history"] == []
    found = client.get(f"{API}/reports/search?status=ALL&q=insul", headers=viewer).json()
    assert found["total"] == 1


# ── Kory ────────────────────────────────────────────────────────────────

def _pot(kind="CAGNOTTE", status="OPEN"):
    organizer, member = _user(), _user()
    with Session() as db:
        pot = KoryPot(organizer_id=organizer, collector_id=organizer, kind=kind, title="Mariage Kossi",
                      join_code=f"C{_n[0]:07d}", status=status)
        db.add(pot)
        db.flush()
        db.add(KoryMember(pot_id=pot.id, user_id=member, fee_paid_at=datetime.utcnow()))
        db.add(KoryEntry(pot_id=pot.id, contributor_id=member, amount=5000, status="CONFIRMED"))
        db.add(KoryEntry(pot_id=pot.id, contributor_id=member, amount=2000, status="REJECTED",
                         review_reason="Rien reçu", proof_media_id=None))
        if kind == "TONTINE":
            db.add(KoryRound(pot_id=pot.id, number=1, beneficiary_id=organizer, status="CURRENT"))
            db.add(KoryRound(pot_id=pot.id, number=2, beneficiary_id=member, status="UPCOMING"))
        db.commit()
        return pot.id, organizer, member


def test_fiche_kory_et_recherche(client):
    viewer, _ = _team(UserRole.VIEWER)
    pot_id, _, _ = _pot()
    detail = client.get(f"{API}/kory/pots/{pot_id}", headers=viewer).json()
    assert detail["confirmed_total"] == 5000 and detail["contested"] == 1
    assert detail["members"][0]["fee_paid_at"] and detail["entries"][0]["has_proof"] is False
    assert client.get(f"{API}/kory/pots/search?q=mariage&contested=true", headers=viewer).json()["total"] == 1
    assert client.get(f"{API}/kory/pots/search?kind=TONTINE", headers=viewer).json()["total"] == 0


def test_cloturer_puis_rouvrir_sans_toucher_aux_montants(client):
    support, _ = _team(UserRole.SUPPORT)
    admin, _ = _team(UserRole.ADMIN)
    pot_id, organizer, member = _pot()
    assert client.post(f"{API}/kory/pots/{pot_id}/close", json={"reason": "arnaque"}, headers=support).status_code == 403
    assert client.post(f"{API}/kory/pots/{pot_id}/close", json={"reason": ""}, headers=admin).status_code == 422
    closed = client.post(f"{API}/kory/pots/{pot_id}/close", json={"reason": "Collecte frauduleuse"}, headers=admin)
    assert closed.status_code == 200 and closed.json()["status"] == "CLOSED"
    assert closed.json()["confirmed_total"] == 5000
    assert any("Collecte frauduleuse" in b for b in _notified(member))
    assert _audits("kory_close")[0].changes["reason"] == "Collecte frauduleuse"
    with Session() as db:
        assert sorted(e.amount for e in db.query(KoryEntry).filter(KoryEntry.pot_id == pot_id)) == [2000, 5000]
    assert client.post(f"{API}/kory/pots/{pot_id}/close", json={"reason": "encore"}, headers=admin).status_code == 409
    reopened = client.post(f"{API}/kory/pots/{pot_id}/reopen", json={"reason": "Erreur"}, headers=admin)
    assert reopened.status_code == 200 and reopened.json()["status"] == "OPEN"


def test_rouvrir_refuse_si_cloture_par_le_collecteur(client):
    admin, _ = _team(UserRole.ADMIN)
    pot_id, _, _ = _pot(status="CLOSED")
    assert client.post(f"{API}/kory/pots/{pot_id}/reopen", json={"reason": "svp"}, headers=admin).status_code == 409


def test_dissoudre_une_tontine(client):
    admin, _ = _team(UserRole.ADMIN)
    cagnotte, _, _ = _pot()
    assert client.post(f"{API}/kory/pots/{cagnotte}/dissolve", json={"reason": "fraude"}, headers=admin).status_code == 409
    pot_id, _, member = _pot(kind="TONTINE")
    assert client.post(f"{API}/kory/pots/{pot_id}/close", json={"reason": "fraude"}, headers=admin).status_code == 409
    done = client.post(f"{API}/kory/pots/{pot_id}/dissolve", json={"reason": "Membres fictifs"}, headers=admin).json()
    assert done["status"] == "CLOSED" and "Membres fictifs" in done["dissolve_reason"]
    assert [r["status"] for r in done["rounds"]] == ["DONE", "CANCELLED"]
    assert any("dissous" in b for b in _notified(member))
    assert _audits("kory_dissolve")


# ── Honam ───────────────────────────────────────────────────────────────

def _pharmacy(status="ACTIVE", wallet_verified=True):
    staff = _user()
    with Session() as db:
        p = Pharmacy(country="TG", name="Pharmacie du Port", address="Lomé", phone="+22822000000",
                     latitude=6.1, longitude=1.2, wallet_phone="+22890000001", wallet_verified=wallet_verified,
                     status=status)
        db.add(p)
        db.flush()
        db.add(PharmacyStaff(pharmacy_id=p.id, user_id=staff, role="TITULAIRE"))
        db.commit()
        return p.id, staff


def _order(pharmacy_id, status, declared=False):
    patient = _user()
    with Session() as db:
        o = HonamOrder(patient_id=patient, pharmacy_id=pharmacy_id, status=status, delivery_address="Bè",
                       medicines_total=8000, delivery_price=1000, prescription_media_id=None,
                       patient_note="asthme", patient_paid_declared_at=datetime.utcnow() if declared else None)
        db.add(o)
        db.flush()
        db.add(HonamOrderEvent(order_id=o.id, actor_id=patient, status="SUBMITTED", note="Ventoline"))
        db.commit()
        return o.id, patient


def test_fiche_commande_sans_donnee_de_sante(client):
    viewer, _ = _team(UserRole.VIEWER)
    pid, _ = _pharmacy()
    oid, _ = _order(pid, "SUBMITTED")
    detail = client.get(f"{API}/honam/orders/{oid}", headers=viewer).json()
    text = str(detail)
    assert "asthme" not in text and "Ventoline" not in text and "quote_items" not in detail
    assert detail["timeline"][0]["by"] == "Patient" and detail["can_cancel"] is True
    assert client.get(f"{API}/honam/orders/search?q=%23{oid}", headers=viewer).json()["total"] == 1


def test_annuler_une_commande_payee_ouvre_le_remboursement(client):
    viewer, _ = _team(UserRole.VIEWER)
    support, _ = _team(UserRole.SUPPORT)
    pid, _ = _pharmacy()
    oid, patient = _order(pid, "PAID")
    assert client.post(f"{API}/honam/orders/{oid}/cancel", json={"reason": "litige"}, headers=viewer).status_code == 403
    assert client.post(f"{API}/honam/orders/{oid}/cancel", json={"reason": "x"}, headers=support).status_code == 422
    with patch("app.services.honam.order_notifications.notify_order_state_changed"):
        done = client.post(f"{API}/honam/orders/{oid}/cancel", json={"reason": "Produit périmé livré"}, headers=support)
    assert done.status_code == 200
    body = done.json()
    assert body["status"] == "CANCELLED" and body["refund_due"] == 9000 and body["refund_pending"]
    assert _audits("honam_order_cancel")[0].changes["refund_due"] == 9000
    assert client.post(f"{API}/honam/orders/{oid}/cancel", json={"reason": "encore"}, headers=support).status_code == 409


def test_annuler_sans_paiement_ne_cree_pas_de_remboursement(client):
    support, _ = _team(UserRole.SUPPORT)
    pid, _ = _pharmacy()
    oid, _ = _order(pid, "QUOTED")
    done = client.post(f"{API}/honam/orders/{oid}/cancel", json={"reason": "Doublon"}, headers=support).json()
    assert done["status"] == "CANCELLED" and done["refund_due"] == 0


def test_officine_suspendre_reactiver_valider(client):
    viewer, _ = _team(UserRole.VIEWER)
    support, _ = _team(UserRole.SUPPORT)
    pid, staff = _pharmacy(wallet_verified=False)
    assert client.get(f"{API}/honam/pharmacies/search?status=TO_VALIDATE", headers=viewer).json()["total"] == 1
    assert client.post(f"{API}/honam/pharmacies/{pid}/suspend", json={"reason": "plainte"}, headers=viewer).status_code == 403
    suspended = client.post(f"{API}/honam/pharmacies/{pid}/suspend", json={"reason": "Plaintes répétées"}, headers=support).json()
    assert suspended["status"] == "SUSPENDED" and "Plaintes" in suspended["suspension_reason"]
    assert any("suspendue" in b for b in _notified(staff))
    back = client.post(f"{API}/honam/pharmacies/{pid}/reactivate", json={"reason": "Réglé"}, headers=support).json()
    assert back["status"] == "ACTIVE" and len(back["team_actions"]) == 2
    assert client.post(f"/api/v1/admin/honam/pharmacies/{pid}/verify-wallet", headers=support).status_code == 200
    assert _audits("pharmacy_verify_wallet")
    assert client.post(f"/api/v1/admin/honam/pharmacies/{pid}/exclude", json={"reason": "Fraude"}, headers=support).status_code == 200
    assert _audits("pharmacy_exclude")


def _courier(status="PENDING"):
    uid = _user()
    with Session() as db:
        db.add(CourierProfile(user_id=uid, country="TG", status=status, city="Lomé", wallet_phone="+22890000002",
                              defaults_count=3 if status == "SUSPENDED" else 0,
                              trial_ends_at=datetime.utcnow() + timedelta(days=10)))
        db.commit()
    return uid


def test_coursiers_candidatures_et_suspension(client):
    viewer, _ = _team(UserRole.VIEWER)
    support, _ = _team(UserRole.SUPPORT)
    a, b, c = _courier(), _courier(), _courier("SUSPENDED")
    assert client.get(f"{API}/honam/couriers?status=PENDING", headers=viewer).json()["total"] == 2
    assert client.post(f"{API}/honam/couriers/{a}/reject", json={"reason": "Pièce illisible"}, headers=viewer).status_code == 403
    info = client.post(f"{API}/honam/couriers/{a}/request-info", json={"reason": "Ajoute ta zone"}, headers=support)
    assert info.json()["status"] == "PENDING" and any("Ajoute ta zone" in m for m in _notified(a))
    assert client.post(f"{API}/honam/couriers/{a}/reject", json={"reason": "Hors zone"}, headers=support).json()["status"] == "REJECTED"
    assert client.post(f"{API}/honam/couriers/{a}/reject", json={"reason": "Hors zone"}, headers=support).status_code == 409
    with Session() as db:
        from app.services.honam import rules
        ok, why = rules.courier_can_accept(db, db.query(CourierProfile).filter(CourierProfile.user_id == a).one())
        assert not ok and why == "Candidature non retenue"
    assert client.post(f"/api/v1/admin/honam/couriers/{b}/validate", headers=support).json()["status"] == "TRIAL"
    assert _audits("courier_validate")
    assert client.post(f"{API}/honam/couriers/{b}/suspend", json={"reason": "Retards"}, headers=support).json()["status"] == "SUSPENDED"
    reinstated = client.post(f"{API}/honam/couriers/{c}/reinstate", json={"reason": "Appel"}, headers=support).json()
    assert reinstated["status"] == "TRIAL"
    with Session() as db:
        assert db.query(CourierProfile).filter(CourierProfile.user_id == c).one().defaults_count == 0
    assert {x.action for x in Session().query(AuditLog)} >= {"courier_reject", "courier_request_info", "courier_suspend", "courier_reinstate"}


# ── Assimé ──────────────────────────────────────────────────────────────

def _payment(user_id, kind="AD"):
    with Session() as db:
        p = MarketplacePayment(user_id=user_id, kind=kind, amount=1000, status="CONFIRMED")
        db.add(p)
        db.commit()
        return p.id


def test_assime_vendeurs_avis_et_mise_en_avant(client):
    viewer, _ = _team(UserRole.VIEWER)
    ai, _ = _team(UserRole.AI_OPERATOR)
    seller, author = _user(), _user()
    pay = _payment(seller, "BOOST")
    with Session() as db:
        db.query(User).filter(User.id == seller).update({User.is_certified_seller: True})
        product = MarketplaceProduct(seller_id=seller, name="Pagne wax", price=5000)
        db.add(product)
        db.flush()
        now = datetime.utcnow()
        db.add(MarketplaceBoost(seller_id=seller, product_id=product.id, payment_id=pay, starts_at=now,
                                expires_at=now + timedelta(days=7), days=7, status_moderation="PENDING"))
        review = SellerReview(seller_id=seller, author_id=author, rating=1, comment="Arnaqueur !!!")
        db.add(review)
        db.commit()
        product_id, review_id = product.id, review.id
    detail = client.get(f"{API}/marketplace/products/{product_id}", headers=viewer).json()
    assert detail["seller"]["is_certified_seller"] and detail["boosts"][0]["status_moderation"] == "PENDING"
    assert client.get(f"{API}/marketplace/sellers?q=", headers=viewer).json()["items"][0]["reviews"] == 1
    assert client.get(f"{API}/marketplace/boosts?state=pending", headers=viewer).json()["total"] == 1
    boost_id = client.get(f"{API}/marketplace/boosts?state=pending", headers=viewer).json()["items"][0]["id"]
    assert client.put(f"{API}/marketplace/sponsored-statuses/{boost_id}", json={"approve": False}, headers=viewer).status_code == 403
    assert client.put(f"{API}/marketplace/sponsored-statuses/{boost_id}", json={"approve": False, "reason": "Image trompeuse"},
                      headers=ai).json()["status_moderation"] == "REJECTED"
    assert _audits("sponsored_status_review")[0].changes["reason"] == "Image trompeuse"
    assert client.get(f"{API}/marketplace/reviews?max_rating=2", headers=viewer).json()["total"] == 1
    assert client.post(f"{API}/marketplace/reviews/{review_id}/remove", json={"reason": "Insulte"}, headers=viewer).status_code == 403
    assert client.post(f"{API}/marketplace/reviews/{review_id}/remove", json={"reason": "Insulte"}, headers=ai).status_code == 200
    assert _audits("review_remove")[0].changes["comment"] == "Arnaqueur !!!"
    revoked = client.post(f"{API}/marketplace/sellers/{seller}/revoke-badge", json={"reason": "Faux papiers"}, headers=ai)
    assert revoked.json()["is_certified_seller"] is False and _audits("seller_badge_revoke")
    assert client.post(f"{API}/marketplace/sellers/{seller}/revoke-badge", json={"reason": "encore"}, headers=ai).status_code == 404


def test_refus_de_publicite_avec_motif(client):
    ai, _ = _team(UserRole.AI_OPERATOR)
    advertiser = _user()
    pay = _payment(advertiser)
    with Session() as db:
        ad = MarketplaceAd(advertiser_id=advertiser, title="Promo", body="Gagnez 1M", payment_id=pay, status="PAID")
        db.add(ad)
        db.commit()
        ad_id = ad.id
    done = client.put(f"{API}/marketplace/ads/{ad_id}", json={"approved": False, "reason": "Promesse de gain"}, headers=ai)
    assert done.json()["status"] == "REJECTED"
    assert _audits("review")[0].changes == {"approved": False, "reason": "Promesse de gain"}


# ── Pokou certifié ──────────────────────────────────────────────────────

def test_dossier_pro_examine_journalise_et_prevenu(client):
    viewer, _ = _team(UserRole.VIEWER)
    ai, _ = _team(UserRole.AI_OPERATOR)
    owner = _user()
    with Session() as db:
        media = MediaAsset(uploader_id=owner, original_filename="rccm.pdf", mime_type="application/pdf", size_bytes=10,
                           storage_path="x")
        db.add(media)
        db.flush()
        a = CertifiedProApplication(user_id=owner, business_name="Boutique Ama", activity="Couture",
                                    document_media_id=media.id, review_due_at=datetime.utcnow() - timedelta(hours=1))
        db.add(a)
        db.commit()
        app_id = a.id
    listing = client.get(f"{API}/certified/applications?q=boutique", headers=viewer).json()
    assert listing["total"] == 1 and listing["items"][0]["overdue"] is True
    assert client.post(f"{API}/certified/pro/{app_id}/review", json={"decision": "REJECT", "note": "Faux"}, headers=viewer).status_code == 403
    assert client.post(f"{API}/certified/pro/{app_id}/review", json={"decision": "REJECT"}, headers=ai).status_code == 422
    done = client.post(f"{API}/certified/pro/{app_id}/review", json={"decision": "CORRECTION", "note": "RCCM expiré"}, headers=ai)
    assert done.json()["status"] == "CORRECTION"
    assert any("RCCM expiré" in b for b in _notified(owner))
    detail = client.get(f"{API}/certified/applications/{app_id}", headers=viewer).json()
    assert detail["history"][0]["decision"] == "CORRECTION"


def test_abonnement_particulier_noms_differents(client):
    viewer, _ = _team(UserRole.VIEWER)
    ai, _ = _team(UserRole.AI_OPERATOR)
    owner = _user()
    with Session() as db:
        db.add(CertifiedSubscription(user_id=owner, status="NAME_MISMATCH", wallet_holder_name="AMEGAN Kossi",
                                     first_paid_at=datetime.utcnow(), current_period_end=datetime.utcnow() + timedelta(days=20)))
        db.commit()
    rows = client.get(f"{API}/certified/subscriptions?status=NAME_MISMATCH", headers=viewer).json()["items"]
    assert rows[0]["wallet_holder_name"] == "AMEGAN Kossi"
    url = f"{API}/certified/subscriptions/{owner}/review"
    assert client.post(url, json={"decision": "APPROVE", "note": "Pièce vue"}, headers=viewer).status_code == 403
    assert client.post(url, json={"decision": "APPROVE"}, headers=ai).status_code == 422
    assert client.post(url, json={"decision": "CORRECTION", "note": "Mets ton nom complet"}, headers=ai).json()["status"] == "NAME_MISMATCH"
    ok = client.post(url, json={"decision": "APPROVE", "note": "Pièce vue en agence"}, headers=ai).json()
    assert ok["status"] == "ACTIVE" and ok["badge_visible"] is True
    assert client.post(url, json={"decision": "APPROVE", "note": "encore"}, headers=ai).status_code == 409
    revoked = client.post(url, json={"decision": "REJECT", "note": "Usurpation"}, headers=ai).json()
    assert revoked["status"] == "NAME_MISMATCH" and revoked["badge_visible"] is False
    assert [a.changes["decision"] for a in _audits("certified_review")] == ["CORRECTION", "APPROVE", "REJECT"]


# ── Journal d'audit ─────────────────────────────────────────────────────

def test_journal_filtres_et_export(client):
    viewer, _ = _team(UserRole.VIEWER)
    admin, admin_id = _team(UserRole.ADMIN)
    rid, _ = _report()
    client.post(f"{API}/reports/{rid}/warn", json={"message": "Attention"}, headers=admin)
    assert client.get(f"{API}/audit/search", headers=viewer).status_code == 403
    found = client.get(f"{API}/audit/search?action=report_warn&entity_type=abuse_report", headers=admin).json()
    assert found["total"] == 1 and found["items"][0]["actor_id"] == admin_id
    assert client.get(f"{API}/audit/search?action=nope", headers=admin).json()["total"] == 0
    today = datetime.utcnow().date().isoformat()
    assert client.get(f"{API}/audit/search?since={today}&until={today}&actor=Equipe", headers=admin).json()["total"] >= 1
    assert client.get(f"{API}/audit/search?since=pas-une-date", headers=admin).status_code == 422
    assert "report_warn" in client.get(f"{API}/audit/facets", headers=admin).json()["actions"]
    export = client.get(f"{API}/audit/export?action=report_warn", headers=admin)
    assert export.status_code == 200 and export.headers["content-type"].startswith("text/csv")
    lines = export.content.decode("utf-8-sig").strip().splitlines()
    assert len(lines) == 2 and "report_warn" in lines[1]
    assert _audits("audit_export")[0].changes["rows"] == 1


def test_visuel_de_publicite_lisible_par_la_moderation_seulement(client):
    from app.api.v1.auth.auth import _issue_session
    from fastapi import Response
    ai, _ = _team(UserRole.AI_OPERATOR)
    advertiser, stranger = _user(), _user()
    pay = _payment(advertiser)
    with Session() as db:
        media = MediaAsset(uploader_id=advertiser, original_filename="pub.png", mime_type="image/png",
                           size_bytes=10, storage_path="pub.png")
        db.add(media)
        db.flush()
        db.add(MarketplaceAd(advertiser_id=advertiser, title="Promo", body="Texte", payment_id=pay,
                             status="PAID", media_asset_id=media.id))
        db.commit()
        media_id = media.id
        token, _, _ = _issue_session(db, Response(), db.get(User, stranger))
    # 409 : l'accès est accordé (fichier local, pas d'URL signée) ; 404 : refusé.
    assert client.get(f"/api/v1/media/{media_id}/download-url", headers=ai).status_code == 409
    assert client.get(f"/api/v1/media/{media_id}/download-url",
                      headers={"Authorization": f"Bearer {token}"}).status_code == 404
