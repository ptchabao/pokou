"""Assimé — favoris, alertes, statut sponsorisé et bilan de mise en avant.

Les règles des maquettes (Assimé 12 et 14 à 17) :

- **Favoris et alertes** : une alerte est une recherche enregistrée. Elle
  se déclenche à la publication d'une annonce qui y répond, et ne lit
  jamais rien d'autre que l'annonce.
- **Statut sponsorisé** : la mise en avant de 7 jours donne une place dans
  la bande des statuts. UNE seule place, un statut sponsorisé tous les 5
  au plus, réservé aux vendeurs qui ont un badge payant, relu par la
  modération avant d'apparaître, ciblé par ville — jamais à partir des
  messages.
- **Pourquoi je vois ça** et **bilan** : ce que la personne voit d'une
  annonce payée, et ce que le vendeur en a obtenu.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import require_permission_claims
from app.core.security import get_current_user
from app.models import (
    MarketplaceAlert,
    MarketplaceBoost,
    MarketplaceFavorite,
    MarketplaceProduct,
    UserRole,
)
from app.services.events.outbox import record_event
from app.services.notifications.push_service import send_push

router = APIRouter(prefix="/marketplace", tags=["Assimé"])
admin_router = APIRouter(prefix="/admin/marketplace", tags=["Admin Assimé"])

_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]

MAX_ALERTS = 10
#: Au plus un statut sponsorisé tous les 5 statuts : l'application ne
#: l'insère qu'à cette position, ou à la fin d'une bande plus courte.
SPONSORED_STATUS_EVERY = 5
#: La mise en avant qui donne une place dans les statuts.
STATUS_BOOST_DAYS = 7


class AlertBody(BaseModel):
    query: Optional[str] = Field(None, max_length=120)
    category: Optional[str] = Field(None, max_length=64)
    location: Optional[str] = Field(None, max_length=255)
    max_price: Optional[int] = Field(None, ge=0, le=1_000_000_000)


class ModerationBody(BaseModel):
    approve: bool
    reason: Optional[str] = Field(None, max_length=280)


def _snapshot(product: MarketplaceProduct) -> dict:
    """De quoi afficher une carte, sans dépendre de la sérialisation
    complète du catalogue."""
    image = product.image_media
    return {
        "id": product.id,
        "name": product.name,
        "price": str(product.price),
        "currency": product.currency,
        "location": product.location,
        "category": product.category,
        "seller_id": product.seller_id,
        "seller_name": (product.seller.full_name or "Vendeur") if product.seller else "Vendeur",
        "image_media_id": image.id if image else None,
    }


def _live_product(db: Session, product_id: int) -> MarketplaceProduct:
    product = db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id == product_id,
        MarketplaceProduct.is_active.is_(True),
        MarketplaceProduct.deleted_at.is_(None),
    ).first()
    if product is None:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    return product


# ── Favoris ─────────────────────────────────────────────────────────────


@router.get("/favorites")
def list_favorites(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = (
        db.query(MarketplaceProduct)
        .join(MarketplaceFavorite, MarketplaceFavorite.product_id == MarketplaceProduct.id)
        .filter(
            MarketplaceFavorite.user_id == current_user["user_id"],
            MarketplaceProduct.is_active.is_(True),
            MarketplaceProduct.deleted_at.is_(None),
        )
        .order_by(MarketplaceFavorite.created_at.desc())
        .limit(200)
        .all()
    )
    return {"items": [_snapshot(p) for p in rows]}


@router.put("/{product_id}/favorite")
def add_favorite(product_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    _live_product(db, product_id)
    me = current_user["user_id"]
    exists = db.query(MarketplaceFavorite.id).filter(
        MarketplaceFavorite.user_id == me, MarketplaceFavorite.product_id == product_id
    ).first()
    if not exists:
        db.add(MarketplaceFavorite(user_id=me, product_id=product_id))
        db.commit()
    return {"product_id": product_id, "favorite": True}


@router.delete("/{product_id}/favorite")
def remove_favorite(product_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(MarketplaceFavorite).filter(
        MarketplaceFavorite.user_id == current_user["user_id"], MarketplaceFavorite.product_id == product_id
    ).delete()
    db.commit()
    return {"product_id": product_id, "favorite": False}


# ── Alertes ─────────────────────────────────────────────────────────────


def _alert_json(alert: MarketplaceAlert) -> dict:
    return {
        "id": alert.id,
        "query": alert.query,
        "category": alert.category,
        "location": alert.location,
        "max_price": alert.max_price,
        "matches_count": alert.matches_count,
        "last_matched_at": alert.last_matched_at.isoformat() if alert.last_matched_at else None,
        "created_at": alert.created_at.isoformat(),
    }


@router.get("/alerts")
def list_alerts(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(MarketplaceAlert).filter(MarketplaceAlert.user_id == current_user["user_id"]).order_by(
        MarketplaceAlert.created_at.desc()
    ).all()
    return {"items": [_alert_json(a) for a in rows], "max": MAX_ALERTS}


@router.post("/alerts", status_code=201)
def create_alert(body: AlertBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = current_user["user_id"]
    query = (body.query or "").strip() or None
    category = (body.category or "").strip().upper() or None
    if category == "TOUT":
        category = None
    if not query and not category:
        raise HTTPException(status_code=422, detail="Une alerte demande un mot-clé ou une catégorie")
    count = db.query(MarketplaceAlert.id).filter(MarketplaceAlert.user_id == me).count()
    if count >= MAX_ALERTS:
        raise HTTPException(status_code=409, detail=f"Pas plus de {MAX_ALERTS} alertes")
    alert = MarketplaceAlert(
        user_id=me, query=query, category=category,
        location=(body.location or "").strip() or None, max_price=body.max_price,
    )
    db.add(alert)
    db.commit()
    return _alert_json(alert)


@router.delete("/alerts/{alert_id}")
def delete_alert(alert_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(MarketplaceAlert).filter(
        MarketplaceAlert.id == alert_id, MarketplaceAlert.user_id == current_user["user_id"]
    ).delete()
    db.commit()
    return {"ok": True}


def alert_matches(alert: MarketplaceAlert, product: MarketplaceProduct) -> bool:
    if alert.user_id == product.seller_id:
        return False
    if alert.category and (product.category or "").upper() != alert.category:
        return False
    if alert.max_price is not None and product.price is not None and float(product.price) > alert.max_price:
        return False
    if alert.location and alert.location.lower() not in (product.location or "").lower():
        return False
    if alert.query:
        haystack = f"{product.name} {product.description or ''}".lower()
        if not all(word in haystack for word in alert.query.lower().split()):
            return False
    return True


def notify_alerts(db: Session, product: MarketplaceProduct) -> int:
    """Appelée à la publication d'une annonce. Une notification par
    personne, même si plusieurs de ses alertes répondent."""
    now = datetime.utcnow()
    notified: set[int] = set()
    for alert in db.query(MarketplaceAlert).filter(MarketplaceAlert.user_id != product.seller_id).all():
        if not alert_matches(alert, product):
            continue
        alert.matches_count += 1
        alert.last_matched_at = now
        if alert.user_id in notified:
            continue
        notified.add(alert.user_id)
        send_push(
            db, alert.user_id, "Assimé : nouvelle annonce",
            f"{product.name} correspond à votre alerte",
            data={"type": "assime_alert", "product_id": str(product.id)},
        )
    if notified:
        record_event(db, "analytics.events", "assime.alert.matched",
                     {"product_id": product.id, "recipients": len(notified)}, key=f"product-{product.id}")
    return len(notified)


# ── Statut sponsorisé ───────────────────────────────────────────────────


def _active_status_boosts(db: Session, now: datetime):
    return db.query(MarketplaceBoost).filter(
        MarketplaceBoost.product_id.isnot(None),
        MarketplaceBoost.days == STATUS_BOOST_DAYS,
        MarketplaceBoost.status_moderation == "APPROVED",
        MarketplaceBoost.starts_at <= now,
        MarketplaceBoost.expires_at > now,
    )


def _why(product: MarketplaceProduct, boost: MarketplaceBoost) -> dict:
    """« Pourquoi je vois ça » (Assimé 16)."""
    seller = (product.seller.full_name or "Un vendeur") if product.seller else "Un vendeur"
    city = boost.city or product.location
    return {
        "sponsor": seller,
        "city": city,
        "text": (
            f"{seller} a payé pour montrer cette annonce"
            + (f" aux personnes de {city}" if city else "")
            + ". Le ciblage se fait par ville, jamais à partir de vos messages."
        ),
        "ends_at": boost.expires_at.isoformat(),
    }


@router.get("/sponsored-status")
def sponsored_status(
    city: Optional[str] = Query(None, max_length=80),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """La seule place sponsorisée de la bande des statuts, ou rien."""
    from app.api.v1.certified.certified import has_paid_badge

    me = current_user["user_id"]
    now = datetime.utcnow()
    boosts = _active_status_boosts(db, now).order_by(MarketplaceBoost.starts_at).all()
    candidates = []
    for boost in boosts:
        if boost.seller_id == me:
            continue
        if city and boost.city and city.strip().lower() not in boost.city.lower():
            continue
        product = db.query(MarketplaceProduct).filter(
            MarketplaceProduct.id == boost.product_id,
            MarketplaceProduct.is_active.is_(True),
            MarketplaceProduct.deleted_at.is_(None),
        ).first()
        # Réservé aux vendeurs qui ont un badge payant : vérifié à
        # l'affichage, un badge expiré retire la place.
        if product is None or not has_paid_badge(db, boost.seller_id):
            continue
        candidates.append((boost, product))
    if not candidates:
        return {"item": None, "every": SPONSORED_STATUS_EVERY}
    # Rotation à la minute : chacun des vendeurs payants a son tour.
    boost, product = candidates[int(now.timestamp() // 60) % len(candidates)]
    boost.status_views += 1
    db.commit()
    return {
        "item": {
            "boost_id": boost.id,
            "label": "Sponsorisé",
            "product": _snapshot(product),
            "why": _why(product, boost),
        },
        "every": SPONSORED_STATUS_EVERY,
    }


@router.post("/boosts/{boost_id}/contact")
def sponsored_contact(boost_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Contacter le vendeur » depuis une annonce sponsorisée : compté pour
    le bilan, rien de plus — la discussion s'ouvre côté application."""
    boost = db.query(MarketplaceBoost).filter(MarketplaceBoost.id == boost_id).first()
    if boost is None:
        raise HTTPException(status_code=404, detail="Mise en avant introuvable")
    if boost.seller_id != current_user["user_id"]:
        boost.contacts += 1
        db.commit()
    return {"ok": True}


@router.get("/{product_id}/why")
def why_sponsored(product_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    product = _live_product(db, product_id)
    now = datetime.utcnow()
    boost = db.query(MarketplaceBoost).filter(
        MarketplaceBoost.product_id == product.id,
        MarketplaceBoost.starts_at <= now,
        MarketplaceBoost.expires_at > now,
    ).order_by(MarketplaceBoost.expires_at.desc()).first()
    if boost is None:
        return {"sponsored": False}
    return {"sponsored": True, **_why(product, boost)}


@router.get("/{product_id}/boost/report")
def boost_report(product_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le bilan (Assimé 17), pour le seul vendeur de l'annonce."""
    product = db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id == product_id, MarketplaceProduct.seller_id == current_user["user_id"]
    ).first()
    if product is None:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    now = datetime.utcnow()
    boosts = db.query(MarketplaceBoost).filter(MarketplaceBoost.product_id == product.id).order_by(
        MarketplaceBoost.starts_at.desc()
    ).all()
    return {"items": [{
        "boost_id": b.id,
        "days": b.days,
        "starts_at": b.starts_at.isoformat(),
        "expires_at": b.expires_at.isoformat(),
        "active": b.starts_at <= now < b.expires_at,
        "impressions": b.impressions,
        "status_views": b.status_views,
        "contacts": b.contacts,
        "status_moderation": b.status_moderation,
    } for b in boosts]}


# ── Modération des statuts sponsorisés ──────────────────────────────────


@admin_router.get("/sponsored-statuses")
def pending_sponsored_statuses(
    current_user: dict = Depends(require_permission_claims("assime.view")), db: Session = Depends(get_db),
):
    rows = db.query(MarketplaceBoost).filter(MarketplaceBoost.status_moderation == "PENDING").order_by(
        MarketplaceBoost.created_at
    ).all()
    items = []
    for boost in rows:
        product = db.query(MarketplaceProduct).filter(MarketplaceProduct.id == boost.product_id).first()
        if product is not None:
            items.append({"boost_id": boost.id, "city": boost.city, "expires_at": boost.expires_at.isoformat(),
                          "product": _snapshot(product)})
    return {"items": items}


@admin_router.put("/sponsored-statuses/{boost_id}")
def moderate_sponsored_status(
    boost_id: int, body: ModerationBody,
    current_user: dict = Depends(require_permission_claims("assime.manage")), db: Session = Depends(get_db),
):
    boost = db.query(MarketplaceBoost).filter(MarketplaceBoost.id == boost_id).first()
    if boost is None or boost.status_moderation is None:
        raise HTTPException(status_code=404, detail="Statut sponsorisé introuvable")
    boost.status_moderation = "APPROVED" if body.approve else "REJECTED"
    from app.models import AuditLog
    db.add(AuditLog(user_id=current_user["user_id"], action="sponsored_status_review", entity_type="marketplace_boost",
                    entity_id=boost.id, changes={"approved": body.approve, "reason": body.reason}))
    db.commit()
    return {"boost_id": boost.id, "status_moderation": boost.status_moderation}
