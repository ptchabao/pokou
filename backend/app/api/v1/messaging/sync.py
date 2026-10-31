from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.sync import SyncEvent
from app.core.security import get_current_user

router = APIRouter(prefix="/sync", tags=["Pokou sync"])


@router.get("/events")
async def pull_events(
    cursor: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Return durable events for the authenticated account after its cursor.

    Cursors are opaque to clients even though this initial implementation
    uses monotonically increasing database IDs. Every response is scoped to
    the authenticated user; gaps caused by other users' events are expected.
    """
    rows = (
        db.query(SyncEvent)
        .filter(
            SyncEvent.user_id == current_user["user_id"],
            SyncEvent.id > cursor,
        )
        .order_by(SyncEvent.id.asc())
        .limit(limit + 1)
        .all()
    )
    has_more = len(rows) > limit
    page = rows[:limit]
    next_cursor = page[-1].id if page else cursor
    return {
        "events": [
            {
                "id": str(row.id),
                "type": row.event_type,
                "payload": row.payload,
                "created_at": row.created_at,
            }
            for row in page
        ],
        "next_cursor": str(next_cursor),
        "has_more": has_more,
        "server_time": datetime.now(timezone.utc),
    }