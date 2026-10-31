"""Pokou — stickers : packs, favoris, récents, recherche, suggestions.

Voir services/sticker_service.py pour ce que chaque notion recouvre et
pourquoi favoris et récents sont deux choses distinctes.
"""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models import StickerPack
from app.services.media import sticker_service
from app.core.security import get_current_user

router = APIRouter(prefix="/stickers", tags=["Pokou stickers"])


class PackCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=64)


class StickerCreate(BaseModel):
    media_asset_id: int
    #: Les emojis qui déclencheront la suggestion de ce sticker.
    emoji_tags: str = Field("", max_length=128)
    keywords: str = Field("", max_length=255)


class ReorderRequest(BaseModel):
    pack_ids: List[int]


class SaveReceived(BaseModel):
    media_asset_id: int


@router.get("")
async def my_packs(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les packs de l'utilisateur, dans SON ordre, avec leurs stickers.

    Tout en une réponse : le panneau les affiche ensemble, et une requête
    par pack ferait autant d'allers-retours que de vignettes à dessiner.
    """
    return {"items": sticker_service.installed_packs(db, current_user["user_id"])}


@router.post("/save")
async def save_received(
    payload: SaveReceived,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Garde dans SES stickers celui qu'on vient de recevoir.

    Deux verrous, et ils ne font pas la même chose :

    1. **Le droit de VOIR ce média**, emprunté à `GET /media/{id}` plutôt
       que réécrit ici. C'est la règle qui sait déjà qu'un sticker de pack
       public est visible de tous, et qu'un sticker de pack personnel ne
       l'est que par le message qui le porte. La recopier aurait fait une
       sixième version d'une règle qui en a déjà trop.
    2. **Le fait que ce soit un sticker**, vérifié par le service. Sans
       ça, cette route rangerait n'importe quelle photo reçue dans les
       stickers de n'importe qui.
    """
    from app.models import MediaAsset
    from app.api.v1.media.media import _can_access

    user_id = current_user["user_id"]
    asset = (
        db.query(MediaAsset)
        .filter(MediaAsset.id == payload.media_asset_id)
        .first()
    )
    # 404 et non 403 : ne pas révéler qu'un identifiant existe ailleurs.
    if asset is None or not _can_access(db, asset, user_id):
        raise HTTPException(status_code=404, detail="Sticker introuvable")

    try:
        sticker = sticker_service.save_received(db, user_id, asset.id)
    except sticker_service.StickerNotReachable as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except sticker_service.StickerLimitReached as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if sticker is None:
        raise HTTPException(status_code=400, detail="Sticker non enregistré")
    return sticker_service.serialize_sticker(sticker)


@router.get("/recents")
async def my_recents(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return {"items": sticker_service.recents(db, current_user["user_id"])}


@router.get("/favorites")
async def my_favorites(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return {"items": sticker_service.favorites(db, current_user["user_id"])}


@router.post("/{sticker_id}/favorite")
async def toggle_favorite(
    sticker_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Bascule : la même route ajoute et retire.

    Deux routes obligeraient le client à savoir l'état courant avant
    d'agir, et donc à se tromper dès qu'il est périmé."""
    est_favori = sticker_service.toggle_favorite(
        db, current_user["user_id"], sticker_id
    )
    return {"favorite": est_favori}


@router.post("/{sticker_id}/used")
async def mark_used(
    sticker_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Note l'usage — appelé à l'ENVOI, pour alimenter les récents."""
    sticker_service.mark_used(db, current_user["user_id"], sticker_id)
    return {"ok": True}


@router.get("/search")
async def search(
    q: str = Query(..., min_length=1, max_length=64),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Cherche dans les mots-clés, les noms de packs ET les emojis.

    Une seule route pour les trois : séparer obligerait l'interface à
    deviner laquelle appeler selon ce qui est tapé."""
    return {
        "items": sticker_service.search(db, current_user["user_id"], q)
    }


@router.get("/suggest")
async def suggest(
    emoji: str = Query(..., min_length=1, max_length=16),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les stickers à proposer quand quelqu'un vient de taper cet emoji.

    Bornée aux packs qu'il POSSÈDE : proposer un sticker qu'il ne peut pas
    envoyer serait une invitation à un échec."""
    return {
        "items": sticker_service.suggest_for_emoji(
            db, current_user["user_id"], emoji
        )
    }


@router.get("/store")
async def store(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les packs disponibles — officiels et publics."""
    user_id = current_user["user_id"]
    installes = {
        p["id"] for p in sticker_service.installed_packs(db, user_id) if p["installed"]
    }
    packs = (
        db.query(StickerPack)
        .options(joinedload(StickerPack.stickers))
        .filter(
            (StickerPack.owner_user_id.is_(None)) | (StickerPack.is_public.is_(True))
        )
        .all()
    )
    return {
        "items": [
            sticker_service.serialize_pack(
                p, installed=p.id in installes, with_stickers=False
            )
            for p in packs
        ]
    }


@router.post("/packs/{pack_id}/install")
async def install(
    pack_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    if not sticker_service.install(db, current_user["user_id"], pack_id):
        raise HTTPException(status_code=404, detail="Pack introuvable")
    return {"installed": True}


@router.delete("/packs/{pack_id}/install")
async def uninstall(
    pack_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Retire le pack de SA liste — le pack lui-même n'est pas touché,
    d'autres l'ont peut-être installé."""
    sticker_service.uninstall(db, current_user["user_id"], pack_id)
    return {"installed": False}


@router.put("/packs/order")
async def reorder(
    payload: ReorderRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sticker_service.reorder(db, current_user["user_id"], payload.pack_ids)
    return {"ok": True}


@router.post("/packs")
async def create_pack(
    payload: PackCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée un pack personnel — celui où atterrissent les stickers faits
    depuis une photo."""
    pack = sticker_service.create_personal_pack(
        db, current_user["user_id"], payload.name
    )
    if pack is None:
        raise HTTPException(status_code=400, detail="Nom invalide")
    return sticker_service.serialize_pack(pack)


@router.post("/packs/{pack_id}/stickers")
async def add_sticker(
    pack_id: int,
    payload: StickerCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ajoute une image à un pack personnel.

    Le média doit appartenir à celui qui l'ajoute — sans ce contrôle, on
    pourrait fabriquer un sticker depuis la photo de quelqu'un d'autre en
    devinant un identifiant."""
    try:
        sticker = sticker_service.add_to_personal_pack(
            db,
            current_user["user_id"],
            pack_id,
            payload.media_asset_id,
            payload.emoji_tags,
            payload.keywords,
        )
    except sticker_service.StickerLimitReached as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if sticker is None:
        raise HTTPException(status_code=404, detail="Pack ou image introuvable")
    return sticker_service.serialize_sticker(sticker)


@router.delete("/packs/{pack_id}")
async def delete_pack(
    pack_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    if not sticker_service.delete_personal_pack(db, current_user["user_id"], pack_id):
        raise HTTPException(status_code=404, detail="Pack introuvable")
    return {"deleted": True}
