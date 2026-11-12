"""Twilio Verify : Twilio génère, envoie et vérifie le code de connexion.

Pourquoi Verify plutôt qu'un SMS ordinaire (sms_service) : Twilio y gère la
livraison de bout en bout — choix de l'expéditeur par pays, numéros
pré-enregistrés là où l'opérateur l'exige (Togo, Côte d'Ivoire…), relance
sur une autre route si la première échoue, et protection contre la fraude
aux SMS surtaxés. Le code n'est plus jamais connu de Pokou : il ne peut donc
fuir ni par la base ni par les journaux.

Ce qui reste à Pokou : la limite de débit, le délai entre deux envois, le
verrouillage après cinq erreurs (otp_service). Chaque demande garde sa ligne
`PhoneOTP`, marquée comme « confiée à Verify ».

Le service Verify se règle par `TWILIO_VERIFY_SERVICE_SID`. Laissé vide, il
est retrouvé (ou créé, au nom de « Pokou ») au premier code envoyé, puis
mémorisé dans les réglages système : il suffit des identifiants du compte.

Tout appel à Twilio est borné à 15 s et ne lève jamais vers l'appelant : un
échec renvoie `False`, et otp_service retombe sur son propre code envoyé par
SMS ordinaire.
"""
import logging
import re
from typing import Optional

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services import settings_service

logger = logging.getLogger(__name__)

VERIFY_BASE = "https://verify.twilio.com/v2"
FRIENDLY_NAME = "Pokou"
_SETTING_KEY = "twilio_verify_service_sid"
#: Durée de validité d'un code Verify (réglage par défaut des services
#: Twilio). La ligne PhoneOTP vit aussi longtemps.
CODE_TTL_SECONDS = 600

_cached_sid: Optional[str] = None


def configured() -> bool:
    s = get_settings()
    return bool(s.twilio_verify_enabled and s.twilio_account_sid and s.twilio_auth_token)


def _auth():
    s = get_settings()
    return (s.twilio_account_sid, s.twilio_auth_token)


def _e164(phone: str) -> str:
    return "+" + re.sub(r"\D", "", phone or "")


def service_sid(db: Session) -> Optional[str]:
    """Le service Verify à utiliser : la configuration, sinon celui déjà
    retrouvé, sinon celui du compte nommé « Pokou », sinon un nouveau."""
    global _cached_sid
    configured_sid = (get_settings().twilio_verify_service_sid or "").strip()
    if configured_sid:
        return configured_sid
    if _cached_sid:
        return _cached_sid
    stored = settings_service.get_setting(db, _SETTING_KEY)
    if stored:
        _cached_sid = stored
        return stored
    try:
        listing = httpx.get(f"{VERIFY_BASE}/Services", params={"PageSize": 50}, auth=_auth(), timeout=15)
        listing.raise_for_status()
        for service in listing.json().get("services", []):
            if service.get("friendly_name") == FRIENDLY_NAME:
                _cached_sid = service["sid"]
                break
        if not _cached_sid:
            created = httpx.post(
                f"{VERIFY_BASE}/Services",
                data={"FriendlyName": FRIENDLY_NAME, "CodeLength": "6"},
                auth=_auth(),
                timeout=15,
            )
            created.raise_for_status()
            _cached_sid = created.json()["sid"]
            logger.info("[Verify] Service Twilio Verify « %s » créé : %s", FRIENDLY_NAME, _cached_sid)
    except Exception as exc:  # noqa: BLE001
        logger.error("[Verify] Service Verify introuvable et non créé : %s", _describe(exc))
        return None
    settings_service.set_setting(db, _SETTING_KEY, _cached_sid)
    db.commit()
    return _cached_sid


def _describe(exc: Exception) -> str:
    if isinstance(exc, httpx.HTTPStatusError):
        try:
            body = exc.response.json()
        except Exception:
            body = {}
        return f"HTTP {exc.response.status_code}, code={body.get('code')}, message={body.get('message')}"
    return f"{type(exc).__name__}: {exc}"


def start(db: Session, phone: str, channel: str = "sms", locale: str = "fr") -> bool:
    """Demande à Twilio d'envoyer un code. `True` si Twilio l'a accepté."""
    sid = service_sid(db)
    if not sid:
        return False
    try:
        response = httpx.post(
            f"{VERIFY_BASE}/Services/{sid}/Verifications",
            data={"To": _e164(phone), "Channel": channel, "Locale": locale},
            auth=_auth(),
            timeout=15,
        )
        response.raise_for_status()
    except Exception as exc:  # noqa: BLE001
        logger.error("[Verify] Envoi refusé pour %s (canal %s) — %s", _e164(phone), channel, _describe(exc))
        return False
    logger.info("[Verify] Code envoyé par Twilio Verify à %s (canal %s)", _e164(phone), channel)
    return True


def check(db: Session, phone: str, code: str) -> Optional[bool]:
    """`True` : code bon. `False` : code faux, expiré ou déjà utilisé.
    `None` : Twilio injoignable — on ne peut rien conclure."""
    sid = service_sid(db)
    if not sid:
        return None
    try:
        response = httpx.post(
            f"{VERIFY_BASE}/Services/{sid}/VerificationCheck",
            data={"To": _e164(phone), "Code": code},
            auth=_auth(),
            timeout=15,
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("[Verify] Vérification impossible pour %s — %s", _e164(phone), _describe(exc))
        return None
    # 404 : plus de vérification en attente (expirée, déjà approuvée, ou
    # trop d'essais côté Twilio) — un code faux, pour l'utilisateur.
    if response.status_code == 404:
        return False
    if response.status_code >= 400:
        try:
            body = response.json()
        except Exception:
            body = {}
        # 60202 : trop d'essais ; 20404 : introuvable. Les deux valent « faux ».
        if body.get("code") in (60202, 20404):
            return False
        logger.error(
            "[Verify] Vérification refusée pour %s — HTTP %s, code=%s, message=%s",
            _e164(phone), response.status_code, body.get("code"), body.get("message"),
        )
        return None
    return response.json().get("status") == "approved"
