"""Les bannières du carrousel de l'accueil — publicités et annonces, par
zone géographique.

Une bannière vise un PAYS (code ISO à deux lettres ; vide = partout) et, à
l'intérieur, éventuellement une RÉGION ou une ville (texte libre, comparé
sans tenir compte de la casse ni des accents à la ville du profil ; vide =
tout le pays). Elle est gérée depuis la console d'administration, jamais
codée dans l'application : une campagne se lance et s'arrête sans mise à
jour de l'app.
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.database import Base


class HomeBanner(Base):
    __tablename__ = "home_banners"

    id = Column(Integer, primary_key=True, index=True)
    #: La petite ligne au-dessus du titre : l'annonceur, ou « Sponsorisé ».
    label = Column(String(40), nullable=True)
    title = Column(String(80), nullable=False)
    body = Column(String(200), nullable=True)
    image_media_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    cta_label = Column(String(30), nullable=True)
    #: `https://…` (ouvert dans le navigateur) ou `app:kory`, `app:honam`,
    #: `app:assime` (ouvre le module dans l'application).
    cta_url = Column(String(500), nullable=True)
    #: Code pays ISO (TG, CI, BJ…) ; NULL = tous les pays.
    country = Column(String(2), nullable=True, index=True)
    #: Région ou ville dans le pays ; NULL = tout le pays.
    region = Column(String(80), nullable=True)
    position = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
    starts_at = Column(DateTime, nullable=True)
    ends_at = Column(DateTime, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    image = relationship("MediaAsset", foreign_keys=[image_media_id])
