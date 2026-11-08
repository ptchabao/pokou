"""Administration de la Marketplace — la moitié manquante de chaque flux.

Le module `marketplace.py` sait EXPOSER les fonctionnalités payantes aux
vendeurs. Ce qu'il ne savait pas faire, c'est permettre à l'équipe de les
voir : un vendeur pouvait déposer un dossier de vérification, le payer, et
personne n'avait de moyen de le retrouver — la route d'examen existait, mais
il fallait déjà connaître l'identifiant du dossier pour l'appeler.

Une file d'attente sans écran de file d'attente n'est pas une file, c'est un
trou. Ce module est cet écran, côté serveur.

Il porte aussi la RELECTURE des publicités, et c'est le point le plus
important ici. Une campagne passait de « payée » à « diffusée » toute seule,
à la confirmation du paiement — alors que le modèle lui-même annonce
« activée après paiement ET validation ». Concrètement, quiconque payait
diffusait son message à tous les utilisateurs de l'application, sans qu'un
humain l'ait jamais lu.
"""
from datetime import datetime
from datetime import timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.core.permissions import require_permission_claims
from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.models import MarketplaceAd, MarketplaceBoost, MarketplacePayment, MarketplaceProduct, MediaAsset, SellerVerificationApplication, User, UserRole
from app.core.audit import AuditLogger
from app.services.marketplace import marketplace_config_service

router = APIRouter(prefix="/admin/marketplace", tags=["Admin Marketplace"])

_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]


def _seller_label(user: Optional[User]) -> str:
    """Un nom lisible, quoi qu'il manque.

    Un compte Pokou n'a ni nom ni e-mail obligatoires — seul le téléphone
    l'est. Une page d'administration qui affiche « None » pour la moitié de
    ses lignes est inutilisable, et c'est exactement ce qui s'était produit
    sur les pages Utilisateurs et Clients.
    """
    if user is None:
        return "compte supprimé"
    return user.full_name or user.email or user.phone or f"#{user.id}"


def _media_url(asset: Optional[MediaAsset]) -> Optional[str]:
    """URL telle que l'ADMIN doit l'appeler — et c'est là que ça se jouait.

    L'admin passe par le rewrite Next `/api/:path*` → `<API>/api/v1/:path*`
    (voir apps/admin/next.config.js). Une URL `/api/v1/media/5` y devient
    donc `/api/v1/v1/media/5` : un `/v1` en double, et un 404 que rien
    n'explique — le lien a l'air parfaitement normal.

    Le préfixe, lui, est indispensable : sans `/api`, la requête part vers
    l'application Next elle-même et non vers l'API.
    """
    return f"/api/media/{asset.id}" if asset else None


# ─── Vue d'ensemble ──────────────────────────────────────────────────────────


@router.get("/overview")
async def marketplace_overview(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.view")),
):
    """Ce qui attend une décision humaine, et ce que la Marketplace a encaissé.

    Les compteurs « en attente » viennent en premier et non le chiffre
    d'affaires : ce sont les seuls qui réclament une action. Un dossier de
    vérification oublié, c'est un vendeur qui a payé 5 000 FCFA et attend ;
    une publicité oubliée, c'est une campagne payée qui ne passe jamais.
    """
    revenue_rows = (
        db.query(
            MarketplacePayment.kind,
            func.count(MarketplacePayment.id),
            func.coalesce(func.sum(MarketplacePayment.amount), 0),
        )
        .filter(MarketplacePayment.status == "CONFIRMED")
        .group_by(MarketplacePayment.kind)
        .all()
    )
    now = datetime.utcnow()

    return {
        "pending": {
            "verifications": db.query(func.count(SellerVerificationApplication.id))
            .filter(SellerVerificationApplication.status == "PENDING")
            .scalar()
            or 0,
            # « PAID » = payée, en attente de relecture. Distinct de
            # « PENDING », qui désigne une campagne dont le paiement n'a même
            # pas abouti : celle-là n'attend personne.
            "ads": db.query(func.count(MarketplaceAd.id))
            .filter(MarketplaceAd.status == "PAID")
            .scalar()
            or 0,
        },
        "revenue": {
            kind: {"count": count, "amount": int(total)} for kind, count, total in revenue_rows
        },
        "revenue_total": sum(int(total) for _, _, total in revenue_rows),
        "active": {
            "boosts": db.query(func.count(MarketplaceBoost.id))
            .filter(MarketplaceBoost.expires_at > now)
            .scalar()
            or 0,
            "ads": db.query(func.count(MarketplaceAd.id))
            .filter(MarketplaceAd.status == "ACTIVE", MarketplaceAd.expires_at > now)
            .scalar()
            or 0,
            "products": db.query(func.count(MarketplaceProduct.id))
            .filter(MarketplaceProduct.is_active.is_(True))
            .scalar()
            or 0,
            "certified_sellers": db.query(func.count(User.id))
            .filter(
                User.is_certified_seller.is_(True),
                or_(User.certified_seller_until.is_(None), User.certified_seller_until > now),
            )
            .scalar()
            or 0,
        },
    }


# ─── Vérifications vendeur ───────────────────────────────────────────────────


@router.get("/verifications")
async def list_verifications(
    status: str = Query("PENDING", pattern="^(PENDING|APPROVED|REJECTED|ALL)$"),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.view")),
):
    """La file d'attente des dossiers — ce qui manquait pour que l'examen
    existe vraiment."""
    query = db.query(SellerVerificationApplication).options(
        joinedload(SellerVerificationApplication.identity_media)
    )
    if status != "ALL":
        query = query.filter(SellerVerificationApplication.status == status)
    applications = (
        query.order_by(SellerVerificationApplication.created_at.asc()).limit(limit).all()
    )

    seller_ids = {a.seller_id for a in applications} | {
        a.reviewer_id for a in applications if a.reviewer_id
    }
    people = {u.id: u for u in db.query(User).filter(User.id.in_(seller_ids)).all()} if seller_ids else {}
    payments = (
        {
            p.id: p
            for p in db.query(MarketplacePayment).filter(
                MarketplacePayment.id.in_([a.payment_id for a in applications])
            )
        }
        if applications
        else {}
    )

    return {
        "items": [
            {
                "id": a.id,
                "seller_id": a.seller_id,
                "seller_name": _seller_label(people.get(a.seller_id)),
                "status": a.status,
                                "plan": a.plan,
                                "duration_days": a.duration_days,
                                "seller_is_certified": bool(people.get(a.seller_id).is_certified_seller)
                                if people.get(a.seller_id)
                                else False,
                                "certified_until": people[a.seller_id].certified_seller_until.isoformat()
                                if people.get(a.seller_id)
                                and people[a.seller_id].certified_seller_until
                                else None,
                # L'admin doit VOIR la pièce d'identité pour décider — sans
                # elle, la page ne sert qu'à cliquer au hasard.
                "identity_media_url": _media_url(a.identity_media),
                "payment_status": payments[a.payment_id].status if a.payment_id in payments else None,
                "reviewer_name": _seller_label(people.get(a.reviewer_id)) if a.reviewer_id else None,
                "review_note": a.review_note,
                "created_at": a.created_at.isoformat(),
                "reviewed_at": a.reviewed_at.isoformat() if a.reviewed_at else None,
            }
            for a in applications
        ]
    }


class VerificationDecision(BaseModel):
    approved: bool
    note: Optional[str] = Field(None, max_length=500)


@router.put("/verifications/{application_id}")
async def decide_verification(
    application_id: int,
    payload: VerificationDecision,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.manage")),
):
    """Accorde ou refuse le badge, avec une NOTE.

    La note n'est pas décorative : un refus sans motif écrit est
    indéfendable si le vendeur le conteste, et l'équipe ne se souviendra pas
    dans six mois pourquoi ce dossier a été rejeté. La route existante
    (`PUT /marketplace/verification/{id}`) ne l'enregistrait pas.
    """
    application = (
        db.query(SellerVerificationApplication)
        .filter(SellerVerificationApplication.id == application_id)
        .first()
    )
    if not application:
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    if application.status != "PENDING":
        raise HTTPException(status_code=409, detail="Ce dossier a déjà été examiné")

    payment = db.query(MarketplacePayment).filter(
        MarketplacePayment.id == application.payment_id
    ).first()
    if payload.approved and (payment is None or payment.status != "CONFIRMED"):
        raise HTTPException(
            status_code=409,
            detail="Le paiement doit être confirmé avant l'approbation",
        )

    seller = db.query(User).filter(User.id == application.seller_id).first()
    if not seller:
        raise HTTPException(status_code=404, detail="Vendeur introuvable")

    application.status = "APPROVED" if payload.approved else "REJECTED"
    application.reviewer_id = current_user["user_id"]
    application.review_note = payload.note
    application.reviewed_at = datetime.utcnow()
    seller.is_certified_seller = payload.approved
    if payload.approved:
        now = datetime.utcnow()
        start = (
            seller.certified_seller_until
            if seller.certified_seller_until
            and seller.certified_seller_until > now
            else now
        )
        seller.is_certified_seller = True
        seller.certified_seller_at = seller.certified_seller_at or now
        seller.certified_seller_until = start + timedelta(
            days=application.duration_days
        )
    # Le `return` de l'approbation précédait ce commit : la route répondait
    # APPROVED, puis la session se refermait sans rien écrire. Le dossier
    # restait en attente et le vendeur jamais certifié.
    db.commit()

    await AuditLogger.log(
        db,
        current_user["user_id"],
        "review",
        "seller_verification",
        application.id,
        changes={"approved": payload.approved, "seller_id": seller.id},
    )
    return {
        "id": application.id,
        "status": application.status,
        "seller_id": seller.id,
        "certified_until": seller.certified_seller_until.isoformat()
        if payload.approved and seller.certified_seller_until
        else None,
    }


# ─── Publicités ──────────────────────────────────────────────────────────────


@router.get("/ads")
async def list_ads(
    status: str = Query("PAID", pattern="^(PENDING|PAID|ACTIVE|REJECTED|ALL)$"),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.view")),
):
    query = db.query(MarketplaceAd).options(joinedload(MarketplaceAd.media))
    if status != "ALL":
        query = query.filter(MarketplaceAd.status == status)
    ads = query.order_by(MarketplaceAd.created_at.desc()).limit(limit).all()

    advertisers = (
        {u.id: u for u in db.query(User).filter(User.id.in_({a.advertiser_id for a in ads}))}
        if ads
        else {}
    )
    return {
        "items": [
            {
                "id": a.id,
                "advertiser_id": a.advertiser_id,
                "advertiser_name": _seller_label(advertisers.get(a.advertiser_id)),
                "title": a.title,
                "body": a.body,
                "media_url": _media_url(a.media),
                "placement": a.placement,
                "status": a.status,
                "created_at": a.created_at.isoformat(),
                "starts_at": a.starts_at.isoformat() if a.starts_at else None,
                "expires_at": a.expires_at.isoformat() if a.expires_at else None,
            }
            for a in ads
        ]
    }


class AdDecision(BaseModel):
    approved: bool
    duration_days: int = Field(7, ge=1, le=90)


@router.put("/ads/{ad_id}")
async def decide_ad(
    ad_id: int,
    payload: AdDecision,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.manage")),
):
    """Diffuse une campagne, ou la refuse.

    C'est ce geste qui manquait entièrement. Une campagne payée s'activait
    seule : n'importe quel message atteignait tous les utilisateurs sans
    qu'aucun humain ne l'ait lu. Sur une application de messagerie, ça veut
    dire escroquerie, contenu illégal ou attaque d'un concurrent diffusés
    sous notre marque.

    Le décompte des jours part de l'APPROBATION, pas du paiement : une
    campagne retenue trois jours en relecture ne doit pas perdre trois jours
    de diffusion payés.
    """
    from datetime import timedelta

    ad = db.query(MarketplaceAd).filter(MarketplaceAd.id == ad_id).first()
    if not ad:
        raise HTTPException(status_code=404, detail="Campagne introuvable")
    if ad.status == "PENDING":
        raise HTTPException(
            status_code=409,
            detail="Cette campagne n'est pas payée — il n'y a rien à diffuser",
        )

    now = datetime.utcnow()
    if payload.approved:
        ad.status = "ACTIVE"
        ad.starts_at = now
        ad.expires_at = now + timedelta(days=payload.duration_days)
    else:
        ad.status = "REJECTED"
        ad.starts_at = None
        ad.expires_at = None
    db.commit()

    await AuditLogger.log(
        db,
        current_user["user_id"],
        "review",
        "marketplace_ad",
        ad.id,
        changes={"approved": payload.approved},
    )
    return {"id": ad.id, "status": ad.status, "expires_at": ad.expires_at.isoformat() if ad.expires_at else None}


# ─── Produits ────────────────────────────────────────────────────────────────


@router.get("/products")
async def list_products(
    q: Optional[str] = Query(None, max_length=120),
    only_inactive: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.view")),
):
    query = db.query(MarketplaceProduct)
    if only_inactive:
        query = query.filter(MarketplaceProduct.is_active.is_(False))
    if q:
        escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        query = query.filter(MarketplaceProduct.name.ilike(f"%{escaped}%", escape="\\"))
    products = query.order_by(MarketplaceProduct.created_at.desc()).limit(limit).all()

    sellers = (
        {u.id: u for u in db.query(User).filter(User.id.in_({p.seller_id for p in products}))}
        if products
        else {}
    )
    return {
        "items": [
            {
                "id": p.id,
                "name": p.name,
                "price": float(p.price),
                "currency": p.currency,
                "seller_id": p.seller_id,
                "seller_name": _seller_label(sellers.get(p.seller_id)),
                "is_active": bool(p.is_active),
                # Distinct de `is_active` : supprimé par SON VENDEUR. La
                # modération ne doit pas pouvoir le remettre en ligne.
                "deleted_by_seller": p.deleted_at is not None,
                "created_at": p.created_at.isoformat(),
            }
            for p in products
        ]
    }


class ProductModeration(BaseModel):
    is_active: bool
    reason: Optional[str] = Field(None, max_length=500)


@router.put("/products/{product_id}")
async def moderate_product(
    product_id: int,
    payload: ProductModeration,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.manage")),
):
    """Retire une annonce du marché, ou la remet.

    On DÉSACTIVE, on ne supprime pas : une suppression effacerait aussi les
    conversations qui pointent vers ce produit, et priverait l'équipe de la
    trace d'une annonce retirée — exactement ce qu'il faut pouvoir montrer
    quand un vendeur conteste.
    """
    product = db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    if product.deleted_at is not None and payload.is_active:
        # Le vendeur l'a retirée lui-même. La remettre en ligne
        # republierait, sous son nom, une annonce qu'il a choisi de
        # supprimer — et il n'en saurait rien. Modérer et supprimer sont
        # deux gestes de mains différentes ; seule celle du vendeur peut
        # défaire la sienne.
        raise HTTPException(
            status_code=409,
            detail="Cette annonce a été supprimée par son vendeur — seul lui peut la republier",
        )
    product.is_active = payload.is_active
    db.commit()

    await AuditLogger.log(
        db,
        current_user["user_id"],
        "moderate",
        "marketplace_product",
        product.id,
        changes={"is_active": payload.is_active, "reason": payload.reason},
    )
    return {"id": product.id, "is_active": bool(product.is_active)}


# ─── Paiements ───────────────────────────────────────────────────────────────


@router.get("/payments")
async def list_payments(
    status: str = Query("ALL", pattern="^(PENDING|CONFIRMED|FAILED|ALL)$"),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_permission_claims("assime.view")),
):
    """Le registre des encaissements — et surtout des paiements RESTÉS en
    attente, qui sont le seul symptôme visible d'une passerelle Mobile Money
    en panne."""
    query = db.query(MarketplacePayment)
    if status != "ALL":
        query = query.filter(MarketplacePayment.status == status)
    payments = query.order_by(MarketplacePayment.created_at.desc()).limit(limit).all()

    users = (
        {u.id: u for u in db.query(User).filter(User.id.in_({p.user_id for p in payments}))}
        if payments
        else {}
    )
    return {
        "items": [
            {
                "id": p.id,
                "user_id": p.user_id,
                "user_name": _seller_label(users.get(p.user_id)),
                "kind": p.kind,
                "amount": p.amount,
                "currency": p.currency,
                "status": p.status,
                "provider_reference": p.provider_reference,
                "created_at": p.created_at.isoformat(),
                "confirmed_at": p.confirmed_at.isoformat() if p.confirmed_at else None,
            }
            for p in payments
        ]
    }


# ── Catégories et devises du marché ───────────────────────────────────────
#
# Elles vivaient en dur dans l'application mobile. Ajouter une catégorie
# demandait donc une publication Play Store — trois jours, et les téléphones
# qui ne se mettent pas à jour gardent l'ancienne liste. Elles se règlent
# maintenant ici, et l'application les relit à chaque ouverture du marché.


class CategorieMarche(BaseModel):
    slug: str = Field(..., min_length=1, max_length=64)
    label: str = Field(..., min_length=1, max_length=64)
    active: bool = True


class DeviseMarche(BaseModel):
    code: str = Field(..., min_length=3, max_length=8)
    label: str = Field(..., min_length=1, max_length=16)
    active: bool = True
    default: bool = False


class FormuleVerification(BaseModel):
    code: str = Field(..., min_length=1, max_length=32)
    label: str = Field(..., min_length=1, max_length=64)
    description: str = Field("", max_length=200)
    amount: int = Field(..., ge=0, le=10_000_000)
    active: bool = True
    default: bool = False


class ConfigurationMarche(BaseModel):
    categories: Optional[List[CategorieMarche]] = None
    currencies: Optional[List[DeviseMarche]] = None
    verification_plans: Optional[List[FormuleVerification]] = None


@router.get("/config")
async def get_marketplace_config_admin(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role([UserRole.ADMIN, UserRole.SUPER_ADMIN])),
):
    """La configuration COMPLÈTE — entrées désactivées comprises.

    La route publique ne renvoie que ce qui est actif : c'est ce dont
    l'application a besoin. L'admin, lui, doit voir ce qu'il a désactivé,
    sinon il ne peut plus le réactiver.
    """
    return {
        "categories": marketplace_config_service.categories(db, actives_seulement=False),
        "currencies": marketplace_config_service.devises(db, actives_seulement=False),
        "verification_plans": marketplace_config_service.formules_verification(
            db, actives_seulement=False
        ),
    }


@router.put("/config")
async def update_marketplace_config(
    payload: ConfigurationMarche,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role([UserRole.ADMIN, UserRole.SUPER_ADMIN])),
):
    """Enregistre les catégories et/ou les devises.

    Une liste absente reste INCHANGÉE — on ne vide pas les devises parce
    qu'on a renommé une catégorie. Le service refuse par ailleurs toute
    configuration qui viderait le marché : au moins une catégorie active, au
    moins une devise active, une seule devise par défaut.
    """
    if (
        payload.categories is None
        and payload.currencies is None
        and payload.verification_plans is None
    ):
        raise HTTPException(status_code=400, detail="Rien à enregistrer")

    resultat: dict = {}
    try:
        if payload.categories is not None:
            resultat["categories"] = marketplace_config_service.enregistrer_categories(
                db, [c.model_dump() for c in payload.categories], current_user["user_id"]
            )
        if payload.currencies is not None:
            resultat["currencies"] = marketplace_config_service.enregistrer_devises(
                db, [d.model_dump() for d in payload.currencies], current_user["user_id"]
            )
        if payload.verification_plans is not None:
            resultat["verification_plans"] = marketplace_config_service.enregistrer_formules(
                db,
                [f.model_dump() for f in payload.verification_plans],
                current_user["user_id"],
            )
    except marketplace_config_service.ConfigurationInvalide as erreur:
        raise HTTPException(status_code=422, detail=str(erreur))

    await AuditLogger.log(
        db,
        current_user["user_id"],
        "update",
        "marketplace_config",
        changes={
            "categories": resultat.get("categories"),
            "currencies": resultat.get("currencies"),
            "verification_plans": resultat.get("verification_plans"),
        },
    )
    return resultat
