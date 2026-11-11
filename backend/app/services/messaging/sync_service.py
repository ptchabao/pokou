import logging
import secrets
from typing import Any

from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.settings import SystemSetting
from app.models.sync import SyncEvent

logger = logging.getLogger(__name__)

# These events change durable UI state. Presence, typing, and call signaling
# are deliberately excluded: they are transient and should not be replayed.
DURABLE_EVENT_TYPES = frozenset({
    "message:new",
    "message:status",
    "message:viewed",
    "message:deleted",
    "message:edited",
    "message:reaction",
    "conversation:updated",
    "group:invitation",
    "group:updated",
    "group:member:added",
    "group:member:removed",
    "group:member:role",
    "group:deleted",
    "group:join_request",
    "e2ee:retry_request",
    "e2ee:retry_delivered",
    "kory:updated",
    "honam:order_updated",
    "group:message:new",
    "group:message:edited",
    "group:message:reaction",
    "group:message:deleted",
    "status:new",
    "status:deleted",
    "user:profile_updated",
    "contact:registered",
    "channel:post",
    "community:member:added",
})


def persist_delivered_event(user_id: int, event: dict[str, Any]) -> str | None:
    event_type = event.get("type")
    if event_type not in DURABLE_EVENT_TYPES:
        return None

    db: Session = SessionLocal()
    try:
        row = append_sync_event(db, user_id, event)
        db.commit()
        return public_event_id(db, row.id)
    except Exception:
        db.rollback()
        logger.exception("Pokou sync event could not be persisted for user %s", user_id)
        return None
    finally:
        db.close()


def append_sync_event(
    db: Session, user_id: int, event: dict[str, Any]
) -> SyncEvent | None:
    """Append a durable event to the caller's transaction without committing."""
    event_type = event.get("type")
    if event_type not in DURABLE_EVENT_TYPES:
        return None
    row = SyncEvent(
        user_id=user_id,
        event_type=event_type,
        payload={key: value for key, value in event.items() if key != "sync_event_id"},
    )
    db.add(row)
    db.flush()
    return row


# ── La génération de la base ────────────────────────────────────────────
#
# Les numéros d'événement sont les identifiants de `sync_events`. Après une
# remise à zéro de la base (scripts/reset_database.py), ils repartent de 1 —
# alors que les téléphones gardent leur curseur (« après 93 ») et les
# numéros déjà reçus. Résultat observé en production : un téléphone sautait
# les 93 premiers événements de la nouvelle base, et ignorait ceux dont le
# numéro avait déjà servi (`ConflictAlgorithm.ignore` côté app).
#
# Chaque base reçoit donc un identifiant de génération, tiré une fois et
# rangé dans `system_settings`. Les numéros publiés et les curseurs le
# portent : « 3f9a1c2e.93 ». Un curseur d'une autre génération repart de 0.

GENERATION_KEY = "sync_generation"
_generation: str | None = None


def sync_generation(db: Session) -> str:
    """L'identifiant de génération de la base, créé au premier besoin.

    Mis en cache pour la vie du processus : il ne change qu'avec une remise
    à zéro, qui se fait au démarrage, avant que le processus ne serve."""
    global _generation
    if _generation:
        return _generation
    row = db.query(SystemSetting).filter(SystemSetting.key == GENERATION_KEY).first()
    if row is None or not row.value:
        # Sa propre session : on n'engage pas la transaction de l'appelant.
        with Session(bind=db.get_bind()) as own:
            try:
                own.add(SystemSetting(key=GENERATION_KEY, value=secrets.token_hex(4)))
                own.commit()
            except IntegrityError:
                own.rollback()  # une autre instance l'a créé à l'instant
        db.expire_all()
        row = db.query(SystemSetting).filter(SystemSetting.key == GENERATION_KEY).first()
    _generation = row.value
    return _generation


def public_event_id(db: Session, raw_id: int | None) -> str | None:
    """Le numéro d'événement tel que les clients le voient."""
    if raw_id is None:
        return None
    return f"{sync_generation(db)}.{raw_id}"


def parse_cursor(db: Session, cursor: str | None) -> tuple[int, bool]:
    """(identifiant à partir duquel lire, curseur remis à zéro ?).

    - « génération.n » de la génération courante : n ;
    - autre génération : 0, remis à zéro ;
    - entier nu (versions de l'app d'avant ce format) : accepté s'il ne
      dépasse pas le dernier événement existant, sinon il vient forcément
      d'une base précédente : 0, remis à zéro ;
    - illisible : 0, remis à zéro.
    """
    raw = (cursor or "0").strip()
    if "." in raw:
        generation, _, number = raw.partition(".")
        if generation == sync_generation(db) and number.isdigit():
            return int(number), False
        return 0, True
    if raw.isdigit():
        value = int(raw)
        if value == 0:
            return 0, False
        newest = db.query(func.max(SyncEvent.id)).scalar() or 0
        if value > newest:
            return 0, True
        return value, False
    return 0, True
