"""Hype Train — un objectif collectif, atteint ensemble ou pas du tout.

Ce qui est débloqué est un CONTENU (la promesse du créateur), jamais de
l'argent rendu : c'est ce qui sépare ce module de Gift Rain, abandonné
parce que reconvertir des cadeaux en Mobile Money est une émission de
monnaie électronique. Même réserve de reversement que VIP Room : la part
due au créateur est calculée et affichée, pas virée.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import HypeContribution, HypeTrain, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.core.security import get_current_user

router = APIRouter(prefix="/hype", tags=["Pokou Hype Train"])

MODULE_SLUG = "hype_train"

MIN_GOAL = 1000
MAX_GOAL = 5000000
MIN_CONTRIBUTION = 100
MAX_CONTRIBUTION = 200000
MAX_HOURS = 168  # sept jours
CREATOR_SHARE = 0.70


class TrainCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    promise: str = Field(..., min_length=10, max_length=500)
    goal_amount: int = Field(..., ge=MIN_GOAL, le=MAX_GOAL)
    hours: int = Field(24, ge=1, le=MAX_HOURS)


class ContributionCreate(BaseModel):
    amount: int = Field(..., ge=MIN_CONTRIBUTION, le=MAX_CONTRIBUTION)


def _train_json(train: HypeTrain, *, viewer_id: int, owner_name: str | None) -> dict:
    now = datetime.utcnow()
    unlocked = train.unlocked_at is not None
    return {
        "id": train.id,
        "owner_id": train.owner_id,
        "owner_name": owner_name,
        "title": train.title,
        # La promesse est visible AVANT de payer. L'inverse serait vendre à
        # l'aveugle, et c'est ce qui rend un module de ce genre condamnable.
        "promise": train.promise,
        "goal_amount": train.goal_amount,
        "collected_amount": train.collected_amount,
        "progress": min(1.0, train.collected_amount / train.goal_amount) if train.goal_amount else 0.0,
        "is_unlocked": unlocked,
        "unlocked_at": train.unlocked_at.isoformat() if unlocked else None,
        "expires_at": train.expires_at.isoformat(),
        "seconds_left": max(0, int((train.expires_at - now).total_seconds())),
        # Un train expiré SANS palier reste consultable : effacer l'échec
        # empêcherait les contributeurs de voir ce qu'il est devenu.
        "is_live": not unlocked and train.expires_at > now,
        "is_owner": train.owner_id == viewer_id,
    }


def _names(db: Session, ids: set[int]) -> dict:
    return {
        u.id: (u.full_name or "Créateur")
        for u in db.query(User).filter(User.id.in_(ids or {-1}))
    }


@router.post("")
async def create_train(
    payload: TrainCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Lance un objectif. Un seul en cours à la fois.

    Plusieurs trains simultanés du même créateur mettraient ses
    contributeurs en concurrence avec eux-mêmes : chacun avancerait deux
    fois moins vite, et aucun ne tomberait.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    live = (
        db.query(HypeTrain.id)
        .filter(
            HypeTrain.owner_id == user_id,
            HypeTrain.unlocked_at.is_(None),
            HypeTrain.expires_at > now,
        )
        .first()
    )
    if live is not None:
        raise HTTPException(status_code=409, detail="Un objectif est déjà en cours")

    train = HypeTrain(
        owner_id=user_id,
        title=payload.title.strip(),
        promise=payload.promise.strip(),
        goal_amount=payload.goal_amount,
        expires_at=now + timedelta(hours=payload.hours),
    )
    db.add(train)
    db.commit()
    db.refresh(train)
    return _train_json(train, viewer_id=user_id, owner_name=None)


@router.get("")
async def live_trains(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    rows = (
        db.query(HypeTrain)
        .filter(HypeTrain.unlocked_at.is_(None), HypeTrain.expires_at > now)
        .order_by(HypeTrain.expires_at)
        .limit(50)
        .all()
    )
    names = _names(db, {t.owner_id for t in rows})
    return {"items": [_train_json(t, viewer_id=user_id, owner_name=names.get(t.owner_id)) for t in rows]}


@router.get("/mine")
async def my_trains(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les miens, et ceux où j'ai mis quelque chose."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    backed = {
        row[0]
        for row in db.query(HypeContribution.train_id).filter(
            HypeContribution.contributor_id == user_id,
            HypeContribution.status == "CONFIRMED",
        )
    }
    rows = (
        db.query(HypeTrain)
        .filter((HypeTrain.owner_id == user_id) | (HypeTrain.id.in_(backed or {-1})))
        .order_by(HypeTrain.created_at.desc())
        .limit(50)
        .all()
    )
    names = _names(db, {t.owner_id for t in rows})
    return {"items": [_train_json(t, viewer_id=user_id, owner_name=names.get(t.owner_id)) for t in rows]}


@router.get("/{train_id}")
async def train_detail(
    train_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    train = db.query(HypeTrain).filter(HypeTrain.id == train_id).first()
    if train is None:
        raise HTTPException(status_code=404, detail="Objectif introuvable")

    contributions = (
        db.query(HypeContribution)
        .filter(HypeContribution.train_id == train.id, HypeContribution.status == "CONFIRMED")
        .order_by(HypeContribution.amount.desc())
        .limit(100)
        .all()
    )
    names = _names(db, {c.contributor_id for c in contributions} | {train.owner_id})
    payload = {
        **_train_json(train, viewer_id=user_id, owner_name=names.get(train.owner_id)),
        "contributors": [
            {
                "amount": c.amount,
                "name": names.get(c.contributor_id),
                "is_mine": c.contributor_id == user_id,
            }
            for c in contributions
        ],
    }
    if train.owner_id == user_id:
        gross = sum(c.amount for c in contributions)
        payload["earnings"] = {
            "gross": gross,
            "due": int(gross * CREATOR_SHARE),
            "share_rate": CREATOR_SHARE,
            "mode": "manual",
        }
    return payload


@router.post("/{train_id}/contribute")
async def contribute(
    train_id: int,
    payload: ContributionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    train = db.query(HypeTrain).filter(HypeTrain.id == train_id).first()
    if train is None:
        raise HTTPException(status_code=404, detail="Objectif introuvable")
    if train.expires_at <= datetime.utcnow():
        raise HTTPException(status_code=409, detail="Cet objectif est terminé")
    if train.unlocked_at is not None:
        raise HTTPException(status_code=409, detail="Le palier est déjà tombé")
    if train.owner_id == user_id:
        # Sinon un créateur pourrait faire tomber son propre palier et
        # afficher un succès que personne n'a financé.
        raise HTTPException(status_code=400, detail="C'est votre objectif")

    contribution = HypeContribution(
        train_id=train.id, contributor_id=user_id, amount=payload.amount, status="PENDING"
    )
    db.add(contribution)
    db.flush()
    payment = open_payment(
        db, user_id,
        kind="HYPE_CONTRIBUTION",
        amount=payload.amount,
        description=f"Hype Train — {train.title}",
        metadata={"module": MODULE_SLUG, "contribution_id": contribution.id, "train_id": train.id},
    )
    contribution.payment_id = payment.id
    db.commit()
    return {"contribution_id": contribution.id, **payment_json(payment)}


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    contribution_id = (payment.metadata_json or {}).get("contribution_id")
    if not contribution_id:
        return None
    contribution = (
        db.query(HypeContribution).filter(HypeContribution.id == int(contribution_id)).first()
    )
    if contribution is None or contribution.status != "PENDING":
        return None
    contribution.status = "CONFIRMED"
    train = db.query(HypeTrain).filter(HypeTrain.id == contribution.train_id).first()
    if train is None:
        return {"contribution_id": contribution.id}

    train.collected_amount += contribution.amount
    unlocked_now = False
    # Le paiement peut se confirmer après l'échéance : on compte quand même,
    # parce que la personne a payé à temps. C'est la passerelle qui a tardé,
    # pas elle.
    if train.unlocked_at is None and train.collected_amount >= train.goal_amount:
        train.unlocked_at = datetime.utcnow()
        unlocked_now = True
    return {
        "contribution_id": contribution.id,
        "train_id": train.id,
        "collected_amount": train.collected_amount,
        "unlocked": train.unlocked_at is not None,
        "unlocked_now": unlocked_now,
    }
