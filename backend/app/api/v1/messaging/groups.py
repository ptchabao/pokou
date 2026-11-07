"""Pokou — conversations de groupe. Construit en parallèle de messages.py
(1:1), qui reste inchangé : autorisation par appartenance au groupe au lieu
de la paire de contacts, diffusion vers N membres au lieu d'un destinataire.

La diffusion temps réel réutilise `ws.py::manager.send_to_user` membre par
membre — le ConnectionManager n'a délibérément aucune notion de groupe, c'est
ici qu'on résout l'appartenance (la session DB est déjà à portée de main).
"""
import secrets
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.models import Contact, Group, GroupInvitation, GroupJoinRequest, GroupMember, GroupMessage, GroupMessageMention, GroupMessageReaction, GroupSenderKeyDistribution, MediaAsset, MessageType, Poll, PollOption, User
from app.utils.editing import MESSAGE_EDIT_WINDOW_MINUTES
from app.utils.identity import est_certifie, nom_certifie
from app.services.messaging import group_invitation_service
from app.services.privacy import privacy_service
from app.core.security import get_current_user
from app.api.v1.messaging.ws import manager
from app.services.messaging import notification_policy
from app.services.media import sticker_service
from app.services.notifications.push_service import send_push

logger = logging.getLogger(__name__)
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
    members_can_edit_info: Optional[bool] = None
    join_approval: Optional[bool] = None


class GroupMemberRole(BaseModel):
    role: str = Field(..., pattern="^(ADMIN|MEMBER)$")


class GroupMessageCreate(BaseModel):
    # `content` remains parseable only to return a clear rejection to older
    # clients; it is never persisted or serialized for group messages.
    content: Optional[str] = Field(None, max_length=4000)
    message_type: str = "TEXT"
    media_asset_id: Optional[int] = None
    reply_to_id: Optional[str] = None
    encryption: Optional[str] = None
    ciphertext: Optional[str] = Field(None, max_length=1000000)
    crypto_epoch: Optional[int] = None
    # Les identifiants des personnes citées par @, et non le texte « @Bob » :
    # le nom affiché change (renommage, contact), le user_id non.
    mention_user_ids: List[int] = Field(default_factory=list)


class GroupMessageEdit(BaseModel):
    content: Optional[str] = Field(None, max_length=4000)
    encryption: Optional[str] = None
    ciphertext: Optional[str] = Field(None, max_length=1000000)
    crypto_epoch: Optional[int] = None


class SenderKeyEnvelope(BaseModel):
    recipient_id: int
    encryption: str = Field(..., pattern="^v1$")
    ciphertext: str = Field(..., min_length=1, max_length=1000000)
    envelope: Dict[str, Any]


class SenderKeyDistributionCreate(BaseModel):
    epoch: int
    distributions: List[SenderKeyEnvelope] = Field(default_factory=list, max_length=500)


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
        "members_can_edit_info": bool(group.members_can_edit_info),
        "join_approval": bool(group.join_approval),
        # Le réglage courant, pas l'échéance d'un message : chaque message
        # emporte la sienne, figée à l'envoi (voir send_group_message).
        "disappearing_seconds": group.disappearing_seconds,
        "proof_mode": bool(group.proof_mode),
        "proof_mode_since": group.proof_mode_since.isoformat() if group.proof_mode_since else None,
        "crypto_epoch": group.crypto_epoch,
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
    payload["can_edit_info"] = role in _MANAGER_ROLES or (
        role is not None and bool(group.members_can_edit_info)
    )
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
    return {
        "id": quoted.id,
        "sender_id": quoted.sender_id,
        "sender_name": _display_name(quoted.sender),
        "sender_certified_name": nom_certifie(quoted.sender),
        "message_type": quoted.message_type.value,
        # A quoted message is opaque to the server too.
        "content": None,
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
        "content": None,
        "encryption": message.encryption,
        "ciphertext": message.ciphertext,
        "crypto_epoch": message.crypto_epoch,
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
        "payload": None,
        "poll": None,
        # Mode preuve : le message supprimé reste lisible, et le client le
        # barre. Hors mode preuve, une suppression efface la ligne.
        "deleted_at": message.deleted_at.isoformat() if message.deleted_at else None,
        "deleted_by": message.deleted_by,
        "original_content": None,
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
    already_member = db.query(GroupMember.id).filter_by(
        group_id=invitation.group_id, user_id=user_id
    ).first() is not None
    group = (
        db.query(Group)
        .filter(Group.id == invitation.group_id)
        .with_for_update()
        .first()
    )
    try:
        member = group_invitation_service.accepter(db, invitation)
    except group_invitation_service.InvitationImpossible as exc:
        # 409 et non 400 : l'invitation a existé, elle n'est simplement plus
        # valable. Le client distingue « jamais reçue » de « trop tard ».
        raise HTTPException(status_code=409, detail=str(exc))
    if not already_member:
        group.crypto_epoch += 1
    db.commit()
    db.refresh(group)
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
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    # Nom et photo : tout membre si le groupe l'autorise (DIS-26). Les
    # réglages du groupe, eux, restent aux administrateurs.
    settings_fields = {"admins_only_messages", "disappearing_seconds", "members_can_edit_info", "join_approval"}
    touches_settings = bool(settings_fields & payload.model_fields_set)
    if touches_settings or not group.members_can_edit_info:
        _require_manager(db, group_id, user_id)
    else:
        _require_membership(db, group_id, user_id)

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
    if payload.members_can_edit_info is not None:
        group.members_can_edit_info = payload.members_can_edit_info
    if payload.join_approval is not None:
        group.join_approval = payload.join_approval

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
    group = (
        db.query(Group)
        .filter(Group.invite_code == invite_code)
        .with_for_update()
        .first()
    )
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

    if group.join_approval:
        # DIS-26 « Approuver les nouveaux membres » : le lien dépose une
        # demande ; un administrateur la valide.
        request = db.query(GroupJoinRequest).filter(
            GroupJoinRequest.group_id == group.id, GroupJoinRequest.user_id == user_id
        ).first()
        if request is None:
            request = GroupJoinRequest(group_id=group.id, user_id=user_id)
            db.add(request)
        request.status = "PENDING"
        request.decided_by = None
        request.decided_at = None
        db.commit()
        admins = [
            uid for (uid,) in db.query(GroupMember.user_id).filter(
                GroupMember.group_id == group.id, GroupMember.role.in_(_MANAGER_ROLES)
            )
        ]
        for admin_id in admins:
            await manager.send_to_user(admin_id, {"type": "group:join_request", "group_id": group.id})
        return JSONResponse(
            status_code=202,
            content={"pending_approval": True, "group_id": group.id, "name": group.name},
        )

    group.crypto_epoch += 1
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


@router.get("/{group_id}/join-requests")
async def list_join_requests(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    _require_manager(db, group_id, current_user["user_id"])
    rows = (
        db.query(GroupJoinRequest)
        .filter(GroupJoinRequest.group_id == group_id, GroupJoinRequest.status == "PENDING")
        .order_by(GroupJoinRequest.created_at)
        .all()
    )
    return {
        "items": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "display_name": _display_name(r.user),
                "created_at": r.created_at.isoformat(),
            }
            for r in rows
        ]
    }


class JoinDecision(BaseModel):
    approve: bool


@router.post("/{group_id}/join-requests/{request_id}")
async def decide_join_request(
    group_id: int,
    request_id: str,
    payload: JoinDecision,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    admin_id = current_user["user_id"]
    _require_manager(db, group_id, admin_id)
    request = db.query(GroupJoinRequest).filter(
        GroupJoinRequest.id == request_id, GroupJoinRequest.group_id == group_id
    ).first()
    if request is None or request.status != "PENDING":
        raise HTTPException(status_code=404, detail="Demande introuvable")
    request.status = "APPROVED" if payload.approve else "REJECTED"
    request.decided_by = admin_id
    request.decided_at = datetime.utcnow()
    group = db.query(Group).filter(Group.id == group_id).with_for_update().first()
    joined = False
    if payload.approve and not db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == request.user_id
    ).first():
        group.crypto_epoch += 1
        db.add(GroupMember(group_id=group_id, user_id=request.user_id, role="MEMBER"))
        joined = True
    db.commit()
    db.refresh(group)
    if joined:
        joiner = db.query(User).filter(User.id == request.user_id).first()
        await _broadcast(
            db,
            group_id,
            {
                "type": "group:member:added",
                "group_id": group_id,
                "group": _serialize_group(group),
                "member": {"user_id": request.user_id, "display_name": _display_name(joiner), "role": "MEMBER"},
            },
        )
    return {"status": request.status}


@router.delete("/{group_id}")
async def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Supprimer le groupe — réservé à son CRÉATEUR.

    Pour tous : la conversation, ses messages, ses invitations et ses clés
    disparaissent. Les cagnottes Kory et le journal d'appels ne pointent
    plus vers lui, mais restent (leur clé étrangère passe à NULL).

    Deux refus :
    - en mode preuve, la conversation sert de trace aux autres membres ;
      la supprimer reviendrait à effacer la preuve par la porte de service ;
    - le groupe d'annonces d'une communauté appartient à la communauté.
    """
    user_id = current_user["user_id"]
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    _require_membership(db, group_id, user_id)
    if group.created_by != user_id:
        raise HTTPException(
            status_code=403, detail="Seul le créateur peut supprimer le groupe"
        )
    if group.proof_mode:
        raise HTTPException(
            status_code=409,
            detail="Le mode preuve est actif : la discussion sert de trace aux membres et ne peut pas être supprimée.",
        )
    if group.is_announcement and group.community_id is not None:
        raise HTTPException(
            status_code=409,
            detail="Le groupe d'annonces appartient à sa communauté.",
        )

    member_ids = [
        row[0]
        for row in db.query(GroupMember.user_id).filter(GroupMember.group_id == group_id).all()
    ]
    # Explicite plutôt que de compter sur le ON DELETE CASCADE de la base :
    # même résultat, et vrai aussi là où les clés étrangères ne sont pas
    # appliquées (SQLite des tests).
    message_ids = [
        row[0] for row in db.query(GroupMessage.id).filter(GroupMessage.group_id == group_id).all()
    ]
    if message_ids:
        db.query(GroupMessageReaction).filter(
            GroupMessageReaction.message_id.in_(message_ids)
        ).delete(synchronize_session=False)
        db.query(GroupMessageMention).filter(
            GroupMessageMention.message_id.in_(message_ids)
        ).delete(synchronize_session=False)
    db.query(GroupMessage).filter(GroupMessage.group_id == group_id).delete(synchronize_session=False)
    db.query(GroupInvitation).filter(GroupInvitation.group_id == group_id).delete(synchronize_session=False)
    db.query(GroupSenderKeyDistribution).filter(
        GroupSenderKeyDistribution.group_id == group_id
    ).delete(synchronize_session=False)
    db.delete(group)
    db.commit()

    event = {"type": "group:deleted", "group_id": group_id}
    for member_id in member_ids:
        if member_id == user_id:
            continue
        try:
            await manager.send_to_user(member_id, event)
        except Exception:  # pragma: no cover - transport best-effort
            logger.warning("group:deleted non remis à %s", member_id, exc_info=True)
    return {"deleted": True, "group_id": group_id}


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

    group = db.query(Group).filter(Group.id == group_id).with_for_update().first()
    db.delete(target)
    group.crypto_epoch += 1
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


@router.get("/{group_id}/sender-key-distributions")
async def list_sender_key_distributions(
    group_id: int,
    epoch: Optional[int] = Query(None, ge=1),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    group = db.query(Group).filter(Group.id == group_id).first()
    requested_epoch = group.crypto_epoch if epoch is None else epoch
    if requested_epoch > group.crypto_epoch:
        raise HTTPException(status_code=409, detail="Époque de chiffrement invalide")
    rows = (
        db.query(GroupSenderKeyDistribution)
        .filter(
            GroupSenderKeyDistribution.group_id == group_id,
            GroupSenderKeyDistribution.epoch == requested_epoch,
            GroupSenderKeyDistribution.recipient_id == user_id,
        )
        .order_by(GroupSenderKeyDistribution.sender_id)
        .all()
    )
    return {
        "epoch": requested_epoch,
        "items": [
            {
                "sender_id": row.sender_id,
                "recipient_id": row.recipient_id,
                "epoch": row.epoch,
                "encryption": row.encryption,
                "ciphertext": row.ciphertext,
                "envelope": row.envelope,
            }
            for row in rows
        ],
    }


@router.post("/{group_id}/sender-key-distributions")
async def publish_sender_key_distributions(
    group_id: int,
    payload: SenderKeyDistributionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sender_id = current_user["user_id"]
    _require_membership(db, group_id, sender_id)
    group = db.query(Group).filter(Group.id == group_id).with_for_update().first()
    if payload.epoch != group.crypto_epoch:
        raise HTTPException(status_code=409, detail="Époque de chiffrement obsolète")
    expected = {
        member.user_id for member in group.members if member.user_id != sender_id
    }
    submitted = [item.recipient_id for item in payload.distributions]
    # Un SOUS-ENSEMBLE des membres est accepté : un membre qui ne peut pas
    # encore recevoir la clé (application trop ancienne, clés non publiées)
    # ne bloque plus l'envoi de tout le groupe — il la recevra à un envoi
    # suivant. Chaque destinataire doit en revanche être un membre actuel.
    if (
        not submitted
        or len(set(submitted)) != len(submitted)
        or not set(submitted) <= expected
    ):
        raise HTTPException(
            status_code=400,
            detail="Enveloppes pairwise invalides pour ce groupe",
        )
    for item in payload.distributions:
        existing = db.query(GroupSenderKeyDistribution).filter_by(
            group_id=group_id,
            epoch=group.crypto_epoch,
            sender_id=sender_id,
            recipient_id=item.recipient_id,
        ).first()
        if existing is not None:
            # Renvoyée (le destinataire a réinstallé, changé de clé) : la
            # nouvelle enveloppe remplace celle qu'il ne peut plus ouvrir.
            existing.encryption = item.encryption
            existing.ciphertext = item.ciphertext
            existing.envelope = item.envelope
        else:
            db.add(
                GroupSenderKeyDistribution(
                    group_id=group_id,
                    epoch=group.crypto_epoch,
                    sender_id=sender_id,
                    recipient_id=item.recipient_id,
                    encryption=item.encryption,
                    ciphertext=item.ciphertext,
                    envelope=item.envelope,
                )
            )
    db.commit()
    return {"accepted": True, "epoch": group.crypto_epoch}


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
    if payload.content is not None:
        raise HTTPException(status_code=400, detail="Les messages de groupe doivent être chiffrés")
    if payload.encryption != "sender-key-v1" or not payload.ciphertext:
        raise HTTPException(status_code=400, detail="Message de groupe chiffré requis")
    if payload.crypto_epoch != group.crypto_epoch:
        raise HTTPException(status_code=409, detail="Époque de chiffrement obsolète")
    if payload.mention_user_ids:
        raise HTTPException(
            status_code=400,
            detail="Les mentions de groupe doivent être incluses dans le contenu chiffré",
        )

    try:
        message_type = MessageType(payload.message_type.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail="Type de message invalide")

    media_asset = None
    if message_type == MessageType.TEXT:
        pass
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
        if message_type != MessageType.STICKER and media_asset.mime_type != "application/octet-stream":
            raise HTTPException(status_code=400, detail="Les fichiers de groupe doivent être chiffrés")

    if payload.reply_to_id:
        # Le message cité doit appartenir à CE groupe : sans cette
        # vérification, un membre pourrait faire remonter l'aperçu (auteur et
        # début du texte) d'un message d'un groupe où il n'est pas.
        quoted = db.query(GroupMessage).filter(
            GroupMessage.id == payload.reply_to_id, GroupMessage.group_id == group_id
        ).first()
        if not quoted:
            raise HTTPException(status_code=404, detail="Message cité introuvable")

    expected_recipients = {
        member.user_id for member in group.members if member.user_id != sender_id
    }
    delivered_recipients = {
        row.recipient_id
        for row in db.query(GroupSenderKeyDistribution).filter_by(
            group_id=group_id, epoch=group.crypto_epoch, sender_id=sender_id
        ).all()
    }
    # Au moins UN membre doit avoir reçu la clé de l'expéditeur ; ceux qui
    # ne l'ont pas encore la recevront plus tard (ou par re-livraison).
    if expected_recipients and not (delivered_recipients & expected_recipients):
        raise HTTPException(status_code=409, detail="Distribution de clé incomplète")

    # Mentions are currently carried only inside the ciphertext; the server
    # intentionally stores no per-user plaintext mention index.
    mention_ids: List[int] = []

    message = GroupMessage(
        group_id=group_id,
        sender_id=sender_id,
        message_type=message_type,
        content=None,
        encryption=payload.encryption,
        ciphertext=payload.ciphertext,
        crypto_epoch=payload.crypto_epoch,
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
    body = "Nouveau message chiffré"
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
    if payload.content is not None:
        raise HTTPException(status_code=400, detail="Les modifications doivent être chiffrées")
    group = db.query(Group).filter(Group.id == group_id).first()
    if payload.encryption != "sender-key-v1" or not payload.ciphertext:
        raise HTTPException(status_code=400, detail="Modification chiffrée requise")
    if payload.crypto_epoch != group.crypto_epoch:
        raise HTTPException(status_code=409, detail="Époque de chiffrement obsolète")
    expected_recipients = {
        member.user_id for member in group.members if member.user_id != user_id
    }
    delivered_recipients = {
        row.recipient_id
        for row in db.query(GroupSenderKeyDistribution).filter_by(
            group_id=group_id, epoch=group.crypto_epoch, sender_id=user_id
        ).all()
    }
    # Au moins UN membre doit avoir reçu la clé de l'expéditeur ; ceux qui
    # ne l'ont pas encore la recevront plus tard (ou par re-livraison).
    if expected_recipients and not (delivered_recipients & expected_recipients):
        raise HTTPException(status_code=409, detail="Distribution de clé incomplète")

    if message.sender_id != user_id:
        # 403 et non 404 : le message est bien visible de tout le groupe,
        # cacher son existence à un membre n'aurait aucun sens.
        raise HTTPException(status_code=403, detail="Vous ne pouvez modifier que vos propres messages")
    if message.deleted_at is not None:
        raise HTTPException(status_code=409, detail="Un message supprimé ne se modifie plus")
    if group.proof_mode:
        raise HTTPException(status_code=409, detail="La modification est désactivée en mode preuve")
    if message.message_type != MessageType.TEXT:
        # Remplacer une pièce jointe n'est pas une modification, c'est un
        # autre message : la précédente est déjà téléchargée chez les autres.
        raise HTTPException(status_code=400, detail="Seuls les messages texte peuvent être modifiés")
    if datetime.utcnow() - message.created_at > timedelta(minutes=_EDIT_WINDOW_MINUTES):
        raise HTTPException(
            status_code=409,
            detail=f"Un message ne peut plus être modifié après {_EDIT_WINDOW_MINUTES} minutes",
        )

    # Neither the old nor new version is retained in clear, including proof
    # mode. The server stores only the latest sender-key ciphertext.
    message.encryption = payload.encryption
    message.ciphertext = payload.ciphertext
    message.crypto_epoch = payload.crypto_epoch
    message.content = None
    message.original_content = None
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


class ProofModeBody(BaseModel):
    enabled: bool


@router.post("/{group_id}/proof-mode")
async def set_proof_mode(
    group_id: int,
    body: ProofModeBody,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Activer ou couper le mode preuve.

    Activer : tout membre qui a le badge (payé ou en essai), administrateur
    ou non. Couper : la personne qui l'a activé, ou un administrateur dont le
    badge est PAYÉ — l'essai ne donne pas ce droit (maquette 7). Le mode
    n'est jamais caché : un message système l'annonce dans le fil.
    """
    from app.api.v1.certified.certified import has_paid_badge, proof_mode_allowed

    user_id = current_user["user_id"]
    membership = _require_membership(db, group_id, user_id)
    group = db.query(Group).filter(Group.id == group_id).first()
    if body.enabled == bool(group.proof_mode):
        return _serialize_group_for(group, user_id)
    if body.enabled:
        if not proof_mode_allowed(db, user_id):
            raise HTTPException(status_code=403, detail="Le mode preuve demande Pokou certifié")
    else:
        is_activator = group.proof_mode_by == user_id
        if not is_activator and not (membership.role in _MANAGER_ROLES and has_paid_badge(db, user_id)):
            raise HTTPException(
                status_code=403,
                detail="Seule la personne qui l'a activé, ou un administrateur au badge payant, peut le désactiver",
            )
    group.proof_mode = body.enabled
    group.proof_mode_since = datetime.utcnow() if body.enabled else None
    group.proof_mode_by = user_id if body.enabled else None
    db.commit()
    await _broadcast(db, group_id, {
        "type": "group:proof_mode",
        "group_id": group_id,
        "enabled": body.enabled,
        "by": user_id,
    })
    return _serialize_group_for(group, user_id)


@router.get("/{group_id}/proof-export")
def export_proof(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """L'export daté (maquettes 8 et 9) : tout membre, tant que le groupe
    est en mode preuve. Depuis l'activation, messages supprimés et versions
    d'origine compris."""
    from fastapi.responses import Response as RawResponse

    from app.services.messaging.proof_export import render

    user_id = current_user["user_id"]
    _require_membership(db, group_id, user_id)
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group.proof_mode:
        raise HTTPException(status_code=409, detail="Le mode preuve n'est pas actif")
    rows = (
        db.query(GroupMessage)
        .filter(GroupMessage.group_id == group_id, GroupMessage.created_at >= group.proof_mode_since)
        .order_by(GroupMessage.created_at)
        .all()
    )
    messages = [{
        "sender": _display_name(m.sender),
        "created_at": m.created_at,
        "type": m.message_type.value,
        "content": None,
        "deleted_at": m.deleted_at,
        "original_content": None,
        "edited_at": m.edited_at,
    } for m in rows]
    me = db.query(User).filter(User.id == user_id).first()
    pdf = render(group.name, group.proof_mode_since, messages, _display_name(me))
    filename = f"pokou-preuve-{group_id}-{datetime.utcnow():%Y%m%d-%H%M}.pdf"
    return RawResponse(pdf, media_type="application/pdf",
                       headers={"Content-Disposition": f'attachment; filename="{filename}"'})


@router.delete("/{group_id}/messages/{message_id}")
async def delete_group_message(
    group_id: int,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Supprimer un message pour tout le groupe : son auteur, ou un admin.

    En mode preuve, la ligne chiffrée reste marquée supprimée. Hors mode
    preuve, elle est effacée.
    """
    user_id = current_user["user_id"]
    membership = _require_membership(db, group_id, user_id)
    message = _get_group_message(db, group_id, message_id)
    if message.sender_id != user_id and membership.role not in _MANAGER_ROLES:
        raise HTTPException(status_code=403, detail="Vous ne pouvez supprimer que vos propres messages")
    group = db.query(Group).filter(Group.id == group_id).first()
    if group.proof_mode:
        if message.deleted_at is None:
            message.deleted_at = datetime.utcnow()
            message.deleted_by = user_id
            db.commit()
            db.refresh(message)
        event = {"type": "group:message:edited", "group_id": group_id, "message": _serialize_message(message)}
        await _broadcast(db, group_id, event)
        return {"deleted": True, "kept_as_proof": True, "message": _serialize_message(message, user_id)}
    db.delete(message)
    db.commit()
    await _broadcast(db, group_id, {"type": "group:message:deleted", "group_id": group_id, "message_id": message_id})
    return {"deleted": True, "kept_as_proof": False, "message_id": message_id}


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
