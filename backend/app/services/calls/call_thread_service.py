"""Déposer un appel terminé dans le fil de sa conversation.

Un appel n'existait que dans le journal d'appels, écran séparé. L'histoire
d'une relation se lisait donc à deux endroits : les messages d'un côté, les
appels de l'autre, sans qu'aucun des deux ne rappelle l'existence du second.
Rien, dans une conversation, ne disait qu'on s'était parlé mardi pendant
douze minutes.

── Un message, pas une vue fusionnée ────────────────────────────────────

L'autre solution consistait à mélanger `call_logs` et les messages à la
lecture. Elle évitait une colonne, et coûtait trois choses :

- la pagination. `GET /messages/{pair}?before=…` devrait fusionner deux
  sources triées, avec deux curseurs, pour une seule liste ;
- le hors-ligne. Le cache local de l'appareil ne contient que des messages ;
  un appel n'y serait jamais, et la conversation relue sans réseau perdrait
  la moitié de son histoire ;
- la simplicité des clients. Chaque écran devrait savoir recombiner.

Un vrai message règle les trois d'un coup, et suit un usage déjà établi
ici : la fiche produit partagée porte elle aussi un INSTANTANÉ dans
`payload` plutôt qu'un simple identifiant.

── L'idempotence est le vrai sujet ──────────────────────────────────────

Un appel atteint son état final par plusieurs chemins : tous les invités
refusent, l'appelant raccroche avant qu'on décroche, le dernier participant
quitte un appel de groupe. Chacun passe par `db.commit()`. Sans marque, le
même appel déposerait deux bulles — et le bogue ne se verrait qu'en
production, sur les appels de groupe, c'est-à-dire tard.

D'où `CallLog.thread_message_id`, posé dans la même transaction que le
message.

── Ce que ce module N'EST PAS ───────────────────────────────────────────

Il ne chiffre rien, et ne prétend pas le contraire. Un événement d'appel est
une métadonnée produite par le SERVEUR, qui n'a aucune clé : elle ne peut
pas être chiffrée de bout en bout, exactement comme un sondage ou une
position partagée. Le contenu des conversations reste chiffré ; savoir qu'un
appel a eu lieu ne l'a jamais été — le journal d'appels l'expose depuis
toujours.
"""
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models import CallLog, CallParticipant, DirectMessage, GroupMessage, MessageType

logger = logging.getLogger(__name__)

#: Les issues qui méritent une trace dans la conversation.
#:
#: `ringing` et `ongoing` n'en sont pas : un appel qui sonne encore n'a pas
#: d'histoire à raconter, et le bandeau « Appel en cours · Rejoindre » s'en
#: charge déjà, en direct.
ETATS_TERMINAUX = {"ended", "missed", "declined"}


def journaliser(db: Session, call_log: CallLog) -> Optional[str]:
    """Dépose l'événement si l'appel vient de se terminer.

    Renvoie l'identifiant du message créé, ou `None` s'il n'y avait rien à
    faire — appel encore en cours, ou déjà journalisé.

    À appeler AVANT `db.commit()` : le message et la marque d'idempotence
    doivent être écrits dans la même transaction que l'état final de
    l'appel, sinon une panne entre les deux laisse un appel terminé sans
    trace, ou une trace sans marque qui se dupliquera au prochain passage.
    """
    if call_log.status not in ETATS_TERMINAUX:
        return None
    if call_log.thread_message_id is not None:
        return None

    charge = _instantane(db, call_log)

    if call_log.call_type == "group":
        if call_log.group_id is None:
            # Un appel « de groupe » sans groupe ne peut se ranger nulle
            # part. Ça ne devrait pas arriver ; si ça arrive, mieux vaut pas
            # de bulle qu'une exception au raccrochage.
            logger.warning("[AppelFil] appel de groupe %s sans group_id", call_log.id)
            return None
        message = GroupMessage(
            group_id=call_log.group_id,
            sender_id=call_log.caller_id,
            message_type=MessageType.CALL,
            payload=charge,
            created_at=call_log.ended_at or datetime.utcnow(),
        )
    else:
        destinataire = _destinataire_1a1(db, call_log)
        if destinataire is None:
            logger.warning("[AppelFil] appel %s sans destinataire", call_log.id)
            return None
        message = DirectMessage(
            sender_id=call_log.caller_id,
            recipient_id=destinataire,
            message_type=MessageType.CALL,
            payload=charge,
            # L'horodatage est celui de la FIN, pas de la création : la bulle
            # doit se ranger après les messages échangés pendant l'appel, pas
            # avant.
            created_at=call_log.ended_at or datetime.utcnow(),
        )

    db.add(message)
    db.flush()  # `autoflush=False` en tests : force l'attribution de l'id
    call_log.thread_message_id = message.id
    return message.id


def _destinataire_1a1(db: Session, call_log: CallLog) -> Optional[int]:
    participant = (
        db.query(CallParticipant)
        .filter(
            CallParticipant.call_log_id == call_log.id,
            CallParticipant.user_id != call_log.caller_id,
        )
        .first()
    )
    return participant.user_id if participant else None


def _instantane(db: Session, call_log: CallLog) -> dict:
    """Ce que la bulle affichera, figé au moment où l'appel se termine.

    La durée se compte depuis le PREMIER décroché, pas depuis la création de
    l'appel : les quarante secondes de sonnerie ne sont pas du temps passé à
    se parler, et les annoncer gonflerait chaque appel d'autant.
    """
    participants = (
        db.query(CallParticipant).filter(CallParticipant.call_log_id == call_log.id).all()
    )
    premier_decroche = min(
        (p.responded_at for p in participants if p.status == "accepted" and p.responded_at),
        default=None,
    )
    duree = None
    if premier_decroche and call_log.ended_at:
        duree = max(0, int((call_log.ended_at - premier_decroche).total_seconds()))

    # L'appelant compte parmi les participants d'un appel de groupe, alors
    # qu'il n'a pas de ligne dans `call_participants` tant qu'il n'a pas
    # quitté : on l'ajoute explicitement.
    ayant_participe = {p.user_id for p in participants if p.status == "accepted"}
    if call_log.status == "ended":
        ayant_participe.add(call_log.caller_id)

    return {
        "call_id": call_log.id,
        "call_type": call_log.call_type,
        "is_video": bool(call_log.is_video),
        "status": call_log.status,
        "duration_seconds": duree,
        "participant_count": len(ayant_participe),
        # L'appelant est déjà `sender_id` du message ; on le répète ici pour
        # que la charge utile se suffise à elle-même — c'est elle, et non la
        # ligne de `call_logs`, qui devra rester lisible dans dix ans.
        "caller_id": call_log.caller_id,
    }
