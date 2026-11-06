"""Temps réel des modules Kory et Honam, sans toucher à chaque route.

Kory (cagnottes) et Honam (commandes de pharmacie) changent d'état par une
trentaine de routes — contribuer, confirmer, devis, paiement, coursier,
livraison… Aucune ne prévenait personne : l'écran de l'autre partie restait
figé jusqu'à ce qu'on le rouvre.

Plutôt que d'ajouter un envoi dans chaque route (et d'en oublier une), on
écoute la SESSION : à chaque flush, on note les cagnottes et commandes
touchées ; après le COMMIT — jamais avant, sinon on annoncerait un état qui
peut encore être annulé — on prévient les personnes concernées :

- une cagnotte : son collecteur et ses membres → `kory:updated` ;
- une commande : le patient, le coursier et le personnel de l'officine →
  `honam:order_updated`.

L'événement ne porte que l'identifiant : chacun relit par l'API, qui
applique ses propres droits.
"""
import asyncio
import logging
from typing import Set

from sqlalchemy import event
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

_KEY = "pokou_live_updates"


def _bucket(session: Session) -> dict:
    return session.info.setdefault(_KEY, {"kory": set(), "honam": set()})


def _collect(session: Session, flush_context=None, instances=None) -> None:
    from app.models import HonamOrder, HonamOrderEvent, KoryEntry, KoryMember, KoryPot, KoryRound

    bucket = _bucket(session)
    for obj in list(session.new) + list(session.dirty):
        if isinstance(obj, KoryPot) and obj.id is not None:
            bucket["kory"].add(obj.id)
        elif isinstance(obj, (KoryEntry, KoryMember, KoryRound)) and getattr(obj, "pot_id", None):
            bucket["kory"].add(obj.pot_id)
        elif isinstance(obj, HonamOrder) and obj.id is not None:
            bucket["honam"].add(obj.id)
        elif isinstance(obj, HonamOrderEvent) and obj.order_id:
            bucket["honam"].add(obj.order_id)


def _after_flush(session: Session, flush_context) -> None:
    # Les objets NOUVEAUX ont maintenant un identifiant.
    from app.models import HonamOrder, KoryPot

    bucket = _bucket(session)
    for obj in session.identity_map.values():
        if isinstance(obj, KoryPot) and obj in session.new:
            bucket["kory"].add(obj.id)
        elif isinstance(obj, HonamOrder) and obj in session.new:
            bucket["honam"].add(obj.id)


_main_loop = None


def bind_loop() -> None:
    """Retient la boucle du serveur. Appelé par le middleware HTTP : les
    routes `def` tournent dans un pool de threads, sans boucle à elles."""
    global _main_loop
    try:
        _main_loop = asyncio.get_running_loop()
    except RuntimeError:
        pass


def _after_commit(session: Session) -> None:
    bucket = session.info.pop(_KEY, None)
    if not bucket or not (bucket["kory"] or bucket["honam"]):
        return
    coro = _announce(session.get_bind(), set(bucket["kory"]), set(bucket["honam"]))
    try:
        asyncio.get_running_loop().create_task(coro)
        return
    except RuntimeError:
        pass
    loop = _main_loop
    if loop is not None and loop.is_running():
        asyncio.run_coroutine_threadsafe(coro, loop)
    else:
        coro.close()  # hors serveur (tâche planifiée) : rien à pousser


def _after_rollback(session: Session) -> None:
    session.info.pop(_KEY, None)


async def _announce(bind, pot_ids: Set[int], order_ids: Set[int]) -> None:
    from app.api.v1.messaging.ws import manager
    from app.models import HonamOrder, KoryMember, KoryPot, PharmacyStaff

    try:
        with Session(bind=bind) as db:
            sends = []
            for pot_id in pot_ids:
                pot = db.get(KoryPot, pot_id)
                if pot is None:
                    continue
                users = {pot.collector_id} | {
                    uid for (uid,) in db.query(KoryMember.user_id).filter(KoryMember.pot_id == pot_id)
                }
                sends += [(u, {"type": "kory:updated", "pot_id": pot_id}) for u in users if u]
            for order_id in order_ids:
                order = db.get(HonamOrder, order_id)
                if order is None:
                    continue
                users = {order.patient_id, order.courier_id} | {
                    uid
                    for (uid,) in db.query(PharmacyStaff.user_id).filter(
                        PharmacyStaff.pharmacy_id == order.pharmacy_id
                    )
                }
                sends += [
                    (u, {"type": "honam:order_updated", "order_id": order_id, "status": order.status})
                    for u in users
                    if u
                ]
        for user_id, payload in sends:
            try:
                await manager.send_to_user(user_id, payload)
            except Exception:  # pragma: no cover - transport best-effort
                logger.warning("live update non remis à %s", user_id, exc_info=True)
    except Exception:  # pragma: no cover - ne jamais casser une route
        logger.warning("live updates Kory/Honam impossibles", exc_info=True)


_installed = False


def install() -> None:
    global _installed
    if _installed:
        return
    event.listen(Session, "before_flush", _collect)
    event.listen(Session, "after_flush", _after_flush)
    event.listen(Session, "after_commit", _after_commit)
    event.listen(Session, "after_rollback", _after_rollback)
    _installed = True
