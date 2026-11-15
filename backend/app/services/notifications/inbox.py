"""Écrire dans le centre de notifications (NOT-1), et prévenir par push.

Une seule entrée pour les services : la ligne reste consultable dans le
centre, et le push prévient tout de suite. Le push est best-effort (voir
push_service) ; la ligne, elle, est écrite dans la même transaction que
l'évènement qui la motive.
"""
from typing import Iterable, Optional

from sqlalchemy.orm import Session

from app.models import ServiceNotification, User
from app.services.notifications.push_service import send_push


def notify(
    db: Session,
    user_ids: Iterable[int],
    *,
    service: str,
    title: str,
    body: str,
    route: Optional[str] = None,
    push: bool = True,
) -> None:
    targets = sorted({u for u in user_ids if u})
    for user_id in targets:
        db.add(ServiceNotification(
            user_id=user_id, service=service, title=title[:120], body=body[:280], route=route,
        ))
    db.flush()
    if not push:
        return
    # Réglages · Notifications · Modules : la ligne reste dans le centre,
    # seul le push se tait pour qui a coupé ce service.
    muted = {
        user_id
        for user_id, prefs in db.query(User.id, User.muted_service_pushes)
        .filter(User.id.in_(targets))
        .all()
        if service in (prefs or [])
    }
    for user_id in targets:
        if user_id in muted:
            continue
        send_push(
            db,
            user_id,
            title=title,
            body=body,
            data={"type": "service", "service": service, **({"route": route} if route else {})},
        )
