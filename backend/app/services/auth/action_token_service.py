"""Les laissez-passer que porte une notification push.

Pourquoi ils existent : la couche native doit pouvoir accepter ou refuser un
appel depuis l'écran verrouillé, sans que Flutter démarre. Le jeton de
session, lui, vit dans `FlutterSecureStorage` — côté Dart. Plutôt que de le
recopier dans un stockage natif, le serveur met dans le push un
laissez-passer de portée étroite, que le natif rend tel quel.

Voir `docs/native-call-layer.md` §3 et §4.

── Six propriétés, et chacune ferme une attaque ──────────────────────────

1. tiré par `secrets` — un générateur cryptographique ;
2. **portée étroite** : un jeton n'autorise QU'UNE action, sur UNE cible,
   pour UN destinataire. Il n'ouvre rien d'autre de l'API ;
3. **courte durée** — la durée de sonnerie pour un appel, un jour pour une
   réponse à un message, qu'une notification peut garder longtemps ;
4. **usage unique**, consommé par une écriture ATOMIQUE. C'est aussi ce qui
   rend les actions idempotentes : un double appui ne produit pas deux
   effets ;
5. **stocké en empreinte** — un export de base ne doit pas livrer de quoi
   répondre à la place de quelqu'un ;
6. **lié à la session émettrice** : révoquer un appareil invalide les jetons
   qu'il a en attente.
"""
import hashlib
import logging
import secrets
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.models import ActionToken, Token

logger = logging.getLogger(__name__)

#: Les portées reconnues. Une portée inconnue est refusée — on n'invente pas
#: de droit à la volée.
SCOPE_CALL_ACCEPT = "call_accept"
SCOPE_CALL_DECLINE = "call_decline"
SCOPE_MESSAGE_REPLY = "message_reply"
SCOPES = {SCOPE_CALL_ACCEPT, SCOPE_CALL_DECLINE, SCOPE_MESSAGE_REPLY}

#: La durée de sonnerie, et pas davantage : un jeton d'appel qui survivrait à
#: l'appel lui-même n'aurait plus rien à autoriser.
CALL_TTL = timedelta(seconds=60)

#: Une notification de message reste affichée tant qu'on ne l'a pas touchée.
#: Répondre le lendemain matin est un usage normal.
REPLY_TTL = timedelta(hours=24)

TOKEN_BYTES = 32


def _digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue(
    db: Session,
    *,
    scope: str,
    user_id: int,
    room: Optional[str] = None,
    peer_user_id: Optional[int] = None,
    jti: Optional[str] = None,
    ttl: Optional[timedelta] = None,
) -> str:
    """Émet un jeton et renvoie sa forme EN CLAIR.

    Le clair n'existe que dans cette valeur de retour et dans le payload du
    push : il n'est ni journalisé ni stocké.
    """
    if scope not in SCOPES:
        raise ValueError(f"Portée inconnue : {scope}")

    token = secrets.token_urlsafe(TOKEN_BYTES)
    duration = ttl or (REPLY_TTL if scope == SCOPE_MESSAGE_REPLY else CALL_TTL)
    db.add(
        ActionToken(
            token_hash=_digest(token),
            scope=scope,
            user_id=user_id,
            room=room,
            peer_user_id=peer_user_id,
            jti=jti,
            expires_at=datetime.utcnow() + duration,
        )
    )
    db.commit()
    # La portée et le destinataire, jamais le jeton.
    logger.info("[Action] Jeton %s émis pour l'utilisateur %s", scope, user_id)
    return token


def issue_call_pair(
    db: Session, *, user_id: int, room: str, jti: Optional[str] = None
) -> dict[str, str]:
    """Les deux jetons d'un appel entrant : accepter, et refuser.

    DEUX et non un seul partagé. Un jeton unique valable pour les deux
    actions serait consommé par la première, et la seconde renverrait « déjà
    fait » — ce qui, après un « Répondre » suivi d'un « Refuser », dirait à
    l'utilisateur que son refus a réussi alors qu'il a répondu.
    """
    return {
        "answer_token": issue(
            db, scope=SCOPE_CALL_ACCEPT, user_id=user_id, room=room, jti=jti
        ),
        "decline_token": issue(
            db, scope=SCOPE_CALL_DECLINE, user_id=user_id, room=room, jti=jti
        ),
    }


def consume(db: Session, token: str, *, expected_scope: str) -> Optional[ActionToken]:
    """Consomme un jeton et renvoie sa ligne, ou `None` s'il est invalide,
    périmé, déjà utilisé, de la mauvaise portée, ou issu d'une session
    révoquée.

    La consommation est une écriture conditionnelle en UN ordre SQL : c'est
    ce qui rend l'usage unique réel. Lire puis écrire laisserait deux
    délivrances simultanées de la même action passer toutes les deux — une
    course improbable à la main, banale quand c'est Android qui rejoue un
    intent.
    """
    if expected_scope not in SCOPES:
        return None

    now = datetime.utcnow()
    digest = _digest(token)
    updated = (
        db.query(ActionToken)
        .filter(
            ActionToken.token_hash == digest,
            ActionToken.scope == expected_scope,
            ActionToken.consumed_at.is_(None),
            ActionToken.expires_at > now,
        )
        .update({"consumed_at": now}, synchronize_session=False)
    )
    db.commit()
    if updated != 1:
        return None

    row = db.query(ActionToken).filter(ActionToken.token_hash == digest).first()
    if row is None:
        return None

    if row.jti:
        session_row = db.query(Token).filter(Token.jti == row.jti).first()
        if session_row is None or session_row.revoked_at is not None:
            logger.info(
                "[Action] Jeton refusé : session révoquée (utilisateur %s)",
                row.user_id,
            )
            return None

    return row


def was_consumed(db: Session, token: str, *, expected_scope: str) -> bool:
    """Ce jeton a-t-il DÉJÀ été consommé ?

    Sert à distinguer « jamais vu » de « déjà fait ». C'est cette distinction
    qui permet de répondre 200 avec l'état courant sur un double appui, au
    lieu d'une erreur : du point de vue de l'utilisateur, l'action a réussi,
    et un 4xx le pousserait à réessayer ou afficherait un échec mensonger.
    """
    row = (
        db.query(ActionToken)
        .filter(
            ActionToken.token_hash == _digest(token),
            ActionToken.scope == expected_scope,
        )
        .first()
    )
    return row is not None and row.consumed_at is not None


def purge_expired(db: Session) -> int:
    """Le ménage. La table grandit de deux lignes par appel entrant."""
    removed = (
        db.query(ActionToken)
        .filter(ActionToken.expires_at < datetime.utcnow() - timedelta(days=2))
        .delete(synchronize_session=False)
    )
    db.commit()
    return removed
