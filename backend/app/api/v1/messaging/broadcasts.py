"""Pokou — listes de diffusion, façon WhatsApp.

Une liste de diffusion est l'exact contraire d'un groupe, et c'est toute la
raison d'être de cette fonctionnalité :

- un **groupe** est un lieu. Ses membres se voient les uns les autres, les
  réponses s'y adressent à tous, et il existe pour chacun d'eux.
- une **liste de diffusion** est un carnet de copie. Elle n'existe que pour
  celui qui l'a faite. Chaque destinataire reçoit un message ORDINAIRE dans
  sa conversation habituelle, ne sait pas qu'il y en a eu d'autres, et sa
  réponse revient en privé à l'expéditeur seul.

D'où la forme de ce module : il n'y a pas de « message de diffusion » à
distribuer, il y a N vrais `DirectMessage` créés d'un coup, poussés par le
même chemin que n'importe quel message privé. `BroadcastMessage` ne sert
qu'à l'expéditeur, pour qu'il retrouve un envoi comme UN envoi plutôt
qu'éparpillé dans quarante conversations.

Les deux garde-fous qui empêchent d'en faire un outil d'envoi en masse :
seuls les gens du carnet d'adresses peuvent être mis dans une liste, et le
blocage est respecté destinataire par destinataire au moment de l'envoi.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models import BroadcastList, BroadcastListMember, BroadcastMessage, Contact, DirectMessage, MediaAsset, MessageType
from app.api.v1.messaging.conversations import is_blocked_between
from app.api.v1.messaging.messages import _deliver, _serialize
from app.core.security import get_current_user

router = APIRouter(prefix="/broadcasts", tags=["Pokou broadcasts"])

#: Plafond aligné sur WhatsApp. Ce n'est pas une limite technique : c'est la
#: frontière entre « prévenir mes clients » et « faire du publipostage ».
#: Au-delà, l'outil approprié est une chaîne, où l'on s'abonne volontairement.
MAX_MEMBERS = 256


class BroadcastListCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    member_user_ids: List[int] = Field(default_factory=list)


class BroadcastListUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    member_user_ids: Optional[List[int]] = None


class BroadcastSend(BaseModel):
    content: Optional[str] = Field(None, max_length=4000)
    message_type: str = "TEXT"
    media_asset_id: Optional[int] = None


def _own_list(db: Session, list_id: int, user_id: int) -> BroadcastList:
    """Une liste n'appartient qu'à son auteur — il n'y a pas de membre qui
    puisse la consulter, puisque personne d'autre ne sait qu'elle existe."""
    broadcast = (
        db.query(BroadcastList)
        .options(joinedload(BroadcastList.members))
        .filter(BroadcastList.id == list_id, BroadcastList.owner_user_id == user_id)
        .first()
    )
    if not broadcast:
        raise HTTPException(status_code=404, detail="Liste de diffusion introuvable")
    return broadcast


def _resolve_members(db: Session, owner_id: int, user_ids: List[int]) -> List[int]:
    """Ne retient que les destinataires présents dans le carnet de l'auteur.

    C'est le garde-fou principal : sans lui, une liste de diffusion serait
    un moyen d'écrire à 256 identifiants d'un seul appel, ce que tout le
    reste de la messagerie interdit précisément (voir `_require_reachable`).

    Silencieusement filtrant plutôt qu'en erreur : un identifiant qui a
    disparu du carnet entre l'affichage de l'écran et l'enregistrement ne
    doit pas faire échouer la sauvegarde de toute la liste.
    """
    wanted = {uid for uid in user_ids if uid != owner_id}
    if not wanted:
        return []
    if len(wanted) > MAX_MEMBERS:
        raise HTTPException(
            status_code=400,
            detail=f"Une liste de diffusion ne peut pas dépasser {MAX_MEMBERS} destinataires",
        )
    rows = (
        db.query(Contact.contact_user_id)
        .filter(
            Contact.owner_user_id == owner_id,
            Contact.contact_user_id.in_(wanted),
            Contact.is_blocked.is_(False),
        )
        .all()
    )
    return sorted({row[0] for row in rows})


def _serialize_list(db: Session, broadcast: BroadcastList) -> dict:
    member_ids = [m.user_id for m in broadcast.members]
    names = {}
    if member_ids:
        names = {
            c.contact_user_id: c.display_name
            for c in db.query(Contact)
            .filter(
                Contact.owner_user_id == broadcast.owner_user_id,
                Contact.contact_user_id.in_(member_ids),
            )
            .all()
        }
    return {
        "id": broadcast.id,
        "name": broadcast.name,
        "created_at": broadcast.created_at.isoformat(),
        "member_count": len(member_ids),
        "members": [
            {"user_id": uid, "display_name": names.get(uid, "Contact")} for uid in member_ids
        ],
    }


@router.get("")
async def list_broadcasts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    rows = (
        db.query(BroadcastList)
        .options(joinedload(BroadcastList.members))
        .filter(BroadcastList.owner_user_id == current_user["user_id"])
        .order_by(BroadcastList.created_at.desc())
        .all()
    )
    return {"items": [_serialize_list(db, row) for row in rows]}


@router.post("")
async def create_broadcast(
    payload: BroadcastListCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    broadcast = BroadcastList(owner_user_id=user_id, name=payload.name.strip())
    db.add(broadcast)
    db.flush()
    for member_id in _resolve_members(db, user_id, payload.member_user_ids):
        db.add(BroadcastListMember(broadcast_list_id=broadcast.id, user_id=member_id))
    db.commit()
    db.refresh(broadcast)
    return _serialize_list(db, broadcast)


@router.patch("/{list_id}")
async def update_broadcast(
    list_id: int,
    payload: BroadcastListUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    broadcast = _own_list(db, list_id, user_id)

    if payload.name is not None:
        broadcast.name = payload.name.strip()

    if payload.member_user_ids is not None:
        # Remplacement complet plutôt qu'ajout/retrait unitaires : l'écran
        # présente une case à cocher par contact, et renvoyer la sélection
        # entière évite de devoir raisonner sur un différentiel côté client.
        wanted = set(_resolve_members(db, user_id, payload.member_user_ids))
        existing = {m.user_id: m for m in broadcast.members}
        for user_id_to_remove in set(existing) - wanted:
            db.delete(existing[user_id_to_remove])
        for user_id_to_add in wanted - set(existing):
            db.add(BroadcastListMember(broadcast_list_id=broadcast.id, user_id=user_id_to_add))

    db.commit()
    db.refresh(broadcast)
    return _serialize_list(db, broadcast)


@router.delete("/{list_id}")
async def delete_broadcast(
    list_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    broadcast = _own_list(db, list_id, current_user["user_id"])
    # Les messages DÉJÀ partis ne bougent pas : ils sont chez leurs
    # destinataires, dans leur conversation, et n'ont jamais porté la marque
    # de cette liste. Supprimer la liste ne supprime que le carnet de copie.
    db.delete(broadcast)
    db.commit()
    return {"deleted": True}


@router.get("/{list_id}/messages")
async def list_broadcast_messages(
    list_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """L'historique vu par l'expéditeur : ce qu'il a composé, une ligne par
    envoi. Les destinataires n'ont pas d'équivalent — chez eux, il n'y a
    qu'un message ordinaire dans une conversation ordinaire."""
    _own_list(db, list_id, current_user["user_id"])
    rows = (
        db.query(BroadcastMessage)
        .filter(BroadcastMessage.broadcast_list_id == list_id)
        .order_by(BroadcastMessage.created_at.asc())
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "content": row.content,
                "message_type": row.message_type.value,
                "media_asset_id": row.media_asset_id,
                "recipient_count": row.recipient_count,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/{list_id}/messages")
async def send_to_broadcast(
    list_id: int,
    payload: BroadcastSend,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Compose une fois, livre N fois — un vrai message privé par personne.

    Le blocage est vérifié destinataire PAR destinataire, et un destinataire
    bloqué est sauté sans que l'envoi échoue : une liste de quarante
    personnes ne doit pas être bloquée par une seule brouille. C'est aussi ce
    qui empêche une liste de diffusion de servir à contourner un blocage.
    """
    sender_id = current_user["user_id"]
    broadcast = _own_list(db, list_id, sender_id)

    try:
        message_type = MessageType(payload.message_type.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail="Type de message invalide")

    media_asset = None
    if message_type == MessageType.TEXT:
        if not payload.content or not payload.content.strip():
            raise HTTPException(status_code=400, detail="Le contenu du message est requis")
    else:
        if not payload.media_asset_id:
            raise HTTPException(status_code=400, detail="Une pièce jointe est requise pour ce type de message")
        media_asset = db.query(MediaAsset).filter(MediaAsset.id == payload.media_asset_id).first()
        if not media_asset or media_asset.uploader_id != sender_id:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")

    recipients = [m.user_id for m in broadcast.members]
    if not recipients:
        raise HTTPException(status_code=400, detail="Cette liste n'a aucun destinataire")

    # Réglage d'éphémère par conversation : il appartient à CHAQUE fiche, pas
    # à la liste. Un envoi groupé ne doit pas imposer la durée d'une
    # conversation à une autre.
    disappearing = {
        c.contact_user_id: c.disappearing_seconds
        for c in db.query(Contact)
        .filter(Contact.owner_user_id == sender_id, Contact.contact_user_id.in_(recipients))
        .all()
    }

    composed = BroadcastMessage(
        broadcast_list_id=broadcast.id,
        sender_id=sender_id,
        message_type=message_type,
        content=payload.content,
        media_asset_id=media_asset.id if media_asset else None,
    )
    db.add(composed)

    from datetime import datetime, timedelta

    created: List[DirectMessage] = []
    skipped = 0
    for recipient_id in recipients:
        if is_blocked_between(db, sender_id, recipient_id):
            skipped += 1
            continue
        seconds = disappearing.get(recipient_id)
        message = DirectMessage(
            sender_id=sender_id,
            recipient_id=recipient_id,
            message_type=message_type,
            content=payload.content,
            media_asset_id=media_asset.id if media_asset else None,
            expires_at=datetime.utcnow() + timedelta(seconds=seconds) if seconds else None,
        )
        db.add(message)
        created.append(message)

    composed.recipient_count = len(created)
    db.commit()

    # Livraison APRÈS le commit : si la poussée temps réel échoue, les
    # messages existent quand même et partiront à la reconnexion du
    # destinataire. L'inverse — pousser puis échouer à écrire — livrerait un
    # message que personne ne retrouverait ensuite.
    for message in created:
        db.refresh(message)
        await _deliver(db, message)

    return {
        "id": composed.id,
        "recipient_count": len(created),
        "skipped_blocked": skipped,
        "messages": [_serialize(m, sender_id) for m in created],
    }
