"""Le carrousel de l'accueil : bannières par pays et région.

Deux routeurs :

- `/home/banners` — l'application : les bannières en cours pour la zone de
  la personne connectée (pays déduit de son numéro, région si on la connaît).
- `/admin/banners` — la console : créer, modifier, activer, supprimer.

Rien n'est codé dans l'application : une campagne commence et s'arrête ici.
"""
import unicodedata
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.countries import country_of_phone
from app.core.database import get_db
from app.core.permissions import require_permission
from app.core.security import get_current_user
from app.models import AuditLog, HomeBanner, MediaAsset, User

router = APIRouter(prefix="/home", tags=["Accueil"])
admin_router = APIRouter(prefix="/admin/banners", tags=["Administration"])

#: Au plus tant de bannières par personne : un carrousel, pas un catalogue.
MAX_BANNERS = 8


def _norm(value: Optional[str]) -> str:
    """« Lomé », « lome », « LOME » : la même région."""
    text = unicodedata.normalize("NFKD", (value or "").strip().lower())
    return "".join(ch for ch in text if not unicodedata.combining(ch))


def _known_regions(db: Session, user_id: int) -> set[str]:
    """Les villes que l'on connaît de cette personne.

    Le profil n'a pas de ville. On prend celles qu'elle a déjà données
    ailleurs — coursier, liste d'attente Honam, dossier Pokou certifié. Pour
    les autres, seules les bannières nationales s'affichent."""
    from app.models.certified import CertifiedProApplication
    from app.models.honam import CourierProfile, HonamWaitlistEntry

    cities: set[str] = set()
    for model in (CourierProfile, HonamWaitlistEntry, CertifiedProApplication):
        for (city,) in db.query(model.city).filter(model.user_id == user_id).all():
            if city:
                cities.add(_norm(city))
    return cities


def _media(asset: Optional[MediaAsset]) -> Optional[dict]:
    if asset is None:
        return None
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _public(banner: HomeBanner) -> dict:
    return {
        "id": banner.id,
        "label": banner.label,
        "title": banner.title,
        "body": banner.body,
        "image": _media(banner.image),
        "cta_label": banner.cta_label,
        "cta_url": banner.cta_url,
    }


def is_live(banner: HomeBanner, now: Optional[datetime] = None) -> bool:
    now = now or datetime.utcnow()
    return bool(
        banner.is_active
        and (banner.starts_at is None or banner.starts_at <= now)
        and (banner.ends_at is None or banner.ends_at > now)
    )


def is_banner_image(db: Session, media_id: int) -> bool:
    """L'image d'une bannière EN COURS est lisible par tout le monde — voir
    media.py::_can_access. Une bannière en préparation ou terminée ne l'est
    pas : l'image d'une campagne ne fuit pas avant son lancement."""
    return any(
        is_live(banner)
        for banner in db.query(HomeBanner).filter(HomeBanner.image_media_id == media_id).all()
    )


@router.get("/banners")
def my_banners(
    region: Optional[str] = Query(None, max_length=80, description="Ville ou région connue de l'appareil"),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    country = (country_of_phone(user.phone if user else None) or "").upper()
    regions = _known_regions(db, current_user["user_id"])
    if region:
        regions.add(_norm(region))

    now = datetime.utcnow()
    query = db.query(HomeBanner).filter(
        HomeBanner.is_active.is_(True),
        or_(HomeBanner.starts_at.is_(None), HomeBanner.starts_at <= now),
        or_(HomeBanner.ends_at.is_(None), HomeBanner.ends_at > now),
        or_(HomeBanner.country.is_(None), HomeBanner.country == country) if country else HomeBanner.country.is_(None),
    )
    rows = query.order_by(HomeBanner.position.asc(), HomeBanner.id.desc()).all()
    # Le plus précis d'abord : sa ville, puis son pays, puis partout.
    matched = [b for b in rows if not b.region or _norm(b.region) in regions]
    matched.sort(key=lambda b: (0 if b.region else 1 if b.country else 2, b.position, -b.id))
    return {"country": country or None, "items": [_public(b) for b in matched[:MAX_BANNERS]]}


# ── Console ──────────────────────────────────────────────────────────────


class BannerBody(BaseModel):
    label: Optional[str] = Field(None, max_length=40)
    title: str = Field(..., min_length=1, max_length=80)
    body: Optional[str] = Field(None, max_length=200)
    image_media_id: Optional[int] = None
    cta_label: Optional[str] = Field(None, max_length=30)
    cta_url: Optional[str] = Field(None, max_length=500)
    country: Optional[str] = Field(None, max_length=2)
    region: Optional[str] = Field(None, max_length=80)
    position: int = Field(0, ge=0, le=999)
    is_active: bool = True
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None

    @field_validator("label", "body", "cta_label", "cta_url", "country", "region", mode="before")
    @classmethod
    def _blank_is_none(cls, value):
        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value

    @field_validator("country")
    @classmethod
    def _country(cls, value):
        if value is None:
            return None
        if len(value) != 2 or not value.isalpha():
            raise ValueError("Code pays à deux lettres (TG, CI, BJ…)")
        return value.upper()

    @field_validator("cta_url")
    @classmethod
    def _url(cls, value):
        # Jamais `http://`, `javascript:` ni un schéma inconnu : ce lien est
        # ouvert sur le téléphone de tous les utilisateurs de la zone.
        if value is None:
            return None
        if value.startswith("https://") or value in {"app:kory", "app:honam", "app:assime"}:
            return value
        raise ValueError("Lien https:// ou app:kory, app:honam, app:assime")


def _admin_json(banner: HomeBanner) -> dict:
    return {
        **_public(banner),
        "image_media_id": banner.image_media_id,
        "country": banner.country,
        "region": banner.region,
        "position": banner.position,
        "is_active": banner.is_active,
        "is_live": is_live(banner),
        "starts_at": banner.starts_at.isoformat() if banner.starts_at else None,
        "ends_at": banner.ends_at.isoformat() if banner.ends_at else None,
        "created_at": banner.created_at.isoformat() if banner.created_at else None,
    }


def _audit(db: Session, actor: User, action: str, banner_id: Optional[int], changes: Optional[dict], request: Request) -> None:
    db.add(AuditLog(
        user_id=actor.id, action=action, entity_type="home_banner", entity_id=banner_id,
        changes=changes,
        ip_address=(request.client.host if request.client else None),
        user_agent=request.headers.get("user-agent", "")[:500],
    ))


def _apply(db: Session, banner: HomeBanner, body: BannerBody) -> None:
    if body.starts_at and body.ends_at and body.ends_at <= body.starts_at:
        raise HTTPException(status_code=400, detail="La fin doit être après le début")
    if body.image_media_id is not None:
        asset = db.get(MediaAsset, body.image_media_id)
        if asset is None or not asset.mime_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="Image introuvable")
    for field, value in body.model_dump().items():
        if field in {"starts_at", "ends_at"} and value is not None and value.tzinfo is not None:
            value = value.replace(tzinfo=None) - value.utcoffset()
        setattr(banner, field, value)


@admin_router.get("")
def list_banners(
    user: User = Depends(require_permission("banners.view")),
    db: Session = Depends(get_db),
):
    rows = db.query(HomeBanner).order_by(HomeBanner.position.asc(), HomeBanner.id.desc()).all()
    return {"items": [_admin_json(b) for b in rows], "total": len(rows)}


@admin_router.post("")
def create_banner(
    body: BannerBody,
    request: Request,
    user: User = Depends(require_permission("banners.manage")),
    db: Session = Depends(get_db),
):
    banner = HomeBanner(created_by=user.id)
    _apply(db, banner, body)
    db.add(banner)
    db.flush()
    _audit(db, user, "banner_create", banner.id, {"title": banner.title, "country": banner.country, "region": banner.region}, request)
    db.commit()
    db.refresh(banner)
    return _admin_json(banner)


@admin_router.put("/{banner_id}")
def update_banner(
    banner_id: int,
    body: BannerBody,
    request: Request,
    user: User = Depends(require_permission("banners.manage")),
    db: Session = Depends(get_db),
):
    banner = db.get(HomeBanner, banner_id)
    if banner is None:
        raise HTTPException(status_code=404, detail="Bannière introuvable")
    _apply(db, banner, body)
    _audit(db, user, "banner_update", banner.id, {"title": banner.title, "is_active": banner.is_active}, request)
    db.commit()
    db.refresh(banner)
    return _admin_json(banner)


@admin_router.delete("/{banner_id}")
def delete_banner(
    banner_id: int,
    request: Request,
    user: User = Depends(require_permission("banners.manage")),
    db: Session = Depends(get_db),
):
    banner = db.get(HomeBanner, banner_id)
    if banner is None:
        raise HTTPException(status_code=404, detail="Bannière introuvable")
    _audit(db, user, "banner_delete", banner.id, {"title": banner.title}, request)
    db.delete(banner)
    db.commit()
    return {"deleted": True}
