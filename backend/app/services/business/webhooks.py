"""La remise des événements au serveur du développeur.

Chaque événement est d'abord ÉCRIT (`vb_webhook_deliveries`), puis remis
par le planificateur — jamais envoyé depuis la requête qui l'a causé : un
serveur lent ou en panne chez le développeur ne doit pas ralentir l'envoi
d'un message dans Pokou, et un redémarrage ne doit rien faire perdre.

Signature, en-tête `X-Pokou-Signature: t=<horodatage>,v1=<hmac>` où
`hmac = HMAC-SHA256(secret, "<horodatage>.<corps brut>")`. L'horodatage
est SIGNÉ : un attaquant qui a capté une requête ne peut pas la rejouer
plus tard en changeant la date — la documentation demande de refuser un
écart de plus de 5 minutes.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import time
import uuid
from datetime import datetime, timedelta
from typing import Any, Optional

import httpx
from sqlalchemy.orm import Session

from app.models.business import Bot, WebhookDelivery
from app.utils.net import is_publicly_routable_url

logger = logging.getLogger(__name__)

#: Délai avant chaque nouvelle tentative — environ 21 heures au total.
RETRY_DELAYS = [
    timedelta(seconds=30),
    timedelta(minutes=2),
    timedelta(minutes=10),
    timedelta(minutes=30),
    timedelta(hours=2),
    timedelta(hours=6),
    timedelta(hours=12),
]
MAX_ATTEMPTS = len(RETRY_DELAYS) + 1
TIMEOUT_SECONDS = 8.0


def signer(secret: str, horodatage: int, corps: bytes) -> str:
    message = f"{horodatage}.".encode() + corps
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def entete_signature(secret: str, corps: bytes, horodatage: Optional[int] = None) -> str:
    t = int(horodatage if horodatage is not None else time.time())
    return f"t={t},v1={signer(secret, t, corps)}"


def mettre_en_file(db: Session, bot: Bot, event_type: str, data: dict[str, Any]) -> Optional[WebhookDelivery]:
    """Écrit l'événement — sans l'envoyer. Rien si le bot n'a pas d'URL."""
    if not bot.webhook_url:
        return None
    event_id = str(uuid.uuid4())
    livraison = WebhookDelivery(
        bot_id=bot.id,
        event_id=event_id,
        event_type=event_type,
        payload={
            "id": event_id,
            "type": event_type,
            "created_at": datetime.utcnow().isoformat() + "Z",
            "bot": {"id": bot.id, "handle": bot.handle},
            "data": data,
        },
        next_attempt_at=datetime.utcnow(),
    )
    db.add(livraison)
    return livraison


def _envoyer(bot: Bot, livraison: WebhookDelivery, client: httpx.Client) -> tuple[Optional[int], Optional[str]]:
    corps = json.dumps(livraison.payload, separators=(",", ":"), ensure_ascii=False).encode()
    if not is_publicly_routable_url(bot.webhook_url or ""):
        return None, "URL non publique ou injoignable"
    try:
        reponse = client.post(
            bot.webhook_url,
            content=corps,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Pokou-Webhooks/1.0",
                "X-Pokou-Event": livraison.event_type,
                "X-Pokou-Event-Id": livraison.event_id,
                "X-Pokou-Signature": entete_signature(bot.webhook_secret, corps),
            },
            # Pas de redirection suivie : elle contournerait la vérification
            # d'URL publique ci-dessus.
            follow_redirects=False,
        )
    except httpx.HTTPError as exc:
        return None, f"{type(exc).__name__}"[:255]
    return reponse.status_code, None


def remettre_en_attente(db: Session, now: Optional[datetime] = None, limite: int = 100, client: Optional[httpx.Client] = None) -> dict[str, int]:
    """Une passe du planificateur : tente chaque événement échu.

    2xx → DELIVERED. Sinon, nouvelle tentative plus tard ; au-delà de
    `MAX_ATTEMPTS`, FAILED — visible et rejouable depuis le portail."""
    now = now or datetime.utcnow()
    dues = (
        db.query(WebhookDelivery)
        .filter(WebhookDelivery.status == "PENDING", WebhookDelivery.next_attempt_at <= now)
        .order_by(WebhookDelivery.next_attempt_at)
        .limit(limite)
        .all()
    )
    bilan = {"delivered": 0, "retried": 0, "failed": 0}
    if not dues:
        return bilan
    possede = client is None
    client = client or httpx.Client(timeout=TIMEOUT_SECONDS)
    try:
        for livraison in dues:
            bot = db.query(Bot).filter(Bot.id == livraison.bot_id).first()
            livraison.attempts += 1
            if bot is None or not bot.is_active or not bot.webhook_url:
                livraison.status = "FAILED"
                livraison.last_error = "Bot désactivé ou sans URL"
                bilan["failed"] += 1
                continue
            code, erreur = _envoyer(bot, livraison, client)
            livraison.last_status_code = code
            livraison.last_error = erreur
            if code is not None and 200 <= code < 300:
                livraison.status = "DELIVERED"
                livraison.delivered_at = now
                bilan["delivered"] += 1
            elif livraison.attempts >= MAX_ATTEMPTS:
                livraison.status = "FAILED"
                bilan["failed"] += 1
            else:
                livraison.next_attempt_at = now + RETRY_DELAYS[livraison.attempts - 1]
                bilan["retried"] += 1
        db.commit()
    finally:
        if possede:
            client.close()
    return bilan
