"""Pokou — conversations de groupe. Construit en parallèle de messages.py
(1:1), qui reste inchangé : autorisation par appartenance au groupe au lieu
de la paire de contacts, diffusion vers N membres au lieu d'un destinataire.

La diffusion temps réel réutilise `ws.py::manager.send_to_user` membre par
membre — le ConnectionManager n'a délibérément aucune notion de groupe, c'est
ici qu'on résout l'appartenance (la session DB est déjà à portée de main).
"""
import secrets
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.models import Contact, Group, GroupInvitation, GroupMember, GroupMessage, GroupMessageMention, GroupMessageReaction, MediaAsset, MessageType, Poll, PollOption, User
from app.utils.editing import MESSAGE_EDIT_WINDOW_MINUTES
from app.utils.identity import est_certifie, nom_certifie
from app.services.messaging import group_invitation_service
from app.services.privacy import privacy_service
from app.core.security import get_current_user
from app.api.v1.messaging.ws import manager
from app.services.messaging import notification_policy
from app.services.media import sticker_service
from app.services.notifications.push_service import send_push

router = APIRouter(prefix="/groups", tags=["Pokou groups"])

# Fenêtre de modification d'un message, alignée sur WhatsApp. Une limite est
# nécessaire : passé un moment le message a été lu, cité et peut-être répondu
# par les autres membres, le réécrire réécrirait leur conversation.
_EDIT_WINDOW_MINUTES = MESSAGE_EDIT_WINDOW_MINUTES

# Durées de disparition proposées : 24 h, 7 jours, 90 jours (les trois choix
# de WhatsApp). Liste fermée volontairement — une durée libre obligerait le
# client à formuler « disparaît dans 3 217 s » et n'apporterait rien.
_DISAPPEARING_CHOICES = (86400, 604800, 7776000)

# Longueur de l'aperçu d'un message cité : de quoi reconnaître la bulle
# d'origine sans transporter deux fois le message entier à chaque réponse.
_REPLY_PREVIEW_CHARS = 120


class GroupCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    member_user_ids: List[int] = Field(default_factory=list)


class GroupMembersAdd(BaseModel):
    user_ids: List[int] = Field(..., min_length=1)


class GroupUpdate(BaseModel):
    """Renommage et/ou photo. Les deux champs sont optionnels et distingués
    de « absent » par None : envoyer `avatar_media_id: null` explicitement
    retire la photo, ne pas envoyer le champ la laisse telle quelle.

    `disappearing_seconds` n'a pas de drapeau `clear_*` : null y est une
    valeur légitime (« ne plus faire disparaître »), donc on distingue
    « absent » de « null » avec `model_fields_set` plutôt qu'en ajoutant un
    booléen par champ nullable."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    avatar_media_id: Optional[int] = None
    clear_avatar: bool = False
    admins_only_messages: Optional[bool] = None
    disappearing_seconds: Optional[int] = None


class GroupMemberRole(BaseModel):
    role: str = Field(..., pattern="^(ADMIN|MEMBER)$")


class GroupMessageCreate(BaseModel):
    content: Optional[str] = Field(None, max_length=4000)
    message_type: str = "TEXT"
    media_asset_id: Optional[int] = None
    reply_to_id: Optional[str] = None
    # Les identifiants des personnes citées par @, et non le texte « @Bob » :
    # le nom affiché change (renommage, contact), le user_id non.
    mention_user_ids: List[int] = Field(default_factory=list)


class GroupMessageEdit(BaseModel):
    content: str = Field(..., min_length=1, max_length=4000)


class GroupMessageReactionSet(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=16)


# ─── Sérialisation ────────────────────────────────────────────────────────────

def _serialize_media(asset: MediaAsset) -> dict:
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _display_name(user: Optional[User]) -> str:
    if not user:
        return "Inconnu"
    return user.full_name or user.phone or f"#{user.id}"


def _serialize_member(member: GroupMember) -> dict:
    return {
        "user_id": member.user_id,
        "role": member.role,
        # Nom résolu côté serveur : sans ça le client devrait faire un appel
        # par membre pour afficher l'auteur de chaque bulle (problème N+1).
        "display_name": _display_name(member.user),
        "joined_at": member.joined_at.isoformat(),
    }


def _serialize_group(group: Group, *, with_members: bool = False) -> dict:
    payload: Dict[str, Any] = {
        "id": group.id,
        "name": group.name,
        "avatar_media_id": group.avatar_media_id,
        # Métadonnée complète en plus de l'identifiant, comme pour les
        # avatars d'utilisateur et les pièces jointes : le client a besoin du
        # type MIME pour nommer son fichier de cache.
        "avatar": _serialize_media(group.avatar_media) if group.avatar_media else None,
        "created_by": group.created_by,
        "created_at": group.created_at.isoformat(),
        "member_count": len(group.members),
        "community_id": group.community_id,
        # Le client affiche une zone de saisie en lecture seule pour un
        # non-admin dans les annonces, au lieu de le laisser écrire puis
        # échouer à l'envoi.
        "is_announcement": group.is_announcement,
        # Même raison pour `admins_only_messages` : la zone de saisie se
        # verrouille d'elle-même au lieu d'attendre un 403 à l'envoi.
        "admins_only_messages": bool(group.admins_only_messages),
        # Le réglage courant, pas l'échéance d'un message : chaque message
        # emporte la sienne, figée à l'envoi (voir send_group_message).
        "disappearing_seconds": group.disappearing_seconds,
    }
    if with_members:
        payload["members"] = [_serialize_member(member) for member in group.members]
    return payload


def _serialize_group_for(group: Group, viewer_id: int, *, with_members: bool = False) -> dict:
    """Ce que le groupe est POUR CELUI QUI REGARDE : son rôle et le lien
    d'invitation. Le lien n'est renvoyé qu'aux administrateurs — un membre
    simple ne doit pas pouvoir diffuser d'invitation."""
    payload = _serialize_group(group, with_members=with_members)
    role = next((m.role for m in group.members if m.user_id == viewer_id), None)
    payload["my_role"] = role
    payload["can_manage"] = role in _MANAGER_ROLES
    payload["invite_code"] = group.invite_code if role in _MANAGER_ROLES else None
    return payload


def _is_expired(message: GroupMessage, now: Optional[datetime] = None) -> bool:
    if not message.expires_at:
        return False
    return message.expires_at <= (now or datetime.utcnow())


def _serialize_reply_preview(quoted: Optional[GroupMessage]) -> Optional[dict]:
    """Aperçu du message cité embarqué dans la réponse, plutôt que laissé à
    la charge du client : la bulle citée est souvent hors de la page chargée,
    sinon il faudrait un appel par citation pour l'afficher.

    Un message cité déjà expiré n'est plus servi : sans ça, citer un message
    éphémère le rendrait lisible indéfiniment à travers la réponse."""
    if quoted is None or _is_expired(quoted):
        return None
    content = quoted.content or ""
    if len(content) > _REPLY_PREVIEW_CHARS:
        content = content[:_REPLY_PREVIEW_CHARS].rstrip() + "…"
    return {
        "id": quoted.id,
        "sender_id": quoted.sender_id,
        "sender_name": _display_name(quoted.sender),
        "sender_certified_name": nom_certifie(quoted.sender),
        "message_type": quoted.message_type.value,
        "content": content or None,
        "media": _serialize_media(quoted.media_asset) if quoted.media_asset else None,
    }


def _serialize_reactions(message: GroupMessage, viewer_id: Optional[int] = None) -> List[dict]:
    """Agrégé par emoji dans l'ordre d'apparition — c'est la forme qu'affiche
    la bulle (« 👍 3 »), et `user_ids` évite un appel de plus pour savoir qui
    a réagi.

    `mine` n'apparaît que pour un lecteur connu : l'événement
    `group:message:reaction` est UN SEUL objet envoyé à N membres, il ne peut
    pas porter un booléen propre à chacun — le client le déduit de
    `user_ids`."""
    grouped: Dict[str, List[int]] = {}
    for reaction in sorted(message.reactions, key=lambda row: (row.created_at, row.id)):
        grouped.setdefault(reaction.emoji, []).append(reaction.user_id)

    items: List[dict] = []
    for emoji, user_ids in grouped.items():
        entry = {"emoji": emoji, "count": len(user_ids), "user_ids": user_ids}
        if viewer_id is not None:
            entry["mine"] = viewer_id in user_ids
        items.append(entry)
    return items


def _serialize_mentions(message: GroupMessage) -> List[dict]:
    # Nom résolu ici comme pour `sender_name` : le client surligne « @Bob »
    # sans avoir à retrouver chaque membre cité.
    return [
        {"user_id": mention.user_id, "display_name": _display_name(mention.user)}
        for mention in message.mentions
    ]


def _serialize_poll(poll: Poll, viewer_id: Optional[int]) -> dict:
    """Même forme que app/routes/polls.py::_serialize_poll (voir le
    commentaire jumeau dans messages.py::_serialize_poll) : dupliquée et non
    importée pour ne pas faire dépendre ce routeur de polls.py."""
    everyone: set = set()
    options: List[dict] = []
    for option in poll.options:
        voters = [
            vote.user_id
            for vote in sorted(option.votes, key=lambda vote: (vote.created_at, vote.id))
        ]
        everyone.update(voters)
        options.append(
            {
                "id": option.id,
                "text": option.text,
                "position": option.position,
                "vote_count": len(voters),
                "voters": voters,
                "mine": viewer_id in voters,
            }
        )
    return {
        "id": poll.id,
        "question": poll.question,
        "allows_multiple": bool(poll.allows_multiple),
        "options": options,
        "total_voters": len(everyone),
    }


def _serialize_message(message: GroupMessage, viewer_id: Optional[int] = None) -> dict:
    return {
        "id": message.id,
        "group_id": message.group_id,
        "sender_id": message.sender_id,
        "sender_name": _display_name(message.sender),
        # Le même message part à tous les membres : le nom du CARNET de
        # chacun se résout chez lui. Seul le nom d'un compte certifié, qui
        # l'emporte sur tous les carnets, vient d'ici (utils/identity.py).
        "sender_certified_name": nom_certifie(message.sender),
        "sender_is_verified": est_certifie(message.sender),
        "message_type": message.message_type.value,
        "content": message.content,
        "media_asset_id": message.media_asset_id,
        "media": _serialize_media(message.media_asset) if message.media_asset else None,
        "created_at": message.created_at.isoformat(),
        # Nul tant que le message n'a jamais été modifié : c'est ce qui permet
        # au client d'afficher la mention « modifié » sans champ en plus.
        "edited_at": message.edited_at.isoformat() if message.edited_at else None,
        "expires_at": message.expires_at.isoformat() if message.expires_at else None,
        "reply_to_id": message.reply_to_id,
        "reply_to": _serialize_reply_preview(message.reply_to),
        "reactions": _serialize_reactions(message, viewer_id),
        "mentions": _serialize_mentions(message),
        # Comme messages.py::_serialize : sans ces deux clés, un sondage ou une
        # position de groupe perdait sa charge utile dès que la conversation
        # était relue via GET /groups/{id}/messages (seul l'événement WebSocket
        # initial de polls.py la portait).
        "payload": message.payload,
        "poll": _serialize_poll(message.poll, viewer_id) if message.poll else None,
    }


# ─── Autorisation ─────────────────────────────────────────────────────────────

def _require_membership(db: Session, group_id: int, user_id: int) -> GroupMember:
    """Lire ou écrire dans un groupe exige d'en être membre. Contrairement au
    1:1, aucune relation de contact n'est requise entre membres : être ajouté
    au groupe EST la mise en relation (même comportement que WhatsApp)."""
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")
    return membership


_MANAGER_ROLES = ("OWNER", "ADMIN")


def _require_manager(db: Session, group_id: int, user_id: int) -> GroupMember:
    """Renommer, changer la photo, gérer le lien d'invitation, retirer un
    membre : réservé au créateur et aux administrateurs qu'il a nommés."""
    membership = _require_membership(db, group_id, user_id)
    if membership.role not in _MANAGER_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Seuls les administrateurs du groupe peuvent faire cela",
        )
    return membership


def _require_owner(db: Session, group_id: int, user_id: int) -> GroupMember:
    """Nommer/révoquer un administrateur reste au seul créateur : sinon un
    admin pourrait s'entourer d'admins et déposséder le groupe."""
    membership = _require_membership(db, group_id, user_id)
    if membership.role != "OWNER":
        raise HTTPException(
            status_code=403,
            detail="Seul le créateur du groupe peut nommer des administrateurs",
        )
    return membership


def _require_can_post(db: Session, group: Group, user_id: int) -> None:
    """Deux situations distinctes aboutissent à la même règle « seuls les
    administrateurs écrivent » : le groupe d'annonces d'une communauté, où
    c'est structurel et non négociable — c'est ce qui distingue une
    communauté d'un dossier de groupes (voir routes/communities.py) — et le
    réglage `admins_only_messages` qu'un admin active sur un groupe
    ordinaire. Partout ailleurs, tout membre écrit.

    Les deux verrous restent séparés jusque dans le message d'erreur : dire
    « annonces » à qui essaie d'écrire dans un groupe simplement verrouillé
    serait incompréhensible."""
    if not group.is_announcement and not group.admins_only_messages:
        return
    membership = _require_membership(db, group.id, user_id)
    if membership.role in _MANAGER_ROLES:
        return
    raise HTTPException(
        status_code=403,
        detail=(
            "Seuls les administrateurs peuvent publier dans les annonces"
            if group.is_announcement
            else "Seuls les administrateurs peuvent écrire dans ce groupe"
        ),
    )


def _get_group_message(db: Session, group_id: int, message_id: str) -> GroupMessage:
    """404 et non 403 : l'identifiant d'un message appartenant à un autre
    groupe ne doit pas révéler qu'il existe. L'appartenance au groupe demandé
    est vérifiée à part, avant."""
    message = db.query(GroupMessage).filter(
        GroupMessage.id == message_id, GroupMessage.group_id == group_id
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")
    return message


def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> None:
    """Deux conditions, et elles regardent dans des directions opposées.

    1. **Mon carnet.** On ne peut inviter que des gens qu'on a soi-même
       enregistrés — c'est le garde-fou d'origine (voir
       messages.py::_require_contact), qui empêche d'ajouter des inconnus en
       devinant des identifiants.

    2. **SA règle à LUI.** Depuis les politiques de confidentialité, chacun
       choisit qui peut l'inviter dans un groupe : tout le monde, ses
       contacts, personne. La première condition protège contre l'inconnu
       qui devine ; la seconde donne à la personne le contrôle de sa propre
       porte, ce qui n'est pas la même chose.

    Le refus est un 403 explicite, et c'est assumé : contrairement à une
    photo masquée, un ajout à un groupe est une ACTION. Celui qui la tente
    doit savoir qu'elle a échoué, sinon il recommence — et le silence lui
    ferait croire que la personne a été ajoutée.
    """
    is_contact = db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first()
    if not is_contact:
        raise HTTPException(status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses")

    if not privacy_service.peut_voir(
        db, contact_user_id, owner_id, privacy_service.Aspect.INVITATIONS_GROUPES
    ):
        raise HTTPException(
            status_code=403,
            detail="Cette personne n'accepte pas les invitations de groupe de votre part",
        )


async def _broadcast(
    db: Session,
    group_id: int,
    event: Dict[str, Any],
    *,
    exclude_user_id: Optional[int] = None,
    extra_user_ids: Optional[List[int]] = None,
) -> set:
    """Diffuse un événement aux membres connectés, en réutilisant
    `send_to_user` (pas de duplication de la logique sockets/erreurs du
    ConnectionManager). Retourne les user_id effectivement joints, pour que
    l'appelant sache lesquels basculer en notification push."""
    member_ids = [
        row[0]
        for row in db.query(GroupMember.user_id).filter(GroupMember.group_id == group_id).all()
        if row[0] != exclude_user_id
    ]
    # `extra_user_ids` sert au membre retiré : il n'est plus dans
    # group_members au moment où l'événement partt, mais doit l'apprendre.
    for user_id in extra_user_ids or []:
        if user_id != exclude_user_id and user_id not in member_ids:
            member_ids.append(user_id)

    reached = set()
    for user_id in member_ids:
        if await manager.send_to_user(user_id, event):
            reached.add(user_id)
    return reached


# ─── Groupes ──────────────────────────────────────────────────────────────────

@router.post("")
async def create_group(
    payload: GroupCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    creator_id = current_user["user_id"]
    member_ids = {user_id for user_id in payload.member_user_ids if user_id != creator_id}
    for user_id in member_ids:
        _require_contact(db, creator_id, user_id)

    group = Group(name=payload.name.strip(), created_by=creator_id)
    db.add(group)
    db.flush()  # besoin de group.id avant d'insérer les membres

    # Le créateur est le SEUL membre à la création. Les autres sont invités.
    #
    # Créer un groupe avec des gens dedans, c'était les y mettre sans leur
    # demander — le cas le plus courant du problème qu'on corrige, pas une
    # exception à laisser de côté. Un groupe naît donc vide, et se remplit à
    # mesure que les invitations sont acceptées.
    db.add(GroupMember(group_id=group.id, user_id=creator_id, role="OWNER"))
    invites: list[tuple[int, dict]] = []
    for user_id in member_ids:
        invitation = group_invitation_service.inviter(db, group.id, user_id, creator_id)
        invites.append(
            (user_id, group_invitation_service.serialiser(db, invitation))
        )
    db.commit()
    db.refresh(group)

    for invite_id, charge in invites:
        await manager.send_to_user(
            invite_id, {"type": "group:invitation", "invitation": charge}
        )
    charge_groupe = _serialize_group(group, with_members=True)
    # Pas de `group:created` diffusé : il n'y a personne d'autre à prévenir,
    # et l'invitation ci-dessus est le bon message — elle appelle une
    # décision, là où « un groupe a été créé » n'appellerait rien.
    return {**charge_groupe, "invitations": [c for _, c in invites]}


@router.get("")
async def list_my_groups(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    groups = (
        db.query(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .filter(GroupMember.user_id == user_id)
        .order_by(Group.created_at.desc())
        .all()
    )
    return {"items": [_serialize_group(group) for group in groups], "total": len(groups)}


@router.get("/mentions")
async def list_my_mentions(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les messages qui me citent, tous groupes confondus, du plus récent au
    plus ancien : c'est la contrepartie d'une mention, retrouver ce qui
    m'attend sans ouvrir un par un des groupes bavards.

    Déclarée AVANT `/{group_id}`, qui attend un entier : FastAPI n'essaie pas
    la route suivante quand la conversion échoue, le chemin littéral
    « mentions » répondrait donc 422 si l'ordre était inversé.

    Restreinte aux groupes dont je suis TOUJOURS membre : la ligne de mention
    survit à un départ du groupe (elle est liée au message), mais son contenu
    ne doit pas me rester accessible."""
    user_id = current_user["user_id"]
    now = datetime.utcnow()
    messages = (
        db.query(GroupMessage)
        .join(GroupMessageMention, GroupMessageMention.message_id == GroupMessage.id)
        .join(GroupMember, GroupMember.group_id == GroupMessage.group_id)
        .filter(
            GroupMessageMention.user_id == user_id,
            GroupMember.user_id == user_id,
            or_(GroupMessage.expires_at.is_(None), GroupMessage.expires_at > now),
        )
        .order_by(GroupMessage.created_at.desc())
        .limit(limit)
        .all()
    )

    items = []
    for message in messages:
        item = _serialize_message(message, user_id)
        # La liste est inter-groupes : sans le nom, impossible de savoir d'où
        # sort la mention (`group_id` seul ne s'affiche pas).
        item["group_name"] = message.group.name if message.group else None
        items.append(item)
    return {"items": items, "total": len(items)}


# ─── Invitations ──────────────────────────────────────────────────────────────
#
# L'invité décide. C'est toute la différence avec ce qui existait : ajouter
# quelqu'un le rendait membre sur-le-champ, avec les notifications et
# l'historique du groupe, et la seule sortie était de partir — c'est-à-dire
# d'annoncer publiquement qu'on était parti.


@router.get("/invitations")
async def list_my_invitations(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce que j'ai à décider.

    Déclarée AVANT `/{group_id}`, sans quoi FastAPI capturerait « invitations »
    comme identifiant de groupe et répondrait 422 — les routes sont testées
    dans l'ordre d'enregistrement.
    """
    invitations = group_invitation_service.mes_invitations(db, current_user["user_id"])
    return {
        "items": [group_invitation_service.serialiser(db, i) for i in invitations]
    }


def _mon_invitation(db: Session, invitation_id: str, user_id: int) -> GroupInvitation:
    invitation = (
        db.query(GroupInvitation)
        .filter(
            GroupInvitation.id == invitation_id,
            # L'invitation de QUELQU'UN D'AUTRE répond 404 et non 403 : un
            # refus explicite confirmerait qu'elle existe, donc que cette
            # personne a été invitée quelque part.
            GroupInvitation.user_id == user_id,
        )
        .first()
    )
    if invitation is None:
        raise HTTPException(status_code=404, detail="Invitation introuvable")
    return invitation


@router.post("/invitations/{invitation_id}/accept")
async def accept_invitation(
    invitation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    invitation = _mon_invitation(db, invitation_id, user_id)
    try:
        member = group_invitation_service.accepter(db, invitation)
    except group_invitation_service.InvitationImpossible as exc:
        # 409 et non 400 : l'invitation a existé, elle n'est simplement plus
        # valable. Le client distingue « jamais reçue » de « trop tard ».
        raise HTTPException(status_code=409, detail=str(exc))
    db.commit()

    group = db.query(Group).filter(Group.id == invitation.group_id).first()
    await _broadcast(
        db,
        invitation.group_id,
        {
            "type": "group:member:added",
            "group": _serialize_group(group, with_members=True),
            "member": _serialize_member(member),
        },
    )
    return _serialize_group_for(group, user_id, with_members=True)


@router.post("/invitations/{invitation_id}/reject")
async def reject_invitation(
    invitation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Refuser.

    Le groupe n'en est PAS averti, et c'est délibéré : annoncer « untel a
    refusé » à toute une conversation transformerait un choix personnel en
    petit événement public, et dissuaderait de refuser. Seul l'invitant sait
    que son invitation n'a pas abouti, en la voyant disparaître.
    """
    invitation = _mon_invitation(db, invitation_id, current_user["user_id"])
    try:
        group_invitation_service.refuser(db, invitation)
    except group_invitation_service.InvitationImpossible as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    db.commit()
    return {"status": "REJECTED"}


@router.get("/{group_id}")
async def get_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    _require_membership(db, group_id, current_user["user_id"])
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    return _serialize_group_for(group, current_user["user_id"], with_members=True)


@router.patch("/{group_id}")
async def update_group(
    group_id: int,
    payload: GroupUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Renommer le groupe, changer sa photo et ses réglages collectifs (qui a
    le droit d'écrire, disparition des messages). Réservé aux
    administrateurs, et diffusé à tous les membres : le nom, la photo et ces
    réglages s'affichent dans la conversation de chacun, ils ne peuvent pas
    rester périmés jusqu'au prochain rechargement.

    Ces deux réglages sont ici et non sur GroupMember, contrairement à
    l'archivage ou la sourdine : ils valent pour le groupe entier, pas pour
    la vue personnelle qu'on en a."""
    user_id = current_user["user_id"]
    _require_manager(db, group_id, user_id)

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    if payload.name is not None:
        name = payload.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Le nom du groupe ne peut pas être vide")
        group.name = name

    if payload.clear_avatar:
        group.avatar_media_id = None
    elif payload.avatar_media_id is not None:
        asset = db.query(MediaAsset).filter(MediaAsset.id == payload.avatar_media_id).first()
        if not asset:
            raise HTTPException(status_code=404, detail="Image introuvable")
        # Ne pas laisser rattacher la pièce jointe de quelqu'un d'autre :
        # l'image devient visible par tout le groupe.
        if asset.uploader_id != user_id:
            raise HTTPException(status_code=403, detail="Cette image ne vous appartient pas")
        group.avatar_media_id = asset.id

    if payload.admins_only_messages is not None:
        group.admins_only_messages = payload.admins_only_messages

    if "disappearing_seconds" in payload.model_fields_set:
        seconds = payload.disappearing_seconds
        if seconds is not None and seconds not in _DISAPPEARING_CHOICES:
            raise HTTPException(status_code=400, detail="Durée de disparition non prise en charge")
        # Le réglage ne touche QUE les messages à venir : ceux déjà envoyés
        # portent leur échéance, figée à l'envoi. Sinon activer la
        # disparition effacerait rétroactivement des mois de conversation, et
        # la désactiver ressusciterait des messages déjà disparus des écrans.
        group.disappearing_seconds = seconds

    db.commit()
    db.refresh(group)

    await _broadcast(
        db,
        group_id,
        {"type": "group:updated", "group": _serialize_group(group)},
        exclude_user_id=user_id,
    )
    return _serialize_group_for(group, user_id, with_members=True)


# ─── Membres ──────────────────────────────────────────────────────────────────

@router.post("/{group_id}/members")
async def add_members(
    group_id: int,
    payload: GroupMembersAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """N'importe quel membre peut inviter (comportement WhatsApp par défaut) —
    évite d'avoir à construire une UI de permissions pour cette première
    version, tout en gardant le garde-fou du carnet d'adresses."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)

    # ── On INVITE, on n'ajoute plus ──────────────────────────────────────
    #
    # Ajouter rendait membre sur-le-champ : on se retrouvait dans une
    # conversation sans l'avoir demandé, avec ses notifications et son
    # historique, et la seule sortie était de partir — c'est-à-dire
    # d'annoncer publiquement qu'on était parti.
    #
    # `_require_contact` vérifie toujours les deux conditions : le carnet de
    # celui qui invite, et la règle « qui peut m'inviter » de l'invité. Mais
    # cette règle décide seulement si l'invitation PART. Elle ne décide
    # jamais de l'adhésion — sinon on ramènerait le comportement d'avant,
    # avec un réglage devant.
    invites: List[tuple[int, dict]] = []
    for new_user_id in payload.user_ids:
        if new_user_id == user_id:
            continue
        _require_contact(db, user_id, new_user_id)
        try:
            invitation = group_invitation_service.inviter(
                db, group_id, new_user_id, user_id
            )
        except group_invitation_service.InvitationImpossible:
            # Déjà membre : ce n'est pas une erreur du point de vue de
            # l'appelant, qui voulait cette personne dans le groupe et l'y
            # trouve. On passe.
            continue
        invites.append((new_user_id, group_invitation_service.serialiser(db, invitation)))
    db.commit()

    group = db.query(Group).filter(Group.id == group_id).first()
    for invite_id, charge in invites:
        # L'invité l'apprend TOUT DE SUITE s'il est connecté : une invitation
        # qui n'arrive qu'au prochain lancement de l'application perd une
        # partie de ses 72 heures.
        await manager.send_to_user(
            invite_id, {"type": "group:invitation", "invitation": charge}
        )
    return {
        "group": _serialize_group(group, with_members=True),
        "invitations": [charge for _, charge in invites],
    }


@router.put("/{group_id}/members/{user_id}/role")
async def set_member_role(
    group_id: int,
    user_id: int,
    payload: GroupMemberRole,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Nommer ou révoquer un administrateur. Réservé au créateur (voir
    _require_owner). Le rôle OWNER n'est pas attribuable ici : il n'y en a
    qu'un, celui qui a créé le groupe."""
    requester_id = current_user["user_id"]
    _require_owner(db, group_id, requester_id)

    if user_id == requester_id:
        # Se rétrograder soi-même laisserait le groupe sans créateur.
        raise HTTPException(status_code=400, detail="Le créateur ne peut pas changer son propre rôle")

    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=404, detail="Ce membre n'est pas dans le groupe")

    membership.role = payload.role
    db.commit()
    db.refresh(membership)

    await _broadcast(
        db,
        group_id,
        {
            "type": "group:member:role",
            "group_id": group_id,
            "member": _serialize_member(membership),
        },
        exclude_user_id=requester_id,
    )
    return _serialize_member(membership)


# ─── Lien d'invitation ────────────────────────────────────────────────────────

def _new_invite_code() -> str:
    # 16 caractères d'URL-safe base64 (~96 bits) : le lien est une
    # autorisation à lui seul, il doit être impossible à devinier.
    return secrets.token_urlsafe(12)[:16]


@router.post("/{group_id}/invite-link")
async def create_invite_link(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée le lien d'invitation, ou le REMPLACE s'il en existait un —
    régénérer est le seul moyen de révoquer un lien déjà diffusé."""
    user_id = current_user["user_id"]
    _require_manager(db, group_id, user_id)

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    group.invite_code = _new_invite_code()
    db.commit()
    db.refresh(group)
    return {"invite_code": group.invite_code}


@router.delete("/{group_id}/invite-link")
async def revoke_invite_link(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_manager(db, group_id, user_id)

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    group.invite_code = None
    db.commit()
    return {"revoked": True}


@router.get("/invite/{invite_code}")
async def preview_invite(
    invite_code: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce qu'on voit AVANT d'accepter une invitation : de quel groupe il
    s'agit et combien de personnes y sont. Volontairement sans la liste des
    membres — on ne révèle pas qui est dans un groupe à quelqu'un qui n'y
    est pas encore."""
    group = db.query(Group).filter(Group.invite_code == invite_code).first()
    if not group:
        raise HTTPException(status_code=404, detail="Ce lien d'invitation n'est plus valide")

    already_member = db.query(GroupMember).filter(
        GroupMember.group_id == group.id, GroupMember.user_id == current_user["user_id"]
    ).first() is not None
    return {
        "id": group.id,
        "name": group.name,
        "avatar_media_id": group.avatar_media_id,
        "avatar": _serialize_media(group.avatar_media) if group.avatar_media else None,
        "member_count": len(group.members),
        "already_member": already_member,
    }


@router.post("/invite/{invite_code}/join")
async def join_by_invite(
    invite_code: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Rejoindre par lien. Aucune relation de contact n'est exigée — c'est
    tout l'intérêt d'un lien : entrer dans un groupe sans que personne ait à
    vous ajouter à la main."""
    user_id = current_user["user_id"]
    group = db.query(Group).filter(Group.invite_code == invite_code).first()
    if not group:
        raise HTTPException(status_code=404, detail="Ce lien d'invitation n'est plus valide")

    existing = db.query(GroupMember).filter(
        GroupMember.group_id == group.id, GroupMember.user_id == user_id
    ).first()
    if existing:
        # Idempotent : toucher deux fois le lien ne doit pas être une erreur.
        return _serialize_group_for(group, user_id, with_members=True)

    db.add(GroupMember(group_id=group.id, user_id=user_id, role="MEMBER"))
    db.commit()
    db.refresh(group)

    joiner = db.query(User).filter(User.id == user_id).first()
    await _broadcast(
        db,
        group.id,
        {
            "type": "group:member:added",
            "group_id": group.id,
            "group": _serialize_group(group),
            "member": {"user_id": user_id, "display_name": _display_name(joiner), "role": "MEMBER"},
        },
        exclude_user_id=user_id,
    )
    return _serialize_group_for(group, user_id, with_members=True)


@router.delete("/{group_id}/members/{user_id}")
async def remove_member(
    group_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le créateur et les administrateurs peuvent retirer quelqu'un d'autre ;
    chacun peut se retirer soi-même (quitter le groupe). « N'importe qui peut
    retirer n'importe qui » ouvrirait la porte au sabotage d'un groupe, et
    « seul le créateur » rendrait « quitter » impossible pour les autres."""
    requester_id = current_user["user_id"]
    requester = _require_membership(db, group_id, requester_id)
    if user_id != requester_id and requester.role not in _MANAGER_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Seuls le créateur et les administrateurs peuvent retirer un autre membre",
        )

    target = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="Ce membre ne fait pas partie du groupe")
    # Un admin ne peut pas évincer le créateur : il ne resterait personne
    # pour nommer des administrateurs.
    if target.role == "OWNER" and user_id != requester_id:
        raise HTTPException(status_code=403, detail="Le créateur du groupe ne peut pas être retiré")

    db.delete(target)
    db.commit()

    # Le membre retiré reçoit aussi l'événement (extra_user_ids) : sans ça il
    # ne l'apprendrait qu'au prochain rafraîchissement de l'app.
    await _broadcast(
        db,
        group_id,
        {"type": "group:member:removed", "group_id": group_id, "user_id": user_id},
        extra_user_ids=[user_id],
    )
    return {"removed": True, "group_id": group_id, "user_id": user_id}


# ─── Messages de groupe ───────────────────────────────────────────────────────

@router.get("/{group_id}/messages/{message_id}")
async def get_group_message(
    group_id: int,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """UN message de groupe, pour la notification construite par l'appareil
    (voir routes/messages.py::get_message_by_id). Membres seulement."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    now = datetime.utcnow()
    message = (
        db.query(GroupMessage)
        .filter(
            GroupMessage.id == message_id,
            GroupMessage.group_id == group_id,
            or_(GroupMessage.expires_at.is_(None), GroupMessage.expires_at > now),
        )
        .first()
    )
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    return _serialize_message(message, user_id)


@router.get("/{group_id}/messages")
async def list_group_messages(
    group_id: int,
    limit: int = Query(100, ge=1, le=200),
    before: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les messages éphémères sortent de l'historique dès leur échéance, sans
    attendre une purge en base : la ligne peut survivre (une réponse la
    référence peut-être), elle ne doit plus être servie.

    `before` pagine vers le passé : les messages strictement antérieurs à
    cet instant (celui du plus ancien déjà affiché). Seule la dernière page
    était servie — un groupe actif dépasse 100 messages en une heure, et
    tout ce qui précédait devenait inaccessible. Un curseur et non un
    décalage : les messages qui arrivent pendant qu'on remonte ne décalent
    pas les pages."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    now = datetime.utcnow()
    messages = (
        db.query(GroupMessage)
        .options(
            # Un aller-retour par collection au lieu d'un par message :
            # réactions et mentions feraient sinon 2×N requêtes sur une page
            # de 100 messages.
            selectinload(GroupMessage.reactions),
            selectinload(GroupMessage.mentions),
            # Même raison pour un sondage : ses options et leurs votes,
            # chargés en deux allers-retours au lieu de deux par sondage
            # affiché (voir _serialize_poll).
            selectinload(GroupMessage.poll).selectinload(Poll.options).selectinload(PollOption.votes),
        )
        .filter(
            GroupMessage.group_id == group_id,
            or_(GroupMessage.expires_at.is_(None), GroupMessage.expires_at > now),
            *([GroupMessage.created_at < before] if before is not None else []),
        )
        .order_by(GroupMessage.created_at.desc())
        # Un de plus que demandé : sa présence dit s'il reste une page.
        .limit(limit + 1)
        .all()
    )
    has_more = len(messages) > limit
    messages = messages[:limit]
    messages.reverse()  # rendu chronologique côté client
    return {
        "items": [_serialize_message(message, user_id) for message in messages],
        "total": len(messages),
        "has_more": has_more,
    }


@router.post("/{group_id}/messages")
async def send_group_message(
    group_id: int,
    payload: GroupMessageCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sender_id = current_user["user_id"]
    _require_membership(db, group_id, sender_id)

    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    _require_can_post(db, group, sender_id)

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
        if media_asset is None:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")
        # Même garde-fou que messages.py : l'upload doit venir de
        # l'expéditeur.
        #
        # Un STICKER est la seule exception, et elle est nécessaire : son
        # image appartient au PACK, jamais à celui qui l'envoie. La règle
        # exacte vit dans sticker_service, pas recopiée ici.
        if media_asset.uploader_id != sender_id and not (
            message_type == MessageType.STICKER
            and sticker_service.sender_may_attach(db, media_asset.id, sender_id)
        ):
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")

    if payload.reply_to_id:
        # Le message cité doit appartenir à CE groupe : sans cette
        # vérification, un membre pourrait faire remonter l'aperçu (auteur et
        # début du texte) d'un message d'un groupe où il n'est pas.
        quoted = db.query(GroupMessage).filter(
            GroupMessage.id == payload.reply_to_id, GroupMessage.group_id == group_id
        ).first()
        if not quoted:
            raise HTTPException(status_code=404, detail="Message cité introuvable")

    # Les personnes citées qui ne sont pas (ou plus) membres sont écartées en
    # silence : le texte est déjà écrit et « @Bob » y reste lisible, refuser
    # tout le message parce que Bob a quitté le groupe ferait perdre le
    # message pour un détail d'affichage.
    mention_ids: List[int] = []
    wanted_mentions = {user_id for user_id in payload.mention_user_ids if user_id != sender_id}
    if wanted_mentions:
        mention_ids = [
            row[0]
            for row in db.query(GroupMember.user_id)
            .filter(GroupMember.group_id == group_id, GroupMember.user_id.in_(wanted_mentions))
            .all()
        ]

    message = GroupMessage(
        group_id=group_id,
        sender_id=sender_id,
        message_type=message_type,
        content=payload.content,
        media_asset_id=media_asset.id if media_asset else None,
        reply_to_id=payload.reply_to_id,
        # Échéance figée à l'envoi, jamais recalculée à la lecture : c'est ce
        # qui fait qu'un changement de réglage plus tard n'efface pas le passé
        # et ne prolonge pas ce qui devait disparaître.
        expires_at=(
            datetime.utcnow() + timedelta(seconds=group.disappearing_seconds)
            if group.disappearing_seconds
            else None
        ),
    )
    db.add(message)
    db.flush()  # besoin de message.id avant d'insérer les mentions
    for mentioned_id in mention_ids:
        db.add(GroupMessageMention(message_id=message.id, user_id=mentioned_id))
    db.commit()
    db.refresh(message)

    serialized = _serialize_message(message, sender_id)
    # L'expéditeur a déjà le message dans la réponse HTTP — inutile de le lui
    # renvoyer par socket (messages.py ne le fait pas non plus en 1:1).
    await _broadcast(
        db,
        group_id,
        {"type": "group:message:new", "message": serialized},
        exclude_user_id=sender_id,
    )

    group = db.query(Group).filter(Group.id == group_id).first()
    body = payload.content if message_type == MessageType.TEXT else f"[{message_type.value.capitalize()}]"
    mentioned = set(mention_ids)
    for member in group.members:
        if member.user_id == sender_id:
            continue
        # Le push complète le WebSocket : Android doit encore pouvoir afficher
        # la notification si l'application passe en arrière-plan juste après
        # l'envoi du message.
        #
        # Une personne citée reçoit ce push comme les autres, mais avec son
        # propre libellé : être cité, c'est justement l'événement pour lequel
        # on accepte d'être dérangé alors qu'on ne suivait pas la discussion,
        # donc « X vous a mentionné » et non un extrait du fil.
        if member.user_id in mentioned:
            push_body = f"{serialized['sender_name']} vous a mentionné dans {group.name}"
            event = notification_policy.NotificationEvent.GROUP_MENTION
        else:
            # L'existence du message, pas son contenu — même règle que pour
            # les conversations privées (voir routes/messages.py
            # ::_push_preview). Un message de groupe n'est pas moins
            # confidentiel parce qu'il est lu par dix personnes, et il passe
            # par Firebase puis par un écran verrouillé exactement pareil.
            push_body = f"{serialized['sender_name']} a envoyé un message"
            event = notification_policy.NotificationEvent.GROUP_MESSAGE
        # Un groupe en sourdine ne sonne pas — sauf si on y est cité. La
        # nuance est décidée en un seul endroit, pas répartie dans les
        # routes (voir services/notification_policy.py).
        decision = notification_policy.decide(
            db,
            recipient_id=member.user_id,
            event=event,
            group_id=group_id,
        )
        if not decision.deliver:
            continue
        send_push(
            db,
            member.user_id,
            title=group.name,
            body=push_body,
            data={
                "type": event.value,
                "group_id": str(group_id),
                "group_name": group.name,
                **decision.as_payload(),
            },
            # L'appareil construit lui-même la notification groupée et va
            # chercher le texte par `message_id` : il ne passe pas par
            # Firebase (voir routes/messages.py::_rich_push_data).
            rich_data={
                "rich": "1",
                "message_id": str(serialized["id"]),
                "sender_id": str(sender_id),
                "sender_name": serialized["sender_name"],
                "sender_certified_name": serialized.get("sender_certified_name") or "",
                "message_type": serialized["message_type"],
                "sent_at": serialized["created_at"] + "Z",
                "mentioned": "1" if member.user_id in mentioned else "0",
            },
        )

    return serialized


@router.patch("/{group_id}/messages/{message_id}")
async def edit_group_message(
    group_id: int,
    message_id: str,
    payload: GroupMessageEdit,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Corriger un message déjà envoyé, dans les 15 minutes
    (_EDIT_WINDOW_MINUTES) et par son seul auteur.

    Le contenu d'origine n'est pas conservé : Pokou n'affiche pas d'historique
    de versions, garder l'ancien texte en base serait une donnée qu'on
    promet implicitement d'avoir effacée."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    message = _get_group_message(db, group_id, message_id)

    if message.sender_id != user_id:
        # 403 et non 404 : le message est bien visible de tout le groupe,
        # cacher son existence à un membre n'aurait aucun sens.
        raise HTTPException(status_code=403, detail="Vous ne pouvez modifier que vos propres messages")
    if message.message_type != MessageType.TEXT:
        # Remplacer une pièce jointe n'est pas une modification, c'est un
        # autre message : la précédente est déjà téléchargée chez les autres.
        raise HTTPException(status_code=400, detail="Seuls les messages texte peuvent être modifiés")
    if datetime.utcnow() - message.created_at > timedelta(minutes=_EDIT_WINDOW_MINUTES):
        raise HTTPException(
            status_code=409,
            detail=f"Un message ne peut plus être modifié après {_EDIT_WINDOW_MINUTES} minutes",
        )

    content = payload.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Le contenu du message est requis")

    message.content = content
    message.edited_at = datetime.utcnow()
    db.commit()
    db.refresh(message)

    await _broadcast(
        db,
        group_id,
        {
            "type": "group:message:edited",
            "group_id": group_id,
            "message": _serialize_message(message),
        },
        exclude_user_id=user_id,
    )
    return _serialize_message(message, user_id)


@router.put("/{group_id}/messages/{message_id}/reaction")
async def set_group_message_reaction(
    group_id: int,
    message_id: str,
    payload: GroupMessageReactionSet,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Réagir à un message du groupe. PUT et non POST parce que l'opération
    est un remplacement : une seule réaction par personne et par message
    (contrainte uq_group_message_reaction), réagir de nouveau change son
    emoji au lieu d'en accumuler un deuxième.

    Ouvert à tout membre, y compris là où seuls les admins écrivent : une
    réaction n'occupe pas le fil, c'est justement le seul retour possible
    dans un groupe d'annonces."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    message = _get_group_message(db, group_id, message_id)

    emoji = payload.emoji.strip()
    if not emoji:
        raise HTTPException(status_code=400, detail="L'emoji de la réaction est requis")

    existing = db.query(GroupMessageReaction).filter(
        GroupMessageReaction.message_id == message.id,
        GroupMessageReaction.user_id == user_id,
    ).first()
    if existing:
        existing.emoji = emoji
    else:
        db.add(GroupMessageReaction(message_id=message.id, user_id=user_id, emoji=emoji))
    db.commit()
    db.refresh(message)

    await _broadcast(
        db,
        group_id,
        {
            "type": "group:message:reaction",
            "group_id": group_id,
            "message_id": message.id,
            "reactions": _serialize_reactions(message),
        },
        exclude_user_id=user_id,
    )
    return {"message_id": message.id, "reactions": _serialize_reactions(message, user_id)}


@router.delete("/{group_id}/messages/{message_id}/reaction")
async def remove_group_message_reaction(
    group_id: int,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Retirer sa réaction. Idempotent : ne rien avoir à retirer n'est pas
    une erreur — le geste est un basculement, et deux appuis rapprochés ne
    doivent pas finir sur un message d'échec."""
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    message = _get_group_message(db, group_id, message_id)

    existing = db.query(GroupMessageReaction).filter(
        GroupMessageReaction.message_id == message.id,
        GroupMessageReaction.user_id == user_id,
    ).first()
    if existing:
        db.delete(existing)
        db.commit()
        db.refresh(message)
        await _broadcast(
            db,
            group_id,
            {
                "type": "group:message:reaction",
                "group_id": group_id,
                "message_id": message.id,
                "reactions": _serialize_reactions(message),
            },
            exclude_user_id=user_id,
        )
    return {"message_id": message.id, "reactions": _serialize_reactions(message, user_id)}
