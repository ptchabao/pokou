from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.sync import SyncEvent
from app.core.security import get_current_user
from app.services.messaging.sync_service import parse_cursor, public_event_id, sync_generation

router = APIRouter(prefix="/sync", tags=["Pokou sync"])


@router.get("/events")
async def pull_events(
    # Chaîne opaque « génération.n » (voir sync_service.parse_cursor) ; les
    # versions plus anciennes de l'app envoient un entier nu.
    cursor: str = Query("0", max_length=64),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Return durable events for the authenticated account after its cursor.

    Cursors are opaque to clients even though this initial implementation
    uses monotonically increasing database IDs. Every response is scoped to
    the authenticated user; gaps caused by other users' events are expected.
    """
    start, reset = parse_cursor(db, cursor)
    rows = (
        db.query(SyncEvent)
        .filter(
            SyncEvent.user_id == current_user["user_id"],
            SyncEvent.id > start,
        )
        .order_by(SyncEvent.id.asc())
        .limit(limit + 1)
        .all()
    )
    has_more = len(rows) > limit
    page = rows[:limit]
    next_id = page[-1].id if page else start
    return {
        "events": [
            {
                "id": public_event_id(db, row.id),
                "type": row.event_type,
                "payload": row.payload,
                "created_at": row.created_at,
            }
            for row in page
        ],
        "next_cursor": f"{sync_generation(db)}.{next_id}",
        # Le curseur reçu venait d'une autre base : la lecture est repartie
        # du début.
        "cursor_reset": reset,
        "has_more": has_more,
        "server_time": datetime.now(timezone.utc),
    }