"""Pokou — canal temps réel (messages, statuts de livraison, invitations
d'appel). Aucune route REST ici, juste le WebSocket + le ConnectionManager
que les autres routers (messages.py, calls futurs) importent pour pousser
des événements aux utilisateurs connectés.

C'est aussi ici qu'est écrit le « vu à » (`User.last_seen_at`), aux seules
transitions de connexion : le registre de sockets est la seule chose qui
sache quand quelqu'un arrive et repart (voir app/routes/presence.py, qui
l'expose).

Limite connue : registre en mémoire, valable pour un seul processus API.
Passer à plusieurs instances nécessiterait un pub/sub (Redis, déjà une
dépendance configurée via `settings.redis_url`) pour que chaque instance
apprenne qu'un autre process détient la connexion d'un destinataire.
"""
import logging
from datetime import datetime
from typing import Any, Dict, Optional, Set

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import User
from app.services.messaging.sync_service import persist_delivered_event
from app.services.auth import ws_ticket_service
from app.services.messaging.ws_registry import registry
from app.core.security import verify_token, _reject_if_revoked, get_current_user
from fastapi import HTTPException

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Pokou realtime"])


class ConnectionManager:
    """Les sockets ouvertes SUR CETTE INSTANCE, et le registre partagé.

    Une socket est liée à son processus — ça, c'est inévitable. Le REGISTRE,
    lui, ne doit pas l'être : sans quoi un message envoyé depuis l'instance 1
    n'atteint pas un destinataire connecté à l'instance 2, et le repli par
    notification masque la panne. Voir services/ws_registry.py.
    """

    def __init__(self) -> None:
        self._connections: Dict[int, Set[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        self._connections.setdefault(user_id, set()).add(websocket)
        await registry.register(user_id)

    async def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)
            # Plus aucune socket ICI — mais l'utilisateur peut en avoir
            # ailleurs, et c'est le registre qui le sait.
            await registry.unregister(user_id)

    def is_connected_locally(self, user_id: int) -> bool:
        """Une socket ouverte sur CETTE instance."""
        return bool(self._connections.get(user_id))

    async def is_online(self, user_id: int) -> bool:
        """En ligne QUELQUE PART — la réponse qui décide d'un push.

        Se tromper coûte dans les deux sens : dire « non » à tort double la
        notification pour quelqu'un qui recevra aussi le message en temps
        réel, dire « oui » à tort la supprime pour quelqu'un qui ne verra
        rien.
        """
        return await registry.is_online(
            user_id, local=self.is_connected_locally(user_id)
        )

    async def deliver_local(self, user_id: int, event: Dict[str, Any]) -> bool:
        """Écrit sur les sockets de cette instance, et rien d'autre.

        C'est ce que le registre rappelle quand un évènement arrive d'une
        AUTRE instance. Ne republie rien : ce serait une boucle.
        """
        sockets = list(self._connections.get(user_id, ()))
        if not sockets:
            return False
        delivered = False
        for ws in sockets:
            try:
                await ws.send_json(event)
                delivered = True
            except Exception as exc:
                logger.warning("[WS] Échec d'envoi à l'utilisateur %s: %s", user_id, exc)
                await self.disconnect(user_id, ws)
        return delivered

    async def send_to_user(self, user_id: int, event: Dict[str, Any]) -> bool:
        """Envoie un évènement, où que soit le destinataire.

        Renvoie `True` si l'utilisateur est joignable en temps réel — c'est
        sur cette réponse que les appelants décident d'envoyer une
        notification push, ou de marquer un message comme remis.

        Livraison locale D'ABORD, publication ensuite : si le destinataire
        est ici, il reçoit sans attendre le tour de Redis. Et l'instance
        émettrice s'ignore à la réception, sinon il recevrait deux fois.
        """
        sync_event_id = event.get("sync_event_id")
        if sync_event_id is None:
            sync_event_id = persist_delivered_event(user_id, event)
        if sync_event_id is not None:
            event = {**event, "sync_event_id": str(sync_event_id)}

        delivered_here = await self.deliver_local(user_id, event)

        # Publication même quand la livraison locale a réussi : le même
        # utilisateur peut avoir un second appareil connecté ailleurs.
        await registry.publish(user_id, event)

        if delivered_here:
            return True
        # Pas de socket ici : le registre sait s'il y en a ailleurs. Sans
        # cette question, on enverrait un push à quelqu'un qui reçoit déjà
        # le message en temps réel sur une autre instance.
        return await registry.is_online(user_id, local=False)


manager = ConnectionManager()


def _touch_last_seen(db: Session, user_id: int) -> None:
    """Une écriture aux seules transitions de connexion (ouverture,
    fermeture), jamais dans la boucle de réception : celle-ci est le chemin
    le plus chaud de l'API, et un UPDATE par trame reçue ferait payer à la
    base le débit du temps réel pour une information dont la granularité
    utile est la minute. « En ligne » couvre de toute façon l'intervalle
    entre les deux écritures, `last_seen_at` ne sert qu'après le départ.

    Un « vu à » perdu ne doit jamais faire échouer la connexion elle-même :
    toute erreur est annulée et journalisée, pas propagée."""
    try:
        db.query(User).filter(User.id == user_id).update(
            {"last_seen_at": datetime.utcnow()}, synchronize_session=False
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.warning("[WS] « Vu à » non enregistré pour l'utilisateur %s: %s", user_id, exc)


@router.post("/ws/ticket")
async def create_ws_ticket(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Un laissez-passer de quelques secondes pour ouvrir le WebSocket.

    Authentifié par le mécanisme ordinaire — en-tête `Authorization`, sur
    une requête HTTP dont l'URL ne porte aucun secret. C'est tout l'objet de
    la manœuvre : le jeton reste dans un en-tête, que personne ne journalise,
    et c'est le ticket qui voyage dans l'URL de la socket.

    Voir services/ws_ticket_service.py pour ce que le ticket garantit.
    """
    ticket, expires_in = ws_ticket_service.issue(
        db,
        user_id=current_user["user_id"],
        jti=current_user.get("jti"),
    )
    return {"ticket": ticket, "expires_in": expires_in}


def _authenticate(token: Optional[str], db: Session) -> int:
    """OBSOLÈTE — authentification par jeton d'accès dans l'URL.

    Conservée pour les applications DÉJÀ INSTALLÉES, qui se connectent
    encore ainsi et cesseraient de recevoir leurs messages du jour au
    lendemain. À retirer une fois le parc renouvelé ; d'ici là, chaque usage
    est journalisé pour qu'on sache quand c'est devenu possible.
    """
    if not token:
        raise HTTPException(status_code=401, detail="Token manquant")
    payload = verify_token(token, "access")
    _reject_if_revoked(db, payload)
    user_id = payload.get("user_id")
    if user_id is None:
        raise HTTPException(status_code=401, detail="Token invalide")
    logger.warning(
        "[WS] Connexion par JETON dans l'URL (client ancien) — utilisateur %s",
        user_id,
    )
    return user_id


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    ticket: Optional[str] = Query(None),
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """Ouverture du canal temps réel.

    `ticket` est le chemin nominal : un laissez-passer à usage unique, valable
    quelques secondes, obtenu par POST /ws/ticket (dont l'URL, elle, ne porte
    rien). `token` est l'ancien chemin, gardé le temps que le parc
    d'applications installées se renouvelle — voir _authenticate.

    `db` passe par `Depends(get_db)` (et non `SessionLocal()` en direct)
    pour respecter les overrides de session utilisés par les tests — un
    appel direct à `SessionLocal()` ignorerait `app.dependency_overrides`
    et irait taper la vraie base de données même en test."""
    if ticket:
        user_id = ws_ticket_service.consume(db, ticket)
        if user_id is None:
            # Expiré, déjà utilisé, inconnu, ou session révoquée : une seule
            # réponse pour tous les cas. Les distinguer dirait à un attaquant
            # si un ticket a existé, et lequel vaut la peine d'être rejoué.
            await websocket.close(code=4401)
            return
    else:
        try:
            user_id = _authenticate(token, db)
        except HTTPException:
            await websocket.close(code=4401)
            return

    await websocket.accept()
    await manager.connect(user_id, websocket)
    _touch_last_seen(db, user_id)
    logger.info("[WS] Utilisateur %s connecté", user_id)

    try:
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.warning("[WS] Erreur pour l'utilisateur %s: %s", user_id, exc)
    finally:
        await manager.disconnect(user_id, websocket)
        # Après le retrait de la connexion : c'est cet instant que le « vu à »
        # doit désigner, et l'ordre garantit que plus personne ne verra
        # « en ligne » avec une date d'activité antérieure à la fermeture.
        _touch_last_seen(db, user_id)
        logger.info("[WS] Utilisateur %s déconnecté", user_id)
