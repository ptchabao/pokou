"""
Client Semoa (CashPay) partagé par les 3 flux de paiement Mobile Money du
repo — abonnements (subscription_service.py), recharges SMS
(sms_service.py), et achats ponctuels de ressources numériques
(digital_goods_service.py). Auparavant, les 3 appelaient `/orders`
directement sans authentification (401 constatés en prod) ET avec un
corps de requête incomplet (gateway_id/currency manquants, mandatory
côté Semoa) — les deux problèmes sont corrigés ici, à un seul endroit.

Mode d'authentification : "Cashpay Auth" (pas OAuth2) — chaque requête est
signée individuellement via 4 headers (login, apisecure, apireference,
salt), voir la documentation Semoa officielle, section "Access to API" /
"Authentication". apisecure = sha256(login + api_key + salt) ; le
api_key brut n'est jamais envoyé sur le réseau, seulement utilisé pour
calculer la signature localement. Pas de token à récupérer ni mettre en
cache — chaque appel se signe lui-même.
"""
import hashlib
import logging
import time
from typing import Any, Optional

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services import settings_service

logger = logging.getLogger(__name__)

SEMOA_BASE_URL = "https://api.semoa-payments.ovh/prod"


class SemoaAuthError(Exception):
    """Identifiants Semoa manquants — voir /management/settings/sms-gateway
    (login, api_key, apireference, gateway_id)."""


def _sign_request(login: str, api_key: str) -> tuple[str, str]:
    salt = str(int(time.time() * 1000))
    apisecure = hashlib.sha256(f"{login}{api_key}{salt}".encode()).hexdigest()
    return apisecure, salt


def build_callback_url(db: Session, webhook_path: str) -> Optional[str]:
    """URL de callback par-commande (voir Design §Contexte — callback_url
    est acceptable par requête chez Semoa) : chaque flux route vers son
    propre webhook (un chemin par type de paiement) sans dépendre
    d'une config statique côté tableau de bord Semoa. Le secret partagé
    voyage en paramètre de requête, vérifié par
    api/v1/payments/webhooks.py::_verify_webhook_secret.
    None si semoa_webhook_secret n'est pas configuré (callback_url est
    alors simplement omis de la requête, pas envoyé avec un secret vide)."""
    secret = settings_service.get_setting(db, "semoa_webhook_secret")
    if not secret:
        return None
    base = get_settings().public_api_url.rstrip("/")
    return f"{base}/api/v1/webhooks/{webhook_path}/semoa?secret={secret}"


def create_order(
    db: Session,
    amount: float,
    description: str,
    merchant_reference: str,
    client_phone: str,
    client_firstname: Optional[str] = None,
    client_lastname: Optional[str] = None,
    callback_url: Optional[str] = None,
) -> dict[str, Any]:
    """POST /orders (mode Cashpay Auth) — lève une exception sur tout échec
    (identifiants manquants, Semoa indisponible, ...) ; les 3 appelants
    catchent déjà largement autour de leur bloc Semoa et marquent la
    commande/recharge/paiement FAILED en conséquence, donc ce comportement
    ne change pas pour eux."""
    login = settings_service.get_setting(db, "semoa_login")
    api_key = settings_service.get_setting(db, "semoa_api_key")
    api_reference = settings_service.get_setting(db, "semoa_api_reference")
    gateway_id = settings_service.get_setting(db, "semoa_gateway_id")
    if not all([login, api_key, api_reference, gateway_id]):
        raise SemoaAuthError(
            "Identifiants Semoa non configurés — voir /management/settings/sms-gateway"
        )

    client: dict[str, Any] = {"phone": client_phone}
    if client_firstname:
        client["firstname"] = client_firstname
    if client_lastname:
        client["lastname"] = client_lastname

    payload: dict[str, Any] = {
        "gateway_id": int(gateway_id),
        "amount": amount,
        "currency": "XOF",
        "merchant_reference": merchant_reference,
        "description": description,
        "client": client,
    }
    if callback_url:
        payload["callback_url"] = callback_url

    apisecure, salt = _sign_request(login, api_key)
    response = httpx.post(
        f"{SEMOA_BASE_URL}/orders",
        json=payload,
        headers={
            "login": login,
            "apisecure": apisecure,
            "apireference": api_reference,
            "salt": salt,
            "Content-Type": "application/json",
        },
        timeout=15,
    )

    if response.status_code >= 400:
        raise Exception(f"Échec de la création de commande Semoa (HTTP {response.status_code})")

    body = response.json()
    # Le lien de paiement hébergé — vérifié en prod (2026-09-01) : la
    # passerelle Orabank/carte (DIRECT_URL) ne renvoie PAS `long_bill_url`
    # du tout, seulement `bill_url` ; d'autres passerelles (ex. PUSH_USSD)
    # peuvent renvoyer les deux. Normalisé ici une seule fois plutôt que
    # de dupliquer ce fallback dans les 3 appelants.
    body["payment_url"] = body.get("long_bill_url") or body.get("bill_url")
    return body
