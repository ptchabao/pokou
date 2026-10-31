"""Réglages système modifiables à chaud (clés de passerelles, tarifs)."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text

from app.core.database import Base


class SystemSetting(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, nullable=False, index=True)
    value = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    updated_by_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
