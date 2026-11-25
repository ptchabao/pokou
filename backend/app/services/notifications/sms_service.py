"""Envoi de SMS : par Twilio uniquement.

Seul usage dans Pokou : livrer les codes de connexion (voir
services/auth/otp_service.py).

- **Twilio** : identifiants dans l'environnement
  (`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, et `TWILIO_SMS_FROM` ou
  `TWILIO_MESSAGING_SERVICE_SID`), donc dans le `.env` en local et dans le
  Secret Kubernetes en production. Le code reste généré et vérifié par
  Pokou : Twilio ne fait que transporter le SMS, si bien que l'expiration,
  le plafond d'essais et le blocage restent les nôtres.
"""
import logging
import re
from datetime import datetime

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

TWILIO_MESSAGES_URL = "https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"


def twilio_configured() -> bool:
    s = get_settings()
    return bool(
        s.twilio_account_sid and s.twilio_auth_token
        and (s.twilio_sms_from or s.twilio_messaging_service_sid)
    )


def _send_via_twilio(to: str, text: str) -> bool:
    """Un SMS par l'API Messages de Twilio. Renvoie `True` si Twilio l'a
    accepté (HTTP 201). Le texte n'est jamais journalisé : il porte le code."""
    s = get_settings()
    destination = "+" + _gateway_msisdn(to)
    if destination == "+":
        logger.error("[SMS] Numéro inexploitable, envoi Twilio abandonné (reçu: %r)", to)
        return False
    data = {"To": destination, "Body": text}
    # Un service de messagerie choisit lui-même l'expéditeur selon le pays ;
    # sinon, le numéro ou l'identifiant alphanumérique déclaré.
    if s.twilio_messaging_service_sid:
        data["MessagingServiceSid"] = s.twilio_messaging_service_sid
    else:
        data["From"] = s.twilio_sms_from
    try:
        response = httpx.post(
            TWILIO_MESSAGES_URL.format(sid=s.twilio_account_sid),
            data=data,
            auth=(s.twilio_account_sid, s.twilio_auth_token),
            timeout=15,
        )
    except Exception:
        logger.exception("[SMS] Twilio injoignable pour %s", destination)
        return False
    if response.status_code >= 400:
        try:
            body = response.json()
        except Exception:
            body = {}
        logger.error(
            "[SMS] Twilio a refusé le message pour %s — HTTP %s, code=%s, message=%s",
            destination, response.status_code, body.get("code"), body.get("message"),
        )
        return False
    try:
        sid = response.json().get("sid")
    except Exception:
        sid = None
    logger.info("[SMS] Accepté par Twilio pour %s — sid=%s", destination, sid)
    return True


def send_sms(db: Session, to: str, text: str, from_sender: str) -> bool:
    """Le SMS part par Twilio, et seulement par lui : aucune autre passerelle."""
    if not twilio_configured():
        logger.error("[SMS] Twilio n'est pas configuré : SMS non envoyé à %s", _gateway_msisdn(to))
        return False
    return _send_via_twilio(to, text)


def _gateway_msisdn(number: str) -> str:
    """Le numéro en chiffres seuls, sans le « + »."""
    return re.sub(r"\D", "", number or "")
