"""Statuts éphémères et leur confidentialité."""
from datetime import datetime
import enum
import uuid

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, Enum as SQLEnum, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class StatusContentType(str, enum.Enum):
    TEXT = "TEXT"
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"

    def __str__(self):
        return self.value


class Status(Base):
    """Pokou — statut/story façon WhatsApp : visible 24h par mes contacts,
    purgé automatiquement ensuite (voir DataSourceScheduler._status_purge_loop).
    `text_content` porte soit le texte d'un statut TEXT, soit la légende d'un
    statut média (même rôle que `DirectMessage.content`)."""
    __tablename__ = "statuses"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    content_type = Column(SQLEnum(StatusContentType, name="status_content_type"), nullable=False)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    text_content = Column(Text, nullable=True)
    # Couleur de fond d'un statut TEXTE, choisie par son auteur avant
    # publication. Chaîne hexadécimale et non un index dans une palette
    # figée : la palette de l'app peut changer sans réécrire les statuts
    # déjà publiés.
    background_color = Column(String(9), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)

    user = relationship("User")
    media_asset = relationship("MediaAsset")
    views = relationship("StatusView", cascade="all, delete-orphan", backref="status")


class StatusPrivacy(Base):
    """Pokou — qui peut voir MES statuts (Profil > Statuts).

    L'audience est décidée par l'AUTEUR, pas par le spectateur : c'est la
    sémantique de WhatsApp, et la seule qui tienne — sinon il suffirait
    d'ajouter quelqu'un à son carnet d'adresses pour s'inviter dans ses
    statuts.

    `mode` :
      CONTACTS — mes contacts (défaut, en l'absence de ligne) ;
      NOBODY   — personne ;
      EXCEPT   — mes contacts SAUF ceux listés dans StatusPrivacyEntry ;
      ONLY     — uniquement ceux listés dans StatusPrivacyEntry.
    """
    __tablename__ = "status_privacy"

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    mode = Column(String(10), nullable=False, default="CONTACTS")
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    user = relationship("User")
    entries = relationship("StatusPrivacyEntry", cascade="all, delete-orphan", backref="privacy")


class StatusPrivacyEntry(Base):
    """La liste que `StatusPrivacy.mode` interprète : exclusions en mode
    EXCEPT, autorisations en mode ONLY. Une table plutôt qu'une colonne JSON —
    ce sont des références à des utilisateurs, avec l'intégrité qui va avec."""
    __tablename__ = "status_privacy_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("status_privacy.user_id", ondelete="CASCADE"), nullable=False, index=True
    )
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    target = relationship("User", foreign_keys=[target_user_id])


class StatusView(Base):
    """Une ligne par (statut, spectateur) — WhatsApp-style 'vu par'."""
    __tablename__ = "status_views"

    id = Column(Integer, primary_key=True, index=True)
    status_id = Column(String(36), ForeignKey("statuses.id"), nullable=False, index=True)
    viewer_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    viewed_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    viewer = relationship("User")

    __table_args__ = (UniqueConstraint("status_id", "viewer_id", name="uq_status_view_status_viewer"),)
