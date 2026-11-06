"""Pokou — changer de numéro (REG-4, MSG-20).

Le compte suit la nouvelle puce : discussions, groupes, badge, cagnottes.
Deux étapes, comme une connexion : un code part vers le NOUVEAU numéro, et
seul ce code prouve qu'on le possède. On ne crée jamais de second compte —
d'où `consume_otp`, et non `verify_otp`, qui ouvrirait un compte au passage.

Le numéro de collecte Kory, lui, ne change pas tout seul (KORY-06) : c'est
un numéro de wallet, et les membres doivent être prévenus de son
changement. L'écran le rappelle.
"""
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.v1.account.profile import _profile_audience
from app.core.audit import AuditLogger
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import Contact, DirectMessage, User
from app.services.auth import contact_linking, otp_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/account/phone", tags=["Pokou account"])


class PhoneChangeRequest(BaseModel):
    new_phone: str = Field(..., max_length=32)


class PhoneChangeConfirm(BaseModel):
    new_phone: str = Field(..., max_length=32)
    code: str = Field(..., min_length=4, max_length=8)
    #: « Prévenir mes contacts » : tous, ceux avec qui j'ai discuté, ou
    #: personne. Les groupes sont toujours prévenus.
    notify: Literal["all", "chatted", "none"] = "chatted"


def _normalized_free_number(db: Session, user: User, raw: str) -> str:
    try:
        phone = otp_service.normalize_phone(raw)
    except otp_service.OTPInvalidError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if phone == user.phone:
        raise HTTPException(status_code=400, detail="C'est déjà ton numéro.")
    taken = (
        db.query(User.id)
        .filter(User.phone == phone, User.id != user.id, User.is_active.is_(True))
        .first()
    )
    if taken:
        raise HTTPException(
            status_code=409,
            detail="Ce numéro est déjà utilisé par un compte Pokou.",
        )
    return phone


def _me(db: Session, current_user: dict) -> User:
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user


@router.post("/change/request")
async def request_phone_change(
    payload: PhoneChangeRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = _me(db, current_user)
    phone = _normalized_free_number(db, user, payload.new_phone)
    try:
        expires_in = otp_service.generate_and_send_otp(db, phone)
    except otp_service.OTPRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except otp_service.OTPInvalidError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"phone": phone, "expires_in": expires_in}


@router.post("/change/confirm")
async def confirm_phone_change(
    payload: PhoneChangeConfirm,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    from app.api.v1.messaging.ws import manager

    user = _me(db, current_user)
    phone = _normalized_free_number(db, user, payload.new_phone)
    try:
        otp_service.consume_otp(db, phone, payload.code)
    except otp_service.OTPRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except otp_service.OTPInvalidError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    # Revérifié APRÈS le code : quelqu'un a pu s'inscrire avec ce numéro
    # entre la demande et la confirmation.
    phone = _normalized_free_number(db, user, phone)

    old_phone = user.phone
    # Un ancien compte DÉSACTIVÉ (supprimé, anonymisé) peut encore porter ce
    # numéro : la colonne est unique, il faut le libérer.
    for stale in db.query(User).filter(User.phone == phone, User.id != user.id).all():
        stale.phone = None
    user.phone = phone

    # Qui garde le lien vers moi dans son carnet : selon « Prévenir mes
    # contacts ». Le lien par identifiant ne casse jamais ; seul le numéro
    # affiché suit, ou non.
    chatted = {
        other
        for (other,) in db.query(DirectMessage.recipient_id).filter(DirectMessage.sender_id == user.id).distinct()
    } | {
        other
        for (other,) in db.query(DirectMessage.sender_id).filter(DirectMessage.recipient_id == user.id).distinct()
    }
    rows = db.query(Contact).filter(Contact.contact_user_id == user.id).all()
    if payload.notify == "all":
        informed = {row.owner_user_id for row in rows} | chatted
    elif payload.notify == "chatted":
        informed = chatted
    else:
        informed = set()
    for row in rows:
        if row.owner_user_id in informed:
            row.phone = phone
    db.commit()
    db.refresh(user)

    # Des fiches qui attendaient ce nouveau numéro se rattachent maintenant.
    try:
        contact_linking.link_pending_contacts(db, user)
    except Exception:  # pragma: no cover - best-effort
        logger.warning("rattachement après changement de numéro impossible", exc_info=True)

    await AuditLogger.log(
        db, user.id, "phone_changed", "user", user.id,
        changes={"notify": payload.notify},
    )

    # Temps réel : les groupes sont toujours prévenus (le profil change pour
    # eux), et les contacts choisis reçoivent le nouveau numéro.
    audience = _profile_audience(db, user.id)
    for other_id in audience:
        event = {"type": "user:profile_updated", "user_id": user.id}
        if other_id in informed:
            event = {**event, "phone_changed": True}
        try:
            await manager.send_to_user(other_id, event)
        except Exception:  # pragma: no cover - transport best-effort
            logger.warning("annonce de changement de numéro non remise à %s", other_id, exc_info=True)

    return {"phone": user.phone, "previous_phone_masked": _mask(old_phone)}


def _mask(phone: str | None) -> str | None:
    if not phone or len(phone) < 6:
        return phone
    return f"{phone[:4]} •• •• •• {phone[-2:]}"
