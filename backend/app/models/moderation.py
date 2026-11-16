"""Signalements d'abus (DIS-16), traités par l'équipe dans l'espace
d'administration. Le contenu des messages n'y est JAMAIS : ils sont chiffrés
de bout en bout ; le signalement porte qui, qui, quand et le motif choisi —
plus, quand la personne qui signale y CONSENT explicitement, les 5 derniers
messages de la discussion, que SON appareil déchiffre et joint. Ceux-ci sont
chiffrés au repos (`recent_messages_encrypted`, voir
app/core/report_crypto.py) et ne se lisent que dans l'espace
d'administration. Rien d'autre."""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.core.database import Base


class AbuseReport(Base):
    __tablename__ = "abuse_reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    # Nul pour le signalement d'un GROUPE (`group_id`).
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=True, index=True)
    #: Au plus 5 messages {sender, text, sent_at}, joints par l'appareil —
    #: CHIFFRÉS (jeton Fernet). Jamais de version en clair en base.
    recent_messages_encrypted = Column(Text, nullable=True)
    #: Quand la personne qui signale a consenti à joindre ces messages.
    messages_consent_at = Column(DateTime, nullable=True)
    reason = Column(String(280), nullable=True)
    blocked = Column(Integer, nullable=False, default=0)
    #: OPEN | DISMISSED | ACTIONED
    status = Column(String(12), nullable=False, default="OPEN", index=True)
    resolution = Column(String(280), nullable=True)
    resolved_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
