"""VIP Room — un salon d'abonnés.

**Même réserve que Social Tax, en plus lourde** : le partage de revenus
annoncé au créateur (70 %) suppose un virement sortant vers son Mobile
Money, que Pokou n'a jamais fait et que le contrat Semoa actuel ne prévoit
pas. Ici, `GET /vip/earnings` calcule et EXPOSE la somme due, sans
prétendre la verser. Tant que le reversement n'est pas contractualisé, le
module reste raisonnablement ouvert côté équipe.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.models import MarketplacePayment, MediaAsset, User, VipPost, VipRoom, VipSubscription
from app.core.database import get_db
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.core.security import get_current_user

router = APIRouter(prefix="/vip", tags=["Pokou VIP Room"])

MODULE_SLUG = "vip_room"

MIN_PRICE = 500
MAX_PRICE = 50000
SUBSCRIPTION_DAYS = 30
#: Part reversée au créateur. Nommée ici, une seule fois, parce que c'est le
#: chiffre qu'on lui a promis — le dupliquer serait le trahir quelque part.
CREATOR_SHARE = 0.70


class RoomUpsert(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    pitch: str = Field(..., min_length=10, max_length=500)
    monthly_price: int = Field(..., ge=MIN_PRICE, le=MAX_PRICE)
    is_open: bool = True


class PostCreate(BaseModel):
    text_content: str | None = Field(None, max_length=4000)
    media_asset_id: int | None = None


def _active_subscription(db: Session, room_id: int, user_id: int) -> VipSubscription | None:
    return (
        db.query(VipSubscription)
        .filter(
            VipSubscription.room_id == room_id,
            VipSubscription.subscriber_id == user_id,
            VipSubscription.expires_at > datetime.utcnow(),
        )
        .order_by(VipSubscription.expires_at.desc())
        .first()
    )


def _room_json(
    room: VipRoom, *, viewer_id: int, owner_name: str | None, subscription: VipSubscription | None
) -> dict:
    return {
        "id": room.id,
        "owner_id": room.owner_id,
        "owner_name": owner_name,
        "title": room.title,
        "pitch": room.pitch,
        "monthly_price": room.monthly_price,
        "is_open": room.is_open,
        "is_owner": room.owner_id == viewer_id,
        "is_subscribed": subscription is not None,
        "expires_at": subscription.expires_at.isoformat() if subscription else None,
    }


@router.get("/room/me")
async def my_room(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.owner_id == user_id).first()
    if room is None:
        return {"room": None}
    subscribers = (
        db.query(VipSubscription)
        .filter(VipSubscription.room_id == room.id, VipSubscription.expires_at > datetime.utcnow())
        .count()
    )
    return {
        "room": _room_json(room, viewer_id=user_id, owner_name=None, subscription=None),
        "active_subscribers": subscribers,
    }


@router.put("/room")
async def upsert_room(
    payload: RoomUpsert,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ouvre ou met à jour MON salon. Un seul par compte.

    Le prix change librement : il ne s'applique qu'aux abonnements SUIVANTS,
    puisque chacun a payé le sien d'avance pour une durée fixe.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.owner_id == user_id).first()
    if room is None:
        room = VipRoom(owner_id=user_id)
        db.add(room)
    room.title = payload.title.strip()
    room.pitch = payload.pitch.strip()
    room.monthly_price = payload.monthly_price
    room.is_open = payload.is_open
    db.commit()
    db.refresh(room)
    return _room_json(room, viewer_id=user_id, owner_name=None, subscription=None)


@router.get("/rooms")
async def open_rooms(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    rooms = (
        db.query(VipRoom)
        .filter(VipRoom.is_open.is_(True), VipRoom.owner_id != user_id)
        .order_by(VipRoom.created_at.desc())
        .limit(50)
        .all()
    )
    names = {
        u.id: (u.full_name or "Créateur")
        for u in db.query(User).filter(User.id.in_({r.owner_id for r in rooms} or {-1}))
    }
    return {
        "items": [
            _room_json(
                r,
                viewer_id=user_id,
                owner_name=names.get(r.owner_id),
                subscription=_active_subscription(db, r.id, user_id),
            )
            for r in rooms
        ]
    }


@router.get("/subscriptions")
async def my_subscriptions(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    rows = (
        db.query(VipSubscription, VipRoom)
        .join(VipRoom, VipRoom.id == VipSubscription.room_id)
        .filter(
            VipSubscription.subscriber_id == user_id,
            VipSubscription.expires_at > datetime.utcnow(),
        )
        .order_by(VipSubscription.expires_at.desc())
        .all()
    )
    # Un salon, une ligne. Renouveler avant l'échéance crée un SECOND
    # abonnement actif (c'est ainsi que la prolongation s'accumule) ; les
    # afficher tous les deux ferait croire qu'on paie deux fois le même
    # salon. On garde le plus lointain, qui est la vraie date de fin.
    latest: dict[int, tuple] = {}
    for sub, room in rows:
        latest.setdefault(room.id, (sub, room))
    names = {
        u.id: (u.full_name or "Créateur")
        for u in db.query(User).filter(User.id.in_({r.owner_id for _, r in latest.values()} or {-1}))
    }
    return {
        "items": [
            _room_json(room, viewer_id=user_id, owner_name=names.get(room.owner_id), subscription=sub)
            for sub, room in latest.values()
        ]
    }


@router.post("/rooms/{room_id}/subscribe")
async def subscribe(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.id == room_id).first()
    if room is None or not room.is_open:
        raise HTTPException(status_code=404, detail="Salon introuvable")
    if room.owner_id == user_id:
        raise HTTPException(status_code=400, detail="C'est votre salon")

    payment = open_payment(
        db, user_id,
        kind="VIP_SUBSCRIPTION",
        amount=room.monthly_price,
        description=f"VIP Room — {room.title}",
        metadata={"module": MODULE_SLUG, "room_id": room.id},
    )
    db.commit()
    return payment_json(payment)


@router.get("/rooms/{room_id}/posts")
async def posts(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le contenu du salon, réservé aux abonnés et au propriétaire.

    Le refus renvoie le salon lui-même : quelqu'un qui tombe sur un lien doit
    voir CE qu'il achèterait, sinon il n'a aucune raison de payer.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.id == room_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Salon introuvable")

    owner = db.query(User).filter(User.id == room.owner_id).first()
    owner_name = owner.full_name if owner else None
    subscription = _active_subscription(db, room.id, user_id)
    if room.owner_id != user_id and subscription is None:
        return {
            "room": _room_json(room, viewer_id=user_id, owner_name=owner_name, subscription=None),
            "locked": True,
            "items": [],
        }

    rows = (
        db.query(VipPost)
        .filter(VipPost.room_id == room.id)
        .order_by(VipPost.created_at.desc())
        .limit(100)
        .all()
    )
    return {
        "room": _room_json(room, viewer_id=user_id, owner_name=owner_name, subscription=subscription),
        "locked": False,
        "items": [
            {
                "id": p.id,
                "text_content": p.text_content,
                # Même forme que partout ailleurs dans Pokou : le client
                # télécharge le média par la route authentifiée et le met en
                # cache. Une URL publique contournerait l'abonnement.
                "media": {
                    "id": p.media.id,
                    "mime_type": p.media.mime_type,
                    "size_bytes": p.media.size_bytes,
                    "original_filename": p.media.original_filename,
                } if p.media else None,
                "created_at": p.created_at.isoformat(),
            }
            for p in rows
        ],
    }


@router.post("/posts")
async def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.owner_id == user_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Ouvrez d'abord votre salon")
    if not (payload.text_content or "").strip() and payload.media_asset_id is None:
        raise HTTPException(status_code=400, detail="Publication vide")
    if payload.media_asset_id is not None:
        media = (
            db.query(MediaAsset)
            .filter(MediaAsset.id == payload.media_asset_id, MediaAsset.uploader_id == user_id)
            .first()
        )
        # Sans ce contrôle, on publierait le média de quelqu'un d'autre en
        # citant simplement son identifiant.
        if media is None:
            raise HTTPException(status_code=404, detail="Média introuvable")

    post = VipPost(
        room_id=room.id,
        text_content=(payload.text_content or "").strip() or None,
        media_asset_id=payload.media_asset_id,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return {"id": post.id, "created_at": post.created_at.isoformat()}


@router.get("/earnings")
async def earnings(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce que mon salon a rapporté, et ce qui m'est dû.

    « Dû », pas « versé ». Le virement est une opération manuelle de
    l'équipe tant que le reversement n'est pas contractualisé.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    room = db.query(VipRoom).filter(VipRoom.owner_id == user_id).first()
    if room is None:
        return {"gross": 0, "due": 0, "subscriptions": 0, "mode": "manual"}

    # Le montant réellement encaissé est celui du PAIEMENT, pas le prix
    # affiché aujourd'hui : le créateur peut avoir changé son tarif depuis.
    rows = (
        db.query(MarketplacePayment.amount)
        .join(VipSubscription, VipSubscription.payment_id == MarketplacePayment.id)
        .filter(VipSubscription.room_id == room.id)
        .all()
    )
    gross = sum(amount for (amount,) in rows)
    return {
        "gross": gross,
        "due": int(gross * CREATOR_SHARE),
        "share_rate": CREATOR_SHARE,
        "subscriptions": len(rows),
        "mode": "manual",
        "note": "Le reversement se fait par l'équipe Pokou, sur demande.",
    }


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """L'abonnement naît ici, pas à la demande.

    Un abonnement déjà actif se PROLONGE au lieu de repartir de zéro : sinon
    renouveler trop tôt ferait perdre les jours restants, ce qui punit
    exactement celui qui paie d'avance.
    """
    room_id = (payment.metadata_json or {}).get("room_id")
    if not room_id:
        return None
    room = db.query(VipRoom).filter(VipRoom.id == int(room_id)).first()
    if room is None:
        return None

    now = datetime.utcnow()
    existing = _active_subscription(db, room.id, payment.user_id)
    start = existing.expires_at if existing else now
    subscription = VipSubscription(
        room_id=room.id,
        subscriber_id=payment.user_id,
        payment_id=payment.id,
        started_at=now,
        expires_at=start + timedelta(days=SUBSCRIPTION_DAYS),
    )
    db.add(subscription)
    db.flush()
    return {
        "subscription_id": subscription.id,
        "room_id": room.id,
        "expires_at": subscription.expires_at.isoformat(),
    }
