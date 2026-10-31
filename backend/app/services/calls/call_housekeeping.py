"""Le serveur clôt les appels que plus aucun client ne fera avancer.

L'état d'un appel n'avance qu'avec les signaux des clients (pas de webhook
LiveKit). Un client qui plante, perd le réseau ou est tué par le système
laissait donc une ligne « en sonnerie » ou « en cours » pour toujours dans le
journal, sans bulle dans la conversation.

Ce balayage les clôt, avec les mêmes bornes que celles qui décident déjà si
un appel est joignable (voir routes/calls.py::_is_over) :

- en sonnerie depuis plus de RINGING_TTL → « manqué » ;
- en cours depuis plus de ONGOING_TTL → « terminé ».

Idempotent : un appel clos n'est plus sélectionné, et la bulle de la
conversation est protégée par `thread_message_id` (call_thread_service).

Il purge aussi les jetons d'action périmés : la fonction existait, personne
ne l'appelait, et la table gagnait deux lignes par appel entrant.
"""
import logging
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models import CallLog
from app.services.auth import action_token_service
from app.services.calls import call_thread_service

logger = logging.getLogger(__name__)

RINGING_TTL = timedelta(seconds=90)
ONGOING_TTL = timedelta(hours=4)


def close_stale_calls(db: Session, now: datetime | None = None) -> int:
    now = now or datetime.utcnow()
    stale = (
        db.query(CallLog)
        .filter(
            CallLog.ended_at.is_(None),
            (
                (CallLog.status == "ringing") & (CallLog.created_at < now - RINGING_TTL)
            )
            | ((CallLog.status == "ongoing") & (CallLog.created_at < now - ONGOING_TTL)),
        )
        .limit(500)
        .all()
    )
    for call in stale:
        if call.status == "ringing":
            call.status = "missed"
            for participant in call.participants:
                if participant.status == "invited":
                    participant.status = "missed"
                    participant.responded_at = now
        else:
            call.status = "ended"
        call.ended_at = now
        call_thread_service.journaliser(db, call)
    if stale:
        db.commit()
        logger.info("[Appels] %d appel(s) abandonné(s) clos", len(stale))
    return len(stale)


def run(db: Session) -> dict:
    closed = close_stale_calls(db)
    purged = action_token_service.purge_expired(db)
    return {"closed_calls": closed, "purged_action_tokens": purged}
