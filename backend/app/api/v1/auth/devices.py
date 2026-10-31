"""Pokou — appareils connectés : enregistrement des jetons FCM (notifications
push app fermée), inventaire et révocation depuis Profil > Appareils connectés.

Un « appareil » ici, c'est un jeton FCM, rattaché à la SESSION qui l'a
enregistré (`session_jti`). Le révoquer coupe donc ses notifications ET
déconnecte sa session — accès immédiatement refusé, et rafraîchissement
impossible, puisque /auth/refresh vérifie la révocation lui aussi.

Ce n'était pas le cas : la route se contentait de supprimer la ligne. Un
appareil révoqué perdait ses notifications et gardait tout le reste — lire,
écrire, renouveler sa session pendant sept jours. Quelqu'un qui révoquait un
téléphone perdu croyait avoir fermé la porte."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import DeviceToken, Token
from app.services.notifications.push_service import register_device_token
from app.core.security import get_current_user

router = APIRouter(prefix="/devices", tags=["Pokou push"])


class DeviceTokenRegister(BaseModel):
    token: str
    platform: str = "android"
    # Ce que l'application sait faire de ses pushs. `rich_message_push` :
    # elle construit elle-même les notifications de message.
    capabilities: list[str] = []


@router.post("/register")
async def register_device(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    try:
        register_device_token(
            db,
            current_user["user_id"],
            payload.token,
            payload.platform,
            session_jti=current_user.get("jti"),
            rich_message_push="rich_message_push" in payload.capabilities,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"ok": True}


def _serialize_device(device: DeviceToken, current_token: str | None) -> dict:
    return {
        "id": device.id,
        "platform": device.platform,
        "registered_at": device.created_at.isoformat(),
        "last_seen_at": device.updated_at.isoformat(),
        # Le jeton complet est un secret d'envoi : on n'en renvoie qu'une
        # empreinte, suffisante pour distinguer deux appareils à l'œil.
        "token_hint": device.token[-6:] if len(device.token) > 6 else device.token,
        "is_current": current_token is not None and device.token == current_token,
    }


@router.get("")
async def list_devices(
    current_token: str | None = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """`current_token` : le jeton FCM de l'appareil qui interroge, pour qu'il
    puisse se reconnaître dans la liste (comparaison côté serveur — le client
    n'a jamais besoin de voir les jetons des autres appareils)."""
    devices = (
        db.query(DeviceToken)
        .filter(DeviceToken.user_id == current_user["user_id"])
        .order_by(DeviceToken.updated_at.desc())
        .all()
    )
    return {"items": [_serialize_device(device, current_token) for device in devices]}


@router.delete("/{device_id}")
async def revoke_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    device = db.query(DeviceToken).filter(
        DeviceToken.id == device_id, DeviceToken.user_id == current_user["user_id"]
    ).first()
    if not device:
        # 404 et non 403 pour un appareil d'un autre compte : ne pas révéler
        # qu'un id existe ailleurs.
        raise HTTPException(status_code=404, detail="Appareil introuvable")
    # Révoquer un appareil, c'est le DÉCONNECTER — pas seulement le rendre
    # silencieux.
    #
    # Cette route ne supprimait que le jeton de notification. L'appareil
    # perdait ses notifications et gardait tout le reste : lire les
    # conversations, envoyer des messages, rafraîchir sa session pendant sept
    # jours. Quelqu'un qui révoque un téléphone perdu croyait avoir fermé la
    # porte.
    revoked_session = False
    if device.session_jti:
        revoked_session = bool(
            db.query(Token)
            .filter(
                Token.jti == device.session_jti,
                Token.user_id == current_user["user_id"],
                Token.revoked_at.is_(None),
            )
            .update({"revoked_at": datetime.utcnow()}, synchronize_session=False)
        )

    db.delete(device)
    db.commit()
    # `session_revoked` à faux signale un appareil enregistré AVANT que le
    # lien de session existe : ses notifications s'arrêtent, mais sa session
    # ne peut pas être retrouvée. Le dire plutôt que de le taire — l'écran
    # peut alors conseiller de changer de code.
    return {"revoked": True, "session_revoked": revoked_session}
