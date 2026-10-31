"""Pokou Business — l'API des bots, appelée par le serveur du développeur.

Authentification par clé de bot : `Authorization: Bearer vb_live_…` (ou
l'en-tête `X-API-Key`). La clé désigne UN bot, et son mode : `vb_test_`
n'écrit qu'aux numéros de test et ne facture rien, `vb_live_` écrit en
production et facture au message (voir services/pokou_business/billing.py).

Codes d'erreur, documentés dans le portail :
- 401 clé absente, inconnue ou révoquée ;
- 402 crédit insuffisant (prépayé) ou plafond atteint (postpayé) ;
- 403 destinataire injoignable (pas de consentement, bac à sable, blocage,
  entreprise suspendue) ;
- 404 destinataire ou média introuvable ;
- 422 contenu invalide ;
- 429 trop de requêtes.
"""
from __future__ import annotations

import time
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Optional

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import MediaAsset, MessageType, User
from app.models.business import Bot, BotApiKey, BusinessOrganization
from app.api.v1.messaging.messages import _deliver as deliver_direct_message
from app.api.v1.messaging.messages import _serialize as serialize_direct_message
from app.services.media import media_storage
from app.services.business import billing, keys, messaging

router = APIRouter(prefix="/bot/v1", tags=["pokou-bots-api"])

#: Requêtes par minute et par clé. Compté par processus : c'est un garde-fou
#: contre la boucle folle d'un développeur, pas une protection anti-DoS.
RATE_LIMIT_PER_MINUTE = 600
_fenetres: dict[int, deque] = defaultdict(deque)


@dataclass
class ContexteBot:
    key: BotApiKey
    bot: Bot
    org: BusinessOrganization

    @property
    def mode(self) -> str:
        return self.key.mode


def _limiter(key_id: int) -> None:
    maintenant = time.monotonic()
    fenetre = _fenetres[key_id]
    while fenetre and maintenant - fenetre[0] > 60:
        fenetre.popleft()
    if len(fenetre) >= RATE_LIMIT_PER_MINUTE:
        raise HTTPException(status_code=429, detail="Trop de requêtes — 600 par minute et par clé")
    fenetre.append(maintenant)


def bot_courant(
    authorization: Optional[str] = Header(None),
    x_api_key: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> ContexteBot:
    brute = x_api_key
    if not brute and authorization and authorization.lower().startswith("bearer "):
        brute = authorization[7:].strip()
    cle = keys.retrouver(db, brute or "")
    if cle is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Clé de bot absente, inconnue ou révoquée",
            headers={"WWW-Authenticate": "Bearer"},
        )
    bot = db.query(Bot).filter(Bot.id == cle.bot_id).first()
    org = db.query(BusinessOrganization).filter(BusinessOrganization.id == bot.organization_id).first() if bot else None
    if bot is None or org is None:
        raise HTTPException(status_code=401, detail="Clé de bot inconnue")
    _limiter(cle.id)
    db.commit()  # last_used_at
    return ContexteBot(key=cle, bot=bot, org=org)


class BotButton(BaseModel):
    id: str = Field(..., min_length=1, max_length=messaging.MAX_BUTTON_ID)
    title: str = Field(..., min_length=1, max_length=messaging.MAX_BUTTON_TITLE)


class BotMessageCreate(BaseModel):
    to: int = Field(..., description="Identifiant Pokou du destinataire, reçu dans le webhook message.received")
    text: Optional[str] = Field(None, max_length=messaging.MAX_TEXT)
    buttons: Optional[list[BotButton]] = Field(None, max_length=messaging.MAX_BUTTONS)
    media_id: Optional[int] = Field(None, description="Image téléversée via POST /bot/v1/media")


@router.get("/me")
async def bot_me(ctx: ContexteBot = Depends(bot_courant)):
    """Le bot de cette clé, son mode et ce que son entreprise peut faire."""
    return {
        "bot": {
            "id": ctx.bot.id,
            "user_id": ctx.bot.user_id,
            "handle": ctx.bot.handle,
            "name": ctx.bot.name,
            "is_active": ctx.bot.is_active,
        },
        "mode": ctx.mode,
        "organization": {
            "id": ctx.org.id,
            "name": ctx.org.name,
            "status": ctx.org.status,
            "billing_mode": ctx.org.billing_mode,
        },
    }


@router.post("/messages", status_code=status.HTTP_201_CREATED)
async def bot_send_message(
    payload: BotMessageCreate,
    ctx: ContexteBot = Depends(bot_courant),
    db: Session = Depends(get_db),
):
    """Envoie un message — facturé AVANT de partir, et seulement s'il part.

    Le débit, le message et la ligne de consommation sont écrits dans la
    même transaction : un refus à n'importe quelle étape n'en laisse rien.
    """
    recipient = db.query(User).filter(User.id == payload.to).first()
    try:
        messaging.verifier_destinataire(db, org=ctx.org, bot=ctx.bot, mode=ctx.mode, recipient=recipient)
        message = messaging.construire_message(
            db,
            bot=ctx.bot,
            recipient=recipient,
            text=payload.text,
            buttons=[b.model_dump() for b in payload.buttons] if payload.buttons else None,
            media_id=payload.media_id,
        )
        facture = billing.facturer_message(
            db, org=ctx.org, bot=ctx.bot, recipient_id=recipient.id, mode=ctx.mode
        )
        db.add(message)
        db.flush()
        facture.usage.message_id = message.id
        db.commit()
    except messaging.EnvoiRefuse as exc:
        db.rollback()
        code = 404 if str(exc) == "Destinataire introuvable" else 403
        raise HTTPException(status_code=code, detail=str(exc)) from exc
    except messaging.MessageInvalide as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except billing.CreditInsuffisant as exc:
        db.rollback()
        raise HTTPException(status_code=402, detail=str(exc)) from exc

    db.refresh(message)
    await deliver_direct_message(db, message)
    return {
        "id": message.id,
        "to": recipient.id,
        "category": facture.category,
        "price": facture.unit_price,
        "currency": "XOF",
        "mode": ctx.mode,
        "message": serialize_direct_message(message, ctx.bot.user_id),
    }


@router.post("/media", status_code=status.HTTP_201_CREATED)
async def bot_upload_media(
    file: UploadFile = File(...),
    ctx: ContexteBot = Depends(bot_courant),
    db: Session = Depends(get_db),
):
    """Téléverse une image, à joindre ensuite par `media_id`."""
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(status_code=422, detail="Seules les images sont acceptées pour l'instant")
    try:
        asset = await media_storage.save_upload(db, ctx.bot.user_id, file, MessageType.IMAGE)
    except media_storage.MediaStorageUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except media_storage.MediaError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {"id": asset.id, "mime_type": asset.mime_type, "size_bytes": asset.size_bytes}


@router.get("/media/{media_id}")
async def bot_download_media(
    media_id: int,
    ctx: ContexteBot = Depends(bot_courant),
    db: Session = Depends(get_db),
):
    """Télécharge un média qu'un utilisateur a envoyé au bot — et seulement
    ceux-là : le contrôle d'accès est celui de la messagerie, appliqué au
    compte du bot."""
    from app.api.v1.media.media import _can_access

    asset = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
    if not asset or not _can_access(db, asset, ctx.bot.user_id):
        raise HTTPException(status_code=404, detail="Fichier introuvable")
    if media_storage.uses_object_storage(asset):
        try:
            chunks, _ = media_storage.open_stream(asset)
        except media_storage.MediaStorageUnavailableError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        return StreamingResponse(chunks, media_type=asset.mime_type)
    path = media_storage.resolve_path(asset)
    if not path:
        raise HTTPException(status_code=404, detail="Fichier introuvable")
    return FileResponse(path, media_type=asset.mime_type)
