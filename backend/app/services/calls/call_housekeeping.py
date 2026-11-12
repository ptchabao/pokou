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

Il clôt aussi les appels de groupe que tout le monde a quittés sans que le
serveur l'ait su (voir close_if_deserted) : LiveKit dit qui est vraiment
dans le salon.

Il purge aussi les jetons d'action périmés : la fonction existait, personne
ne l'appelait, et la table gagnait deux lignes par appel entrant.
"""
import logging
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models import CallLog
from app.services.auth import action_token_service
from app.services.calls import call_thread_service, livekit_service

logger = logging.getLogger(__name__)

RINGING_TTL = timedelta(seconds=90)
ONGOING_TTL = timedelta(hours=4)

#: Délai après la dernière arrivée pendant lequel on ne conclut rien d'un
#: salon vide : celui qui vient de recevoir son jeton n'est pas encore
#: connecté à LiveKit.
DESERTED_GRACE = timedelta(seconds=45)


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


def _last_arrival(call: CallLog) -> datetime:
    moments = [call.created_at] + [p.responded_at for p in call.participants if p.responded_at]
    return max(moments)


async def close_if_deserted(db: Session, call: CallLog, now: datetime | None = None) -> bool:
    """Clôt un appel de groupe « en cours » dont le salon est vide.

    Dans un appel de groupe, le serveur compte les présents d'après les
    signaux : entrée à la remise du jeton, sortie au signal `end`. Un retour
    qui échoue APRÈS la remise du jeton (clé d'appel impossible à rouvrir,
    réseau, application tuée) réinscrit donc la personne comme présente sans
    qu'elle le soit, et aucun `end` ne suit. L'appel restait alors « en
    cours » jusqu'à quatre heures : le bandeau « Rejoindre » menait à un
    salon vide, et tout nouvel appel du groupe y était ramené — plus
    personne ne pouvait s'appeler (production, 11 novembre 2026).

    LiveKit sait qui est vraiment connecté. Salon vide, passé le délai de
    grâce : l'appel est fini. Sans réponse de LiveKit, on ne touche à rien.
    """
    if call.call_type != "group" or call.status != "ongoing" or call.ended_at is not None:
        return False
    now = now or datetime.utcnow()
    if now - _last_arrival(call) < DESERTED_GRACE:
        return False
    if await livekit_service.participant_count(call.room) != 0:
        return False
    call.status = "ended"
    call.ended_at = now
    for participant in call.participants:
        if participant.status == "accepted" and participant.left_at is None:
            participant.left_at = now
    call_thread_service.journaliser(db, call)
    db.commit()
    logger.info("[Appels] appel de groupe %s clos : salon vide", call.room)
    return True


async def close_deserted_group_calls(db: Session) -> int:
    calls = (
        db.query(CallLog)
        .filter(
            CallLog.ended_at.is_(None),
            CallLog.status == "ongoing",
            CallLog.call_type == "group",
        )
        .limit(50)
        .all()
    )
    closed = 0
    for call in calls:
        if await close_if_deserted(db, call):
            closed += 1
    return closed


def run(db: Session) -> dict:
    closed = close_stale_calls(db)
    purged = action_token_service.purge_expired(db)
    return {"closed_calls": closed, "purged_action_tokens": purged}
