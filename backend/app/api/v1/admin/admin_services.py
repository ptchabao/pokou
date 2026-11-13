"""Console d'administration : les actions des pages de SERVICES.

Ce qui manquait à `admin.py` et aux routeurs d'administration des services
pour que chaque page de la console ait sa liste (recherche, filtres, pages),
sa fiche et ses gestes métier. Chaque route exige une permission
(app/core/permissions.py), chaque geste écrit une ligne d'audit.

Les règles des services restent celles des services :

- Kory : Pokou ne touche jamais l'argent. L'équipe peut CLÔTURER une
  collecte frauduleuse ou DISSOUDRE une tontine, avec un motif ; elle ne
  modifie jamais un montant ni une contribution.
- Honam : l'ordonnance ne se montre qu'à l'officine destinataire. La console
  voit les métadonnées d'une commande (étapes, montants, remboursement),
  jamais l'image ni les produits ni les notes du patient.
- Assimé et Pokou certifié : les décisions sont des décisions humaines,
  motivées, et la personne concernée est prévenue.
"""
import csv
import io
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.api.v1.admin.admin import _audit, _report_json
from app.core.database import get_db
from app.core.permissions import permissions_of, require_permission
from app.models import (
    AbuseReport, AuditLog, CertifiedProApplication, CertifiedSubscription, CourierProfile, GroupMember,
    HonamOrder, HonamOrderEvent, KoryEntry, KoryInvite, KoryMember, KoryPot, KoryRound, MarketplaceAd,
    MarketplaceBoost, MarketplacePayment, MarketplaceProduct, Pharmacy, PharmacyCourier, PharmacyStaff,
    SellerReview, SellerVerificationApplication, User, UserRole,
)
from app.services.notifications.inbox import notify

router = APIRouter(prefix="/admin", tags=["Administration · services"])


class ReasonBody(BaseModel):
    reason: str = Field(..., min_length=3, max_length=280)


def _label(user: Optional[User]) -> Optional[str]:
    if user is None:
        return None
    return user.full_name or user.email or user.phone or f"#{user.id}"


def _people(db: Session, ids) -> dict:
    ids = {i for i in ids if i}
    return {u.id: u for u in db.query(User).filter(User.id.in_(ids)).all()} if ids else {}


def _iso(value) -> Optional[str]:
    return value.isoformat() if value else None


def _like(q: str) -> str:
    escaped = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _page(query, page: int, size: int):
    total = query.count()
    return total, query.offset((page - 1) * size).limit(size).all()


# ── Tableau de bord : les files d'attente ───────────────────────────────

@router.get("/queues")
def queues(user: User = Depends(require_permission("dashboard.view")), db: Session = Depends(get_db)):
    """Ce qui attend une décision humaine, avec la page où la prendre.
    Une file que le rôle ne peut pas voir n'est pas renvoyée."""
    perms = permissions_of(user)
    now = datetime.utcnow()

    def n(query) -> int:
        return int(query.scalar() or 0)

    items = []

    def add(key, label, count, href, perm, urgent=0):
        if perm in perms:
            items.append({"key": key, "label": label, "count": count, "urgent": urgent, "href": href})

    add("reports", "Signalements ouverts",
        n(db.query(func.count(AbuseReport.id)).filter(AbuseReport.status == "OPEN")),
        "/reports/", "reports.view")
    add("certified_pro", "Dossiers Pro à examiner",
        n(db.query(func.count(CertifiedProApplication.id)).filter(CertifiedProApplication.status == "PENDING")),
        "/certified/", "certified.view",
        urgent=n(db.query(func.count(CertifiedProApplication.id)).filter(
            CertifiedProApplication.status == "PENDING", CertifiedProApplication.review_due_at < now)))
    add("certified_names", "Noms différents (Pokou certifié)",
        n(db.query(func.count(CertifiedSubscription.id)).filter(CertifiedSubscription.status == "NAME_MISMATCH")),
        "/certified/?tab=subscriptions", "certified.view")
    add("ads", "Publicités à relire",
        n(db.query(func.count(MarketplaceAd.id)).filter(MarketplaceAd.status == "PAID")),
        "/assime/?tab=ads", "assime.view")
    add("sponsored", "Statuts sponsorisés à relire",
        n(db.query(func.count(MarketplaceBoost.id)).filter(MarketplaceBoost.status_moderation == "PENDING")),
        "/assime/?tab=boosts", "assime.view")
    add("sellers", "Vendeurs à vérifier",
        n(db.query(func.count(SellerVerificationApplication.id)).filter(SellerVerificationApplication.status == "PENDING")),
        "/assime/?tab=verifications", "assime.view")
    add("pharmacies", "Officines à valider (wallet)",
        n(db.query(func.count(Pharmacy.id)).filter(Pharmacy.wallet_verified.is_(False), Pharmacy.status != "EXCLUDED")),
        "/honam/?tab=pharmacies", "honam.view")
    add("couriers", "Candidatures de coursiers",
        n(db.query(func.count(CourierProfile.id)).filter(CourierProfile.status == "PENDING")),
        "/honam/?tab=couriers", "honam.view")
    add("refunds", "Remboursements Honam en attente",
        n(db.query(func.count(HonamOrder.id)).filter(HonamOrder.refund_due > 0, HonamOrder.refund_confirmed_at.is_(None))),
        "/honam/", "honam.view")
    add("kory_contested", "Contributions Kory contestées",
        n(db.query(func.count(KoryEntry.id)).join(KoryPot, KoryPot.id == KoryEntry.pot_id).filter(
            KoryEntry.status == "REJECTED", KoryPot.status != "CLOSED")),
        "/kory/", "kory.view")
    return {"items": items}


# ── Signalements ────────────────────────────────────────────────────────

@router.get("/reports/search")
def reports_search(
    q: Optional[str] = Query(None, max_length=80),
    status: str = Query("OPEN", pattern="^(OPEN|DISMISSED|ACTIONED|ALL)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("reports.view")),
    db: Session = Depends(get_db),
):
    query = db.query(AbuseReport)
    if status != "ALL":
        query = query.filter(AbuseReport.status == status)
    if q:
        like = _like(q)
        targets = db.query(User.id).filter(or_(User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))
        query = query.filter(or_(AbuseReport.target_user_id.in_(targets), AbuseReport.reason.ilike(like, escape="\\")))
    total, rows = _page(query.order_by(AbuseReport.created_at.desc()), page, size)
    return {"items": [_report_json(db, r) for r in rows], "total": total, "page": page, "size": size}


@router.get("/reports/{report_id}")
def report_detail(report_id: int, user: User = Depends(require_permission("reports.view")), db: Session = Depends(get_db)):
    r = db.get(AbuseReport, report_id)
    if r is None:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    history = (
        db.query(AbuseReport).filter(AbuseReport.target_user_id == r.target_user_id, AbuseReport.id != r.id)
        .order_by(AbuseReport.created_at.desc()).limit(20).all()
    )
    resolver = db.get(User, r.resolved_by) if r.resolved_by else None
    return {
        **_report_json(db, r),
        "resolved_by": _label(resolver),
        "history": [{"id": h.id, "status": h.status, "reason": h.reason, "resolution": h.resolution,
                     "created_at": h.created_at.isoformat()} for h in history],
    }


class WarnBody(BaseModel):
    message: str = Field(..., min_length=3, max_length=280)


@router.post("/reports/{report_id}/warn")
def warn_reported(
    report_id: int, body: WarnBody, request: Request,
    user: User = Depends(require_permission("reports.manage")),
    db: Session = Depends(get_db),
):
    """Avertir le compte signalé : un message de l'équipe dans son centre de
    notifications, sans suspension. Le signalement est marqué « sanctionné »."""
    r = db.get(AbuseReport, report_id)
    if r is None:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if r.status != "OPEN":
        raise HTTPException(status_code=409, detail="Ce signalement est déjà traité")
    message = body.message.strip()
    notify(db, [r.target_user_id], service="pokou", title="Avertissement de l'équipe Pokou", body=message)
    r.status = "ACTIONED"
    r.resolution = f"Avertissement : {message}"[:280]
    r.resolved_by = user.id
    r.resolved_at = datetime.utcnow()
    _audit(db, user, "report_warn", "abuse_report", r.id, {"message": message, "target_user_id": r.target_user_id}, request)
    db.commit()
    return _report_json(db, r)


# ── Kory ────────────────────────────────────────────────────────────────

def _pot_summary(db: Session, p: KoryPot, people: dict) -> dict:
    confirmed = db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.pot_id == p.id, KoryEntry.status == "CONFIRMED").scalar() or 0
    counts = dict(db.query(KoryEntry.status, func.count(KoryEntry.id)).filter(
        KoryEntry.pot_id == p.id).group_by(KoryEntry.status).all())
    return {
        "id": p.id, "title": p.title, "kind": p.kind, "status": p.status,
        "goal_amount": p.goal_amount, "amount_per_member": p.amount_per_member, "period": p.period,
        "confirmed_total": int(confirmed),
        "pending": int(counts.get("DECLARED", 0)), "contested": int(counts.get("REJECTED", 0)),
        "organizer": _label(people.get(p.organizer_id)), "organizer_id": p.organizer_id,
        "collector": _label(people.get(p.collector_id)), "collector_id": p.collector_id,
        "due_at": _iso(p.due_at), "created_at": p.created_at.isoformat(), "closed_at": _iso(p.closed_at),
        "dissolved_at": _iso(p.dissolved_at), "dissolve_reason": p.dissolve_reason,
    }


@router.get("/kory/pots/search")
def kory_search(
    q: Optional[str] = Query(None, max_length=80),
    kind: Optional[str] = Query(None, pattern="^(CAGNOTTE|COTISATION|TONTINE)$"),
    status: Optional[str] = Query(None, pattern="^(OPEN|CLOSED|PENDING)$"),
    contested: bool = False,
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("kory.view")),
    db: Session = Depends(get_db),
):
    query = db.query(KoryPot)
    if kind:
        query = query.filter(KoryPot.kind == kind)
    if status:
        query = query.filter(KoryPot.status == status)
    if contested:
        query = query.filter(KoryPot.id.in_(db.query(KoryEntry.pot_id).filter(KoryEntry.status == "REJECTED")))
    if q:
        like = _like(q)
        organizers = db.query(User.id).filter(or_(User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))
        conds = [KoryPot.title.ilike(like, escape="\\"), KoryPot.join_code == q.strip().upper(),
                 KoryPot.organizer_id.in_(organizers)]
        if q.strip().isdigit():
            conds.append(KoryPot.id == int(q.strip()))
        query = query.filter(or_(*conds))
    total, rows = _page(query.order_by(KoryPot.created_at.desc()), page, size)
    people = _people(db, {p.organizer_id for p in rows} | {p.collector_id for p in rows})
    return {"items": [_pot_summary(db, p, people) for p in rows], "total": total, "page": page, "size": size}


def _get_pot(db: Session, pot_id: int) -> KoryPot:
    pot = db.get(KoryPot, pot_id)
    if pot is None:
        raise HTTPException(status_code=404, detail="Collecte introuvable")
    return pot


@router.get("/kory/pots/{pot_id}")
def kory_detail(pot_id: int, user: User = Depends(require_permission("kory.view")), db: Session = Depends(get_db)):
    """La fiche d'une collecte : membres, tours, journal, contestations et
    frais Kory Plus. Lecture seule : les montants sont ceux déclarés et
    confirmés entre membres."""
    pot = _get_pot(db, pot_id)
    members = db.query(KoryMember).filter(KoryMember.pot_id == pot.id).order_by(KoryMember.joined_at).all()
    rounds = db.query(KoryRound).filter(KoryRound.pot_id == pot.id).order_by(KoryRound.number).all()
    entries = db.query(KoryEntry).filter(KoryEntry.pot_id == pot.id).order_by(KoryEntry.declared_at.desc()).limit(500).all()
    invites = db.query(KoryInvite).filter(KoryInvite.pot_id == pot.id, KoryInvite.joined_user_id.is_(None)).count()
    fee_payments = {
        p.id: p for p in db.query(MarketplacePayment).filter(
            MarketplacePayment.id.in_([m.fee_payment_id for m in members if m.fee_payment_id]))
    } if any(m.fee_payment_id for m in members) else {}
    people = _people(db, {pot.organizer_id, pot.collector_id, pot.deputy_id}
                     | {m.user_id for m in members} | {r.beneficiary_id for r in rounds}
                     | {e.contributor_id for e in entries})
    group_members = (
        db.query(func.count(GroupMember.id)).filter(GroupMember.group_id == pot.group_id).scalar() or 0
        if pot.group_id else 0
    )
    confirmed_by_user = dict(db.query(KoryEntry.contributor_id, func.sum(KoryEntry.amount)).filter(
        KoryEntry.pot_id == pot.id, KoryEntry.status == "CONFIRMED").group_by(KoryEntry.contributor_id).all())
    team_actions = (
        db.query(AuditLog).filter(AuditLog.entity_type == "kory_pot", AuditLog.entity_id == pot.id)
        .order_by(AuditLog.created_at.desc()).all()
    )
    actors = _people(db, {a.user_id for a in team_actions})
    return {
        **_pot_summary(db, pot, people),
        "description": pot.description,
        "beneficiary_name": pot.beneficiary_name,
        "deputy": _label(people.get(pot.deputy_id)),
        "group_id": pot.group_id, "group_members": int(group_members),
        "join_code": pot.join_code,
        "draw_mode": pot.draw_mode, "draw_seal": pot.draw_seal, "drawn_at": _iso(pot.drawn_at),
        "ends_at": _iso(pot.ends_at),
        "pending_invites": invites,
        "members": [{
            "user_id": m.user_id, "name": _label(people.get(m.user_id)),
            "joined_at": m.joined_at.isoformat(),
            "accepted_at": _iso(m.accepted_at), "declined_at": _iso(m.declined_at),
            "pledge_base": m.pledge_base, "pledge_daily": m.pledge_daily,
            "pledge_cancelled_at": _iso(m.pledge_cancelled_at),
            "confirmed_total": int(confirmed_by_user.get(m.user_id) or 0),
            "fee_paid_at": _iso(m.fee_paid_at),
            "fee_amount": fee_payments[m.fee_payment_id].amount if m.fee_payment_id in fee_payments else None,
            "fee_status": fee_payments[m.fee_payment_id].status if m.fee_payment_id in fee_payments else None,
        } for m in members],
        "rounds": [{
            "number": r.number, "beneficiary": _label(people.get(r.beneficiary_id)),
            "status": r.status, "due_at": _iso(r.due_at), "closed_at": _iso(r.closed_at),
        } for r in rounds],
        "entries": [{
            "id": e.id, "contributor": _label(people.get(e.contributor_id)), "amount": e.amount,
            "status": e.status, "period_label": e.period_label, "round_number": e.round_number,
            "wallet_reference": e.wallet_reference, "declared_at": e.declared_at.isoformat(),
            "reviewed_at": _iso(e.reviewed_at), "review_reason": e.review_reason,
            # La capture du SMS ne se montre qu'à celui qui confirme (KOR-5).
            "has_proof": e.proof_media_id is not None,
        } for e in entries],
        "fees": {
            "paid": sum(1 for m in members if m.fee_paid_at),
            "total": sum(fee_payments[m.fee_payment_id].amount for m in members
                         if m.fee_paid_at and m.fee_payment_id in fee_payments),
        },
        "team_actions": [{
            "action": a.action, "actor": _label(actors.get(a.user_id)),
            "reason": (a.changes or {}).get("reason"), "at": a.created_at.isoformat(),
        } for a in team_actions],
    }


def _kory_participants(db: Session, pot: KoryPot) -> set:
    from app.api.v1.kory.kory import _participants
    return _participants(db, pot)


@router.post("/kory/pots/{pot_id}/close")
def kory_close(
    pot_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("kory.manage")),
    db: Session = Depends(get_db),
):
    """Clôturer une collecte frauduleuse : plus aucune déclaration n'est
    acceptée. Le journal reste intact, aucun montant n'est touché ; ce qui a
    été versé se règle entre membres, hors de Pokou."""
    from app.api.v1.kory.kory import _emit
    pot = _get_pot(db, pot_id)
    if pot.status == "CLOSED":
        raise HTTPException(status_code=409, detail="Cette collecte est déjà clôturée")
    if pot.kind == "TONTINE":
        raise HTTPException(status_code=409, detail="Une tontine se dissout : utilise « Dissoudre »")
    reason = body.reason.strip()
    previous = pot.status
    pot.status = "CLOSED"
    pot.closed_at = datetime.utcnow()
    _emit(db, pot, "kory.pot.closed_by_team")
    notify(db, _kory_participants(db, pot), service="kory", title=pot.title,
           body=f"L'équipe Pokou a clôturé cette collecte. Motif : « {reason} »", route=f"kory/{pot.id}")
    _audit(db, user, "kory_close", "kory_pot", pot.id, {"reason": reason, "from": previous}, request)
    db.commit()
    return kory_detail(pot.id, user, db)


@router.post("/kory/pots/{pot_id}/reopen")
def kory_reopen(
    pot_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("kory.manage")),
    db: Session = Depends(get_db),
):
    """Lever une clôture décidée par l'équipe (erreur, soupçon levé). Une
    collecte clôturée par son collecteur, ou une tontine dissoute, ne se
    rouvre pas d'ici."""
    pot = _get_pot(db, pot_id)
    if pot.status != "CLOSED" or pot.dissolved_at is not None:
        raise HTTPException(status_code=409, detail="Cette collecte n'est pas clôturée par l'équipe")
    last = (
        db.query(AuditLog).filter(AuditLog.entity_type == "kory_pot", AuditLog.entity_id == pot.id,
                                  AuditLog.action.in_(("kory_close", "kory_reopen")))
        .order_by(AuditLog.id.desc()).first()
    )
    if last is None or last.action != "kory_close":
        raise HTTPException(status_code=409, detail="Cette collecte a été clôturée par son collecteur")
    reason = body.reason.strip()
    pot.status = (last.changes or {}).get("from") or "OPEN"
    pot.closed_at = None
    notify(db, _kory_participants(db, pot), service="kory", title=pot.title,
           body="L'équipe Pokou a rouvert cette collecte.", route=f"kory/{pot.id}")
    _audit(db, user, "kory_reopen", "kory_pot", pot.id, {"reason": reason}, request)
    db.commit()
    return kory_detail(pot.id, user, db)


@router.post("/kory/pots/{pot_id}/dissolve")
def kory_dissolve(
    pot_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("kory.manage")),
    db: Session = Depends(get_db),
):
    """Dissoudre une tontine (KOR-30), comme son administrateur le ferait :
    plus aucun tour n'est appelé, le journal reste."""
    from app.api.v1.kory.kory import _emit, _tontine_member_ids
    from app.models.kory import KorySwap
    pot = _get_pot(db, pot_id)
    if pot.kind != "TONTINE":
        raise HTTPException(status_code=409, detail="Seule une tontine se dissout")
    if pot.status not in ("OPEN", "PENDING"):
        raise HTTPException(status_code=409, detail="Cette tontine est déjà terminée")
    now = datetime.utcnow()
    reason = body.reason.strip()
    cancelled = 0
    for round_ in db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.status != "DONE"):
        if round_.status == "CURRENT":
            round_.status = "DONE"
            round_.closed_at = now
        else:
            round_.status = "CANCELLED"
            cancelled += 1
    db.query(KorySwap).filter(
        KorySwap.pot_id == pot.id, KorySwap.status.in_(("PENDING", "ACCEPTED"))
    ).update({"status": "REFUSED", "decided_at": now}, synchronize_session=False)
    pot.status = "CLOSED"
    pot.closed_at = now
    pot.dissolved_at = now
    pot.dissolve_reason = f"Équipe Pokou : {reason}"[:280]
    _emit(db, pot, "kory.tontine.dissolved", cancelled_rounds=cancelled, by_team=True)
    members = set(_tontine_member_ids(db, pot)) | {
        m.user_id for m in db.query(KoryMember).filter(KoryMember.pot_id == pot.id)
    } | {pot.organizer_id}
    notify(db, members, service="kory", title=pot.title,
           body=f"L'équipe Pokou a dissous la tontine. Motif : « {reason} »", route=f"kory/{pot.id}")
    _audit(db, user, "kory_dissolve", "kory_pot", pot.id, {"reason": reason, "cancelled_rounds": cancelled}, request)
    db.commit()
    return kory_detail(pot.id, user, db)


# ── Honam : commandes ───────────────────────────────────────────────────

def _order_row(o: HonamOrder, pharmacies: dict, people: dict) -> dict:
    pharmacy = pharmacies.get(o.pharmacy_id)
    total = (o.medicines_total or 0) + (o.delivery_price or 0) if o.medicines_total is not None else None
    return {
        "id": o.id, "status": o.status,
        "pharmacy": pharmacy.name if pharmacy else None, "pharmacy_id": o.pharmacy_id,
        "patient": _label(people.get(o.patient_id)),
        "courier": _label(people.get(o.courier_id)),
        "total": total,
        "refund_due": o.refund_due or 0,
        "refund_pending": bool(o.refund_due and not o.refund_confirmed_at),
        "created_at": o.created_at.isoformat(), "updated_at": _iso(o.updated_at),
    }


@router.get("/honam/orders/search")
def honam_orders_search(
    q: Optional[str] = Query(None, max_length=80),
    status: Optional[str] = Query(None, max_length=12),
    pharmacy_id: Optional[int] = None,
    refund: bool = False,
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("honam.view")),
    db: Session = Depends(get_db),
):
    query = db.query(HonamOrder)
    if status:
        query = query.filter(HonamOrder.status == status)
    if pharmacy_id:
        query = query.filter(HonamOrder.pharmacy_id == pharmacy_id)
    if refund:
        query = query.filter(HonamOrder.refund_due > 0, HonamOrder.refund_confirmed_at.is_(None))
    if q:
        text = q.strip().lstrip("#")
        conds = [HonamOrder.pharmacy_id.in_(db.query(Pharmacy.id).filter(Pharmacy.name.ilike(_like(text), escape="\\")))]
        if text.isdigit():
            conds.append(HonamOrder.id == int(text))
        query = query.filter(or_(*conds))
    total, rows = _page(query.order_by(HonamOrder.created_at.desc()), page, size)
    pharmacies = {p.id: p for p in db.query(Pharmacy).filter(Pharmacy.id.in_({o.pharmacy_id for o in rows}))} if rows else {}
    people = _people(db, {o.patient_id for o in rows} | {o.courier_id for o in rows})
    return {"items": [_order_row(o, pharmacies, people) for o in rows], "total": total, "page": page, "size": size}


def _get_order(db: Session, order_id: int) -> HonamOrder:
    order = db.get(HonamOrder, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    return order


@router.get("/honam/orders/{order_id}")
def honam_order_detail(order_id: int, user: User = Depends(require_permission("honam.view")), db: Session = Depends(get_db)):
    """Métadonnées seulement (HON-04) : ni l'ordonnance, ni les produits, ni
    la note du patient, ni les notes des étapes (elles peuvent nommer un
    médicament). L'étape, la date, qui l'a franchie, les montants."""
    order = _get_order(db, order_id)
    pharmacy = db.get(Pharmacy, order.pharmacy_id)
    events = db.query(HonamOrderEvent).filter(HonamOrderEvent.order_id == order.id).order_by(HonamOrderEvent.id).all()
    people = _people(db, {order.patient_id, order.courier_id} | {e.actor_id for e in events})
    staff = {s.user_id for s in db.query(PharmacyStaff).filter(PharmacyStaff.pharmacy_id == order.pharmacy_id)}

    def role(actor_id):
        if actor_id is None:
            return "Système"
        if actor_id == order.patient_id:
            return "Patient"
        if actor_id in staff:
            return "Officine"
        if actor_id == order.courier_id:
            return "Coursier"
        actor = people.get(actor_id)
        if actor is not None and (actor.role or UserRole.USER) != UserRole.USER:
            return "Équipe Pokou"
        return "Autre"

    data = _order_row(order, {order.pharmacy_id: pharmacy} if pharmacy else {}, people)
    from app.services.honam.rules import TRANSITIONS
    data.update({
        "medicines_total": order.medicines_total,
        "delivery_price": order.delivery_price,
        "has_prescription": order.prescription_media_id is not None,
        "original_required": bool(order.original_required),
        "patient_paid_declared_at": _iso(order.patient_paid_declared_at),
        "payment_not_received_at": _iso(order.payment_not_received_at),
        "missing_amount": order.missing_amount,
        "missing_choice": order.missing_choice,
        "refund_requested_at": _iso(order.refund_requested_at),
        "refund_reason": order.refund_reason,
        "refund_confirmed_at": _iso(order.refund_confirmed_at),
        "courier_paid_at": _iso(order.courier_paid_at),
        "delivered_at": _iso(order.delivered_at),
        "can_cancel": "CANCELLED" in TRANSITIONS.get(order.status, set()),
        "refund_on_cancel": order.status == "PAID" or (order.status == "ACCEPTED" and order.patient_paid_declared_at is not None),
        "timeline": [{
            "status": e.status, "by": role(e.actor_id), "at": e.created_at.isoformat(),
            # Les notes de l'équipe sont les siennes : elles se montrent.
            "note": e.note if role(e.actor_id) == "Équipe Pokou" else None,
        } for e in events],
    })
    return data


class CancelOrderBody(ReasonBody):
    refund: bool = True


@router.post("/honam/orders/{order_id}/cancel")
def honam_order_cancel(
    order_id: int, body: CancelOrderBody, request: Request,
    user: User = Depends(require_permission("honam.manage")),
    db: Session = Depends(get_db),
):
    """Annuler une commande pour cause de litige. Si le patient a payé
    l'officine (wallet à wallet), le remboursement complet lui est dû : le
    flux existant prend le relais (2 h pour rembourser, sinon suspension
    automatique de l'officine, HON-35 ; le patient confirme la réception)."""
    from app.services.honam import rules
    from app.services.honam.order_notifications import notify_order_state_changed
    order = _get_order(db, order_id)
    reason = body.reason.strip()
    # Paiement confirmé par l'officine : le remboursement est dû, toujours.
    # Paiement seulement déclaré par le patient : à l'équipe d'en juger.
    confirmed = order.status == "PAID"
    declared = order.status == "ACCEPTED" and order.patient_paid_declared_at is not None
    try:
        rules.transition(db, order, "CANCELLED", user.id, f"Annulée par l'équipe Pokou (litige) : {reason}")
    except rules.TransitionError:
        raise HTTPException(status_code=409, detail="Cette commande ne peut plus être annulée à cette étape")
    refund = 0
    if (confirmed or (declared and body.refund)) and not order.refund_due:
        refund = (order.medicines_total or 0) + (order.delivery_price or 0)
        if refund > 0:
            order.refund_due = refund
            order.refund_requested_at = datetime.utcnow()
            order.refund_reason = f"Litige : {reason}"[:255]
    _audit(db, user, "honam_order_cancel", "honam_order", order.id, {"reason": reason, "refund_due": refund}, request)
    db.commit()
    notify_order_state_changed(db, order, actor_id=user.id)
    return honam_order_detail(order.id, user, db)


# ── Honam : officines ───────────────────────────────────────────────────

def _pharmacy_row(db: Session, p: Pharmacy) -> dict:
    return {
        "id": p.id, "name": p.name, "country": p.country, "address": p.address, "phone": p.phone,
        "status": p.status, "suspension_reason": p.suspension_reason,
        "wallet_phone": p.wallet_phone, "wallet_verified": bool(p.wallet_verified),
        "subscription_plan": p.subscription_plan, "subscription_until": _iso(p.subscription_until),
        "subscription_active": bool(p.subscription_until and p.subscription_until > datetime.utcnow()),
        "credit_balance": p.credit_balance, "is_on_duty": bool(p.is_on_duty),
        "created_at": p.created_at.isoformat(),
    }


@router.get("/honam/pharmacies/search")
def honam_pharmacies_search(
    q: Optional[str] = Query(None, max_length=80),
    status: Optional[str] = Query(None, pattern="^(ACTIVE|SUSPENDED|EXCLUDED|TO_VALIDATE)$"),
    country: Optional[str] = Query(None, min_length=2, max_length=2),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("honam.view")),
    db: Session = Depends(get_db),
):
    query = db.query(Pharmacy)
    if status == "TO_VALIDATE":
        query = query.filter(Pharmacy.wallet_verified.is_(False), Pharmacy.status != "EXCLUDED")
    elif status:
        query = query.filter(Pharmacy.status == status)
    if country:
        query = query.filter(Pharmacy.country == country.upper())
    if q:
        like = _like(q)
        query = query.filter(or_(Pharmacy.name.ilike(like, escape="\\"), Pharmacy.address.ilike(like, escape="\\"),
                                 Pharmacy.phone.ilike(like, escape="\\")))
    total, rows = _page(query.order_by(Pharmacy.name), page, size)
    return {"items": [_pharmacy_row(db, p) for p in rows], "total": total, "page": page, "size": size}


def _get_pharmacy(db: Session, pharmacy_id: int) -> Pharmacy:
    pharmacy = db.get(Pharmacy, pharmacy_id)
    if pharmacy is None:
        raise HTTPException(status_code=404, detail="Officine introuvable")
    return pharmacy


@router.get("/honam/pharmacies/{pharmacy_id}")
def honam_pharmacy_detail(pharmacy_id: int, user: User = Depends(require_permission("honam.view")), db: Session = Depends(get_db)):
    p = _get_pharmacy(db, pharmacy_id)
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.pharmacy_id == p.id).all()
    couriers = db.query(CourierProfile).join(PharmacyCourier, PharmacyCourier.courier_id == CourierProfile.id).filter(
        PharmacyCourier.pharmacy_id == p.id).all()
    people = _people(db, {s.user_id for s in staff} | {c.user_id for c in couriers})
    orders = dict(db.query(HonamOrder.status, func.count(HonamOrder.id)).filter(
        HonamOrder.pharmacy_id == p.id).group_by(HonamOrder.status).all())
    refunds = db.query(func.count(HonamOrder.id)).filter(
        HonamOrder.pharmacy_id == p.id, HonamOrder.refund_due > 0, HonamOrder.refund_confirmed_at.is_(None)).scalar() or 0
    actions = db.query(AuditLog).filter(AuditLog.entity_type == "pharmacy", AuditLog.entity_id == p.id).order_by(
        AuditLog.created_at.desc()).limit(20).all()
    actors = _people(db, {a.user_id for a in actions})
    return {
        **_pharmacy_row(db, p),
        "opening_hours": p.opening_hours,
        "staff": [{"name": _label(people.get(s.user_id)), "phone": people[s.user_id].phone if s.user_id in people else None,
                   "role": s.role} for s in staff],
        "couriers": [{"name": _label(people.get(c.user_id)), "status": c.status} for c in couriers],
        "orders_by_status": {k: int(v) for k, v in orders.items()},
        "refunds_pending": int(refunds),
        "team_actions": [{"action": a.action, "actor": _label(actors.get(a.user_id)),
                          "reason": (a.changes or {}).get("reason"), "at": a.created_at.isoformat()} for a in actions],
    }


@router.post("/honam/pharmacies/{pharmacy_id}/suspend")
def honam_pharmacy_suspend(
    pharmacy_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")),
    db: Session = Depends(get_db),
):
    """Suspension décidée par l'équipe : l'officine disparaît de l'annuaire
    et ne reçoit plus d'ordonnance. Elle ne se lève pas toute seule (seules
    les suspensions automatiques de HON-35 le font)."""
    p = _get_pharmacy(db, pharmacy_id)
    if p.status != "ACTIVE":
        raise HTTPException(status_code=409, detail="Cette officine n'est pas active")
    reason = body.reason.strip()
    p.status = "SUSPENDED"
    p.suspension_reason = f"Équipe Pokou : {reason}"[:255]
    staff = [s.user_id for s in db.query(PharmacyStaff).filter(PharmacyStaff.pharmacy_id == p.id)]
    notify(db, staff, service="honam", title=p.name, body=f"Officine suspendue par l'équipe Pokou. Motif : « {reason} »")
    _audit(db, user, "pharmacy_suspend", "pharmacy", p.id, {"reason": reason}, request)
    db.commit()
    return honam_pharmacy_detail(p.id, user, db)


@router.post("/honam/pharmacies/{pharmacy_id}/reactivate")
def honam_pharmacy_reactivate(
    pharmacy_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")),
    db: Session = Depends(get_db),
):
    """Lever une suspension ou une exclusion. Si une obligation est encore
    en retard (remboursement, course impayée), la règle HON-35 la suspend
    de nouveau aussitôt : la réponse le dit."""
    from app.services.honam import rules
    p = _get_pharmacy(db, pharmacy_id)
    if p.status == "ACTIVE":
        raise HTTPException(status_code=409, detail="Cette officine est déjà active")
    previous = p.status
    p.status = "ACTIVE"
    p.suspension_reason = None
    rules.refresh_pharmacy_status(db, p)
    _audit(db, user, "pharmacy_reactivate", "pharmacy", p.id,
           {"reason": body.reason.strip(), "from": previous, "result": p.status}, request)
    db.commit()
    return honam_pharmacy_detail(p.id, user, db)


# ── Honam : coursiers ───────────────────────────────────────────────────

@router.get("/honam/couriers")
def honam_couriers(
    q: Optional[str] = Query(None, max_length=80),
    status: Optional[str] = Query(None, pattern="^(PENDING|TRIAL|MEMBER|ENDED|SUSPENDED|REJECTED)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("honam.view")),
    db: Session = Depends(get_db),
):
    query = db.query(CourierProfile)
    if status:
        query = query.filter(CourierProfile.status == status)
    if q:
        like = _like(q)
        query = query.filter(or_(
            CourierProfile.user_id.in_(db.query(User.id).filter(or_(
                User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))),
            CourierProfile.city.ilike(like, escape="\\")))
    total, rows = _page(query.order_by(CourierProfile.created_at.desc()), page, size)
    people = _people(db, {c.user_id for c in rows})
    return {"total": total, "page": page, "size": size, "items": [{
        "user_id": c.user_id, "name": _label(people.get(c.user_id)),
        "phone": people[c.user_id].phone if c.user_id in people else None,
        "country": c.country, "city": c.city, "zones": c.zones, "wallet_phone": c.wallet_phone,
        "status": c.status, "defaults_count": c.defaults_count,
        "rules_accepted_at": _iso(c.rules_accepted_at), "validated_at": _iso(c.validated_at),
        "suspended_at": _iso(c.suspended_at), "trial_ends_at": _iso(c.trial_ends_at),
        "membership_until": _iso(c.membership_until), "current_pack": c.current_pack,
        "created_at": c.created_at.isoformat(),
    } for c in rows]}


def _get_courier(db: Session, user_id: int) -> CourierProfile:
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()
    if courier is None:
        raise HTTPException(status_code=404, detail="Coursier introuvable")
    return courier


def _courier_decision(db: Session, user: User, request: Request, courier: CourierProfile,
                      action: str, reason: str, message: str) -> dict:
    notify(db, [courier.user_id], service="honam", title="Mode coursier", body=message)
    _audit(db, user, action, "courier", courier.user_id, {"reason": reason, "status": courier.status}, request)
    db.commit()
    return {"user_id": courier.user_id, "status": courier.status}


@router.post("/honam/couriers/{user_id}/reject")
def honam_courier_reject(
    user_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")), db: Session = Depends(get_db),
):
    courier = _get_courier(db, user_id)
    if courier.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cette candidature n'est plus en attente")
    reason = body.reason.strip()
    courier.status = "REJECTED"
    return _courier_decision(db, user, request, courier, "courier_reject", reason,
                             f"Ta candidature de coursier n'a pas été retenue. Motif : « {reason} »")


@router.post("/honam/couriers/{user_id}/request-info")
def honam_courier_request_info(
    user_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")), db: Session = Depends(get_db),
):
    """Demander des compléments : la candidature reste en attente, et le
    candidat peut la renvoyer depuis l'app (POST /honam/courier/join)."""
    courier = _get_courier(db, user_id)
    if courier.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cette candidature n'est plus en attente")
    reason = body.reason.strip()
    return _courier_decision(db, user, request, courier, "courier_request_info", reason,
                             f"Ta candidature de coursier doit être complétée : {reason}")


@router.post("/honam/couriers/{user_id}/suspend")
def honam_courier_suspend(
    user_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")), db: Session = Depends(get_db),
):
    courier = _get_courier(db, user_id)
    if courier.status in ("PENDING", "REJECTED", "SUSPENDED"):
        raise HTTPException(status_code=409, detail="Ce coursier n'est pas en activité")
    reason = body.reason.strip()
    courier.status = "SUSPENDED"
    courier.suspended_at = datetime.utcnow()
    return _courier_decision(db, user, request, courier, "courier_suspend", reason,
                             f"Ton compte coursier est suspendu par l'équipe Pokou. Motif : « {reason} »")


@router.post("/honam/couriers/{user_id}/reinstate")
def honam_courier_reinstate(
    user_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("honam.manage")), db: Session = Depends(get_db),
):
    """Lever une suspension : le coursier retrouve l'état que ses dates lui
    donnent (adhésion, essai, ou fin d'essai), et son compteur de défauts
    repart de zéro — sinon le prochain défaut le suspendrait aussitôt."""
    courier = _get_courier(db, user_id)
    if courier.status != "SUSPENDED":
        raise HTTPException(status_code=409, detail="Ce coursier n'est pas suspendu")
    now = datetime.utcnow()
    if courier.membership_until and courier.membership_until > now:
        courier.status = "MEMBER"
    elif courier.trial_ends_at and courier.trial_ends_at > now:
        courier.status = "TRIAL"
    else:
        courier.status = "ENDED"
    courier.suspended_at = None
    courier.defaults_count = 0
    return _courier_decision(db, user, request, courier, "courier_reinstate", body.reason.strip(),
                             "Ton compte coursier est de nouveau actif.")


# ── Assimé ──────────────────────────────────────────────────────────────

@router.get("/marketplace/products/{product_id}")
def assime_product_detail(product_id: int, user: User = Depends(require_permission("assime.view")), db: Session = Depends(get_db)):
    p = db.get(MarketplaceProduct, product_id)
    if p is None:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    seller = db.get(User, p.seller_id)
    boosts = db.query(MarketplaceBoost).filter(MarketplaceBoost.product_id == p.id).order_by(MarketplaceBoost.id.desc()).all()
    actions = db.query(AuditLog).filter(AuditLog.entity_type == "marketplace_product", AuditLog.entity_id == p.id).order_by(
        AuditLog.created_at.desc()).limit(20).all()
    actors = _people(db, {a.user_id for a in actions})
    now = datetime.utcnow()
    return {
        "id": p.id, "name": p.name, "description": p.description, "category": p.category,
        "location": p.location, "price": float(p.price), "currency": p.currency,
        "image_media_id": p.image_media_id,
        "is_active": bool(p.is_active), "deleted_by_seller": p.deleted_at is not None,
        "sold_at": _iso(p.sold_at), "created_at": p.created_at.isoformat(),
        "seller": {"id": p.seller_id, "name": _label(seller), "phone": seller.phone if seller else None,
                   "is_certified_seller": bool(seller and seller.is_certified_seller),
                   "products": db.query(func.count(MarketplaceProduct.id)).filter(
                       MarketplaceProduct.seller_id == p.seller_id).scalar() or 0},
        "boosts": [{"id": b.id, "days": b.days, "starts_at": _iso(b.starts_at), "expires_at": _iso(b.expires_at),
                    "active": b.starts_at <= now < b.expires_at, "status_moderation": b.status_moderation,
                    "impressions": b.impressions, "contacts": b.contacts} for b in boosts],
        "team_actions": [{"action": a.action, "actor": _label(actors.get(a.user_id)),
                          "reason": (a.changes or {}).get("reason"), "is_active": (a.changes or {}).get("is_active"),
                          "at": a.created_at.isoformat()} for a in actions],
    }


@router.get("/marketplace/sellers")
def assime_sellers(
    q: Optional[str] = Query(None, max_length=80),
    certified: Optional[bool] = None,
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("assime.view")),
    db: Session = Depends(get_db),
):
    sellers = db.query(MarketplaceProduct.seller_id).distinct()
    query = db.query(User).filter(or_(User.id.in_(sellers), User.is_certified_seller.is_(True)))
    if certified is not None:
        query = query.filter(User.is_certified_seller.is_(certified))
    if q:
        like = _like(q)
        query = query.filter(or_(User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))
    total, rows = _page(query.order_by(User.id.desc()), page, size)
    ids = [u.id for u in rows]
    products = dict(db.query(MarketplaceProduct.seller_id, func.count(MarketplaceProduct.id)).filter(
        MarketplaceProduct.seller_id.in_(ids), MarketplaceProduct.deleted_at.is_(None)).group_by(MarketplaceProduct.seller_id).all()) if ids else {}
    hidden = dict(db.query(MarketplaceProduct.seller_id, func.count(MarketplaceProduct.id)).filter(
        MarketplaceProduct.seller_id.in_(ids), MarketplaceProduct.is_active.is_(False)).group_by(MarketplaceProduct.seller_id).all()) if ids else {}
    ratings = {sid: (avg, n) for sid, avg, n in db.query(
        SellerReview.seller_id, func.avg(SellerReview.rating), func.count(SellerReview.id)).filter(
        SellerReview.seller_id.in_(ids)).group_by(SellerReview.seller_id).all()} if ids else {}
    return {"total": total, "page": page, "size": size, "items": [{
        "id": u.id, "name": _label(u), "phone": u.phone, "is_active": bool(u.is_active),
        "is_certified_seller": bool(u.is_certified_seller), "certified_seller_until": _iso(u.certified_seller_until),
        "products": int(products.get(u.id, 0)), "hidden_products": int(hidden.get(u.id, 0)),
        "rating": round(float(ratings[u.id][0]), 1) if u.id in ratings else None,
        "reviews": int(ratings[u.id][1]) if u.id in ratings else 0,
    } for u in rows]}


@router.post("/marketplace/sellers/{seller_id}/revoke-badge")
def assime_revoke_badge(
    seller_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("assime.manage")), db: Session = Depends(get_db),
):
    seller = db.get(User, seller_id)
    if seller is None or not seller.is_certified_seller:
        raise HTTPException(status_code=404, detail="Ce vendeur n'a pas de badge")
    reason = body.reason.strip()
    seller.is_certified_seller = False
    seller.certified_seller_until = None
    notify(db, [seller.id], service="assime", title="Badge vendeur vérifié",
           body=f"Ton badge vendeur vérifié a été retiré par l'équipe Pokou. Motif : « {reason} »")
    _audit(db, user, "seller_badge_revoke", "user", seller.id, {"reason": reason}, request)
    db.commit()
    return {"id": seller.id, "is_certified_seller": False}


@router.get("/marketplace/boosts")
def assime_boosts(
    state: str = Query("active", pattern="^(active|pending|all)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("assime.view")),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    query = db.query(MarketplaceBoost)
    if state == "active":
        query = query.filter(MarketplaceBoost.starts_at <= now, MarketplaceBoost.expires_at > now)
    elif state == "pending":
        query = query.filter(MarketplaceBoost.status_moderation == "PENDING")
    total, rows = _page(query.order_by(MarketplaceBoost.id.desc()), page, size)
    products = {p.id: p for p in db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id.in_({b.product_id for b in rows if b.product_id}))} if rows else {}
    people = _people(db, {b.seller_id for b in rows})
    return {"total": total, "page": page, "size": size, "items": [{
        "id": b.id, "product_id": b.product_id,
        "product": products[b.product_id].name if b.product_id in products else None,
        "seller": _label(people.get(b.seller_id)), "city": b.city, "days": b.days,
        "starts_at": _iso(b.starts_at), "expires_at": _iso(b.expires_at),
        "active": b.starts_at <= now < b.expires_at, "status_moderation": b.status_moderation,
        "impressions": b.impressions, "status_views": b.status_views, "contacts": b.contacts,
    } for b in rows]}


@router.get("/marketplace/reviews")
def assime_reviews(
    q: Optional[str] = Query(None, max_length=80),
    max_rating: int = Query(5, ge=1, le=5),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("assime.view")),
    db: Session = Depends(get_db),
):
    """Les avis sur les vendeurs, les plus sévères à filtrer d'abord.
    L'app n'a pas (encore) de bouton « signaler un avis » : la modération
    les parcourt ici."""
    query = db.query(SellerReview).filter(SellerReview.rating <= max_rating)
    if q:
        like = _like(q)
        names = db.query(User.id).filter(or_(User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))
        query = query.filter(or_(SellerReview.comment.ilike(like, escape="\\"),
                                 SellerReview.seller_id.in_(names), SellerReview.author_id.in_(names)))
    total, rows = _page(query.order_by(SellerReview.created_at.desc()), page, size)
    people = _people(db, {r.seller_id for r in rows} | {r.author_id for r in rows})
    return {"total": total, "page": page, "size": size, "items": [{
        "id": r.id, "seller": _label(people.get(r.seller_id)), "seller_id": r.seller_id,
        "author": _label(people.get(r.author_id)), "rating": r.rating, "comment": r.comment,
        "tags": r.tags, "created_at": r.created_at.isoformat(),
    } for r in rows]}


@router.post("/marketplace/reviews/{review_id}/remove")
def assime_remove_review(
    review_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("assime.manage")), db: Session = Depends(get_db),
):
    """Retirer un avis abusif. Le texte retiré est gardé au journal d'audit :
    c'est la trace à montrer si l'auteur conteste."""
    review = db.get(SellerReview, review_id)
    if review is None:
        raise HTTPException(status_code=404, detail="Avis introuvable")
    reason = body.reason.strip()
    snapshot = {"reason": reason, "seller_id": review.seller_id, "author_id": review.author_id,
                "rating": review.rating, "comment": review.comment}
    db.delete(review)
    _audit(db, user, "review_remove", "seller_review", review_id, snapshot, request)
    db.commit()
    return {"id": review_id, "removed": True}


# ── Pokou certifié ──────────────────────────────────────────────────────

def _application_row(a: CertifiedProApplication, people: dict, now: datetime) -> dict:
    return {
        "id": a.id, "user_id": a.user_id, "verified_name": _label(people.get(a.user_id)),
        "phone": people[a.user_id].phone if a.user_id in people else None,
        "business_name": a.business_name, "activity": a.activity, "city": a.city,
        "document_media_id": a.document_media_id, "status": a.status, "review_note": a.review_note,
        "submitted_at": a.submitted_at.isoformat(), "review_due_at": a.review_due_at.isoformat(),
        "overdue": a.status == "PENDING" and a.review_due_at < now,
        "reviewed_at": _iso(a.reviewed_at), "reviewer": _label(people.get(a.reviewer_id)),
    }


@router.get("/certified/applications")
def certified_applications(
    q: Optional[str] = Query(None, max_length=80),
    status: Optional[str] = Query("PENDING", pattern="^(PENDING|CORRECTION|APPROVED|REJECTED|ALL)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("certified.view")),
    db: Session = Depends(get_db),
):
    query = db.query(CertifiedProApplication)
    if status and status != "ALL":
        query = query.filter(CertifiedProApplication.status == status)
    if q:
        like = _like(q)
        query = query.filter(or_(
            CertifiedProApplication.business_name.ilike(like, escape="\\"),
            CertifiedProApplication.user_id.in_(db.query(User.id).filter(or_(
                User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\"))))))
    order = CertifiedProApplication.review_due_at if status == "PENDING" else CertifiedProApplication.submitted_at.desc()
    total, rows = _page(query.order_by(order), page, size)
    people = _people(db, {a.user_id for a in rows} | {a.reviewer_id for a in rows})
    now = datetime.utcnow()
    return {"items": [_application_row(a, people, now) for a in rows], "total": total, "page": page, "size": size}


@router.get("/certified/applications/{application_id}")
def certified_application_detail(
    application_id: int, user: User = Depends(require_permission("certified.view")), db: Session = Depends(get_db),
):
    a = db.get(CertifiedProApplication, application_id)
    if a is None:
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    people = _people(db, {a.user_id, a.reviewer_id})
    sub = db.query(CertifiedSubscription).filter(CertifiedSubscription.user_id == a.user_id).first()
    actions = db.query(AuditLog).filter(AuditLog.entity_type == "certified_pro", AuditLog.entity_id == a.id).order_by(
        AuditLog.created_at.desc()).all()
    actors = _people(db, {x.user_id for x in actions})
    return {
        **_application_row(a, people, datetime.utcnow()),
        "subscription": {"status": sub.status, "plan": sub.plan,
                         "current_period_end": _iso(sub.current_period_end)} if sub else None,
        "history": [{"action": x.action, "actor": _label(actors.get(x.user_id)),
                     "decision": (x.changes or {}).get("decision"), "note": (x.changes or {}).get("note"),
                     "at": x.created_at.isoformat()} for x in actions],
    }


@router.get("/certified/subscriptions")
def certified_subscriptions(
    q: Optional[str] = Query(None, max_length=80),
    status: Optional[str] = Query(None, pattern="^(TRIAL|ACTIVE|NAME_MISMATCH|PAUSED|EXPIRED)$"),
    plan: Optional[str] = Query(None, max_length=24),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("certified.view")),
    db: Session = Depends(get_db),
):
    query = db.query(CertifiedSubscription)
    if status:
        query = query.filter(CertifiedSubscription.status == status)
    if plan:
        query = query.filter(CertifiedSubscription.plan == plan)
    if q:
        like = _like(q)
        query = query.filter(CertifiedSubscription.user_id.in_(db.query(User.id).filter(or_(
            User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\")))))
    total, rows = _page(query.order_by(CertifiedSubscription.updated_at.desc()), page, size)
    people = _people(db, {s.user_id for s in rows})
    return {"total": total, "page": page, "size": size, "items": [{
        "user_id": s.user_id, "name": _label(people.get(s.user_id)),
        "phone": people[s.user_id].phone if s.user_id in people else None,
        "plan": s.plan, "status": s.status,
        # Le nom du titulaire du wallet n'est montré qu'en cas de différence :
        # c'est ce que l'équipe doit comparer.
        "wallet_holder_name": s.wallet_holder_name if s.status == "NAME_MISMATCH" else None,
        "badge_visible": bool(people[s.user_id].is_verified) if s.user_id in people else False,
        "trial_ends_at": _iso(s.trial_ends_at), "current_period_end": _iso(s.current_period_end),
        "first_paid_at": _iso(s.first_paid_at), "updated_at": _iso(s.updated_at),
    } for s in rows]}


class SubscriptionReview(BaseModel):
    decision: str = Field(..., pattern="^(APPROVE|CORRECTION|REJECT)$")
    note: str = Field(..., min_length=3, max_length=280)


@router.post("/certified/subscriptions/{user_id}/review")
def certified_subscription_review(
    user_id: int, body: SubscriptionReview, request: Request,
    user: User = Depends(require_permission("certified.manage")), db: Session = Depends(get_db),
):
    """Examen d'un abonnement particulier :

    - APPROVE : « noms différents » levé à la main, après vérification par
      l'équipe (pièce présentée, nom abrégé…) ; le badge s'allume.
    - CORRECTION : la personne est invitée à corriger le nom de son profil
      (l'app propose déjà « Corriger mon nom »).
    - REJECT : le badge est retiré (abonnement repassé en « noms
      différents ») ; le mode preuve reste ouvert tant que l'abonnement court.
    Le motif est obligatoire : il passe outre une vérification automatique.
    """
    from app.api.v1.certified.certified import _apply_badge
    sub = db.query(CertifiedSubscription).filter(CertifiedSubscription.user_id == user_id).first()
    target = db.get(User, user_id)
    if sub is None or target is None:
        raise HTTPException(status_code=404, detail="Abonnement introuvable")
    note = body.note.strip()
    previous = sub.status
    if body.decision == "APPROVE":
        if sub.status != "NAME_MISMATCH":
            raise HTTPException(status_code=409, detail="Seul un abonnement « noms différents » s'approuve")
        sub.status = "ACTIVE"
        _apply_badge(target, sub)
        message = "Ton badge Pokou certifié est activé après vérification par l'équipe."
    elif body.decision == "CORRECTION":
        if sub.status != "NAME_MISMATCH":
            raise HTTPException(status_code=409, detail="Aucune différence de nom à corriger")
        message = f"Corrige le nom de ton profil pour activer ton badge : {note}"
    else:
        if sub.status not in ("ACTIVE", "NAME_MISMATCH"):
            raise HTTPException(status_code=409, detail="Cet abonnement n'a pas de badge à retirer")
        sub.status = "NAME_MISMATCH"
        _apply_badge(target, sub)
        message = f"Ton badge Pokou certifié a été retiré par l'équipe. Motif : « {note} »"
    notify(db, [user_id], service="certified", title="Pokou certifié", body=message)
    _audit(db, user, "certified_review", "certified_subscription", user_id,
           {"decision": body.decision, "note": note, "from": previous, "to": sub.status}, request)
    db.commit()
    return {"user_id": user_id, "status": sub.status, "badge_visible": bool(target.is_verified)}


# ── Journal d'audit ─────────────────────────────────────────────────────

def _audit_query(db: Session, actor: Optional[str], action: Optional[str], entity_type: Optional[str],
                 entity_id: Optional[int], since: Optional[date], until: Optional[date]):
    query = db.query(AuditLog)
    if actor:
        text = actor.strip()
        ids = db.query(User.id).filter(or_(User.full_name.ilike(_like(text), escape="\\"),
                                           User.email.ilike(_like(text), escape="\\"),
                                           User.phone.ilike(_like(text), escape="\\")))
        query = query.filter(AuditLog.user_id.in_(ids) if not text.isdigit() else
                             or_(AuditLog.user_id == int(text), AuditLog.user_id.in_(ids)))
    if action:
        query = query.filter(AuditLog.action == action)
    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)
    if entity_id is not None:
        query = query.filter(AuditLog.entity_id == entity_id)
    if since:
        query = query.filter(AuditLog.created_at >= datetime.combine(since, datetime.min.time()))
    if until:
        query = query.filter(AuditLog.created_at < datetime.combine(until, datetime.min.time()) + timedelta(days=1))
    return query.order_by(AuditLog.created_at.desc(), AuditLog.id.desc())


def _audit_row(r: AuditLog, actors: dict) -> dict:
    actor = actors.get(r.user_id)
    return {
        "id": r.id, "action": r.action, "entity_type": r.entity_type, "entity_id": r.entity_id,
        "changes": r.changes, "ip_address": r.ip_address, "created_at": r.created_at.isoformat(),
        "actor": _label(actor), "actor_id": r.user_id,
    }


@router.get("/audit/search")
def audit_search(
    actor: Optional[str] = Query(None, max_length=120),
    action: Optional[str] = Query(None, max_length=255),
    entity_type: Optional[str] = Query(None, max_length=50),
    entity_id: Optional[int] = None,
    since: Optional[date] = None,
    until: Optional[date] = None,
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    user: User = Depends(require_permission("audit.view")),
    db: Session = Depends(get_db),
):
    total, rows = _page(_audit_query(db, actor, action, entity_type, entity_id, since, until), page, size)
    actors = _people(db, {r.user_id for r in rows})
    return {"items": [_audit_row(r, actors) for r in rows], "total": total, "page": page, "size": size}


@router.get("/audit/facets")
def audit_facets(user: User = Depends(require_permission("audit.view")), db: Session = Depends(get_db)):
    """Les valeurs connues, pour les listes de filtres."""
    actions = [a for (a,) in db.query(AuditLog.action).distinct().order_by(AuditLog.action).all()]
    types = [t for (t,) in db.query(AuditLog.entity_type).distinct().order_by(AuditLog.entity_type).all()]
    return {"actions": actions, "entity_types": types}


_EXPORT_LIMIT = 10000


@router.get("/audit/export")
def audit_export(
    request: Request,
    actor: Optional[str] = Query(None, max_length=120),
    action: Optional[str] = Query(None, max_length=255),
    entity_type: Optional[str] = Query(None, max_length=50),
    entity_id: Optional[int] = None,
    since: Optional[date] = None,
    until: Optional[date] = None,
    user: User = Depends(require_permission("audit.view")),
    db: Session = Depends(get_db),
):
    """Export CSV (UTF-8 avec BOM, pour Excel), au plus 10 000 lignes.
    L'export lui-même est journalisé."""
    import json
    rows = _audit_query(db, actor, action, entity_type, entity_id, since, until).limit(_EXPORT_LIMIT).all()
    actors = _people(db, {r.user_id for r in rows})
    out = io.StringIO()
    out.write("﻿")
    writer = csv.writer(out, delimiter=";")
    writer.writerow(["id", "date (UTC)", "acteur", "acteur_id", "action", "type", "cible", "details", "ip"])
    for r in rows:
        writer.writerow([
            r.id, r.created_at.isoformat(timespec="seconds"), _label(actors.get(r.user_id)) or "", r.user_id,
            r.action, r.entity_type, r.entity_id if r.entity_id is not None else "",
            json.dumps(r.changes, ensure_ascii=False) if r.changes else "", r.ip_address or "",
        ])
    filters = {k: v for k, v in {"actor": actor, "action": action, "entity_type": entity_type,
                                 "entity_id": entity_id, "since": _iso(since), "until": _iso(until)}.items() if v is not None}
    _audit(db, user, "audit_export", "audit_log", None, {"rows": len(rows), "filters": filters}, request)
    db.commit()
    stamp = datetime.utcnow().strftime("%Y%m%d-%H%M")
    return Response(content=out.getvalue().encode("utf-8"), media_type="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f'attachment; filename="pokou-audit-{stamp}.csv"'})
