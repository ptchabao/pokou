"""Reçus de nouvel essai (voir app/models/e2ee_retry.py).

1. Le destinataire qui n'ouvre pas un message : POST /e2ee/retries.
2. L'expéditeur (prévenu en temps réel, ou à sa prochaine synchronisation)
   rescelle le clair POUR LUI : POST /e2ee/retries/{id}/fulfill.
3. Le destinataire l'ouvre, puis l'acquitte : POST /e2ee/retries/{id}/ack.
"""
from typing import Any, Dict, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.v1.messaging.ws import manager
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import DirectMessage, E2EERetry, GroupMember, GroupMessage

router = APIRouter(prefix="/e2ee/retries", tags=["E2EE"])

#: Un appareil qui échoue en boucle ne doit pas inonder l'expéditeur.
MAX_PENDING_PER_REQUESTER = 300


class RetryRequest(BaseModel):
    kind: Literal["direct", "group"]
    message_id: str = Field(..., max_length=64)


class RetryFulfill(BaseModel):
    encryption: Optional[str] = Field(None, max_length=16)
    ciphertext: Optional[str] = Field(None, max_length=1_000_000)
    envelope: Optional[Dict[str, Any]] = None
    #: L'expéditeur n'a plus le clair (réinstallation de son côté).
    unavailable: bool = False


def _item(r: E2EERetry) -> dict:
    return {
        "id": r.id,
        "kind": r.kind,
        "message_id": r.message_id,
        "group_id": r.group_id,
        "requester_id": r.requester_id,
        "sender_id": r.sender_id,
        "status": r.status,
        "encryption": r.encryption,
        "ciphertext": r.ciphertext,
        "envelope": r.envelope,
    }


@router.post("")
async def request_retry(
    payload: RetryRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    me = current_user["user_id"]
    group_id = None
    if payload.kind == "direct":
        msg = db.query(DirectMessage).filter(DirectMessage.id == payload.message_id).first()
        if msg is None or msg.recipient_id != me:
            raise HTTPException(status_code=404, detail="Message introuvable")
        sender_id = msg.sender_id
    else:
        msg = db.query(GroupMessage).filter(GroupMessage.id == payload.message_id).first()
        if msg is None:
            raise HTTPException(status_code=404, detail="Message introuvable")
        member = db.query(GroupMember.id).filter(
            GroupMember.group_id == msg.group_id, GroupMember.user_id == me
        ).first()
        if member is None or msg.sender_id == me:
            raise HTTPException(status_code=404, detail="Message introuvable")
        sender_id = msg.sender_id
        group_id = msg.group_id

    existing = db.query(E2EERetry).filter(
        E2EERetry.kind == payload.kind,
        E2EERetry.message_id == payload.message_id,
        E2EERetry.requester_id == me,
    ).first()
    if existing is not None:
        return _item(existing)
    pending = db.query(E2EERetry).filter(
        E2EERetry.requester_id == me, E2EERetry.status == "PENDING"
    ).count()
    if pending >= MAX_PENDING_PER_REQUESTER:
        raise HTTPException(status_code=429, detail="Trop de demandes en attente")

    row = E2EERetry(
        kind=payload.kind,
        message_id=payload.message_id,
        group_id=group_id,
        requester_id=me,
        sender_id=sender_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    await manager.send_to_user(sender_id, {"type": "e2ee:retry_request", "retry_id": row.id})
    return _item(row)


@router.get("")
async def my_retries(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    """Ce que j'ai à resceller (expéditeur), et ce que j'ai à ouvrir
    (destinataire)."""
    me = current_user["user_id"]
    rows = (
        db.query(E2EERetry)
        .filter(
            or_(
                (E2EERetry.sender_id == me) & (E2EERetry.status == "PENDING"),
                (E2EERetry.requester_id == me) & (E2EERetry.status.in_(("DELIVERED", "UNAVAILABLE"))),
            )
        )
        .order_by(E2EERetry.created_at)
        .limit(500)
        .all()
    )
    to_open = []
    for r in rows:
        if r.requester_id != me or r.status == "PENDING":
            continue
        item = _item(r)
        # Le message lui-même (chiffré) : le destinataire ne l'a pas
        # forcément en cache, un échec de déchiffrement n'y étant pas rangé.
        item["message"] = _message_for(db, r, me)
        to_open.append(item)
    return {
        "to_fulfill": [_item(r) for r in rows if r.sender_id == me and r.status == "PENDING"],
        "to_open": to_open,
    }


def _message_for(db: Session, r: E2EERetry, viewer_id: int):
    from app.api.v1.messaging.groups import _serialize_message
    from app.api.v1.messaging.messages import _serialize

    if r.kind == "direct":
        m = db.query(DirectMessage).filter(DirectMessage.id == r.message_id).first()
        return _serialize(m, viewer_id) if m else None
    m = db.query(GroupMessage).filter(GroupMessage.id == r.message_id).first()
    return _serialize_message(m, viewer_id) if m else None


@router.post("/{retry_id}/fulfill")
async def fulfill_retry(
    retry_id: str,
    payload: RetryFulfill,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    row = db.query(E2EERetry).filter(E2EERetry.id == retry_id).first()
    if row is None or row.sender_id != current_user["user_id"]:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    if payload.unavailable:
        row.status = "UNAVAILABLE"
    else:
        if payload.encryption != "v1" or not payload.ciphertext or payload.envelope is None:
            raise HTTPException(status_code=400, detail="Re-livraison chiffrée requise")
        row.encryption = payload.encryption
        row.ciphertext = payload.ciphertext
        row.envelope = payload.envelope
        row.status = "DELIVERED"
    db.commit()
    await manager.send_to_user(row.requester_id, {"type": "e2ee:retry_delivered", "retry_id": row.id})
    return {"status": row.status}


@router.post("/{retry_id}/ack")
async def ack_retry(
    retry_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    row = db.query(E2EERetry).filter(E2EERetry.id == retry_id).first()
    if row is None or row.requester_id != current_user["user_id"]:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    row.status = "DONE"
    # Le chiffré a servi : on ne le garde pas.
    row.ciphertext = None
    row.envelope = None
    db.commit()
    return {"status": row.status}
