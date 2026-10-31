"""Envoi de messages WhatsApp : Twilio s'il est configuré, sinon la
passerelle WhatsApp auto-hébergée (`WHATSAPP_SERVICE_URL`).

Seul usage dans Pokou : le second canal des codes de connexion (voir
services/auth/otp_service.py). Au Togo, la livraison SMS est régulièrement
lente ou perdue par l'opérateur ; WhatsApp arrive souvent quand le SMS
n'arrive pas.
"""
import logging
import os
import time
from typing import Dict

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

MAX_RETRIES = 3
BASE_DELAY_SECONDS = 2
# Un même texte vers un même numéro dans cette fenêtre n'est envoyé qu'une
# fois : un double clic sur « renvoyer » ne doit pas doubler le message.
DEDUP_WINDOW_SECONDS = 30

_recent_outbound: Dict[str, float] = {}


def _service_url() -> str:
    return (os.getenv("WHATSAPP_SERVICE_URL", "").strip() or (settings.whatsapp_service_url or "").strip())


def _send_via_twilio(destination: str, message: str) -> bool:
    url = f"https://api.twilio.com/2010-04-01/Accounts/{settings.twilio_account_sid}/Messages.json"
    data = {"From": settings.twilio_whatsapp_from, "To": f"whatsapp:{destination}", "Body": message}
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = httpx.post(
                url,
                data=data,
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
                timeout=settings.whatsapp_service_timeout_seconds,
            )
            resp.raise_for_status()
            logger.info("[WhatsApp] Envoyé via Twilio à %s", destination)
            return True
        except Exception as exc:
            logger.warning("[WhatsApp] Tentative %d/%d via Twilio échouée pour %s : %s", attempt, MAX_RETRIES, destination, exc)
            if attempt < MAX_RETRIES:
                time.sleep(BASE_DELAY_SECONDS * (2 ** (attempt - 1)))
    return False


def _send_via_gateway(destination: str, message: str) -> bool:
    base_url = _service_url()
    if not base_url:
        logger.error("[WhatsApp] WHATSAPP_SERVICE_URL n'est pas configurée — envoi impossible vers %s", destination)
        return False

    url = base_url.rstrip("/") + "/send"
    headers = {"X-Gateway-Secret": settings.whatsapp_gateway_secret} if settings.whatsapp_gateway_secret else {}
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = httpx.post(
                url,
                json={"number": destination, "message": message},
                headers=headers,
                timeout=settings.whatsapp_service_timeout_seconds,
            )
            if resp.status_code < 400:
                logger.info("[WhatsApp] Envoyé via la passerelle à %s", destination)
                return True
            logger.warning(
                "[WhatsApp] Tentative %d/%d : HTTP %d pour %s — %s",
                attempt, MAX_RETRIES, resp.status_code, destination, (resp.text or "")[:300],
            )
            # Numéro refusé ou inconnu de WhatsApp : réessayer n'y changera rien.
            if resp.status_code in (400, 404):
                return False
        except Exception as exc:
            logger.warning("[WhatsApp] Tentative %d/%d échouée pour %s : %s", attempt, MAX_RETRIES, destination, exc)
        if attempt < MAX_RETRIES:
            time.sleep(BASE_DELAY_SECONDS * (2 ** (attempt - 1)))

    logger.error("[WhatsApp] Abandon après %d tentatives pour %s", MAX_RETRIES, destination)
    return False


def send_whatsapp(message: str, destination: str) -> bool:
    """Renvoie `True` si le message a été accepté par Twilio ou la passerelle.

    Bloquant (jusqu'à trois tentatives avec attente exponentielle) : à
    appeler hors de la boucle asyncio, comme le fait otp_service."""
    destination = str(destination or "").replace("whatsapp:", "").strip()
    if not destination:
        return False

    now = time.time()
    for key, sent_at in list(_recent_outbound.items()):
        if now - sent_at > DEDUP_WINDOW_SECONDS:
            _recent_outbound.pop(key, None)
    dedup_key = f"{destination}:{message.strip()}"
    if dedup_key in _recent_outbound:
        logger.info("[WhatsApp] Envoi en double ignoré pour %s", destination)
        return True

    if settings.twilio_account_sid and settings.twilio_auth_token and settings.twilio_whatsapp_from:
        if _send_via_twilio(destination, message):
            _recent_outbound[dedup_key] = time.time()
            return True

    if _send_via_gateway(destination, message):
        _recent_outbound[dedup_key] = time.time()
        return True
    return False
