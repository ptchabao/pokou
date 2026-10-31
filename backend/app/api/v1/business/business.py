"""Pokou Business — le portail des entreprises, et son pendant admin.

Le portail (`/business/…`) s'utilise avec un compte Pokou ordinaire : on
se connecte par son numéro, puis on agit pour une ou plusieurs
entreprises selon son rôle (OWNER, DEVELOPER, BILLING — voir
models/business.py::BusinessMember).

L'admin (`/admin/business/…`) examine les dossiers, règle la facturation
d'une entreprise (prépayé ou postpayé), suspend, ajuste un solde, et fixe
les tarifs.
"""
from __future__ import annotations

import re
import secrets
from datetime import datetime, timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.models import MarketplacePayment, MediaAsset, User, UserRole
from app.models.business import Bot, BotApiKey, BotUsage, Invoice, LedgerEntry, BusinessOrganization, BusinessMember, BusinessTestNumber, WebhookDelivery
from app.api.v1.account.profile import _serialize_avatar
from app.services.marketplace.marketplace_monetization_service import create_payment
from app.services.auth.otp_service import OTPInvalidError, normalize_phone
from app.services.business import billing, invoice_pdf, keys, pricing, webhooks
from app.core.audit import AuditLogger
from app.core.security import get_current_user

router = APIRouter(tags=["pokou-business"])

_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]
ROLES = ("OWNER", "DEVELOPER", "BILLING")
HANDLE = re.compile(r"^[a-z][a-z0-9_]{2,31}$")
MAX_TEST_NUMBERS = 10
MAX_BOTS = 20


# ── Accès ─────────────────────────────────────────────────────────────────


def _membre(db: Session, org_id: int, user_id: int, roles: tuple[str, ...] = ROLES) -> tuple[BusinessOrganization, BusinessMember]:
    """L'entreprise et MON rôle — ou 404. 404 et non 403 pour une
    entreprise dont on n'est pas membre : « interdit » confirmerait qu'elle
    existe. 403 seulement pour un membre qui n'a pas le rôle requis."""
    membre = (
        db.query(BusinessMember)
        .filter(BusinessMember.organization_id == org_id, BusinessMember.user_id == user_id)
        .first()
    )
    if membre is None:
        raise HTTPException(status_code=404, detail="Entreprise introuvable")
    if membre.role not in roles:
        raise HTTPException(status_code=403, detail="Votre rôle ne permet pas cette action")
    return membre.organization, membre


def _bot_de(db: Session, org: BusinessOrganization, bot_id: int) -> Bot:
    bot = db.query(Bot).filter(Bot.id == bot_id, Bot.organization_id == org.id).first()
    if bot is None:
        raise HTTPException(status_code=404, detail="Bot introuvable")
    return bot


def _media_de(db: Session, media_id: Optional[int], user_id: int) -> Optional[MediaAsset]:
    if media_id is None:
        return None
    media = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
    if media is None or media.uploader_id != user_id:
        raise HTTPException(status_code=404, detail="Document introuvable — téléversez-le d'abord")
    return media


# ── Sérialisation ─────────────────────────────────────────────────────────


def _org(org: BusinessOrganization, role: Optional[str] = None) -> dict[str, Any]:
    return {
        "id": org.id,
        "name": org.name,
        "legal_name": org.legal_name,
        "country": org.country,
        "rccm": org.rccm,
        "nif": org.nif,
        "address": org.address,
        "billing_email": org.billing_email,
        "phone": org.phone,
        "status": org.status,
        "review_note": org.review_note,
        "suspended_reason": org.suspended_reason,
        "submitted_at": org.submitted_at.isoformat() if org.submitted_at else None,
        "verified_at": org.verified_at.isoformat() if org.verified_at else None,
        "billing_mode": org.billing_mode,
        "credit_balance": org.credit_balance,
        "postpaid_limit": org.postpaid_limit,
        "payment_terms_days": org.payment_terms_days,
        "created_at": org.created_at.isoformat(),
        **({"my_role": role} if role else {}),
    }


def _bot(bot: Bot, org: BusinessOrganization) -> dict[str, Any]:
    return {
        "id": bot.id,
        "user_id": bot.user_id,
        "handle": bot.handle,
        "name": bot.name,
        "description": bot.description,
        "avatar": _serialize_avatar(bot.user.avatar_media) if bot.user else None,
        "webhook_url": bot.webhook_url,
        "is_active": bot.is_active,
        "is_verified": org.status == "VERIFIED",
        "link": f"https://pok.app/bot/{bot.handle}",
        "created_at": bot.created_at.isoformat(),
    }


def _key(key: BotApiKey) -> dict[str, Any]:
    return {
        "id": key.id,
        "name": key.name,
        "mode": key.mode,
        "prefix": key.prefix,
        "created_at": key.created_at.isoformat(),
        "last_used_at": key.last_used_at.isoformat() if key.last_used_at else None,
        "revoked_at": key.revoked_at.isoformat() if key.revoked_at else None,
    }


def _invoice(inv: Invoice) -> dict[str, Any]:
    return {
        "id": inv.id,
        "number": inv.number,
        "kind": inv.kind,
        "status": inv.status,
        "period_start": inv.period_start.isoformat() if inv.period_start else None,
        "period_end": inv.period_end.isoformat() if inv.period_end else None,
        "lines": inv.lines or [],
        "subtotal": inv.subtotal,
        "tax_rate_bp": inv.tax_rate_bp,
        "tax_amount": inv.tax_amount,
        "total": inv.total,
        "currency": "XOF",
        "issued_at": inv.issued_at.isoformat(),
        "due_at": inv.due_at.isoformat() if inv.due_at else None,
        "paid_at": inv.paid_at.isoformat() if inv.paid_at else None,
    }


# ── Tarifs (public) ───────────────────────────────────────────────────────


@router.get("/business/pricing")
async def public_pricing(db: Session = Depends(get_db)):
    """Les tarifs en vigueur — publics : la page de tarifs du portail les
    lit ici plutôt que de les recopier."""
    t = pricing.tarifs(db)
    return {
        "currency": "XOF",
        "service_price": t["service_price"],
        "initiated_price": t["initiated_price"],
        "tax_rate_bp": t["tax_rate_bp"],
        "min_recharge": t["min_recharge"],
        "max_recharge": t["max_recharge"],
        "service_window_hours": int(billing.SERVICE_WINDOW.total_seconds() // 3600),
    }


# ── Entreprises ───────────────────────────────────────────────────────────


class OrganizationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    legal_name: Optional[str] = Field(None, max_length=200)
    country: str = Field("TG", min_length=2, max_length=2)
    billing_email: Optional[str] = Field(None, max_length=255)
    phone: Optional[str] = Field(None, max_length=32)
    address: Optional[str] = Field(None, max_length=255)


class OrganizationUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=120)
    legal_name: Optional[str] = Field(None, max_length=200)
    billing_email: Optional[str] = Field(None, max_length=255)
    phone: Optional[str] = Field(None, max_length=32)
    address: Optional[str] = Field(None, max_length=255)


@router.post("/business/organizations", status_code=201)
async def create_organization(
    payload: OrganizationCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée l'entreprise, en BAC À SABLE, avec son créateur pour OWNER.
    Les clés de test et les numéros de test sont utilisables tout de suite."""
    org = BusinessOrganization(
        name=payload.name.strip(),
        legal_name=(payload.legal_name or "").strip() or None,
        country=payload.country.upper(),
        billing_email=payload.billing_email,
        phone=payload.phone,
        address=payload.address,
    )
    db.add(org)
    db.flush()
    db.add(BusinessMember(organization_id=org.id, user_id=current_user["user_id"], role="OWNER"))
    db.commit()
    db.refresh(org)
    return _org(org, "OWNER")


@router.get("/business/organizations")
async def list_my_organizations(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    rows = (
        db.query(BusinessMember)
        .filter(BusinessMember.user_id == current_user["user_id"])
        .all()
    )
    return {"items": [_org(m.organization, m.role) for m in rows]}


@router.get("/business/organizations/{org_id}")
async def get_organization(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, membre = _membre(db, org_id, current_user["user_id"])
    data = _org(org, membre.role)
    data["bots_count"] = db.query(func.count(Bot.id)).filter(Bot.organization_id == org.id).scalar()
    if org.billing_mode == "POSTPAID":
        data["postpaid_outstanding"] = billing.encours_postpaye(db, org)
    return data


@router.patch("/business/organizations/{org_id}")
async def update_organization(
    org_id: int,
    payload: OrganizationUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, membre = _membre(db, org_id, current_user["user_id"], ("OWNER",))
    if org.status in {"PENDING_REVIEW", "VERIFIED"} and payload.legal_name is not None and payload.legal_name != org.legal_name:
        # La raison sociale est ce que l'équipe a vérifié : la changer après
        # coup reviendrait à faire porter le ✓ à une autre entreprise.
        raise HTTPException(status_code=409, detail="La raison sociale d'une entreprise vérifiée ne se modifie qu'avec l'équipe Pokou")
    for champ, valeur in payload.model_dump(exclude_unset=True).items():
        setattr(org, champ, valeur.strip() if isinstance(valeur, str) else valeur)
    db.commit()
    return _org(org, membre.role)


class VerificationSubmit(BaseModel):
    legal_name: str = Field(..., min_length=2, max_length=200)
    rccm: str = Field(..., min_length=3, max_length=64)
    nif: str = Field(..., min_length=3, max_length=64)
    address: str = Field(..., min_length=3, max_length=255)
    rccm_media_id: int
    identity_media_id: int


@router.post("/business/organizations/{org_id}/verification")
async def submit_verification(
    org_id: int,
    payload: VerificationSubmit,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le dossier : registre du commerce (RCCM), NIF, et la pièce d'identité
    du représentant. L'équipe tranche ; la production s'ouvre à
    l'approbation, pas au dépôt."""
    org, membre = _membre(db, org_id, current_user["user_id"], ("OWNER",))
    if org.status in {"PENDING_REVIEW", "VERIFIED"}:
        raise HTTPException(status_code=409, detail="Un dossier est déjà en cours ou approuvé")
    if org.status == "SUSPENDED":
        raise HTTPException(status_code=409, detail="Entreprise suspendue — contactez l'équipe Pokou")
    _media_de(db, payload.rccm_media_id, current_user["user_id"])
    _media_de(db, payload.identity_media_id, current_user["user_id"])
    org.legal_name = payload.legal_name.strip()
    org.rccm = payload.rccm.strip()
    org.nif = payload.nif.strip()
    org.address = payload.address.strip()
    org.rccm_media_id = payload.rccm_media_id
    org.identity_media_id = payload.identity_media_id
    org.status = "PENDING_REVIEW"
    org.submitted_at = datetime.utcnow()
    org.review_note = None
    db.commit()
    return _org(org, membre.role)


# ── Membres ───────────────────────────────────────────────────────────────


class MemberAdd(BaseModel):
    phone: str = Field(..., max_length=32)
    role: str = Field("DEVELOPER", pattern="^(OWNER|DEVELOPER|BILLING)$")


class MemberRole(BaseModel):
    role: str = Field(..., pattern="^(OWNER|DEVELOPER|BILLING)$")


def _member(m: BusinessMember) -> dict[str, Any]:
    return {
        "user_id": m.user_id,
        "name": m.user.full_name if m.user else None,
        "phone": m.user.phone if m.user else None,
        "role": m.role,
        "created_at": m.created_at.isoformat(),
    }


@router.get("/business/organizations/{org_id}/members")
async def list_members(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"])
    return {"items": [_member(m) for m in org.members]}


@router.post("/business/organizations/{org_id}/members", status_code=201)
async def add_member(
    org_id: int,
    payload: MemberAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ajoute quelqu'un qui a déjà un compte Pokou, par son numéro."""
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER",))
    try:
        phone = normalize_phone(payload.phone)
    except OTPInvalidError as exc:
        raise HTTPException(status_code=422, detail="Numéro invalide") from exc
    user = db.query(User).filter(User.phone == phone, User.is_bot.is_(False)).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Aucun compte Pokou avec ce numéro")
    if any(m.user_id == user.id for m in org.members):
        raise HTTPException(status_code=409, detail="Déjà membre")
    membre = BusinessMember(organization_id=org.id, user_id=user.id, role=payload.role)
    db.add(membre)
    db.commit()
    db.refresh(membre)
    return _member(membre)


def _proprietaires(org: BusinessOrganization) -> int:
    return sum(1 for m in org.members if m.role == "OWNER")


@router.patch("/business/organizations/{org_id}/members/{user_id}")
async def change_member_role(
    org_id: int,
    user_id: int,
    payload: MemberRole,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER",))
    cible = next((m for m in org.members if m.user_id == user_id), None)
    if cible is None:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    if cible.role == "OWNER" and payload.role != "OWNER" and _proprietaires(org) <= 1:
        raise HTTPException(status_code=409, detail="L'entreprise doit garder au moins un propriétaire")
    cible.role = payload.role
    db.commit()
    return _member(cible)


@router.delete("/business/organizations/{org_id}/members/{user_id}", status_code=204)
async def remove_member(
    org_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER",))
    cible = next((m for m in org.members if m.user_id == user_id), None)
    if cible is None:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    if cible.role == "OWNER" and _proprietaires(org) <= 1:
        raise HTTPException(status_code=409, detail="L'entreprise doit garder au moins un propriétaire")
    db.delete(cible)
    db.commit()
    return Response(status_code=204)


# ── Numéros de test ───────────────────────────────────────────────────────


class TestNumberAdd(BaseModel):
    phone: str = Field(..., max_length=32)


@router.get("/business/organizations/{org_id}/test-numbers")
async def list_test_numbers(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    rows = db.query(BusinessTestNumber).filter(BusinessTestNumber.organization_id == org.id).all()
    return {"items": [{"id": r.id, "phone": r.phone} for r in rows], "max": MAX_TEST_NUMBERS}


@router.post("/business/organizations/{org_id}/test-numbers", status_code=201)
async def add_test_number(
    org_id: int,
    payload: TestNumberAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    try:
        phone = normalize_phone(payload.phone)
    except OTPInvalidError as exc:
        raise HTTPException(status_code=422, detail="Numéro invalide") from exc
    existants = db.query(BusinessTestNumber).filter(BusinessTestNumber.organization_id == org.id).all()
    if any(r.phone == phone for r in existants):
        raise HTTPException(status_code=409, detail="Numéro déjà déclaré")
    if len(existants) >= MAX_TEST_NUMBERS:
        raise HTTPException(status_code=409, detail=f"{MAX_TEST_NUMBERS} numéros de test au plus")
    row = BusinessTestNumber(organization_id=org.id, phone=phone)
    db.add(row)
    db.commit()
    return {"id": row.id, "phone": row.phone}


@router.delete("/business/organizations/{org_id}/test-numbers/{number_id}", status_code=204)
async def remove_test_number(
    org_id: int,
    number_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    row = db.query(BusinessTestNumber).filter(
        BusinessTestNumber.id == number_id, BusinessTestNumber.organization_id == org.id
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Numéro introuvable")
    db.delete(row)
    db.commit()
    return Response(status_code=204)


# ── Bots ──────────────────────────────────────────────────────────────────


class BotCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=80)
    handle: str = Field(..., min_length=3, max_length=32)
    description: Optional[str] = Field(None, max_length=500)


class BotUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=80)
    description: Optional[str] = Field(None, max_length=500)
    webhook_url: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = None
    avatar_media_id: Optional[int] = None


@router.get("/business/organizations/{org_id}/bots")
async def list_bots(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"])
    return {"items": [_bot(b, org) for b in db.query(Bot).filter(Bot.organization_id == org.id).order_by(Bot.id)]}


@router.post("/business/organizations/{org_id}/bots", status_code=201)
async def create_bot(
    org_id: int,
    payload: BotCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée le bot ET le compte Pokou qui parle en son nom. Le secret de
    webhook est rendu ici, une seule fois — il se régénère ensuite."""
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    handle = payload.handle.strip().lower()
    if not HANDLE.match(handle):
        raise HTTPException(status_code=422, detail="Identifiant : 3 à 32 caractères, minuscules, chiffres et _, en commençant par une lettre")
    if db.query(Bot.id).filter(Bot.handle == handle).first():
        raise HTTPException(status_code=409, detail="Cet identifiant est déjà pris")
    if db.query(func.count(Bot.id)).filter(Bot.organization_id == org.id).scalar() >= MAX_BOTS:
        raise HTTPException(status_code=409, detail=f"{MAX_BOTS} bots au plus par entreprise")
    compte = User(
        full_name=payload.name.strip(),
        about=(payload.description or "")[:140] or None,
        is_bot=True,
        is_active=True,
        is_verified=org.status == "VERIFIED",
    )
    db.add(compte)
    db.flush()
    secret = secrets.token_hex(32)
    bot = Bot(
        organization_id=org.id,
        user_id=compte.id,
        handle=handle,
        name=payload.name.strip(),
        description=payload.description,
        webhook_secret=secret,
    )
    db.add(bot)
    db.commit()
    db.refresh(bot)
    return {**_bot(bot, org), "webhook_secret": secret}


@router.get("/business/organizations/{org_id}/bots/{bot_id}")
async def get_bot(org_id: int, bot_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"])
    return _bot(_bot_de(db, org, bot_id), org)


@router.patch("/business/organizations/{org_id}/bots/{bot_id}")
async def update_bot(
    org_id: int,
    bot_id: int,
    payload: BotUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    from app.utils.net import is_publicly_routable_url

    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    donnees = payload.model_dump(exclude_unset=True)
    if "webhook_url" in donnees and donnees["webhook_url"]:
        url = donnees["webhook_url"].strip()
        if not url.startswith("https://"):
            raise HTTPException(status_code=422, detail="L'URL de webhook doit être en https://")
        if not is_publicly_routable_url(url):
            raise HTTPException(status_code=422, detail="L'URL de webhook doit être publique et joignable")
        bot.webhook_url = url
    elif "webhook_url" in donnees:
        bot.webhook_url = None
    if "name" in donnees and donnees["name"]:
        bot.name = donnees["name"].strip()
        bot.user.full_name = bot.name
    if "description" in donnees:
        bot.description = donnees["description"]
        bot.user.about = (donnees["description"] or "")[:140] or None
    if "is_active" in donnees and donnees["is_active"] is not None:
        bot.is_active = donnees["is_active"]
    if "avatar_media_id" in donnees and donnees["avatar_media_id"] is not None:
        media = _media_de(db, donnees["avatar_media_id"], current_user["user_id"])
        bot.user.avatar_media_id = media.id
    db.commit()
    db.refresh(bot)
    return _bot(bot, org)


@router.post("/business/organizations/{org_id}/bots/{bot_id}/webhook-secret")
async def rotate_webhook_secret(
    org_id: int,
    bot_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    bot.webhook_secret = secrets.token_hex(32)
    db.commit()
    return {"webhook_secret": bot.webhook_secret}


@router.post("/business/organizations/{org_id}/bots/{bot_id}/webhook-test", status_code=202)
async def test_webhook(
    org_id: int,
    bot_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Met en file un événement `ping`, remis dans les secondes qui
    suivent : de quoi vérifier l'URL et la signature sans attendre un vrai
    message."""
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    if not bot.webhook_url:
        raise HTTPException(status_code=409, detail="Renseignez d'abord une URL de webhook")
    livraison = webhooks.mettre_en_file(db, bot, "ping", {"message": "Bonjour de Pokou"})
    db.commit()
    return {"event_id": livraison.event_id}


@router.get("/business/organizations/{org_id}/bots/{bot_id}/webhook-deliveries")
async def list_webhook_deliveries(
    org_id: int,
    bot_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    rows = (
        db.query(WebhookDelivery)
        .filter(WebhookDelivery.bot_id == bot.id)
        .order_by(WebhookDelivery.id.desc())
        .limit(50)
        .all()
    )
    return {
        "items": [
            {
                "id": r.id,
                "event_id": r.event_id,
                "event_type": r.event_type,
                "status": r.status,
                "attempts": r.attempts,
                "last_status_code": r.last_status_code,
                "last_error": r.last_error,
                "created_at": r.created_at.isoformat(),
                "delivered_at": r.delivered_at.isoformat() if r.delivered_at else None,
                "next_attempt_at": r.next_attempt_at.isoformat() if r.status == "PENDING" else None,
            }
            for r in rows
        ]
    }


@router.post("/business/organizations/{org_id}/bots/{bot_id}/webhook-deliveries/{delivery_id}/retry", status_code=202)
async def retry_webhook_delivery(
    org_id: int,
    bot_id: int,
    delivery_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    row = db.query(WebhookDelivery).filter(WebhookDelivery.id == delivery_id, WebhookDelivery.bot_id == bot.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Événement introuvable")
    row.status = "PENDING"
    row.attempts = 0
    row.next_attempt_at = datetime.utcnow()
    db.commit()
    return {"id": row.id, "status": row.status}


# ── Clés ──────────────────────────────────────────────────────────────────


class KeyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    mode: str = Field("TEST", pattern="^(TEST|LIVE)$")


@router.get("/business/organizations/{org_id}/bots/{bot_id}/keys")
async def list_keys(org_id: int, bot_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    rows = db.query(BotApiKey).filter(BotApiKey.bot_id == bot.id).order_by(BotApiKey.id.desc()).all()
    return {"items": [_key(k) for k in rows]}


@router.post("/business/organizations/{org_id}/bots/{bot_id}/keys", status_code=201)
async def create_key(
    org_id: int,
    bot_id: int,
    payload: KeyCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """La clé brute n'est rendue QU'ICI. Une clé de production attend la
    vérification de l'entreprise : avant, rien ne justifie qu'elle existe."""
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    if payload.mode == "LIVE" and org.status != "VERIFIED":
        raise HTTPException(status_code=409, detail="Les clés de production s'ouvrent après la vérification de l'entreprise")
    brute, prefixe, empreinte = keys.generer(payload.mode)
    cle = BotApiKey(
        bot_id=bot.id,
        name=payload.name.strip(),
        mode=payload.mode,
        prefix=prefixe,
        key_hash=empreinte,
        created_by_id=current_user["user_id"],
    )
    db.add(cle)
    db.commit()
    db.refresh(cle)
    await AuditLogger.log(db, current_user["user_id"], "create", "vb_api_key", cle.id, changes={"mode": cle.mode, "bot_id": bot.id})
    return {**_key(cle), "key": brute}


@router.delete("/business/organizations/{org_id}/bots/{bot_id}/keys/{key_id}", status_code=204)
async def revoke_key(
    org_id: int,
    bot_id: int,
    key_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "DEVELOPER"))
    bot = _bot_de(db, org, bot_id)
    cle = db.query(BotApiKey).filter(BotApiKey.id == key_id, BotApiKey.bot_id == bot.id).first()
    if cle is None:
        raise HTTPException(status_code=404, detail="Clé introuvable")
    if cle.revoked_at is None:
        cle.revoked_at = datetime.utcnow()
        db.commit()
        await AuditLogger.log(db, current_user["user_id"], "revoke", "vb_api_key", cle.id)
    return Response(status_code=204)


# ── Consommation ──────────────────────────────────────────────────────────


@router.get("/business/organizations/{org_id}/usage")
async def usage(
    org_id: int,
    days: int = Query(30, ge=1, le=366),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Messages envoyés et leur coût, jour par jour, en production comme en
    bac à sable (où ils ne coûtent rien)."""
    org, _ = _membre(db, org_id, current_user["user_id"])
    depuis = datetime.utcnow() - timedelta(days=days)
    jour = func.date(BotUsage.created_at)
    rows = (
        db.query(jour, BotUsage.mode, BotUsage.category, func.count(BotUsage.id), func.coalesce(func.sum(BotUsage.unit_price), 0))
        .filter(BotUsage.organization_id == org.id, BotUsage.created_at >= depuis)
        .group_by(jour, BotUsage.mode, BotUsage.category)
        .order_by(jour)
        .all()
    )
    par_jour: dict[str, dict[str, Any]] = {}
    totaux = {"messages": 0, "amount": 0, "service": 0, "initiated": 0, "test": 0}
    for d, mode, cat, n, montant in rows:
        cle = str(d)
        entree = par_jour.setdefault(cle, {"date": cle, "service": 0, "initiated": 0, "test": 0, "amount": 0})
        if mode == "TEST":
            entree["test"] += n
            totaux["test"] += n
        elif cat == "SERVICE":
            entree["service"] += n
            totaux["service"] += n
        else:
            entree["initiated"] += n
            totaux["initiated"] += n
        entree["amount"] += int(montant)
        totaux["messages"] += n
        totaux["amount"] += int(montant)
    return {"days": days, "currency": "XOF", "totals": totaux, "series": list(par_jour.values())}


# ── Facturation ───────────────────────────────────────────────────────────


@router.get("/business/organizations/{org_id}/billing")
async def billing_overview(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "BILLING"))
    ledger = (
        db.query(LedgerEntry)
        .filter(LedgerEntry.organization_id == org.id)
        .order_by(LedgerEntry.id.desc())
        .limit(50)
        .all()
    )
    return {
        "billing_mode": org.billing_mode,
        "credit_balance": org.credit_balance,
        "postpaid_limit": org.postpaid_limit,
        "postpaid_outstanding": billing.encours_postpaye(db, org) if org.billing_mode == "POSTPAID" else 0,
        "currency": "XOF",
        "pricing": pricing.tarifs(db),
        "ledger": [
            {
                "id": e.id,
                "kind": e.kind,
                "amount": e.amount,
                "balance_after": e.balance_after,
                "reference": e.reference,
                "created_at": e.created_at.isoformat(),
            }
            for e in ledger
        ],
    }


class RechargeCreate(BaseModel):
    amount: int = Field(..., gt=0)


@router.post("/business/organizations/{org_id}/recharges", status_code=201)
async def create_recharge(
    org_id: int,
    payload: RechargeCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ouvre le paiement Mobile Money d'une recharge. Le crédit n'arrive
    qu'à la confirmation signée du paiement — jamais ici."""
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "BILLING"))
    t = pricing.tarifs(db)
    if not t["min_recharge"] <= payload.amount <= t["max_recharge"]:
        raise HTTPException(status_code=422, detail=f"Recharge entre {t['min_recharge']} et {t['max_recharge']} FCFA")
    payeur = db.query(User).filter(User.id == current_user["user_id"]).first()
    try:
        paiement = create_payment(
            db,
            payeur,
            kind="BOT_CREDIT",
            amount=payload.amount,
            description=f"Pokou Business — recharge {org.name}",
            metadata={"organization_id": org.id},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.commit()
    return {"payment_id": paiement.id, "payment_url": paiement.payment_url, "status": paiement.status}


@router.get("/business/organizations/{org_id}/invoices")
async def list_invoices(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "BILLING"))
    rows = db.query(Invoice).filter(Invoice.organization_id == org.id).order_by(Invoice.id.desc()).all()
    return {"items": [_invoice(i) for i in rows]}


@router.get("/business/organizations/{org_id}/invoices/{invoice_id}/pdf")
async def invoice_pdf_route(
    org_id: int,
    invoice_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "BILLING"))
    facture = db.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == org.id).first()
    if facture is None:
        raise HTTPException(status_code=404, detail="Facture introuvable")
    return Response(
        content=invoice_pdf.rendre(facture, org),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{facture.number}.pdf"'},
    )


@router.post("/business/organizations/{org_id}/invoices/{invoice_id}/pay", status_code=201)
async def pay_invoice(
    org_id: int,
    invoice_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    org, _ = _membre(db, org_id, current_user["user_id"], ("OWNER", "BILLING"))
    facture = db.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == org.id).first()
    if facture is None:
        raise HTTPException(status_code=404, detail="Facture introuvable")
    if facture.status not in {"ISSUED", "OVERDUE"}:
        raise HTTPException(status_code=409, detail="Cette facture n'est pas à régler")
    payeur = db.query(User).filter(User.id == current_user["user_id"]).first()
    try:
        paiement = create_payment(
            db,
            payeur,
            kind="BOT_INVOICE",
            amount=facture.total,
            description=f"Pokou Business — facture {facture.number}",
            metadata={"organization_id": org.id, "invoice_id": facture.id},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.commit()
    return {"payment_id": paiement.id, "payment_url": paiement.payment_url, "status": paiement.status}


@router.get("/business/payments/{payment_id}")
async def payment_status(payment_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    paiement = db.query(MarketplacePayment).filter(
        MarketplacePayment.id == payment_id,
        MarketplacePayment.user_id == current_user["user_id"],
        MarketplacePayment.kind.in_(["BOT_CREDIT", "BOT_INVOICE"]),
    ).first()
    if paiement is None:
        raise HTTPException(status_code=404, detail="Paiement introuvable")
    return {"id": paiement.id, "status": paiement.status, "amount": paiement.amount, "kind": paiement.kind}


def apply_confirmed_payment(db: Session, payment: MarketplacePayment) -> Optional[dict]:
    """Appelé par marketplace_monetization_service.confirm_payment, UNE fois
    par paiement confirmé (il refuse de rejouer un paiement déjà traité)."""
    metadata = payment.metadata_json or {}
    org = db.query(BusinessOrganization).filter(BusinessOrganization.id == metadata.get("organization_id")).first()
    if org is None:
        return None
    if payment.kind == "BOT_CREDIT":
        billing.crediter(db, org, payment.amount, reference=f"payment:{payment.id}")
        facture = billing.facture_de_recharge(db, org, payment.amount, payment.id)
        return {"organization_id": org.id, "credited": payment.amount, "invoice": facture.number}
    if payment.kind == "BOT_INVOICE":
        facture = db.query(Invoice).filter(
            Invoice.id == metadata.get("invoice_id"), Invoice.organization_id == org.id
        ).first()
        if facture is None or facture.status == "PAID":
            return {"organization_id": org.id, "invoice_paid": False}
        billing.regler_facture(db, facture, payment.id)
        return {"organization_id": org.id, "invoice_paid": facture.number}
    return None


# ── Annuaire des bots (application Pokou) ─────────────────────────────────


def _public_bot(bot: Bot, org: BusinessOrganization) -> dict[str, Any]:
    return {
        "user_id": bot.user_id,
        "handle": bot.handle,
        "name": bot.name,
        "description": bot.description,
        "avatar": _serialize_avatar(bot.user.avatar_media) if bot.user else None,
        "is_verified": org.status == "VERIFIED",
        "organization": org.legal_name or org.name if org.status == "VERIFIED" else org.name,
    }


@router.get("/bots/search")
async def search_bots(
    q: str = Query(..., min_length=2, max_length=60),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les bots d'entreprises VÉRIFIÉES seulement : un bot de bac à sable
    n'a rien à faire dans un annuaire public."""
    motif = f"%{q.strip().lower()}%"
    rows = (
        db.query(Bot, BusinessOrganization)
        .join(BusinessOrganization, BusinessOrganization.id == Bot.organization_id)
        .filter(
            Bot.is_active.is_(True),
            BusinessOrganization.status == "VERIFIED",
            (func.lower(Bot.name).like(motif)) | (Bot.handle.like(motif)),
        )
        .order_by(Bot.name)
        .limit(20)
        .all()
    )
    return {"items": [_public_bot(b, o) for b, o in rows]}


@router.get("/bots/{handle}")
async def get_bot_by_handle(handle: str, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    """La fiche d'un bot, ouverte depuis un lien pok.app/bot/<handle>.
    Un bot de bac à sable n'est visible que de ses numéros de test."""
    bot = db.query(Bot).filter(Bot.handle == handle.lower(), Bot.is_active.is_(True)).first()
    if bot is None:
        raise HTTPException(status_code=404, detail="Bot introuvable")
    org = db.query(BusinessOrganization).filter(BusinessOrganization.id == bot.organization_id).first()
    if org.status != "VERIFIED":
        moi = db.query(User).filter(User.id == current_user["user_id"]).first()
        numeros = {
            r.phone
            for r in db.query(BusinessTestNumber).filter(BusinessTestNumber.organization_id == org.id)
        }
        if moi is None or moi.phone not in numeros:
            raise HTTPException(status_code=404, detail="Bot introuvable")
    return _public_bot(bot, org)


# ── Admin ─────────────────────────────────────────────────────────────────


def _admin_org(db: Session, org_id: int) -> BusinessOrganization:
    org = db.query(BusinessOrganization).filter(BusinessOrganization.id == org_id).first()
    if org is None:
        raise HTTPException(status_code=404, detail="Entreprise introuvable")
    return org


@router.get("/admin/business/overview")
async def admin_overview(db: Session = Depends(get_db), current_user: dict = Depends(require_admin_role(_TEAM_ROLES))):
    par_statut = dict(db.query(BusinessOrganization.status, func.count(BusinessOrganization.id)).group_by(BusinessOrganization.status).all())
    debut = billing.debut_du_mois(datetime.utcnow())
    return {
        "organizations": par_statut,
        "pending_review": par_statut.get("PENDING_REVIEW", 0),
        "bots": db.query(func.count(Bot.id)).scalar(),
        "messages_this_month": db.query(func.count(BotUsage.id)).filter(BotUsage.mode == "LIVE", BotUsage.created_at >= debut).scalar(),
        "revenue_this_month": int(
            db.query(func.coalesce(func.sum(BotUsage.unit_price), 0)).filter(BotUsage.mode == "LIVE", BotUsage.created_at >= debut).scalar()
            or 0
        ),
        "overdue_invoices": db.query(func.count(Invoice.id)).filter(Invoice.status == "OVERDUE").scalar(),
    }


@router.get("/admin/business/organizations")
async def admin_list_organizations(
    status_filter: Optional[str] = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    query = db.query(BusinessOrganization)
    if status_filter:
        query = query.filter(BusinessOrganization.status == status_filter)
    return {"items": [_org(o) for o in query.order_by(BusinessOrganization.id.desc()).limit(200)]}


@router.get("/admin/business/organizations/{org_id}")
async def admin_get_organization(org_id: int, db: Session = Depends(get_db), current_user: dict = Depends(require_admin_role(_TEAM_ROLES))):
    org = _admin_org(db, org_id)
    data = _org(org)
    data["members"] = [_member(m) for m in org.members]
    data["bots"] = [_bot(b, org) for b in org.bots]
    # Les pièces s'ouvrent par /media/<id> : le contrôle d'accès y réserve
    # les documents d'un dossier à l'équipe (voir media.py::_can_access).
    # Même forme que marketplace_admin.py::_media_url : l'admin réécrit
    # `/api/…` vers l'API, et un `/api/v1/…` y devenait `/api/v1/v1/…`.
    data["rccm_media_url"] = f"/api/media/{org.rccm_media_id}" if org.rccm_media_id else None
    data["identity_media_url"] = f"/api/media/{org.identity_media_id}" if org.identity_media_id else None
    data["invoices"] = [_invoice(i) for i in db.query(Invoice).filter(Invoice.organization_id == org.id).order_by(Invoice.id.desc()).limit(24)]
    if org.billing_mode == "POSTPAID":
        data["postpaid_outstanding"] = billing.encours_postpaye(db, org)
    return data


class VerificationDecision(BaseModel):
    approved: bool
    note: str = Field(..., min_length=3, max_length=500)


@router.put("/admin/business/organizations/{org_id}/verification")
async def admin_decide_verification(
    org_id: int,
    payload: VerificationDecision,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Approuver ouvre la production et pose le ✓ sur les comptes des bots ;
    refuser garde le bac à sable, avec le motif écrit."""
    org = _admin_org(db, org_id)
    if org.status != "PENDING_REVIEW":
        raise HTTPException(status_code=409, detail="Aucun dossier en attente")
    org.reviewer_id = current_user["user_id"]
    org.review_note = payload.note
    if payload.approved:
        org.status = "VERIFIED"
        org.verified_at = datetime.utcnow()
        for bot in org.bots:
            if bot.user:
                bot.user.is_verified = True
                bot.user.verified_at = org.verified_at
    else:
        org.status = "REJECTED"
    db.commit()
    await AuditLogger.log(db, current_user["user_id"], "review", "vb_organization", org.id, changes={"approved": payload.approved})
    return _org(org)


class BillingSettings(BaseModel):
    billing_mode: str = Field(..., pattern="^(PREPAID|POSTPAID)$")
    postpaid_limit: int = Field(0, ge=0)
    payment_terms_days: int = Field(15, ge=1, le=90)


@router.put("/admin/business/organizations/{org_id}/billing")
async def admin_set_billing(
    org_id: int,
    payload: BillingSettings,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Le postpayé se décide ici et nulle part ailleurs : c'est un crédit
    consenti à l'entreprise. Seule une entreprise VÉRIFIÉE y a droit."""
    org = _admin_org(db, org_id)
    if payload.billing_mode == "POSTPAID":
        if org.status != "VERIFIED":
            raise HTTPException(status_code=409, detail="Le postpayé est réservé aux entreprises vérifiées")
        if payload.postpaid_limit <= 0:
            raise HTTPException(status_code=422, detail="Fixez un plafond de consommation")
    org.billing_mode = payload.billing_mode
    org.postpaid_limit = payload.postpaid_limit
    org.payment_terms_days = payload.payment_terms_days
    db.commit()
    await AuditLogger.log(db, current_user["user_id"], "update", "vb_billing", org.id, changes=payload.model_dump())
    return _org(org)


class SuspensionChange(BaseModel):
    suspended: bool
    reason: Optional[str] = Field(None, max_length=255)


@router.put("/admin/business/organizations/{org_id}/suspension")
async def admin_suspend(
    org_id: int,
    payload: SuspensionChange,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    org = _admin_org(db, org_id)
    if payload.suspended:
        if not payload.reason:
            raise HTTPException(status_code=422, detail="Motif obligatoire")
        org.status = "SUSPENDED"
        org.suspended_reason = payload.reason
    elif org.status == "SUSPENDED":
        org.status = "VERIFIED" if org.verified_at else "SANDBOX"
        org.suspended_reason = None
    db.commit()
    await AuditLogger.log(db, current_user["user_id"], "update", "vb_suspension", org.id, changes=payload.model_dump())
    return _org(org)


class Adjustment(BaseModel):
    amount: int
    reason: str = Field(..., min_length=3, max_length=120)


@router.post("/admin/business/organizations/{org_id}/adjustments", status_code=201)
async def admin_adjust_balance(
    org_id: int,
    payload: Adjustment,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Geste commercial ou correction, toujours tracé avec son motif."""
    org = _admin_org(db, org_id)
    if payload.amount == 0:
        raise HTTPException(status_code=422, detail="Montant nul")
    if org.credit_balance + payload.amount < 0:
        raise HTTPException(status_code=409, detail="Le solde deviendrait négatif")
    entry = billing.crediter(db, org, payload.amount, reference=payload.reason, by=current_user["user_id"], kind="ADJUSTMENT")
    db.commit()
    await AuditLogger.log(db, current_user["user_id"], "adjust", "vb_ledger", entry.id, changes=payload.model_dump())
    return {"credit_balance": entry.balance_after}


@router.get("/admin/business/pricing")
async def admin_get_pricing(db: Session = Depends(get_db), current_user: dict = Depends(require_admin_role(_TEAM_ROLES))):
    return pricing.tarifs(db)


@router.put("/admin/business/pricing")
async def admin_set_pricing(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    try:
        valeurs = pricing.enregistrer(db, payload, current_user["user_id"])
    except pricing.TarifsInvalides as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    db.commit()
    await AuditLogger.log(db, current_user["user_id"], "update", "vb_pricing", 0, changes=valeurs)
    return valeurs
