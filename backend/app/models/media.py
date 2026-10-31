"""Pièces jointes (métadonnées ; le contenu vit dans le stockage objet)."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.core.database import Base


class MediaAsset(Base):
    """Pokou — fichier joint à un message (note vocale/document/image/vidéo)
    ou à un statut. Seule la métadonnée vit ici, jamais le contenu.

    Le contenu part dans un stockage objet S3-compatible (MinIO) dès qu'il est
    configuré, sinon sur le disque local sous `settings.media_storage_dir`.
    `storage_backend` dit lequel des deux détient CE fichier : les pièces
    jointes déposées avant la bascule restent lisibles sur disque sans
    migration de données (voir app/services/media_storage.py)."""
    __tablename__ = "media_assets"

    id = Column(Integer, primary_key=True, index=True)
    uploader_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # Nom de fichier sur disque, ou clé d'objet dans le bucket.
    storage_path = Column(String(255), nullable=False)
    storage_backend = Column(String(10), nullable=False, default="local")  # local | s3
    original_filename = Column(String(255), nullable=True)
    mime_type = Column(String(100), nullable=False)
    size_bytes = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # foreign_keys explicite : users.avatar_media_id crée un second chemin de
    # clé étrangère entre users et media_assets, rendant la jointure ambiguë
    # par défaut.
    uploader = relationship("User", foreign_keys=[uploader_id])
