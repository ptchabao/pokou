"""Garde-fous de démarrage : refusent de lancer la production avec une
configuration dangereuse, et préviennent bruyamment ailleurs."""
import logging

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
    """Refuse de démarrer en production avec la porte dérobée de revue des
    stores encore ouverte.

    REVIEW_PHONE_NUMBERS + REVIEW_OTP_CODE donnent un code de connexion FIXE,
    valable une heure, sur des numéros déclarés. C'est indispensable pour
    faire publier l'application — un relecteur doit pouvoir entrer — et ça
    n'a plus rien à faire là une fois la revue passée. Or rien ne le
    rappelait : la porte se refermait par mémoire, ce qui veut dire jamais.

    Les deux réglages sont exigés ensemble par `is_review_phone`, donc il
    suffit qu'UN des deux traîne pour que la porte soit close. On refuse
    quand même dès qu'il y en a un : une configuration à moitié oubliée est
    le meilleur moyen de rouvrir la porte au prochain déploiement sans que
    personne ne s'en rende compte.
    """
    leftovers = [
        name
        for name, value in (
            ("REVIEW_PHONE_NUMBERS", settings.review_phone_numbers),
            ("REVIEW_OTP_CODE", settings.review_otp_code),
        )
        if (value or "").strip()
    ]
    if not leftovers:
        return

    message = (
        f"{', '.join(leftovers)} encore renseigné — la porte dérobée de revue "
        "des stores donne un code de connexion fixe. À vider une fois la revue "
        "passée."
    )
    if settings.environment == "production":
        raise RuntimeError(f"Refusing to start in production: {message}")
    logger.warning("INSECURE CONFIG: %s", message)
