"""Écrire un évènement métier, et le publier vers Kafka.

Les routes n'appellent que `record_event` : elles ne savent pas si Kafka
existe. Le relais appelle `publish_pending`, avec un producteur injecté pour
que les tests n'aient besoin d'aucun courtier.
"""
import json
import logging
import uuid
from datetime import datetime, timedelta
from typing import Any, Awaitable, Callable, Optional

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import OutboxEvent

logger = logging.getLogger(__name__)

#: Un lot par tour : assez pour suivre un pic, assez peu pour que la
#: transaction qui verrouille les lignes reste brève.
BATCH_SIZE = 200
SCHEMA_VERSION = 1


def record_event(
    db: Session,
    topic: str,
    event_type: str,
    data: dict[str, Any],
    *,
    key: Optional[str] = None,
) -> OutboxEvent:
    """Ajoute l'évènement à la session ; c'est le `commit` de l'appelant
    qui l'écrit, avec la donnée qu'il décrit, ou pas du tout."""
    envelope = {
        "id": str(uuid.uuid4()),
        "type": event_type,
        "version": SCHEMA_VERSION,
        "occurred_at": datetime.utcnow().isoformat() + "Z",
        "data": data,
    }
    event = OutboxEvent(
        topic=topic,
        key=key,
        event_type=event_type,
        payload=json.dumps(envelope, ensure_ascii=False, separators=(",", ":")),
    )
    db.add(event)
    return event


def full_topic(topic: str) -> str:
    prefix = get_settings().kafka_topic_prefix.strip(".")
    return f"{prefix}.{topic}" if prefix else topic


Send = Callable[[str, Optional[bytes], bytes], Awaitable[None]]


async def publish_pending(db: Session, send: Send, *, batch_size: int = BATCH_SIZE) -> int:
    """Publie un lot d'évènements en attente, dans l'ordre d'insertion.

    `FOR UPDATE SKIP LOCKED` sous PostgreSQL : deux relais en parallèle se
    partagent les lignes au lieu de les publier deux fois. Une ligne n'est
    marquée publiée qu'après l'accusé de Kafka (`acks=all`) ; un échec
    l'arrête là, pour ne pas publier la suivante avant elle et casser
    l'ordre d'une même cagnotte.
    """
    query = (
        db.query(OutboxEvent)
        .filter(OutboxEvent.published_at.is_(None))
        .order_by(OutboxEvent.id)
        .limit(batch_size)
    )
    if db.bind is not None and db.bind.dialect.name == "postgresql":
        query = query.with_for_update(skip_locked=True)
    published = 0
    for event in query.all():
        try:
            await send(
                full_topic(event.topic),
                event.key.encode() if event.key else None,
                event.payload.encode(),
            )
        except Exception as exc:  # le courtier dira pourquoi, on le garde
            event.attempts += 1
            event.last_error = str(exc)[:500]
            logger.warning("[Outbox] Publication échouée (%s) : %s", event.event_type, exc)
            break
        event.published_at = datetime.utcnow()
        event.attempts += 1
        published += 1
    db.commit()
    return published


def purge_published(db: Session) -> int:
    cutoff = datetime.utcnow() - timedelta(days=get_settings().outbox_retention_days)
    deleted = (
        db.query(OutboxEvent)
        .filter(OutboxEvent.published_at.isnot(None), OutboxEvent.published_at < cutoff)
        .delete(synchronize_session=False)
    )
    db.commit()
    return deleted
