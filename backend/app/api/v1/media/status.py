"""Pokou — statuts/stories façon WhatsApp. Visibles 24h, purgés ensuite (voir
app/utils/scheduler.py::_status_purge_loop). L'audience est choisie par
l'auteur (voir app/services/status_privacy_service.py)."""
import logging
import base64
import binascii
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models import Contact, MarketplaceBoost, MediaAsset, Status, StatusContentType, StatusRecipient, StatusView, User
from app.api.v1.messaging.ws import manager
from app.services.privacy import status_privacy_service
from app.utils.identity import est_certifie, nom_affiche
from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/status", tags=["Pokou status"])


class StatusRecipientCreate(BaseModel):
    user_id: int
    encryption: str = Field(min_length=1, max_length=32)
    ciphertext: str = Field(min_length=1, max_length=8192)
    envelope: Dict[str, Any]

    class Config:
        extra = "forbid"

    def valid_e2ee_payload(self) -> bool:
        nonce = self.envelope.get("iv")
        try:
            nonce_bytes = base64.b64decode(nonce, validate=True)
            ciphertext_bytes = base64.b64decode(self.ciphertext, validate=True)
        except (TypeError, ValueError, binascii.Error):
            return False
        return (
            self.encryption == "v1"
            and self.envelope.get("v") == 1
            and isinstance(self.envelope.get("sid"), str)
            and bool(self.envelope.get("sid"))
            and isinstance(self.envelope.get("n"), int)
            and self.envelope["n"] >= 0
            and len(nonce_bytes) == 12
            and len(ciphertext_bytes) >= 16
        )


class StatusCreate(BaseModel):
    content_type: str
    media_asset_id: Optional[int] = None
    background_color: Optional[str] = Field(None, max_length=9, pattern=r"^#[0-9A-Fa-f]{6}$")
    recipients: List[StatusRecipientCreate] = Field(default_factory=list, max_length=1000)

    class Config:
        extra = "forbid"


def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> None:
    is_contact = db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first()
    if not is_contact:
        raise HTTPException(status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses")


def _serialize_media(asset: MediaAsset) -> dict:
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _serialize_avatar(asset: Optional[MediaAsset]) -> Optional[dict]:
    return _serialize_media(asset) if asset is not None else None


def _serialize_status(
    status: Status,
    viewed_by_me: bool,
    view_count: int,
    encrypted_content: Optional[StatusRecipient] = None,
) -> dict:
    return {
        "id": status.id,
        "user_id": status.user_id,
        "content_type": status.content_type.value,
        # Never a plaintext compatibility fallback: an author's own
        # plaintext lives only in their encrypted local cache.
        "text_content": None,
        "encrypted_content": (
            {
                "encryption": encrypted_content.encryption,
                "ciphertext": encrypted_content.ciphertext,
                "envelope": encrypted_content.envelope,
            }
            if encrypted_content is not None
            else None
        ),
        "background_color": status.background_color,
        "media": _serialize_media(status.media_asset) if status.media_asset else None,
        "created_at": status.created_at.isoformat(),
        "expires_at": status.expires_at.isoformat(),
        "viewed_by_me": viewed_by_me,
        "view_count": view_count,
    }


@router.post("")
async def create_status(
    payload: StatusCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    try:
        content_type = StatusContentType(payload.content_type.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail="Type de statut invalide")

    audience = status_privacy_service.viewer_ids_for(db, user_id)
    recipient_ids = [recipient.user_id for recipient in payload.recipients]
    if len(recipient_ids) != len(set(recipient_ids)) or set(recipient_ids) != audience:
        raise HTTPException(
            status_code=409,
            detail="L'audience a changé. Rechargez-la puis chiffrez à nouveau le statut.",
        )
    if any(not recipient.valid_e2ee_payload() for recipient in payload.recipients):
        raise HTTPException(status_code=400, detail="Enveloppe E2EE de statut invalide")
    if user_id in recipient_ids:
        raise HTTPException(status_code=400, detail="L'auteur ne doit pas être un destinataire E2EE")

    media_asset = None
    if content_type == StatusContentType.TEXT:
        if payload.media_asset_id is not None:
            raise HTTPException(status_code=400, detail="Un statut texte ne peut pas avoir de pièce jointe")
    else:
        if not payload.media_asset_id:
            raise HTTPException(status_code=400, detail="Une pièce jointe est requise pour ce type de statut")
        media_asset = db.query(MediaAsset).filter(MediaAsset.id == payload.media_asset_id).first()
        if not media_asset or media_asset.uploader_id != user_id:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")
        if (
            media_asset.mime_type != "application/octet-stream"
            or media_asset.original_filename != "pokou.bin"
            or media_asset.size_bytes < 16
        ):
            raise HTTPException(status_code=400, detail="Le média du statut doit être chiffré et opaque")

    now = datetime.utcnow()
    status_row = Status(
        user_id=user_id,
        content_type=content_type,
        background_color=payload.background_color or "#3F6212",
        media_asset_id=media_asset.id if media_asset else None,
        created_at=now,
        expires_at=now + timedelta(hours=24),
    )
    db.add(status_row)
    db.flush()
    for recipient in payload.recipients:
        db.add(
            StatusRecipient(
                status_id=status_row.id,
                recipient_id=recipient.user_id,
                encryption=recipient.encryption,
                ciphertext=recipient.ciphertext,
                envelope=recipient.envelope,
            )
        )
    db.commit()
    db.refresh(status_row)

    serialized = _serialize_status(status_row, viewed_by_me=False, view_count=0)
    await _announce_status(db, current_user, status_row, serialized)
    return serialized


@router.get("/audience")
async def status_audience(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Return the exact current feed audience, for client-side E2EE wrapping."""
    user_id = current_user["user_id"]
    return {
        "author_id": user_id,
        "recipient_ids": sorted(status_privacy_service.viewer_ids_for(db, user_id)),
    }




async def _announce_status(db: Session, current_user: dict, status_row: Status, serialized: dict) -> None:
    """Pousse le statut à ceux qui ont le droit de le voir.

    Sans ça, « Actualités » n'était rafraîchi qu'à l'ouverture de l'onglet ou
    au tirer-pour-rafraîchir : un statut publié restait invisible pour tout
    le monde tant que personne ne pensait à recharger. C'est le seul pan de
    l'application qui n'avait aucune poussée temps réel, alors que c'est
    précisément celui qu'on regarde sans rien demander.

    On n'envoie que l'anneau à rallumer, pas le contenu : le client relit son
    fil, ce qui lui applique au passage les filtres de confidentialité et les
    « déjà vus » calculés côté serveur. Pousser le statut lui-même dupliquerait
    cette logique dans le client, où elle finirait par diverger.

    Best-effort, comme toute poussée : un statut existe en base et sera lu au
    prochain chargement même si le socket est tombé.
    """
    try:
        viewers = status_privacy_service.viewer_ids_for(db, status_row.user_id)
        if not viewers:
            return
        author = db.query(User).filter(User.id == status_row.user_id).first()
        event = {
            "type": "status:new",
            "user_id": status_row.user_id,
            "display_name": (author.full_name or author.phone or "Utilisateur") if author else None,
            "status_id": status_row.id,
        }
        for viewer_id in viewers:
            await manager.send_to_user(viewer_id, event)
    except Exception:  # noqa: BLE001 — voir docstring
        logger.warning("Pokou: annonce de statut impossible (%s)", status_row.id, exc_info=True)


@router.get("/feed")
async def get_feed(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    now = datetime.utcnow()

    # Candidats : les gens que je connais, plus moi. Le filtre décisif vient
    # ensuite — c'est l'AUTEUR qui choisit son public, pas moi (voir
    # status_privacy_service).
    contact_ids = [
        row[0]
        for row in db.query(Contact.contact_user_id)
        .filter(Contact.owner_user_id == user_id, Contact.contact_user_id.isnot(None))
        .all()
    ]
    visible_user_ids = status_privacy_service.visible_author_ids(
        db, user_id, set(contact_ids)
    ) | {user_id}

    statuses = (
        db.query(Status)
        .filter(Status.user_id.in_(visible_user_ids), Status.expires_at > now)
        .order_by(Status.user_id, Status.created_at.asc())
        .all()
    )
    recipient_rows = (
        db.query(StatusRecipient)
        .filter(
            StatusRecipient.status_id.in_([status.id for status in statuses] or [""]),
            StatusRecipient.recipient_id == user_id,
        )
        .all()
    )
    recipient_content = {row.status_id: row for row in recipient_rows}
    statuses = [
        status for status in statuses
        if status.user_id == user_id or status.id in recipient_content
    ]
    boosted_status_ids = {
        row[0]
        for row in db.query(MarketplaceBoost.status_id)
        .filter(
            MarketplaceBoost.status_id.isnot(None),
            MarketplaceBoost.starts_at <= now,
            MarketplaceBoost.expires_at > now,
        )
        .all()
    }
    statuses.sort(key=lambda item: (item.id not in boosted_status_ids, item.created_at))

    status_ids = [s.id for s in statuses]
    views = db.query(StatusView).filter(StatusView.status_id.in_(status_ids)).all() if status_ids else []
    viewed_by_me_ids = {v.status_id for v in views if v.viewer_id == user_id}
    view_counts: dict[str, int] = {}
    for v in views:
        view_counts[v.status_id] = view_counts.get(v.status_id, 0) + 1

    grouped: dict[int, list[dict]] = {}
    for status_row in statuses:
        grouped.setdefault(status_row.user_id, []).append(
            _serialize_status(
                status_row,
                viewed_by_me=status_row.id in viewed_by_me_ids,
                view_count=view_counts.get(status_row.id, 0),
                encrypted_content=recipient_content.get(status_row.id),
            )
        )

    author_ids = list(grouped.keys())
    authors = {u.id: u for u in db.query(User).filter(User.id.in_(author_ids)).all()} if author_ids else {}
    # Sous le nom de MON carnet, comme partout — sauf compte certifié (voir
    # utils/identity.py::nom_affiche). Le fil affichait le nom choisi par
    # l'auteur, si bien qu'un contact n'y portait pas le même nom que dans
    # les discussions.
    feed_petnames = {
        row.contact_user_id: row.display_name
        for row in db.query(Contact).filter(
            Contact.owner_user_id == user_id,
            Contact.contact_user_id.in_(author_ids or [0]),
        ).all()
    }

    items = [
        {
            "user_id": author_id,
            "display_name": nom_affiche(authors[author_id], feed_petnames.get(author_id)),
            "is_verified": est_certifie(authors[author_id]),
            "avatar": _serialize_avatar(authors[author_id].avatar_media),
            "statuses": entries,
        }
        for author_id, entries in grouped.items()
    ]
    return {"items": items}


class StatusPrivacyUpdate(BaseModel):
    mode: str
    # Exclusions en mode EXCEPT, autorisations en mode ONLY ; ignoré sinon.
    user_ids: List[int] = Field(default_factory=list)


@router.get("/privacy")
async def get_status_privacy(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return status_privacy_service.get_privacy(db, current_user["user_id"])


@router.put("/privacy")
async def update_status_privacy(
    payload: StatusPrivacyUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    mode = payload.mode.upper()
    if mode not in status_privacy_service.VALID_MODES:
        raise HTTPException(
            status_code=400,
            detail=f"Mode invalide — attendu l'un de : {', '.join(status_privacy_service.VALID_MODES)}",
        )
    return status_privacy_service.set_privacy(db, current_user["user_id"], mode, payload.user_ids)


@router.get("/{status_id}/views")
async def list_status_viewers(
    status_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Qui a vu MON statut, et quand. Réservé à l'AUTEUR : savoir qui regarde
    le statut de quelqu'un d'autre n'est le droit de personne (c'est aussi la
    règle de WhatsApp).

    404 et non 403 pour le statut d'autrui : répondre « interdit »
    confirmerait qu'un statut existe derrière cet identifiant."""
    user_id = current_user["user_id"]
    status_row = db.query(Status).filter(Status.id == status_id, Status.user_id == user_id).first()
    if not status_row:
        raise HTTPException(status_code=404, detail="Statut introuvable")

    views = (
        db.query(StatusView)
        .options(joinedload(StatusView.viewer))
        .filter(StatusView.status_id == status_id)
        .order_by(StatusView.viewed_at.desc())
        .all()
    )
    # Le nom du carnet d'adresses de l'AUTEUR l'emporte sur celui que le
    # spectateur s'est choisi — c'est sous ce nom que l'auteur le reconnaît.
    petnames = {
        row.contact_user_id: row.display_name
        for row in db.query(Contact).filter(
            Contact.owner_user_id == user_id,
            Contact.contact_user_id.in_([view.viewer_id for view in views] or [0]),
        ).all()
    }
    return {
        "status_id": status_id,
        "view_count": len(views),
        "items": [
            {
                "viewer_id": view.viewer_id,
                "display_name": nom_affiche(view.viewer, petnames.get(view.viewer_id)),
                "avatar": _serialize_avatar(view.viewer.avatar_media) if view.viewer else None,
                "viewed_at": view.viewed_at.isoformat(),
            }
            for view in views
        ],
    }


@router.delete("/{status_id}")
async def delete_status(
    status_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Retirer son statut avant les 24 h.

    Il n'existait aucun moyen de le faire : une photo publiée avec le
    mauvais prix restait visible une journée entière. Réservé à l'AUTEUR ;
    404 et non 403 pour celui d'un autre, comme `/views` — répondre
    « interdit » confirmerait qu'un statut existe derrière cet identifiant.

    Le média n'est pas effacé ici : il peut être partagé ailleurs, et la
    purge horaire sait déjà quand il ne l'est plus. Sans statut, personne
    d'autre que son auteur ne peut plus l'ouvrir."""
    user_id = current_user["user_id"]
    status_row = db.query(Status).filter(Status.id == status_id, Status.user_id == user_id).first()
    if not status_row:
        raise HTTPException(status_code=404, detail="Statut introuvable")

    viewers = status_privacy_service.viewer_ids_for(db, user_id)
    db.delete(status_row)
    db.commit()

    # Même poussée que la publication : les fils ouverts se relisent, et
    # l'anneau s'éteint si c'était le seul statut non vu.
    event = {"type": "status:deleted", "user_id": user_id, "status_id": status_id}
    for viewer_id in viewers or []:
        try:
            await manager.send_to_user(viewer_id, event)
        except Exception:  # noqa: BLE001 — best-effort, comme l'annonce
            logger.warning("Pokou: retrait de statut non annoncé (%s)", status_id, exc_info=True)
    return {"ok": True}


@router.post("/{status_id}/view")
async def view_status(
    status_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    status_row = db.query(Status).filter(Status.id == status_id, Status.expires_at > datetime.utcnow()).first()
    if not status_row:
        raise HTTPException(status_code=404, detail="Statut introuvable ou expiré")

    if status_row.user_id == user_id:
        return {"ok": True}

    if not status_privacy_service.can_view_statuses_of(db, status_row.user_id, user_id):
        raise HTTPException(status_code=404, detail="Statut introuvable")
    if not db.query(StatusRecipient.id).filter(
        StatusRecipient.status_id == status_id,
        StatusRecipient.recipient_id == user_id,
    ).first():
        raise HTTPException(status_code=404, detail="Statut introuvable")

    existing = db.query(StatusView).filter(
        StatusView.status_id == status_id, StatusView.viewer_id == user_id
    ).first()
    if not existing:
        db.add(StatusView(status_id=status_id, viewer_id=user_id, viewed_at=datetime.utcnow()))
        db.commit()
    return {"ok": True}
