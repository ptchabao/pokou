"""Assimé — la vente en main propre, close par un code.

Pas de paiement en ligne sur Assimé : l'acheteur et le vendeur se
rencontrent. Le parcours (retours des testeurs, maquette Assimé 18 à 20) :

1. le VENDEUR, en face de l'acheteur, touche « Commande validée et livrée »
   (`POST /marketplace/{id}/handover`) ;
2. l'ACHETEUR reçoit un code à 6 chiffres (`GET …/handover`, lui seul le
   voit) et le dit au vendeur ;
3. le vendeur le saisit pour « Clôturer la vente »
   (`POST …/handover/confirm`) : l'annonce est vendue, l'acheteur est invité
   à noter le vendeur (les avis existent déjà : PUT /sellers/{id}/review).

Le code prouve que l'acheteur était là : sans lui, un vendeur pourrait
désigner n'importe qui comme acheteur — et se faire noter par un complice.
Usage unique, valable `HANDOVER_TTL_MINUTES` minutes, `HANDOVER_MAX_ATTEMPTS`
essais ; au plus `HANDOVER_MAX_PER_HOUR` codes par annonce et par heure.
"""
import hmac
import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import MarketplaceHandover, MarketplaceProduct, User

router = APIRouter(prefix="/marketplace", tags=["Pokou marketplace"])

HANDOVER_TTL_MINUTES = 15
HANDOVER_MAX_ATTEMPTS = 5
HANDOVER_MAX_PER_HOUR = 5


class HandoverStart(BaseModel):
    buyer_id: int
    final_price: Optional[int] = Field(None, ge=0, le=100_000_000)


class HandoverConfirm(BaseModel):
    code: str = Field(..., min_length=4, max_length=12)


def _new_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _name(db: Session, user_id: int, fallback: str) -> str:
    user = db.query(User).filter(User.id == user_id).first()
    return (user.full_name if user else None) or fallback


def _refresh(handover: MarketplaceHandover, now: datetime) -> None:
    """Un code périmé ne sert plus : il est effacé à la lecture."""
    if handover.status == "PENDING" and handover.expires_at < now:
        handover.status = "EXPIRED"
        handover.code = None
        handover.closed_at = now


def _latest(db: Session, product_id: int) -> Optional[MarketplaceHandover]:
    return (
        db.query(MarketplaceHandover)
        .filter(MarketplaceHandover.product_id == product_id)
        .order_by(MarketplaceHandover.created_at.desc(), MarketplaceHandover.id.desc())
        .first()
    )


def _json(db: Session, handover: MarketplaceHandover, product: MarketplaceProduct, viewer_id: int) -> dict:
    is_buyer = viewer_id == handover.buyer_id
    data = {
        "product_id": product.id,
        "product_name": product.name,
        "status": handover.status,
        "role": "buyer" if is_buyer else "seller",
        "seller_id": handover.seller_id,
        "seller_name": _name(db, handover.seller_id, "Vendeur"),
        "buyer_id": handover.buyer_id,
        "buyer_name": _name(db, handover.buyer_id, "Acheteur"),
        "final_price": handover.final_price,
        "expires_at": handover.expires_at.isoformat(),
        "attempts_left": max(0, HANDOVER_MAX_ATTEMPTS - (handover.attempts or 0)),
        "ttl_minutes": HANDOVER_TTL_MINUTES,
    }
    # Le code ne va QU'à l'acheteur, et tant qu'il peut servir.
    if is_buyer and handover.status == "PENDING" and handover.code:
        data["code"] = handover.code
    return data


def _seller_product(db: Session, product_id: int, me: int) -> MarketplaceProduct:
    product = db.query(MarketplaceProduct).filter(
        MarketplaceProduct.id == product_id, MarketplaceProduct.seller_id == me,
        MarketplaceProduct.deleted_at.is_(None),
    ).first()
    if product is None:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    return product


@router.post("/{product_id}/handover", status_code=201)
def start_handover(
    product_id: int, payload: HandoverStart,
    db: Session = Depends(get_db), current_user: dict = Depends(get_current_user),
):
    """« Commande validée et livrée » : le vendeur, en face de l'acheteur.
    Un nouveau code remplace le précédent, s'il y en avait un."""
    me = current_user["user_id"]
    product = _seller_product(db, product_id, me)
    if product.sold_at is not None:
        raise HTTPException(status_code=409, detail="Cette annonce est déjà vendue")
    if payload.buyer_id == me or db.query(User.id).filter(User.id == payload.buyer_id).first() is None:
        raise HTTPException(status_code=422, detail="Acheteur introuvable")
    now = datetime.utcnow()
    recent = db.query(MarketplaceHandover.id).filter(
        MarketplaceHandover.product_id == product.id,
        MarketplaceHandover.created_at > now - timedelta(hours=1),
    ).count()
    if recent >= HANDOVER_MAX_PER_HOUR:
        raise HTTPException(status_code=429, detail={
            "code": "handover_too_many",
            "message": "Trop de codes demandés pour cette annonce : réessaie dans une heure.",
        })
    for previous in db.query(MarketplaceHandover).filter(
        MarketplaceHandover.product_id == product.id, MarketplaceHandover.status == "PENDING",
    ).all():
        previous.status = "CANCELLED"
        previous.code = None
        previous.closed_at = now
    handover = MarketplaceHandover(
        product_id=product.id, seller_id=me, buyer_id=payload.buyer_id,
        code=_new_code(), final_price=payload.final_price,
        status="PENDING", attempts=0,
        expires_at=now + timedelta(minutes=HANDOVER_TTL_MINUTES), created_at=now,
    )
    db.add(handover)
    db.flush()
    from app.services.notifications.inbox import notify

    # Le code n'est PAS dans la notification : elle peut s'afficher sur un
    # écran verrouillé. L'acheteur l'ouvre dans l'app.
    notify(
        db, [payload.buyer_id], service="assime", title=product.name,
        body=f"{_name(db, me, 'Le vendeur')} a validé la remise de l'article. "
             "Ouvre Pokou pour voir ton code et le lui donner.",
        route=f"assime/handover/{product.id}",
    )
    db.commit()
    return _json(db, handover, product, me)


@router.get("/{product_id}/handover")
def get_handover(
    product_id: int,
    db: Session = Depends(get_db), current_user: dict = Depends(get_current_user),
):
    """La remise en cours ou la dernière : pour l'acheteur, avec le code."""
    me = current_user["user_id"]
    handover = _latest(db, product_id)
    if handover is None or me not in (handover.seller_id, handover.buyer_id):
        raise HTTPException(status_code=404, detail="Aucune remise en cours")
    product = db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product_id).first()
    if product is None:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    _refresh(handover, datetime.utcnow())
    db.commit()
    return _json(db, handover, product, me)


@router.post("/{product_id}/handover/confirm")
def confirm_handover(
    product_id: int, payload: HandoverConfirm,
    db: Session = Depends(get_db), current_user: dict = Depends(get_current_user),
):
    """« Clôturer la vente » avec le code que l'acheteur a donné."""
    me = current_user["user_id"]
    product = _seller_product(db, product_id, me)
    handover = _latest(db, product.id)
    now = datetime.utcnow()
    if handover is None or handover.seller_id != me:
        raise HTTPException(status_code=404, detail="Aucune remise en cours")
    _refresh(handover, now)
    if handover.status == "EXPIRED":
        db.commit()
        raise HTTPException(status_code=410, detail={
            "code": "handover_expired",
            "message": "Ce code a expiré : touche à nouveau « Commande validée et livrée ».",
        })
    if handover.status != "PENDING" or not handover.code:
        raise HTTPException(status_code=409, detail={
            "code": "handover_closed",
            "message": "Cette remise est close : recommence pour obtenir un nouveau code.",
        })
    typed = "".join(ch for ch in payload.code if ch.isdigit())
    if not hmac.compare_digest(typed, handover.code):
        handover.attempts = (handover.attempts or 0) + 1
        left = HANDOVER_MAX_ATTEMPTS - handover.attempts
        if left <= 0:
            handover.status = "LOCKED"
            handover.code = None
            handover.closed_at = now
            db.commit()
            raise HTTPException(status_code=429, detail={
                "code": "handover_locked",
                "message": "Trop d'essais : ce code ne marche plus. Recommence pour en obtenir un nouveau.",
                "attempts_left": 0,
            })
        db.commit()
        raise HTTPException(status_code=422, detail={
            "code": "handover_wrong_code",
            "message": "Ce code ne correspond pas.",
            "attempts_left": left,
        })
    if product.sold_at is not None:
        raise HTTPException(status_code=409, detail="Cette annonce est déjà vendue")
    handover.status = "DONE"
    handover.code = None
    handover.closed_at = now
    product.sold_at = now
    product.buyer_id = handover.buyer_id
    product.final_price = handover.final_price
    from app.services.notifications.inbox import notify

    price = handover.final_price if handover.final_price is not None else int(product.price or 0)
    notify(
        db, [handover.buyer_id], service="assime", title=product.name,
        body=(
            f"Vente conclue avec {_name(db, me, 'le vendeur')} pour "
            + f"{price:,} FCFA. ".replace(",", " ")
            + "Comment s'est passée la transaction ? Note le vendeur."
        ),
        route=f"assime/review/{product.id}",
    )
    db.commit()
    return {
        **_json(db, handover, product, me),
        "sold_at": product.sold_at.isoformat(),
    }


@router.delete("/{product_id}/handover")
def cancel_handover(
    product_id: int,
    db: Session = Depends(get_db), current_user: dict = Depends(get_current_user),
):
    """Le vendeur renonce (l'acheteur n'est finalement pas venu)."""
    me = current_user["user_id"]
    product = _seller_product(db, product_id, me)
    handover = _latest(db, product.id)
    if handover is None or handover.status != "PENDING":
        raise HTTPException(status_code=404, detail="Aucune remise en cours")
    handover.status = "CANCELLED"
    handover.code = None
    handover.closed_at = datetime.utcnow()
    db.commit()
    return _json(db, handover, product, me)
