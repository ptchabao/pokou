"""Centre de notifications (NOT-1)."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import ServiceNotification

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
