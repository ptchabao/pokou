"""Spark, côté équipe — le catalogue des formules et la file des alertes.

Deux écrans, et le second est le plus important : une alerte de sécurité qui
n'arrive sur aucun bureau n'est pas une alerte, c'est une ligne dans une
table. Le Safe Word prévient le cercle de la personne ; cette file est
l'endroit où l'équipe voit ce qui s'est passé, et le marque traité.
"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.models import SparkDate, SparkDatePack, SparkProfile, SparkSafetyAlert, User, UserRole
from app.services.modules import spark_rules as rules
from app.core.audit import AuditLogger

router = APIRouter(prefix="/spark-admin", tags=["Admin Spark"])

_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]


class PackUpsert(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    description: str | None = Field(None, max_length=500)
    venue_name: str = Field(..., min_length=2, max_length=120)
    venue_address: str | None = Field(None, max_length=255)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)
    price: int = Field(..., ge=500, le=100000)
    merchant_id: int | None = None
    image_media_id: int | None = None
    is_active: bool = True


def _pack_row(pack: SparkDatePack) -> dict:
    return {
        "id": pack.id,
        "title": pack.title,
        "description": pack.description,
        "venue_name": pack.venue_name,
        "venue_address": pack.venue_address,
        "price": pack.price,
        "merchant_id": pack.merchant_id,
        "is_active": pack.is_active,
        "media_url": f"/api/media/{pack.image_media_id}" if pack.image_media_id else None,
        "created_at": pack.created_at.isoformat(),
    }


@router.get("/overview")
async def overview(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Ce qu'il faut regarder en premier."""
    now = datetime.utcnow()
    held = db.query(SparkDate).filter(SparkDate.status == "HELD").all()
    return {
        "profiles": db.query(SparkProfile).count(),
        "packs_active": db.query(SparkDatePack).filter(SparkDatePack.is_active.is_(True)).count(),
        "dates_held": len(held),
        # L'argent actuellement bloqué. Le chiffre à connaître avant toute
        # autre chose : c'est de l'argent encaissé qui ne nous appartient pas.
        "escrow_amount": sum(row.amount for row in held),
        "alerts_open": db.query(SparkSafetyAlert)
        .filter(SparkSafetyAlert.resolved_at.is_(None))
        .count(),
        "dates_awaiting_payout": db.query(SparkDate)
        .filter(SparkDate.settled_at.isnot(None), SparkDate.merchant_due.isnot(None))
        .count(),
        "generated_at": now.isoformat(),
    }


# ─── Les formules ────────────────────────────────────────────────────────────


@router.get("/packs")
async def list_packs(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    packs = db.query(SparkDatePack).order_by(SparkDatePack.created_at.desc()).all()
    return {"items": [_pack_row(pack) for pack in packs]}


@router.post("/packs")
async def create_pack(
    payload: PackUpsert,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Le catalogue est tenu par l'équipe, jamais par les commerçants.

    Un pack est une promesse faite à deux personnes qui vont se déplacer et
    qui ont déjà payé. Une formule fantaisiste ne coûte rien à celui qui la
    publie, et un rendez-vous raté à ceux qui la croient.
    """
    if payload.merchant_id is not None:
        if db.query(User.id).filter(User.id == payload.merchant_id).first() is None:
            raise HTTPException(status_code=404, detail="Commerçant introuvable")
    pack = SparkDatePack(**payload.model_dump())
    db.add(pack)
    db.commit()
    db.refresh(pack)
    AuditLogger(db).log(
        user_id=current_user["user_id"],
        action="spark_pack_created",
        resource_type="spark_date_pack",
        resource_id=str(pack.id),
        details={"title": pack.title, "price": pack.price},
    )
    return _pack_row(pack)


@router.put("/packs/{pack_id}")
async def update_pack(
    pack_id: int,
    payload: PackUpsert,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    pack = db.query(SparkDatePack).filter(SparkDatePack.id == pack_id).first()
    if pack is None:
        raise HTTPException(status_code=404, detail="Formule introuvable")
    for field, value in payload.model_dump().items():
        setattr(pack, field, value)
    db.commit()
    db.refresh(pack)
    AuditLogger(db).log(
        user_id=current_user["user_id"],
        action="spark_pack_updated",
        resource_type="spark_date_pack",
        resource_id=str(pack.id),
        details={"is_active": pack.is_active, "price": pack.price},
    )
    return _pack_row(pack)


# ─── L'argent en attente ─────────────────────────────────────────────────────


@router.get("/settlements")
async def settlements(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Ce qui est DÛ, et à qui.

    Pokou n'a pas de rail de virement sortant : cette liste est le document
    de travail à partir duquel l'équipe paie les commerçants, rembourse les
    annulations et verse les pénalités. Tant que le virement automatique
    n'existe pas, c'est ici que l'argent se règle.
    """
    rows = (
        db.query(SparkDate)
        .filter(SparkDate.settled_at.isnot(None))
        .order_by(SparkDate.settled_at.desc())
        .limit(limit)
        .all()
    )
    packs = {
        pack.id: pack
        for pack in db.query(SparkDatePack).filter(
            SparkDatePack.id.in_({row.pack_id for row in rows} or {-1})
        )
    }
    return {
        "items": [
            {
                "date_id": row.id,
                "status": row.status,
                "amount": row.amount,
                "venue": packs[row.pack_id].venue_name if row.pack_id in packs else None,
                "merchant_id": packs[row.pack_id].merchant_id if row.pack_id in packs else None,
                "merchant_due": row.merchant_due,
                "platform_fee": row.platform_fee,
                "refund_to_user_id": row.payer_id if row.status == "REFUNDED" else None,
                "refund_amount": row.amount if row.status == "REFUNDED" else None,
                "penalty_to_user_id": row.penalty_to_user_id,
                "penalty_amount": row.penalty_amount,
                "settled_at": row.settled_at.isoformat(),
            }
            for row in rows
        ],
        "mode": "manual",
        "note": "Aucun virement n'est automatique. Cette liste est à régler à la main.",
    }


# ─── La file des alertes ─────────────────────────────────────────────────────


@router.get("/alerts")
async def alerts(
    only_open: bool = Query(True),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    query = db.query(SparkSafetyAlert)
    if only_open:
        query = query.filter(SparkSafetyAlert.resolved_at.is_(None))
    rows = query.order_by(SparkSafetyAlert.created_at.desc()).limit(limit).all()

    users = {
        user.id: user
        for user in db.query(User).filter(User.id.in_({row.user_id for row in rows} or {-1}))
    }
    return {
        "items": [
            {
                "id": row.id,
                "kind": row.kind,
                "user_id": row.user_id,
                # Le nom ET le numéro : une alerte de sécurité doit permettre
                # de RAPPELER quelqu'un, pas seulement de savoir qui c'est.
                "user_name": users[row.user_id].full_name if row.user_id in users else None,
                "user_phone": users[row.user_id].phone if row.user_id in users else None,
                "date_id": row.date_id,
                "latitude": row.latitude,
                "longitude": row.longitude,
                "map_url": (
                    f"https://maps.google.com/?q={row.latitude},{row.longitude}"
                    if row.latitude is not None and row.longitude is not None
                    else None
                ),
                "resolved_at": row.resolved_at.isoformat() if row.resolved_at else None,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


class AlertResolution(BaseModel):
    #: Obligatoire. Une alerte close sans un mot ne dit pas si quelqu'un a
    #: vraiment été joint, et la prochaine personne qui ouvre le dossier ne
    #: peut rien en faire.
    note: str = Field(..., min_length=3, max_length=500)


@router.post("/alerts/{alert_id}/resolve")
async def resolve_alert(
    alert_id: int,
    payload: AlertResolution,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    alert = db.query(SparkSafetyAlert).filter(SparkSafetyAlert.id == alert_id).first()
    if alert is None:
        raise HTTPException(status_code=404, detail="Alerte introuvable")
    if alert.resolved_at is not None:
        raise HTTPException(status_code=409, detail="Alerte déjà traitée")
    alert.resolved_at = datetime.utcnow()
    db.commit()
    AuditLogger(db).log(
        user_id=current_user["user_id"],
        action="spark_alert_resolved",
        resource_type="spark_safety_alert",
        resource_id=str(alert.id),
        details={"note": payload.note, "kind": alert.kind},
    )
    return {"ok": True, "resolved_at": alert.resolved_at.isoformat()}


# ─── Les profils ─────────────────────────────────────────────────────────────


@router.get("/profiles")
async def profiles(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    rows = (
        db.query(SparkProfile)
        .order_by(SparkProfile.karma, SparkProfile.created_at.desc())
        .limit(limit)
        .all()
    )
    today = datetime.utcnow().date()
    return {
        "items": [
            {
                "user_id": row.user_id,
                "display_name": row.display_name,
                "age": rules.age_on(row.birth_date, today),
                "gender": row.gender,
                "karma": row.karma,
                "can_invite": rules.can_invite(row.karma),
                "is_visible": row.is_visible,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/profiles/{user_id}/hide")
async def hide_profile(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Retirer un profil du flux.

    Réversible, et distinct d'une suppression : instruire un signalement
    suppose que le profil existe encore.
    """
    profile = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
    if profile is None:
        raise HTTPException(status_code=404, detail="Profil introuvable")
    profile.is_visible = False
    db.commit()
    AuditLogger(db).log(
        user_id=current_user["user_id"],
        action="spark_profile_hidden",
        resource_type="spark_profile",
        resource_id=str(profile.id),
        details={"display_name": profile.display_name},
    )
    return {"ok": True}
