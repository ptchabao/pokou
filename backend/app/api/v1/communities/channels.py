"""Pokou public channels: creation, editing, subscriptions and invitations."""
import logging
import secrets
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.api.v1.messaging.ws import manager
from app.utils.editing import MESSAGE_EDIT_WINDOW
from app.models import Channel, ChannelCertificationApplication, ChannelMember, ChannelPost, ChannelPostReaction, ChannelPostView, MarketplacePayment, MediaAsset, Poll, PollOption, User, UserRole
# Sondages : la table `polls` et sa route de vote servent aussi aux chaînes.
# `_clean_options` (bornes 2..12, options vides retirées) et `_serialize_poll`
# sont importés plutôt que recopiés — deux validations divergentes du même
# objet finiraient par ne plus dire la même chose. Ce sont des helpers de
# FORME, pas d'autorisation : celle des chaînes reste entièrement ici.
from app.api.v1.messaging.polls import _clean_options, _serialize_poll
from app.api.v1.marketplace.marketplace import _payment_json
from app.services.marketplace.marketplace_monetization_service import channel_certification_terms, create_payment
from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/channels", tags=["Pokou channels"])
_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]


class ChannelCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    #: Privée : introuvable par la recherche, illisible sans abonnement, et
    #: accessible par le seul lien d'invitation. Faux par défaut — une
    #: chaîne créée sans y penser reste ce qu'elle a toujours été.
    is_private: bool = False


class ChannelUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    avatar_media_id: Optional[int] = None
    clear_avatar: bool = False


class ChannelCertification(BaseModel):
    verified: bool


class ChannelPollCreate(BaseModel):
    question: str = Field(..., min_length=1, max_length=500)
    options: List[str] = Field(default_factory=list)
    allows_multiple: bool = False


class ChannelPostCreate(BaseModel):
    text_content: Optional[str] = Field(None, max_length=4000)
    media_asset_id: Optional[int] = None
    # Un sondage EST une publication (il défile dans le fil, se compte en
    # vues, se réagit, se supprime) — d'où un champ ici plutôt qu'une route
    # séparée qui aurait à recopier les droits de publication.
    poll: Optional[ChannelPollCreate] = None


class ChannelPostEdit(BaseModel):
    text_content: str = Field(..., min_length=1, max_length=4000)


class ChannelReaction(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=16)


class ChannelRole(BaseModel):
    role: str = Field(..., pattern="^(ADMIN|FOLLOWER)$")


_ADMIN_ROLE = "ADMIN"

# Fenêtre de modification d'une publication, alignée sur celle des messages
# (voir messages.py::EDIT_WINDOW) : la même promesse partout.
_EDIT_WINDOW = MESSAGE_EDIT_WINDOW


def _new_code() -> str:
    return secrets.token_urlsafe(12)[:16]


def _serialize(channel: Channel, viewer_id: int) -> dict:
    membership = next((m for m in channel.members if m.user_id == viewer_id), None)
    avatar = channel.avatar_media
    return {
        "id": channel.id,
        "name": channel.name,
        "description": channel.description,
        "avatar": {
            "id": avatar.id,
            "mime_type": avatar.mime_type,
            "size_bytes": avatar.size_bytes,
            "original_filename": avatar.original_filename,
        } if avatar else None,
        "created_by": channel.created_by,
        "is_owner": channel.created_by == viewer_id,
        "is_private": bool(channel.is_private),
        "is_following": membership is not None,
        # Le créateur est bien membre (sa chaîne figure dans sa liste) mais
        # n'est pas son propre PUBLIC : l'exclure rend le compteur honnête —
        # une chaîne neuve annonce « 0 abonné » et non « 1 ».
        "follower_count": sum(1 for m in channel.members if m.user_id != channel.created_by),
        "invite_code": channel.invite_code if channel.created_by == viewer_id else None,
        # Un abonnement échu n'affiche plus le badge, sans qu'aucune tâche
        # de fond n'ait eu à repasser l'éteindre.
        "is_verified": _certification_active(channel),
        "verified_until": channel.verified_until.isoformat()
        if channel.verified_until
        else None,
        # L'écran a besoin de savoir s'il doit proposer « Publier » et
        # « Modifier » — le rôle vient du serveur, jamais déduit côté client.
        "is_admin": _is_admin(channel, viewer_id),
        "post_count": len(channel.posts),
    }


def _certification_active(channel: Channel) -> bool:
    if not channel.is_verified:
        return False
    # Sans échéance : une certification posée avant l'arrivée des
    # abonnements (à la main, en base). On la laisse valable plutôt que de
    # retirer silencieusement un badge que quelqu'un a déjà accordé.
    if channel.verified_until is None:
        return True
    return channel.verified_until > datetime.utcnow()


def _get(db: Session, channel_id: int) -> Channel:
    channel = db.query(Channel).filter(Channel.id == channel_id).first()
    if not channel:
        raise HTTPException(status_code=404, detail="Chaîne introuvable")
    return channel


def _is_admin(channel: Channel, user_id: int) -> bool:
    """Créateur ou membre promu ADMIN. Le créateur l'est TOUJOURS, sans
    dépendre d'une ligne ChannelMember : il ne doit pas pouvoir se retirer
    ses propres droits en se désabonnant de sa chaîne."""
    if channel.created_by == user_id:
        return True
    membership = next((m for m in channel.members if m.user_id == user_id), None)
    return membership is not None and membership.role == _ADMIN_ROLE


def _require_admin(channel: Channel, user_id: int) -> None:
    if not _is_admin(channel, user_id):
        raise HTTPException(
            status_code=403, detail="Seuls le créateur et les admins peuvent publier ou modifier"
        )


def _serialize_post(post: ChannelPost, viewer_id: int) -> dict:
    """Réactions agrégées par emoji, avec `mine` : c'est ce qui permet à
    l'écran de surligner celle qu'on a posée sans comparer des listes."""
    grouped: dict[str, list[int]] = {}
    for reaction in post.reactions:
        grouped.setdefault(reaction.emoji, []).append(reaction.user_id)
    media = post.media_asset
    return {
        "id": post.id,
        "channel_id": post.channel_id,
        "author_id": post.author_id,
        "author_name": (post.author.full_name or post.author.phone or "Chaîne") if post.author else "Chaîne",
        "text_content": post.text_content,
        "media": {
            "id": media.id,
            "mime_type": media.mime_type,
            "size_bytes": media.size_bytes,
            "original_filename": media.original_filename,
        } if media else None,
        # reveal_voters=False : sur une chaîne publique, qui a voté quoi ne
        # se publie pas — voir polls.py::_serialize_poll.
        "poll": _serialize_poll(post.poll, viewer_id, reveal_voters=False) if post.poll else None,
        "created_at": post.created_at.isoformat(),
        "edited_at": post.edited_at.isoformat() if post.edited_at else None,
        "view_count": len(post.views),
        "reactions": [
            {
                "emoji": emoji,
                "count": len(user_ids),
                "mine": viewer_id in user_ids,
            }
            for emoji, user_ids in grouped.items()
        ],
    }


def _post_load_options():
    """Sérialiser une publication touche son auteur, sa pièce jointe, ses
    réactions et ses vues — sans chargement anticipé, une page de 30
    publications coûte une centaine de requêtes de plus."""
    return (
        joinedload(ChannelPost.author),
        joinedload(ChannelPost.media_asset),
        selectinload(ChannelPost.reactions),
        selectinload(ChannelPost.views),
        # Le sondage, ses options ET les votes de chaque option : sérialiser
        # un sondage compte les voix, donc les traverse toutes.
        joinedload(ChannelPost.poll).selectinload(Poll.options).selectinload(PollOption.votes),
    )


def _abonne(db: Session, channel_id: int, user_id: int) -> bool:
    return (
        db.query(ChannelMember.id)
        .filter(
            ChannelMember.channel_id == channel_id,
            ChannelMember.user_id == user_id,
        )
        .first()
        is not None
    )


def _exiger_acces(db: Session, channel: Channel, user_id: int) -> None:
    """Une chaîne privée ne se lit pas sans y être abonné.

    404 et non 403, délibérément : une chaîne privée doit être INTROUVABLE,
    pas « trouvable mais interdite ». Un 403 confirmerait son existence à
    qui essaie des identifiants, et le nom d'une chaîne privée en dit déjà
    beaucoup — « Prix grossistes Adidogomé » se devine mal, mais se
    confirme vite.
    """
    if not channel.is_private:
        return
    if not _abonne(db, channel.id, user_id):
        raise HTTPException(status_code=404, detail="Chaîne introuvable")


@router.post("")
async def create_channel(payload: ChannelCreate, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    channel = Channel(
        name=payload.name.strip(),
        description=payload.description.strip() if payload.description else None,
        created_by=user_id,
        is_private=bool(payload.is_private),
        # Le lien est créé D'EMBLÉE pour une chaîne privée : c'est sa seule
        # porte d'entrée, et devoir le générer après coup ferait une chaîne
        # que personne ne peut rejoindre — y compris ceux qu'on venait
        # d'inviter de vive voix.
        invite_code=_new_code(),
    )
    db.add(channel)
    db.flush()
    db.add(ChannelMember(channel_id=channel.id, user_id=user_id, role="OWNER"))
    db.commit()
    db.refresh(channel)
    return _serialize(channel, user_id)


@router.get("")
async def list_channels(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    channels = db.query(Channel).join(ChannelMember).filter(ChannelMember.user_id == user_id).order_by(Channel.name).all()
    return {"items": [_serialize(channel, user_id) for channel in channels]}


@router.patch("/{channel_id}")
async def update_channel(channel_id: int, payload: ChannelUpdate, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    if channel.created_by != user_id:
        raise HTTPException(status_code=403, detail="Seul le propriétaire peut modifier cette chaîne")
    if payload.name is not None:
        channel.name = payload.name.strip()
    if payload.description is not None:
        channel.description = payload.description.strip() or None
    if payload.clear_avatar:
        channel.avatar_media_id = None
    elif payload.avatar_media_id is not None:
        if not db.query(MediaAsset).filter(MediaAsset.id == payload.avatar_media_id).first():
            raise HTTPException(status_code=404, detail="Média introuvable")
        channel.avatar_media_id = payload.avatar_media_id
    db.commit()
    db.refresh(channel)
    return _serialize(channel, user_id)


@router.post("/{channel_id}/invite-link")
async def regenerate_invite(channel_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    channel = _get(db, channel_id)
    if channel.created_by != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Seul le propriétaire peut gérer le lien")
    channel.invite_code = _new_code()
    db.commit()
    return {"invite_code": channel.invite_code}


@router.get("/invite/{code}")
async def preview_invite(code: str, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    channel = db.query(Channel).filter(Channel.invite_code == code).first()
    if not channel:
        raise HTTPException(status_code=404, detail="Lien de chaîne invalide")
    return {"id": channel.id, "name": channel.name, "description": channel.description, "follower_count": len(channel.members), "is_verified": channel.is_verified}


@router.post("/invite/{code}/join")
async def join_invite(code: str, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    channel = db.query(Channel).filter(Channel.invite_code == code).first()
    if not channel:
        raise HTTPException(status_code=404, detail="Lien de chaîne invalide")
    if not db.query(ChannelMember).filter(ChannelMember.channel_id == channel.id, ChannelMember.user_id == user_id).first():
        db.add(ChannelMember(channel_id=channel.id, user_id=user_id, role="FOLLOWER"))
        db.commit()
    db.refresh(channel)
    return _serialize(channel, user_id)


@router.put("/{channel_id}/certification")
async def certify_channel(channel_id: int, payload: ChannelCertification, db: Session = Depends(get_db), current_user: dict = Depends(require_admin_role(_TEAM_ROLES))):
    """Accorder ou retirer le badge à la main, sans dossier ni paiement.

    La porte de service, et elle a sa raison d'être : un partenaire, une
    institution, une chaîne qu'on veut certifier sans lui faire remplir un
    formulaire. Elle accorde SANS ÉCHÉANCE — c'est la différence avec
    l'abonnement (voir review_certification), et c'est voulu : une
    certification offerte ne doit pas s'éteindre sans que personne ne s'en
    aperçoive.

    Retirer le badge efface aussi l'échéance : sans cela, un abonnement
    révoqué se rallumerait à la lecture tant que sa date n'est pas passée.
    """
    channel = _get(db, channel_id)
    channel.is_verified = payload.verified
    channel.verified_at = datetime.utcnow() if payload.verified else None
    if not payload.verified:
        channel.verified_until = None
    db.commit()
    return {"id": channel.id, "is_verified": channel.is_verified}


# ─── Découverte : recherche et abonnement ─────────────────────────────────────

class CertificationRequest(BaseModel):
    #: MONTHLY ou ANNUAL. Le montant et la durée en découlent côté serveur —
    #: le client ne propose jamais de prix.
    plan: str = Field(default="MONTHLY")


class CertificationReview(BaseModel):
    approved: bool
    note: Optional[str] = Field(default=None, max_length=500)


@router.post("/{channel_id}/certification")
async def request_certification(
    channel_id: int,
    payload: CertificationRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Demander le badge pour sa chaîne, contre un abonnement.

    Payer n'accorde PAS le badge : le paiement ouvre un dossier, l'équipe
    tranche. Un badge qui s'achète sans regard ne vaut rien — et c'est
    précisément parce qu'il désigne ce qui est fiable qu'il doit pouvoir
    être refusé.
    """
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    if channel.created_by != user_id:
        raise HTTPException(
            status_code=403, detail="Seul le propriétaire peut demander la certification"
        )
    # Une chaîne DÉJÀ certifiée peut redemander : c'est un renouvellement,
    # et l'approbation prolonge au lieu de remplacer (voir
    # review_certification). Le refuser obligerait à laisser le badge
    # expirer avant de pouvoir le reprendre — soit une coupure volontaire
    # au milieu d'un abonnement qu'on veut poursuivre.
    if (
        db.query(ChannelCertificationApplication)
        .filter(
            ChannelCertificationApplication.channel_id == channel_id,
            ChannelCertificationApplication.status == "PENDING",
        )
        .first()
    ):
        raise HTTPException(status_code=409, detail="Une demande est déjà en attente")

    try:
        amount, _days = channel_certification_terms(payload.plan)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    user = db.query(User).filter(User.id == user_id).first()
    try:
        payment = create_payment(
            db,
            user,
            kind="CHANNEL_CERTIFICATION",
            amount=amount,
            description=f"Chaîne certifiée — {channel.name}",
            metadata={},
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    application = ChannelCertificationApplication(
        channel_id=channel.id,
        requested_by=user_id,
        plan=payload.plan,
        payment_id=payment.id,
    )
    db.add(application)
    db.flush()
    payment.metadata_json = {"certification_application_id": application.id}
    db.commit()
    return {
        "application_id": application.id,
        "status": application.status,
        "plan": application.plan,
        "amount": amount,
        **_payment_json(payment),
    }


@router.get("/certifications")
async def list_certifications(
    status: str = Query("PENDING"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Les dossiers à examiner, pour l'écran d'administration."""
    applications = (
        db.query(ChannelCertificationApplication)
        .options(
            joinedload(ChannelCertificationApplication.channel),
            joinedload(ChannelCertificationApplication.requester),
        )
        .filter(ChannelCertificationApplication.status == status.upper())
        .order_by(ChannelCertificationApplication.created_at.desc())
        .limit(200)
        .all()
    )
    payments = {
        payment.id: payment
        for payment in db.query(MarketplacePayment).filter(
            MarketplacePayment.id.in_([application.payment_id for application in applications])
        ).all()
    } if applications else {}
    return {
        "items": [
            {
                "id": application.id,
                "channel_id": application.channel_id,
                "channel_name": application.channel.name if application.channel else None,
                "channel_description": application.channel.description
                if application.channel
                else None,
                "follower_count": sum(
                    1
                    for member in (application.channel.members if application.channel else [])
                    if member.user_id != application.channel.created_by
                ),
                "requested_by": application.requested_by,
                "requester_name": application.requester.full_name
                if application.requester
                else None,
                "requester_phone": application.requester.phone
                if application.requester
                else None,
                "plan": application.plan,
                "status": application.status,
                "payment_status": payments[application.payment_id].status
                if application.payment_id in payments
                else None,
                "is_verified": bool(application.channel.is_verified)
                if application.channel
                else False,
                "verified_until": application.channel.verified_until.isoformat()
                if application.channel and application.channel.verified_until
                else None,
                "created_at": application.created_at.isoformat(),
                "reviewed_at": application.reviewed_at.isoformat()
                if application.reviewed_at
                else None,
                "review_note": application.review_note,
            }
            for application in applications
        ]
    }


@router.put("/certifications/{application_id}")
async def review_certification(
    application_id: int,
    payload: CertificationReview,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Accorder ou refuser le badge.

    L'échéance part de MAINTENANT et non de la demande : un dossier examiné
    trois jours après avoir été payé ne doit pas amputer l'abonnement de ces
    trois jours. Une certification encore valable est PROLONGÉE plutôt que
    remplacée — renouveler avant l'échéance ne doit pas faire perdre le
    reliquat.
    """
    application = (
        db.query(ChannelCertificationApplication)
        .filter(ChannelCertificationApplication.id == application_id)
        .first()
    )
    if not application:
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    if application.status != "PENDING":
        raise HTTPException(status_code=409, detail="Ce dossier a déjà été examiné")
    payment = db.query(MarketplacePayment).filter(
        MarketplacePayment.id == application.payment_id
    ).first()
    if payload.approved and (payment is None or payment.status != "CONFIRMED"):
        raise HTTPException(
            status_code=409,
            detail="Le paiement doit être confirmé avant l'approbation",
        )

    application.status = "APPROVED" if payload.approved else "REJECTED"
    application.reviewer_id = current_user["user_id"]
    application.review_note = payload.note
    application.reviewed_at = datetime.utcnow()

    channel = _get(db, application.channel_id)
    if payload.approved:
        _, days = channel_certification_terms(application.plan)
        now = datetime.utcnow()
        start = (
            channel.verified_until
            if channel.verified_until and channel.verified_until > now
            else now
        )
        channel.is_verified = True
        channel.verified_at = channel.verified_at or now
        channel.verified_until = start + timedelta(days=days)
    db.commit()
    return {
        "application_id": application.id,
        "status": application.status,
        "channel_id": channel.id,
        "verified_until": channel.verified_until.isoformat()
        if channel.verified_until
        else None,
    }


@router.get("/suggested")
async def suggested_channels(
    limit: int = Query(6, ge=1, le=20),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Quelques chaînes à suivre, pour quelqu'un qui n'en suit aucune.

    Un écran vide ne dit pas quoi faire. « Créez une chaîne pour partager
    vos actualités » s'adresse à celui qui veut PUBLIER, alors que la
    plupart des gens arrivent pour LIRE — et repartent sans rien avoir
    trouvé, faute d'un point d'entrée.

    Le classement met les chaînes certifiées en tête, puis les plus
    suivies : dans une application neuve, le nombre d'abonnés est un signal
    faible, et la certification est la seule garantie qu'on ne recommande
    pas n'importe quoi à quelqu'un qui découvre.

    Les chaînes déjà suivies sont exclues — recommander ce qu'on lit déjà
    ferait douter que la suggestion regarde quoi que ce soit. Celles dont
    on est propriétaire aussi : on ne se suggère pas à soi-même.
    """
    user_id = current_user["user_id"]
    already = select(ChannelMember.channel_id).where(ChannelMember.user_id == user_id)
    follower_count = (
        select(func.count(ChannelMember.id))
        .where(ChannelMember.channel_id == Channel.id)
        .correlate(Channel)
        .scalar_subquery()
    )
    channels = (
        db.query(Channel)
        .options(selectinload(Channel.members), selectinload(Channel.posts))
        .filter(
            Channel.id.notin_(already),
            Channel.created_by != user_id,
            # Une chaîne privée ne se SUGGÈRE pas : la suggérer reviendrait
            # à en révéler l'existence et le nom à des gens qui n'y ont
            # aucun accès.
            Channel.is_private.is_(False),
        )
        .order_by(Channel.is_verified.desc(), follower_count.desc(), Channel.name)
        .limit(limit)
        .all()
    )
    return {"items": [_serialize(channel, user_id) for channel in channels]}


@router.get("/search")
async def search_channels(
    q: str = Query(..., min_length=1, max_length=120),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Recherche par nom ou description. Une chaîne est PUBLIQUE : on la
    trouve et on la lit sans y être abonné — c'est ce qui distingue une
    chaîne d'un groupe, dont l'existence même n'est pas consultable."""
    # Jokers ÉCHAPPÉS : sinon chercher « 100% » ramènerait toutes les chaînes.
    needle = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    pattern = f"%{needle}%"
    channels = (
        db.query(Channel)
        .options(selectinload(Channel.members), selectinload(Channel.posts))
        .filter(
            or_(
                Channel.name.ilike(pattern, escape="\\"),
                Channel.description.ilike(pattern, escape="\\"),
            ),
            # Introuvable, c'est le sens même du mot « privée ». Sans cette
            # ligne, `is_private` n'aurait fermé que la lecture — et le nom
            # d'une chaîne en dit déjà beaucoup.
            Channel.is_private.is_(False),
        )
        # Les chaînes certifiées d'abord, puis les plus suivies : une
        # recherche doit remonter ce qui est fiable avant ce qui est obscur.
        .order_by(Channel.is_verified.desc(), Channel.name)
        .limit(50)
        .all()
    )
    return {"items": [_serialize(channel, current_user["user_id"]) for channel in channels]}


@router.post("/{channel_id}/follow")
async def follow_channel(
    channel_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """S'abonner sans lien d'invitation. Idempotent : rejouer la requête ne
    crée pas un second abonnement.

    Refusé sur une chaîne PRIVÉE : son lien est sa seule porte. Sans ce
    contrôle, `is_private` n'aurait fermé que la vitrine — il suffirait de
    connaître un identifiant pour entrer, et les identifiants sont des
    entiers consécutifs.
    """
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    if channel.is_private and not _abonne(db, channel_id, user_id):
        raise HTTPException(status_code=404, detail="Chaîne introuvable")
    existing = db.query(ChannelMember).filter(
        ChannelMember.channel_id == channel_id, ChannelMember.user_id == user_id
    ).first()
    if existing is None:
        db.add(ChannelMember(channel_id=channel_id, user_id=user_id, role="FOLLOWER"))
        db.commit()
        db.refresh(channel)
    return _serialize(channel, user_id)


@router.delete("/{channel_id}/follow")
async def unfollow_channel(
    channel_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    membership = db.query(ChannelMember).filter(
        ChannelMember.channel_id == channel_id, ChannelMember.user_id == user_id
    ).first()
    if membership is not None:
        db.delete(membership)
        db.commit()
        db.refresh(channel)
    # Le créateur reste admin même désabonné (voir _is_admin) : il ne doit
    # pas perdre sa chaîne en quittant sa propre liste de lecture.
    return _serialize(channel, user_id)


@router.put("/{channel_id}/members/{user_id}/role")
async def set_member_role(
    channel_id: int,
    user_id: int,
    payload: ChannelRole,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Promouvoir un abonné admin (il pourra publier), ou le rétrograder.
    Réservé au CRÉATEUR : un admin qui pourrait nommer d'autres admins
    rendrait la propriété de la chaîne diluable sans le consentement de son
    créateur."""
    channel = _get(db, channel_id)
    if channel.created_by != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Seul le créateur gère les admins")
    if user_id == channel.created_by:
        raise HTTPException(status_code=400, detail="Le créateur est admin par nature")
    membership = db.query(ChannelMember).filter(
        ChannelMember.channel_id == channel_id, ChannelMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=404, detail="Cette personne ne suit pas la chaîne")
    membership.role = payload.role
    db.commit()
    db.refresh(channel)
    return _serialize(channel, current_user["user_id"])


# ─── Publications ─────────────────────────────────────────────────────────────

@router.get("/{channel_id}/posts")
async def list_posts(
    channel_id: int,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le fil d'une chaîne, du plus récent au plus ancien.

    Lisible SANS être abonné tant que la chaîne est publique : on juge une
    chaîne sur son contenu avant de la suivre. Une chaîne PRIVÉE, elle, ne
    se lit pas de l'extérieur — c'est le sens du mot.
    """
    _exiger_acces(db, _get(db, channel_id), current_user["user_id"])
    posts = (
        db.query(ChannelPost)
        .options(*_post_load_options())
        .filter(ChannelPost.channel_id == channel_id)
        .order_by(ChannelPost.created_at.desc())
        .limit(limit)
        .all()
    )
    return {"items": [_serialize_post(post, current_user["user_id"]) for post in posts]}


async def _announce_post(db: Session, channel: Channel, post: ChannelPost) -> None:
    """Prévient les abonnés qu'une publication est arrivée.

    Une chaîne se consulte comme un fil d'information : on l'ouvre pour voir
    ce qu'il y a de neuf. Sans poussée, « de neuf » voulait dire « depuis le
    dernier tirer-pour-rafraîchir », ce qui vide une chaîne de son intérêt —
    l'annonce d'un arrivage arrive quand le client pense à recharger.

    On ne pousse que l'existence, pas le contenu : le client relit la
    chaîne, ce qui lui applique ses droits de lecture et son compteur de
    non-lus sans que cette logique ait à exister en double.

    Best-effort : la publication est en base, elle sera lue au prochain
    chargement même si le socket est tombé. On saute l'auteur, qui a déjà
    l'état à jour dans sa réponse HTTP.
    """
    try:
        follower_ids = [
            row[0]
            for row in db.query(ChannelMember.user_id)
            .filter(ChannelMember.channel_id == channel.id, ChannelMember.user_id != post.author_id)
            .all()
        ]
        if not follower_ids:
            return
        event = {
            "type": "channel:post",
            "channel_id": channel.id,
            "channel_name": channel.name,
            "post_id": post.id,
        }
        for follower_id in follower_ids:
            await manager.send_to_user(follower_id, event)
    except Exception:  # noqa: BLE001 — voir docstring
        logger.warning("Pokou: annonce de publication impossible (%s)", post.id, exc_info=True)


@router.post("/{channel_id}/posts")
async def create_post(
    channel_id: int,
    payload: ChannelPostCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    _require_admin(channel, user_id)

    has_text = bool(payload.text_content and payload.text_content.strip())
    if not has_text and payload.media_asset_id is None and payload.poll is None:
        raise HTTPException(
            status_code=400,
            detail="Une publication a besoin d'un texte, d'une pièce jointe ou d'un sondage",
        )
    if payload.media_asset_id is not None:
        # Sa propre pièce jointe seulement : sinon connaître l'id d'un média
        # d'autrui suffirait à le diffuser à tous les abonnés.
        asset = db.query(MediaAsset).filter(
            MediaAsset.id == payload.media_asset_id, MediaAsset.uploader_id == user_id
        ).first()
        if not asset:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")

    poll: Optional[Poll] = None
    if payload.poll is not None:
        question = payload.poll.question.strip()
        if not question:
            raise HTTPException(status_code=400, detail="La question du sondage est requise")
        # Bornes et nettoyage des options délégués à polls.py : mêmes règles
        # dans une chaîne que dans une conversation.
        options = _clean_options(payload.poll.options)
        poll = Poll(
            question=question,
            allows_multiple=payload.poll.allows_multiple,
            created_by=user_id,
        )
        db.add(poll)
        db.flush()  # besoin de poll.id pour les options et la publication
        for position, text in enumerate(options):
            db.add(PollOption(poll_id=poll.id, text=text, position=position))
        # Flush et non commit : sondage, options et publication partent dans
        # la MÊME transaction. Valider ici laisserait un sondage orphelin,
        # invisible de tous, si l'écriture de la publication échouait.
        db.flush()

    post = ChannelPost(
        channel_id=channel_id,
        author_id=user_id,
        text_content=payload.text_content.strip() if has_text else None,
        media_asset_id=payload.media_asset_id,
        poll_id=poll.id if poll is not None else None,
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    serialized = _serialize_post(post, user_id)
    await _announce_post(db, channel, post)
    return serialized


@router.patch("/{channel_id}/posts/{post_id}")
async def edit_post(
    channel_id: int,
    post_id: str,
    payload: ChannelPostEdit,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    _require_admin(channel, user_id)
    post = db.query(ChannelPost).filter(
        ChannelPost.id == post_id, ChannelPost.channel_id == channel_id
    ).first()
    if not post:
        raise HTTPException(status_code=404, detail="Publication introuvable")
    if datetime.utcnow() - post.created_at > _EDIT_WINDOW:
        raise HTTPException(
            status_code=409,
            detail="Cette publication est trop ancienne pour être modifiée (15 minutes)",
        )
    post.text_content = payload.text_content.strip()
    post.edited_at = datetime.utcnow()
    db.commit()
    db.refresh(post)
    return _serialize_post(post, user_id)


@router.delete("/{channel_id}/posts/{post_id}")
async def delete_post(
    channel_id: int,
    post_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    channel = _get(db, channel_id)
    _require_admin(channel, user_id)
    post = db.query(ChannelPost).filter(
        ChannelPost.id == post_id, ChannelPost.channel_id == channel_id
    ).first()
    if not post:
        raise HTTPException(status_code=404, detail="Publication introuvable")
    # Le sondage part AVEC la publication. La cascade de la base va dans
    # l'autre sens (supprimer le sondage supprime la publication qui le
    # porte), elle ne ramasse donc rien ici : sans ce geste explicite, la
    # ligne `polls`, ses options et ses votes resteraient en base sans que
    # rien ne puisse plus les afficher.
    orphan_poll = post.poll
    db.delete(post)
    if orphan_poll is not None:
        db.delete(orphan_poll)
    db.commit()
    return {"deleted": True}


@router.post("/{channel_id}/posts/{post_id}/view")
async def mark_post_viewed(
    channel_id: int,
    post_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Compteur de vues d'une publication. Idempotent par personne : un
    aller-retour dans le fil ne doit pas le gonfler."""
    user_id = current_user["user_id"]
    _get(db, channel_id)
    post = db.query(ChannelPost).filter(
        ChannelPost.id == post_id, ChannelPost.channel_id == channel_id
    ).first()
    if not post:
        raise HTTPException(status_code=404, detail="Publication introuvable")
    existing = db.query(ChannelPostView).filter(
        ChannelPostView.post_id == post_id, ChannelPostView.viewer_id == user_id
    ).first()
    if existing is None:
        db.add(ChannelPostView(post_id=post_id, viewer_id=user_id))
        db.commit()
        db.refresh(post)
    return {"post_id": post_id, "view_count": len(post.views)}


@router.put("/{channel_id}/posts/{post_id}/reaction")
async def react_to_post(
    channel_id: int,
    post_id: str,
    payload: ChannelReaction,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """PUT et non POST : une réaction par personne, REMPLACÉE quand elle
    change (contrainte uq_channel_post_reaction), jamais empilée."""
    user_id = current_user["user_id"]
    _get(db, channel_id)
    post = db.query(ChannelPost).filter(
        ChannelPost.id == post_id, ChannelPost.channel_id == channel_id
    ).first()
    if not post:
        raise HTTPException(status_code=404, detail="Publication introuvable")
    reaction = db.query(ChannelPostReaction).filter(
        ChannelPostReaction.post_id == post_id, ChannelPostReaction.user_id == user_id
    ).first()
    if reaction is None:
        reaction = ChannelPostReaction(post_id=post_id, user_id=user_id, emoji=payload.emoji)
        db.add(reaction)
    else:
        reaction.emoji = payload.emoji
    db.commit()
    db.refresh(post)
    return _serialize_post(post, user_id)


@router.delete("/{channel_id}/posts/{post_id}/reaction")
async def remove_reaction(
    channel_id: int,
    post_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _get(db, channel_id)
    reaction = db.query(ChannelPostReaction).filter(
        ChannelPostReaction.post_id == post_id, ChannelPostReaction.user_id == user_id
    ).first()
    if reaction is None:
        raise HTTPException(status_code=404, detail="Réaction introuvable")
    db.delete(reaction)
    db.commit()
    post = db.query(ChannelPost).options(*_post_load_options()).filter(
        ChannelPost.id == post_id
    ).first()
    return _serialize_post(post, user_id) if post else {"deleted": True}
