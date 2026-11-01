"""Marché : annonces, vendeurs, paiements et publicité."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey, Float, Text, UniqueConstraint, Numeric
from sqlalchemy.orm import relationship

from app.core.database import Base


class MarketplaceProduct(Base):
    """Produit publié par un utilisateur dans son catalogue Pokou."""
    __tablename__ = "marketplace_products"

    id = Column(Integer, primary_key=True, index=True)
    seller_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(64), nullable=False, default="AUTRE")
    location = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    price = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(8), nullable=False, default="XOF")
    image_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    #: Retiré par la MODÉRATION. Réversible par l'équipe.
    is_active = Column(Boolean, nullable=False, default=True)
    #: Supprimé par SON VENDEUR — et c'est une colonne distincte de
    #: `is_active`, pas un raccourci.
    #:
    #: Les deux retirent l'annonce du marché, mais ne se défont pas de la
    #: même main : l'équipe peut remettre en ligne ce qu'elle a modéré, elle
    #: ne doit PAS pouvoir ressusciter ce qu'un vendeur a supprimé. Les
    #: confondre ferait réapparaître, sur un geste de modération, une annonce
    #: que son auteur avait retirée.
    #:
    #: Suppression DOUCE, jamais un `DELETE` : la ligne est citée par les
    #: bulles produit des conversations, par le suivi de commande, et par les
    #: enregistrements de boost — pour lesquels quelqu'un a payé. L'effacer
    #: détruirait la trace d'une somme encaissée et laisserait des
    #: conversations pointant dans le vide.
    deleted_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    seller = relationship("User", back_populates="marketplace_products", foreign_keys=[seller_id])
    image_media = relationship("MediaAsset")
    # Galerie ordonnée. Table à part et non une liste JSON de media_id : ce
    # sont de vraies pièces jointes, donc de vraies clés étrangères — un
    # média supprimé ne doit pas laisser un id orphelin dans un blob.
    images = relationship(
        "MarketplaceProductImage",
        cascade="all, delete-orphan",
        backref="product",
        order_by="MarketplaceProductImage.position",
    )


class MarketplaceProductImage(Base):
    """Image secondaire d'un produit — l'image PRINCIPALE reste
    `MarketplaceProduct.image_media_id` (c'est celle des vignettes de liste,
    elle doit être atteignable sans charger la galerie)."""
    __tablename__ = "marketplace_product_images"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(
        Integer, ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=False)
    # Ordre voulu par le vendeur — sans lui, la galerie remonterait dans
    # l'ordre arbitraire de la base.
    position = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    media = relationship("MediaAsset")


class SellerReview(Base):
    """Avis laissé sur un VENDEUR, pas sur un produit : dans une marketplace
    de mise en relation (aucun paiement encaissé, voir routes/marketplace.py),
    ce qui compte est la confiance dans la personne — elle survit au retrait
    d'un produit de son catalogue.

    Unicité sur (vendeur, auteur) : un avis par personne, modifiable, plutôt
    qu'un empilement qui laisserait gonfler une note à volonté."""
    __tablename__ = "seller_reviews"

    id = Column(Integer, primary_key=True, index=True)
    seller_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    author_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    rating = Column(Integer, nullable=False)  # 1..5, borné par la route
    comment = Column(String(1000), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    seller = relationship("User", foreign_keys=[seller_id])
    author = relationship("User", foreign_keys=[author_id])

    __table_args__ = (UniqueConstraint("seller_id", "author_id", name="uq_seller_review_author"),)


class MarketplacePayment(Base):
    """Paiement Mobile Money d'une fonctionnalité Marketplace.

    Le paiement est séparé des commandes produit : Pokou ne vend pas le
    stock du vendeur, mais des services de visibilité et de confiance.
    """
    __tablename__ = "marketplace_payments"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(32), nullable=False, index=True)  # PRODUCT_BOOST | STATUS_BOOST | AD | VERIFICATION
    amount = Column(Integer, nullable=False)
    currency = Column(String(8), nullable=False, default="XOF")
    provider = Column(String(32), nullable=False, default="semoa")
    provider_reference = Column(String(255), nullable=True, unique=True, index=True)
    payment_url = Column(String(500), nullable=True)
    status = Column(String(16), nullable=False, default="PENDING", index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    confirmed_at = Column(DateTime, nullable=True)


class MarketplaceBoost(Base):
    """Visibilité payée, active uniquement après confirmation du paiement."""
    __tablename__ = "marketplace_boosts"

    id = Column(Integer, primary_key=True, index=True)
    seller_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(Integer, ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=True, index=True)
    status_id = Column(String(36), ForeignKey("statuses.id", ondelete="CASCADE"), nullable=True, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="CASCADE"), nullable=False, unique=True)
    starts_at = Column(DateTime, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    #: 3 (en tête des résultats) ou 7 (résultats et une place dans la bande
    #: des statuts).
    days = Column(Integer, nullable=True)
    #: La place dans les statuts est relue par la modération : PENDING tant
    #: qu'un humain ne l'a pas vue, puis APPROVED ou REJECTED. Les résultats
    #: de recherche, eux, n'attendent pas.
    status_moderation = Column(String(10), nullable=True, index=True)
    #: Ville ciblée — celle de l'annonce. Jamais déduite des messages.
    city = Column(String(80), nullable=True, index=True)
    #: Bilan de la mise en avant (maquette Assimé 17).
    impressions = Column(Integer, default=0, nullable=False)
    status_views = Column(Integer, default=0, nullable=False)
    contacts = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class MarketplaceFavorite(Base):
    """Une annonce mise de côté (maquette Assimé 12)."""
    __tablename__ = "marketplace_favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(Integer, ForeignKey("marketplace_products.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("user_id", "product_id", name="uq_marketplace_favorite"),)


class MarketplaceAlert(Base):
    """Une recherche enregistrée : prévenir quand une annonce correspond.

    Les critères sont ceux de la recherche, rien d'autre — jamais le
    contenu des discussions."""
    __tablename__ = "marketplace_alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    query = Column(String(120), nullable=True)
    category = Column(String(64), nullable=True)
    location = Column(String(255), nullable=True)
    max_price = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_matched_at = Column(DateTime, nullable=True)
    matches_count = Column(Integer, default=0, nullable=False)


class MarketplaceAd(Base):
    """Campagne publicitaire in-app, activée après paiement et validation."""
    __tablename__ = "marketplace_ads"

    id = Column(Integer, primary_key=True, index=True)
    advertiser_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    body = Column(String(500), nullable=False)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    placement = Column(String(16), nullable=False, default="MARKET")  # MARKET | STATUS
    status = Column(String(16), nullable=False, default="PENDING", index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="CASCADE"), nullable=False, unique=True)
    starts_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    media = relationship("MediaAsset")


class SellerVerificationApplication(Base):
    """Dossier de vérification vendeur, examiné par l'équipe Pokou."""
    __tablename__ = "seller_verification_applications"

    id = Column(Integer, primary_key=True, index=True)
    seller_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    identity_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=False)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="CASCADE"), nullable=False, unique=True)
    plan = Column(String(16), nullable=False, default="ANNUAL")
    duration_days = Column(Integer, nullable=False, default=365)
    status = Column(String(16), nullable=False, default="PENDING", index=True)  # PENDING | APPROVED | REJECTED
    reviewer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    review_note = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)

    identity_media = relationship("MediaAsset")
