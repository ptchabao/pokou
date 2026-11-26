"""Garde-fous de démarrage : refusent de lancer la production avec une
configuration dangereuse, et préviennent bruyamment ailleurs."""
import logging
import re

logger = logging.getLogger(__name__)


def ensure_no_weak_secrets(settings) -> None:
    """Refuse to boot in production with a known-public default secret —
    an unchanged secret_key lets anyone forge JWTs, an unchanged
    webhook_hmac_secret lets anyone forge webhook signatures (see
    core/config.py WEAK_DEFAULT_*). In non-production environments this only
    warns loudly, since local dev commonly runs without a customized .env."""
    from app.core.config import WEAK_DEFAULT_SECRET_KEY, WEAK_DEFAULT_WEBHOOK_HMAC_SECRET

    weak = []
    if settings.secret_key == WEAK_DEFAULT_SECRET_KEY:
        weak.append("SECRET_KEY")
    if settings.webhook_hmac_secret == WEAK_DEFAULT_WEBHOOK_HMAC_SECRET:
        weak.append("WEBHOOK_HMAC_SECRET")

    if not weak:
        return

    message = (
        f"{', '.join(weak)} still set to its known default value — "
        "anyone can forge tokens/signatures with it. Set a strong value in .env."
    )
    if settings.environment == "production":
        raise RuntimeError(f"Refusing to start in production: {message}")
    logger.warning("INSECURE CONFIG: %s", message)


def ensure_no_review_backdoor(settings) -> None:
    """Valide la configuration de l'OTP de revue des stores."""
    leftovers = [
        name
        for name, value in (
            ("REVIEW_PHONE_NUMBERS", settings.review_phone_numbers),
            ("REVIEW_OTP_CODE", settings.review_otp_code),
        )
        if (value or "").strip()
    ]
    production_enabled = getattr(settings, "review_otp_production_enabled", False)
    if not leftovers and not production_enabled:
        return

    if bool(settings.review_phone_numbers) != bool(settings.review_otp_code):
        raise RuntimeError(
            "REVIEW_PHONE_NUMBERS et REVIEW_OTP_CODE doivent être configurés ensemble."
        )

    if settings.environment != "production":
        if leftovers:
            logger.warning(
                "REVIEW_PHONE_NUMBERS and REVIEW_OTP_CODE are configured outside production; "
                "remove them after the review."
            )
        return

    if not leftovers:
        raise RuntimeError(
            "REVIEW_OTP_PRODUCTION_ENABLED ne peut pas être activé sans "
            "REVIEW_PHONE_NUMBERS et REVIEW_OTP_CODE."
        )
    if not production_enabled:
        raise RuntimeError(
            "La configuration OTP de revue en production exige "
            "REVIEW_OTP_PRODUCTION_ENABLED=true."
        )

    numbers = [part.strip() for part in settings.review_phone_numbers.split(",") if part.strip()]
    if len(numbers) != 1 or not re.fullmatch(r"\+[1-9]\d{6,14}", numbers[0]):
        raise RuntimeError(
            "La revue en production exige un unique numéro REVIEW_PHONE_NUMBERS au format E.164."
        )
    if not re.fullmatch(r"\d{6}", settings.review_otp_code):
        raise RuntimeError("REVIEW_OTP_CODE doit contenir exactement six chiffres.")

    logger.warning(
        "Store-review OTP is enabled in production for one dedicated account. "
        "Disable REVIEW_OTP_PRODUCTION_ENABLED after the review."
    )
