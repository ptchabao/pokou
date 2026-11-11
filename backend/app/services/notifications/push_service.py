"""Pokou — notifications push (Firebase Cloud Messaging).

Best-effort, jamais bloquant : un push raté ou FCM non configuré ne doit
jamais faire échouer l'envoi d'un message/appel (voir routes/messages.py et
routes/calls.py, qui appellent send_push après coup, sans vérifier son
retour). Suit le même compromis "désactivé par défaut, dégrade proprement"
que livekit_service.py — ici sans lever d'exception, puisque le push est un
supplément au WebSocket et non une action demandée explicitement par
l'utilisateur.
"""
import logging
import json
import os
from datetime import datetime
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import DeviceToken

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_init_failed = False


def _get_firebase_app():
    global _firebase_app, _firebase_init_failed
    if _firebase_app is not None or _firebase_init_failed:
        return _firebase_app

    settings = get_settings()
    if not settings.fcm_enabled:
        return None
    # L'UNE des deux sources suffit. Ce garde exigeait le CHEMIN, alors que
    # le corps ci-dessous préfère le JSON quand il est là : quiconque
    # configurait FCM avec le seul `FIREBASE_CREDENTIALS_JSON` — la voie la
    # plus simple sur Dokploy, où l'injection d'un fichier secret est
    # capricieuse — voyait la fonction rendre None ici, sans qu'aucune ligne
    # de journal ne mentionne la raison. Le diagnostic, lui, se plaignait
    # d'un chemin vide, ce qui envoyait chercher au mauvais endroit.
    if not settings.firebase_credentials_path and not settings.firebase_credentials_json.strip():
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        configured_path = settings.firebase_credentials_path
        credential_path = configured_path
        credential_data = settings.firebase_credentials_json.strip()
        if credential_data:
            cred = credentials.Certificate(json.loads(credential_data))
            logger.info("[Push] Credentials Firebase chargées depuis le secret JSON")
        else:
            if not os.path.isfile(credential_path):
                fallback_path = "/run/secrets/firebase-service-account.json"
                if os.path.isfile(fallback_path):
                    credential_path = fallback_path
                    logger.info(
                        "[Push] Ancien chemin Firebase '%s' remplacé par '%s'",
                        configured_path,
                        fallback_path,
                    )
            cred = credentials.Certificate(credential_path)
        _firebase_app = firebase_admin.initialize_app(cred)
    except Exception as exc:
        logger.warning("[Push] Initialisation Firebase impossible: %s", exc)
        _firebase_init_failed = True
        return None

    return _firebase_app


def push_status_message() -> str:
    """Diagnostic lisible au démarrage — send_push() échoue en silence par
    design (voir docstring du module), donc sans ça une désactivation ou
    une mauvaise config FCM ne laisse absolument aucune trace dans les
    logs : les messages/appels app fermée cessent juste d'arriver, sans
    erreur nulle part à chercher."""
    settings = get_settings()
    if not settings.fcm_enabled:
        return "désactivé (FCM_ENABLED=false) — aucune notification/sonnerie app fermée ne sera envoyée"
    if not settings.firebase_credentials_path and not settings.firebase_credentials_json:
        return "FCM_ENABLED=true mais credentials Firebase manquants — désactivé de fait"
    # La SOURCE est nommée dans les deux issues : un diagnostic qui parle
    # d'un chemin alors que l'exploitant a fourni un JSON l'envoie chercher
    # au mauvais endroit — c'est exactement ce qui est arrivé.
    source = (
        "le secret JSON (FIREBASE_CREDENTIALS_JSON)"
        if settings.firebase_credentials_json.strip()
        else f"le fichier '{settings.firebase_credentials_path}'"
    )
    if _get_firebase_app() is None:
        return (
            f"FCM_ENABLED=true mais l'initialisation Firebase a échoué depuis "
            f"{source} — voir le warning [Push] ci-dessus"
        )
    return f"activé et initialisé depuis {source}"


def register_device_token(
    db: Session,
    user_id: int,
    token: str,
    platform: str = "android",
    session_jti: Optional[str] = None,
    rich_message_push: bool = False,
) -> None:
    """`session_jti` rattache l'appareil à la session qui l'enregistre.

    C'est ce qui permet à « Appareils connectés » de DÉCONNECTER un appareil
    et pas seulement de le rendre silencieux. Il est réécrit à chaque
    enregistrement : l'application republie son jeton à chaque démarrage,
    donc après une reconnexion le lien pointe bien sur la session en cours et
    non sur une session périmée.
    """
    token = token.strip()
    if not token:
        raise ValueError("FCM token vide")
    existing = db.query(DeviceToken).filter(DeviceToken.token == token).first()
    if existing:
        existing.user_id = user_id
        existing.platform = platform
        existing.rich_message_push = rich_message_push
        if session_jti:
            existing.session_jti = session_jti
        existing.updated_at = datetime.utcnow()
    else:
        db.add(DeviceToken(
            user_id=user_id,
            token=token,
            platform=platform,
            session_jti=session_jti,
            rich_message_push=rich_message_push,
        ))
    db.commit()
    logger.info("[Push] Jeton FCM enregistré pour l'utilisateur %s (%s)", user_id, platform)


def send_push(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    silent: bool = False,
    rich_data: Optional[Dict[str, str]] = None,
) -> None:
    """Envoie une notification à tous les appareils enregistrés de
    l'utilisateur. N'importe quel échec (FCM non configuré, jeton invalide,
    erreur réseau) est journalisé et avalé — voir docstring du module.

    `silent=True` omet le champ `notification` (payload data-only) : pour un
    appel entrant, Android ne doit PAS auto-afficher une notification par
    défaut (sans action, sans sonnerie plein écran) quand l'app est
    fermée — c'est le handler d'arrière-plan côté client
    (firebaseMessagingBackgroundHandler dans push_service.dart) qui doit
    construire lui-même la vraie UI d'appel entrant à partir de `data`.
    Un payload combiné notification+data afficherait les DEUX (le système
    ET notre propre notification), d'où l'exclusion mutuelle ici."""
    app = _get_firebase_app()
    if app is None:
        return

    tokens: List[DeviceToken] = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    if not tokens:
        logger.info("[Push] Aucun jeton FCM pour l'utilisateur %s", user_id)
        return

    try:
        from firebase_admin import messaging
    except Exception as exc:
        logger.warning("[Push] Module firebase_admin.messaging indisponible: %s", exc)
        return

    # ── iOS a besoin qu'on le lui dise explicitement ─────────────────────
    #
    # Android livre un message data-only à l'application même endormie, du
    # moment que la priorité est haute. APNs, non : sans `content-available`,
    # un message SANS bloc `notification` n'est tout simplement pas remis à
    # une application en arrière-plan ou fermée.
    #
    # Comme les appels partent justement en data-only (`silent=True`, pour
    # qu'Android n'affiche pas SA notification par-dessus la nôtre), l'oubli
    # de ce réglage aurait un effet simple : **aucun appel entrant
    # n'arriverait jamais sur iPhone**, sans la moindre erreur nulle part.
    #
    # `apns-priority: 10` va avec : un message silencieux est livré en
    # priorité 5 par défaut, c'est-à-dire « quand ça arrange le système ».
    # Pour une sonnerie, ça ne va pas.
    apns_silencieux = messaging.APNSConfig(
        headers={"apns-priority": "10", "apns-push-type": "background"},
        payload=messaging.APNSPayload(
            aps=messaging.Aps(content_available=True),
        ),
    )

    def _message(t: DeviceToken) -> "messaging.Message":
        # `rich_data` : l'appareil construit lui-même sa notification (groupée
        # par conversation, contenu récupéré par lui) — un push de données,
        # que le système n'affiche pas. Les versions antérieures gardent le
        # push « notification » qu'elles savent afficher.
        riche = rich_data is not None and bool(getattr(t, "rich_message_push", False))
        silencieux = silent or riche
        return messaging.Message(
            notification=None if silencieux else messaging.Notification(title=title, body=body),
            data=_firebase_safe_data({**(data or {}), **(rich_data or {})} if riche else (data or {})),
            token=t.token,
            android=messaging.AndroidConfig(priority="high"),
            apns=apns_silencieux if silencieux else None,
        )

    messages = [_message(t) for t in tokens]

    try:
        response = messaging.send_each(messages, app=app)
    except Exception as exc:
        logger.warning("[Push] Échec d'envoi pour l'utilisateur %s: %s", user_id, exc)
        return

    logger.info(
        "[Push] Envoi utilisateur %s: %s succès, %s échecs",
        user_id,
        response.success_count,
        response.failure_count,
    )

    for token_row, result in zip(tokens, response.responses):
        if result.success:
            continue
        if _token_is_dead(result.exception):
            logger.info("[Push] Jeton invalide pour l'utilisateur %s (%s) — suppression", user_id, result.exception)
            db.delete(token_row)
        else:
            # Erreur passagère (quota, Firebase indisponible, délai) : le
            # jeton reste. Le supprimer laissait le téléphone sans aucune
            # notification jusqu'au prochain démarrage de l'application.
            logger.warning("[Push] Échec passager pour l'utilisateur %s (%s) — jeton conservé", user_id, result.exception)
    db.commit()


#: Les seules réponses de Firebase qui disent que le jeton ne servira plus :
#: application désinstallée, jeton expiré, ou jeton d'un autre projet.
_DEAD_TOKEN_CODES = frozenset({
    "UNREGISTERED", "SENDER_ID_MISMATCH",
    "registration-token-not-registered", "invalid-registration-token", "mismatched-credential",
})


def _token_is_dead(exc) -> bool:
    if exc is None:
        return False
    from firebase_admin import messaging as fcm

    if isinstance(exc, (fcm.UnregisteredError, fcm.SenderIdMismatchError)):
        return True
    # INVALID_ARGUMENT vise parfois le MESSAGE (contenu trop gros), pas le
    # jeton : mort seulement si Firebase parle du jeton.
    if "registration token" in str(exc).lower():
        return True
    code = str(getattr(exc, "code", "") or "")
    cause = getattr(exc, "cause", None)
    details = f"{code} {exc} {cause or ''}"
    return any(marker in details for marker in _DEAD_TOKEN_CODES)


#: Clés que Firebase réserve dans `data` : une seule suffit à faire refuser la
#: notification entière (« Invalid data payload key »). C'est ainsi que TOUTES
#: les notifications de message échouaient, avec `message_type`.
_FIREBASE_RESERVED_KEYS = {"from": "from_user", "message_type": "msg_type", "notification": "notif"}


def _firebase_safe_data(data):
    """Renomme les clés réservées, retire les préfixes interdits."""
    if not data:
        return data
    safe = {}
    for key, value in data.items():
        if key.startswith(("google.", "gcm.")):
            continue
        new_key = _FIREBASE_RESERVED_KEYS.get(key, key)
        if new_key != key and new_key in data:
            continue  # la version sûre est déjà là
        safe[new_key] = value
    return safe
