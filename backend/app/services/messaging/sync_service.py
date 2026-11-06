import logging
from typing import Any

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.sync import SyncEvent

logger = logging.getLogger(__name__)

# These events change durable UI state. Presence, typing, and call signaling
# are deliberately excluded: they are transient and should not be replayed.
DURABLE_EVENT_TYPES = frozenset({
    "message:new",
    "message:status",
    "message:viewed",
    "message:deleted",
    "message:edited",
    "message:reaction",
    "conversation:updated",
    "group:invitation",
    "group:updated",
    "group:member:added",
    "group:member:removed",
    "group:member:role",
    "group:message:new",
    "group:message:edited",
    "group:message:reaction",
    "group:message:deleted",
    "status:new",
    "status:deleted",
    "user:profile_updated",
    "contact:registered",
    "channel:post",
    "community:member:added",
})


def persist_delivered_event(user_id: int, event: dict[str, Any]) -> int | None:
    event_type = event.get("type")
    if event_type not in DURABLE_EVENT_TYPES:
        return None

    db: Session = SessionLocal()
    try:
        row = append_sync_event(db, user_id, event)
        db.commit()
        return row.id
    except Exception:
        db.rollback()
        logger.exception("Pokou sync event could not be persisted for user %s", user_id)
        return None
    finally:
        db.close()


def append_sync_event(
    db: Session, user_id: int, event: dict[str, Any]
) -> SyncEvent | None:
    """Append a durable event to the caller's transaction without committing."""
    event_type = event.get("type")
    if event_type not in DURABLE_EVENT_TYPES:
        return None
    row = SyncEvent(
        user_id=user_id,
        event_type=event_type,
        payload={key: value for key, value in event.items() if key != "sync_event_id"},
    )
    db.add(row)
    db.flush()
    return row