"""Envoi de SMS via la passerelle NGH.

Seul usage dans Pokou : livrer les codes de connexion (voir
services/auth/otp_service.py). Les identifiants de la passerelle se règlent
à chaud dans les réglages système (`ngh_api_key`/`ngh_api_secret`), avec
repli sur l'environnement.
"""
import logging
import re
from datetime import datetime

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services import settings_service

logger = logging.getLogger(__name__)
settings = get_settings()

NGH_SEND_SMS_URL = "https://extranet.nghcorp.net/api/send-sms"


def _gateway_msisdn(number: str) -> str:
    """Le numéro tel que la passerelle NGH l'attend : des CHIFFRES, sans le
    « + ».

    Tout le reste du code manipule de l'E.164 (`+22890000000`) et c'est très
    bien : c'est ce qui rend un numéro comparable d'un module à l'autre. Mais
    la documentation NGH montre `"to": 22892470847`, et la passerelle refuse
    la forme préfixée — silencieusement, puisque rien n'était journalisé.
    C'est la conversion qui manquait, et elle n'appartient qu'ici : à la
    frontière avec ce fournisseur précis.
    """
    return re.sub(r"\D", "", number or "")


def send_sms(db: Session, to: str, text: str, from_sender: str) -> bool:
    """Un SMS via la passerelle NGH. Renvoie `True` si elle l'a ACCEPTÉ.

    NGH répond HTTP 200 avec un corps qui porte le vrai verdict
    (`{"status": 200, "status_desc": "Success"}`) : c'est ce verdict qui est
    lu, pas seulement le code HTTP. Chaque refus est journalisé.

    Le texte n'est jamais journalisé : il transporte les codes de connexion.
    Le numéro et le motif de refus suffisent à diagnostiquer.
    """
    destination = _gateway_msisdn(to)
    if not destination:
        logger.error("[SMS] Numéro inexploitable, envoi abandonné (reçu: %r)", to)
        return False

    api_key = settings_service.get_setting(db, "ngh_api_key") or getattr(settings, "ngh_api_key", "") or ""
    api_secret = settings_service.get_setting(db, "ngh_api_secret") or getattr(settings, "ngh_api_secret", "") or ""
    if not (api_key and api_secret):
        logger.error(
            "[SMS] Passerelle NGH non configurée (ngh_api_key/ngh_api_secret) — "
            "aucun SMS ne peut partir. À renseigner dans les réglages admin."
        )
        return False

    payload = {
        "from": from_sender,
        # Entier et non chaîne, comme dans la documentation NGH.
        "to": int(destination),
        "text": text,
        # Entier lui aussi. L'ancienne référence (`sms-<timestamp flottant>`)
        # était une chaîne, que la documentation ne prévoit pas.
        "reference": int(datetime.utcnow().timestamp() * 1000),
        "api_key": api_key,
        "api_secret": api_secret,
    }

    try:
        response = httpx.post(
            NGH_SEND_SMS_URL,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=15,
        )
    except Exception:
        logger.exception("[SMS] Passerelle NGH injoignable pour %s", destination)
        return False

    if response.status_code >= 400:
        logger.error(
            "[SMS] NGH a répondu HTTP %s pour %s : %s",
            response.status_code,
            destination,
            response.text[:300],
        )
        return False

    # Le verdict est DANS le corps. On reste tolérant sur la forme : si la
    # réponse n'est pas du JSON attendu, on ne transforme pas une passerelle
    # qui marche en panne — on le signale, et on s'en tient au code HTTP.
    try:
        body = response.json()
    except Exception:
        logger.warning(
            "[SMS] Réponse NGH illisible pour %s (HTTP %s) : %s",
            destination,
            response.status_code,
            response.text[:300],
        )
        return True

    gateway_status = body.get("status") if isinstance(body, dict) else None
    if gateway_status is None:
        logger.warning("[SMS] Réponse NGH sans champ `status` pour %s : %s", destination, body)
        return True

    try:
        accepted = int(gateway_status) == 200
    except (TypeError, ValueError):
        logger.warning("[SMS] Statut NGH illisible pour %s : %r", destination, gateway_status)
        return True

    if not accepted:
        logger.error(
            "[SMS] NGH a refusé le message pour %s — status=%s, status_desc=%s (expéditeur %r)",
            destination,
            gateway_status,
            body.get("status_desc"),
            from_sender,
        )
        return False

    logger.info(
        "[SMS] Accepté par NGH pour %s — messageid=%s, crédits restants=%s",
        destination,
        body.get("messageid"),
        body.get("credits"),
    )
    return True
