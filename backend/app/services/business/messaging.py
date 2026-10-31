"""Ce qu'un bot a le droit d'envoyer, à qui — et ce qu'il reçoit.

Un bot n'écrit jamais à quelqu'un qui ne lui a rien demandé :

- en PRODUCTION (clé `vb_live_`, entreprise vérifiée), seulement à qui lui
  a déjà écrit. C'est la règle de consentement de WhatsApp Business, et la
  seule qui empêche un annuaire de bots de devenir un canal de spam ;
- en BAC À SABLE (clé `vb_test_`), seulement aux numéros de test que
  l'entreprise a déclarés — ceux de son équipe.

Et dans tous les cas, jamais à travers un blocage.
"""
from __future__ import annotations

from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models import DirectMessage, MediaAsset, MessageStatus, MessageType, User
from app.models.business import Bot, BusinessOrganization, BusinessTestNumber
from app.services.business import webhooks

MAX_TEXT = 4096
MAX_BUTTONS = 3
MAX_BUTTON_TITLE = 20
MAX_BUTTON_ID = 64


class EnvoiRefuse(Exception):
    """Le bot n'a pas le droit d'écrire à ce destinataire — HTTP 403."""


class MessageInvalide(Exception):
    """Contenu mal formé — HTTP 422."""


def _numeros_de_test(db: Session, org: BusinessOrganization) -> set[str]:
    return {
        row.phone
        for row in db.query(BusinessTestNumber).filter(
            BusinessTestNumber.organization_id == org.id
        )
    }


def verifier_destinataire(db: Session, *, org: BusinessOrganization, bot: Bot, mode: str, recipient: Optional[User]) -> None:
    from app.api.v1.messaging.conversations import is_blocked_between

    if recipient is None or not recipient.is_active or recipient.is_bot:
        raise EnvoiRefuse("Destinataire introuvable")
    if org.status == "SUSPENDED":
        raise EnvoiRefuse(org.suspended_reason or "Entreprise suspendue")
    if not bot.is_active:
        raise EnvoiRefuse("Ce bot est désactivé")
    if is_blocked_between(db, bot.user_id, recipient.id):
        raise EnvoiRefuse("Ce destinataire n'accepte pas vos messages")

    if mode == "TEST":
        if recipient.phone not in _numeros_de_test(db, org):
            raise EnvoiRefuse(
                "En bac à sable, un bot n'écrit qu'aux numéros de test de l'entreprise"
            )
        return

    if org.status != "VERIFIED":
        raise EnvoiRefuse("La production s'ouvre après la vérification de l'entreprise")
    a_ecrit = (
        db.query(DirectMessage.id)
        .filter(DirectMessage.sender_id == recipient.id, DirectMessage.recipient_id == bot.user_id)
        .first()
    )
    if a_ecrit is None:
        raise EnvoiRefuse(
            "Un bot ne peut écrire qu'à quelqu'un qui lui a écrit en premier"
        )


def valider_boutons(boutons: Optional[list[dict[str, Any]]]) -> Optional[list[dict[str, str]]]:
    if not boutons:
        return None
    if len(boutons) > MAX_BUTTONS:
        raise MessageInvalide(f"{MAX_BUTTONS} boutons au plus")
    propres: list[dict[str, str]] = []
    vus: set[str] = set()
    for b in boutons:
        ident = str(b.get("id", "")).strip()
        titre = str(b.get("title", "")).strip()
        if not ident or len(ident) > MAX_BUTTON_ID:
            raise MessageInvalide(f"Chaque bouton a un id de 1 à {MAX_BUTTON_ID} caractères")
        if not titre or len(titre) > MAX_BUTTON_TITLE:
            raise MessageInvalide(f"Chaque bouton a un titre de 1 à {MAX_BUTTON_TITLE} caractères")
        if ident in vus or titre in {p["title"] for p in propres}:
            raise MessageInvalide("Deux boutons ne peuvent pas partager un id ou un titre")
        vus.add(ident)
        propres.append({"id": ident, "title": titre})
    return propres


def construire_message(
    db: Session,
    *,
    bot: Bot,
    recipient: User,
    text: Optional[str],
    buttons: Optional[list[dict[str, Any]]],
    media_id: Optional[int],
) -> DirectMessage:
    texte = (text or "").strip()
    if len(texte) > MAX_TEXT:
        raise MessageInvalide(f"{MAX_TEXT} caractères au plus")
    boutons = valider_boutons(buttons)
    media: Optional[MediaAsset] = None
    if media_id is not None:
        media = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
        # Le bot n'envoie que ce que LUI a téléversé : un identifiant de
        # média deviné ne doit pas permettre de faire circuler celui d'un
        # autre.
        if media is None or media.uploader_id != bot.user_id:
            raise MessageInvalide("Média introuvable — téléversez-le d'abord via /bot/v1/media")
        if not media.mime_type.startswith("image/"):
            raise MessageInvalide("Seules les images sont acceptées pour l'instant")
        if boutons:
            raise MessageInvalide("Une image ne porte pas de boutons")
    if not texte and media is None:
        raise MessageInvalide("Message vide")
    if boutons and not texte:
        raise MessageInvalide("Des boutons demandent un texte")

    return DirectMessage(
        sender_id=bot.user_id,
        recipient_id=recipient.id,
        message_type=MessageType.IMAGE if media else MessageType.TEXT,
        content=texte or None,
        media_asset_id=media.id if media else None,
        payload={"bot_buttons": boutons} if boutons else None,
        status=MessageStatus.SENT,
    )


def reponse_bouton(db: Session, message: DirectMessage) -> Optional[dict[str, str]]:
    """L'utilisateur a touché un bouton : l'app envoie le TITRE en réponse
    citée au message du bot. On retrouve ici l'`id` que le développeur a
    choisi — c'est lui qu'il attend, pas un libellé qu'il peut traduire."""
    if not message.reply_to_id or not message.content:
        return None
    cite = db.query(DirectMessage).filter(DirectMessage.id == message.reply_to_id).first()
    if cite is None or cite.sender_id != message.recipient_id:
        return None
    for bouton in (cite.payload or {}).get("bot_buttons") or []:
        if bouton.get("title") == message.content.strip():
            return {"id": bouton["id"], "title": bouton["title"]}
    return None


def message_recu(db: Session, message: DirectMessage, sender: User) -> None:
    """Un utilisateur a écrit à un bot : l'événement part (plus tard) au
    serveur du développeur. Le bot n'apprend NI le numéro ni le nom du
    carnet de la personne — seulement le nom qu'elle s'est choisi."""
    bot = db.query(Bot).filter(Bot.user_id == message.recipient_id).first()
    if bot is None:
        return
    data: dict[str, Any] = {
        "message_id": message.id,
        "from": {"user_id": sender.id, "name": sender.full_name},
        "type": message.message_type.value,
        "text": message.content,
        "reply_to_id": message.reply_to_id,
        "timestamp": message.created_at.isoformat() + "Z",
    }
    if message.media_asset_id:
        data["media"] = {"id": message.media_asset_id}
    bouton = reponse_bouton(db, message)
    if bouton:
        data["button_reply"] = bouton
    webhooks.mettre_en_file(db, bot, "message.received", data)
