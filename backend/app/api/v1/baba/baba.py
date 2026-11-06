"""Baba — l'assistant IA, servi par l'API Pokou.

Même contrat que l'ancien service Mahizu (`/minou/*`), pour que
l'application n'ait qu'à changer d'adresse : `status`, `thread`, `messages`.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import BabaMessage, User
from app.services.baba import baba_service

router = APIRouter(prefix="/baba", tags=["Baba"])

#: Plafond par utilisateur et par heure : chaque message coûte un appel
#: au modèle de langage.
HOURLY_LIMIT = 30


class BabaSend(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)


def _item(row: BabaMessage) -> dict:
    return {
        "id": row.id,
        "direction": row.direction,
        "kind": "message",
        "body": row.body,
        "created_at": row.created_at.isoformat(),
    }


@router.get("/status")
async def baba_status(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    phone = db.query(User.phone).filter(User.id == user_id).scalar()
    has_history = db.query(BabaMessage.id).filter(BabaMessage.user_id == user_id).first() is not None
    return {
        "mode": "messaging",
        "monitors": [],
        "phone": phone,
        "has_minou_history": has_history,
        "providers": baba_service.configured_providers(),
    }


@router.get("/thread")
async def baba_thread(
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    limit = max(1, min(limit, 200))
    rows = (
        db.query(BabaMessage)
        .filter(BabaMessage.user_id == current_user["user_id"])
        .order_by(BabaMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    return {"mode": "messaging", "items": [_item(r) for r in reversed(rows)]}


@router.post("/messages")
async def baba_send(
    payload: BabaSend,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Message vide")
    since = datetime.utcnow() - timedelta(hours=1)
    recent = (
        db.query(BabaMessage.id)
        .filter(
            BabaMessage.user_id == user_id,
            BabaMessage.direction == "in",
            BabaMessage.created_at >= since,
        )
        .count()
    )
    if recent >= HOURLY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Tu as beaucoup écrit à Baba cette heure-ci. Réessaie un peu plus tard.",
        )

    history_rows = (
        db.query(BabaMessage)
        .filter(BabaMessage.user_id == user_id)
        .order_by(BabaMessage.created_at.desc())
        .limit(10)
        .all()
    )
    history = [(r.direction, r.body) for r in reversed(history_rows)]

    mine = BabaMessage(user_id=user_id, direction="in", body=text)
    db.add(mine)
    db.commit()
    db.refresh(mine)

    answer, provider = await baba_service.reply(history, text)
    theirs = BabaMessage(user_id=user_id, direction="out", body=answer, provider=provider)
    db.add(theirs)
    db.commit()
    db.refresh(theirs)
    return {"items": [_item(mine), _item(theirs)], "provider": provider}
