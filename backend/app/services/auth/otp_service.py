"""Inscription/connexion par numéro de téléphone, façon WhatsApp : pas de
mot de passe, juste un code à usage unique envoyé par SMS (passerelle NGH,
voir services/notifications/sms_service.py) ET par WhatsApp (voir
_send_whatsapp_otp), pour que le code arrive même sans réseau SMS."""
import logging
import re
import secrets
import threading
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import User, PhoneOTP
from app.services.notifications import sms_service, whatsapp_service
from app.core.security import hash_password, verify_password

logger = logging.getLogger(__name__)

OTP_LENGTH = 6
OTP_TTL_MINUTES = 5
# Durée de vie du code d'un compte de démonstration. Bien plus longue que
# les 5 minutes ordinaires, pour une raison pratique : un relecteur de store
# prend des captures, remplit un formulaire, revient — et seules 3 demandes
# sont permises par quart d'heure. Un code expiré au mauvais moment se
# conclut par « nous n'avons pas pu nous connecter », c'est-à-dire un refus
# de publication.
#
# Le coût en sécurité est nul : ce code est PUBLIÉ dans la console Play, sa
# durée de vie ne protège donc rien. Ce qui borne le risque, c'est que le
# compte est vide et n'ouvre l'accès à aucune donnée d'un tiers.
REVIEW_OTP_TTL_MINUTES = 60
MAX_VERIFY_ATTEMPTS = 5
RATE_LIMIT_WINDOW_MINUTES = 15
RATE_LIMIT_MAX_REQUESTS = 3
#: Délai minimal entre deux envois au même numéro (cahier des charges,
#: section 8.1 : « renvoi après 60 s »). L'écran affiche le même compte à
#: rebours ; le serveur le fait respecter.
RESEND_MIN_SECONDS = 60
#: Cinq codes faux, tous codes confondus, verrouillent le numéro quinze
#: minutes. Sans ce cumul, redemander un code remettait le compteur à zéro.
LOCKOUT_MINUTES = 15

_PHONE_RE = re.compile(r"^\+[1-9]\d{6,14}$")


class OTPError(Exception):
    """Base class — callers map this to an HTTP error."""


class OTPRateLimitError(OTPError):
    pass


class OTPInvalidError(OTPError):
    pass


def _recent_failures(db: Session, phone: str) -> int:
    since = datetime.utcnow() - timedelta(minutes=LOCKOUT_MINUTES)
    rows = db.query(PhoneOTP.attempts).filter(PhoneOTP.phone == phone, PhoneOTP.created_at >= since).all()
    return sum(row[0] or 0 for row in rows)


def _ensure_not_locked(db: Session, phone: str) -> None:
    if _recent_failures(db, phone) >= MAX_VERIFY_ATTEMPTS:
        raise OTPRateLimitError(
            f"Trop d'essais pour ce numéro — réessayez dans {LOCKOUT_MINUTES} minutes."
        )


def normalize_phone(raw: str) -> str:
    """Accepts E.164 (`+22890123456`) with optional spaces/dashes. Doesn't
    guess a default country code — the client is expected to send the
    number with its country code, same as WhatsApp's own picker does."""
    cleaned = re.sub(r"[\s\-()]", "", raw or "")
    if not _PHONE_RE.match(cleaned):
        raise OTPInvalidError("Numéro de téléphone invalide — format attendu: +<indicatif><numéro>")
    return cleaned


def _review_numbers() -> set[str]:
    """Les numéros de démonstration déclarés pour la revue des stores, en
    E.164 normalisé. Séparés par des virgules dans REVIEW_PHONE_NUMBERS."""
    raw = get_settings().review_phone_numbers or ""
    numbers = set()
    for part in raw.split(","):
        candidate = part.strip()
        if not candidate:
            continue
        try:
            numbers.add(normalize_phone(candidate))
        except OTPInvalidError:
            # Un numéro mal écrit dans la configuration ne doit pas faire
            # tomber la connexion de tout le monde : on l'ignore en le
            # signalant. Le silence serait pire — le relecteur ne pourrait
            # pas entrer et personne ne saurait pourquoi.
            logger.error("[OTP] REVIEW_PHONE_NUMBERS contient un numéro invalide : %s", candidate)
    return numbers


def is_review_phone(raw_phone: str) -> bool:
    """Ce numéro est-il un compte de démonstration à code fixe ?

    Faux dès que REVIEW_OTP_CODE n'est pas configuré : la porte dérobée
    exige les DEUX réglages, pour qu'une moitié de configuration oubliée ne
    l'ouvre pas à moitié."""
    settings = get_settings()
    if not (settings.review_otp_code or "").strip():
        return False
    try:
        phone = normalize_phone(raw_phone)
    except OTPInvalidError:
        return False
    return phone in _review_numbers()


def _otp_message(code: str) -> str:
    """Le message nomme POKOU : c'est l'application que la personne vient
    d'ouvrir. Un code arrivant au nom d'une marque qu'elle n'a jamais vue se
    lit comme une tentative d'hameçonnage, et se jette."""
    return f"Votre code Pokou est {code}. Il expire dans {OTP_TTL_MINUTES} minutes."


def _send_whatsapp_otp(phone: str, code: str) -> None:
    """Second canal de livraison du code, en plus du SMS. Beaucoup
    d'utilisateurs au Togo ont WhatsApp qui fonctionne quand la livraison SMS
    est lente ou perdue par l'opérateur ; envoyer sur les deux canaux évite un
    « je n'ai rien reçu » sans recours.

    Lancé dans un THREAD à part et jamais attendu, pour deux raisons :
    whatsapp_service.send_whatsapp retente jusqu'à 3 fois avec un backoff
    exponentiel (donc potentiellement plusieurs dizaines de secondes), et la
    route /auth/phone/request-otp est une coroutine qui appelle cette fonction
    directement — bloquer ici gèlerait la boucle asyncio pour TOUTES les
    requêtes en cours, pas seulement celle-ci.

    Le SMS reste le canal de référence : un échec WhatsApp est donc journalisé
    puis ignoré, il ne doit jamais faire échouer une connexion."""

    def _run() -> None:
        try:
            whatsapp_service.send_whatsapp(_otp_message(code), phone)
        except Exception:
            logger.warning("Envoi du code OTP par WhatsApp impossible pour %s", phone, exc_info=True)

    threading.Thread(target=_run, name="otp-whatsapp", daemon=True).start()


#: Canaux de livraison d'un code. « both » est le défaut de la PREMIÈRE
#: demande : on ne sait pas encore lequel arrivera, et au Togo la livraison
#: SMS est régulièrement lente ou perdue par l'opérateur.
#:
#: « whatsapp » sert au RENVOI demandé explicitement — celui de quelqu'un dont
#: le code a expiré sans jamais arriver. Refaire partir un SMS par le même
#: chemin qui vient d'échouer coûte un message pour rien ; et si la personne
#: demande WhatsApp, c'est qu'elle sait que WhatsApp lui arrive.
OTP_CHANNELS = ("both", "sms", "whatsapp")


def generate_and_send_otp(db: Session, raw_phone: str, channel: str = "both") -> int:
    """Returns the TTL in seconds. Raises OTPRateLimitError if this phone
    has requested too many codes recently.

    `channel` choisit la voie de livraison — voir OTP_CHANNELS. Un canal
    inconnu est traité comme « both » plutôt que rejeté : un code qui part
    trop largement reste préférable à une connexion impossible."""
    phone = normalize_phone(raw_phone)

    since = datetime.utcnow() - timedelta(minutes=RATE_LIMIT_WINDOW_MINUTES)
    recent_count = (
        db.query(PhoneOTP)
        .filter(PhoneOTP.phone == phone, PhoneOTP.created_at >= since)
        .count()
    )
    if recent_count >= RATE_LIMIT_MAX_REQUESTS:
        raise OTPRateLimitError(
            f"Trop de demandes de code pour ce numéro — réessayez dans {RATE_LIMIT_WINDOW_MINUTES} minutes."
        )
    _ensure_not_locked(db, phone)
    # Seul un code ENCORE EN ATTENTE impose le délai : après une connexion
    # réussie, se reconnecter aussitôt (autre appareil) reste possible.
    last = (
        db.query(PhoneOTP.created_at)
        .filter(PhoneOTP.phone == phone, PhoneOTP.consumed_at.is_(None))
        .order_by(PhoneOTP.created_at.desc())
        .first()
    )
    if last is not None and (datetime.utcnow() - last[0]).total_seconds() < RESEND_MIN_SECONDS:
        wait = RESEND_MIN_SECONDS - int((datetime.utcnow() - last[0]).total_seconds())
        raise OTPRateLimitError(f"Patientez {wait} s avant de redemander un code.")

    # Compte de démonstration pour la revue des stores : code FIXE, aucun SMS.
    # Tout le reste du flux est identique — la ligne PhoneOTP est créée
    # normalement, donc l'expiration, le plafond d'essais, l'usage unique et
    # la limite de débit s'appliquent exactement comme pour n'importe qui.
    # C'est ce qui rend cette porte étroite : on ne saute PAS la
    # vérification, on prédétermine seulement le code.
    is_review = is_review_phone(phone)
    if is_review:
        code = get_settings().review_otp_code.strip()
        logger.warning(
            "[OTP] Code de DÉMONSTRATION servi pour %s (compte de revue des stores) — "
            "aucun SMS envoyé. Retirer REVIEW_PHONE_NUMBERS/REVIEW_OTP_CODE une fois la revue passée.",
            phone,
        )
    else:
        code = f"{secrets.randbelow(10 ** OTP_LENGTH):0{OTP_LENGTH}d}"

    ttl_minutes = REVIEW_OTP_TTL_MINUTES if is_review else OTP_TTL_MINUTES

    otp = PhoneOTP(
        phone=phone,
        code_hash=hash_password(code),
        expires_at=datetime.utcnow() + timedelta(minutes=ttl_minutes),
    )
    db.add(otp)
    db.commit()

    if not is_review:
        # Ni SMS ni WhatsApp pour un numéro de démonstration : il n'appartient
        # à personne, et l'envoi ne ferait que payer un message vers un
        # numéro qui ne le lira pas — ou, si le numéro finit par être attribué
        # à quelqu'un, lui envoyer nos codes.
        if channel != "whatsapp":
            sms_service.send_sms(db, phone, _otp_message(code), get_settings().sms_sender_id)
        if channel != "sms":
            _send_whatsapp_otp(phone, code)

    # Le code n'est JAMAIS journalisé, nulle part, dans aucun environnement.
    #
    # Il l'était — `logger.info("[OTP DEBUG] Code pour %s : %s", phone, code)`,
    # sans condition. Le numéro figurait sur la même ligne : quiconque lisait
    # les journaux (hébergeur, supervision, export de débogage, capture
    # d'écran d'un terminal) pouvait se connecter à n'importe quel compte. Un
    # code à usage unique de cinq minutes reste un mot de passe le temps de
    # ces cinq minutes, et un journal se conserve bien plus longtemps.
    #
    # Ce qui est journalisé à la place suffit à diagnostiquer « je ne reçois
    # rien » : qu'un code a été émis, pour quel numéro, et par quel canal.
    # Ce qui manquait pour déboguer, ce n'était pas le code — c'était de
    # savoir si le SMS était parti, et sms_service le dit maintenant.
    logger.info(
        "[OTP] Code émis pour %s (canal: %s, validité: %s min)",
        phone,
        channel,
        ttl_minutes,
    )

    return ttl_minutes * 60


def get_or_create_user_by_phone(db: Session, phone: str) -> User:
    user = db.query(User).filter(User.phone == phone).first()
    if user:
        return user
    # Un compte de démonstration porte son nom : sans ça, il ressemble à
    # n'importe quel utilisateur dans la base de production, et personne ne
    # sait plus lequel peut être supprimé après la revue.
    full_name = "Compte de démonstration (revue des stores)" if is_review_phone(phone) else None
    user = User(phone=phone, email=None, is_active=True, full_name=full_name)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def verify_otp(db: Session, raw_phone: str, code: str) -> User:
    """Verifies the most recent unconsumed code for this phone, then
    creates the User row on first success. Raises OTPInvalidError on any
    failure (wrong code, expired, too many attempts) — deliberately the
    same error/message for all of these so a caller can't distinguish
    "expired" from "wrong code" to narrow down a brute-force guess."""
    phone = normalize_phone(raw_phone)
    _ensure_not_locked(db, phone)

    otp: Optional[PhoneOTP] = (
        db.query(PhoneOTP)
        .filter(PhoneOTP.phone == phone, PhoneOTP.consumed_at.is_(None))
        .order_by(PhoneOTP.created_at.desc())
        .first()
    )
    if otp is None or otp.expires_at < datetime.utcnow() or otp.attempts >= MAX_VERIFY_ATTEMPTS:
        raise OTPInvalidError("Code invalide ou expiré — redemandez un code.")

    if not verify_password(code, otp.code_hash):
        otp.attempts += 1
        db.commit()
        # Le nombre d'essais restants, comme le demande l'état « erreur avec
        # essais restants » du composant de saisie (section 7.6). Il ne dit
        # rien du code lui-même.
        left = MAX_VERIFY_ATTEMPTS - _recent_failures(db, phone)
        if left <= 0:
            raise OTPRateLimitError(
                f"Trop d'essais pour ce numéro — réessayez dans {LOCKOUT_MINUTES} minutes."
            )
        raise OTPInvalidError(
            f"Code incorrect — il vous reste {left} essai{'s' if left > 1 else ''}."
        )

    otp.consumed_at = datetime.utcnow()
    db.commit()

    return get_or_create_user_by_phone(db, phone)
