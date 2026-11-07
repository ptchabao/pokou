"""Sauvegarde chiffrée des discussions (MSG-12, CNX-2).

Le fichier est chiffré SUR LE TÉLÉPHONE avec une clé tirée d'un mot de passe
que seul l'utilisateur connaît : le serveur range un bloc opaque (un média
dont il est l'auteur, voir media.py) et ces quelques métadonnées — jamais la
clé, jamais le mot de passe.
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class UserBackup(Base):
    __tablename__ = "user_backups"

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    #: Dérivation de la clé (PBKDF2-HMAC-SHA256) : sel et itérations.
    salt = Column(String(64), nullable=False)
    iterations = Column(Integer, nullable=False)
    discussions = Column(Integer, nullable=False, default=0)
    messages = Column(Integer, nullable=False, default=0)
    size_bytes = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
