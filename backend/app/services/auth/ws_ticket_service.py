"""Le laissez-passer d'ouverture du WebSocket.

Pourquoi il existe : le jeton d'accès voyageait dans l'URL
(`/api/v1/ws?token=eyJ...`). Une URL se retrouve dans le journal d'accès du
serveur, chez le reverse proxy, dans les traces de supervision, dans les
historiques. Quiconque en lisait une pouvait rejouer la session jusqu'à
l'expiration du jeton, soit trente minutes. Le filtre de rédaction coupait la
fuite vers NOS journaux ; il ne pouvait rien pour ceux des autres.

Ce qu'un ticket change : même s'il fuit, il ne vaut que quelques secondes, il
a probablement déjà été consommé, et il n'ouvre qu'une socket — pas l'API.

Six propriétés, et chacune ferme une attaque précise :

1. **tiré de `secrets.token_urlsafe`** — un générateur cryptographique. Avec
   `random`, la graine se devine depuis l'heure d'émission ;
2. **très court** (30 s) — le client demande puis se connecte
   immédiatement ; tout ce qui dépasse est du temps offert à un attaquant ;
3. **usage unique**, consommé par une écriture ATOMIQUE — deux ouvertures
   simultanées avec le même ticket ne peuvent pas réussir toutes les deux ;
4. **lié à l'utilisateur** — un ticket volé n'ouvre pas la socket de
   quelqu'un d'autre ;
5. **lié à la session** (`jti`) — révoquer un appareil depuis « Appareils
   connectés » invalide les tickets déjà émis par cette session, qui
   survivraient sinon à la révocation ;
6. **stocké en empreinte** — un export de base ne livre pas de quoi se
   connecter, et aucun journal ne peut restituer le ticket.
"""
import hashlib
import logging
import secrets
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Token, WSTicket

logger = logging.getLogger(__name__)

#: Assez pour aller de la réponse HTTP à la poignée de main WebSocket, même
#: sur un réseau lent. Pas assez pour qu'un ticket trouvé dans un journal
#: serve encore à quoi que ce soit.
TICKET_TTL = timedelta(seconds=30)

#: 32 octets d'entropie. `token_urlsafe(32)` rend 43 caractères.
TICKET_BYTES = 32


def _digest(ticket: str) -> str:
    return hashlib.sha256(ticket.encode("utf-8")).hexdigest()


def issue(db: Session, *, user_id: int, jti: Optional[str]) -> tuple[str, int]:
    """Émet un ticket. Renvoie (ticket en clair, durée de vie en secondes).

    Le ticket en clair n'existe QUE dans cette valeur de retour et dans la
    réponse HTTP : il n'est ni journalisé ni stocké.
    """
    ticket = secrets.token_urlsafe(TICKET_BYTES)
    db.add(
        WSTicket(
            ticket_hash=_digest(ticket),
            user_id=user_id,
            jti=jti,
            expires_at=datetime.utcnow() + TICKET_TTL,
        )
    )
    db.commit()
    # L'identifiant de l'utilisateur, jamais le ticket. C'est tout l'objet de
    # la manœuvre : un journal ne doit pas permettre de le récupérer.
    logger.info("[WS] Ticket émis pour l'utilisateur %s", user_id)
    return ticket, int(TICKET_TTL.total_seconds())


def consume(db: Session, ticket: str) -> Optional[int]:
    """Consomme un ticket et renvoie l'identifiant de son propriétaire, ou
    `None` s'il est invalide, expiré, déjà utilisé, ou issu d'une session
    révoquée.

    La consommation est une écriture conditionnelle en UN ordre SQL : c'est
    ce qui rend l'usage unique réel. Lire puis écrire laisserait deux
    ouvertures simultanées passer toutes les deux — une course improbable à
    la main, triviale à provoquer avec un script.
    """
    now = datetime.utcnow()
    updated = (
        db.query(WSTicket)
        .filter(
            WSTicket.ticket_hash == _digest(ticket),
            WSTicket.consumed_at.is_(None),
            WSTicket.expires_at > now,
        )
        .update({"consumed_at": now}, synchronize_session=False)
    )
    db.commit()
    if updated != 1:
        return None

    row = (
        db.query(WSTicket)
        .filter(WSTicket.ticket_hash == _digest(ticket))
        .first()
    )
    if row is None:
        return None

    # La session qui a émis ce ticket est-elle toujours valable ? Sans ce
    # contrôle, révoquer un appareil laisserait ses tickets déjà émis ouvrir
    # une socket — la révocation serait donc incomplète pendant trente
    # secondes, ce qui suffit largement.
    if row.jti:
        session_row = db.query(Token).filter(Token.jti == row.jti).first()
        if session_row is None or session_row.revoked_at is not None:
            logger.info(
                "[WS] Ticket refusé : session révoquée (utilisateur %s)", row.user_id
            )
            return None

    return row.user_id


def purge_expired(db: Session) -> int:
    """Supprime les tickets périmés. Sans ça la table grandit indéfiniment,
    d'une ligne par ouverture de socket — c'est-à-dire beaucoup."""
    removed = (
        db.query(WSTicket)
        .filter(WSTicket.expires_at < datetime.utcnow() - timedelta(hours=1))
        .delete(synchronize_session=False)
    )
    db.commit()
    return removed
