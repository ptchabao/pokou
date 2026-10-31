"""Faut-il déranger cette personne, et à quel point ?

Trois choses sont distinctes, et les confondre est la raison pour laquelle
une messagerie devient insupportable :

1. **L'événement** — un message est arrivé. C'est un fait, il est toujours
   enregistré et toujours poussé sur le WebSocket.
2. **La décision de notifier** — faut-il sortir le téléphone de sa poche ?
   C'est ce module. Elle dépend de la sourdine, du type d'événement, et de
   la place de cette personne dans la conversation (citée ou simple témoin).
3. **La présentation** — bandeau, son, vibration, plein écran, regroupement.
   Elle appartient au CLIENT, qui seul sait si l'écran concerné est ouvert
   (voir mobile/lib/core/notifications/notification_policy.dart).

Jusqu'ici, chaque route appelait `send_push` directement avec un titre déjà
composé. Aucune ne consultait la sourdine : mettre une conversation en
silence taisait la bannière côté client, mais le téléphone recevait quand
même la poussée, la construisait et la montrait quand l'application était
fermée — c'est-à-dire précisément là où la sourdine compte.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Contact, GroupMember


class NotificationEvent(str, Enum):
    """Ce qui vient de se produire.

    La valeur est celle envoyée au client dans `data["type"]` : elle sert
    aussi à router le tap vers le bon écran, donc elle ne change pas sans
    casser les installations déjà déployées.
    """

    DIRECT_MESSAGE = "message"
    GROUP_MESSAGE = "group_message"
    GROUP_MENTION = "group_mention"
    REPLY = "reply"
    REACTION = "reaction"
    CALL = "call"
    POLL = "poll"


class Priority(str, Enum):
    """À quel point cet événement mérite d'interrompre.

    Le client traduit ces quatre niveaux en canaux et en importance Android ;
    le serveur ne connaît pas ces notions et n'a pas à les connaître.
    """

    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


@dataclass(frozen=True)
class NotificationDecision:
    """Le verdict, et de quoi le relire dans les journaux."""

    deliver: bool
    priority: Priority
    muted: bool
    reason: str

    def as_payload(self) -> dict[str, str]:
        """Ce qui voyage jusqu'au client, en plus du contenu.

        Des chaînes, parce que FCM n'accepte que des chaînes dans `data`.
        """
        return {"priority": self.priority.value, "muted": "1" if self.muted else "0"}


def _is_muted(muted_until: Optional[datetime]) -> bool:
    return muted_until is not None and muted_until > datetime.utcnow()


def _direct_conversation_muted(db: Session, recipient_id: int, sender_id: int) -> bool:
    contact = (
        db.query(Contact)
        .filter(Contact.owner_user_id == recipient_id, Contact.contact_user_id == sender_id)
        .first()
    )
    return contact is not None and _is_muted(contact.muted_until)


def _group_muted(db: Session, recipient_id: int, group_id: int) -> bool:
    # La sourdine vit sur l'APPARTENANCE et non sur le groupe : silencer une
    # conversation est un choix personnel, il ne s'impose pas aux autres
    # membres (voir orm.py::GroupMember).
    membership = (
        db.query(GroupMember)
        .filter(GroupMember.group_id == group_id, GroupMember.user_id == recipient_id)
        .first()
    )
    return membership is not None and _is_muted(membership.muted_until)


def decide(
    db: Session,
    *,
    recipient_id: int,
    event: NotificationEvent,
    sender_id: Optional[int] = None,
    group_id: Optional[int] = None,
) -> NotificationDecision:
    """Le verdict pour un destinataire et un événement.

    Les règles, et ce qu'elles coûtent quand on les oublie :

    - **Un appel passe toujours, au maximum de priorité.** Mettre une
      conversation en sourdine veut dire « ne me lis pas les messages à voix
      haute », pas « ne me préviens pas si cette personne m'appelle ». Les
      confondre ferait manquer des appels, ce qu'aucune excuse ne rattrape.
    - **Une mention passe même en sourdine**, mais sans son. Quelqu'un qui a
      silencé un groupe de cent personnes veut toujours savoir qu'on
      s'adresse à LUI — c'est la seule raison de rouvrir un groupe qu'on a
      cessé de suivre.
    - **Une réaction en sourdine ne passe pas du tout.** C'est l'événement de
      plus faible valeur ; en faire vibrer un téléphone qu'on a explicitement
      demandé de taire, c'est ce qui pousse à désinstaller.
    - **Le reste passe, silencieux si la conversation est en sourdine.** La
      notification reste visible en ouvrant le volet : la sourdine porte sur
      le bruit, pas sur l'information.
    """
    if event is NotificationEvent.CALL:
        return NotificationDecision(
            deliver=True,
            priority=Priority.URGENT,
            muted=False,
            reason="appel — la sourdine d'une conversation ne couvre pas les appels",
        )

    if group_id is not None:
        muted = _group_muted(db, recipient_id, group_id)
    elif sender_id is not None:
        muted = _direct_conversation_muted(db, recipient_id, sender_id)
    else:
        muted = False

    if event is NotificationEvent.GROUP_MENTION:
        return NotificationDecision(
            deliver=True,
            # En sourdine, la mention passe mais ne sonne pas : elle informe
            # sans rompre le silence demandé.
            priority=Priority.NORMAL if muted else Priority.HIGH,
            muted=muted,
            reason="mention" + (" dans un groupe en sourdine" if muted else ""),
        )

    if event is NotificationEvent.REACTION:
        if muted:
            return NotificationDecision(
                deliver=False,
                priority=Priority.LOW,
                muted=True,
                reason="réaction dans une conversation en sourdine — rien à annoncer",
            )
        return NotificationDecision(
            deliver=True, priority=Priority.LOW, muted=False, reason="réaction"
        )

    if event is NotificationEvent.REPLY:
        return NotificationDecision(
            deliver=True,
            priority=Priority.NORMAL if muted else Priority.HIGH,
            muted=muted,
            reason="réponse à un de mes messages",
        )

    return NotificationDecision(
        deliver=True,
        priority=Priority.NORMAL,
        muted=muted,
        reason="message" + (" en sourdine" if muted else ""),
    )
