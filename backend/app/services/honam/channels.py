"""Les conversations d'une commande Honam, séparées selon les acteurs.

Trois canaux, chacun entre DEUX parties seulement :

- ``patient`` : la patiente et l'officine (devis, paiement, refus…) ;
- ``coursier`` : l'officine et le coursier de la course (remise du colis,
  original à rapporter) ;
- ``livraison`` : la patiente et le coursier (guider jusqu'à l'adresse,
  « je suis devant »). Il existe parce que le coursier et la patiente
  s'écrivaient déjà dans le fil commun (incident « adresse introuvable »).

Personne ne voit un canal qui ne le concerne pas : ni l'officine la
livraison, ni la patiente l'échange avec le coursier, ni le coursier ce que
la patiente dit à l'officine. Les canaux du coursier sont ceux du coursier
ACTUEL : chaque message y garde le coursier de l'époque, et un coursier
remplacé (défaut, accident) ne relit plus rien, pas plus que son
remplaçant ne lit ce que l'ancien avait échangé.
"""
from typing import Optional, Set

from sqlalchemy.orm import Session

from app.models import HonamOrder, HonamOrderMessage, PharmacyStaff

PATIENT = "patient"
COURIER = "coursier"
DELIVERY = "livraison"

#: Les deux rôles de chaque canal.
CHANNELS = {
    PATIENT: ("PATIENT", "PHARMACY"),
    COURIER: ("PHARMACY", "COURIER"),
    DELIVERY: ("PATIENT", "COURIER"),
}

#: Le canal par défaut d'un client qui n'en précise pas (anciennes versions
#: de l'application) : celui que chacun avait d'abord.
DEFAULT_FOR_ROLE = {"PATIENT": PATIENT, "PHARMACY": PATIENT, "COURIER": COURIER}


def _is_staff(db: Session, order: HonamOrder, user_id: int) -> bool:
    return db.query(PharmacyStaff.id).filter(
        PharmacyStaff.pharmacy_id == order.pharmacy_id, PharmacyStaff.user_id == user_id,
    ).first() is not None


def roles_of(db: Session, order: HonamOrder, user_id: int) -> Set[str]:
    roles = set()
    if order.patient_id == user_id:
        roles.add("PATIENT")
    if order.courier_id is not None and order.courier_id == user_id:
        roles.add("COURIER")
    if _is_staff(db, order, user_id):
        roles.add("PHARMACY")
    return roles


def role_in(db: Session, order: HonamOrder, user_id: int, channel: str) -> Optional[str]:
    """Le rôle sous lequel [user_id] parle dans [channel], ou rien s'il n'en
    est pas membre. Un canal du coursier n'existe qu'avec un coursier."""
    if channel not in CHANNELS:
        return None
    if channel in (COURIER, DELIVERY) and order.courier_id is None:
        return None
    mine = roles_of(db, order, user_id)
    for role in CHANNELS[channel]:
        if role in mine:
            return role
    return None


def channels_of(db: Session, order: HonamOrder, user_id: int) -> list:
    return [c for c in CHANNELS if role_in(db, order, user_id, c) is not None]


def members(db: Session, order: HonamOrder, channel: str) -> Set[int]:
    """Les utilisateurs qui lisent [channel] maintenant."""
    if channel in (COURIER, DELIVERY) and order.courier_id is None:
        return set()
    users: Set[int] = set()
    roles = CHANNELS.get(channel, ())
    if "PATIENT" in roles:
        users.add(order.patient_id)
    if "COURIER" in roles:
        users.add(order.courier_id)
    if "PHARMACY" in roles:
        users.update(
            uid for (uid,) in db.query(PharmacyStaff.user_id).filter(PharmacyStaff.pharmacy_id == order.pharmacy_id)
        )
    return users


def visible_messages(db: Session, order: HonamOrder, channel: str, role: str):
    """Les messages de [channel] que [role] peut lire : le coursier ne lit
    que ce qui a été échangé avec lui."""
    query = db.query(HonamOrderMessage).filter(
        HonamOrderMessage.order_id == order.id, HonamOrderMessage.channel == channel,
    )
    if role == "COURIER":
        query = query.filter(HonamOrderMessage.courier_id == order.courier_id)
    return query


def message_recipients(db: Session, order: HonamOrder, message: HonamOrderMessage) -> Set[int]:
    """À qui annoncer un message : les membres de son canal, et pour un
    canal du coursier seulement si c'est encore le coursier de la course."""
    if message.channel in (COURIER, DELIVERY) and message.courier_id != order.courier_id:
        recipients = members(db, order, message.channel) - {order.courier_id}
    else:
        recipients = members(db, order, message.channel)
    return {u for u in recipients if u}
