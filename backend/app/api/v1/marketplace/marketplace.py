"""Pokou — marketplace et catalogue vendeur.

MISE EN RELATION UNIQUEMENT : aucun paiement n'est encaissé ici, aucune
commande n'est créée. Le prix affiché est une information, l'acheteur et le
vendeur s'arrangent ensuite dans la conversation. C'est ce qui explique que
la confiance se joue sur le VENDEUR (avis, note, certification) plutôt que
sur une transaction qui n'existe pas.
"""
from datetime import datetime
from datetime import timedelta
from decimal import Decimal
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.models import Contact, DirectMessage, MarketplaceProduct, MarketplaceProductImage, MarketplaceAd, MarketplaceBoost, MarketplacePayment, MediaAsset, MessageStatus, MessageType, SellerReview, SellerVerificationApplication, User, UserRole
# Réutilise la livraison et la sérialisation des messages directs plutôt que
# de les redéfinir : une fiche produit partagée EST un message, elle doit
# arriver par le même WebSocket, le même push et la même forme sérialisée.
from app.api.v1.messaging.messages import _deliver as deliver_direct_message
from app.api.v1.messaging.messages import _serialize as serialize_direct_message
from app.core.security import get_current_user
from app.utils.identity import est_vendeur_verifie
from app.services.marketplace import marketplace_config_service
from app.services.marketplace.marketplace_monetization_service import ad_amount_for, PRODUCT_BOOST_AMOUNT, STATUS_BOOST_AMOUNT, create_payment

router = APIRouter(prefix="/marketplace", tags=["Pokou marketplace"])

# Mêmes rôles que la certification des chaînes (voir routes/channels.py) —
# certifier un vendeur est un acte d'équipe, jamais du vendeur lui-même.
_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]

# Bornes de la note, appliquées ici et non par une contrainte de base : le
# message d'erreur reste en français et explicite.
_MIN_RATING = 1
_MAX_RATING = 5

_MAX_GALLERY_IMAGES = 8


class ProductPayload(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=4000)
    category: Optional[str] = Field(None, min_length=1, max_length=64)
    location: Optional[str] = Field(None, max_length=255)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    price: Decimal = Field(..., ge=0, max_digits=12, decimal_places=2)
    currency: str = Field("XOF", min_length=3, max_length=8)
    image_media_id: Optional[int] = None
    # Galerie : ids de médias déjà téléversés, dans l'ordre d'affichage
    # voulu. `None` laisse la galerie inchangée, `[]` la vide — la
    # distinction compte, sinon un PATCH qui ne parle pas d'images
    # effacerait la galerie.
    gallery_media_ids: Optional[List[int]] = None
    # `is_active` N'EST PAS ici, et c'est délibéré.
    #
    # Ce drapeau appartient à la modération : c'est lui que bascule
    # `PUT /admin/marketplace/products/{id}/moderation` pour retirer une
    # annonce du marché. Tant qu'il figurait dans ce schéma, il suffisait
    # à un vendeur d'envoyer `{"is_active": true}` sur son propre PATCH
    # pour remettre en ligne ce que la modération venait de retirer —
    # l'application ne le faisait pas, mais l'API l'acceptait, et une API
    # ouverte n'a pas le droit de compter sur la politesse de ses clients.
    #
    # La valeur par défaut de la colonne (`True`) suffit à la création.


def _exiger_devise_connue(db: Session, code: str) -> None:
    """La devise d'un prix doit être une de celles que l'admin a ouvertes.

    Le champ était libre côté application : cinq écritures du franc CFA
    circulaient (« XOF », « FCFA », « fcfa »…), et rien n'empêchait de
    publier un prix en « BTC ». Deux prix dans deux orthographes de la même
    monnaie ne se comparent pas, donc ne s'additionnent pas, donc aucun
    total de catalogue n'était juste.

    Le contrôle est ici, côté serveur, et pas seulement dans le menu
    déroulant : c'est l'API qui décide, pas l'écran.
    """
    if not marketplace_config_service.devise_connue(db, (code or "").upper()):
        raise HTTPException(
            status_code=422,
            detail=f"Devise « {code} » non prise en charge sur ce marché",
        )


class ReviewPayload(BaseModel):
    rating: int = Field(..., ge=_MIN_RATING, le=_MAX_RATING)
    comment: Optional[str] = Field(None, max_length=1000)


class SellerCertification(BaseModel):
    certified: bool


class AdCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    body: str = Field(..., min_length=1, max_length=500)
    media_asset_id: Optional[int] = None
    placement: str = Field("MARKET", pattern="^(MARKET|STATUS)$")
    duration_days: int = Field(7, ge=1, le=30)
    # `amount` a DISPARU de ce schéma, volontairement. Il était fourni par le
    # client : n'importe qui pouvait publier une campagne à un dixième du
    # tarif en changeant un champ de la requête, sans que rien ne le
    # signale — le paiement aboutit, la campagne s'affiche, seul le montant
    # encaissé est faux. Le prix vient maintenant de `ad_amount_for()`.


class VerificationCreate(BaseModel):
    identity_media_id: int
    # Le CODE de la formule, jamais son montant. C'est la leçon des
    # campagnes publicitaires, où le prix arrivait de la requête : on
    # pouvait s'offrir une semaine de diffusion au dixième du tarif.
    # Absent = la formule par défaut, ce que fait l'application jusqu'ici.
    plan: Optional[str] = Field(None, max_length=32)


def _media(asset: Optional[MediaAsset]) -> Optional[dict]:
    if asset is None:
        return None
    return {"id": asset.id, "mime_type": asset.mime_type, "size_bytes": asset.size_bytes, "original_filename": asset.original_filename}


def _rating_summary(db: Session, seller_ids: List[int]) -> dict:
    """Note moyenne + nombre d'avis par vendeur, en UNE requête groupée :
    une liste de 50 produits ne doit pas coûter 50 agrégations."""
    if not seller_ids:
        return {}
    rows = (
        db.query(
            SellerReview.seller_id,
            func.avg(SellerReview.rating),
            func.count(SellerReview.id),
        )
        .filter(SellerReview.seller_id.in_(set(seller_ids)))
        .group_by(SellerReview.seller_id)
        .all()
    )
    return {row[0]: {"rating": round(float(row[1]), 2), "count": row[2]} for row in rows}


def _serialize(product: MarketplaceProduct, rating: Optional[dict] = None, boosted: bool = False) -> dict:
    seller = product.seller
    return {
        "id": product.id,
        "seller_id": product.seller_id,
        "seller_name": (seller.full_name or seller.phone or "Vendeur") if seller else "Vendeur",
        # Le badge de certification vient du COMPTE vendeur, pas du produit :
        # un vendeur certifié l'est sur tout son catalogue.
        "seller_is_certified": est_vendeur_verifie(seller) if seller else False,
        "seller_rating": (rating or {}).get("rating"),
        "seller_review_count": (rating or {}).get("count", 0),
        "name": product.name,
        "description": product.description,
        "category": product.category,
        "location": product.location,
        "latitude": product.latitude,
        "longitude": product.longitude,
        "is_boosted": boosted,
        "price": str(product.price),
        "currency": product.currency,
        "image": _media(product.image_media),
        "gallery": [_media(image.media) for image in product.images if image.media is not None],
        "is_active": product.is_active,
    }


def _serialize_review(review: SellerReview, viewer_id: int) -> dict:
    author = review.author
    return {
        "id": review.id,
        "seller_id": review.seller_id,
        "author_id": review.author_id,
        "author_name": (author.full_name or author.phone or "Utilisateur") if author else "Utilisateur",
        "rating": review.rating,
        "comment": review.comment,
        "created_at": review.created_at.isoformat(),
        "is_mine": review.author_id == viewer_id,
    }


def _require_own_media(db: Session, media_id: int, user_id: int) -> MediaAsset:
    """Un vendeur ne peut illustrer son produit qu'avec SES propres
    téléversements — sinon il suffirait de connaître l'id d'un média d'autrui
    (une photo privée) pour l'afficher publiquement dans son catalogue."""
    asset = db.query(MediaAsset).filter(
        MediaAsset.id == media_id, MediaAsset.uploader_id == user_id
    ).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Image produit introuvable")
    return asset


def _apply_gallery(db: Session, product: MarketplaceProduct, media_ids: List[int], user_id: int) -> None:
    if len(media_ids) > _MAX_GALLERY_IMAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Pas plus de {_MAX_GALLERY_IMAGES} images secondaires par produit",
        )
    for media_id in media_ids:
        _require_own_media(db, media_id, user_id)
    # Remplacement complet : la liste reçue EST la galerie voulue, ce qui
    # rend la requête idempotente (rejouer un PATCH ne duplique rien).
    product.images.clear()
    db.flush()
    for position, media_id in enumerate(media_ids):
        product.images.append(
            MarketplaceProductImage(media_asset_id=media_id, position=position)
        )


@router.get("/config")
async def get_marketplace_config(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les catégories et les devises du marché, telles que l'admin les a
    réglées.

    L'application les tenait en dur : ajouter une catégorie demandait une
    publication Play Store, et la devise était un champ de texte libre où
    « XOF », « FCFA » et « fcfa » cohabitaient sans jamais se comparer.

    Jamais d'erreur ici : si rien n'est configuré, le service renvoie les
    valeurs historiques. Un marché sans filtres serait pire qu'un marché aux
    filtres figés.
    """
    return marketplace_config_service.configuration_publique(db)


@router.get("")
async def list_marketplace(
    seller_id: Optional[int] = Query(None),
    q: Optional[str] = Query(None, max_length=120, description="Recherche nom/description"),
    category: Optional[str] = Query(None, max_length=64),
    location: Optional[str] = Query(None, max_length=255),
    latitude: Optional[float] = Query(None, ge=-90, le=90),
    longitude: Optional[float] = Query(None, ge=-180, le=180),
    limit: int = Query(40, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    query = db.query(MarketplaceProduct).options(*_load_options()).filter(
        MarketplaceProduct.is_active.is_(True),
        MarketplaceProduct.deleted_at.is_(None),
    )
    if seller_id is not None:
        query = query.filter(MarketplaceProduct.seller_id == seller_id)
    if category and category.upper() != "TOUT":
        query = query.filter(MarketplaceProduct.category == category.upper())
    if location and location.strip():
        query = query.filter(MarketplaceProduct.location.ilike(f"%{location.strip()}%"))
    if q and q.strip():
        # Jokers ÉCHAPPÉS : sans ça, une recherche « 100% » ou « _ » se
        # comporterait comme un motif LIKE et ramènerait tout le catalogue.
        needle = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{needle}%"
        query = query.filter(
            or_(
                MarketplaceProduct.name.ilike(pattern, escape="\\"),
                MarketplaceProduct.description.ilike(pattern, escape="\\"),
            )
        )
    items = query.order_by(MarketplaceProduct.created_at.desc()).all()
    distances: dict[int, float] = {item.id: float("inf") for item in items}
    if latitude is not None and longitude is not None:
        from math import asin, cos, radians, sin, sqrt

        def distance(item: MarketplaceProduct) -> float:
            if item.latitude is None or item.longitude is None:
                return float("inf")
            dlat = radians(item.latitude - latitude)
            dlon = radians(item.longitude - longitude)
            value = sin(dlat / 2) ** 2 + cos(radians(latitude)) * cos(radians(item.latitude)) * sin(dlon / 2) ** 2
            return 6371 * 2 * asin(sqrt(value))

        distances = {item.id: distance(item) for item in items}
    now = datetime.utcnow()
    boosted_ids = {
        row[0]
        for row in db.query(MarketplaceBoost.product_id)
        .filter(
            MarketplaceBoost.product_id.isnot(None),
            MarketplaceBoost.starts_at <= now,
            MarketplaceBoost.expires_at > now,
        )
        .all()
    }
    # Les boosts sont un signal de tri, jamais une autorisation d'afficher un
    # produit inactif: le filtre actif reste appliqué par la requête ci-dessus.
    items.sort(key=lambda item: (item.id not in boosted_ids, distances[item.id], -item.created_at.timestamp()))
    page = items[offset:offset + limit]
    ratings = _rating_summary(db, [item.seller_id for item in page])
    return {
        "items": [_serialize(item, ratings.get(item.seller_id), item.id in boosted_ids) for item in page],
        "has_more": offset + limit < len(items),
        "next_offset": offset + limit if offset + limit < len(items) else None,
    }


@router.get("/mine")
async def list_my_products(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    items = (
        db.query(MarketplaceProduct)
        .options(*_load_options())
        .filter(
            MarketplaceProduct.seller_id == current_user["user_id"],
            # Le vendeur non plus ne revoit pas ce qu'il a supprimé : sinon
            # le geste semble sans effet, et il recommence.
            MarketplaceProduct.deleted_at.is_(None),
        )
        .order_by(MarketplaceProduct.updated_at.desc())
        .all()
    )
    ratings = _rating_summary(db, [item.seller_id for item in items])
    now = datetime.utcnow()
    boosted_ids = {
        row[0]
        for row in db.query(MarketplaceBoost.product_id)
        .filter(
            MarketplaceBoost.product_id.isnot(None),
            MarketplaceBoost.seller_id == current_user["user_id"],
            MarketplaceBoost.starts_at <= now,
            MarketplaceBoost.expires_at > now,
        )
        .all()
    }
    return {
        "items": [
            _serialize(item, ratings.get(item.seller_id), item.id in boosted_ids)
            for item in items
        ]
    }


@router.get("/payments/{payment_id}")
async def marketplace_payment_status(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    payment = db.query(MarketplacePayment).filter(
        MarketplacePayment.id == payment_id,
        MarketplacePayment.user_id == current_user["user_id"],
    ).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Paiement introuvable")
    return _payment_json(payment)


@router.post("")
async def create_product(payload: ProductPayload, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    if payload.image_media_id is not None:
        _require_own_media(db, payload.image_media_id, user_id)
    _exiger_devise_connue(db, payload.currency)
    fields = payload.model_dump(exclude={"gallery_media_ids"})
    fields["category"] = (payload.category or "AUTRE").upper()
    item = MarketplaceProduct(seller_id=user_id, **fields)
    db.add(item)
    db.flush()
    if payload.gallery_media_ids:
        _apply_gallery(db, item, payload.gallery_media_ids, user_id)
        # Pas de photo principale, mais une galerie : la première en tient
        # lieu.
        #
        # Le formulaire propose deux zones séparées — « Photo principale »
        # et « Autres photos » — et rien n'obligeait à remplir la première.
        # Une annonce publiée avec des photos ressortait alors SANS image
        # sur sa fiche, parce que la liste ne lit que l'image principale.
        #
        # Corrigé ici, à l'écriture, et pas seulement à l'affichage : la
        # donnée doit être juste pour tous les clients, y compris ceux qui
        # n'existent pas encore.
        if item.image_media_id is None:
            item.image_media_id = payload.gallery_media_ids[0]
    db.commit()
    db.refresh(item)
    return _serialize(item, _rating_summary(db, [item.seller_id]).get(item.seller_id))


@router.patch("/{product_id}")
async def update_product(product_id: int, payload: ProductPayload, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    item = db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id == product_id, MarketplaceProduct.seller_id == user_id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    if payload.image_media_id is not None:
        _require_own_media(db, payload.image_media_id, user_id)
    if "currency" in payload.model_fields_set:
        _exiger_devise_connue(db, payload.currency)
    # `exclude_unset` : un PATCH ne parle que des champs qu'il envoie.
    #
    # Sans cela, `image_media_id` valait None par défaut et était écrit tel
    # quel : toute modification qui ne renvoyait pas la photo principale
    # l'EFFAÇAIT. L'application y échappait seulement parce qu'elle la
    # renvoie systématiquement — un autre client, ou l'admin, aurait perdu
    # l'image en corrigeant un prix.
    #
    # C'est la même règle que la galerie, qui la documentait déjà : absent
    # = inchangé, valeur explicite = appliquée.
    updates = payload.model_dump(exclude={"gallery_media_ids"}, exclude_unset=True)
    if payload.category is None:
        updates.pop("category", None)
    for key, value in updates.items():
        setattr(item, key, value)
    # `None` = galerie inchangée ; `[]` = galerie vidée (voir ProductPayload).
    if payload.gallery_media_ids is not None:
        _apply_gallery(db, item, payload.gallery_media_ids, user_id)
    db.commit()
    db.refresh(item)
    return _serialize(item, _rating_summary(db, [item.seller_id]).get(item.seller_id))


@router.delete("/{product_id}")
async def delete_product(product_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    """Le vendeur retire son annonce — sans que la ligne disparaisse.

    C'était un vrai `DELETE`, et trois choses partaient avec la ligne :

    - les images de l'annonce, en cascade ;
    - **les enregistrements de boost**, en cascade aussi — c'est-à-dire la
      trace d'une somme réellement encaissée, effacée par un geste
      d'interface. Impossible ensuite de prouver ce qui avait été payé ;
    - rien ne cassait visiblement côté conversations, mais leurs bulles
      produit citent `product_id` : elles pointaient dans le vide, et le
      suivi de commande d'un achat en cours perdait son objet.

    `deleted_at` est distinct de `is_active`, qui appartient à la modération
    (voir marketplace_admin.py). Les deux retirent l'annonce du marché, mais
    ne se défont pas de la même main : l'équipe remet en ligne ce qu'elle a
    modéré, elle ne doit pas pouvoir ressusciter ce qu'un vendeur a supprimé.

    Idempotent : resupprimer une annonce déjà retirée répond 200 plutôt que
    404. Un double appui sur un bouton ne doit pas produire une erreur pour
    une action déjà obtenue.
    """
    item = db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product_id, MarketplaceProduct.seller_id == current_user["user_id"]).first()
    if not item:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    if item.deleted_at is None:
        item.deleted_at = datetime.utcnow()
        db.commit()
    return {"deleted": True}


def _payment_json(payment: MarketplacePayment) -> dict:
    return {
        "payment_id": payment.id,
        "status": payment.status.lower(),
        "amount": payment.amount,
        "currency": payment.currency,
        "payment_url": payment.payment_url,
    }


@router.post("/{product_id}/boost")
async def boost_product(product_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    product = db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id == product_id,
        MarketplaceProduct.seller_id == current_user["user_id"],
        MarketplaceProduct.is_active.is_(True),
        # Payer pour mettre en avant une annonce supprimée reviendrait à
        # payer pour du vide, sans que rien ne le dise.
        MarketplaceProduct.deleted_at.is_(None),
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    try:
        payment = create_payment(
            db, user, kind="PRODUCT_BOOST", amount=PRODUCT_BOOST_AMOUNT,
            description=f"Boost annonce 48h — {product.name}",
            metadata={"product_id": product.id},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"kind": "PRODUCT_BOOST", "duration_hours": 48, **_payment_json(payment)}


@router.post("/boost/status/{status_id}")
async def boost_status(status_id: str, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    from app.models import Status

    status_row = db.query(Status).filter(Status.id == status_id, Status.user_id == current_user["user_id"]).first()
    if not status_row:
        raise HTTPException(status_code=404, detail="Statut introuvable")
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    try:
        payment = create_payment(
            db, user, kind="STATUS_BOOST", amount=STATUS_BOOST_AMOUNT,
            description="Boost de statut marchand 48h",
            metadata={"status_id": status_row.id},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"kind": "STATUS_BOOST", "duration_hours": 48, **_payment_json(payment)}


@router.post("/ads")
async def create_ad(payload: AdCreate, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if payload.media_asset_id is not None and not _require_own_media(db, payload.media_asset_id, user.id):
        raise HTTPException(status_code=404, detail="Média publicitaire introuvable")
    try:
        payment = create_payment(
            db, user, kind="AD", amount=ad_amount_for(payload.duration_days),
            description=f"Publicité Pokou — {payload.title}",
            metadata={"duration_days": payload.duration_days},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    ad = MarketplaceAd(
        advertiser_id=user.id, title=payload.title.strip(), body=payload.body.strip(),
        media_asset_id=payload.media_asset_id, placement=payload.placement,
        payment_id=payment.id,
    )
    db.add(ad)
    db.flush()
    payment.metadata_json = {"ad_id": ad.id, "duration_days": payload.duration_days}
    db.commit()
    return {"ad_id": ad.id, "placement": ad.placement, **_payment_json(payment)}


@router.get("/ads/feed")
async def ad_feed(placement: str = Query("MARKET", pattern="^(MARKET|STATUS)$"), db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    now = datetime.utcnow()
    ads = db.query(MarketplaceAd).options(joinedload(MarketplaceAd.media)).filter(
        MarketplaceAd.placement == placement,
        MarketplaceAd.status == "ACTIVE",
        MarketplaceAd.starts_at <= now,
        MarketplaceAd.expires_at > now,
    ).order_by(MarketplaceAd.created_at.desc()).limit(10).all()
    # L'annonceur, pour que « Contacter » mène quelque part : une publicité
    # qu'on ne peut que regarder ne rapporte rien à celui qui l'a payée.
    advertisers = {
        u.id: u
        for u in db.query(User).filter(User.id.in_({ad.advertiser_id for ad in ads})).all()
    } if ads else {}
    return {"items": [{
        "id": ad.id, "title": ad.title, "body": ad.body,
        "placement": ad.placement, "media": _media(ad.media),
        "expires_at": ad.expires_at.isoformat(),
        "advertiser_id": ad.advertiser_id,
        "advertiser_name": _advertiser_name(advertisers.get(ad.advertiser_id)),
    } for ad in ads]}


def _advertiser_name(user: Optional[User]) -> str:
    if user is None:
        return "Annonceur"
    return user.full_name or user.phone or "Annonceur"


@router.post("/ads/{ad_id}/contact")
async def contact_advertiser(
    ad_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ouvre la conversation avec l'annonceur depuis sa publicité.

    Même principe que « Écrire au vendeur » : le premier message est créé
    ici, ce qui autorise ensuite l'échange sans passer par le carnet. Seule
    une publicité EN DIFFUSION ouvre ce droit — sinon l'identifiant d'une
    campagne refusée ou expirée servirait de porte d'entrée vers n'importe
    quel compte."""
    from app.api.v1.messaging.conversations import is_blocked_between

    user_id = current_user["user_id"]
    now = datetime.utcnow()
    ad = db.query(MarketplaceAd).filter(
        MarketplaceAd.id == ad_id,
        MarketplaceAd.status == "ACTIVE",
        MarketplaceAd.starts_at <= now,
        MarketplaceAd.expires_at > now,
    ).first()
    if not ad:
        raise HTTPException(status_code=404, detail="Publicité introuvable")
    if ad.advertiser_id == user_id:
        raise HTTPException(status_code=400, detail="C'est votre propre publicité")
    if is_blocked_between(db, user_id, ad.advertiser_id):
        raise HTTPException(status_code=403, detail="Conversation impossible avec cet annonceur")

    message = DirectMessage(
        sender_id=user_id,
        recipient_id=ad.advertiser_id,
        message_type=MessageType.TEXT,
        content=f"Bonjour, je vous écris au sujet de votre publicité « {ad.title} ».",
        status=MessageStatus.SENT,
    )
    db.add(message)
    db.commit()
    db.refresh(message)

    await deliver_direct_message(db, message)
    advertiser = db.query(User).filter(User.id == ad.advertiser_id).first()
    return {
        "advertiser_id": ad.advertiser_id,
        "advertiser_name": _advertiser_name(advertiser),
        "message": serialize_direct_message(message, user_id),
    }


@router.post("/verification")
async def request_seller_verification(
    payload: VerificationCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    media = db.query(MediaAsset).filter(MediaAsset.id == payload.identity_media_id, MediaAsset.uploader_id == user.id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Pièce d'identité introuvable")
    if db.query(SellerVerificationApplication).filter(
        SellerVerificationApplication.seller_id == user.id,
        SellerVerificationApplication.status == "PENDING",
    ).first():
        raise HTTPException(status_code=409, detail="Une vérification est déjà en attente")
    try:
        formule = marketplace_config_service.formule_verification(db, payload.plan)
    except marketplace_config_service.ConfigurationInvalide as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    try:
        payment = create_payment(
            db, user, kind="VERIFICATION", amount=int(formule["amount"]),
            description=f"Vendeur vérifié Pokou — {formule['label']}",
            metadata={"plan": formule["code"]},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    application = SellerVerificationApplication(
        seller_id=user.id,
        identity_media_id=media.id,
        payment_id=payment.id,
        plan=formule["code"],
        duration_days=formule["duration_days"],
    )
    db.add(application)
    db.flush()
    payment.metadata_json = {"application_id": application.id}
    db.commit()
    return {
        "application_id": application.id,
        "status": application.status,
        "plan": application.plan,
        "duration_days": application.duration_days,
        **_payment_json(payment),
    }


@router.put("/verification/{application_id}")
async def review_seller_verification(application_id: int, payload: SellerCertification, db: Session = Depends(get_db), current_user: dict = Depends(require_admin_role(_TEAM_ROLES))):
    application = db.query(SellerVerificationApplication).filter(SellerVerificationApplication.id == application_id).first()
    if not application:
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    # Mêmes règles que `PUT /marketplace-admin/verifications/{id}` : un dossier
    # n'est examiné qu'une fois, et on ne certifie pas un vendeur dont le
    # paiement n'est pas confirmé. Cette route accordait auparavant un badge
    # PERMANENT (échéance vide) sans rien vérifier.
    if application.status != "PENDING":
        raise HTTPException(status_code=409, detail="Ce dossier a déjà été examiné")
    payment = db.query(MarketplacePayment).filter(MarketplacePayment.id == application.payment_id).first()
    if payload.certified and (payment is None or payment.status != "CONFIRMED"):
        raise HTTPException(status_code=409, detail="Le paiement doit être confirmé avant l'approbation")
    seller = db.query(User).filter(User.id == application.seller_id).first()
    if not seller:
        raise HTTPException(status_code=404, detail="Vendeur introuvable")
    now = datetime.utcnow()
    application.status = "APPROVED" if payload.certified else "REJECTED"
    application.reviewer_id = current_user["user_id"]
    application.reviewed_at = now
    seller.is_certified_seller = payload.certified
    if payload.certified:
        start = seller.certified_seller_until if seller.certified_seller_until and seller.certified_seller_until > now else now
        seller.certified_seller_at = seller.certified_seller_at or now
        seller.certified_seller_until = start + timedelta(days=application.duration_days)
    db.commit()
    return {"application_id": application.id, "status": application.status, "seller_id": seller.id}

def _load_options():
    """Chargements anticipés — sérialiser un produit touche son vendeur, son
    image principale et toute sa galerie. Sans ça, une page de 50 produits
    coûte une centaine de requêtes de plus."""
    return (
        joinedload(MarketplaceProduct.seller),
        joinedload(MarketplaceProduct.image_media),
        selectinload(MarketplaceProduct.images).joinedload(MarketplaceProductImage.media),
    )


# ─── Confiance : avis, note, certification ────────────────────────────────────

@router.get("/sellers/{seller_id}")
async def get_seller_profile(
    seller_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Fiche publique d'un vendeur : sa note, son nombre d'avis, s'il est
    certifié. Sert d'en-tête à son catalogue."""
    seller = db.query(User).filter(User.id == seller_id).first()
    if not seller:
        raise HTTPException(status_code=404, detail="Vendeur introuvable")
    summary = _rating_summary(db, [seller_id]).get(seller_id) or {}
    return {
        "seller_id": seller.id,
        "seller_name": seller.full_name or seller.phone or "Vendeur",
        "is_certified": est_vendeur_verifie(seller),
        "certified_at": seller.certified_seller_at.isoformat() if seller.certified_seller_at else None,
        "rating": summary.get("rating"),
        "review_count": summary.get("count", 0),
        "product_count": db.query(MarketplaceProduct)
        .filter(
            MarketplaceProduct.seller_id == seller_id,
            MarketplaceProduct.is_active.is_(True),
            MarketplaceProduct.deleted_at.is_(None),
        )
        .count(),
    }


@router.get("/sellers/{seller_id}/reviews")
async def list_seller_reviews(
    seller_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    reviews = (
        db.query(SellerReview)
        .options(joinedload(SellerReview.author))
        .filter(SellerReview.seller_id == seller_id)
        .order_by(SellerReview.updated_at.desc())
        .all()
    )
    summary = _rating_summary(db, [seller_id]).get(seller_id) or {}
    return {
        "items": [_serialize_review(review, current_user["user_id"]) for review in reviews],
        "rating": summary.get("rating"),
        "review_count": summary.get("count", 0),
    }


@router.put("/sellers/{seller_id}/review")
async def upsert_seller_review(
    seller_id: int,
    payload: ReviewPayload,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Pose OU met à jour MON avis sur ce vendeur — PUT et non POST : il n'y
    a qu'un avis par personne (contrainte uq_seller_review_author), le
    réécrire est la seule façon de changer d'avis."""
    author_id = current_user["user_id"]
    if seller_id == author_id:
        # Se noter soi-même est le premier réflexe de qui veut gonfler sa
        # réputation ; c'est aussi le plus facile à interdire.
        raise HTTPException(status_code=403, detail="Vous ne pouvez pas vous noter vous-même")
    if not db.query(User).filter(User.id == seller_id).first():
        raise HTTPException(status_code=404, detail="Vendeur introuvable")

    review = db.query(SellerReview).filter(
        SellerReview.seller_id == seller_id, SellerReview.author_id == author_id
    ).first()
    if review is None:
        review = SellerReview(seller_id=seller_id, author_id=author_id)
        db.add(review)
    review.rating = payload.rating
    review.comment = payload.comment
    db.commit()
    db.refresh(review)
    return _serialize_review(review, author_id)


@router.delete("/sellers/{seller_id}/review")
async def delete_seller_review(
    seller_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    review = db.query(SellerReview).filter(
        SellerReview.seller_id == seller_id, SellerReview.author_id == current_user["user_id"]
    ).first()
    if not review:
        raise HTTPException(status_code=404, detail="Avis introuvable")
    db.delete(review)
    db.commit()
    return {"deleted": True}


@router.put("/sellers/{seller_id}/certification")
async def certify_seller(
    seller_id: int,
    payload: SellerCertification,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Certification par l'ÉQUIPE (mêmes rôles que pour les chaînes, voir
    routes/channels.py) : c'est une garantie donnée par la plateforme, elle
    n'aurait aucune valeur si le vendeur pouvait se l'attribuer."""
    seller = db.query(User).filter(User.id == seller_id).first()
    if not seller:
        raise HTTPException(status_code=404, detail="Vendeur introuvable")
    seller.is_certified_seller = payload.certified
    seller.certified_seller_at = datetime.utcnow() if payload.certified else None
    seller.certified_seller_until = None
    db.commit()
    return {
        "seller_id": seller.id,
        "is_certified": est_vendeur_verifie(seller),
        "certified_at": seller.certified_seller_at.isoformat() if seller.certified_seller_at else None,
        "certified_until": seller.certified_seller_until.isoformat()
        if seller.certified_seller_until
        else None,
    }


# ─── Mise en relation : partager un produit dans une conversation ─────────────

class ProductShare(BaseModel):
    """À qui envoyer la fiche. Par défaut au VENDEUR (« écrire au vendeur »
    depuis la fiche produit), mais on peut aussi la transmettre à un
    contact — recommander un article est le geste le plus naturel d'une
    marketplace de mise en relation."""
    recipient_id: Optional[int] = None
    message: Optional[str] = Field(None, max_length=1000)


@router.post("/{product_id}/share")
async def share_product(
    product_id: int,
    payload: ProductShare,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Épingle la fiche produit dans la conversation, puis renvoie le message
    créé — c'est ce qui permet à « Écrire au vendeur » d'ouvrir une
    discussion où l'article dont on parle est déjà sous les yeux, sans que
    l'acheteur ait à le décrire.

    La charge utile porte un INSTANTANÉ du produit (nom, prix, photo) et pas
    seulement son identifiant : la bulle doit rester lisible même si le
    vendeur retire l'article de son catalogue ensuite."""
    user_id = current_user["user_id"]
    product = (
        db.query(MarketplaceProduct)
        .options(joinedload(MarketplaceProduct.seller), joinedload(MarketplaceProduct.image_media))
        .filter(MarketplaceProduct.id == product_id)
        .first()
    )
    # Deux façons de ne plus être en vente, et il faut les deux :
    # `is_active` (la modération l'a retirée) et `deleted_at` (le vendeur
    # l'a supprimée). Seule la première était vérifiée, alors que
    # l'application n'utilise QUE la seconde — une annonce supprimée
    # continuait donc de s'épingler dans les conversations.
    if not product or not product.is_active or product.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Produit introuvable")

    recipient_id = payload.recipient_id or product.seller_id
    if recipient_id == user_id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous envoyer votre propre fiche")

    # Écrire au VENDEUR ne demande pas de l'avoir dans son carnet : c'est
    # tout l'objet d'une marketplace que de mettre en relation des gens qui
    # ne se connaissent pas. Envoyer la fiche à quelqu'un d'AUTRE, en
    # revanche, reste soumis à la règle habituelle du carnet d'adresses.
    if recipient_id != product.seller_id:
        _require_contact_for_share(db, user_id, recipient_id)
    elif not db.query(User).filter(User.id == recipient_id).first():
        raise HTTPException(status_code=404, detail="Vendeur introuvable")

    message = DirectMessage(
        sender_id=user_id,
        recipient_id=recipient_id,
        message_type=MessageType.PRODUCT,
        # Le contenu porte une phrase lisible : les aperçus de conversation
        # et la recherche de messages ne lisent pas `payload`.
        content=(payload.message or "").strip() or f"À propos de : {product.name}",
        payload={
            "product_id": product.id,
            "name": product.name,
            "price": str(product.price),
            "currency": product.currency,
            "seller_id": product.seller_id,
            "image_media_id": product.image_media_id,
        },
        status=MessageStatus.SENT,
    )
    db.add(message)
    db.commit()
    db.refresh(message)

    await deliver_direct_message(db, message)
    return serialize_direct_message(message, user_id)


def _require_contact_for_share(db: Session, owner_id: int, contact_user_id: int) -> None:
    if not db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first():
        raise HTTPException(status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses")
