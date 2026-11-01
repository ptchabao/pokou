"""Pokou certifié : l'abonnement qui porte le badge et ouvre le mode preuve.

L'identité est vérifiée par le NOM DU TITULAIRE DU WALLET qui a payé : un
wallet mobile money est ouvert sur pièce d'identité chez l'opérateur, ce
nom-là est donc déjà vérifié par quelqu'un d'autre. Pokou ne demande pas de
pièce, il compare.
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class CertifiedSubscription(Base):
    __tablename__ = "certified_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    plan = Column(String(24), nullable=False, default="PARTICULIER_MONTHLY")
    #: TRIAL : mode preuve ouvert, pas de badge (CERT-11).
    #: ACTIVE : payé, noms concordants, badge affiché.
    #: NAME_MISMATCH : payé, mais le nom du wallet diffère du nom affiché.
    #: EXPIRED : période échue, plus de badge ni de mode preuve.
    status = Column(String(16), nullable=False, default="TRIAL", index=True)
    trial_ends_at = Column(DateTime, nullable=True)
    current_period_end = Column(DateTime, nullable=True)
    #: Le nom du titulaire, tel que la passerelle le renvoie. Jamais modifié
    #: par la personne : c'est la référence.
    wallet_holder_name = Column(String(160), nullable=True)
    first_paid_at = Column(DateTime, nullable=True)
    #: Vrai si c'est CET abonnement qui a allumé `User.is_verified`. Une
    #: expiration ne retire que ce qu'elle a posé : une certification
    #: accordée par l'équipe survit à la fin de l'abonnement.
    badge_granted = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class CertifiedProApplication(Base):
    """Pokou certifié Pro (maquettes Pro 1 à 5).

    Le justificatif d'abord, le paiement ensuite : le support vérifie sous
    48 h, et la formule Pro ne se paie qu'une fois le dossier validé. Le
    profil Pro montre le NOM COMMERCIAL en premier, puis « Géré par » suivi
    du nom vérifié de la personne (celui du badge Pokou certifié).
    """
    __tablename__ = "certified_pro_applications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    business_name = Column(String(160), nullable=False)
    activity = Column(String(120), nullable=False)
    city = Column(String(80), nullable=True)
    #: Registre de commerce, carte professionnelle, patente… Visible du seul
    #: support, jamais affiché sur le profil.
    document_media_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    #: PENDING (en vérification) | CORRECTION (justificatif à corriger)
    #: | APPROVED (payable) | REJECTED
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    review_note = Column(String(500), nullable=True)
    submitted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    #: L'engagement affiché à la personne : réponse sous 48 h.
    review_due_at = Column(DateTime, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)
    reviewer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
