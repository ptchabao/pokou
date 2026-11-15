"""Signalements d'abus (DIS-16), traités par l'équipe dans l'espace
d'administration. Le contenu des messages n'y est JAMAIS : ils sont chiffrés
de bout en bout ; le signalement porte qui, qui, quand et le motif choisi —
plus, quand la personne qui signale l'accepte, les 5 derniers messages de la
discussion, que SON appareil déchiffre et joint (`recent_messages`).
Rien d'autre."""
from datetime import datetime

from sqlalchemy import JSON, Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class AbuseReport(Base):
    __tablename__ = "abuse_reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    # Nul pour le signalement d'un GROUPE (`group_id`).
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=True, index=True)
    #: Au plus 5 messages {sender, text, sent_at}, joints par l'appareil.
    recent_messages = Column(JSON, nullable=True)
    reason = Column(String(280), nullable=True)
    blocked = Column(Integer, nullable=False, default=0)
    #: OPEN | DISMISSED | ACTIONED
    status = Column(String(12), nullable=False, default="OPEN", index=True)
    resolution = Column(String(280), nullable=True)
    resolved_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
