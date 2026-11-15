"""Centre de notifications (NOT-1)."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from pydantic import BaseModel

from app.models import ServiceNotification, User

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _json(n: ServiceNotification) -> dict:
    return {
        "id": n.id,
        "service": n.service,
        "title": n.title,
        "body": n.body,
        "route": n.route,
        "created_at": n.created_at.isoformat(),
        "read": n.read_at is not None,
    }


@router.get("")
def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    me = current_user["user_id"]
    rows = (
        db.query(ServiceNotification)
        .filter(ServiceNotification.user_id == me)
        .order_by(ServiceNotification.created_at.desc(), ServiceNotification.id.desc())
        .limit(limit)
        .all()
    )
    unread = db.query(ServiceNotification).filter(
        ServiceNotification.user_id == me, ServiceNotification.read_at.is_(None)
    ).count()
    return {"items": [_json(n) for n in rows], "unread": unread}


#: Les services dont on peut couper le push (Réglages · Notifications ·
#: Modules). Les autres — Pokou certifié, Pokou lui-même — passent toujours :
#: ils portent des échéances de paiement et des avis de sécurité.
SERVICES_COUPABLES = ("kory", "honam", "assime")


class ServicePreferences(BaseModel):
    """Partiel : seuls les services envoyés changent."""

    kory: bool | None = None
    honam: bool | None = None
    assime: bool | None = None


def _preferences(user: User) -> dict:
    muted = set(user.muted_service_pushes or [])
    return {service: service not in muted for service in SERVICES_COUPABLES}


@router.get("/preferences")
def get_preferences(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    """Quels services ont le droit de pousser une notification."""
    user = db.get(User, current_user["user_id"])
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return _preferences(user)


@router.put("/preferences")
def update_preferences(
    payload: ServicePreferences,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = db.get(User, current_user["user_id"])
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    muted = set(user.muted_service_pushes or [])
    for service, enabled in payload.model_dump(exclude_unset=True).items():
        if enabled is None:
            continue
        if enabled:
            muted.discard(service)
        else:
            muted.add(service)
    # Une NOUVELLE liste : une colonne JSON modifiée sur place n'est pas vue
    # comme changée par SQLAlchemy.
    user.muted_service_pushes = sorted(muted)
    db.commit()
    return _preferences(user)


@router.post("/read-all")
def read_all(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    db.query(ServiceNotification).filter(
        ServiceNotification.user_id == current_user["user_id"],
        ServiceNotification.read_at.is_(None),
    ).update({ServiceNotification.read_at: datetime.utcnow()}, synchronize_session=False)
    db.commit()
    return {"unread": 0}


@router.post("/{notification_id}/read")
def read_one(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    row = db.query(ServiceNotification).filter(
        ServiceNotification.id == notification_id,
        ServiceNotification.user_id == current_user["user_id"],
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Notification introuvable")
    if row.read_at is None:
        row.read_at = datetime.utcnow()
        db.commit()
    return _json(row)
