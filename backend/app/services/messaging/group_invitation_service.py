"""Inviter quelqu'un dans un groupe, et le laisser décider.

Ajouter quelqu'un le rendait membre sur-le-champ : on se retrouvait dans une
conversation sans l'avoir demandé, avec ses notifications et son historique,
et la seule sortie était de partir — c'est-à-dire d'annoncer publiquement
qu'on était parti.

── Les deux règles ne sont pas la même ──────────────────────────────────

« Qui peut m'inviter » décide si l'invitation PART. Elle ne décide jamais de
l'adhésion : même quelqu'un qui autorise tout le monde garde le dernier mot
sur chaque invitation. Confondre les deux ramènerait exactement le
comportement qu'on remplace, avec un réglage devant.

── L'expiration se calcule, elle ne se balaie pas ───────────────────────

Aucune tâche de fond. Un balayage périodique aurait deux défauts : une
fenêtre pendant laquelle une invitation périmée reste acceptable, et un
ordonnanceur de plus à surveiller — alors que « est-elle encore valable ? »
a une réponse exacte à tout instant, qui est une soustraction de dates.

Le statut est tout de même ÉCRIT quand on le constate, pour que la base
reflète ce que l'utilisateur a vu et que l'historique se relise. La lecture
fait donc foi ; l'écriture ne fait que suivre.
"""
import logging
from datetime import datetime, timedelta
from typing import List, Optional

from sqlalchemy.orm import Session

from app.models import Group, GroupInvitation, GroupInvitationStatus, GroupMember, User

logger = logging.getLogger(__name__)

#: Trois jours. Assez pour couvrir un week-end sans réseau, assez court pour
#: qu'une invitation oubliée ne resurgisse pas des mois plus tard dans un
#: groupe devenu autre chose.
DUREE_DE_VIE = timedelta(hours=72)


class InvitationImpossible(ValueError):
    """Refus métier — l'appelant en fait un 4xx avec le message."""


def _perimee(invitation: GroupInvitation, maintenant: datetime) -> bool:
    return (
        invitation.status == GroupInvitationStatus.PENDING
        and invitation.expires_at <= maintenant
    )


def etat(
    db: Session, invitation: GroupInvitation, *, maintenant: Optional[datetime] = None
) -> GroupInvitationStatus:
    """Le statut RÉEL, expiration comprise.

    Écrit `EXPIRED` au passage : sans cela la base garderait des `PENDING`
    éternels, et la contrainte d'unicité partielle empêcherait une nouvelle
    invitation alors que l'ancienne ne vaut plus rien.
    """
    maintenant = maintenant or datetime.utcnow()
    if _perimee(invitation, maintenant):
        invitation.status = GroupInvitationStatus.EXPIRED
        db.flush()
    return invitation.status


def en_cours(
    db: Session, group_id: int, user_id: int, *, maintenant: Optional[datetime] = None
) -> Optional[GroupInvitation]:
    """L'invitation encore valable pour ce couple, ou `None`."""
    maintenant = maintenant or datetime.utcnow()
    invitation = (
        db.query(GroupInvitation)
        .filter(
            GroupInvitation.group_id == group_id,
            GroupInvitation.user_id == user_id,
            GroupInvitation.status == GroupInvitationStatus.PENDING,
        )
        .first()
    )
    if invitation is None:
        return None
    if etat(db, invitation, maintenant=maintenant) != GroupInvitationStatus.PENDING:
        return None
    return invitation


def inviter(
    db: Session, group_id: int, user_id: int, invited_by_id: int
) -> GroupInvitation:
    """Crée l'invitation, ou renvoie celle qui court déjà.

    **Idempotent**, et c'est ce qui compte ici : un double appui sur
    « Ajouter » ne doit pas produire deux invitations pour la même personne,
    ni échouer avec une violation de contrainte que l'utilisateur ne peut pas
    interpréter. La deuxième tentative rend simplement la première.
    """
    maintenant = datetime.utcnow()

    deja_membre = (
        db.query(GroupMember.id)
        .filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id)
        .first()
    )
    if deja_membre:
        raise InvitationImpossible("Cette personne fait déjà partie du groupe")

    existante = en_cours(db, group_id, user_id, maintenant=maintenant)
    if existante is not None:
        return existante

    invitation = GroupInvitation(
        group_id=group_id,
        user_id=user_id,
        invited_by_id=invited_by_id,
        status=GroupInvitationStatus.PENDING,
        created_at=maintenant,
        expires_at=maintenant + DUREE_DE_VIE,
    )
    db.add(invitation)
    db.flush()
    return invitation


def accepter(db: Session, invitation: GroupInvitation) -> GroupMember:
    """L'invité rejoint le groupe.

    Crée l'appartenance ET clôt l'invitation dans la même transaction : une
    panne entre les deux laisserait soit un membre sans trace d'invitation,
    soit une invitation acceptée sans appartenance — et le second cas se
    solderait par un groupe qu'on croit avoir rejoint et où l'on ne reçoit
    rien.
    """
    maintenant = datetime.utcnow()
    if etat(db, invitation, maintenant=maintenant) != GroupInvitationStatus.PENDING:
        raise InvitationImpossible("Cette invitation n'est plus valable")

    invitation.status = GroupInvitationStatus.ACCEPTED
    invitation.responded_at = maintenant

    # Course possible : la personne a pu être ajoutée autrement entre-temps
    # (lien d'invitation). On ne crée pas de doublon.
    membre = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == invitation.group_id,
            GroupMember.user_id == invitation.user_id,
        )
        .first()
    )
    if membre is None:
        membre = GroupMember(
            group_id=invitation.group_id,
            user_id=invitation.user_id,
            role="MEMBER",
        )
        db.add(membre)
    db.flush()
    return membre


def refuser(db: Session, invitation: GroupInvitation) -> GroupInvitation:
    maintenant = datetime.utcnow()
    if etat(db, invitation, maintenant=maintenant) != GroupInvitationStatus.PENDING:
        raise InvitationImpossible("Cette invitation n'est plus valable")
    invitation.status = GroupInvitationStatus.REJECTED
    invitation.responded_at = maintenant
    db.flush()
    return invitation


def mes_invitations(db: Session, user_id: int) -> List[GroupInvitation]:
    """Ce que l'invité a à décider, les plus récentes d'abord."""
    maintenant = datetime.utcnow()
    lignes = (
        db.query(GroupInvitation)
        .filter(
            GroupInvitation.user_id == user_id,
            GroupInvitation.status == GroupInvitationStatus.PENDING,
        )
        .order_by(GroupInvitation.created_at.desc())
        .all()
    )
    encore = [i for i in lignes if etat(db, i, maintenant=maintenant) == GroupInvitationStatus.PENDING]
    if len(encore) != len(lignes):
        db.commit()  # les expirations constatées sont écrites
    return encore


def serialiser(db: Session, invitation: GroupInvitation) -> dict:
    """Ce que l'invité voit AVANT d'accepter.

    Le nom, la photo, qui l'invite, combien ils sont — de quoi décider. Pas
    les messages : on ne lit pas une conversation qu'on n'a pas rejointe, et
    l'invitation ne doit pas devenir une porte dérobée vers son contenu.
    """
    groupe: Optional[Group] = invitation.group
    invitant: Optional[User] = invitation.invited_by
    membres = (
        db.query(GroupMember).filter(GroupMember.group_id == invitation.group_id).count()
    )
    return {
        "id": invitation.id,
        "group": {
            "id": invitation.group_id,
            "name": groupe.name if groupe else None,
            "avatar_media_id": getattr(groupe, "avatar_media_id", None),
            "member_count": membres,
        },
        "invited_by": {
            "id": invitant.id if invitant else None,
            "display_name": (
                (invitant.full_name or invitant.phone) if invitant else None
            ),
        },
        "status": invitation.status.value
        if hasattr(invitation.status, "value")
        else str(invitation.status),
        "created_at": invitation.created_at.isoformat(),
        "expires_at": invitation.expires_at.isoformat(),
    }
