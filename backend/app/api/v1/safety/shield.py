"""Pokou — Mode Bouclier (Shield Mode). Voir app/services/shield_service.py
pour la logique ; aucune donnée n'est journalisée ou persistée ici."""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.services.privacy import shield_service
from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/shield", tags=["Pokou shield mode"])


class ContextRequest(BaseModel):
    # Déjà anonymisés côté client — voir local_redaction.dart.
    recent_messages: List[str] = Field(default_factory=list, max_length=5)


class EvaluateRequest(BaseModel):
    context_score: int = Field(..., ge=1, le=10)
    event_type: str  # call | message
    sender_tag: Optional[str] = None
    hashed_text: Optional[str] = None
    sender_known: bool = True
    group_size: Optional[int] = None
    sender_message_count_last_minute: Optional[int] = None


@router.post("/context")
async def evaluate_context(
    payload: ContextRequest,
    current_user: dict = Depends(get_current_user),
):
    # shield_service already degrades to focus_score=1 (shield inactive) when
    # every LLM provider fails — this is a second safety net at the API
    # boundary so any *other* unexpected error here still treats the
    # conversation as normal (not shielded) rather than surfacing a 500 that
    # the client would have to guess how to handle.
    try:
        focus_score = await shield_service.evaluate_context(payload.recent_messages)
    except Exception as exc:
        logger.warning("[SHIELD] /context erreur inattendue, traité comme message normal: %s", exc)
        focus_score = 1
    return {"focus_score": focus_score}


@router.post("/evaluate")
async def evaluate_event(
    payload: EvaluateRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        decision = shield_service.evaluate_event(
            context_score=payload.context_score,
            event_type=payload.event_type,
            sender_tag=payload.sender_tag,
            hashed_text=payload.hashed_text,
            sender_known=payload.sender_known,
            group_size=payload.group_size,
            sender_message_count_last_minute=payload.sender_message_count_last_minute,
        )
    except Exception as exc:
        logger.warning("[SHIELD] /evaluate erreur inattendue, traité comme message normal: %s", exc)
        decision = "ALLOW"
    return {"decision": decision}
