"""Packs de stickers, favoris et récents."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class StickerPack(Base):
    """Un ensemble de stickers — officiel, ou créé par quelqu'un.

    `owner_user_id` distingue les deux : nul pour un pack publié par Pokou,
    renseigné pour un pack personnel. Une seule table plutôt que deux, parce
    que tout le reste est identique — l'installation, la recherche, l'envoi
    — et que deux tables obligeraient à faire l'union à chaque lecture.
    """

    __tablename__ = "sticker_packs"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(64), nullable=False)
    # Identifiant lisible, pour partager un pack par lien.
    slug = Column(String(64), nullable=False, unique=True, index=True)
    author_name = Column(String(64), nullable=True)
    # Nul = pack officiel, publié par Pokou.
    owner_user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    cover_media_id = Column(
        Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True
    )
    is_animated = Column(Boolean, nullable=False, default=False)
    # Un pack personnel non publié n'apparaît pas dans la recherche des
    # autres. Le rendre public est un geste délibéré.
    is_public = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    stickers = relationship(
        "Sticker", cascade="all, delete-orphan", back_populates="pack"
    )
    cover = relationship("MediaAsset", foreign_keys=[cover_media_id])


class Sticker(Base):
    """Un sticker : une image, et les mots par lesquels on le trouve.

    `emoji_tags` et `keywords` sont deux chemins de recherche distincts et
    complémentaires. Les emojis servent aux SUGGESTIONS — quelqu'un tape 😂,
    on lui propose les stickers marqués 😂. Les mots servent à la recherche
    écrite. Les mélanger dans un seul champ rendrait impossible de suggérer
    sans aussi chercher.
    """

    __tablename__ = "stickers"

    id = Column(Integer, primary_key=True, index=True)
    pack_id = Column(
        Integer, ForeignKey("sticker_packs.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # INDEXÉ, et ce n'est pas facultatif : `GET /media/{id}` interroge
    # cette colonne pour savoir si un média est un sticker public (voir
    # routes/media.py::_can_access). PostgreSQL n'indexe pas les clés
    # étrangères tout seul — sans cette ligne, chaque ouverture de média
    # parcourait la table entière.
    media_asset_id = Column(
        Integer,
        ForeignKey("media_assets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Les emojis associés, séparés par des espaces : « 😂 🤣 ». Une colonne
    # texte plutôt qu'une table de liaison — on ne fait jamais que chercher
    # « contient cet emoji », et une table coûterait une jointure par frappe.
    emoji_tags = Column(String(128), nullable=True, index=True)
    keywords = Column(String(255), nullable=True)
    position = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    pack = relationship("StickerPack", back_populates="stickers")
    media = relationship("MediaAsset")


class UserStickerPack(Base):
    """Un pack installé par quelqu'un, et sa place dans sa liste."""

    __tablename__ = "user_sticker_packs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    pack_id = Column(
        Integer, ForeignKey("sticker_packs.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # L'ordre choisi par l'utilisateur — il réorganise ses packs.
    position = Column(Integer, nullable=False, default=0)
    installed_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "pack_id", name="uq_user_sticker_pack"),
    )


class StickerFavorite(Base):
    """Un sticker mis de côté, indépendamment de son pack.

    Séparé des récents : un favori est un CHOIX, un récent est une trace.
    Confondre les deux ferait disparaître un favori dès qu'on s'en sert
    moins.
    """

    __tablename__ = "sticker_favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sticker_id = Column(
        Integer, ForeignKey("stickers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "sticker_id", name="uq_sticker_favorite"),
    )


class StickerRecent(Base):
    """Le dernier usage d'un sticker par quelqu'un.

    Une ligne par (personne, sticker) mise à jour, et non une par envoi :
    l'historique complet ne sert à rien et grandirait sans fin. Ce qu'on
    veut, c'est l'ordre des derniers utilisés.
    """

    __tablename__ = "sticker_recents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sticker_id = Column(
        Integer, ForeignKey("stickers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    used_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    __table_args__ = (
        UniqueConstraint("user_id", "sticker_id", name="uq_sticker_recent"),
    )
