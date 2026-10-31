"""Streak Lock — la chaîne d'une conversation, et son rachat.

La chaîne avance toute seule depuis l'envoi d'un message (voir
`record_message`, appelé par messages.py). Ces routes ne font que la montrer
et permettre de la racheter.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import ConversationStreak, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.services.modules import streak_service
from app.core.security import get_current_user

router = APIRouter(prefix="/streaks", tags=["Pokou Streak Lock"])

MODULE_SLUG = "streak_lock"


def _streak_row(db: Session, a: int, b: int) -> ConversationStreak | None:
    low, high = streak_service.ordered_pair(a, b)
    return (
        db.query(ConversationStreak)
        .filter(
            ConversationStreak.low_user_id == low,
            ConversationStreak.high_user_id == high,
        )
        .first()
    )


def record_message(db: Session, sender_id: int, recipient_id: int) -> None:
    """Enregistre qu'un message vient de partir, et fait avancer la chaîne.

    Appelé depuis l'envoi de message. **Silencieux en cas d'échec** : une
    chaîne est un ornement, et la faire échouer empêcherait l'envoi d'un
    message pour une raison sans rapport avec lui. Un compteur perdu est
    désagréable ; un message perdu est une panne.

    Ne vérifie PAS l'activation du module, volontairement : la chaîne se
    construit en arrière-plan pour que quelqu'un qui active Streak Lock
    demain retrouve l'historique de ses conversations plutôt qu'un zéro.
    """
    try:
        low, high = streak_service.ordered_pair(sender_id, recipient_id)
        today = datetime.utcnow().date()
        row = _streak_row(db, sender_id, recipient_id)
        if row is None:
            row = ConversationStreak(
                low_user_id=low, high_user_id=high,
                current_days=0, best_days=0, broken_days=0,
            )
            db.add(row)

        sender_is_low = sender_id == low
        if sender_is_low:
            row.low_last_day = today
        else:
            row.high_last_day = today

        other_last = row.high_last_day if sender_is_low else row.low_last_day
        outcome = streak_service.apply_message(
            today=today,
            sender_last_day=today,
            other_last_day=other_last,
            current_days=row.current_days,
            last_exchange_day=row.last_exchange_day,
        )
        if outcome.broke and row.current_days > 0:
            row.broken_at = datetime.utcnow()
            row.broken_days = row.current_days
        if outcome.current_days > 0:
            # Une chaîne qui repart efface la fenêtre de rachat : il n'y a
            # plus rien à racheter une fois qu'on a recommencé.
            row.broken_at = None
            row.broken_days = 0
        row.current_days = outcome.current_days
        row.last_exchange_day = outcome.last_exchange_day
        row.best_days = max(row.best_days, outcome.current_days)
        db.commit()
    except Exception:  # noqa: BLE001 — voir docstring
        db.rollback()


def _serialize(row: ConversationStreak | None, *, peer_id: int, now: datetime) -> dict:
    if row is None:
        return {
            "peer_id": peer_id, "current_days": 0, "best_days": 0,
            "is_broken": False, "can_restore": False, "seconds_left": 0,
            "restore_amount": streak_service.RESTORE_AMOUNT,
        }
    restorable = streak_service.can_restore(row.broken_at, now)
    return {
        "peer_id": peer_id,
        "current_days": row.current_days,
        "best_days": row.best_days,
        "is_broken": row.broken_at is not None,
        "broken_days": row.broken_days,
        "can_restore": restorable,
        "seconds_left": streak_service.seconds_left(row.broken_at, now),
        "restore_amount": streak_service.RESTORE_AMOUNT,
    }


@router.get("")
async def my_streaks(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Mes chaînes en cours, la plus longue d'abord — et celles qui viennent
    de se rompre tout en haut : ce sont les seules où une action est encore
    possible."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()

    rows = (
        db.query(ConversationStreak)
        .filter(
            or_(
                ConversationStreak.low_user_id == user_id,
                ConversationStreak.high_user_id == user_id,
            )
        )
        .all()
    )
    peers = {
        u.id: u
        for u in db.query(User).filter(
            User.id.in_(
                {r.low_user_id for r in rows} | {r.high_user_id for r in rows}
            )
        )
    }

    items = []
    for row in rows:
        peer_id = row.high_user_id if row.low_user_id == user_id else row.low_user_id
        peer = peers.get(peer_id)
        payload = _serialize(row, peer_id=peer_id, now=now)
        payload["display_name"] = (
            (peer.full_name or peer.phone or "Contact") if peer else "Contact"
        )
        items.append(payload)

    items.sort(key=lambda s: (not s["can_restore"], -s["current_days"]))
    return {"items": items}


@router.get("/{peer_id}")
async def streak_with(
    peer_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    return _serialize(_streak_row(db, user_id, peer_id), peer_id=peer_id, now=datetime.utcnow())


@router.post("/{peer_id}/restore")
async def restore_streak(
    peer_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Rachète une chaîne rompue, dans la fenêtre de grâce.

    Refuse hors fenêtre plutôt que d'accepter et de ne rien rendre : prendre
    l'argent pour une chaîne qu'on ne peut plus restaurer est la seule chose
    qui rendrait ce module indéfendable.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)

    row = _streak_row(db, user_id, peer_id)
    if row is None or not streak_service.can_restore(row.broken_at, datetime.utcnow()):
        raise HTTPException(
            status_code=409,
            detail="Cette chaîne ne peut plus être sauvée — le délai est passé",
        )

    payment = open_payment(
        db, user_id,
        kind="STREAK_RESTORE",
        amount=streak_service.RESTORE_AMOUNT,
        description=f"Streak Lock — sauver une chaîne de {row.broken_days} jours",
        metadata={"module": MODULE_SLUG, "peer_id": peer_id, "days": row.broken_days},
    )
    db.commit()
    return payment_json(payment)


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """Restaure la chaîne, une fois l'argent confirmé.

    La fenêtre de grâce est revérifiée ICI : entre l'ouverture du paiement et
    sa confirmation, il se passe le temps d'un parcours Mobile Money. Sans
    cette seconde vérification, un paiement lent restaurerait une chaîne dont
    le délai est expiré — et surtout, on aurait encaissé pour un délai
    dépassé.
    """
    metadata = payment.metadata_json or {}
    peer_id = metadata.get("peer_id")
    if not peer_id:
        return None

    row = _streak_row(db, payment.user_id, int(peer_id))
    if row is None:
        return None

    now = datetime.utcnow()
    # Tolérance : le temps du parcours de paiement s'ajoute à la fenêtre.
    # Sans elle, personne ne pourrait jamais racheter — dix minutes ne
    # suffisent pas à ouvrir une page Mobile Money et à la valider.
    if row.broken_at is None or (now - row.broken_at) > streak_service.GRACE_PERIOD + timedelta(minutes=20):
        return {"restored": False, "reason": "délai dépassé"}

    row.current_days = row.broken_days
    row.best_days = max(row.best_days, row.broken_days)
    row.last_exchange_day = now.date()
    row.broken_at = None
    row.broken_days = 0
    return {"restored": True, "current_days": row.current_days}
