"""Pokou — carnet de contacts personnel (messagerie personne-à-personne,
distincte des « contacts intelligents » de l'assistant Mahizu, servis par l'API Mahizu)."""
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Contact, User
from app.api.v1.account.profile import _serialize_avatar
from app.services.auth.otp_service import normalize_phone, OTPInvalidError
from app.utils.identity import est_certifie, nom_affiche
from app.core.security import get_current_user

router = APIRouter(prefix="/contacts", tags=["Pokou contacts"])


_PRIORITY_TAGS = {"BUSINESS", "FOURNISSEUR", "CLIENT", "BOSS", "AMI"}


class ContactCreate(BaseModel):
    phone: str = Field(..., min_length=6, max_length=32)
    display_name: str = Field(..., min_length=1, max_length=255)


class ContactUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=255)
    priority_tag: Optional[str] = None


class DeviceContactEntry(BaseModel):
    phone: str
    name: str = Field(..., min_length=1, max_length=255)


class ContactsSyncRequest(BaseModel):
    contacts: List[DeviceContactEntry] = Field(..., max_length=3000)


def _serialize(contact: Contact) -> dict:
    is_registered = contact.contact_user_id is not None
    registered_user = contact.contact_user if is_registered else None
    return {
        "id": contact.id,
        "phone": contact.phone,
        # Le carnet, sauf pour un compte certifié qui a un nom — voir
        # utils/identity.py::nom_affiche. L'application n'édite pas ce nom :
        # le renvoyer résolu ne prive personne de rien.
        "display_name": nom_affiche(registered_user, contact.display_name)
        if registered_user
        else contact.display_name,
        "contact_user_id": contact.contact_user_id,
        "is_registered": is_registered,
        "about": registered_user.about if registered_user else None,
        "avatar": _serialize_avatar(registered_user.avatar_media) if registered_user else None,
        # Le ✓ vient d'UNE fonction pour toute l'API (voir utils/identity.py)
        # plutôt que d'une lecture de colonne recopiée route par route.
        "is_verified": est_certifie(registered_user) if registered_user else False,
        "priority_tag": contact.priority_tag,
        "created_at": contact.created_at.isoformat(),
    }


@router.get("")
async def list_contacts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    contacts = (
        db.query(Contact)
        .filter(Contact.owner_user_id == current_user["user_id"])
        .order_by(Contact.display_name)
        .all()
    )
    return {"items": [_serialize(c) for c in contacts]}


@router.get("/lookup")
async def lookup_phone(
    phone: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Pokou — un numéro partagé (bulle de texte, carte de visite, un lien)
    peut être touché sans qu'on veuille forcément l'ajouter au carnet :
    « entrer en discussion » ou « inviter par WhatsApp » n'exigent qu'un
    coup d'œil, pas une ligne Contact. D'où cette route à part, qui ne CRÉE
    rien — contrairement à POST /contacts, qui ajoute toujours une ligne.

    Répond toujours 200 : l'absence d'inscription n'est pas une erreur, c'est
    le cas normal qui déclenche l'invitation WhatsApp côté client."""
    try:
        normalized = normalize_phone(phone)
    except OTPInvalidError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    matched_user = db.query(User).filter(User.phone == normalized).first()
    if not matched_user:
        return {"phone": normalized, "registered": False, "user_id": None, "display_name": None, "avatar": None}

    # Nom du carnet d'adresses s'il existe déjà (reconnu par l'utilisateur),
    # sinon le nom de profil — jamais le numéro brut si un nom est connu.
    existing_contact = db.query(Contact).filter(
        Contact.owner_user_id == current_user["user_id"], Contact.contact_user_id == matched_user.id
    ).first()
    display_name = nom_affiche(
        matched_user, existing_contact.display_name if existing_contact else None, repli=normalized
    )
    return {
        "phone": normalized,
        "registered": True,
        "user_id": matched_user.id,
        "display_name": display_name,
        "avatar": _serialize_avatar(matched_user.avatar_media),
    }


@router.post("")
async def add_contact(
    payload: ContactCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    try:
        phone = normalize_phone(payload.phone)
    except OTPInvalidError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    user_id = current_user["user_id"]
    if phone == db.query(User.phone).filter(User.id == user_id).scalar():
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous ajouter vous-même")

    existing = db.query(Contact).filter(Contact.owner_user_id == user_id, Contact.phone == phone).first()
    if existing:
        raise HTTPException(status_code=409, detail="Ce numéro est déjà dans vos contacts")

    matched_user = db.query(User).filter(User.phone == phone).first()
    contact = Contact(
        owner_user_id=user_id,
        phone=phone,
        display_name=payload.display_name,
        contact_user_id=matched_user.id if matched_user else None,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return _serialize(contact)


@router.post("/sync")
async def sync_device_contacts(
    payload: ContactsSyncRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Découverte de contacts façon WhatsApp/Telegram : l'app envoie les
    numéros (+ noms) de son carnet d'adresses local, on renvoie ceux qui
    correspondent à un compte Pokou déjà enregistré et on les ajoute (ou
    met à jour) automatiquement dans le carnet de contacts de
    l'utilisateur. Recherche sans état : les numéros qui ne correspondent
    à aucun compte ne sont jamais écrits en base — seule la comparaison
    `User.phone IN (...)` est faite, rien n'est conservé pour les
    non-inscrits."""
    user_id = current_user["user_id"]
    my_phone = db.query(User.phone).filter(User.id == user_id).scalar()

    name_by_phone: Dict[str, str] = {}
    for entry in payload.contacts:
        try:
            phone = normalize_phone(entry.phone)
        except OTPInvalidError:
            continue
        if phone == my_phone:
            continue
        name_by_phone.setdefault(phone, entry.name)

    if not name_by_phone:
        return {"items": []}

    matched_users = db.query(User).filter(User.phone.in_(name_by_phone.keys())).all()
    if not matched_users:
        return {"items": []}

    existing_by_phone = {
        c.phone: c
        for c in db.query(Contact).filter(
            Contact.owner_user_id == user_id,
            Contact.phone.in_([u.phone for u in matched_users]),
        ).all()
    }

    touched: List[Contact] = []
    for matched_user in matched_users:
        device_name = name_by_phone[matched_user.phone]
        contact = existing_by_phone.get(matched_user.phone)
        if contact:
            contact.display_name = device_name
            contact.contact_user_id = matched_user.id
        else:
            contact = Contact(
                owner_user_id=user_id,
                phone=matched_user.phone,
                display_name=device_name,
                contact_user_id=matched_user.id,
            )
            db.add(contact)
        touched.append(contact)

    db.commit()
    for contact in touched:
        db.refresh(contact)
    return {"items": [_serialize(c) for c in touched]}


@router.put("/{contact_id}")
async def update_contact(
    contact_id: int,
    payload: ContactUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    contact = db.query(Contact).filter(
        Contact.id == contact_id, Contact.owner_user_id == current_user["user_id"]
    ).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact introuvable")

    if payload.display_name is not None:
        contact.display_name = payload.display_name
    if payload.priority_tag is not None:
        tag = payload.priority_tag.upper()
        if tag not in _PRIORITY_TAGS:
            raise HTTPException(status_code=400, detail="Tag invalide")
        contact.priority_tag = tag

    db.commit()
    db.refresh(contact)
    return _serialize(contact)


@router.delete("/{contact_id}")
async def delete_contact(
    contact_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    contact = db.query(Contact).filter(
        Contact.id == contact_id, Contact.owner_user_id == current_user["user_id"]
    ).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact introuvable")
    db.delete(contact)
    db.commit()
    return {"success": True}
