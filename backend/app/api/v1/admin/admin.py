"""Espace d'administration de Pokou : tableau de bord, utilisateurs, équipe,
signalements, Kory, Honam, journal d'audit. Chaque route exige une
permission (app/core/permissions.py) ; chaque action est journalisée.

Rien ici ne lit un message : ils sont chiffrés de bout en bout. Les
statistiques de messagerie sont des COMPTES.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import ROLE_LABELS, ROLE_PERMISSIONS, permissions_of, require_permission
from app.models import (
    AbuseReport, AuditLog, CertifiedSubscription, DirectMessage, Group, GroupMessage,
    HonamOrder, KoryEntry, KoryPot, MarketplaceProduct, Pharmacy, User, UserRole,
)

router = APIRouter(prefix="/admin", tags=["Administration"])


def _audit(db: Session, actor: User, action: str, entity_type: str, entity_id: Optional[int],
           changes: Optional[dict], request: Optional[Request]) -> None:
    db.add(AuditLog(
        user_id=actor.id, action=action, entity_type=entity_type, entity_id=entity_id,
        changes=changes,
        ip_address=(request.client.host if request and request.client else None),
        user_agent=(request.headers.get("user-agent", "")[:500] if request else None),
    ))


def _revoke_sessions(db: Session, user_id: int) -> None:
    """Suspendre, c'est déconnecter TOUT DE SUITE : les jetons déjà émis
    sont révoqués (voir _reject_if_revoked), pas seulement la prochaine
    connexion refusée."""
    from app.models import Token
    db.query(Token).filter(Token.user_id == user_id, Token.revoked_at.is_(None)).update(
        {Token.revoked_at: datetime.utcnow()}, synchronize_session=False)


def _user_json(u: User) -> dict:
    role = u.role or UserRole.USER
    return {
        "id": u.id,
        "full_name": u.full_name,
        "phone": u.phone,
        "email": u.email,
        "role": role.value,
        "role_label": ROLE_LABELS.get(role, role.value),
        "is_active": bool(u.is_active),
        "is_verified": bool(getattr(u, "is_verified", False)),
        "created_at": u.created_at.isoformat() if u.created_at else None,
        "last_seen_at": u.last_seen_at.isoformat() if u.last_seen_at else None,
    }


# ── Moi ──────────────────────────────────────────────────────────────────

# ── Connexion à la console par e-mail et mot de passe ───────────────────
#
# L'app se connecte par code SMS. La console l'accepte aussi, mais le compte
# super-administrateur créé au déploiement (scripts/seed.py) n'a pas de
# téléphone : il lui faut un mot de passe. Ce mot de passe ne vaut QUE pour
# la console, et seulement pour un compte de l'équipe.

_MAX_FAILURES = 5
_LOCK = timedelta(minutes=15)
_BAD_CREDENTIALS = "E-mail ou mot de passe incorrect"


class ConsoleLogin(BaseModel):
    email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=1, max_length=128)


@router.post("/auth/login")
def console_login(body: ConsoleLogin, request: Request, db: Session = Depends(get_db)):
    from app.core.security import verify_password
    from app.services.auth.console_session import issue_console_session

    user = db.query(User).filter(func.lower(User.email) == body.email.strip().lower()).first()
    now = datetime.utcnow()
    if user is not None and user.console_locked_until and user.console_locked_until > now:
        raise HTTPException(status_code=429, detail="Trop d'essais : réessaie dans quelques minutes")
    ok = (
        user is not None
        and user.console_password_hash
        and verify_password(body.password, user.console_password_hash)
    )
    if not ok:
        if user is not None and user.console_password_hash:
            user.console_failed_attempts = (user.console_failed_attempts or 0) + 1
            if user.console_failed_attempts >= _MAX_FAILURES:
                user.console_failed_attempts = 0
                user.console_locked_until = now + _LOCK
            db.commit()
        # Même réponse que le compte existe ou non : pas d'énumération.
        raise HTTPException(status_code=401, detail=_BAD_CREDENTIALS)
    if not user.is_active or not permissions_of(user):
        raise HTTPException(status_code=403, detail="Ce compte n'a pas accès à la console")
    user.console_failed_attempts = 0
    user.console_locked_until = None
    access_token = issue_console_session(db, user)
    _audit(db, user, "console_login", "user", user.id, {"method": "password"}, request)
    db.commit()
    return {"access_token": access_token, "token_type": "bearer"}


class PasswordChange(BaseModel):
    current_password: Optional[str] = Field(None, max_length=128)
    new_password: str = Field(..., min_length=12, max_length=72)


@router.put("/me/password")
def change_console_password(
    body: PasswordChange, request: Request,
    user: User = Depends(require_permission("dashboard.view")),
    db: Session = Depends(get_db),
):
    """Le mot de passe donné au déploiement est à remplacer dès la première
    connexion. Un compte qui en a déjà un doit le fournir pour le changer."""
    from app.core.security import hash_password, verify_password

    if user.console_password_hash and not verify_password(body.current_password or "", user.console_password_hash):
        raise HTTPException(status_code=403, detail="Mot de passe actuel incorrect")
    user.console_password_hash = hash_password(body.new_password)
    _audit(db, user, "console_password_change", "user", user.id, None, request)
    db.commit()
    return {"ok": True}


@router.get("/me")
def me(user: User = Depends(require_permission("dashboard.view"))):
    return {**_user_json(user), "email": user.email, "has_console_password": bool(user.console_password_hash),
            "permissions": sorted(permissions_of(user))}


@router.get("/roles")
def roles(user: User = Depends(require_permission("team.view"))):
    return {"items": [
        {"role": r.value, "label": ROLE_LABELS[r], "permissions": sorted(ROLE_PERMISSIONS[r])}
        for r in ROLE_PERMISSIONS if r != UserRole.USER
    ]}


# ── Tableau de bord ─────────────────────────────────────────────────────

@router.get("/overview")
def overview(
    days: int = Query(30, ge=7, le=180),
    user: User = Depends(require_permission("dashboard.view")),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    since = now - timedelta(days=days)
    week = now - timedelta(days=7)

    def count(q):
        return int(q.scalar() or 0)

    users_total = count(db.query(func.count(User.id)))
    users_new = count(db.query(func.count(User.id)).filter(User.created_at >= week))
    users_active = count(db.query(func.count(User.id)).filter(User.last_seen_at >= week))
    direct = count(db.query(func.count(DirectMessage.id)).filter(DirectMessage.created_at >= since))
    group_msgs = count(db.query(func.count(GroupMessage.id)).filter(GroupMessage.created_at >= since))
    groups = count(db.query(func.count(Group.id)))
    pots_open = count(db.query(func.count(KoryPot.id)).filter(KoryPot.status == "OPEN"))
    kory_confirmed = count(
        db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
            KoryEntry.status == "CONFIRMED", KoryEntry.declared_at >= since)
    )
    orders_by_status = dict(
        db.query(HonamOrder.status, func.count(HonamOrder.id)).group_by(HonamOrder.status).all()
    )
    products = count(db.query(func.count(MarketplaceProduct.id)).filter(
        MarketplaceProduct.deleted_at.is_(None), MarketplaceProduct.sold_at.is_(None)))
    certified = count(db.query(func.count(CertifiedSubscription.user_id)).filter(
        CertifiedSubscription.status.in_(("ACTIVE", "TRIAL", "NAME_MISMATCH"))))
    reports_open = count(db.query(func.count(AbuseReport.id)).filter(AbuseReport.status == "OPEN"))

    # Séries quotidiennes : inscriptions et messages.
    def series(column, model_id, extra=None):
        q = db.query(func.date(column), func.count(model_id)).filter(column >= since)
        if extra is not None:
            q = q.filter(extra)
        rows = dict((str(d), int(c)) for d, c in q.group_by(func.date(column)).all())
        return [
            {"date": (since + timedelta(days=i)).date().isoformat(),
             "value": rows.get((since + timedelta(days=i)).date().isoformat(), 0)}
            for i in range(days + 1)
        ]

    signups = series(User.created_at, User.id)
    dm_series = series(DirectMessage.created_at, DirectMessage.id)
    gm_series = series(GroupMessage.created_at, GroupMessage.id)
    activity = [
        {"date": a["date"], "signups": a["value"], "direct": b["value"], "group": c["value"]}
        for a, b, c in zip(signups, dm_series, gm_series)
    ]
    return {
        "users": {"total": users_total, "new_7d": users_new, "active_7d": users_active},
        "messages": {"direct": direct, "group": group_msgs, "days": days},
        "groups": groups,
        "kory": {"open_pots": pots_open, "confirmed_amount": kory_confirmed},
        "honam": {"orders_by_status": orders_by_status,
                  "pharmacies": count(db.query(func.count(Pharmacy.id)))},
        "assime": {"live_products": products},
        "certified": {"active": certified},
        "reports": {"open": reports_open},
        "activity": activity,
    }


# ── Utilisateurs ────────────────────────────────────────────────────────

@router.get("/users")
def list_users(
    q: Optional[str] = Query(None, max_length=80),
    role: Optional[str] = None,
    status: Optional[str] = Query(None, pattern="^(active|suspended)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("users.view")),
    db: Session = Depends(get_db),
):
    query = db.query(User)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(User.full_name.ilike(like), User.phone.ilike(like)))
    if role:
        try:
            query = query.filter(User.role == UserRole(role))
        except ValueError:
            raise HTTPException(status_code=422, detail="Rôle inconnu")
    if status == "active":
        query = query.filter(User.is_active.is_(True))
    elif status == "suspended":
        query = query.filter(User.is_active.is_(False))
    total = query.count()
    rows = query.order_by(User.created_at.desc()).offset((page - 1) * size).limit(size).all()
    return {"items": [_user_json(u) for u in rows], "total": total, "page": page, "size": size}


@router.get("/users/{user_id}")
def user_detail(
    user_id: int,
    user: User = Depends(require_permission("users.view")),
    db: Session = Depends(get_db),
):
    from app.models import GroupMember
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    sub = db.query(CertifiedSubscription).filter(CertifiedSubscription.user_id == user_id).first()
    return {
        **_user_json(target),
        "stats": {
            "groups": db.query(func.count(GroupMember.id)).filter(GroupMember.user_id == user_id).scalar() or 0,
            "direct_sent": db.query(func.count(DirectMessage.id)).filter(DirectMessage.sender_id == user_id).scalar() or 0,
            "pots_organized": db.query(func.count(KoryPot.id)).filter(KoryPot.organizer_id == user_id).scalar() or 0,
            "honam_orders": db.query(func.count(HonamOrder.id)).filter(HonamOrder.patient_id == user_id).scalar() or 0
            if hasattr(HonamOrder, "patient_id") else 0,
            "products": db.query(func.count(MarketplaceProduct.id)).filter(MarketplaceProduct.seller_id == user_id).scalar() or 0,
            "reports_received": db.query(func.count(AbuseReport.id)).filter(AbuseReport.target_user_id == user_id).scalar() or 0,
        },
        "certified": {"status": sub.status, "plan": sub.plan} if sub else None,
    }


class SuspendBody(BaseModel):
    reason: str = Field(..., min_length=3, max_length=280)


@router.post("/users/{user_id}/suspend")
def suspend_user(
    user_id: int, body: SuspendBody, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if target.id == user.id:
        raise HTTPException(status_code=409, detail="Impossible de se suspendre soi-même")
    if (target.role or UserRole.USER) != UserRole.USER and "team.manage" not in permissions_of(user):
        raise HTTPException(status_code=403, detail="Seul un super-administrateur suspend un membre de l'équipe")
    target.is_active = False
    _revoke_sessions(db, target.id)
    _audit(db, user, "suspend", "user", target.id, {"reason": body.reason}, request)
    db.commit()
    return _user_json(target)


@router.post("/users/{user_id}/reactivate")
def reactivate_user(
    user_id: int, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    target.is_active = True
    _audit(db, user, "reactivate", "user", target.id, None, request)
    db.commit()
    return _user_json(target)


# ── Équipe (RBAC) ───────────────────────────────────────────────────────

@router.get("/team")
def team(user: User = Depends(require_permission("team.view")), db: Session = Depends(get_db)):
    rows = db.query(User).filter(User.role != UserRole.USER).order_by(User.role, User.full_name).all()
    return {"items": [_user_json(u) for u in rows]}


class RoleBody(BaseModel):
    role: str


@router.put("/team/{user_id}")
def set_role(
    user_id: int, body: RoleBody, request: Request,
    user: User = Depends(require_permission("team.manage")),
    db: Session = Depends(get_db),
):
    try:
        new_role = UserRole(body.role)
    except ValueError:
        raise HTTPException(status_code=422, detail="Rôle inconnu")
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    old = target.role or UserRole.USER
    if old == UserRole.SUPER_ADMIN and new_role != UserRole.SUPER_ADMIN:
        others = db.query(func.count(User.id)).filter(
            User.role == UserRole.SUPER_ADMIN, User.id != target.id, User.is_active.is_(True)).scalar()
        if not others:
            raise HTTPException(status_code=409, detail="Il faut garder au moins un super-administrateur")
    target.role = new_role
    _audit(db, user, "role_change", "user", target.id, {"from": old.value, "to": new_role.value}, request)
    db.commit()
    return _user_json(target)


class InviteBody(BaseModel):
    email: str = Field(..., min_length=5, max_length=255, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    full_name: str = Field(..., min_length=2, max_length=120)
    role: str


def _temporary_password() -> str:
    import secrets
    return secrets.token_urlsafe(12)


@router.post("/team")
def add_member(
    body: InviteBody, request: Request,
    user: User = Depends(require_permission("team.manage")),
    db: Session = Depends(get_db),
):
    """Ajouter un membre de l'équipe PAR SON E-MAIL. Le compte de console
    est créé s'il n'existe pas, avec un mot de passe provisoire rendu UNE
    seule fois, à transmettre à la personne (qui le change à sa première
    connexion). Aucun numéro de téléphone : la console ne s'en sert pas."""
    from app.core.security import hash_password
    try:
        role = UserRole(body.role)
    except ValueError:
        raise HTTPException(status_code=422, detail="Rôle inconnu")
    if role == UserRole.USER:
        raise HTTPException(status_code=422, detail="Choisis un rôle d'équipe")
    email = body.email.strip().lower()
    target = db.query(User).filter(func.lower(User.email) == email).first()
    created = target is None
    if created:
        target = User(email=email, full_name=body.full_name.strip(), role=role, is_active=True)
        db.add(target)
        db.flush()
    old = target.role or UserRole.USER
    target.role = role
    password = None
    if not target.console_password_hash:
        password = _temporary_password()
        target.console_password_hash = hash_password(password)
    _audit(db, user, "team_add" if created else "role_change", "user", target.id,
           {"from": old.value, "to": role.value, "email": email}, request)
    db.commit()
    return {**_user_json(target), "temporary_password": password}


@router.post("/team/{user_id}/reset-password")
def reset_member_password(
    user_id: int, request: Request,
    user: User = Depends(require_permission("team.manage")),
    db: Session = Depends(get_db),
):
    """Nouveau mot de passe provisoire pour un membre qui a perdu le sien.
    Ses sessions de console ouvertes sont révoquées."""
    from app.core.security import hash_password
    target = db.get(User, user_id)
    if target is None or (target.role or UserRole.USER) == UserRole.USER or not target.email:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    password = _temporary_password()
    target.console_password_hash = hash_password(password)
    target.console_failed_attempts = 0
    target.console_locked_until = None
    _revoke_sessions(db, target.id)
    _audit(db, user, "console_password_reset", "user", target.id, None, request)
    db.commit()
    return {"temporary_password": password}


# ── Signalements ────────────────────────────────────────────────────────

def _report_json(db: Session, r: AbuseReport) -> dict:
    target = db.get(User, r.target_user_id)
    reporter = db.get(User, r.reporter_id) if r.reporter_id else None
    return {
        "id": r.id,
        "status": r.status,
        "reason": r.reason,
        "blocked": bool(r.blocked),
        "created_at": r.created_at.isoformat(),
        "resolved_at": r.resolved_at.isoformat() if r.resolved_at else None,
        "resolution": r.resolution,
        "target": _user_json(target) if target else None,
        "reporter": _user_json(reporter) if reporter else None,
        "target_reports": db.query(func.count(AbuseReport.id)).filter(
            AbuseReport.target_user_id == r.target_user_id).scalar() or 0,
    }


@router.get("/reports")
def reports(
    status: str = Query("OPEN", pattern="^(OPEN|DISMISSED|ACTIONED|ALL)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("reports.view")),
    db: Session = Depends(get_db),
):
    query = db.query(AbuseReport)
    if status != "ALL":
        query = query.filter(AbuseReport.status == status)
    total = query.count()
    rows = query.order_by(AbuseReport.created_at.desc()).offset((page - 1) * size).limit(size).all()
    return {"items": [_report_json(db, r) for r in rows], "total": total}


class ResolveBody(BaseModel):
    action: str = Field(..., pattern="^(dismiss|suspend)$")
    note: Optional[str] = Field(None, max_length=280)


@router.post("/reports/{report_id}/resolve")
def resolve_report(
    report_id: int, body: ResolveBody, request: Request,
    user: User = Depends(require_permission("reports.manage")),
    db: Session = Depends(get_db),
):
    r = db.get(AbuseReport, report_id)
    if r is None:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if body.action == "suspend":
        if "users.manage" not in permissions_of(user):
            raise HTTPException(status_code=403, detail="Permission refusée")
        target = db.get(User, r.target_user_id)
        if target is not None and target.id != user.id:
            # Même règle que /users/{id}/suspend : un membre de l'équipe ne
            # se suspend que par un super-administrateur.
            if (target.role or UserRole.USER) != UserRole.USER and "team.manage" not in permissions_of(user):
                raise HTTPException(status_code=403, detail="Seul un super-administrateur suspend un membre de l'équipe")
            target.is_active = False
            _revoke_sessions(db, target.id)
            # Les autres signalements ouverts du même compte sont réglés du
            # même coup : la file ne garde que ce qui reste à décider.
            now = datetime.utcnow()
            for other in db.query(AbuseReport).filter(
                    AbuseReport.target_user_id == target.id, AbuseReport.status == "OPEN",
                    AbuseReport.id != r.id).all():
                other.status = "ACTIONED"
                other.resolution = body.note
                other.resolved_by = user.id
                other.resolved_at = now
    r.status = "ACTIONED" if body.action == "suspend" else "DISMISSED"
    r.resolution = body.note
    r.resolved_by = user.id
    r.resolved_at = datetime.utcnow()
    _audit(db, user, f"report_{body.action}", "abuse_report", r.id, {"note": body.note}, request)
    db.commit()
    return _report_json(db, r)


# ── Kory et Honam (lecture) ─────────────────────────────────────────────

@router.get("/kory/pots")
def kory_pots(
    status: Optional[str] = Query(None, pattern="^(OPEN|CLOSED)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("kory.view")),
    db: Session = Depends(get_db),
):
    query = db.query(KoryPot)
    if status:
        query = query.filter(KoryPot.status == status)
    total = query.count()
    rows = query.order_by(KoryPot.created_at.desc()).offset((page - 1) * size).limit(size).all()
    items = []
    for p in rows:
        confirmed = db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
            KoryEntry.pot_id == p.id, KoryEntry.status == "CONFIRMED").scalar() or 0
        pending = db.query(func.count(KoryEntry.id)).filter(
            KoryEntry.pot_id == p.id, KoryEntry.status == "DECLARED").scalar() or 0
        contested = db.query(func.count(KoryEntry.id)).filter(
            KoryEntry.pot_id == p.id, KoryEntry.status == "REJECTED").scalar() or 0
        organizer = db.get(User, p.organizer_id)
        items.append({
            "id": p.id, "title": p.title, "kind": p.kind, "status": p.status,
            "goal_amount": p.goal_amount, "confirmed_total": int(confirmed),
            "pending": int(pending), "contested": int(contested),
            "organizer": organizer.full_name if organizer else None,
            "due_at": p.due_at.isoformat() if p.due_at else None,
            "created_at": p.created_at.isoformat(),
        })
    return {"items": items, "total": total}


@router.get("/honam/orders")
def honam_orders(
    status: Optional[str] = None,
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("honam.view")),
    db: Session = Depends(get_db),
):
    query = db.query(HonamOrder)
    if status:
        query = query.filter(HonamOrder.status == status)
    total = query.count()
    rows = query.order_by(HonamOrder.created_at.desc()).offset((page - 1) * size).limit(size).all()
    items = []
    for o in rows:
        pharmacy = db.get(Pharmacy, o.pharmacy_id) if getattr(o, "pharmacy_id", None) else None
        # Jamais l'ordonnance ni les produits (HON-04) : l'étape et la pharmacie.
        items.append({
            "id": o.id, "status": o.status,
            "pharmacy": pharmacy.name if pharmacy else None,
            "created_at": o.created_at.isoformat(),
        })
    return {"items": items, "total": total}


@router.get("/honam/pharmacies")
def honam_pharmacies(user: User = Depends(require_permission("honam.view")), db: Session = Depends(get_db)):
    rows = db.query(Pharmacy).order_by(Pharmacy.name).all()
    return {"items": [
        {"id": p.id, "name": p.name, "status": getattr(p, "status", None),
         "city": getattr(p, "city", None)}
        for p in rows
    ]}


# ── Journal d'audit ─────────────────────────────────────────────────────

@router.get("/audit")
def audit_log(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    user: User = Depends(require_permission("audit.view")),
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog)
    total = query.count()
    rows = query.order_by(AuditLog.created_at.desc()).offset((page - 1) * size).limit(size).all()
    actors = {u.id: u for u in db.query(User).filter(User.id.in_({r.user_id for r in rows})).all()} if rows else {}
    return {"total": total, "items": [
        {"id": r.id, "action": r.action, "entity_type": r.entity_type, "entity_id": r.entity_id,
         "changes": r.changes, "created_at": r.created_at.isoformat(),
         "actor": (actors[r.user_id].full_name or actors[r.user_id].phone) if r.user_id in actors else None}
        for r in rows
    ]}
