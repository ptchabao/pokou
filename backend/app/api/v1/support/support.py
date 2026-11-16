"""Réglages › Aide et support : « Écrire au support » et « Signaler un
problème » (voir app/models/support.py).

Côté application :

- POST /support/tickets — une demande (SUPPORT) ou un problème (PROBLEM),
  avec la version de l'application, la plateforme et, pour un problème, une
  capture d'écran facultative déjà déposée par POST /media/upload ;
- GET /support/tickets — MES demandes, leur état et la réponse de l'équipe.

Côté console (mêmes permissions que les signalements d'abus) :

- GET /admin/support/search, GET /admin/support/{id} ;
- POST /admin/support/{id}/reply — la réponse arrive dans le centre de
  notifications de la personne, et dans la liste de ses demandes ;
- POST /admin/support/{id}/close.

Le texte libre est chiffré au repos (REPORTS_ENCRYPTION_KEY). Sans clé, la
demande est REFUSÉE (503) plutôt que gardée en clair.
"""
from datetime import datetime, timedelta
from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.v1.admin.admin import _audit, _user_json
from app.core import report_crypto
from app.core.database import get_db
from app.core.permissions import require_permission
from app.core.security import get_current_user
from app.models import MediaAsset, SupportTicket, User
from app.services.notifications.inbox import notify

router = APIRouter(prefix="/support", tags=["Support"])
admin_router = APIRouter(prefix="/admin/support", tags=["Administration · support"])

#: Ce que l'écran « Signaler un problème » propose ; « Écrire au support »
#: envoie QUESTION.
CATEGORIES = ("QUESTION", "ACCOUNT", "MESSAGES", "CALLS", "NOTIFICATIONS", "CRASH", "OTHER")

#: Assez pour revenir à la charge, pas assez pour inonder la file : par
#: personne, compté en base — le NAT d'opérateur ne la gêne donc pas.
MAX_PER_HOUR = 5
MAX_PER_DAY = 20

_UNAVAILABLE = "Le support est momentanément indisponible. Réessaie plus tard."


class TicketCreate(BaseModel):
    kind: Literal["SUPPORT", "PROBLEM"] = "SUPPORT"
    category: Literal[CATEGORIES] = "OTHER"  # type: ignore[valid-type]
    description: str = Field(..., min_length=10, max_length=4000)
    app_version: Optional[str] = Field(None, max_length=32)
    platform: Optional[str] = Field(None, max_length=16)
    screenshot_media_id: Optional[int] = None


class ReplyBody(BaseModel):
    message: str = Field(..., min_length=3, max_length=4000)


def _iso(value) -> Optional[str]:
    return value.isoformat() if value else None


def _ticket_json(t: SupportTicket) -> dict:
    """Ce que la personne voit de SA demande. Une clé absente ou changée
    rend un texte vide, jamais une erreur."""
    return {
        "id": t.id,
        "kind": t.kind,
        "category": t.category,
        "status": t.status,
        "description": report_crypto.decrypt_text(t.description_encrypted),
        "reply": report_crypto.decrypt_text(t.reply_encrypted),
        "has_screenshot": t.screenshot_media_id is not None,
        "created_at": t.created_at.isoformat(),
        "replied_at": _iso(t.replied_at),
        "closed_at": _iso(t.closed_at),
    }


@router.post("/tickets")
def create_ticket(
    payload: TicketCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    me = current_user["user_id"]
    now = datetime.utcnow()
    recent = db.query(SupportTicket.created_at).filter(
        SupportTicket.user_id == me, SupportTicket.created_at >= now - timedelta(days=1)
    ).all()
    last_hour = sum(1 for (at,) in recent if at >= now - timedelta(hours=1))
    if last_hour >= MAX_PER_HOUR or len(recent) >= MAX_PER_DAY:
        raise HTTPException(
            status_code=429,
            detail="Tu as déjà envoyé plusieurs demandes : l'équipe y répond, réessaie plus tard.",
        )

    description = payload.description.strip()
    if len(description) < 10:
        raise HTTPException(status_code=422, detail="Décris ta demande en quelques mots")

    screenshot_id = None
    if payload.screenshot_media_id is not None:
        asset = db.get(MediaAsset, payload.screenshot_media_id)
        # Sa propre image, et rien d'autre : joindre le fichier d'un autre
        # l'ouvrirait à l'équipe sans son accord.
        if asset is None or asset.uploader_id != me or not (asset.mime_type or "").startswith("image/"):
            raise HTTPException(status_code=400, detail="Capture d'écran invalide")
        screenshot_id = asset.id

    encrypted = report_crypto.encrypt_text(description)
    if encrypted is None:
        raise HTTPException(status_code=503, detail=_UNAVAILABLE)

    ticket = SupportTicket(
        user_id=me,
        kind=payload.kind,
        category="QUESTION" if payload.kind == "SUPPORT" else payload.category,
        description_encrypted=encrypted,
        app_version=(payload.app_version or "").strip() or None,
        platform=(payload.platform or "").strip().lower() or None,
        screenshot_media_id=screenshot_id,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return _ticket_json(ticket)


@router.get("/tickets")
def my_tickets(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    rows = (
        db.query(SupportTicket)
        .filter(SupportTicket.user_id == current_user["user_id"])
        .order_by(SupportTicket.created_at.desc(), SupportTicket.id.desc())
        .limit(50)
        .all()
    )
    return {"items": [_ticket_json(t) for t in rows]}


# ── Console d'administration ────────────────────────────────────────────

def _admin_json(db: Session, t: SupportTicket) -> dict:
    """Pour les listes : métadonnées seulement. Le texte ne se déchiffre
    qu'à l'ouverture d'UNE demande, comme les messages d'un signalement."""
    author = db.get(User, t.user_id) if t.user_id else None
    return {
        "id": t.id,
        "kind": t.kind,
        "category": t.category,
        "status": t.status,
        "app_version": t.app_version,
        "platform": t.platform,
        "has_screenshot": t.screenshot_media_id is not None,
        "created_at": t.created_at.isoformat(),
        "replied_at": _iso(t.replied_at),
        "closed_at": _iso(t.closed_at),
        "user": _user_json(author) if author else None,
    }


def _get_ticket(db: Session, ticket_id: int) -> SupportTicket:
    ticket = db.get(SupportTicket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    return ticket


@admin_router.get("/search")
def admin_search(
    q: Optional[str] = Query(None, max_length=80),
    status: str = Query("OPEN", pattern="^(OPEN|ANSWERED|CLOSED|ALL)$"),
    kind: Optional[str] = Query(None, pattern="^(SUPPORT|PROBLEM)$"),
    page: int = Query(1, ge=1),
    size: int = Query(25, ge=1, le=100),
    user: User = Depends(require_permission("reports.view")),
    db: Session = Depends(get_db),
):
    query = db.query(SupportTicket)
    if status != "ALL":
        query = query.filter(SupportTicket.status == status)
    if kind:
        query = query.filter(SupportTicket.kind == kind)
    if q:
        # Le texte est chiffré : on cherche la personne, pas le contenu.
        escaped = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        like = f"%{escaped}%"
        authors = db.query(User.id).filter(
            or_(User.full_name.ilike(like, escape="\\"), User.phone.ilike(like, escape="\\"))
        )
        query = query.filter(SupportTicket.user_id.in_(authors))
    total = query.count()
    rows = query.order_by(SupportTicket.created_at.desc()).offset((page - 1) * size).limit(size).all()
    return {"items": [_admin_json(db, t) for t in rows], "total": total, "page": page, "size": size}


@admin_router.get("/{ticket_id}")
def admin_detail(
    ticket_id: int,
    user: User = Depends(require_permission("reports.view")),
    db: Session = Depends(get_db),
):
    t = _get_ticket(db, ticket_id)
    replier = db.get(User, t.replied_by) if t.replied_by else None
    return {
        **_admin_json(db, t),
        # Déchiffrés ICI seulement. Une clé absente ou changée rend None.
        "description": report_crypto.decrypt_text(t.description_encrypted),
        "reply": report_crypto.decrypt_text(t.reply_encrypted),
        # Servie par GET /media/{id} : la console y a droit avec reports.view.
        "screenshot_media_id": t.screenshot_media_id,
        "replied_by": (replier.full_name or replier.phone) if replier else None,
    }


@admin_router.post("/{ticket_id}/reply")
def admin_reply(
    ticket_id: int,
    body: ReplyBody,
    request: Request,
    user: User = Depends(require_permission("reports.manage")),
    db: Session = Depends(get_db),
):
    """Répondre dans l'application : la réponse s'affiche dans « Mes
    demandes » et arrive dans le centre de notifications."""
    t = _get_ticket(db, ticket_id)
    if t.status == "CLOSED":
        raise HTTPException(status_code=409, detail="Cette demande est close")
    message = body.message.strip()
    encrypted = report_crypto.encrypt_text(message)
    if encrypted is None:
        raise HTTPException(status_code=503, detail="REPORTS_ENCRYPTION_KEY absente : réponse non enregistrée")
    t.reply_encrypted = encrypted
    t.status = "ANSWERED"
    t.replied_by = user.id
    t.replied_at = datetime.utcnow()
    # Le texte de la réponse ne part pas dans la notification (elle passe
    # par les serveurs de push) : il se lit dans l'application.
    notify(
        db, [t.user_id], service="pokou",
        title="Le support Pokou t'a répondu",
        body="Ouvre Réglages › Aide et support › Écrire au support pour lire la réponse.",
        route="support/tickets",
    )
    _audit(db, user, "support_reply", "support_ticket", t.id, None, request)
    db.commit()
    return _admin_json(db, t)


@admin_router.post("/{ticket_id}/close")
def admin_close(
    ticket_id: int,
    request: Request,
    user: User = Depends(require_permission("reports.manage")),
    db: Session = Depends(get_db),
):
    t = _get_ticket(db, ticket_id)
    if t.status == "CLOSED":
        raise HTTPException(status_code=409, detail="Cette demande est déjà close")
    t.status = "CLOSED"
    t.closed_at = datetime.utcnow()
    _audit(db, user, "support_close", "support_ticket", t.id, None, request)
    db.commit()
    return _admin_json(db, t)
