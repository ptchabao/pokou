"""Sauvegarde chiffrée (MSG-12) : métadonnées et pointeur vers le bloc."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import MediaAsset, UserBackup

router = APIRouter(prefix="/backup", tags=["Sauvegarde"])


class BackupBody(BaseModel):
    media_id: int
    salt: str = Field(..., min_length=16, max_length=64)
    iterations: int = Field(..., ge=50_000, le=2_000_000)
    discussions: int = Field(0, ge=0)
    messages: int = Field(0, ge=0)
    size_bytes: int = Field(0, ge=0)


def _json(b: UserBackup) -> dict:
    return {
        "exists": True,
        "media_id": b.media_asset_id,
        "salt": b.salt,
        "iterations": b.iterations,
        "discussions": b.discussions,
        "messages": b.messages,
        "size_bytes": b.size_bytes,
        "created_at": b.created_at.isoformat(),
    }


@router.get("")
def get_backup(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    backup = db.get(UserBackup, current_user["user_id"])
    if backup is None or backup.media_asset_id is None:
        return {"exists": False}
    return _json(backup)


@router.put("")
def put_backup(
    body: BackupBody,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    me = current_user["user_id"]
    asset = db.get(MediaAsset, body.media_id)
    # Seulement un bloc déposé par soi-même : sinon on pointerait sa
    # sauvegarde sur le fichier de quelqu'un d'autre.
    if asset is None or asset.uploader_id != me:
        raise HTTPException(status_code=403, detail="Fichier de sauvegarde introuvable")
    backup = db.get(UserBackup, me)
    if backup is None:
        backup = UserBackup(user_id=me)
        db.add(backup)
    backup.media_asset_id = asset.id
    backup.salt = body.salt
    backup.iterations = body.iterations
    backup.discussions = body.discussions
    backup.messages = body.messages
    backup.size_bytes = body.size_bytes or (asset.size_bytes or 0)
    backup.created_at = datetime.utcnow()
    db.commit()
    return _json(backup)


@router.delete("")
def delete_backup(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    backup = db.get(UserBackup, current_user["user_id"])
    if backup is not None:
        db.delete(backup)
        db.commit()
    return {"exists": False}
