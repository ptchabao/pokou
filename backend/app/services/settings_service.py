from datetime import datetime
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models import SystemSetting

SMS_GATEWAY_KEYS = [
    "ngh_api_key",
    "ngh_api_secret",
    "semoa_webhook_secret",
    "semoa_login",
    "semoa_api_key",
    "semoa_api_reference",
    "semoa_gateway_id",
]


def get_setting(db: Session, key: str) -> Optional[str]:
    setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    return setting.value if setting else None


def set_setting(db: Session, key: str, value: str, updated_by_admin_id: Optional[int] = None) -> None:
    setting = db.query(SystemSetting).filter(SystemSetting.key == key).first()
    if setting:
        setting.value = value
        setting.updated_at = datetime.utcnow()
        setting.updated_by_admin_id = updated_by_admin_id
    else:
        setting = SystemSetting(key=key, value=value, updated_by_admin_id=updated_by_admin_id)
        db.add(setting)
    db.commit()


def _mask(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    if len(value) <= 4:
        return "****"
    return f"{'*' * (len(value) - 4)}{value[-4:]}"


def get_sms_gateway_settings_masked(db: Session) -> dict[str, Any]:
    ngh_key = get_setting(db, "ngh_api_key")
    ngh_secret = get_setting(db, "ngh_api_secret")
    webhook_secret = get_setting(db, "semoa_webhook_secret")
    semoa_login = get_setting(db, "semoa_login")
    semoa_api_key = get_setting(db, "semoa_api_key")
    semoa_api_reference = get_setting(db, "semoa_api_reference")
    semoa_gateway_id = get_setting(db, "semoa_gateway_id")
    return {
        "ngh_api_key": _mask(ngh_key),
        "ngh_api_key_configured": bool(ngh_key),
        "ngh_api_secret": _mask(ngh_secret),
        "ngh_api_secret_configured": bool(ngh_secret),
        "semoa_webhook_secret": _mask(webhook_secret),
        "semoa_webhook_secret_configured": bool(webhook_secret),
        # Identifiants "Cashpay Auth" pour authentifier NOS appels SORTANTS
        # vers Semoa (signature sha256(login+api_key+salt) par requête, voir
        # app/services/semoa_client.py) — distincts de semoa_webhook_secret
        # ci-dessus, qui vérifie seulement les appels ENTRANTS de Semoa vers
        # nous. semoa_gateway_id sélectionne la passerelle Mobile Money
        # (voir GET /gateways côté Semoa) utilisée pour créer une commande.
        "semoa_login": _mask(semoa_login),
        "semoa_login_configured": bool(semoa_login),
        "semoa_api_key": _mask(semoa_api_key),
        "semoa_api_key_configured": bool(semoa_api_key),
        "semoa_api_reference": _mask(semoa_api_reference),
        "semoa_api_reference_configured": bool(semoa_api_reference),
        "semoa_gateway_id": _mask(semoa_gateway_id),
        "semoa_gateway_id_configured": bool(semoa_gateway_id),
    }


def update_sms_gateway_settings(db: Session, payload: dict, admin_id: Optional[int]) -> dict[str, Any]:
    for key in SMS_GATEWAY_KEYS:
        if payload.get(key):
            set_setting(db, key, str(payload[key]), updated_by_admin_id=admin_id)
    return get_sms_gateway_settings_masked(db)
