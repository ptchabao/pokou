"""Signalements d'abus (DIS-16), traités par l'équipe dans l'espace
d'administration. Le contenu des messages n'y est JAMAIS : ils sont chiffrés
de bout en bout ; le signalement porte qui, qui, quand et le motif choisi."""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class AbuseReport(Base):
    __tablename__ = "abuse_reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason = Column(String(280), nullable=True)
    blocked = Column(Integer, nullable=False, default=0)
    #: OPEN | DISMISSED | ACTIONED
    status = Column(String(12), nullable=False, default="OPEN", index=True)
    resolution = Column(String(280), nullable=True)
    resolved_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
