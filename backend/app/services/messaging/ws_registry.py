"""Le registre des connexions temps réel, partagé entre instances.

── Le problème ───────────────────────────────────────────────────────────

`ConnectionManager` gardait ses sockets dans un `Dict` de processus. Une
socket EST liée à son processus — c'est inévitable — mais le registre, lui,
ne doit pas l'être. Avec deux instances :

    A (servi par l'instance 1) écrit à B (connecté à l'instance 2)
        ↓
    instance 1 cherche la socket de B dans SON dictionnaire
        ↓
    ne la trouve pas
        ↓
    « B n'est pas connecté » → notification push

Le message arrive quand même, par le push. C'est ce qui rend la panne
SILENCIEUSE : le temps réel a cessé de fonctionner et personne ne le voit,
parce que le repli le masque. Le fondateur l'a dit mieux que moi — « le
fallback FCM doit rester un fallback, pas masquer une défaillance du temps
réel ».

── La correction ─────────────────────────────────────────────────────────

Redis, en deux rôles distincts qu'il ne faut pas confondre :

1. **un canal de diffusion** : `send_to_user` PUBLIE au lieu d'écrire
   directement. Chaque instance est abonnée et livre aux sockets qu'elle
   détient. L'émetteur n'a pas besoin de savoir où se trouve le
   destinataire ;

2. **un registre de présence** : qui est connecté, et sur quelles instances.
   C'est lui qui décide s'il faut envoyer un push — sans lui, l'instance 1
   pousserait une notification à un B pourtant connecté ailleurs, et
   l'utilisateur recevrait le message DEUX fois.

── Le repli, et pourquoi il compte ───────────────────────────────────────

Redis indisponible ne doit pas couper la messagerie. Tout ce module
retombe alors sur le comportement d'avant — registre local, une seule
instance — qui reste correct tant qu'il n'y en a qu'une. Une dépendance
ajoutée pour permettre la mise à l'échelle ne doit pas devenir un point de
panne pour ceux qui n'en ont pas besoin.
"""
import asyncio
import json
import logging
import os
import time
import uuid
from typing import Any, Callable, Dict, Optional

from app.core.config import get_settings

logger = logging.getLogger(__name__)

#: Le canal de diffusion. Un seul, avec l'identifiant du destinataire dans
#: la charge utile : un canal par utilisateur imposerait de s'abonner et de
#: se désabonner à chaque connexion, et Redis n'aime pas les abonnements qui
#: changent des centaines de fois par seconde.
CHANNEL = "pokou:ws:events"

#: Qui est en ligne. Une table de hachage par utilisateur : le champ est
#: l'identifiant d'instance, la valeur l'horodatage du dernier signe de vie.
#:
#: Une table plutôt qu'un ensemble, parce qu'une instance qui tombe ne
#: retire pas ses entrées. L'horodatage permet de les ignorer, et une
#: instance vivante rafraîchit les siennes.
def _presence_key(user_id: int) -> str:
    return f"pokou:ws:online:{user_id}"


#: Au-delà de ce silence, une instance est considérée comme morte et ses
#: entrées ne comptent plus. Généreux devant l'intervalle de battement (30 s)
#: pour qu'un pic de charge ne fasse pas disparaître des gens en ligne.
PRESENCE_TTL_SECONDS = 90
HEARTBEAT_SECONDS = 30

#: La clé de présence expire d'elle-même : si toutes les instances tombent,
#: personne ne reste éternellement « en ligne ».
KEY_TTL_SECONDS = PRESENCE_TTL_SECONDS * 2


class WsRegistry:
    """Le registre partagé. Une instance par processus."""

    def __init__(self, instance_id: Optional[str] = None) -> None:
        # Un identifiant par PROCESSUS, pas par machine : deux workers
        # uvicorn sur le même hôte sont deux instances du point de vue des
        # sockets qu'ils détiennent.
        self.instance_id = instance_id or os.environ.get(
            "POKOU_INSTANCE_ID", f"{os.getpid()}-{uuid.uuid4().hex[:8]}"
        )
        self._redis = None
        self._pubsub = None
        self._listener: Optional[asyncio.Task] = None
        self._heartbeat: Optional[asyncio.Task] = None
        self._local_users: set[int] = set()
        self._deliver: Optional[Callable[[int, Dict[str, Any]], Any]] = None
        self._enabled = False

    @property
    def enabled(self) -> bool:
        """Redis répond-il ? Sinon tout retombe sur le registre local."""
        return self._enabled

    async def start(self, deliver: Callable[[int, Dict[str, Any]], Any]) -> None:
        """Se connecte à Redis et commence à écouter.

        `deliver(user_id, event)` est appelé pour chaque évènement reçu du
        canal : c'est au `ConnectionManager` d'écrire sur ses sockets
        locales. Ce module ne connaît pas les sockets, et c'est voulu — il
        serait sinon impossible de le tester sans en ouvrir.
        """
        self._deliver = deliver
        try:
            import redis.asyncio as aioredis

            self._redis = aioredis.from_url(
                get_settings().redis_url, decode_responses=True
            )
            await self._redis.ping()
            self._pubsub = self._redis.pubsub(ignore_subscribe_messages=True)
            await self._pubsub.subscribe(CHANNEL)
            self._listener = asyncio.create_task(self._listen())
            self._heartbeat = asyncio.create_task(self._beat())
            self._enabled = True
            logger.info(
                "[WS] Registre distribué actif — instance %s", self.instance_id
            )
        except Exception as exc:
            # Pas d'exception propagée : une API qui refuse de démarrer
            # parce que Redis est absent serait une régression pour un
            # déploiement à une seule instance, qui n'en a pas besoin.
            self._enabled = False
            logger.warning(
                "[WS] Registre distribué indisponible (%s) — repli sur le "
                "registre local, valable pour UNE instance",
                exc.__class__.__name__,
            )

    async def stop(self) -> None:
        for task in (self._listener, self._heartbeat):
            if task:
                task.cancel()
        # Retrait PROPRE : sans lui, les gens connectés à cette instance
        # restent « en ligne » jusqu'à l'expiration, et les messages qui
        # leur sont destinés partent dans le vide pendant ce temps.
        if self._enabled and self._redis:
            for user_id in list(self._local_users):
                try:
                    await self._redis.hdel(_presence_key(user_id), self.instance_id)
                except Exception:
                    pass
        if self._pubsub:
            try:
                await self._pubsub.unsubscribe(CHANNEL)
                await self._pubsub.aclose()
            except Exception:
                pass
        if self._redis:
            try:
                await self._redis.aclose()
            except Exception:
                pass
        self._enabled = False

    async def register(self, user_id: int) -> None:
        """Déclare qu'un utilisateur a une socket ouverte ICI."""
        self._local_users.add(user_id)
        if not self._enabled:
            return
        try:
            key = _presence_key(user_id)
            await self._redis.hset(key, self.instance_id, str(time.time()))
            await self._redis.expire(key, KEY_TTL_SECONDS)
        except Exception as exc:
            logger.warning("[WS] Présence non enregistrée : %s", exc)

    async def unregister(self, user_id: int) -> None:
        """Cet utilisateur n'a plus de socket ici."""
        self._local_users.discard(user_id)
        if not self._enabled:
            return
        try:
            await self._redis.hdel(_presence_key(user_id), self.instance_id)
        except Exception as exc:
            logger.warning("[WS] Présence non retirée : %s", exc)

    async def is_online(self, user_id: int, local: bool) -> bool:
        """Cet utilisateur a-t-il une socket ouverte QUELQUE PART ?

        C'est cette réponse qui décide d'envoyer un push. Se tromper coûte
        cher dans les deux sens : dire « non » à tort double la notification
        pour quelqu'un qui recevra aussi le message en temps réel, dire
        « oui » à tort la supprime pour quelqu'un qui ne verra rien.

        `local` est la réponse du registre de processus, et elle fait foi
        quand elle est positive : une socket qu'on détient soi-même est la
        preuve la plus directe qui soit.
        """
        if local:
            return True
        if not self._enabled:
            return False
        try:
            entries = await self._redis.hgetall(_presence_key(user_id))
        except Exception:
            return False
        if not entries:
            return False
        limite = time.time() - PRESENCE_TTL_SECONDS
        # Les entrées d'une instance morte sont ignorées, pas nettoyées ici :
        # un nettoyage sur le chemin de lecture ajouterait une écriture à
        # chaque envoi de message. Le battement des instances vivantes et
        # l'expiration de la clé s'en chargent.
        return any(float(vu) > limite for vu in entries.values() if vu)

    async def publish(self, user_id: int, event: Dict[str, Any]) -> None:
        """Diffuse un évènement aux AUTRES instances.

        L'instance émettrice a déjà livré à ses propres sockets : elle
        s'ignore à la réception, sinon le destinataire recevrait le message
        deux fois s'il est connecté ici.
        """
        if not self._enabled:
            return
        try:
            await self._redis.publish(
                CHANNEL,
                json.dumps(
                    {"from": self.instance_id, "user_id": user_id, "event": event}
                ),
            )
        except Exception as exc:
            logger.warning("[WS] Diffusion impossible : %s", exc)

    async def _listen(self) -> None:
        assert self._pubsub is not None
        try:
            async for message in self._pubsub.listen():
                if message.get("type") != "message":
                    continue
                try:
                    payload = json.loads(message["data"])
                except Exception:
                    continue
                if payload.get("from") == self.instance_id:
                    continue  # déjà livré localement
                user_id = payload.get("user_id")
                event = payload.get("event")
                if user_id is None or event is None or self._deliver is None:
                    continue
                try:
                    await self._deliver(int(user_id), event)
                except Exception as exc:
                    logger.warning("[WS] Livraison locale échouée : %s", exc)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logger.error("[WS] Écoute interrompue : %s", exc)
            self._enabled = False

    async def _beat(self) -> None:
        """Rafraîchit la présence des utilisateurs connectés ici.

        Sans battement, une instance vivante depuis plus de PRESENCE_TTL
        verrait ses utilisateurs disparaître du registre et recevoir des
        notifications en double.
        """
        try:
            while True:
                await asyncio.sleep(HEARTBEAT_SECONDS)
                if not self._enabled:
                    continue
                maintenant = str(time.time())
                for user_id in list(self._local_users):
                    try:
                        key = _presence_key(user_id)
                        await self._redis.hset(key, self.instance_id, maintenant)
                        await self._redis.expire(key, KEY_TTL_SECONDS)
                    except Exception:
                        break
        except asyncio.CancelledError:
            raise


registry = WsRegistry()
