from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, JSON, String

from app.core.database import Base


class SyncEvent(Base):
    """A durable event delivered to one Pokou account, ordered by database ID."""

    __tablename__ = "sync_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String(100), nullable=False)
    payload = Column(JSON, nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
    )

    __table_args__ = (
        Index("ix_sync_events_user_cursor", "user_id", "id"),
    )