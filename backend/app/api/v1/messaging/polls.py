"""Pokou — contenus riches sans pièce jointe : sondage, position partagée et
carte de visite, envoyables en 1:1 comme en groupe.

Pourquoi les trois dans le MÊME routeur (d'où `POST /polls/location` et
`POST /polls/contact-card`, dont le préfixe ne dit pas grand-chose) : ils ne
partagent pas qu'un préfixe d'URL, ils partagent toute la mécanique. Chacun
doit résoudre la conversation visée et vérifier le droit d'y écrire (contact
présent dans le carnet d'adresses en 1:1, appartenance au groupe en groupe),
créer un message d'un TYPE particulier portant une charge utile, puis le
diffuser aux participants par WebSocket avec repli sur la notification push
pour ceux qui ne sont pas connectés. Les éclater en trois routeurs
recopierait trois fois ce code d'autorisation et de diffusion — et c'est
précisément là que se logent les oublis de garde-fou.

La charge utile va dans `payload` (JSON) plutôt que dans un jeu de colonnes
par type, comme le documente `DirectMessage.payload` : le TYPE du message dit
comment la lire. Le sondage fait exception avec sa propre table parce qu'il a
des options et des votes, donc ses propres lignes de toute façon.

Les règles d'autorisation sont réécrites ici plutôt qu'importées de
messages.py / groups.py : ces deux modules gardent leurs helpers privés, et
un import croisé entre routers ferait dépendre l'envoi d'un sondage de
l'ordre d'import des modules de routes.
"""
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, NamedTuple, Optional, Union

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Channel, ChannelMember, ChannelPost, Contact, DirectMessage, Group, GroupMember, GroupMessage, MessageStatus, MessageType, Poll, PollOption, PollVote, User
from app.api.v1.messaging.ws import manager
from app.services.messaging import notification_policy
from app.services.notifications.push_service import send_push
from app.utils.phone import normalize_e164
from app.core.security import get_current_user

router = APIRouter(prefix="/polls", tags=["Pokou polls"])

_MANAGER_ROLES = ("OWNER", "ADMIN")

# Bornes d'un sondage : deux options pour qu'il y ait un choix à faire, douze
# pour que la liste tienne dans une bulle de conversation sans défilement
# (WhatsApp s'arrête aussi à douze).
_MIN_OPTIONS = 2
_MAX_OPTIONS = 12

# Fiches par carte de visite. Au-delà on partage un carnet d'adresses, pas un
# contact, et le destinataire n'a aucun moyen d'en faire quelque chose.
_MAX_CONTACT_CARDS = 10

# Durée maximale d'un partage de position EN DIRECT (8 h, le maximum de
# WhatsApp). Sans plafond, un partage devient un traceur permanent posé dans
# une conversation, que son auteur oublie d'avoir laissé ouvert.
_MAX_LIVE_SECONDS = 8 * 3600

_LATITUDE_BOUNDS = (-90.0, 90.0)
_LONGITUDE_BOUNDS = (-180.0, 180.0)


# ─── Corps de requête ─────────────────────────────────────────────────────────

class _TargetedCreate(BaseModel):
    """Cible commune aux trois envois : `kind` dit dans QUEL type de
    conversation écrire, `target_id` s'interprète d'après lui (l'id de l'autre
    utilisateur en 1:1, l'id du groupe en groupe). Un seul couple de champs
    plutôt que `recipient_id` et `group_id` nullables : on ne peut pas
    exprimer « les deux à la fois », qui n'a pas de sens ici."""
    kind: str = Field(..., pattern="^(contact|group)$")
    target_id: int


class PollCreate(_TargetedCreate):
    question: str = Field(..., min_length=1, max_length=500)
    options: List[str] = Field(default_factory=list)
    allows_multiple: bool = False


class PollVoteSet(BaseModel):
    """`option_ids` décrit l'ÉTAT voulu de mon vote, pas un incrément : la
    liste remplace l'ensemble de mes choix, et une liste vide retire mon vote.
    Un client qui rejoue deux fois la même requête (réseau capricieux) obtient
    donc le même résultat, ce qu'un « ajoute ce vote » ne garantirait pas."""
    option_ids: List[int] = Field(default_factory=list)


class LocationCreate(_TargetedCreate):
    latitude: float
    longitude: float
    label: Optional[str] = Field(None, max_length=200)
    # Accepte une date ISO ou un nombre de secondes : le client mobile connaît
    # « 15 minutes » (une durée choisie dans un menu), un client web calcule
    # plus volontiers une échéance. Refuser l'une des deux formes obligerait
    # l'un des deux à convertir avec sa propre horloge, souvent décalée.
    live_until: Optional[Union[int, float, str]] = None


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float


class ContactCardEntry(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=255)
    phone: str = Field(..., min_length=1, max_length=32)


class ContactCardCreate(_TargetedCreate):
    contacts: List[ContactCardEntry] = Field(default_factory=list)


# ─── Sérialisation ────────────────────────────────────────────────────────────

def _display_name(user: Optional[User]) -> str:
    if not user:
        return "Inconnu"
    return user.full_name or user.phone or f"#{user.id}"


def _serialize_poll(poll: Poll, viewer_id: Optional[int], *, reveal_voters: bool = True) -> dict:
    """Le sondage tel que le voit UNE personne : `mine` dépend du lecteur,
    donc l'événement poussé à chaque participant doit être calculé de son
    point de vue et non de celui de l'auteur de la requête.

    `reveal_voters=False` pour un sondage de CHAÎNE : dans une conversation ou
    un groupe, les votants sont publics et c'est voulu (savoir qui vient est
    souvent tout l'intérêt du sondage) — mais une chaîne est publique et peut
    avoir des milliers d'abonnés qui ne se connaissent pas. Y publier « qui a
    voté quoi » exposerait à des inconnus à la fois une opinion et
    l'identifiant du compte qui la porte. Le client reçoit alors
    `reveals_voters: false` pour pouvoir dire « liste masquée » plutôt que de
    laisser croire à zéro votant."""
    everyone: set = set()
    options: List[dict] = []
    for option in poll.options:
        # Ordonné par ancienneté du vote : la liste des votants ne doit pas se
        # réordonner sous les yeux du lecteur à chaque rafraîchissement.
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
                # Les votants sont publics chez WhatsApp, et c'est voulu : un
                # sondage de groupe sert surtout à savoir QUI vient. Une
                # chaîne, elle, ne les révèle pas (voir reveal_voters).
                "voters": voters if reveal_voters else [],
                # Évite au client de chercher son propre id dans `voters` à
                # chaque rendu de barre.
                "mine": viewer_id in voters,
            }
        )
    return {
        "id": poll.id,
        "question": poll.question,
        "allows_multiple": bool(poll.allows_multiple),
        "reveals_voters": reveal_voters,
        "options": options,
        # Des PERSONNES, pas des votes : en choix multiple la somme des
        # `vote_count` dépasse le nombre de participants et ne peut pas servir
        # de dénominateur aux pourcentages.
        "total_voters": len(everyone),
    }


def _serialize_direct(message: DirectMessage, viewer_id: Optional[int]) -> dict:
    """Volontairement un SUR-ENSEMBLE de ce que renvoie messages.py : mêmes
    clés, plus `payload` et `poll`. Le client traite déjà `message:new` avec
    cette forme, et un message de sondage/position ne doit pas arriver avec
    une forme différente des autres — sinon chaque bulle exigerait un test sur
    l'origine de l'événement."""
    return {
        "id": message.id,
        "sender_id": message.sender_id,
        "recipient_id": message.recipient_id,
        "message_type": message.message_type.value,
        "content": message.content,
        "media_asset_id": message.media_asset_id,
        "media": None,
        "status": message.status.value,
        "created_at": message.created_at.isoformat(),
        "delivered_at": message.delivered_at.isoformat() if message.delivered_at else None,
        "read_at": message.read_at.isoformat() if message.read_at else None,
        "reply_to_id": message.reply_to_id,
        "reply_to": None,
        "reactions": [],
        "edited_at": message.edited_at.isoformat() if message.edited_at else None,
        "expires_at": message.expires_at.isoformat() if message.expires_at else None,
        "view_once": bool(message.view_once),
        "viewed_at": message.viewed_at.isoformat() if message.viewed_at else None,
        "payload": message.payload,
        "poll": _serialize_poll(message.poll, viewer_id) if message.poll else None,
    }


def _serialize_group_message(message: GroupMessage, viewer_id: Optional[int]) -> dict:
    """Même parti pris que `_serialize_direct` : sur-ensemble de la forme
    renvoyée par groups.py."""
    return {
        "id": message.id,
        "group_id": message.group_id,
        "sender_id": message.sender_id,
        "sender_name": _display_name(message.sender),
        "message_type": message.message_type.value,
        "content": message.content,
        "media_asset_id": message.media_asset_id,
        "media": None,
        "created_at": message.created_at.isoformat(),
        "payload": message.payload,
        "poll": _serialize_poll(message.poll, viewer_id) if message.poll else None,
    }


def _serialize(message: Union[DirectMessage, GroupMessage], viewer_id: Optional[int]) -> dict:
    if isinstance(message, DirectMessage):
        return _serialize_direct(message, viewer_id)
    return _serialize_group_message(message, viewer_id)


# ─── Autorisation ─────────────────────────────────────────────────────────────

class _Target(NamedTuple):
    kind: str
    group: Optional[Group]
    contact: Optional[Contact]
    recipient_id: Optional[int]


def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> Contact:
    """Même règle que messages.py::_require_contact : on n'écrit qu'à
    quelqu'un présent dans son propre carnet d'adresses, ce qui empêche
    d'arroser des utilisateurs arbitraires en devinant des user_id.

    Renvoie la ligne Contact, qui porte le réglage d'éphémère de la
    conversation — inutile de la relire ensuite."""
    contact = db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first()
    if not contact:
        raise HTTPException(status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses")
    return contact


def _require_membership(db: Session, group_id: int, user_id: int) -> GroupMember:
    """Même règle que groups.py::_require_membership. 403 et non 404 y compris
    pour un groupe inexistant : la réponse ne distingue pas « ce groupe n'est
    pas à vous » de « ce groupe n'existe pas », donc elle ne permet pas
    d'énumérer les groupes des autres."""
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")
    return membership


def _require_can_post(group: Group, membership: GroupMember) -> None:
    """Un groupe d'annonces (ou verrouillé par ses admins) reste verrouillé
    pour les contenus riches : sans ce contrôle, poster un « sondage » serait
    la porte dérobée par laquelle un membre simple reprendrait la parole là
    où groups.py la lui refuse."""
    if not (group.is_announcement or group.admins_only_messages):
        return
    if membership.role not in _MANAGER_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Seuls les administrateurs peuvent publier dans ce groupe",
        )


def _resolve_target(db: Session, kind: str, target_id: int, sender_id: int) -> _Target:
    if kind == "group":
        membership = _require_membership(db, target_id, sender_id)
        group = db.query(Group).filter(Group.id == target_id).first()
        if not group:
            raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")
        _require_can_post(group, membership)
        return _Target("group", group, None, None)

    if target_id == sender_id:
        raise HTTPException(status_code=400, detail="Impossible de s'envoyer un message à soi-même")
    contact = _require_contact(db, sender_id, target_id)
    return _Target("contact", None, contact, target_id)


def _participants(db: Session, message: Union[DirectMessage, GroupMessage]) -> List[int]:
    if isinstance(message, DirectMessage):
        return [message.sender_id, message.recipient_id]
    return [
        row[0]
        for row in db.query(GroupMember.user_id)
        .filter(GroupMember.group_id == message.group_id)
        .all()
    ]


def _require_participant(
    db: Session,
    message: Union[DirectMessage, GroupMessage],
    user_id: int,
    detail: str,
) -> None:
    """404 et non 403 : répondre « interdit » confirmerait à un inconnu que ce
    sondage / cette position existe bien, alors qu'il n'a aucun titre à en
    connaître l'existence."""
    if user_id not in _participants(db, message):
        raise HTTPException(status_code=404, detail=detail)


def _carrier_of_poll(
    db: Session, poll_id: str, user_id: int
) -> Union[DirectMessage, GroupMessage, ChannelPost]:
    """Retrouve le message qui porte le sondage — et VÉRIFIE au passage l'accès
    à sa conversation : connaître l'identifiant d'un sondage ne doit jamais
    suffire à le lire ni à y voter (un identifiant circule — capture d'écran,
    journal client, message transféré).

    Un sondage n'a qu'un seul message porteur : le transfert d'un message ne
    recopie pas `poll_id` (voir messages.py::forward_message), il n'y a donc
    pas de second exemplaire par lequel un tiers hériterait d'un droit de
    vote."""
    direct = db.query(DirectMessage).filter(DirectMessage.poll_id == poll_id).first()
    if direct is not None:
        _require_participant(db, direct, user_id, "Sondage introuvable")
        return direct

    group_message = db.query(GroupMessage).filter(GroupMessage.poll_id == poll_id).first()
    if group_message is not None:
        _require_participant(db, group_message, user_id, "Sondage introuvable")
        return group_message

    # Sondage d'une CHAÎNE. Une chaîne PUBLIQUE se lit sans être abonné (voir
    # channels.py::list_posts) : l'existence de la publication suffit. Une
    # chaîne PRIVÉE, elle, est introuvable sans abonnement — y voter ou y lire
    # un sondage avec un simple identifiant contournerait cette règle.
    channel_post = db.query(ChannelPost).filter(ChannelPost.poll_id == poll_id).first()
    if channel_post is None:
        raise HTTPException(status_code=404, detail="Sondage introuvable")
    channel = db.query(Channel).filter(Channel.id == channel_post.channel_id).first()
    if channel is not None and channel.is_private:
        is_member = (
            db.query(ChannelMember.id)
            .filter(ChannelMember.channel_id == channel.id, ChannelMember.user_id == user_id)
            .first()
            is not None
        )
        if not is_member:
            raise HTTPException(status_code=404, detail="Sondage introuvable")
    return channel_post


def _find_message(db: Session, message_id: str) -> Optional[Union[DirectMessage, GroupMessage]]:
    """Les identifiants sont des uuid tirés du même espace : un message donné
    est dans une table ou dans l'autre, jamais dans les deux."""
    direct = db.query(DirectMessage).filter(DirectMessage.id == message_id).first()
    if direct is not None:
        return direct
    return db.query(GroupMessage).filter(GroupMessage.id == message_id).first()


# ─── Création et diffusion ────────────────────────────────────────────────────

def _expires_at(target: _Target) -> Optional[datetime]:
    """Échéance d'éphémère figée à l'envoi d'après le réglage de la
    conversation, jamais recalculée à la lecture : changer le réglage ne doit
    pas réécrire le sort des messages déjà partis (voir messages.py)."""
    seconds = target.contact.disappearing_seconds if target.kind == "contact" else target.group.disappearing_seconds
    return datetime.utcnow() + timedelta(seconds=seconds) if seconds else None


def _create_message(
    db: Session,
    target: _Target,
    sender_id: int,
    message_type: MessageType,
    *,
    caption: Optional[str],
    payload: Optional[Dict[str, Any]] = None,
    poll_id: Optional[str] = None,
) -> Union[DirectMessage, GroupMessage]:
    """`caption` part dans `content` : c'est un libellé lisible du contenu
    riche (la question du sondage, le nom du lieu, les noms partagés), pour
    que les historiques qui ne savent pas encore lire `payload` affichent
    quelque chose au lieu d'une bulle vide, et pour que la recherche
    plein-texte des conversations retrouve un sondage. `payload` (et la table
    polls) restent la source de vérité ; `content` n'est qu'un reflet figé à
    l'envoi."""
    if target.kind == "contact":
        message: Union[DirectMessage, GroupMessage] = DirectMessage(
            sender_id=sender_id,
            recipient_id=target.recipient_id,
            message_type=message_type,
            content=caption,
            payload=payload,
            poll_id=poll_id,
            expires_at=_expires_at(target),
        )
    else:
        message = GroupMessage(
            group_id=target.group.id,
            sender_id=sender_id,
            message_type=message_type,
            content=caption,
            payload=payload,
            poll_id=poll_id,
            expires_at=_expires_at(target),
        )
    db.add(message)
    db.commit()
    db.refresh(message)
    return message


async def _dispatch_new_message(
    db: Session,
    target: _Target,
    message: Union[DirectMessage, GroupMessage],
    sender_id: int,
    push_body: str,
) -> None:
    """Pousse le nouveau message aux participants, et bascule en notification
    push pour ceux que le WebSocket n'a pas joints (app fermée ou en
    arrière-plan). L'auteur est exclu : il a déjà l'état à jour dans sa
    réponse HTTP.

    Les valeurs de `data.type` sont celles de messages.py et groups.py
    (`message` / `group_message`) : le client route déjà ces notifications
    vers la bonne conversation, un type inédit l'obligerait à apprendre trois
    nouveaux cas pour ouvrir exactement les mêmes écrans."""
    sender = db.query(User).filter(User.id == sender_id).first()
    sender_name = _display_name(sender)

    if isinstance(message, DirectMessage):
        recipient_id = message.recipient_id
        delivered = await manager.send_to_user(
            recipient_id,
            {"type": "message:new", "message": _serialize_direct(message, recipient_id)},
        )
        if delivered:
            message.status = MessageStatus.DELIVERED
            message.delivered_at = datetime.utcnow()
            db.commit()
            db.refresh(message)
            return
        decision = notification_policy.decide(
            db,
            recipient_id=recipient_id,
            event=notification_policy.NotificationEvent.POLL,
            sender_id=sender_id,
        )
        if not decision.deliver:
            return
        send_push(
            db,
            recipient_id,
            title=sender_name,
            body=push_body,
            data={
                "type": "message",
                "contact_user_id": str(sender_id),
                "contact_name": sender_name,
                **decision.as_payload(),
            },
        )
        return

    group = target.group
    member_ids = [member_id for member_id in _participants(db, message) if member_id != sender_id]
    reached = set()
    for member_id in member_ids:
        if await manager.send_to_user(
            member_id,
            {"type": "group:message:new", "message": _serialize_group_message(message, member_id)},
        ):
            reached.add(member_id)

    for member_id in member_ids:
        if member_id in reached:
            continue
        decision = notification_policy.decide(
            db,
            recipient_id=member_id,
            event=notification_policy.NotificationEvent.POLL,
            group_id=group.id,
        )
        if not decision.deliver:
            continue
        send_push(
            db,
            member_id,
            title=group.name,
            body=f"{sender_name}: {push_body}",
            data={
                "type": "group_message",
                "group_id": str(group.id),
                "group_name": group.name,
                **decision.as_payload(),
            },
        )


async def _broadcast_to_participants(
    db: Session,
    message: Union[DirectMessage, GroupMessage],
    actor_id: int,
    event: Dict[str, Any],
    *,
    per_viewer_key: Optional[str] = None,
    per_viewer=None,
) -> None:
    """Diffuse un événement de MISE À JOUR aux autres participants.

    `per_viewer` recalcule la partie de l'événement qui dépend du lecteur (le
    `mine` des options d'un sondage) : diffuser tel quel l'état vu par le
    votant afficherait son propre choix comme celui de tout le monde."""
    for viewer_id in _participants(db, message):
        if viewer_id == actor_id:
            continue
        payload = dict(event)
        if per_viewer_key and per_viewer is not None:
            payload[per_viewer_key] = per_viewer(viewer_id)
        await manager.send_to_user(viewer_id, payload)


# ─── Sondages ─────────────────────────────────────────────────────────────────

def _clean_options(raw: Iterable[str]) -> List[str]:
    """Les options vides sont retirées AVANT de compter : un formulaire mobile
    envoie volontiers deux champs vides en fin de liste, et les compter
    laisserait créer un sondage à une seule vraie réponse."""
    cleaned = [text.strip() for text in raw if text and text.strip()]
    if len(cleaned) < _MIN_OPTIONS:
        raise HTTPException(
            status_code=400, detail=f"Un sondage demande au moins {_MIN_OPTIONS} options"
        )
    if len(cleaned) > _MAX_OPTIONS:
        raise HTTPException(
            status_code=400, detail=f"Un sondage accepte au plus {_MAX_OPTIONS} options"
        )
    return cleaned


@router.post("")
async def create_poll(
    body: PollCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée le sondage ET le message qui le porte, en une seule requête : un
    sondage sans message n'est visible de personne, et un client qui ferait
    les deux appels laisserait des sondages orphelins à chaque coupure entre
    les deux."""
    sender_id = current_user["user_id"]
    question = body.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="La question du sondage est requise")
    options = _clean_options(body.options)
    target = _resolve_target(db, body.kind, body.target_id, sender_id)

    poll = Poll(question=question, allows_multiple=body.allows_multiple, created_by=sender_id)
    db.add(poll)
    db.flush()  # besoin de poll.id pour l'attacher aux options et au message
    for position, text in enumerate(options):
        db.add(PollOption(poll_id=poll.id, text=text, position=position))
    # Flush et non commit : le sondage, ses options et le message qui le porte
    # partent dans la MÊME transaction (c'est _create_message qui valide).
    # Valider ici laisserait un sondage orphelin, invisible de tous, si
    # l'écriture du message échouait ensuite.
    db.flush()

    message = _create_message(
        db, target, sender_id, MessageType.POLL, caption=question, poll_id=poll.id
    )
    # Le TYPE, pas la question — elle est écrite par un humain et peut être
    # aussi révélatrice qu'un message.
    await _dispatch_new_message(db, target, message, sender_id, "Nouveau sondage")
    return _serialize(message, sender_id)


@router.post("/{poll_id}/vote")
async def vote(
    poll_id: str,
    body: PollVoteSet,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    poll = db.query(Poll).filter(Poll.id == poll_id).first()
    if not poll:
        raise HTTPException(status_code=404, detail="Sondage introuvable")
    message = _carrier_of_poll(db, poll.id, user_id)

    wanted = list(dict.fromkeys(body.option_ids))  # dédoublonné, ordre conservé
    if not poll.allows_multiple and len(wanted) > 1:
        raise HTTPException(status_code=400, detail="Ce sondage n'accepte qu'une seule réponse")

    option_ids = {option.id for option in poll.options}
    unknown = [option_id for option_id in wanted if option_id not in option_ids]
    if unknown:
        # 400 et non 404 : le sondage existe et est accessible, c'est la
        # requête qui désigne une option d'ailleurs (autre sondage, option
        # supprimée entre-temps).
        raise HTTPException(status_code=400, detail="Option inconnue pour ce sondage")

    existing = {
        vote_row.option_id: vote_row
        for vote_row in db.query(PollVote)
        .filter(PollVote.option_id.in_(option_ids), PollVote.user_id == user_id)
        .all()
    }
    # Différence et non « tout supprimer puis tout réinsérer » : SQLAlchemy
    # ordonne les insertions AVANT les suppressions dans un même flush, donc
    # revoter la même option violerait uq_poll_vote. Au passage, un vote
    # conservé garde son `created_at`, et la liste des votants ne se réordonne
    # pas parce qu'on a ajouté un second choix.
    for option_id, vote_row in existing.items():
        if option_id not in wanted:
            db.delete(vote_row)
    for option_id in wanted:
        if option_id not in existing:
            db.add(PollVote(option_id=option_id, user_id=user_id))
    db.commit()
    db.refresh(poll)

    # Pas de diffusion pour un sondage de chaîne : une chaîne n'a pas de
    # « participants » à qui pousser un événement, elle a des abonnés dont le
    # nombre n'est pas borné — un message WebSocket par abonné à CHAQUE vote
    # serait une décision d'architecture (fan-out de diffusion) qui n'a pas à
    # se prendre dans une route de vote. Le votant reçoit l'état à jour dans
    # la réponse, les autres au prochain chargement du fil.
    if not isinstance(message, ChannelPost):
        await _broadcast_to_participants(
            db,
            message,
            user_id,
            {"type": "poll:vote", "poll_id": poll.id, "message_id": message.id},
            per_viewer_key="poll",
            per_viewer=lambda viewer_id: _serialize_poll(poll, viewer_id),
        )
    return _serialize_poll(poll, user_id, reveal_voters=not isinstance(message, ChannelPost))


@router.get("/{poll_id}")
async def get_poll(
    poll_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    poll = db.query(Poll).filter(Poll.id == poll_id).first()
    if not poll:
        raise HTTPException(status_code=404, detail="Sondage introuvable")
    carrier = _carrier_of_poll(db, poll.id, user_id)
    return _serialize_poll(poll, user_id, reveal_voters=not isinstance(carrier, ChannelPost))


# ─── Position partagée ────────────────────────────────────────────────────────

def _check_coordinates(latitude: float, longitude: float) -> None:
    """Bornes vérifiées côté serveur : une latitude de 200 vient d'un capteur
    ou d'une conversion d'unités cassée, et une fois stockée elle fait planter
    la carte de tous les destinataires, sans moyen de corriger le message."""
    if not _LATITUDE_BOUNDS[0] <= latitude <= _LATITUDE_BOUNDS[1]:
        raise HTTPException(status_code=400, detail="Latitude invalide : attendue entre -90 et 90")
    if not _LONGITUDE_BOUNDS[0] <= longitude <= _LONGITUDE_BOUNDS[1]:
        raise HTTPException(
            status_code=400, detail="Longitude invalide : attendue entre -180 et 180"
        )


def _parse_live_until(raw: Optional[Union[int, float, str]]) -> Optional[datetime]:
    """Interprète une durée en secondes ou une date ISO, et renvoie une date
    UTC naïve — toutes les colonnes de dates du modèle le sont (datetime.utcnow),
    mélanger une date avec fuseau ferait échouer la comparaison d'expiration."""
    if raw is None:
        return None
    if isinstance(raw, bool):
        raise HTTPException(status_code=400, detail="live_until invalide")

    seconds: Optional[float] = None
    if isinstance(raw, (int, float)):
        seconds = float(raw)
    else:
        text = raw.strip()
        if not text:
            return None
        if re.fullmatch(r"\d+(\.\d+)?", text):
            seconds = float(text)

    if seconds is not None:
        if seconds <= 0:
            raise HTTPException(
                status_code=400, detail="La durée du partage en direct doit être positive"
            )
        if seconds > _MAX_LIVE_SECONDS:
            raise HTTPException(
                status_code=400,
                detail=f"Un partage en direct ne peut pas dépasser {_MAX_LIVE_SECONDS // 3600} heures",
            )
        return datetime.utcnow() + timedelta(seconds=seconds)

    try:
        parsed = datetime.fromisoformat(str(raw).strip().replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(
            status_code=400, detail="live_until invalide : attendu une date ISO ou un nombre de secondes"
        )
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    now = datetime.utcnow()
    if parsed <= now:
        raise HTTPException(
            status_code=400, detail="La fin du partage en direct est déjà passée"
        )
    if parsed - now > timedelta(seconds=_MAX_LIVE_SECONDS):
        raise HTTPException(
            status_code=400,
            detail=f"Un partage en direct ne peut pas dépasser {_MAX_LIVE_SECONDS // 3600} heures",
        )
    return parsed


def _location_payload(
    latitude: float, longitude: float, label: Optional[str], live_until: Optional[datetime]
) -> Dict[str, Any]:
    return {
        "latitude": latitude,
        "longitude": longitude,
        "label": label,
        # Sérialisée en texte ISO : la colonne est du JSON, elle ne sait pas
        # transporter un datetime.
        "live_until": live_until.isoformat() if live_until else None,
    }


@router.post("/location")
async def share_location(
    body: LocationCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sender_id = current_user["user_id"]
    _check_coordinates(body.latitude, body.longitude)
    live_until = _parse_live_until(body.live_until)
    label = body.label.strip() if body.label else None
    target = _resolve_target(db, body.kind, body.target_id, sender_id)

    message = _create_message(
        db,
        target,
        sender_id,
        MessageType.LOCATION,
        caption=label,
        payload=_location_payload(body.latitude, body.longitude, label, live_until),
    )
    push_body = "Position en direct" if live_until else "Position partagée"
    await _dispatch_new_message(
        # Sans le libellé du lieu : « Position partagée — Clinique Saint-Joseph »
        # en dit beaucoup trop sur un écran verrouillé.
        db, target, message, sender_id, push_body
    )
    return _serialize(message, sender_id)


def _require_location_message(
    db: Session, message_id: str, user_id: int
) -> Union[DirectMessage, GroupMessage]:
    message = _find_message(db, message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    _require_participant(db, message, user_id, "Message introuvable")
    if message.message_type != MessageType.LOCATION:
        raise HTTPException(status_code=400, detail="Ce message n'est pas une position")
    return message


@router.get("/location/{message_id}")
async def read_location(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Relire une position, expirée ou non. Un partage en direct terminé reste
    lisible comme DERNIÈRE position connue : le message ne disparaît pas de la
    conversation, seule sa mise à jour s'arrête — c'est ce que dit
    `live_expired`, pour que le client cesse d'afficher « en direct » sans
    effacer le point de la carte."""
    user_id = current_user["user_id"]
    message = _require_location_message(db, message_id, user_id)
    payload = dict(message.payload or {})
    live_until = payload.get("live_until")
    return {
        **_serialize(message, user_id),
        "live_expired": bool(live_until)
        and datetime.fromisoformat(live_until) <= datetime.utcnow(),
    }


@router.put("/location/{message_id}")
async def update_live_location(
    message_id: str,
    body: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Nouveau point d'un partage EN DIRECT : on modifie le message existant
    au lieu d'en envoyer un nouveau, sinon un trajet de vingt minutes
    remplirait la conversation d'une centaine de bulles."""
    user_id = current_user["user_id"]
    _check_coordinates(body.latitude, body.longitude)
    message = _require_location_message(db, message_id, user_id)

    if message.sender_id != user_id:
        # 403 et non 404 : le demandeur participe à la conversation, il VOIT
        # ce message. Le lui cacher serait mentir sur un état qu'il connaît.
        raise HTTPException(
            status_code=403, detail="Seul l'auteur peut mettre à jour sa position"
        )

    payload = dict(message.payload or {})
    live_until = payload.get("live_until")
    if not live_until:
        raise HTTPException(
            status_code=409, detail="Cette position n'est pas partagée en direct"
        )
    if datetime.fromisoformat(live_until) <= datetime.utcnow():
        raise HTTPException(
            status_code=409, detail="Le partage de position en direct est terminé"
        )

    payload["latitude"] = body.latitude
    payload["longitude"] = body.longitude
    payload["updated_at"] = datetime.utcnow().isoformat()
    # Réassignation du dictionnaire entier : SQLAlchemy ne surveille pas les
    # mutations INTERNES d'une colonne JSON, muter payload en place ne
    # produirait aucun UPDATE.
    message.payload = payload
    db.commit()
    db.refresh(message)

    await _broadcast_to_participants(
        db,
        message,
        user_id,
        {
            "type": "location:update",
            "message_id": message.id,
            "latitude": body.latitude,
            "longitude": body.longitude,
            "live_until": live_until,
        },
    )
    return _serialize(message, user_id)


# ─── Carte de visite ──────────────────────────────────────────────────────────

@router.post("/contact-card")
async def share_contact_card(
    body: ContactCardCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Partage d'une ou plusieurs fiches. Les numéros sont normalisés en E.164
    à l'ENTRÉE : le destinataire n'a qu'à toucher la fiche pour appeler ou
    ajouter le contact, et stocker « 90 12 34 56 » lui laisserait un numéro
    inutilisable sans savoir de quel pays il vient."""
    sender_id = current_user["user_id"]
    if not body.contacts:
        raise HTTPException(status_code=400, detail="Au moins un contact est requis")
    if len(body.contacts) > _MAX_CONTACT_CARDS:
        raise HTTPException(
            status_code=400, detail=f"Au plus {_MAX_CONTACT_CARDS} contacts par message"
        )

    cards: List[Dict[str, str]] = []
    for entry in body.contacts:
        display_name = entry.display_name.strip()
        if not display_name:
            raise HTTPException(status_code=400, detail="Le nom du contact est requis")
        phone = normalize_e164(entry.phone)
        if not phone:
            raise HTTPException(
                status_code=400, detail=f"Numéro de téléphone invalide : {entry.phone}"
            )
        cards.append({"display_name": display_name, "phone": phone})

    target = _resolve_target(db, body.kind, body.target_id, sender_id)
    caption = ", ".join(card["display_name"] for card in cards)
    message = _create_message(
        db,
        target,
        sender_id,
        MessageType.CONTACT,
        caption=caption,
        payload={"contacts": cards},
    )
    # Le type, pas le nom de la personne partagée : c'est la donnée d'un
    # tiers qui n'a rien demandé.
    await _dispatch_new_message(db, target, message, sender_id, "Fiche contact")
    return _serialize(message, sender_id)
