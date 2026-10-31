"""Deux instances FastAPI, une seule messagerie.

C'est le critère de sortie du P0, énoncé par le fondateur :

    A connecté sur l'instance 1
    B connecté sur l'instance 2
    A écrit à B
    B reçoit le message en WebSocket
    aucun doublon FCM

Le registre des sockets était un dictionnaire de processus. L'instance 1 ne
trouvait donc pas la socket de B, concluait « hors ligne » et envoyait une
notification push. Le message arrivait quand même — et c'est précisément ce
qui rendait la panne invisible : le repli masquait la mort du temps réel.

Ces tests montent un faux Redis en mémoire, partagé par deux registres
distincts. Deux processus ne peuvent pas être simulés dans un test unitaire,
mais deux REGISTRES qui ne se connaissent que par Redis, si — et c'est
exactement ce qu'on veut éprouver.
"""
import asyncio
import json
import time

import pytest

from app.services.messaging import ws_registry
from app.services.messaging.ws_registry import WsRegistry


class FakeRedis:
    """Le strict nécessaire : hash, pubsub, expire.

    Partagé par les deux registres — c'est lui qui joue le rôle du Redis
    commun à deux instances.
    """

    def __init__(self):
        self.hashes: dict[str, dict[str, str]] = {}
        self.subscribers: list["FakePubSub"] = []

    async def ping(self):
        return True

    async def hset(self, key, field, value):
        self.hashes.setdefault(key, {})[field] = value

    async def hdel(self, key, field):
        self.hashes.get(key, {}).pop(field, None)

    async def hgetall(self, key):
        return dict(self.hashes.get(key, {}))

    async def expire(self, key, ttl):
        return True

    async def publish(self, channel, data):
        for sub in self.subscribers:
            await sub.queue.put({"type": "message", "channel": channel, "data": data})

    def pubsub(self, ignore_subscribe_messages=False):
        sub = FakePubSub(self)
        self.subscribers.append(sub)
        return sub

    async def aclose(self):
        return None


class FakePubSub:
    def __init__(self, redis):
        self.redis = redis
        self.queue: asyncio.Queue = asyncio.Queue()

    async def subscribe(self, channel):
        return None

    async def unsubscribe(self, channel):
        return None

    async def aclose(self):
        if self in self.redis.subscribers:
            self.redis.subscribers.remove(self)

    async def listen(self):
        while True:
            yield await self.queue.get()


async def _start(registry: WsRegistry, redis: FakeRedis, deliver) -> None:
    """Démarre un registre sur le faux Redis, sans passer par `from_url`."""
    registry._deliver = deliver
    registry._redis = redis
    registry._pubsub = redis.pubsub(ignore_subscribe_messages=True)
    await registry._pubsub.subscribe(ws_registry.CHANNEL)
    registry._listener = asyncio.create_task(registry._listen())
    registry._enabled = True


@pytest.fixture
def redis():
    return FakeRedis()


@pytest.mark.asyncio
async def test_un_evenement_traverse_les_instances(redis):
    """Le cœur du sujet : A sur l'instance 1, B sur l'instance 2."""
    recus_2: list[tuple[int, dict]] = []

    instance_1 = WsRegistry("inst-1")
    instance_2 = WsRegistry("inst-2")
    await _start(instance_1, redis, lambda uid, ev: None)
    await _start(instance_2, redis, lambda uid, ev: recus_2.append((uid, ev)))

    # B a sa socket sur l'instance 2.
    await instance_2.register(user_id=7)

    # L'instance 1 publie un message destiné à B.
    await instance_1.publish(7, {"type": "message:new", "id": "m1"})
    await asyncio.sleep(0.05)

    assert recus_2 == [(7, {"type": "message:new", "id": "m1"})]

    await instance_1.stop()
    await instance_2.stop()


@pytest.mark.asyncio
async def test_l_instance_emettrice_ne_se_livre_pas_a_elle_meme(redis):
    """Sinon le destinataire connecté ICI recevrait le message deux fois :
    une par la livraison locale, une par le canal."""
    recus: list = []

    instance_1 = WsRegistry("inst-1")
    await _start(instance_1, redis, lambda uid, ev: recus.append(ev))

    await instance_1.publish(7, {"type": "message:new"})
    await asyncio.sleep(0.05)

    assert recus == []
    await instance_1.stop()


@pytest.mark.asyncio
async def test_en_ligne_ailleurs_est_vu_comme_en_ligne(redis):
    """La question qui décide d'un push.

    Sans registre partagé, l'instance 1 répondait « hors ligne » pour
    quelqu'un connecté à l'instance 2 — et lui envoyait une notification
    alors qu'il recevait déjà le message en temps réel. C'est le doublon FCM
    du critère de sortie.
    """
    instance_1 = WsRegistry("inst-1")
    instance_2 = WsRegistry("inst-2")
    await _start(instance_1, redis, lambda uid, ev: None)
    await _start(instance_2, redis, lambda uid, ev: None)

    assert await instance_1.is_online(7, local=False) is False

    await instance_2.register(user_id=7)

    assert await instance_1.is_online(7, local=False) is True

    await instance_1.stop()
    await instance_2.stop()


@pytest.mark.asyncio
async def test_se_deconnecter_retire_la_presence(redis):
    instance_1 = WsRegistry("inst-1")
    instance_2 = WsRegistry("inst-2")
    await _start(instance_1, redis, lambda uid, ev: None)
    await _start(instance_2, redis, lambda uid, ev: None)

    await instance_2.register(7)
    await instance_2.unregister(7)

    assert await instance_1.is_online(7, local=False) is False

    await instance_1.stop()
    await instance_2.stop()


@pytest.mark.asyncio
async def test_une_instance_morte_ne_garde_personne_en_ligne(redis):
    """Une instance qui tombe ne retire pas ses entrées.

    Sans horodatage, ses utilisateurs resteraient « en ligne » pour
    toujours : plus aucune notification ne leur parviendrait, et le « vu à »
    afficherait une présence qui n'existe plus.
    """
    instance_1 = WsRegistry("inst-1")
    await _start(instance_1, redis, lambda uid, ev: None)

    # Une entrée laissée par une instance disparue, trop vieille.
    redis.hashes[ws_registry._presence_key(7)] = {
        "inst-morte": str(time.time() - ws_registry.PRESENCE_TTL_SECONDS - 10)
    }

    assert await instance_1.is_online(7, local=False) is False
    await instance_1.stop()


@pytest.mark.asyncio
async def test_une_socket_locale_fait_foi_sans_interroger_redis(redis):
    """La preuve la plus directe qui soit : on détient la socket.

    Interroger Redis pour une réponse qu'on a déjà coûterait un aller-retour
    sur le chemin le plus chaud de l'API.
    """
    instance_1 = WsRegistry("inst-1")
    # Volontairement PAS démarré : si `local=True` interrogeait Redis, ce
    # test échouerait.
    assert await instance_1.is_online(7, local=True) is True


@pytest.mark.asyncio
async def test_sans_redis_tout_retombe_sur_le_registre_local(monkeypatch):
    """Redis absent ne doit pas couper la messagerie.

    Une dépendance ajoutée pour permettre la mise à l'échelle ne doit pas
    devenir un point de panne pour un déploiement à une seule instance, qui
    n'en a pas besoin.
    """
    # Un port sur lequel personne n'écoute. Un vrai Redis tourne peut-être
    # sur cette machine — c'est d'ailleurs le cas — et le test doit éprouver
    # le repli, pas la configuration locale de la machine de build.
    class _Injoignable:
        redis_url = "redis://127.0.0.1:1/0"

    monkeypatch.setattr(ws_registry, "get_settings", lambda: _Injoignable())

    instance = WsRegistry("inst-seule")
    # `start` échoue silencieusement sur une URL injoignable.
    await instance.start(lambda uid, ev: None)

    assert instance.enabled is False
    # Aucune exception : les appels sont sans effet.
    await instance.register(7)
    await instance.publish(7, {"type": "x"})
    assert await instance.is_online(7, local=False) is False
    assert await instance.is_online(7, local=True) is True
    await instance.stop()


@pytest.mark.asyncio
async def test_un_message_illisible_n_interrompt_pas_l_ecoute(redis):
    """Une charge utile abîmée ne doit pas tuer le canal : tout le temps
    réel de l'instance en dépend."""
    recus: list = []
    instance = WsRegistry("inst-1")
    await _start(instance, redis, lambda uid, ev: recus.append(ev))

    for sub in redis.subscribers:
        await sub.queue.put({"type": "message", "data": "pas du json"})
    await asyncio.sleep(0.02)

    await redis.publish(ws_registry.CHANNEL, json.dumps(
        {"from": "autre", "user_id": 7, "event": {"type": "ok"}}
    ))
    await asyncio.sleep(0.05)

    assert recus == [{"type": "ok"}]
    await instance.stop()
