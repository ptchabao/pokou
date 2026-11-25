"""Ce qui se passe dans une collecte Kory, raconté dans le fil de son groupe.

Une cagnotte, une cotisation ou une tontine ouverte depuis un groupe vivait
à côté de lui : le bandeau « Cagnotte en cours » disait qu'elle existait,
rien ne disait ce qui s'y passait. Chaque membre devait ouvrir Kory pour
apprendre qu'Ama avait versé, que le tour 3 commençait ou que la collecte
était close.

── Un message du groupe, comme un appel terminé ─────────────────────────

Même parti pris que services/calls/call_thread_service.py : un VRAI message
du groupe (pagination, cache hors ligne, ordre du fil), qui porte dans
`payload` un instantané de l'évènement — `{"kind": "kory_activity", …}` —
et que l'application dessine en carte discrète au centre du fil.

── Ce que le serveur peut dire, et rien de plus ─────────────────────────

Les messages d'un groupe sont chiffrés de bout en bout : le serveur n'en lit
aucun. Celui-ci n'est pas chiffré, parce que c'est le SERVEUR qui l'écrit,
et il n'y met que ce qu'il sait déjà et que chaque membre du groupe voit
déjà dans Kory : le titre de la collecte, des noms, un numéro de tour, et
des montants CONFIRMÉS. Jamais une référence de transaction, jamais un
numéro de téléphone. Quand l'organisateur a masqué les montants de chacun
(`amounts_visible`), la carte dit QUI a versé, pas COMBIEN — le total, lui,
reste visible, comme dans Kory.

Le message part après le COMMIT, comme `kory:updated` (voir
services/events/live_updates.py) : on n'annonce pas ce qui peut encore être
annulé.
"""
import asyncio
import logging
from typing import Optional

from sqlalchemy import event as sa_event
from sqlalchemy.orm import Session

from app.models import GroupMember, GroupMessage, KoryPot, MessageType, User

logger = logging.getLogger(__name__)

#: La marque des messages écrits par Kory. Le client la reconnaît ; une
#: application plus ancienne n'y voit qu'un message vide, sans contenu.
KIND = "kory_activity"

EVENTS = {"created", "contribution", "round", "started", "closed", "dissolved", "reminder"}

_KEY = "pokou_kory_activity"


def _display_name(db: Session, user_id: Optional[int]) -> Optional[str]:
    if user_id is None:
        return None
    user = db.get(User, user_id)
    return (user.full_name or None) if user else None


def is_kory_activity(message: GroupMessage) -> bool:
    """Un message de groupe écrit par Kory — jamais par un client, qui ne
    peut envoyer que du chiffré (voir groups.py::send_group_message)."""
    payload = message.payload
    return message.encryption is None and isinstance(payload, dict) and payload.get("kind") == KIND


def post(
    db: Session,
    pot: KoryPot,
    actor_id: int,
    event: str,
    **fields,
) -> Optional[GroupMessage]:
    """Dépose l'évènement dans le fil du groupe de la collecte.

    Sans groupe (collecte partagée par code), rien : il n'y a pas de fil.
    À appeler AVANT `db.commit()`, dans la transaction de l'évènement
    lui-même — l'un ne doit pas exister sans l'autre.
    """
    if event not in EVENTS or pot.group_id is None:
        return None
    if db.query(GroupMember.id).filter(GroupMember.group_id == pot.group_id).first() is None:
        return None  # groupe supprimé ou vide
    payload = {
        "kind": KIND,
        "event": event,
        "pot_id": pot.id,
        "pot_kind": pot.kind,
        "title": pot.title,
        "actor_id": actor_id,
        "actor_name": _display_name(db, actor_id),
        "amounts_visible": bool(pot.amounts_visible) if pot.amounts_visible is not None else True,
    }
    for key, value in fields.items():
        if value is not None:
            payload[key] = value
    if not payload["amounts_visible"]:
        # Le montant de CHACUN reste entre l'auteur et le collecteur.
        payload.pop("amount", None)
    message = GroupMessage(
        group_id=pot.group_id,
        sender_id=actor_id,
        message_type=MessageType.TEXT,
        # L'aperçu de la liste des discussions (conversations.py) lit ce
        # texte : la marque et le titre, lisibles dans toutes les langues.
        content=f"Kory · {pot.title}"[:200],
        payload=payload,
    )
    db.add(message)
    db.flush()
    pending = db.info.setdefault(_KEY, [])
    if not db.info.get(f"{_KEY}:listening"):
        sa_event.listen(db, "after_commit", _after_commit)
        sa_event.listen(db, "after_rollback", _after_rollback)
        db.info[f"{_KEY}:listening"] = True
    pending.append(message.id)
    return message


def _after_rollback(session: Session) -> None:
    session.info.pop(_KEY, None)


def _after_commit(session: Session) -> None:
    ids = session.info.pop(_KEY, None)
    if not ids:
        return
    coro = _announce(session.get_bind(), list(ids))
    try:
        asyncio.get_running_loop().create_task(coro)
        return
    except RuntimeError:
        pass
    # Les routes `def` tournent dans un pool de threads : la boucle du
    # serveur est celle que retient live_updates.
    from app.services.events import live_updates

    loop = live_updates._main_loop
    if loop is not None and loop.is_running():
        asyncio.run_coroutine_threadsafe(coro, loop)
    else:
        coro.close()  # hors serveur (tâche planifiée) : le fil se relira


async def _announce(bind, message_ids: list) -> None:
    """`group:message:new` à chaque membre connecté. Pas de notification
    push : Kory prévient déjà les personnes concernées par la sienne."""
    from app.api.v1.messaging.groups import _serialize_message
    from app.api.v1.messaging.ws import manager

    try:
        with Session(bind=bind) as db:
            sends = []
            for message_id in message_ids:
                message = db.get(GroupMessage, message_id)
                if message is None:
                    continue
                members = [
                    uid
                    for (uid,) in db.query(GroupMember.user_id).filter(GroupMember.group_id == message.group_id)
                ]
                sends += [
                    (uid, {"type": "group:message:new", "message": _serialize_message(message, uid)})
                    for uid in members
                ]
        for user_id, payload in sends:
            try:
                await manager.send_to_user(user_id, payload)
            except Exception:  # pragma: no cover - transport best-effort
                logger.warning("activité Kory non remise à %s", user_id, exc_info=True)
    except Exception:  # pragma: no cover - ne jamais casser une route
        logger.warning("activité Kory impossible à diffuser", exc_info=True)
