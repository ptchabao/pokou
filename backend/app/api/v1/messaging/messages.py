"""Pokou — messagerie personne-à-personne. Persistance + poussée temps réel
via app/routes/ws.py::manager si le destinataire est connecté."""
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.database import get_db
from app.models import Contact, MarketplaceProduct, DirectMessage, DirectProofMode, GroupMember, MediaAsset, MessageReaction, MessageStatus, MessageType, Poll, PollOption, User
from app.services.media import sticker_service
from app.services.auth.otp_service import OTPInvalidError, normalize_phone
from app.utils.editing import MESSAGE_EDIT_WINDOW, MESSAGE_EDIT_WINDOW_MINUTES
from app.utils.identity import nom_affiche
from app.core.security import get_current_user
from app.api.v1.modules import streak_lock
from app.api.v1.messaging.ws import manager
from app.services.messaging import notification_policy
from app.services.messaging.sync_service import append_sync_event, public_event_id
from app.services.notifications.push_service import send_push

router = APIRouter(prefix="/messages", tags=["Pokou messages"])

#: Seule version de chiffrement acceptée. Un entier de version explicite dans
#: chaque message est ce qui permettra d'en changer un jour sans casser
#: l'historique : les anciens messages restent lisibles par l'ancien chemin.
ENCRYPTION_VERSION = "v1"

# Fenêtre de modification — voir app/utils/editing.py, qui porte la valeur
# et la raison. Réexportée sous son nom historique : plusieurs tests
# l'importent depuis ici.
EDIT_WINDOW = MESSAGE_EDIT_WINDOW

# Durées de disparition proposées par WhatsApp (24 h, 7 jours, 90 jours).
# Liste fermée et non durée libre : le client affiche trois libellés, et une
# valeur arbitraire (3 secondes) ferait un historique inutilisable.
DISAPPEARING_CHOICES = (86400, 604800, 7776000)

# Aperçu d'un message cité : de quoi reconnaître la phrase citée dans une
# bulle de deux lignes, pas de quoi recopier le message.
REPLY_PREVIEW_LENGTH = 120

# Seuls ces types se prêtent à la vue unique : un document ou une note vocale
# se rejouent hors de l'app de toute façon, la promesse serait mensongère.
VIEW_ONCE_TYPES = (MessageType.IMAGE, MessageType.VIDEO)


class MessageCreate(BaseModel):
    recipient_id: int
    #: Numéro du destinataire, quand il n'est pas dans le carnet. C'est la
    #: PREUVE qu'on ne devine pas un identifiant : voir _require_reachable.
    #: Inutile une fois la conversation ouverte — l'historique suffit alors.
    recipient_phone: Optional[str] = Field(None, max_length=32)
    content: Optional[str] = Field(None, max_length=4000)
    #: Chiffrement de bout en bout. Fourni, `content` est ignoré et jamais
    #: écrit : le serveur ne doit pas conserver une copie en clair de ce
    #: qu'il vient d'accepter sous forme chiffrée, sinon le chiffrement ne
    #: sert plus à rien.
    encryption: Optional[str] = Field(None, max_length=8)
    ciphertext: Optional[str] = Field(None, max_length=32000)
    envelope: Optional[dict] = None
    message_type: str = "TEXT"
    media_asset_id: Optional[int] = None
    reply_to_id: Optional[str] = None
    view_once: bool = False


class MessageForward(BaseModel):
    recipient_id: int
    recipient_phone: Optional[str] = Field(None, max_length=32)


class MessageEdit(BaseModel):
    #: Facultatif quand le message est chiffré — le nouveau texte voyage
    #: alors dans `ciphertext`, et `content` n'aurait rien à porter.
    content: str = Field("", max_length=4000)
    ciphertext: Optional[str] = Field(None, max_length=32000)
    envelope: Optional[dict] = None


class ReactionSet(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=16)


class DisappearingUpdate(BaseModel):
    """`null` est une valeur légitime — c'est ainsi qu'on désactive les
    messages éphémères, d'où l'Optional plutôt qu'un champ requis."""
    seconds: Optional[int] = None


def _serialize_reply_preview(quoted: Optional[DirectMessage]) -> Optional[dict]:
    """Aperçu compact du message cité : le client doit pouvoir dessiner la
    citation sans second appel, mais l'aperçu ne porte JAMAIS la citation du
    message cité — sinon une chaîne de réponses de proche en proche ferait
    grossir la réponse indéfiniment."""
    if quoted is None:
        return None
    content = quoted.content
    if content and len(content) > REPLY_PREVIEW_LENGTH:
        content = content[:REPLY_PREVIEW_LENGTH] + "…"
    return {
        "id": quoted.id,
        "sender_id": quoted.sender_id,
        "message_type": quoted.message_type.value,
        "content": content,
        "media": _serialize_media(quoted.media_asset) if quoted.media_asset else None,
    }


def _serialize_reactions(message: DirectMessage, viewer_id: Optional[int]) -> List[dict]:
    """Agrégé par emoji : l'interface affiche « 👍 3 », pas trois lignes.
    `mine` évite au client de chercher son propre id dans `user_ids`, ce
    qu'il devrait faire à chaque rendu de bulle."""
    grouped: Dict[str, List[int]] = {}
    for reaction in message.reactions:
        grouped.setdefault(reaction.emoji, []).append(reaction.user_id)
    return [
        {
            "emoji": emoji,
            "count": len(user_ids),
            "user_ids": user_ids,
            "mine": viewer_id in user_ids,
        }
        for emoji, user_ids in grouped.items()
    ]


def _serialize_poll(poll: Poll, viewer_id: Optional[int]) -> dict:
    """Même forme que app/routes/polls.py::_serialize_poll — un sondage
    rendu par CETTE route doit avoir la forme que le client sait déjà lire
    depuis l'événement WebSocket `poll:vote` / la réponse d'envoi, sinon
    recharger la conversation ferait disparaître les barres de vote qui
    s'affichaient l'instant d'avant.

    Dupliquée plutôt qu'importée de polls.py : chaque routeur garde ses
    propres helpers privés, un import croisé ferait dépendre l'affichage
    d'un sondage de l'ordre de chargement des modules de routes."""
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
        # Toujours vrai en conversation : les votants y sont publics. Le champ
        # existe pour que la forme du sondage soit la même partout — une
        # chaîne, elle, le renvoie à faux (voir polls.py::_serialize_poll).
        "reveals_voters": True,
        "options": options,
        "total_voters": len(everyone),
    }


def _serialize(message: DirectMessage, viewer_id: Optional[int] = None) -> dict:
    """`viewer_id` n'est là que pour `reactions[].mine` : la sérialisation
    dépend de QUI regarde, et l'événement WebSocket poussé à l'autre partie
    doit donc être calculé de son point de vue, pas de celui de l'auteur de
    la requête."""
    return {
        "id": message.id,
        "sender_id": message.sender_id,
        "recipient_id": message.recipient_id,
        "message_type": message.message_type.value,
        "content": message.content,
        # Chiffrement de bout en bout. `encryption` à None = message en clair
        # (conversation dont un côté n'a pas encore d'application qui
        # chiffre). Sinon `content` est NULL et seul le destinataire peut
        # lire — le serveur relaie sans jamais pouvoir déchiffrer.
        "encryption": message.encryption,
        "ciphertext": message.ciphertext,
        "envelope": message.envelope,
        "media_asset_id": message.media_asset_id,
        "media": _serialize_media(message.media_asset) if message.media_asset else None,
        "status": message.status.value,
        "created_at": message.created_at.isoformat(),
        "delivered_at": message.delivered_at.isoformat() if message.delivered_at else None,
        "read_at": message.read_at.isoformat() if message.read_at else None,
        "reply_to_id": message.reply_to_id,
        "reply_to": _serialize_reply_preview(message.reply_to),
        "reactions": _serialize_reactions(message, viewer_id),
        "edited_at": message.edited_at.isoformat() if message.edited_at else None,
        "expires_at": message.expires_at.isoformat() if message.expires_at else None,
        "view_once": bool(message.view_once),
        "viewed_at": message.viewed_at.isoformat() if message.viewed_at else None,
        # Charge utile des contenus riches sans pièce jointe (position, carte
        # de visite) — voir app/routes/polls.py. Absente jusqu'ici de CETTE
        # sérialisation : un sondage ou une position survivait à l'envoi mais
        # perdait sa charge utile au premier rechargement de la conversation.
        "payload": message.payload,
        "poll": _serialize_poll(message.poll, viewer_id) if message.poll else None,
        # Mode preuve à deux : un message supprimé reste, barré, et une
        # modification garde l'original. Pour un message chiffré, le serveur
        # n'a pas ce texte : c'est le téléphone qui le garde.
        "proof_mode": bool(message.proof_mode),
        "deleted_at": message.deleted_at.isoformat() if message.deleted_at else None,
        "original_content": message.original_content,
    }


def _serialize_media(asset: MediaAsset) -> dict:
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> Contact:
    """Exige une ligne Contact, parce que c'est ELLE qu'on va lire ou écrire.

    Réservé aux réglages qui vivent sur le carnet d'adresses (durée
    d'éphémère). Pour savoir si l'on a le droit d'ÉCRIRE à quelqu'un, c'est
    `_require_reachable` qu'il faut appeler : le droit d'écrire ne dépend pas
    de la présence d'une ligne dans le carnet."""
    is_contact = db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first()
    if not is_contact:
        raise HTTPException(status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses")
    return is_contact


def _require_reachable(
    db: Session,
    sender_id: int,
    recipient_id: int,
    claimed_phone: Optional[str] = None,
) -> Optional[Contact]:
    """Qui ai-je le droit d'écrire ? — le garde-fou du chemin d'envoi.

    L'ancienne règle était « uniquement les gens de mon carnet ». Elle
    protégeait d'une vraie menace — les `user_id` sont des entiers
    séquentiels, et sans garde-fou on écrit à toute la base en incrémentant
    un compteur — mais elle avait deux effets qu'on ne voulait pas :

    - **on ne pouvait pas répondre à un inconnu.** Quelqu'un qui vous a dans
      son carnet vous écrit ; vous n'avez pas le sien ; votre réponse partait
      en 403. Une messagerie où le premier message passe mais pas la réponse
      n'est pas une messagerie.
    - **on ne pouvait pas écrire à un numéro qu'on vient de lire** (carte de
      visite, message d'un groupe, numéro dicté) sans d'abord créer une fiche
      dans son carnet.

    La règle devient donc : ce n'est pas l'appartenance au carnet qui
    autorise, c'est le fait de pouvoir DÉSIGNER la personne autrement qu'en
    devinant un identifiant. Quatre façons, dans l'ordre du moins cher au
    plus cher en requêtes :

    1. elle est dans mon carnet (l'ancienne règle, conservée) ;
    2. une conversation existe déjà — si elle m'a écrit, je peux répondre ;
    3. je présente SON NUMÉRO. Connaître un numéro est exactement ce qui
       autorise à joindre quelqu'un par SMS ou par téléphone : c'est la même
       clé, et elle ne s'énumère pas comme un entier séquentiel ;
    4. nous partageons un groupe — on s'y est déjà vus.

    Et dans tous les cas, le BLOCAGE est vérifié en premier. Il ne l'était
    nulle part jusqu'ici : `is_blocked_between` existait, était testé, et
    n'était appelé par aucune route. Bloquer quelqu'un ne l'empêchait donc
    pas de continuer à écrire — ce qui passait inaperçu parce que le carnet
    obligatoire servait de barrière de fait. En relâchant le carnet sans
    réparer ça, on transformait un garde-fou décoratif en porte ouverte.

    Renvoie la ligne Contact quand elle existe (elle porte les réglages de la
    conversation), et None quand la personne est joignable sans être dans le
    carnet. Tout appelant doit donc tolérer None.
    """
    # Import local : conversations.py importe déjà des symboles de ce module
    # au chargement, un import en tête créerait un cycle.
    from app.api.v1.messaging.conversations import is_blocked_between

    if is_blocked_between(db, sender_id, recipient_id):
        # Même message que pour un inconnu, et délibérément : dire « vous êtes
        # bloqué » apprend à l'expéditeur ce que le blocage cherche justement
        # à ne pas lui dire.
        raise HTTPException(status_code=403, detail="Vous ne pouvez pas écrire à cette personne")

    # Un BOT d'entreprise se joint sans carnet ni numéro : c'est sa raison
    # d'être, on lui écrit après l'avoir trouvé par son lien ou l'annuaire.
    # Seulement s'il est actif — et, tant que l'entreprise n'est pas
    # vérifiée, seulement depuis ses numéros de test.
    destinataire = db.query(User).filter(User.id == recipient_id).first()
    if destinataire is not None and destinataire.is_bot:
        from app.models.business import Bot, BusinessOrganization, BusinessTestNumber

        bot = db.query(Bot).filter(Bot.user_id == recipient_id).first()
        org = db.query(BusinessOrganization).filter(BusinessOrganization.id == bot.organization_id).first() if bot else None
        if bot is None or org is None or not bot.is_active or org.status == "SUSPENDED":
            raise HTTPException(status_code=403, detail="Ce bot ne reçoit pas de messages pour le moment")
        if org.status != "VERIFIED":
            expediteur = db.query(User.phone).filter(User.id == sender_id).scalar()
            autorise = db.query(BusinessTestNumber.id).filter(
                BusinessTestNumber.organization_id == org.id,
                BusinessTestNumber.phone == expediteur,
            ).first()
            if autorise is None:
                raise HTTPException(status_code=403, detail="Ce bot ne reçoit pas de messages pour le moment")
        return None

    contact = db.query(Contact).filter(
        Contact.owner_user_id == sender_id, Contact.contact_user_id == recipient_id
    ).first()
    if contact:
        return contact

    already_talking = db.query(DirectMessage.id).filter(
        _conversation_pair(sender_id, recipient_id)
    ).first()
    if already_talking:
        return None

    if claimed_phone:
        try:
            normalized = normalize_phone(claimed_phone)
        except OTPInvalidError:
            normalized = None
        if normalized:
            actual = db.query(User.phone).filter(User.id == recipient_id).scalar()
            if actual and actual == normalized:
                return None

    shared_group = (
        db.query(GroupMember.id)
        .filter(
            GroupMember.user_id == sender_id,
            GroupMember.group_id.in_(
                db.query(GroupMember.group_id).filter(GroupMember.user_id == recipient_id)
            ),
        )
        .first()
    )
    if shared_group:
        return None

    raise HTTPException(status_code=403, detail="Vous ne pouvez pas écrire à cette personne")


def _not_expired():
    """Un message éphémère échu sort de l'historique à la LECTURE, sans
    tâche de fond ni purge : la date de disparition est déjà en base, la
    filtrer au moment du SELECT suffit et reste exact à la seconde."""
    return or_(DirectMessage.expires_at.is_(None), DirectMessage.expires_at > datetime.utcnow())


# Chargements anticipés : la sérialisation touche les réactions, le message
# cité et la pièce jointe de CHAQUE message. Sans ça, rendre une page de 50
# messages coûte une centaine de requêtes de plus, une par bulle.
def _load_options():
    return (
        selectinload(DirectMessage.reactions),
        joinedload(DirectMessage.media_asset),
        joinedload(DirectMessage.reply_to).joinedload(DirectMessage.media_asset),
        # Un sondage porte ses options, qui portent leurs votes : sans ce
        # chargement anticipé, sérialiser une page de messages ferait deux
        # requêtes de plus par sondage affiché (voir _serialize_poll).
        selectinload(DirectMessage.poll).selectinload(Poll.options).selectinload(PollOption.votes),
    )


def _conversation_pair(user_id: int, other_id: int):
    return or_(
        and_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == other_id),
        and_(DirectMessage.sender_id == other_id, DirectMessage.recipient_id == user_id),
    )


def _get_participating_message(db: Session, message_id: str, user_id: int) -> DirectMessage:
    """404 et non 403 quand on n'est ni expéditeur ni destinataire : répondre
    « interdit » confirmerait l'existence du message de deux inconnus."""
    message = db.query(DirectMessage).filter(
        DirectMessage.id == message_id,
        or_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == user_id),
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")
    return message


async def _notify_other_party(
    message: DirectMessage,
    actor_id: int,
    event_type: str,
    *,
    sync_event_id: Optional[str] = None,
) -> None:
    """Pousse une mise à jour de message à l'AUTRE partie — celle qui n'a pas
    agi ; l'auteur de la requête a déjà l'état à jour dans sa réponse HTTP."""
    other_id = message.recipient_id if actor_id == message.sender_id else message.sender_id
    event = {"type": event_type, "message": _serialize(message, other_id)}
    if sync_event_id is not None:
        event["sync_event_id"] = str(sync_event_id)
    await manager.send_to_user(other_id, event)


def _append_message_created_events(
    db: Session, message: DirectMessage
) -> dict[str, int]:
    db.flush()
    recipient_event = append_sync_event(
        db,
        message.recipient_id,
        {"type": "message:new", "message": _serialize(message, message.recipient_id)},
    )
    sender_event = append_sync_event(
        db,
        message.sender_id,
        {
            "type": "conversation:updated",
            "contact_user_id": message.recipient_id,
            "message_id": str(message.id),
        },
    )
    return {"recipient": recipient_event.id, "sender": sender_event.id}


def _push_preview(message: DirectMessage) -> str:
    """Le texte d'une notification : l'EXISTENCE du message, jamais son
    contenu.

    Une notification passe par Firebase, c'est-à-dire par un tiers, puis
    s'affiche sur un écran verrouillé que n'importe qui peut lire par-dessus
    une épaule. Y mettre le texte du message revient à le publier deux fois
    hors de portée de l'utilisateur.

    C'était pourtant le cas : tout message NON chiffré partait en clair dans
    le corps de la notification. Et comme les groupes, les chaînes et les
    statuts ne sont jamais chiffrés — et qu'un 1:1 retombait en clair au
    moindre incident — c'est une part importante du trafic qui transitait
    ainsi, en contradiction directe avec ce que l'application promet.

    Ce que l'utilisateur voit, application en arrière-plan : le nom de
    l'expéditeur en titre (`title=sender_name`) et « Nouveau message ». C'est
    un push `notification`, affiché par Android lui-même : aucun code de
    l'application ne tourne à ce moment-là, et ce texte n'est donc PAS
    remplacé par le contenu ensuite. C'est assumé — le contenu n'a pas à
    transiter par un tiers. Il s'affiche à l'ouverture de la conversation.
    """
    return "Nouveau message"


async def _deliver(
    db: Session,
    message: DirectMessage,
    *,
    sync_event_ids: Optional[dict[str, int]] = None,
) -> None:
    """Pousse le message au destinataire et bascule son statut, puis envoie
    aussi la notification FCM. Partagé par l'envoi et le transfert : le
    WebSocket assure le temps réel et FCM couvre l'arrière-plan."""
    recipient_event = {
        "type": "message:new",
        "message": _serialize(message, message.recipient_id),
        **(
            {"sync_event_id": public_event_id(db, sync_event_ids["recipient"])}
            if sync_event_ids and sync_event_ids.get("recipient") is not None
            else {}
        ),
    }
    delivered = await manager.send_to_user(
        message.recipient_id,
        recipient_event,
    )
    if delivered:
        message.status = MessageStatus.DELIVERED
        message.delivered_at = datetime.utcnow()
        db.flush()
        status_event = {
            "type": "message:status",
            "message": _serialize(message, message.sender_id),
        }
        status_row = append_sync_event(db, message.sender_id, status_event)
        db.commit()
        db.refresh(message)
        if status_row is not None:
            status_event["sync_event_id"] = str(status_row.id)
        await manager.send_to_user(message.sender_id, status_event)

    # L'EXPÉDITEUR aussi est prévenu — il ne l'était pas, et c'est ce qui
    # obligeait à tirer pour rafraîchir en revenant sur la liste des
    # discussions : rien ne lui disait que sa propre conversation venait de
    # remonter en tête.
    #
    # Un type d'événement DISTINCT, et non `message:new` : la conversation
    # ouverte chez l'expéditeur a déjà ajouté ce message de façon optimiste,
    # et lui repousser `message:new` l'afficherait deux fois. Celui-ci ne dit
    # qu'une chose — « ta liste n'est plus à jour » — ce qui est exactement
    # ce dont la liste a besoin, et rien de plus.
    #
    # Au passage, les AUTRES appareils de l'expéditeur voient eux aussi leur
    # liste bouger, ce qui n'était pas le cas non plus.
    sender_event = {
        "type": "conversation:updated",
        "contact_user_id": message.recipient_id,
        "message_id": str(message.id),
        **(
            {"sync_event_id": str(sync_event_ids["sender"])}
            if sync_event_ids and sync_event_ids.get("sender") is not None
            else {}
        ),
    }
    await manager.send_to_user(message.sender_id, sender_event)

    # Le push complète toujours le WebSocket : le socket peut être actif
    # quelques secondes avant que l'application passe en arrière-plan, et
    # Android doit alors pouvoir afficher la notification FCM.
    sender = db.query(User).filter(User.id == message.sender_id).first()
    # Le petname que LE DESTINATAIRE a posé sur cet expéditeur l'emporte sur
    # le nom que l'expéditeur s'est choisi — c'est le nom que le destinataire
    # reconnaît, pas celui de l'autre. Sans cette priorité, le titre de la
    # notification (et le nom affiché en rouvrant la conversation depuis
    # elle, voir contact_name ci-dessous) ignorait le carnet d'adresses.
    recipient_contact = db.query(Contact).filter(
        Contact.owner_user_id == message.recipient_id, Contact.contact_user_id == message.sender_id
    ).first()
    # Même règle que partout (utils/identity.py::nom_affiche) : un compte
    # certifié garde son nom, sinon le carnet du destinataire l'emporte.
    sender_name = nom_affiche(
        sender, recipient_contact.display_name if recipient_contact else None, repli="Pokou"
    )
    # La décision AVANT l'envoi : une conversation en sourdine ne doit pas
    # faire sonner le téléphone, et c'est ici qu'on le sait (voir
    # services/notification_policy.py). Le client, lui, décidera de la
    # présentation.
    decision = notification_policy.decide(
        db,
        recipient_id=message.recipient_id,
        event=notification_policy.NotificationEvent.DIRECT_MESSAGE,
        sender_id=message.sender_id,
    )
    if not decision.deliver:
        return
    send_push(
        db,
        message.recipient_id,
        title=sender_name,
        # Un message chiffré n'a PAS d'aperçu, et c'est une conséquence
        # directe du chiffrement, pas une régression : le serveur qui
        # compose la notification ne peut pas lire le texte. Le client
        # déchiffre à la réception et remplace la notification par une
        # version complète quand l'application tourne.
        body=_push_preview(message),
        data={
            "type": "message",
            "contact_user_id": str(message.sender_id),
            "contact_name": sender_name,
            # L'identifiant, et non le texte : c'est ce qui permet au client
            # d'aller chercher le message et de le déchiffrer lui-même, sans
            # que le contenu ait à passer par Firebase.
            "message_id": str(message.id),
            **decision.as_payload(),
        },
        rich_data=_rich_push_data(message, sender_name),
    )


#: Au-delà, le chiffré ne voyage pas dans le push (FCM plafonne à 4 Ko) :
#: l'appareil ira le chercher, comme un message en clair.
_RICH_CIPHERTEXT_BUDGET = 3000


def _rich_push_data(message: DirectMessage, sender_name: str) -> dict[str, str]:
    """Ce que l'appareil reçoit pour construire LUI-MÊME la notification,
    groupée par conversation et avec le contenu.

    Le texte en clair ne voyage JAMAIS par Firebase : pour un message non
    chiffré, l'appareil va le chercher auprès de Pokou avec `message_id`.
    Un message chiffré, lui, voyage tel quel — Firebase n'en lit rien, et
    l'appareil le déchiffre sans aller-retour."""
    donnees = {
        "rich": "1",
        "sender_id": str(message.sender_id),
        "sender_name": sender_name,
        # `msg_type` et non `message_type` : Firebase réserve ce nom et
        # refusait TOUTE la notification (« Invalid data payload key »).
        "msg_type": message.message_type.value,
        "sent_at": message.created_at.isoformat() + "Z",
        "is_encrypted": "1" if message.encryption else "0",
    }
    if message.encryption and message.ciphertext:
        enveloppe = json.dumps(message.envelope or {}, separators=(",", ":"))
        if len(message.ciphertext) + len(enveloppe) <= _RICH_CIPHERTEXT_BUDGET:
            donnees.update(
                {
                    "encryption": message.encryption,
                    "ciphertext": message.ciphertext,
                    "envelope": enveloppe,
                }
            )
    return donnees


@router.post("")
async def send_message(
    payload: MessageCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sender_id = current_user["user_id"]
    if payload.recipient_id == sender_id:
        raise HTTPException(status_code=400, detail="Impossible de s'envoyer un message à soi-même")

    contact = _require_reachable(db, sender_id, payload.recipient_id, payload.recipient_phone)

    try:
        message_type = MessageType(payload.message_type.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail="Type de message invalide")

    encrypted = bool(payload.encryption)
    if encrypted:
        if payload.encryption != ENCRYPTION_VERSION:
            raise HTTPException(
                status_code=400,
                detail=f"Version de chiffrement inconnue : {payload.encryption}",
            )
        if not payload.ciphertext or not payload.envelope:
            raise HTTPException(
                status_code=400,
                detail="Un message chiffré exige un ciphertext et une enveloppe",
            )

    media_asset = None
    if message_type == MessageType.TEXT:
        # Un message chiffré porte son texte dans le ciphertext ; exiger
        # `content` en plus reviendrait à demander une copie en clair de ce
        # qu'on vient de chiffrer.
        if not encrypted and (not payload.content or not payload.content.strip()):
            raise HTTPException(status_code=400, detail="Le contenu du message est requis")
    else:
        if not payload.media_asset_id:
            raise HTTPException(status_code=400, detail="Une pièce jointe est requise pour ce type de message")
        media_asset = db.query(MediaAsset).filter(MediaAsset.id == payload.media_asset_id).first()
        if media_asset is None:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")
        # L'upload doit avoir été fait par l'expéditeur lui-même — empêche
        # de "voler" le média de quelqu'un d'autre en devinant son id.
        #
        # Un STICKER est la seule exception, et elle est nécessaire : son
        # image appartient au PACK, jamais à celui qui l'envoie. La règle
        # exacte vit dans sticker_service, pas recopiée ici.
        if media_asset.uploader_id != sender_id and not (
            message_type == MessageType.STICKER
            and sticker_service.sender_may_attach(db, media_asset.id, sender_id)
        ):
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")

    if payload.view_once and message_type not in VIEW_ONCE_TYPES:
        raise HTTPException(status_code=400, detail="La vue unique n'existe que pour une photo ou une vidéo")

    if payload.reply_to_id:
        # Le message cité doit appartenir à CETTE conversation : citer le
        # message d'une autre conversation reviendrait à en recopier un
        # extrait chez quelqu'un qui n'y a jamais eu accès.
        quoted = db.query(DirectMessage).filter(
            DirectMessage.id == payload.reply_to_id,
            _conversation_pair(sender_id, payload.recipient_id),
        ).first()
        if not quoted:
            raise HTTPException(status_code=404, detail="Message cité introuvable dans cette conversation")

    # Date de disparition figée ICI d'après le réglage de la conversation, et
    # jamais recalculée à la lecture : changer le réglage ne doit pas
    # réécrire le sort des messages déjà envoyés.
    expires_at = (
        datetime.utcnow() + timedelta(seconds=contact.disappearing_seconds)
        if contact and contact.disappearing_seconds
        else None
    )

    message = DirectMessage(
        sender_id=sender_id,
        recipient_id=payload.recipient_id,
        message_type=message_type,
        # `content` reste NULL quand le message est chiffré — délibérément.
        # Conserver « aussi » une copie en clair par commodité (recherche,
        # aperçu de notification) annulerait tout l'intérêt du chiffrement,
        # et c'est exactement ainsi que ce genre de fonctionnalité se vide
        # de son sens sans que personne ne le remarque.
        content=None if encrypted else payload.content,
        encryption=payload.encryption if encrypted else None,
        ciphertext=payload.ciphertext if encrypted else None,
        envelope=payload.envelope if encrypted else None,
        media_asset_id=media_asset.id if media_asset else None,
        reply_to_id=payload.reply_to_id,
        view_once=payload.view_once,
        expires_at=expires_at,
        proof_mode=proof_mode_row(db, sender_id, payload.recipient_id) is not None,
    )
    db.add(message)
    sync_event_ids = _append_message_created_events(db, message)
    db.commit()
    db.refresh(message)

    # APRÈS la validation du message, jamais avant : `record_message` gère
    # sa propre transaction et fait un rollback en cas d'échec — appelé plus
    # tôt, il emporterait le message avec lui.
    streak_lock.record_message(db, sender_id, payload.recipient_id)

    await _deliver(
        db,
        message,
        sync_event_ids=sync_event_ids,
    )

    # Écrit à un bot : l'événement part au serveur du développeur, par la
    # file des webhooks (jamais depuis cette requête — voir
    # services/pokou_business/webhooks.py).
    destinataire = db.query(User).filter(User.id == payload.recipient_id).first()
    if destinataire is not None and destinataire.is_bot:
        from app.services.business import messaging as bot_messaging

        expediteur = db.query(User).filter(User.id == sender_id).first()
        bot_messaging.message_recu(db, message, expediteur)
        db.commit()
    return _serialize(message, sender_id)


ORDER_STATUSES = {
    "VALIDATED": "Commande validée",
    "SHIPPED": "Commande expédiée",
    "DELIVERED": "Commande livrée",
}


class OrderUpdate(BaseModel):
    recipient_id: int
    product_id: int
    status: str = Field(..., pattern="^(VALIDATED|SHIPPED|DELIVERED)$")


@router.post("/order-update")
async def send_order_update(
    payload: OrderUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le vendeur fait avancer une commande dans la conversation.

    Une route dédiée, et non un message texte portant un préfixe convenu.
    L'ancienne version envoyait littéralement « [POKOU_ORDER] Commande
    livrée · Ciment » comme un message ordinaire, ce qui posait trois
    problèmes dont un sérieux :

    - **n'importe qui pouvait le TAPER.** Un acheteur écrivant ce texte à la
      main voyait sa propre conversation afficher « Commande livrée ». Un
      suivi de commande falsifiable en le tapant n'est pas un suivi.
    - le préfixe voyageait dans `content`, donc **chiffré** : le destinataire
      ne pouvait classer le message qu'après déchiffrement, et toute
      défaillance de ce côté produisait une bulle vide sans explication.
    - il polluait l'aperçu de la liste des discussions, qui affichait le
      marqueur technique.

    Le serveur vérifie donc que l'expéditeur est bien le VENDEUR du produit,
    puis écrit l'état dans `payload` — une colonne de métadonnées, jamais
    chiffrée, que le client lit sans rien déchiffrer. `content` garde une
    phrase lisible : c'est elle qui s'affiche dans l'aperçu de la liste et
    dans une version de l'application qui ne connaîtrait pas encore ce
    format.
    """
    sender_id = current_user["user_id"]
    if payload.recipient_id == sender_id:
        raise HTTPException(status_code=400, detail="Destinataire invalide")

    product = (
        db.query(MarketplaceProduct)
        .filter(MarketplaceProduct.id == payload.product_id)
        .first()
    )
    if not product:
        raise HTTPException(status_code=404, detail="Produit introuvable")
    if product.seller_id != sender_id:
        # C'est LA vérification qui manquait. Sans elle, l'acheteur pouvait
        # annoncer lui-même que sa commande était livrée.
        raise HTTPException(
            status_code=403,
            detail="Seul le vendeur peut faire avancer cette commande",
        )

    _require_reachable(db, sender_id, payload.recipient_id)

    label = ORDER_STATUSES[payload.status]
    message = DirectMessage(
        sender_id=sender_id,
        recipient_id=payload.recipient_id,
        message_type=MessageType.TEXT,
        content=f"{label} · {product.name}",
        payload={
            "pokou_order": {
                "status": payload.status,
                "label": label,
                "product_id": product.id,
                "product_name": product.name,
            }
        },
    )
    db.add(message)
    sync_event_ids = _append_message_created_events(db, message)
    db.commit()
    db.refresh(message)

    await _deliver(db, message, sync_event_ids=sync_event_ids)
    return _serialize(message, sender_id)


@router.get("/search")
async def search_messages(
    q: str = Query(..., min_length=1, max_length=200),
    limit: int = Query(50, ge=1, le=200),
    contact_user_id: Optional[int] = Query(
        None, description="Restreindre la recherche à cette conversation"
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Recherche dans ses conversations 1:1 — toutes, ou une seule avec
    `contact_user_id` (l'icône de recherche DANS une conversation ne doit
    pas remonter les messages des autres).

    Déclarée AVANT GET /{contact_user_id} : FastAPI retient la première
    route qui correspond, et « search » serait sinon capté par la route
    paramétrée puis rejeté comme identifiant non entier."""
    user_id = current_user["user_id"]

    # Un message chiffré a `content` à NULL : il ne peut pas correspondre, et
    # c'est la conséquence inévitable du chiffrement de bout en bout — le
    # serveur ne peut pas chercher dans ce qu'il ne peut pas lire. La
    # recherche du contenu chiffré se fait côté client, sur le cache local
    # déchiffré. On COMPTE ce qu'on ne peut pas voir, pour que le client
    # puisse le dire plutôt que de laisser croire à une absence de résultat.

    # `%` et `_` sont les jokers de LIKE : les échapper, sinon chercher
    # « 50% » ramènerait la conversation entière.
    escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    items = (
        db.query(DirectMessage)
        .options(*_load_options())
        .filter(
            _conversation_pair(user_id, contact_user_id)
            if contact_user_id is not None
            else or_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == user_id),
            DirectMessage.content.ilike(f"%{escaped}%", escape="\\"),
            _not_expired(),
        )
        .order_by(DirectMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    return {
        "items": [
            {
                **_serialize(message, user_id),
                # L'autre partie, pour que le client sache quelle
                # conversation ouvrir sur un résultat : il ne peut pas la
                # déduire sans savoir de quel côté il se trouve.
                "contact_user_id": (
                    message.recipient_id if message.sender_id == user_id else message.sender_id
                ),
            }
            for message in items
        ]
    }


@router.get("/by-id/{message_id}")
async def get_message_by_id(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """UN message, pour la notification que l'appareil construit lui-même
    (voir _rich_push_data) : son texte ne passe pas par Firebase, l'appareil
    vient le chercher ici. Réservé à l'expéditeur et au destinataire — 404
    pour tout autre, sans confirmer que le message existe."""
    user_id = current_user["user_id"]
    message = (
        db.query(DirectMessage)
        .options(*_load_options())
        .filter(
            DirectMessage.id == message_id,
            or_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == user_id),
            _not_expired(),
        )
        .first()
    )
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    return _serialize(message, user_id)


@router.get("/{contact_user_id}")
async def get_conversation(
    contact_user_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    query = db.query(DirectMessage).filter(
        _conversation_pair(user_id, contact_user_id),
        _not_expired(),
    )
    # Le comptage garde la requête NUE : les chargements anticipés n'ont pas
    # de sens dans un count() et y ajouteraient des jointures pour rien.
    total = query.count()
    # Most-recent-first page, then re-ascend for display order — matches
    # the usual "load latest page, scroll up for older" chat UX.
    items = (
        query.options(*_load_options())
        .order_by(DirectMessage.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    items.reverse()
    return {
        "items": [_serialize(m, user_id) for m in items],
        "total": total,
        "skip": skip,
        "limit": limit,
    }


@router.get("/{contact_user_id}/disappearing")
async def get_disappearing(
    contact_user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    contact = _require_contact(db, current_user["user_id"], contact_user_id)
    return {"contact_user_id": contact_user_id, "disappearing_seconds": contact.disappearing_seconds}


@router.put("/{contact_user_id}/disappearing")
async def set_disappearing(
    contact_user_id: int,
    payload: DisappearingUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le réglage vit sur le Contact de celui qui le pose, pas sur la paire :
    chacun décide de la durée de vie de SES propres envois, comme le veut
    l'asymétrie du carnet d'adresses Pokou (voir Contact)."""
    if payload.seconds is not None and payload.seconds not in DISAPPEARING_CHOICES:
        raise HTTPException(
            status_code=400,
            detail="Durée invalide : 86400 (24 h), 604800 (7 jours) ou 7776000 (90 jours)",
        )
    contact = _require_contact(db, current_user["user_id"], contact_user_id)
    contact.disappearing_seconds = payload.seconds
    db.commit()
    return {"contact_user_id": contact_user_id, "disappearing_seconds": contact.disappearing_seconds}


def proof_mode_row(db: Session, user_a: int, user_b: int) -> Optional[DirectProofMode]:
    low, high = sorted((user_a, user_b))
    return db.query(DirectProofMode).filter(
        DirectProofMode.user_low_id == low, DirectProofMode.user_high_id == high
    ).first()


def _proof_mode_json(row: Optional[DirectProofMode], viewer_id: int, contact_user_id: int) -> dict:
    return {
        "contact_user_id": contact_user_id,
        "enabled": row is not None,
        "since": row.since.isoformat() if row else None,
        "enabled_by_me": bool(row and row.enabled_by == viewer_id),
        # À deux, seule la personne qui l'a activé peut le couper (maquette 10).
        "can_disable": bool(row and row.enabled_by == viewer_id),
    }


class ProofModeUpdate(BaseModel):
    enabled: bool


@router.get("/{contact_user_id}/proof-mode")
async def get_proof_mode(
    contact_user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    me = current_user["user_id"]
    return _proof_mode_json(proof_mode_row(db, me, contact_user_id), me, contact_user_id)


@router.put("/{contact_user_id}/proof-mode")
async def set_proof_mode(
    contact_user_id: int,
    body: ProofModeUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le mode preuve d'une discussion à deux (maquettes 4b, 5b et 10).

    Activer : tout titulaire du badge, essai compris. Couper : seule la
    personne qui l'a activé. Jamais caché : un message système l'annonce
    dans le fil, en clair — il ne dit rien d'autre que le changement.
    """
    from app.api.v1.certified.certified import proof_mode_allowed

    me = current_user["user_id"]
    if contact_user_id == me:
        raise HTTPException(status_code=400, detail="Discussion invalide")
    _require_reachable(db, me, contact_user_id)
    row = proof_mode_row(db, me, contact_user_id)
    if body.enabled == (row is not None):
        return _proof_mode_json(row, me, contact_user_id)
    if body.enabled:
        if not proof_mode_allowed(db, me):
            raise HTTPException(status_code=403, detail="Le mode preuve demande Pokou certifié")
        low, high = sorted((me, contact_user_id))
        row = DirectProofMode(user_low_id=low, user_high_id=high, enabled_by=me)
        db.add(row)
    else:
        if row.enabled_by != me:
            raise HTTPException(
                status_code=403,
                detail="Seule la personne qui l'a activé peut désactiver le mode preuve",
            )
        db.delete(row)
        row = None
    notice = DirectMessage(
        sender_id=me,
        recipient_id=contact_user_id,
        message_type=MessageType.TEXT,
        content="a activé le mode preuve" if body.enabled else "a désactivé le mode preuve",
        payload={"kind": "proof_mode", "enabled": body.enabled},
        proof_mode=body.enabled,
    )
    db.add(notice)
    sync_event_ids = _append_message_created_events(db, notice)
    db.commit()
    db.refresh(notice)
    await _deliver(db, notice, sync_event_ids=sync_event_ids)
    return {**_proof_mode_json(row, me, contact_user_id), "notice": _serialize(notice, me)}


@router.patch("/{message_id}")
async def edit_message(
    message_id: str,
    payload: MessageEdit,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    message = db.query(DirectMessage).filter(
        DirectMessage.id == message_id, DirectMessage.sender_id == user_id
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")
    if message.message_type != MessageType.TEXT:
        # Requête valide mais interdite : remplacer la légende ne remplace
        # pas le fichier déjà téléchargé chez l'autre, la modification
        # mentirait sur ce qu'il a reçu.
        raise HTTPException(status_code=403, detail="Seul un message texte peut être modifié")
    if datetime.utcnow() - message.created_at > EDIT_WINDOW:
        raise HTTPException(
            status_code=409,
            detail=f"Ce message ne peut plus être modifié : le délai de {MESSAGE_EDIT_WINDOW_MINUTES} minutes est dépassé",
        )

    if message.encryption:
        # Modifier un message chiffré, c'est le RE-chiffrer : le serveur ne
        # peut pas produire le nouveau ciphertext, il ne détient aucune clé.
        if not payload.ciphertext or not payload.envelope:
            raise HTTPException(
                status_code=400,
                detail="La modification d'un message chiffré exige un ciphertext et une enveloppe",
            )
        message.ciphertext = payload.ciphertext
        message.envelope = payload.envelope
    else:
        if message.proof_mode and message.original_content is None:
            message.original_content = message.content
        message.content = payload.content
    message.edited_at = datetime.utcnow()
    other_id = message.recipient_id if message.sender_id == user_id else message.sender_id
    event = {"type": "message:edited", "message": _serialize(message, other_id)}
    sync_event = append_sync_event(db, other_id, event)
    db.commit()
    db.refresh(message)

    await _notify_other_party(
        message, user_id, "message:edited", sync_event_id=public_event_id(db, sync_event.id)
    )
    return _serialize(message, user_id)


@router.put("/{message_id}/reaction")
async def set_reaction(
    message_id: str,
    payload: ReactionSet,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Pose OU remplace sa réaction : une seule par personne et par message,
    comme WhatsApp. Remplacer plutôt que cumuler évite qu'un même pouce
    revienne cinq fois parce qu'on a hésité."""
    user_id = current_user["user_id"]
    message = _get_participating_message(db, message_id, user_id)

    existing = db.query(MessageReaction).filter(
        MessageReaction.message_id == message.id, MessageReaction.user_id == user_id
    ).first()
    if existing:
        existing.emoji = payload.emoji
    else:
        db.add(MessageReaction(message_id=message.id, user_id=user_id, emoji=payload.emoji))
    other_id = message.recipient_id if message.sender_id == user_id else message.sender_id
    event = {"type": "message:reaction", "message": _serialize(message, other_id)}
    sync_event = append_sync_event(db, other_id, event)
    db.commit()
    db.refresh(message)

    await _notify_other_party(
        message, user_id, "message:reaction", sync_event_id=public_event_id(db, sync_event.id)
    )
    return _serialize(message, user_id)


@router.delete("/{message_id}/reaction")
async def remove_reaction(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    message = _get_participating_message(db, message_id, user_id)

    existing = db.query(MessageReaction).filter(
        MessageReaction.message_id == message.id, MessageReaction.user_id == user_id
    ).first()
    # Retirer une réaction absente n'est pas une erreur : l'appui long est
    # une bascule côté client, deux retraits d'affilée sont banals.
    if existing:
        db.delete(existing)
    other_id = message.recipient_id if message.sender_id == user_id else message.sender_id
    event = {"type": "message:reaction", "message": _serialize(message, other_id)}
    sync_event = append_sync_event(db, other_id, event)
    db.commit()
    db.refresh(message)

    await _notify_other_party(
        message, user_id, "message:reaction", sync_event_id=public_event_id(db, sync_event.id)
    )
    return _serialize(message, user_id)


@router.post("/{message_id}/viewed")
async def mark_view_once_viewed(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Consommation d'un média à vue unique par son DESTINATAIRE. C'est cet
    horodatage que app/routes/media.py::_can_access relit pour refuser le
    fichier ensuite."""
    user_id = current_user["user_id"]
    message = db.query(DirectMessage).filter(
        DirectMessage.id == message_id, DirectMessage.recipient_id == user_id
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")
    if not message.view_once:
        raise HTTPException(status_code=400, detail="Ce message n'est pas à vue unique")

    # Idempotent : seul le PREMIER appel horodate. Un client qui réessaie
    # après une coupure réseau ne doit pas repousser l'échéance ni brouiller
    # la date à laquelle l'expéditeur voit « ouvert ».
    if message.viewed_at is None:
        message.viewed_at = datetime.utcnow()
        event = {"type": "message:viewed", "message": _serialize(message, message.sender_id)}
        sync_event = append_sync_event(db, message.sender_id, event)
        db.commit()
        db.refresh(message)
        await _notify_other_party(
            message, user_id, "message:viewed", sync_event_id=public_event_id(db, sync_event.id)
        )

    return _serialize(message, user_id)


@router.post("/{message_id}/read")
async def mark_read(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    message = db.query(DirectMessage).filter(
        DirectMessage.id == message_id, DirectMessage.recipient_id == current_user["user_id"]
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")

    message.status = MessageStatus.READ
    message.read_at = datetime.utcnow()
    status_event = {
        "type": "message:status",
        "message": _serialize(message, message.sender_id),
    }
    status_sync_event = append_sync_event(db, message.sender_id, status_event)
    db.commit()
    db.refresh(message)

    if status_sync_event is not None:
        status_event["sync_event_id"] = str(status_sync_event.id)
    await manager.send_to_user(message.sender_id, status_event)
    return _serialize(message, message.recipient_id)


@router.post("/{message_id}/forward")
async def forward_message(
    message_id: str,
    payload: MessageForward,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    sender_id = current_user["user_id"]
    contact = _require_reachable(db, sender_id, payload.recipient_id, payload.recipient_phone)
    source = db.query(DirectMessage).filter(
        DirectMessage.id == message_id,
        or_(DirectMessage.sender_id == sender_id, DirectMessage.recipient_id == sender_id),
    ).first()
    if not source:
        raise HTTPException(status_code=404, detail="Message introuvable")
    if payload.recipient_id == sender_id:
        raise HTTPException(status_code=400, detail="Impossible de s'envoyer un message à soi-même")
    # Un message chiffré de bout en bout ne se transfère pas ici : le serveur
    # ne peut recopier que le chiffré, scellé pour le destinataire d'ORIGINE.
    # La copie arriverait vide — ou, pour une pièce jointe, comme un bloc
    # que personne ne peut ouvrir. L'appareil, qui détient le clair, le
    # renvoie comme un nouveau message.
    if source.encryption:
        raise HTTPException(
            status_code=409,
            detail="Un message chiffré se transfère depuis l'application, pas par le serveur",
        )

    # La copie repart avec la durée d'éphémère de la conversation d'ARRIVÉE,
    # et sans la vue unique ni la citation de l'original : un transfert est
    # un nouvel envoi dans un autre fil, pas un clone. La vue unique en
    # particulier ne survit pas à un transfert chez WhatsApp non plus.
    forwarded = DirectMessage(
        sender_id=sender_id,
        recipient_id=payload.recipient_id,
        message_type=source.message_type,
        content=source.content,
        media_asset_id=source.media_asset_id,
        expires_at=(
            datetime.utcnow() + timedelta(seconds=contact.disappearing_seconds)
            if contact and contact.disappearing_seconds
            else None
        ),
    )
    db.add(forwarded)
    sync_event_ids = _append_message_created_events(db, forwarded)
    db.commit()
    db.refresh(forwarded)
    await _deliver(db, forwarded, sync_event_ids=sync_event_ids)
    return _serialize(forwarded, sender_id)


@router.delete("/{message_id}")
async def delete_message(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    message = db.query(DirectMessage).filter(
        DirectMessage.id == message_id,
        DirectMessage.sender_id == current_user["user_id"],
    ).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message introuvable")
    recipient_id = message.recipient_id
    if message.proof_mode:
        # Mode preuve : « Supprimer pour tous » ne fait que MARQUER le
        # message. Chaque téléphone le garde barré, avec son texte — le
        # serveur, lui, n'a jamais eu le texte d'un message chiffré.
        if message.deleted_at is None:
            message.deleted_at = datetime.utcnow()
        kept_event = {
            "type": "message:deleted",
            "message_id": message_id,
            "proof": True,
            "message": _serialize(message, recipient_id),
        }
        sync_event = append_sync_event(db, recipient_id, kept_event)
        db.commit()
        kept_event["sync_event_id"] = str(sync_event.id)
        await manager.send_to_user(recipient_id, kept_event)
        return {"deleted": True, "kept_as_proof": True, "message": _serialize(message, current_user["user_id"])}
    deleted_event = {"type": "message:deleted", "message_id": message_id}
    sync_event = append_sync_event(db, recipient_id, deleted_event)
    db.delete(message)
    db.commit()
    if sync_event is not None:
        deleted_event["sync_event_id"] = str(sync_event.id)
    await manager.send_to_user(recipient_id, deleted_event)
    return {"deleted": True, "message_id": message_id}
