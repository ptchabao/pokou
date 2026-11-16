"""Demandes de support et problèmes signalés depuis Réglages › Aide et
support (« Écrire au support », « Signaler un problème »).

Même régime que les signalements d'abus (app/models/moderation.py) : la
file se traite dans l'espace d'administration, et le texte libre — ce que la
personne raconte, ce que l'équipe lui répond — est CHIFFRÉ au repos avec
REPORTS_ENCRYPTION_KEY (app/core/report_crypto.py). Sans clé, la demande
est refusée plutôt que stockée en clair.

Restent en clair ce qui sert à trier la file : la nature, la catégorie, la
version de l'application et la plateforme."""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.core.database import Base


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id = Column(Integer, primary_key=True, index=True)
    #: La demande appartient à la personne : elle part avec son compte.
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #: SUPPORT (« Écrire au support ») | PROBLEM (« Signaler un problème »)
    kind = Column(String(10), nullable=False, default="SUPPORT", index=True)
    #: Voir app/api/v1/support/support.py, CATEGORIES.
    category = Column(String(20), nullable=False, default="OTHER")
    #: Le texte de la personne — jeton Fernet, jamais en clair.
    description_encrypted = Column(Text, nullable=False)
    app_version = Column(String(32), nullable=True)
    platform = Column(String(16), nullable=True)
    #: Capture d'écran facultative, déposée par POST /media/upload. Lisible
    #: par son auteur et par l'équipe qui voit les signalements.
    screenshot_media_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    #: OPEN | ANSWERED | CLOSED
    status = Column(String(10), nullable=False, default="OPEN", index=True)
    #: La réponse de l'équipe — chiffrée elle aussi.
    reply_encrypted = Column(Text, nullable=True)
    replied_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    replied_at = Column(DateTime, nullable=True)
    closed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
