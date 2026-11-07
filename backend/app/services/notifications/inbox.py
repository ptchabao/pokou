"""Écrire dans le centre de notifications (NOT-1), et prévenir par push.

Une seule entrée pour les services : la ligne reste consultable dans le
centre, et le push prévient tout de suite. Le push est best-effort (voir
push_service) ; la ligne, elle, est écrite dans la même transaction que
l'évènement qui la motive.
"""
from typing import Iterable, Optional

from sqlalchemy.orm import Session

from app.models import ServiceNotification
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
    for user_id in targets:
        send_push(
            db,
            user_id,
            title=title,
            body=body,
            data={"type": "service", "service": service, **({"route": route} if route else {})},
        )
