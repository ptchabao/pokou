"""Le relais de l'outbox vers Kafka — un processus à part entière.

    python -m app.workers.outbox_relay

Séparé de l'API, pour deux raisons : il se met à l'échelle indépendamment
(un seul suffit longtemps), et une API qui redémarre en boucle ne doit pas
emporter la publication des évènements avec elle. Sur Kubernetes, c'est le
Deployment `pokou-outbox-relay`.

Sans `KAFKA_BOOTSTRAP_SERVERS`, il s'arrête aussitôt avec un message clair :
les évènements restent dans la table et partiront quand Kafka sera branché.
"""
import asyncio
import logging
import signal
import ssl

from app.core.config import get_settings
from app.core.database import SessionLocal
from app.services.events.outbox import publish_pending, purge_published

logger = logging.getLogger("pokou.outbox_relay")

IDLE_SECONDS = 1.0
PURGE_EVERY_SECONDS = 3600


def _producer_kwargs(settings) -> dict:
    kwargs = {
        "bootstrap_servers": settings.kafka_bootstrap_servers,
        "security_protocol": settings.kafka_security_protocol,
        # Au moins une fois, sans doublon côté courtier en cas de nouvel
        # essai du producteur, et écrit sur toutes les répliques à jour.
        "acks": "all",
        "enable_idempotence": True,
        "linger_ms": 20,
        "compression_type": "gzip",
    }
    if settings.kafka_security_protocol in ("SSL", "SASL_SSL"):
        context = ssl.create_default_context(cafile=settings.kafka_ssl_cafile or None)
        kwargs["ssl_context"] = context
    if settings.kafka_sasl_mechanism:
        kwargs["sasl_mechanism"] = settings.kafka_sasl_mechanism
        kwargs["sasl_plain_username"] = settings.kafka_sasl_username
        kwargs["sasl_plain_password"] = settings.kafka_sasl_password
    return kwargs


async def run() -> None:
    settings = get_settings()
    if not settings.kafka_bootstrap_servers:
        logger.warning("[Outbox] KAFKA_BOOTSTRAP_SERVERS vide : relais inactif, les évènements restent en base.")
        return

    from aiokafka import AIOKafkaProducer

    producer = AIOKafkaProducer(**_producer_kwargs(settings))
    await producer.start()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)

    async def send(topic: str, key, value: bytes) -> None:
        await producer.send_and_wait(topic, value=value, key=key)

    logger.info("[Outbox] Relais démarré vers %s", settings.kafka_bootstrap_servers)
    last_purge = 0.0
    try:
        while not stop.is_set():
            db = SessionLocal()
            try:
                published = await publish_pending(db, send)
                now = loop.time()
                if now - last_purge > PURGE_EVERY_SECONDS:
                    purge_published(db)
                    last_purge = now
            finally:
                db.close()
            if published == 0:
                try:
                    await asyncio.wait_for(stop.wait(), timeout=IDLE_SECONDS)
                except asyncio.TimeoutError:
                    pass
    finally:
        # SIGTERM de Kubernetes : on vide ce qui est en vol avant de partir.
        await producer.stop()
        logger.info("[Outbox] Relais arrêté")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    asyncio.run(run())
