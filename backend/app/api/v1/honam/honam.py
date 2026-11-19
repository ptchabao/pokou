"""HONAM — pharmacies et livraison (lot 2).

Trois publics, trois préfixes :

- ``/honam/...`` : le patient (annuaire, ordonnance, devis, suivi) ;
- ``/honam/pharmacy/...`` : l'équipe d'une officine (l'espace officine,
  servi aussi en application web sous ``/officine``) ;
- ``/honam/courier/...`` : le mode coursier Win Pokou.

Ce que chacun voit est découpé à la main dans `_order_json` : le code de
remise ne part QU'AU patient, l'ordonnance qu'à l'officine, et le coursier ne
voit ni l'ordonnance ni les médicaments.
"""
from datetime import date, datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.v1.modules.common import open_payment, payment_json
from app.core.countries import country_config, country_of_phone, module_open
from app.core.database import get_db
from app.core.permissions import require_permission_claims
from app.core.rbac import require_admin_role
from app.core.security import get_current_user
from app.models import (
    CourierDefault,
    CourierLedgerEntry,
    CourierOfferDismissal,
    CourierProfile,
    CourierWalletCheck,
    HonamOrder,
    HonamOrderEvent,
    HonamOrderMessage,
    HonamWaitlistEntry,
    Pharmacy,
    PharmacyApplication,
    PharmacyCourier,
    PharmacyStaff,
    User,
    UserRole,
)
from app.services.honam import rules
from app.services.honam import channels as honam_channels
from app.services.honam.order_notifications import notify_order_message, notify_order_state_changed
from app.utils.phone import normalize_e164

router = APIRouter(prefix="/honam", tags=["HONAM"])
admin_router = APIRouter(prefix="/admin/honam", tags=["Admin HONAM"])

#: Une officine ne voit que ses commandes ; les plus anciennes d'abord dans
#: la file à traiter.
_PHARMACY_QUEUE = ("SUBMITTED", "ACCEPTED", "PAID", "READY", "IN_DELIVERY")

#: Le suivi n'existe que pendant la course : de l'acceptation par le
#: coursier à la remise.
_TRACKABLE = ("READY", "IN_DELIVERY")

#: « Le support de Pokou vérifie votre autorisation et votre wallet sous
#: 48 h » (maquette Officine 16), comme un dossier Pokou certifié Pro.
REGISTRATION_REVIEW_HOURS = 48

#: Les jours et moments de disponibilité (maquette Coursiers 4).
_DAYS = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")
_MOMENTS = ("MORNING", "NOON", "AFTERNOON", "EVENING")


# ── Corps de requêtes ───────────────────────────────────────────────────


class OrderCreate(BaseModel):
    pharmacy_id: int
    prescription_media_id: int
    delivery_address: str = Field(..., min_length=3, max_length=255)
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    note: Optional[str] = Field(None, max_length=500)
    #: Le repère qui aide le coursier (« portail bleu face au kiosque »).
    landmark: Optional[str] = Field(None, max_length=255)


class ResendBody(BaseModel):
    pharmacy_id: int


class DeclarePaidBody(BaseModel):
    #: La référence de la transaction, lue dans le SMS de l'opérateur.
    #: Facultative : un ancien client ne l'envoie pas.
    reference: Optional[str] = Field(None, max_length=64)


class QuoteItem(BaseModel):
    name: str = Field(..., min_length=1, max_length=160)
    quantity: int = Field(1, ge=1, le=100)
    unit_price: int = Field(..., ge=0, le=5_000_000)
    available: bool = True
    #: Le conditionnement (« 12 gélules », « Flacon 125 ml »).
    packaging: Optional[str] = Field(None, max_length=80)
    #: Un générique proposé à la place du princeps.
    generic: bool = False


class QuoteBody(BaseModel):
    items: List[QuoteItem] = Field(..., min_length=1, max_length=50)
    original_required: bool = False


class ReasonBody(BaseModel):
    reason: str = Field(..., min_length=3, max_length=255)


class RefundBody(BaseModel):
    amount: int = Field(..., ge=1, le=5_000_000)
    reason: str = Field(..., min_length=3, max_length=255)


class MissingChoiceBody(BaseModel):
    choice: str  # KEEP (recevoir le reste) | CANCEL (tout annuler)


class OrderMessageBody(BaseModel):
    body: str = Field(..., min_length=1, max_length=1000)
    #: patient | coursier | livraison ; par défaut, le premier canal du rôle.
    channel: Optional[str] = Field(None, max_length=10)


class CourierApplication(BaseModel):
    #: Les zones en texte libre (ancien formulaire). Sans elles, les
    #: quartiers de `zones_list` en tiennent lieu.
    zones: Optional[str] = Field(None, max_length=255)
    wallet_phone: str
    accept_rules: bool
    #: Ville où la personne livrerait. Hors des villes desservies, la
    #: candidature est refusée et l'application propose la liste d'attente.
    city: Optional[str] = Field(None, max_length=80)
    #: Code de parrainage d'un coursier déjà validé (maquette Coursiers 15).
    referral_code: Optional[str] = Field(None, max_length=12)
    # ── Inscription en 6 étapes (maquettes Coursiers 2 à 6) ──
    birth_date: Optional[date] = None
    transport: Optional[str] = Field(None, pattern="^(MOTO|VELO|PIED)$")
    id_doc_type: Optional[str] = Field(None, pattern="^(CNI|PASSPORT|VOTER)$")
    id_front_media_id: Optional[int] = None
    id_back_media_id: Optional[int] = None
    selfie_media_id: Optional[int] = None
    zones_list: Optional[List[str]] = Field(None, max_length=30)
    days: Optional[List[str]] = Field(None, max_length=7)
    moments: Optional[List[str]] = Field(None, max_length=4)
    quiz_passed: bool = False


class WalletCodeBody(BaseModel):
    wallet_phone: str


class WalletVerifyBody(BaseModel):
    wallet_phone: str
    code: str = Field(..., min_length=4, max_length=8)


class AvailabilityBody(BaseModel):
    available: bool


class IdentityBody(BaseModel):
    """Candidature à compléter (maquette Coursiers 18) : la pièce reprise."""
    selfie_media_id: Optional[int] = None
    id_front_media_id: Optional[int] = None
    id_back_media_id: Optional[int] = None


class IncidentBody(BaseModel):
    kind: str = Field(..., pattern="^(NO_ANSWER|ADDRESS|CODE|ACCIDENT)$")


class ContestBody(BaseModel):
    note: Optional[str] = Field(None, max_length=500)


class LocationBody(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)


class WaitlistBody(BaseModel):
    city: str = Field(..., min_length=2, max_length=80)
    role: str = "COURIER"  # COURIER | PATIENT


class AttachCourierBody(BaseModel):
    phone: str


class DeliverBody(BaseModel):
    code: str = Field(..., min_length=6, max_length=6)


class OnDutyBody(BaseModel):
    on_duty: bool


class PlanBody(BaseModel):
    plan: str  # WETRI | EPE


class CreditBody(BaseModel):
    #: Montant HT de crédit, multiple de 100 (une commande).
    amount_ht: int = Field(..., ge=1000, le=1_000_000)


class PackBody(BaseModel):
    pack: str


class PickupProposeBody(BaseModel):
    #: Le message à la patiente, rédigé dans sa langue par l'application.
    message: Optional[str] = Field(None, max_length=1000)


class CodeBody(BaseModel):
    code: str = Field(..., min_length=6, max_length=6)


class PharmacyUpdate(BaseModel):
    """Compte de l'officine (maquette Officine 13). Le nom, enregistré
    auprès de l'Ordre, ne se change qu'avec l'équipe Pokou."""
    address: Optional[str] = Field(None, min_length=3, max_length=255)
    phone: Optional[str] = Field(None, min_length=6, max_length=32)
    opening_hours: Optional[str] = Field(None, max_length=255)
    #: « Prochaine garde » ; `clear_next_duty` l'efface.
    next_duty_on: Optional[date] = None
    clear_next_duty: bool = False
    temporarily_closed: Optional[bool] = None
    #: Propre au téléphone (au compte) qui fait la demande.
    ring_on_order: Optional[bool] = None


class PhoneBody(BaseModel):
    phone: str = Field(..., min_length=6, max_length=32)


class PharmacyCreate(BaseModel):
    country: str = Field(..., min_length=2, max_length=2)
    name: str = Field(..., min_length=2, max_length=160)
    address: str = Field(..., min_length=3, max_length=255)
    phone: str
    opening_hours: Optional[str] = None
    latitude: float
    longitude: float
    wallet_phone: str
    titulaire_phone: str


class PharmacyRegistrationBody(BaseModel):
    """« Référencer votre officine » (maquettes Officine 14 et 15)."""
    name: str = Field(..., min_length=2, max_length=160)
    address: str = Field(..., min_length=3, max_length=255)
    license_number: str = Field(..., min_length=2, max_length=64)
    wallet_phone: str
    #: L'arrêté d'autorisation d'ouverture (photo ou PDF), déjà téléversé.
    #: Facultatif seulement au renvoi d'un dossier refusé : le précédent sert.
    authorization_media_id: Optional[int] = None
    plan: str = Field(..., pattern="^(WETRI|EPE)$")
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)


class RegistrationReviewBody(BaseModel):
    decision: str = Field(..., pattern="^(APPROVE|REJECT)$")
    note: Optional[str] = Field(None, max_length=500)
    #: La position de l'officine, quand le téléphone ne l'a pas donnée ou
    #: qu'elle est fausse : l'annuaire trie par distance.
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    #: Le téléphone de l'officine ; par défaut, celui du titulaire.
    phone: Optional[str] = None
    opening_hours: Optional[str] = Field(None, max_length=255)


# ── Accès ───────────────────────────────────────────────────────────────


def _user(db: Session, current_user: dict) -> User:
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if user is None or not module_open(db, user.phone, "honam"):
        raise HTTPException(status_code=404, detail="HONAM n'est pas disponible dans votre pays")
    return user


def _expire_quote_and_notify(db: Session, order: HonamOrder) -> bool:
    previous_status = order.status
    rules.expire_quote_if_due(db, order)
    if order.status == previous_status:
        return False
    db.commit()
    notify_order_state_changed(db, order, actor_id=None)
    return True


def _staff_pharmacy(db: Session, user_id: int) -> Pharmacy:
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.user_id == user_id).first()
    if staff is None:
        raise HTTPException(status_code=403, detail="Réservé à l'équipe d'une officine")
    return db.query(Pharmacy).filter(Pharmacy.id == staff.pharmacy_id).first()


def _patient_order(db: Session, order_id: int, user_id: int) -> HonamOrder:
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id, HonamOrder.patient_id == user_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    _expire_quote_and_notify(db, order)
    return order


def _pharmacy_order(db: Session, order_id: int, pharmacy: Pharmacy) -> HonamOrder:
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id, HonamOrder.pharmacy_id == pharmacy.id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    _expire_quote_and_notify(db, order)
    return order


def _courier(db: Session, user: User) -> CourierProfile:
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user.id).first()
    if courier is None:
        raise HTTPException(status_code=403, detail="Activez d'abord le mode coursier")
    return courier


def _move(db: Session, order: HonamOrder, status: str, actor_id: int, note: Optional[str] = None) -> None:
    try:
        rules.transition(db, order, status, actor_id, note)
    except rules.TransitionError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


def _commit_order_change(db: Session, order: HonamOrder, actor_id: int) -> None:
    db.commit()
    notify_order_state_changed(db, order, actor_id=actor_id)


# ── Représentations ─────────────────────────────────────────────────────


def _pharmacy_json(pharmacy: Pharmacy, *, distance: Optional[float] = None) -> dict:
    """Format annuaire : les MÊMES champs pour toutes les officines."""
    return {
        "id": pharmacy.id,
        "name": pharmacy.name,
        "address": pharmacy.address,
        "phone": pharmacy.phone,
        "opening_hours": pharmacy.opening_hours,
        "is_on_duty": pharmacy.is_on_duty,
        "latitude": pharmacy.latitude,
        "longitude": pharmacy.longitude,
        "distance_km": round(distance, 2) if distance is not None else None,
    }


def _name(db: Session, user_id: Optional[int]) -> Optional[str]:
    if user_id is None:
        return None
    user = db.query(User).filter(User.id == user_id).first()
    return user.full_name if user else None


def _phone(db: Session, user_id: int) -> Optional[str]:
    user = db.query(User).filter(User.id == user_id).first()
    return user.phone if user else None


def _iso(value: Optional[datetime]) -> Optional[str]:
    return value.isoformat() if value else None


def _courier_wallet(db: Session, order: HonamOrder) -> Optional[str]:
    if order.courier_id is None:
        return None
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == order.courier_id).first()
    return courier.wallet_phone if courier else None


def _order_json(db: Session, order: HonamOrder, viewer: str) -> dict:
    """`viewer` : patient | pharmacy | courier."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
    total = (order.medicines_total or 0) + (order.delivery_price or 0) if order.medicines_total is not None else None
    data = {
        "id": order.id,
        "status": order.status,
        "pharmacy": _pharmacy_json(pharmacy) if pharmacy else None,
        "delivery_address": order.delivery_address,
        "delivery_price": order.delivery_price,
        "original_required": order.original_required,
        "delivery_landmark": order.delivery_landmark,
        "courier_name": _name(db, order.courier_id),
        "created_at": order.created_at.isoformat(),
        "updated_at": order.updated_at.isoformat(),
        "delivered_at": order.delivered_at.isoformat() if order.delivered_at else None,
    }
    if viewer in ("patient", "pharmacy"):
        data.update({
            "patient_note": order.patient_note,
            "payment_reference": order.payment_reference,
            "missing_reported_at": order.missing_reported_at.isoformat() if order.missing_reported_at else None,
        })
    if viewer == "patient":
        # La photo est celle que la patiente a envoyée : elle la revoit dans
        # sa commande (maquette Honam patient 2).
        data["prescription_media_id"] = order.prescription_media_id
        # Pendant la course, de quoi joindre le coursier par un appel Pokou
        # (numéro masqué) et estimer son arrivée.
        courier = _courier_profile_of(db, order.courier_id) if order.status in _TRACKABLE else None
        data["courier_user_id"] = order.courier_id if order.status in _TRACKABLE else None
        data["courier_transport"] = courier.transport if courier else None
    if viewer in ("patient", "pharmacy"):
        data.update({
            "quote_items": order.quote_items,
            "medicines_total": order.medicines_total,
            "total": total,
            "quote_expires_at": order.quote_expires_at.isoformat() if order.quote_expires_at else None,
            "rejection_reason": order.rejection_reason,
            "patient_paid_declared_at": order.patient_paid_declared_at.isoformat() if order.patient_paid_declared_at else None,
            "payment_not_received_at": order.payment_not_received_at.isoformat() if order.payment_not_received_at else None,
            "missing_amount": order.missing_amount,
            "missing_reason": order.missing_reason,
            "missing_choice": order.missing_choice,
            "refund_due": order.refund_due,
            "refund_reason": order.refund_reason,
            "refund_confirmed_at": order.refund_confirmed_at.isoformat() if order.refund_confirmed_at else None,
            "refund_requested_at": _iso(order.refund_requested_at),
            "refund_sent_at": _iso(order.refund_sent_at),
            "refund_reference": order.refund_reference,
            "timeline": [
                {"status": e.status, "note": e.note, "at": e.created_at.isoformat()}
                for e in db.query(HonamOrderEvent).filter(HonamOrderEvent.order_id == order.id).order_by(HonamOrderEvent.id)
            ],
        })
    if viewer == "patient":
        # Le wallet à payer n'apparaît qu'une fois le devis accepté.
        data["pay_to_phone"] = pharmacy.wallet_phone if pharmacy and order.status == "ACCEPTED" else None
        data["delivery_code"] = order.delivery_code if order.status in ("PAID", "READY", "IN_DELIVERY") else None
    if viewer == "pharmacy":
        data.update({
            "patient_name": _name(db, order.patient_id),
            "prescription_media_id": order.prescription_media_id,
            "patient_note": order.patient_note,
            "courier_paid_at": order.courier_paid_at.isoformat() if order.courier_paid_at else None,
            "courier_paid_declared_at": _iso(order.courier_paid_declared_at),
            "original_collected_at": _iso(order.original_collected_at),
            "original_returned_at": _iso(order.original_returned_at),
            # Le remboursement part UNIQUEMENT vers le numéro qui a payé.
            "refund_to_phone": _phone(db, order.patient_id) if order.refund_due > 0 else None,
            # Le wallet du coursier, pour lui payer la course : seulement
            # une fois la commande livrée, et seulement à l'officine.
            "courier_wallet_phone": _courier_wallet(db, order) if order.status == "DELIVERED" else None,
            # L'appel relayé par Pokou (numéro masqué) tant que la
            # discussion avec le coursier est ouverte (maquette Officine 10).
            "courier_user_id": order.courier_id if rules.courier_chat_open(order) else None,
            "courier_chat_closes_at": _iso(
                order.delivered_at + timedelta(hours=rules.COURIER_CHAT_HOURS)
            ) if order.courier_id and order.delivered_at else None,
            "pickup_proposed_at": _iso(order.pickup_proposed_at),
            "pickup_at_pharmacy": bool(order.pickup_at_pharmacy),
            "delivery_distance_km": _delivery_distance(pharmacy, order),
            "dispatch": _dispatch_json(db, pharmacy, order) if pharmacy else None,
        })
    if viewer == "courier":
        picked_up = (
            db.query(HonamOrderEvent.created_at)
            .filter(HonamOrderEvent.order_id == order.id, HonamOrderEvent.status == "IN_DELIVERY")
            .order_by(HonamOrderEvent.id.desc())
            .first()
        )
        mine = order.courier_id is not None
        data.update({
            "courier_paid_at": order.courier_paid_at.isoformat() if order.courier_paid_at else None,
            "courier_paid_declared_at": _iso(order.courier_paid_declared_at),
            "delivery_latitude": order.delivery_latitude,
            "delivery_longitude": order.delivery_longitude,
            # Le prénom seul (« Afi ») : de quoi demander le code à la bonne
            # personne, rien de plus.
            "patient_name": _first_name(db, order.patient_id),
            # L'appel passe par Pokou : le coursier ne voit jamais le numéro.
            "patient_user_id": order.patient_id if mine and order.status in _TRACKABLE else None,
            "picked_up_at": picked_up[0].isoformat() if picked_up else None,
            "incident_kind": order.incident_kind,
            "incident_at": order.incident_at.isoformat() if order.incident_at else None,
            "code_attempts_left": max(rules.MAX_CODE_ATTEMPTS - (order.code_attempts or 0), 0),
            "original_returned_at": order.original_returned_at.isoformat() if order.original_returned_at else None,
        })
    return data


def _first_name(db: Session, user_id: Optional[int]) -> Optional[str]:
    name = _name(db, user_id)
    return name.split()[0] if name else None


def _courier_profile_of(db: Session, user_id: Optional[int]) -> Optional[CourierProfile]:
    if user_id is None:
        return None
    return db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()


def _delivery_distance(pharmacy: Optional[Pharmacy], order: HonamOrder) -> Optional[float]:
    """De l'officine à l'adresse de livraison, à vol d'oiseau (« 5,8 km »,
    maquette Officine 8)."""
    if pharmacy is None or order.delivery_latitude is None or order.delivery_longitude is None:
        return None
    return round(rules.distance_km(
        pharmacy.latitude, pharmacy.longitude, order.delivery_latitude, order.delivery_longitude,
    ), 1)


def _courier_position(courier: CourierProfile, now: datetime) -> Optional[tuple]:
    """La position récente d'un coursier disponible, ou rien."""
    if courier.latitude is None or courier.longitude is None or courier.located_at is None:
        return None
    if courier.located_at + timedelta(minutes=rules.COURIER_POSITION_TTL_MINUTES) < now:
        return None
    return courier.latitude, courier.longitude


def _within_radius(courier: CourierProfile, pharmacy: Pharmacy, radius_km: float, now: datetime) -> bool:
    """Un coursier sans position connue n'est pas écarté : il reçoit les
    courses de son pays, comme avant le rayon."""
    position = _courier_position(courier, now)
    if position is None:
        return True
    return rules.distance_km(position[0], position[1], pharmacy.latitude, pharmacy.longitude) <= radius_km


def _dispatch_radius(order: HonamOrder) -> float:
    return order.dispatch_radius_km or rules.DISPATCH_RADIUS_KM


def _dispatch_json(db: Session, pharmacy: Pharmacy, order: HonamOrder) -> Optional[dict]:
    """La recherche d'un coursier (maquettes Officine 8 et 9) : seulement
    tant que la commande prête attend un coursier."""
    if order.status != "READY" or order.courier_id is not None or order.pickup_at_pharmacy:
        return None
    now = datetime.utcnow()
    radius = _dispatch_radius(order)
    started = order.dispatch_started_at or order.updated_at
    couriers = db.query(CourierProfile).filter(
        CourierProfile.country == pharmacy.country,
        CourierProfile.available.is_(True),
        CourierProfile.status.in_(("TRIAL", "MEMBER")),
        CourierProfile.user_id != order.patient_id,
    ).all()
    nearby = [c for c in couriers if _within_radius(c, pharmacy, radius, now)]
    attached_ids = {
        row[0] for row in db.query(PharmacyCourier.courier_id).filter(PharmacyCourier.pharmacy_id == pharmacy.id)
    }
    priority_over = started + timedelta(minutes=rules.ATTACHED_PRIORITY_MINUTES) <= now
    # « Kodjo A. n'a pas répondu » : les livreurs habituels disponibles à
    # qui la course a été proposée d'abord, une fois leur avance passée.
    unanswered = [
        _first_name(db, c.user_id) for c in couriers if c.id in attached_ids
    ] if priority_over and order.dispatch_cancelled_at is None else []
    area = (pharmacy.address or "").split(",")[0].strip() or None
    return {
        "started_at": _iso(started),
        "cancelled_at": _iso(order.dispatch_cancelled_at),
        "radius_km": radius,
        "wide_radius_km": rules.WIDE_DISPATCH_RADIUS_KM,
        "available_count": len(nearby),
        "attached_count": len(attached_ids),
        "attached_available_count": sum(1 for c in couriers if c.id in attached_ids),
        "unanswered": [name for name in unanswered if name],
        "priority_minutes": rules.ATTACHED_PRIORITY_MINUTES,
        "no_courier_minutes": rules.NO_COURIER_MINUTES,
        "area": area,
    }


def _order_message_json(db: Session, message: HonamOrderMessage) -> dict:
    sender = db.query(User).filter(User.id == message.sender_id).first() if message.sender_id else None
    return {
        "id": message.id,
        "sender_id": message.sender_id,
        "sender_name": sender.full_name if sender else None,
        "sender_role": message.sender_role,
        "channel": message.channel,
        "body": message.body,
        "read_at": _iso(message.read_at),
        "created_at": message.created_at.isoformat(),
    }


def _message_channel(db: Session, order: Optional[HonamOrder], user_id: int, channel: Optional[str]) -> tuple:
    """Le canal demandé (ou celui par défaut du rôle) et le rôle sous lequel
    l'utilisateur y parle. 404 s'il n'en est pas membre : un canal qui ne le
    concerne pas n'existe pas pour lui."""
    if order is not None:
        if channel is None:
            roles = honam_channels.roles_of(db, order, user_id)
            for role in ("PATIENT", "COURIER", "PHARMACY"):
                if role in roles:
                    channel = honam_channels.DEFAULT_FOR_ROLE[role]
                    break
        role = honam_channels.role_in(db, order, user_id, channel) if channel else None
        if role is not None:
            return channel, role
    raise HTTPException(status_code=404, detail="Conversation introuvable")


# ── Annuaire et configuration ───────────────────────────────────────────


@router.get("/config")
def honam_config(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    config = country_config(db, country_of_phone(user.phone))
    return {
        "delivery_price": config.get("delivery_price"),
        "emergency_numbers": config.get("emergency_numbers", {}),
        "disclaimer": "Pokou n'est pas un service d'urgence.",
    }


@router.get("/pharmacies")
def directory(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    on_duty: bool = False,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """L'annuaire (BM-12) : toutes les officines abonnées, triées par
    distance, sans mise en avant ni classement payant."""
    user = _user(db, current_user)
    country = country_of_phone(user.phone)
    rows = []
    for pharmacy in db.query(Pharmacy).filter(Pharmacy.country == country).all():
        if not rules.pharmacy_accepts_orders(db, pharmacy):
            continue
        if on_duty and not pharmacy.is_on_duty:
            continue
        distance = (
            rules.distance_km(lat, lng, pharmacy.latitude, pharmacy.longitude)
            if lat is not None and lng is not None else None
        )
        rows.append((distance, pharmacy))
    db.commit()
    # Sans position, l'ordre alphabétique : le seul qui ne favorise personne.
    rows.sort(key=lambda r: (r[0] if r[0] is not None else 0, r[1].name))
    return {"items": [_pharmacy_json(p, distance=d) for d, p in rows[:50]]}


# ── Patient ─────────────────────────────────────────────────────────────


def _create_order(db: Session, user: User, body: OrderCreate) -> HonamOrder:
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == body.pharmacy_id).first()
    if pharmacy is None or pharmacy.country != country_of_phone(user.phone) or not rules.pharmacy_accepts_orders(db, pharmacy):
        raise HTTPException(status_code=404, detail="Officine indisponible")
    order = HonamOrder(
        patient_id=user.id,
        pharmacy_id=pharmacy.id,
        prescription_media_id=body.prescription_media_id,
        delivery_address=body.delivery_address.strip(),
        delivery_landmark=(body.landmark or "").strip() or None,
        delivery_latitude=body.delivery_latitude,
        delivery_longitude=body.delivery_longitude,
        patient_note=(body.note or "").strip() or None,
    )
    db.add(order)
    db.flush()
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status="SUBMITTED"))
    rules.record_event(db, rules.EVENTS_TOPIC, "honam.order.submitted",
                       {"order_id": order.id, "pharmacy_id": pharmacy.id, "patient_id": user.id},
                       key=f"order-{order.id}")
    return order


@router.post("/orders", status_code=201)
def submit_prescription(body: OrderCreate, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    from app.models import MediaAsset

    user = _user(db, current_user)
    media = db.query(MediaAsset).filter(MediaAsset.id == body.prescription_media_id).first()
    if media is None or media.uploader_id != user.id:
        raise HTTPException(status_code=422, detail="Photo d'ordonnance introuvable")
    order = _create_order(db, user, body)
    db.commit()
    notify_order_state_changed(db, order, actor_id=user.id)
    return _order_json(db, order, "patient")


@router.get("/orders")
def my_orders(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    orders = db.query(HonamOrder).filter(HonamOrder.patient_id == user.id).order_by(HonamOrder.created_at.desc()).limit(50).all()
    expired = []
    for order in orders:
        previous_status = order.status
        rules.expire_quote_if_due(db, order)
        if order.status != previous_status:
            expired.append(order)
    db.commit()
    for order in expired:
        notify_order_state_changed(db, order, actor_id=None)
    return {"items": [_order_json(db, o, "patient") for o in orders]}


@router.get("/orders/{order_id}")
def my_order(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    db.commit()
    return _order_json(db, order, "patient")


@router.get("/orders/{order_id}/messages")
def order_messages(
    order_id: int,
    channel: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Les messages d'UN canal de la commande (voir services/honam/channels)."""
    user = _user(db, current_user)
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id).first()
    channel, role = _message_channel(db, order, user.id, channel)
    messages = (
        honam_channels.visible_messages(db, order, channel, role)
        .order_by(HonamOrderMessage.created_at, HonamOrderMessage.id)
        .limit(500)
        .all()
    )
    # Accusé « Lu » (maquette Officine 10) : ouvrir le fil marque comme lus
    # les messages de l'autre partie.
    now = datetime.utcnow()
    unread = [m for m in messages if m.read_at is None and m.sender_role != role]
    for message in unread:
        message.read_at = now
    if unread:
        db.commit()
    return {
        "channel": channel,
        "channels": honam_channels.channels_of(db, order, user.id),
        "items": [_order_message_json(db, message) for message in messages],
    }


@router.post("/orders/{order_id}/messages", status_code=201)
def send_order_message(
    order_id: int,
    body: OrderMessageBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _user(db, current_user)
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id).first()
    channel, role = _message_channel(db, order, user.id, body.channel)
    if channel != honam_channels.PATIENT and not rules.courier_chat_open(order):
        raise HTTPException(status_code=409, detail="La discussion s'est fermée 24 h après la livraison")
    message = HonamOrderMessage(
        order_id=order.id,
        sender_id=user.id,
        sender_role=role,
        channel=channel,
        courier_id=order.courier_id if channel != honam_channels.PATIENT else None,
        body=body.body.strip(),
    )
    if not message.body:
        raise HTTPException(status_code=422, detail="Le message ne peut pas être vide")
    db.add(message)
    db.commit()
    db.refresh(message)
    notify_order_message(db, order, message)
    return _order_message_json(db, message)


@router.post("/orders/{order_id}/accept")
def accept_quote(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    _move(db, order, "ACCEPTED", user.id)
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/declare-paid")
def declare_paid(
    order_id: int,
    body: Optional[DeclarePaidBody] = None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """« J'ai payé l'officine » : l'officine doit encore le confirmer. La
    référence de la transaction (maquette Honam patient 4) l'aide à
    retrouver l'envoi dans son wallet."""
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    if order.status != "ACCEPTED":
        raise HTTPException(status_code=409, detail="Le devis doit être accepté")
    order.patient_paid_declared_at = datetime.utcnow()
    order.payment_not_received_at = None
    reference = ((body.reference if body else None) or "").strip().upper()
    order.payment_reference = reference or None
    note = f"Paiement déclaré par le patient (réf. {reference})" if reference else "Paiement déclaré par le patient"
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status="ACCEPTED", note=note))
    db.commit()
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/cancel")
def cancel_order(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    _move(db, order, "CANCELLED", user.id)
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/resend", status_code=201)
def resend_to_other_pharmacy(
    order_id: int, body: ResendBody,
    current_user: dict = Depends(get_current_user), db: Session = Depends(get_db),
):
    """Après un refus ou un devis expiré : la même ordonnance, une autre
    officine — sans reprendre la photo."""
    user = _user(db, current_user)
    previous = _patient_order(db, order_id, user.id)
    if previous.status not in ("REJECTED", "EXPIRED", "CANCELLED"):
        raise HTTPException(status_code=409, detail="Cette commande est encore en cours")
    order = _create_order(db, user, OrderCreate(
        pharmacy_id=body.pharmacy_id,
        prescription_media_id=previous.prescription_media_id,
        delivery_address=previous.delivery_address,
        delivery_latitude=previous.delivery_latitude,
        delivery_longitude=previous.delivery_longitude,
        note=previous.patient_note,
        landmark=previous.delivery_landmark,
    ))
    db.commit()
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/missing-choice")
def missing_choice(order_id: int, body: MissingChoiceBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Un produit manque : recevoir le reste (remboursement du manquant), ou
    tout annuler (remboursement complet). Le délai de 2 h part d'ici."""
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    if order.missing_amount is None or order.missing_choice is not None:
        raise HTTPException(status_code=409, detail="Aucun choix attendu")
    choice = body.choice.upper()
    if choice not in ("KEEP", "CANCEL"):
        raise HTTPException(status_code=422, detail="Choix inconnu")
    order.missing_choice = choice
    order.refund_requested_at = datetime.utcnow()
    order.refund_reason = order.missing_reason
    if choice == "KEEP":
        order.refund_due = order.missing_amount
        db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status=order.status,
                               note="La patiente reçoit le reste ; remboursement du manquant attendu"))
    else:
        order.refund_due = (order.medicines_total or 0) + (order.delivery_price or 0)
        _move(db, order, "CANCELLED", user.id, "Commande annulée après un produit manquant ; remboursement complet attendu")
    if choice == "CANCEL":
        _commit_order_change(db, order, user.id)
    else:
        db.commit()
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/refund-received")
def refund_received(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    if order.refund_due <= 0:
        raise HTTPException(status_code=409, detail="Aucun remboursement attendu")
    order.refund_confirmed_at = datetime.utcnow()
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status=order.status, note="Remboursement reçu"))
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
    rules.refresh_pharmacy_status(db, pharmacy)
    db.commit()
    return _order_json(db, order, "patient")


# ── Officine ────────────────────────────────────────────────────────────


@router.get("/pharmacy/me")
def pharmacy_dashboard(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'accueil de l'espace officine. Les statistiques sont incluses pour
    TOUTES les officines (HON-07, HON-40) : pas d'offre premium."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    rules.refresh_pharmacy_status(db, pharmacy)
    month_start = datetime(datetime.utcnow().year, datetime.utcnow().month, 1)
    counts = dict(
        db.query(HonamOrder.status, func.count(HonamOrder.id))
        .filter(HonamOrder.pharmacy_id == pharmacy.id, HonamOrder.created_at >= month_start)
        .group_by(HonamOrder.status).all()
    )
    prices = rules.pharmacy_prices(db, pharmacy.country)
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.user_id == current_user["user_id"]).first()
    phones_count = db.query(func.count(PharmacyStaff.id)).filter(PharmacyStaff.pharmacy_id == pharmacy.id).scalar()
    db.commit()
    return {
        "pharmacy": {**_pharmacy_json(pharmacy), "wallet_phone": pharmacy.wallet_phone,
                     "wallet_verified": pharmacy.wallet_verified, "status": pharmacy.status,
                     "suspension_reason": pharmacy.suspension_reason,
                     "wallet_phone_pending": pharmacy.wallet_phone_pending,
                     "next_duty_on": pharmacy.next_duty_on.isoformat() if pharmacy.next_duty_on else None,
                     "temporarily_closed": pharmacy.temporarily_closed_at is not None},
        # Ce téléphone du comptoir : son rôle et sa sonnerie.
        "staff": {"role": staff.role if staff else None,
                  "ring_on_order": bool(staff.ring_on_order) if staff else True},
        "phones_count": phones_count,
        "visible": rules.pharmacy_accepts_orders(db, pharmacy),
        "subscription": {
            "plan": pharmacy.subscription_plan,
            "until": pharmacy.subscription_until.isoformat() if pharmacy.subscription_until else None,
            "prices_ht": {"WETRI": prices["WETRI"], "EPE": prices["EPE"]},
            "vat_rate": prices["vat_rate"],
        },
        "credit": {
            "balance_ht": pharmacy.credit_balance,
            "orders_left": pharmacy.credit_balance // rules.CREDIT_PER_ORDER,
            "exhausted_at": pharmacy.credit_exhausted_at.isoformat() if pharmacy.credit_exhausted_at else None,
        },
        "stats_month": {
            "received": sum(counts.values()),
            "paid": sum(counts.get(s, 0) for s in ("PAID", "READY", "IN_DELIVERY", "DELIVERED")),
            "delivered": counts.get("DELIVERED", 0),
            "rejected": counts.get("REJECTED", 0),
        },
    }


@router.get("/pharmacy/orders")
def pharmacy_orders(
    status: Optional[str] = None,
    current_user: dict = Depends(get_current_user), db: Session = Depends(get_db),
):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    query = db.query(HonamOrder).filter(HonamOrder.pharmacy_id == pharmacy.id)
    query = query.filter(HonamOrder.status == status.upper()) if status else query.filter(HonamOrder.status.in_(_PHARMACY_QUEUE + ("QUOTED",)))
    orders = query.order_by(HonamOrder.created_at).limit(200).all()
    expired = []
    for order in orders:
        previous_status = order.status
        rules.expire_quote_if_due(db, order)
        if order.status != previous_status:
            expired.append(order)
    db.commit()
    for order in expired:
        notify_order_state_changed(db, order, actor_id=None)
    return {"items": [_order_json(db, o, "pharmacy") for o in orders]}


@router.get("/pharmacy/orders/{order_id}")
def pharmacy_order(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/quote")
def send_quote(order_id: int, body: QuoteBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le devis. Le prix de la course est ajouté par HONAM, selon le pays
    (BM-09) : l'officine ne le fixe pas."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    items = [item.model_dump() for item in body.items]
    available = [i for i in items if i["available"]]
    if not available:
        raise HTTPException(status_code=422, detail="Aucun produit disponible : refusez plutôt l'ordonnance")
    order.quote_items = items
    order.medicines_total = sum(i["unit_price"] * i["quantity"] for i in available)
    order.delivery_price = rules.pharmacy_prices(db, pharmacy.country)["delivery_price"]
    order.original_required = body.original_required
    order.quote_expires_at = datetime.utcnow() + timedelta(hours=rules.QUOTE_TTL_HOURS)
    _move(db, order, "QUOTED", current_user["user_id"])
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/reject")
def reject_prescription(order_id: int, body: ReasonBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    order.rejection_reason = body.reason.strip()
    _move(db, order, "REJECTED", current_user["user_id"], body.reason.strip())
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/confirm-payment")
def confirm_patient_payment(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'officine a reçu l'argent sur son wallet : la commande est PAYÉE,
    le crédit officine est décompté et le code de remise naît."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    _move(db, order, "PAID", current_user["user_id"])
    order.delivery_code = rules.new_delivery_code()
    order.payment_not_received_at = None
    rules.charge_order_credit(db, pharmacy, order)
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/payment-not-received")
def payment_not_received(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "ACCEPTED":
        raise HTTPException(status_code=409, detail="Aucun paiement attendu")
    order.payment_not_received_at = datetime.utcnow()
    order.patient_paid_declared_at = None
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status="ACCEPTED",
                           note="Paiement non reçu par l'officine"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/ready")
def mark_ready(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.missing_amount is not None and order.missing_choice is None:
        raise HTTPException(status_code=409, detail="La patiente n'a pas encore choisi après le produit manquant")
    _move(db, order, "READY", current_user["user_id"])
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/missing-product")
def missing_product(order_id: int, body: RefundBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Un produit payé manque. Le manque se signale PENDANT LA PRÉPARATION,
    avant tout appel de coursier (maquette A1) ; la patiente choisit ensuite
    entre recevoir le reste et tout annuler. L'officine rembourse sous 2 h,
    sur le seul numéro qui a payé, sans quoi elle est suspendue (HON-35)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "PAID":
        raise HTTPException(status_code=409, detail="Le manque se signale pendant la préparation, avant le coursier")
    if order.missing_amount is not None:
        raise HTTPException(status_code=409, detail="Manque déjà signalé")
    if body.amount > (order.medicines_total or 0):
        raise HTTPException(status_code=422, detail="Le manquant dépasse le prix des médicaments")
    order.missing_amount = body.amount
    order.missing_reason = body.reason.strip()
    order.updated_at = datetime.utcnow()
    order.missing_reported_at = order.updated_at
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                           note=f"Produit manquant ({body.amount} FCFA) : choix de la patiente attendu"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/courier-default")
def report_courier_default(order_id: int, body: ReasonBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le coursier n'est pas venu, ou n'a pas livré : la commande revient à
    PRÊTE pour un autre coursier, et le défaut est compté (BM-05)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.courier_id is None or order.status not in ("READY", "IN_DELIVERY", "DELIVERED"):
        raise HTTPException(status_code=409, detail="Aucun coursier sur cette commande")
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == order.courier_id).first()
    suspended = rules.record_default(db, courier, order, body.reason) if courier else False
    if order.status == "DELIVERED":
        # Après la livraison (maquette 11 : retard, colis abîmé, original
        # non rapporté) : le défaut est compté, la commande ne bouge pas.
        db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                               note=f"Défaut du coursier : {body.reason}"))
        db.commit()
        return {"courier_suspended": suspended, "order": _order_json(db, order, "pharmacy")}
    state_changed = order.status == "IN_DELIVERY"
    if state_changed:
        _move(db, order, "READY", current_user["user_id"], f"Défaut du coursier : {body.reason}")
    order.courier_id = None
    db.commit()
    if state_changed:
        notify_order_state_changed(db, order, actor_id=current_user["user_id"])
    return {"courier_suspended": suspended, "order": _order_json(db, order, "pharmacy")}


# ── Recherche d'un coursier et retrait à l'officine (Officine 8, 9) ─────


def _searching_order(db: Session, order_id: int, pharmacy: Pharmacy) -> HonamOrder:
    """Une commande prête qui attend un coursier."""
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "READY" or order.courier_id is not None:
        raise HTTPException(status_code=409, detail="Un coursier a déjà accepté la course")
    if order.pickup_at_pharmacy:
        raise HTTPException(status_code=409, detail="La commande est retirée à l'officine")
    return order


def _relaunch(db: Session, order: HonamOrder, actor_id: int, note: str) -> None:
    order.dispatch_started_at = datetime.utcnow()
    order.dispatch_cancelled_at = None
    order.pickup_proposed_at = None
    db.add(HonamOrderEvent(order_id=order.id, actor_id=actor_id, status=order.status, note=note))


@router.post("/pharmacy/orders/{order_id}/dispatch/relaunch")
def relaunch_dispatch(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Relancer la recherche » (maquette Officine 9) : la course est
    proposée de nouveau, d'abord aux livreurs habituels, puis à la zone."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _searching_order(db, order_id, pharmacy)
    _relaunch(db, order, current_user["user_id"], "Recherche de coursier relancée")
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/dispatch/widen")
def widen_dispatch(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Élargir la zone à 8 km » : la recherche repart sur un rayon plus
    grand autour de l'officine."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _searching_order(db, order_id, pharmacy)
    if _dispatch_radius(order) >= rules.WIDE_DISPATCH_RADIUS_KM:
        raise HTTPException(status_code=409, detail="La zone est déjà élargie")
    order.dispatch_radius_km = rules.WIDE_DISPATCH_RADIUS_KM
    _relaunch(db, order, current_user["user_id"],
              f"Zone de recherche élargie à {rules.WIDE_DISPATCH_RADIUS_KM:g} km")
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/dispatch/cancel")
def cancel_dispatch(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Annuler la demande » (maquette Officine 8) : la course n'est plus
    proposée aux coursiers. La commande reste prête ; l'officine peut
    relancer la recherche ou proposer le retrait."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _searching_order(db, order_id, pharmacy)
    if order.dispatch_cancelled_at is not None:
        raise HTTPException(status_code=409, detail="La demande est déjà annulée")
    order.dispatch_cancelled_at = datetime.utcnow()
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                           note="Demande de coursier annulée"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/pickup/propose")
def propose_pickup(order_id: int, body: PickupProposeBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Proposer le retrait à l'officine » (maquette Officine 9) : la
    patiente est prévenue dans sa discussion avec l'officine, et la course
    n'est plus proposée aux coursiers pendant qu'elle répond."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _searching_order(db, order_id, pharmacy)
    now = datetime.utcnow()
    order.pickup_proposed_at = now
    order.dispatch_cancelled_at = now
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                           note="Retrait à l'officine proposé à la patiente"))
    message = None
    text = (body.message or "").strip()
    if text:
        message = HonamOrderMessage(
            order_id=order.id, sender_id=current_user["user_id"], sender_role="PHARMACY",
            channel=honam_channels.PATIENT, body=text,
        )
        db.add(message)
    db.commit()
    if message is not None:
        db.refresh(message)
        notify_order_message(db, order, message)
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/pickup/confirm")
def confirm_pickup(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """La patiente a accepté de venir : la commande passe en retrait à
    l'officine, et l'officine lui rembourse la course (2 h, sur le numéro
    qui a payé, comme tout remboursement)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _searching_order(db, order_id, pharmacy)
    if order.refund_sent_at is not None:
        raise HTTPException(status_code=409, detail="Un remboursement est déjà en cours sur cette commande")
    now = datetime.utcnow()
    order.pickup_at_pharmacy = True
    order.pickup_proposed_at = order.pickup_proposed_at or now
    order.dispatch_cancelled_at = order.dispatch_cancelled_at or now
    if order.delivery_price:
        order.refund_due = (order.refund_due or 0) + order.delivery_price
        order.refund_requested_at = order.refund_requested_at or now
        order.refund_reason = order.refund_reason or "Retrait à l'officine : course remboursée"
    order.updated_at = now
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                           note="Retrait à l'officine accepté ; course à rembourser"))
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/pickup/hand-over")
def hand_over_at_counter(order_id: int, body: CodeBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """La patiente retire sa commande au comptoir et donne son code de
    remise, comme elle l'aurait donné au coursier."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "READY" or not order.pickup_at_pharmacy:
        raise HTTPException(status_code=409, detail="Cette commande n'est pas en retrait à l'officine")
    if (order.code_attempts or 0) >= rules.MAX_CODE_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Trop d'essais : contactez le support Pokou")
    if body.code != order.delivery_code:
        order.code_attempts = (order.code_attempts or 0) + 1
        db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                               note=f"Code de remise refusé au comptoir (essai {order.code_attempts} sur {rules.MAX_CODE_ATTEMPTS})"))
        db.commit()
        raise HTTPException(status_code=422, detail="Code de remise incorrect")
    order.delivered_at = datetime.utcnow()
    _move(db, order, "DELIVERED", current_user["user_id"], "Retirée à l'officine")
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


class RefundSentBody(BaseModel):
    reference: Optional[str] = Field(None, max_length=40)


@router.post("/pharmacy/orders/{order_id}/handed-over")
def handed_over(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Colis remis à Kodjo » (maquette 4) : l'officine confirme la remise
    au coursier qui a accepté la course ; la livraison commence."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "READY" or order.courier_id is None:
        raise HTTPException(status_code=409, detail="Aucun coursier n'a encore accepté la course")
    _move(db, order, "IN_DELIVERY", current_user["user_id"], "Colis remis au coursier par l'officine")
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/courier-paid")
def pharmacy_paid_courier(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« J'ai payé Kodjo » (maquette 4b) : l'officine le déclare, le coursier
    le confirme ensuite de son côté (`courier_paid_at`)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.status != "DELIVERED":
        raise HTTPException(status_code=409, detail="Course non livrée")
    if order.courier_paid_declared_at is None:
        order.courier_paid_declared_at = datetime.utcnow()
        db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                               note="Course payée au coursier, selon l'officine"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/original-received")
def original_received(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Original reçu » (maquette 4c) : le coursier a rapporté l'ordonnance
    originale demandée au devis."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if not order.original_required or order.status != "DELIVERED":
        raise HTTPException(status_code=409, detail="Aucun original attendu")
    if order.original_returned_at is None:
        order.original_returned_at = datetime.utcnow()
        db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                               note="Ordonnance originale rapportée à l'officine"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/refund-sent")
def refund_sent(order_id: int, body: RefundSentBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« J'ai remboursé Afi » (maquette A2), avec la référence du transfert.
    Seule la confirmation de la patiente lève le délai de 2 h."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    if order.refund_due <= 0 or order.refund_confirmed_at is not None:
        raise HTTPException(status_code=409, detail="Aucun remboursement attendu")
    order.refund_sent_at = datetime.utcnow()
    order.refund_reference = (body.reference or "").strip() or None
    db.add(HonamOrderEvent(order_id=order.id, actor_id=current_user["user_id"], status=order.status,
                           note="Remboursement envoyé par l'officine"))
    db.commit()
    return _order_json(db, order, "pharmacy")


@router.post("/pharmacy/orders/{order_id}/cancel")
def pharmacy_cancel(order_id: int, body: ReasonBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'officine annule : paiement jamais reçu (maquette P2, rien à
    rembourser), ou commande payée qu'elle ne peut pas servir (A1 : tout est
    remboursé, sous 2 h, au seul numéro qui a payé)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    order = _pharmacy_order(db, order_id, pharmacy)
    reason = body.reason.strip()
    if order.status == "PAID":
        order.refund_due = (order.medicines_total or 0) + (order.delivery_price or 0)
        order.refund_requested_at = datetime.utcnow()
        order.refund_reason = reason
    elif order.status != "ACCEPTED":
        raise HTTPException(status_code=409, detail="Cette commande ne peut plus être annulée par l'officine")
    _move(db, order, "CANCELLED", current_user["user_id"], reason)
    _commit_order_change(db, order, current_user["user_id"])
    return _order_json(db, order, "pharmacy")


_CLOSED = ("DELIVERED", "REJECTED", "CANCELLED", "EXPIRED")


@router.get("/pharmacy/history")
def pharmacy_history(month: Optional[str] = None, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Historique d'un mois (maquette 12) : les commandes closes reçues ce
    mois-là, et ses chiffres. `month` au format AAAA-MM (défaut : en cours)."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    now = datetime.utcnow()
    try:
        year, mon = (int(p) for p in month.split("-")) if month else (now.year, now.month)
        start = datetime(year, mon, 1)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Mois invalide (AAAA-MM)") from exc
    end = datetime(year + (mon == 12), mon % 12 + 1, 1)
    orders = (
        db.query(HonamOrder)
        .filter(HonamOrder.pharmacy_id == pharmacy.id, HonamOrder.status.in_(_CLOSED),
                HonamOrder.created_at >= start, HonamOrder.created_at < end)
        .order_by(HonamOrder.created_at.desc())
        .limit(500)
        .all()
    )
    delivered = [o for o in orders if o.status == "DELIVERED"]
    return {
        "month": f"{year:04d}-{mon:02d}",
        "items": [_order_json(db, o, "pharmacy") for o in orders],
        "stats": {
            "delivered": len(delivered),
            "collected": sum((o.medicines_total or 0) + (o.delivery_price or 0) for o in delivered),
            "cancelled": len(orders) - len(delivered),
        },
    }


@router.post("/pharmacy/on-duty")
def set_on_duty(body: OnDutyBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    pharmacy.is_on_duty = body.on_duty
    db.commit()
    return _pharmacy_json(pharmacy)


# ── Compte de l'officine (Officine 13) ──────────────────────────────────


def _staff_row(db: Session, user_id: int) -> PharmacyStaff:
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.user_id == user_id).first()
    if staff is None:
        raise HTTPException(status_code=403, detail="Réservé à l'équipe d'une officine")
    return staff


def _titulaire(db: Session, user_id: int) -> PharmacyStaff:
    staff = _staff_row(db, user_id)
    if staff.role != "TITULAIRE":
        raise HTTPException(status_code=403, detail="Réservé au pharmacien titulaire")
    return staff


def _phones_json(db: Session, pharmacy: Pharmacy, viewer_id: int) -> list:
    """Les téléphones du comptoir : les comptes Pokou de l'équipe. Le
    numéro est masqué (« 90 •• •• 12 »), comme partout dans l'espace."""
    rows = (
        db.query(PharmacyStaff, User)
        .join(User, User.id == PharmacyStaff.user_id)
        .filter(PharmacyStaff.pharmacy_id == pharmacy.id)
        .order_by(PharmacyStaff.id)
        .all()
    )
    return [
        {
            "id": staff.id,
            "name": user.full_name,
            "phone_masked": _masked(user.phone),
            "role": staff.role,
            "me": staff.user_id == viewer_id,
        }
        for staff, user in rows
    ]


def _masked(phone: Optional[str]) -> Optional[str]:
    """« +22896 •• •• 12 », comme `officineMasked` dans l'application."""
    if not phone or len(phone) < 8:
        return None
    return f"{phone[:-6]} •• •• {phone[-2:]}"


@router.patch("/pharmacy/me")
def update_pharmacy(body: PharmacyUpdate, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Adresse, téléphone, horaires, prochaine garde, fermeture temporaire
    et sonnerie. Fermée, l'officine sort de l'annuaire et ne reçoit plus
    d'ordonnances (`rules.pharmacy_accepts_orders`)."""
    staff = _staff_row(db, current_user["user_id"])
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == staff.pharmacy_id).first()
    if body.address is not None:
        pharmacy.address = body.address.strip()
    if body.phone is not None:
        phone = normalize_e164(body.phone, pharmacy.country)
        if not phone:
            raise HTTPException(status_code=422, detail="Numéro invalide")
        pharmacy.phone = phone
    if body.opening_hours is not None:
        pharmacy.opening_hours = body.opening_hours.strip() or None
    if body.clear_next_duty:
        pharmacy.next_duty_on = None
    elif body.next_duty_on is not None:
        if body.next_duty_on < date.today():
            raise HTTPException(status_code=422, detail="La prochaine garde est à venir")
        pharmacy.next_duty_on = body.next_duty_on
    if body.temporarily_closed is not None:
        pharmacy.temporarily_closed_at = (
            (pharmacy.temporarily_closed_at or datetime.utcnow()) if body.temporarily_closed else None
        )
    if body.ring_on_order is not None:
        staff.ring_on_order = body.ring_on_order
    db.commit()
    return pharmacy_dashboard(current_user, db)


@router.post("/pharmacy/wallet")
def change_wallet(body: PhoneBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le titulaire demande un autre wallet de réception. L'ancien reçoit
    les paiements jusqu'à ce que l'équipe vérifie le nouveau (BM-02) : un
    wallet faux enverrait l'argent des patients ailleurs."""
    staff = _titulaire(db, current_user["user_id"])
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == staff.pharmacy_id).first()
    phone = normalize_e164(body.phone, pharmacy.country)
    if not phone:
        raise HTTPException(status_code=422, detail="Numéro invalide")
    if phone == pharmacy.wallet_phone:
        pharmacy.wallet_phone_pending = None
    else:
        pharmacy.wallet_phone_pending = phone
        rules.record_event(db, rules.EVENTS_TOPIC, "honam.pharmacy.wallet_change_requested",
                           {"pharmacy_id": pharmacy.id}, key=f"pharmacy-{pharmacy.id}")
    db.commit()
    return pharmacy_dashboard(current_user, db)


@router.get("/pharmacy/phones")
def counter_phones(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    return {"items": _phones_json(db, pharmacy, current_user["user_id"])}


@router.post("/pharmacy/phones", status_code=201)
def add_counter_phone(body: PhoneBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Un téléphone du comptoir de plus : le compte Pokou d'un collaborateur
    (« Téléphones du comptoir », maquette Officine 13)."""
    staff = _titulaire(db, current_user["user_id"])
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == staff.pharmacy_id).first()
    phone = normalize_e164(body.phone, pharmacy.country)
    user = db.query(User).filter(User.phone == phone).first() if phone else None
    if user is None:
        raise HTTPException(status_code=404, detail="Ce numéro n'a pas encore installé Pokou")
    existing = db.query(PharmacyStaff).filter(PharmacyStaff.user_id == user.id).first()
    if existing is not None:
        detail = "Ce téléphone est déjà au comptoir" if existing.pharmacy_id == pharmacy.id else "Ce numéro appartient à une autre officine"
        raise HTTPException(status_code=409, detail=detail)
    db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=user.id, role="COLLABORATEUR", added_at=datetime.utcnow()))
    db.commit()
    return {"items": _phones_json(db, pharmacy, current_user["user_id"])}


def _remove_staff(db: Session, staff: PharmacyStaff) -> None:
    """Le dernier titulaire ne part pas : l'officine resterait sans
    personne pour la gérer."""
    if staff.role == "TITULAIRE":
        others = db.query(PharmacyStaff.id).filter(
            PharmacyStaff.pharmacy_id == staff.pharmacy_id, PharmacyStaff.role == "TITULAIRE",
            PharmacyStaff.id != staff.id,
        ).first()
        if others is None:
            raise HTTPException(status_code=409, detail="Le titulaire ne peut pas retirer son propre téléphone")
    db.delete(staff)


@router.delete("/pharmacy/phones/me")
def leave_counter(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Se déconnecter de ce téléphone » : ce compte n'a plus accès à
    l'espace officine. Le reste de l'équipe continue."""
    staff = _staff_row(db, current_user["user_id"])
    _remove_staff(db, staff)
    db.commit()
    return {"ok": True}


@router.delete("/pharmacy/phones/{staff_id}")
def remove_counter_phone(staff_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _titulaire(db, current_user["user_id"])
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.id == staff_id, PharmacyStaff.pharmacy_id == me.pharmacy_id).first()
    if staff is None:
        raise HTTPException(status_code=404, detail="Téléphone introuvable")
    _remove_staff(db, staff)
    db.commit()
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == me.pharmacy_id).first()
    return {"items": _phones_json(db, pharmacy, current_user["user_id"])}


@router.post("/pharmacy/subscribe")
def pharmacy_subscribe(body: PlanBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    prices = rules.pharmacy_prices(db, pharmacy.country)
    price_ht = prices.get(body.plan)
    if body.plan not in ("WETRI", "EPE") or not price_ht:
        raise HTTPException(status_code=422, detail="Formule inconnue")
    payment = open_payment(
        db, current_user["user_id"], kind="HONAM_PHARMACY_SUB", amount=rules.ttc(price_ht, prices["vat_rate"]),
        description=f"{'Wétri' if body.plan == 'WETRI' else 'ÉPÉ'} HONAM — {pharmacy.name}",
        metadata={"pharmacy_id": pharmacy.id, "plan": body.plan, "price_ht": price_ht},
    )
    db.commit()
    return payment_json(payment)


@router.post("/pharmacy/credit")
def pharmacy_buy_credit(body: CreditBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    amount_ht = body.amount_ht - body.amount_ht % rules.CREDIT_PER_ORDER
    vat = rules.pharmacy_prices(db, pharmacy.country)["vat_rate"]
    payment = open_payment(
        db, current_user["user_id"], kind="HONAM_CREDIT", amount=rules.ttc(amount_ht, vat),
        description=f"Crédit HONAM — {amount_ht // rules.CREDIT_PER_ORDER} commandes",
        metadata={"pharmacy_id": pharmacy.id, "amount_ht": amount_ht},
    )
    db.commit()
    return payment_json(payment)


# ── Référencement d'une officine (maquettes Officine 14 à 16) ──────────


def _registration_json(db: Session, user: User, application: Optional[PharmacyApplication]) -> dict:
    """L'état du dossier et les prix de la formule (écran 2/3). L'arrêté
    lui-même ne repart jamais vers l'application."""
    country = application.country if application else (country_of_phone(user.phone) or "TG")
    prices = rules.pharmacy_prices(db, country)
    has_pharmacy = db.query(PharmacyStaff.id).filter(PharmacyStaff.user_id == user.id).first() is not None
    data = {
        "status": application.status if application else "NONE",
        "has_pharmacy": has_pharmacy,
        "prices_ht": {"WETRI": prices["WETRI"], "EPE": prices["EPE"]},
        "vat_rate": prices["vat_rate"],
        "review_hours": REGISTRATION_REVIEW_HOURS,
    }
    if application is None:
        return data
    return {
        **data,
        "name": application.name,
        "address": application.address,
        "license_number": application.license_number,
        "wallet_phone": application.wallet_phone,
        "has_authorization": application.authorization_media_id is not None,
        "plan": application.plan,
        "review_note": application.review_note,
        "submitted_at": application.submitted_at.isoformat(),
        "review_due_at": application.review_due_at.isoformat(),
        "reviewed_at": _iso(application.reviewed_at),
        "pharmacy_id": application.pharmacy_id,
    }


@router.get("/pharmacy/registration")
def pharmacy_registration(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Où en est le dossier : NONE (rien envoyé), PENDING (vérification en
    cours, écran 3/3), APPROVED (l'officine existe) ou REJECTED (motif)."""
    user = _user(db, current_user)
    application = db.query(PharmacyApplication).filter(PharmacyApplication.user_id == user.id).first()
    return _registration_json(db, user, application)


@router.post("/pharmacy/registration", status_code=201)
def submit_pharmacy_registration(
    body: PharmacyRegistrationBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db),
):
    """Envoyer (ou renvoyer, après un refus) le dossier. Rien n'est payé
    avant la vérification : la formule choisie se règle ensuite par CashPay
    depuis l'espace officine."""
    user = _user(db, current_user)
    if db.query(PharmacyStaff.id).filter(PharmacyStaff.user_id == user.id).first() is not None:
        raise HTTPException(status_code=409, detail="Ce compte appartient déjà à l'équipe d'une officine")
    country = country_of_phone(user.phone) or "TG"
    if not rules.pharmacy_prices(db, country).get(body.plan):
        raise HTTPException(status_code=409, detail="Honam n'accueille pas encore d'officine dans votre pays")
    application = db.query(PharmacyApplication).filter(PharmacyApplication.user_id == user.id).first()
    if application is not None and application.status in ("PENDING", "APPROVED"):
        raise HTTPException(status_code=409, detail="Un dossier est déjà en cours ou validé")
    wallet = normalize_e164(body.wallet_phone, country)
    if wallet is None:
        raise HTTPException(status_code=422, detail="Numéro de wallet invalide")
    authorization_id = _check_media(db, user, body.authorization_media_id) or (
        application.authorization_media_id if application is not None else None
    )
    if authorization_id is None:
        raise HTTPException(status_code=422, detail="L'autorisation d'ouverture est obligatoire")
    now = datetime.utcnow()
    if application is None:
        application = PharmacyApplication(user_id=user.id)
        db.add(application)
    application.country = country
    application.name = body.name.strip()
    application.address = body.address.strip()
    application.license_number = body.license_number.strip()
    application.wallet_phone = wallet
    application.authorization_media_id = authorization_id
    application.plan = body.plan
    application.latitude = body.latitude if body.latitude is not None else application.latitude
    application.longitude = body.longitude if body.longitude is not None else application.longitude
    application.status = "PENDING"
    application.review_note = None
    application.submitted_at = now
    application.review_due_at = now + timedelta(hours=REGISTRATION_REVIEW_HOURS)
    application.reviewed_at = None
    application.reviewer_id = None
    db.commit()
    return _registration_json(db, user, application)


# ── Coursier ────────────────────────────────────────────────────────────


def _courier_json(db: Session, courier: CourierProfile) -> dict:
    rules.refresh_courier_status(courier)
    country = courier.country
    vat = rules.pharmacy_prices(db, country)["vat_rate"]
    return {
        "status": courier.status,
        "launch_period": rules.launch_active(db, country),
        "queen_unlocked": rules.queen_unlocked(db, courier),
        "rides_left": rules.rides_left(db, courier),
        "unlimited": courier.current_pack == "QUEEN" and courier.status == "MEMBER",
        "trial_ends_at": courier.trial_ends_at.isoformat() if courier.trial_ends_at else None,
        "membership_until": courier.membership_until.isoformat() if courier.membership_until else None,
        "current_pack": courier.current_pack,
        "defaults_count": courier.defaults_count,
        "membership_price_ht": rules.COURIER_MEMBERSHIP_HT,
        "vat_rate": vat,
        "city": courier.city,
        "referral_code": courier.referral_code,
        "referral_gift_rides": rules.REFERRAL_GIFT_RIDES,
        "referrals_count": db.query(func.count(CourierProfile.id)).filter(CourierProfile.referred_by_id == courier.id).scalar() or 0,
        # Fin d'essai : un pack recommandé selon l'activité réelle.
        "recommended_pack": rules.recommended_pack(db, courier) if courier.status in ("TRIAL", "ENDED") else None,
        "packs": [
            {"code": code, "label": p["label"], "rides": None if p["rides"] == rules.UNLIMITED else p["rides"],
             "price_ht": rules.pack_price(country, code),
             "upgrade_price_ht": rules.upgrade_price(country, courier.current_pack, code)}
            for code, p in rules.PACKS.items()
        ],
        # ── Maquettes Coursiers 8, 17, 18, 20, 21, 26 ──
        "available": courier.available,
        "transport": courier.transport,
        "zones": courier.zones,
        "zones_list": courier.zones_list or [],
        "days": courier.days or [],
        "moments": courier.moments or [],
        "wallet_phone": courier.wallet_phone,
        "wallet_verified": courier.wallet_verified_at is not None,
        "id_doc_type": courier.id_doc_type,
        "has_selfie": courier.selfie_media_id is not None,
        "rules_accepted": courier.rules_accepted_at is not None,
        "incomplete_item": courier.incomplete_item if courier.status == "INCOMPLETE" else None,
        "incomplete_reason": courier.incomplete_reason if courier.status == "INCOMPLETE" else None,
        "applied_at": courier.created_at.isoformat(),
        "validated_at": courier.validated_at.isoformat() if courier.validated_at else None,
        "welcomed": courier.welcomed_at is not None,
        "trial_rides": rules.COURIER_TRIAL_RIDES,
        "pack_until": courier.pack_until.isoformat() if courier.pack_until else None,
        "pack_rides": _pack_rides(courier),
        "max_defaults": rules.MAX_COURIER_DEFAULTS,
        "suspended_at": courier.suspended_at.isoformat() if courier.suspended_at else None,
        "review_requested_at": courier.review_requested_at.isoformat() if courier.review_requested_at else None,
        "invited_by_pharmacy": _attached_pharmacy_name(db, courier),
        "month": _month_summary(db, courier),
        "originals_to_return": _originals_to_return(db, courier),
        "unacknowledged_default": _default_json(db, _last_unacknowledged_default(db, courier)),
    }


def _pack_rides(courier: CourierProfile) -> Optional[int]:
    """Le nombre de courses du pack en cours, pour la barre « 8 restantes
    sur 20 ». L'essai compte comme un pack de 5."""
    if courier.status == "TRIAL":
        return rules.COURIER_TRIAL_RIDES
    pack = rules.PACKS.get(courier.current_pack or "")
    if pack is None or pack["rides"] == rules.UNLIMITED:
        return None
    return pack["rides"]


def _attached_pharmacy_name(db: Session, courier: CourierProfile) -> Optional[str]:
    """« Invité par Pharmacie Démo » : la première officine qui a rattaché ce
    coursier à ses livreurs habituels (Officine 6)."""
    row = (
        db.query(Pharmacy.name)
        .join(PharmacyCourier, PharmacyCourier.pharmacy_id == Pharmacy.id)
        .filter(PharmacyCourier.courier_id == courier.id)
        .order_by(PharmacyCourier.added_at)
        .first()
    )
    return row[0] if row else None


def _month_bounds(month: Optional[str] = None) -> tuple[datetime, datetime]:
    now = datetime.utcnow()
    if month:
        try:
            start = datetime.strptime(month, "%Y-%m")
        except ValueError as exc:
            raise HTTPException(status_code=422, detail="Mois attendu au format AAAA-MM") from exc
    else:
        start = datetime(now.year, now.month, 1)
    end = datetime(start.year + (start.month == 12), start.month % 12 + 1, 1)
    return start, end


def _month_summary(db: Session, courier: CourierProfile, month: Optional[str] = None) -> dict:
    """Les courses LIVRÉES du mois et ce qu'elles rapportent : le prix de la
    course, que l'officine verse au coursier (BM-09). « Payées » : celles
    dont le coursier a confirmé le versement."""
    start, end = _month_bounds(month)
    rows = db.query(HonamOrder.delivery_price, HonamOrder.courier_paid_at).filter(
        HonamOrder.courier_id == courier.user_id,
        HonamOrder.status == "DELIVERED",
        HonamOrder.delivered_at >= start,
        HonamOrder.delivered_at < end,
    ).all()
    defaults = db.query(func.count(CourierDefault.id)).filter(
        CourierDefault.courier_id == courier.id,
        CourierDefault.status != "CANCELLED",
        CourierDefault.created_at >= start,
        CourierDefault.created_at < end,
    ).scalar() or 0
    return {
        "month": start.strftime("%Y-%m"),
        "rides": len(rows),
        "earnings": sum(price or 0 for price, _ in rows),
        "paid_rides": sum(1 for _, paid in rows if paid),
        "paid_earnings": sum(price or 0 for price, paid in rows if paid),
        "defaults": defaults,
    }


def _originals_to_return(db: Session, courier: CourierProfile) -> list:
    """Maquette Coursiers 8 : les ordonnances originales récupérées chez le
    patient et pas encore rendues à l'officine."""
    rows = db.query(HonamOrder).filter(
        HonamOrder.courier_id == courier.user_id,
        HonamOrder.original_required.is_(True),
        HonamOrder.original_collected_at.isnot(None),
        HonamOrder.original_returned_at.is_(None),
    ).order_by(HonamOrder.delivered_at).limit(10).all()
    items = []
    for order in rows:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
        due = (order.delivered_at or order.original_collected_at) + timedelta(hours=rules.ORIGINAL_RETURN_HOURS)
        items.append({"order_id": order.id, "pharmacy_name": pharmacy.name if pharmacy else None,
                      "due_at": due.isoformat()})
    return items


def _last_unacknowledged_default(db: Session, courier: CourierProfile) -> Optional[CourierDefault]:
    return (
        db.query(CourierDefault)
        .filter(CourierDefault.courier_id == courier.id, CourierDefault.acknowledged_at.is_(None))
        .order_by(CourierDefault.created_at.desc())
        .first()
    )


def _default_json(db: Session, default: Optional[CourierDefault]) -> Optional[dict]:
    if default is None:
        return None
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == default.pharmacy_id).first() if default.pharmacy_id else None
    order = db.query(HonamOrder).filter(HonamOrder.id == default.order_id).first() if default.order_id else None
    return {
        "id": default.id,
        "reason": default.reason,
        "status": default.status,
        "pharmacy_name": pharmacy.name if pharmacy else None,
        "order_date": order.created_at.isoformat() if order else None,
        "created_at": default.created_at.isoformat(),
        "contest_until": default.contest_until.isoformat(),
        "can_contest": default.status == "CONFIRMED" and default.contest_until > datetime.utcnow(),
        "contested_at": default.contested_at.isoformat() if default.contested_at else None,
    }


def _check_media(db: Session, user: User, media_id: Optional[int]) -> Optional[int]:
    """Une pièce ou un selfie : un média que la personne a elle-même envoyé."""
    from app.models import MediaAsset

    if media_id is None:
        return None
    media = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
    if media is None or media.uploader_id != user.id:
        raise HTTPException(status_code=422, detail="Photo introuvable")
    return media_id


@router.post("/courier/join")
def courier_join(body: CourierApplication, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """La candidature (maquettes Coursiers 2 à 7) : zones et créneaux, wallet,
    règles d'or. Elle attend la validation de l'équipe ; l'essai de 5 courses
    commence à la validation."""
    user = _user(db, current_user)
    if not body.accept_rules:
        raise HTTPException(status_code=422, detail="Les règles d'or doivent être acceptées")
    country = country_of_phone(user.phone) or "TG"
    if body.city and not rules.city_served(db, country, body.city):
        raise HTTPException(status_code=409, detail={
            "code": "waitlist",
            "message": "Honam ne livre pas encore dans cette ville : inscrivez-vous sur la liste d'attente",
        })
    if body.birth_date and rules.courier_age(body.birth_date) < rules.MIN_COURIER_AGE:
        raise HTTPException(status_code=422, detail="Le mode coursier est réservé aux 18 ans et plus")
    zones_list = [z.strip()[:60] for z in (body.zones_list or []) if z and z.strip()]
    zones = (body.zones or "").strip() or ", ".join(zones_list)
    if len(zones) < 2:
        raise HTTPException(status_code=422, detail="Indiquez au moins un quartier")
    wallet = normalize_e164(body.wallet_phone, country)
    if wallet is None:
        raise HTTPException(status_code=422, detail="Numéro de wallet invalide")
    # Le wallet vérifié par SMS pendant l'inscription (maquette Coursiers 5).
    wallet_checked = db.query(CourierWalletCheck.id).filter(
        CourierWalletCheck.user_id == user.id, CourierWalletCheck.phone == wallet,
        CourierWalletCheck.verified_at > datetime.utcnow() - timedelta(days=1),
    ).first() is not None
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user.id).first()
    if courier is None:
        courier = CourierProfile(user_id=user.id, country=country, status="PENDING")
        db.add(courier)
    if courier.status == "PENDING":
        courier.zones = zones[:255]
        courier.city = (body.city or "").strip() or courier.city
        courier.wallet_phone = wallet
        courier.wallet_verified_at = datetime.utcnow() if wallet_checked else None
        courier.rules_accepted_at = datetime.utcnow()
        courier.quiz_passed_at = datetime.utcnow() if body.quiz_passed else courier.quiz_passed_at
        courier.zones_list = zones_list or courier.zones_list
        courier.days = [d for d in (body.days or []) if d in _DAYS] or courier.days
        courier.moments = [m for m in (body.moments or []) if m in _MOMENTS] or courier.moments
        courier.birth_date = body.birth_date or courier.birth_date
        courier.transport = body.transport or courier.transport
        courier.id_doc_type = body.id_doc_type or courier.id_doc_type
        courier.id_front_media_id = _check_media(db, user, body.id_front_media_id) or courier.id_front_media_id
        courier.id_back_media_id = _check_media(db, user, body.id_back_media_id) or courier.id_back_media_id
        courier.selfie_media_id = _check_media(db, user, body.selfie_media_id) or courier.selfie_media_id
        if body.referral_code and courier.referred_by_id is None:
            referrer = db.query(CourierProfile).filter(
                CourierProfile.referral_code == body.referral_code.strip().upper()
            ).first()
            if referrer is None or referrer.user_id == user.id:
                raise HTTPException(status_code=422, detail="Code de parrainage inconnu")
            db.flush()
            courier.referred_by_id = referrer.id
    db.commit()
    return _courier_json(db, courier)


@router.get("/courier/me")
def courier_me(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    courier = _courier(db, user)
    data = _courier_json(db, courier)
    db.commit()
    return data


@router.get("/courier/offer")
def courier_offer(code: Optional[str] = None, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'offre « Livre pour Honam » (maquettes Coursiers 1 et 25) : ce qu'une
    course rapporte et ce que le mode coursier coûte, dans le pays de la
    personne. Avec `code`, le parrain qui l'invite."""
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    country = country_of_phone(user.phone if user else None) or "TG"
    prices = rules.pharmacy_prices(db, country)
    # Un pays sans tarif Honam (numéro étranger, pays pas encore lancé) :
    # l'offre est celle du marché de lancement. Sans ce repli, l'écran
    # disait « Tu gagnes 0 FCFA par course » et l'estimation était fausse.
    if not prices.get("delivery_price"):
        country = "TG"
        prices = rules.pharmacy_prices(db, country)
    vat = prices["vat_rate"]
    inviter = None
    if code:
        referrer = db.query(CourierProfile).filter(CourierProfile.referral_code == code.strip().upper()).first()
        if referrer is not None and referrer.status not in ("SUSPENDED", "REJECTED") and referrer.user_id != current_user["user_id"]:
            inviter = {"name": _name(db, referrer.user_id), "code": referrer.referral_code,
                       "verified": referrer.validated_at is not None}
    dismissed = db.query(CourierOfferDismissal.id).filter(
        CourierOfferDismissal.user_id == current_user["user_id"]
    ).first() is not None
    return {
        "country": country,
        "honam_open": bool(user and module_open(db, user.phone, "honam")),
        "served_cities": rules.served_cities(db, country),
        "delivery_price": prices["delivery_price"],
        "launch_period": rules.launch_active(db, country),
        "trial_rides": rules.COURIER_TRIAL_RIDES,
        "membership_price_ht": rules.COURIER_MEMBERSHIP_HT,
        "membership_price_ttc": rules.ttc(rules.COURIER_MEMBERSHIP_HT, vat),
        "vat_rate": vat,
        "referral_gift_rides": rules.REFERRAL_GIFT_RIDES,
        "min_age": rules.MIN_COURIER_AGE,
        "transports": {code: t["range_km"] for code, t in rules.TRANSPORTS.items()},
        "packs": [
            {"code": code, "label": p["label"], "rides": None if p["rides"] == rules.UNLIMITED else p["rides"],
             "price_ht": rules.pack_price(country, code), "price_ttc": rules.ttc(rules.pack_price(country, code), vat)}
            for code, p in rules.PACKS.items()
        ],
        "inviter": inviter,
        "dismissed": dismissed,
    }


@router.post("/courier/offer/dismiss")
def dismiss_courier_offer(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Ne plus me proposer » (maquette Coursiers 0) : l'encart après une
    livraison et le bandeau de l'onglet ne reviennent plus."""
    if db.query(CourierOfferDismissal.id).filter(CourierOfferDismissal.user_id == current_user["user_id"]).first() is None:
        db.add(CourierOfferDismissal(user_id=current_user["user_id"]))
        db.commit()
    return {"dismissed": True}


@router.post("/courier/wallet/send-code")
def courier_wallet_send_code(body: WalletCodeBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Maquette Coursiers 5 : un code par SMS prouve que le wallet est bien
    celui de la personne. Les mêmes limites que le code de connexion."""
    from app.services.auth import otp_service

    user = _user(db, current_user)
    wallet = normalize_e164(body.wallet_phone, country_of_phone(user.phone) or "TG")
    if wallet is None:
        raise HTTPException(status_code=422, detail="Numéro de wallet invalide")
    try:
        ttl = otp_service.generate_and_send_otp(db, wallet, channel="sms")
    except otp_service.OTPError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    return {"wallet_phone": wallet, "expires_in": ttl}


@router.post("/courier/wallet/verify")
def courier_wallet_verify(body: WalletVerifyBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    from app.services.auth import otp_service

    user = _user(db, current_user)
    wallet = normalize_e164(body.wallet_phone, country_of_phone(user.phone) or "TG")
    if wallet is None:
        raise HTTPException(status_code=422, detail="Numéro de wallet invalide")
    try:
        otp_service.consume_otp(db, wallet, body.code.strip())
    except otp_service.OTPError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    db.add(CourierWalletCheck(user_id=user.id, phone=wallet))
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user.id).first()
    if courier is not None and courier.wallet_phone == wallet:
        courier.wallet_verified_at = datetime.utcnow()
    db.commit()
    return {"wallet_phone": wallet, "verified": True}


@router.post("/courier/identity")
def courier_identity(body: IdentityBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Candidature à compléter (maquette Coursiers 18) : la pièce reprise,
    la candidature repart en vérification."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    if courier.status not in ("INCOMPLETE", "PENDING"):
        raise HTTPException(status_code=409, detail="Aucune pièce à reprendre")
    courier.selfie_media_id = _check_media(db, user, body.selfie_media_id) or courier.selfie_media_id
    courier.id_front_media_id = _check_media(db, user, body.id_front_media_id) or courier.id_front_media_id
    courier.id_back_media_id = _check_media(db, user, body.id_back_media_id) or courier.id_back_media_id
    courier.status = "PENDING"
    courier.incomplete_item = None
    courier.incomplete_reason = None
    db.commit()
    return _courier_json(db, courier)


@router.post("/courier/availability")
def courier_availability(body: AvailabilityBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le bouton marche/arrêt (maquettes Coursiers 8 et 26)."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    if body.available and rules.refresh_courier_status(courier) in ("PENDING", "INCOMPLETE", "REJECTED", "SUSPENDED"):
        raise HTTPException(status_code=409, detail="Le mode coursier n'est pas actif")
    courier.available = body.available
    if not body.available:
        # À l'arrêt, plus de position gardée.
        courier.latitude = courier.longitude = courier.located_at = None
    data = _courier_json(db, courier)
    db.commit()
    return data


@router.post("/courier/welcomed")
def courier_welcomed(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Bienvenue chez les coursiers » vu (maquette Coursiers 17)."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    courier.welcomed_at = courier.welcomed_at or datetime.utcnow()
    data = _courier_json(db, courier)
    db.commit()
    return data


@router.get("/courier/earnings")
def courier_earnings(month: Optional[str] = None, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Mes courses et gains » (maquette Coursiers 22) : un mois, ses
    courses livrées, payées ou en attente de versement par l'officine."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    start, end = _month_bounds(month)
    orders = db.query(HonamOrder).filter(
        HonamOrder.courier_id == user.id, HonamOrder.status == "DELIVERED",
        HonamOrder.delivered_at >= start, HonamOrder.delivered_at < end,
    ).order_by(HonamOrder.delivered_at.desc()).limit(200).all()
    first = db.query(func.min(HonamOrder.delivered_at)).filter(
        HonamOrder.courier_id == user.id, HonamOrder.status == "DELIVERED",
    ).scalar()
    months = []
    cursor = datetime(datetime.utcnow().year, datetime.utcnow().month, 1)
    floor = datetime(first.year, first.month, 1) if first else cursor
    while cursor >= floor and len(months) < 12:
        months.append(cursor.strftime("%Y-%m"))
        cursor = datetime(cursor.year - (cursor.month == 1), (cursor.month - 2) % 12 + 1, 1)
    items = []
    for order in orders:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
        items.append({
            "order_id": order.id,
            "pharmacy_name": pharmacy.name if pharmacy else None,
            "delivery_address": order.delivery_address,
            "delivered_at": order.delivered_at.isoformat(),
            "amount": order.delivery_price or 0,
            "paid": order.courier_paid_at is not None,
        })
    rules.refresh_courier_status(courier)
    db.commit()
    return {
        **_month_summary(db, courier, start.strftime("%Y-%m")),
        "months": months,
        "max_defaults": rules.MAX_COURIER_DEFAULTS,
        "wallet_phone": courier.wallet_phone,
        "current_pack": courier.current_pack if courier.status == "MEMBER" else ("TRIAL" if courier.status == "TRIAL" else None),
        "rides_left": rules.rides_left(db, courier),
        "pack_rides": _pack_rides(courier),
        "items": items,
    }


@router.get("/courier/defaults")
def courier_defaults(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Les défauts du coursier, datés (maquettes Coursiers 20 et 21)."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    rows = db.query(CourierDefault).filter(CourierDefault.courier_id == courier.id).order_by(CourierDefault.created_at).all()
    return {"items": [_default_json(db, d) for d in rows], "max_defaults": rules.MAX_COURIER_DEFAULTS}


def _my_default(db: Session, user: User, default_id: int) -> CourierDefault:
    courier = _courier(db, user)
    default = db.query(CourierDefault).filter(
        CourierDefault.id == default_id, CourierDefault.courier_id == courier.id
    ).first()
    if default is None:
        raise HTTPException(status_code=404, detail="Défaut introuvable")
    return default


@router.post("/courier/defaults/{default_id}/acknowledge")
def acknowledge_default(default_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« J'ai compris » (maquette Coursiers 20)."""
    user = _user(db, current_user)
    default = _my_default(db, user, default_id)
    default.acknowledged_at = default.acknowledged_at or datetime.utcnow()
    db.commit()
    return _default_json(db, default)


@router.post("/courier/defaults/{default_id}/contest")
def contest_default(default_id: int, body: ContestBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Contester ce défaut » : le support compare l'heure de retrait, la
    position pendant la course et les appels passés par Pokou."""
    user = _user(db, current_user)
    default = _my_default(db, user, default_id)
    if default.status != "CONFIRMED" or default.contest_until < datetime.utcnow():
        raise HTTPException(status_code=409, detail="Ce défaut ne se conteste plus")
    default.status = "CONTESTED"
    default.contested_at = datetime.utcnow()
    default.contest_note = (body.note or "").strip() or None
    default.acknowledged_at = default.acknowledged_at or default.contested_at
    rules.record_event(db, rules.EVENTS_TOPIC, "honam.courier.default_contested",
                       {"courier_user_id": user.id, "default_id": default.id}, key=f"courier-{user.id}")
    db.commit()
    return _default_json(db, default)


@router.post("/courier/review-request")
def courier_review_request(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Demander un réexamen » (maquette Coursiers 21)."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    if courier.status != "SUSPENDED":
        raise HTTPException(status_code=409, detail="Ce compte coursier n'est pas suspendu")
    courier.review_requested_at = courier.review_requested_at or datetime.utcnow()
    rules.record_event(db, rules.EVENTS_TOPIC, "honam.courier.review_requested",
                       {"courier_user_id": user.id}, key=f"courier-{user.id}")
    data = _courier_json(db, courier)
    db.commit()
    return data


@router.get("/courier/referrals")
def courier_referrals(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Tes filleuls » (maquette Coursiers 15) : où en est chacun, et les
    courses offertes qu'il a rapportées."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    rows = db.query(CourierProfile).filter(CourierProfile.referred_by_id == courier.id).order_by(CourierProfile.created_at.desc()).all()
    items = []
    for friend in rows:
        if friend.referral_rewarded_at is not None:
            state = "FIRST_DELIVERY"
        elif friend.status in ("PENDING", "INCOMPLETE"):
            state = "APPLYING"
        elif friend.status == "REJECTED":
            state = "DECLINED"
        else:
            state = "ACTIVE"
        items.append({
            "name": _name(db, friend.user_id),
            "state": state,
            "gift_rides": rules.REFERRAL_GIFT_RIDES if friend.referral_rewarded_at else None,
        })
    return {"code": courier.referral_code, "gift_rides": rules.REFERRAL_GIFT_RIDES, "items": items}


@router.get("/courier/rides")
def available_rides(
    lat: Optional[float] = Query(None, ge=-90, le=90),
    lng: Optional[float] = Query(None, ge=-180, le=180),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _user(db, current_user)
    courier = _courier(db, user)
    now = datetime.utcnow()
    if lat is not None and lng is not None and courier.available:
        # La position du coursier disponible : une seule, écrasée.
        courier.latitude, courier.longitude, courier.located_at = lat, lng, now
        db.commit()
    pharmacy_ids = db.query(Pharmacy.id).filter(Pharmacy.country == courier.country)
    # Une recherche annulée par l'officine, ou une commande passée en
    # retrait à l'officine, n'est plus proposée.
    open_rides = db.query(HonamOrder).filter(
        HonamOrder.status == "READY", HonamOrder.courier_id.is_(None), HonamOrder.pharmacy_id.in_(pharmacy_ids),
        HonamOrder.dispatch_cancelled_at.is_(None), HonamOrder.pickup_at_pharmacy.is_(False),
    ).order_by(HonamOrder.updated_at).limit(100).all()
    # Le rayon de chaque recherche autour de l'officine (5 km, 8 km si
    # l'officine a élargi la zone).
    pharmacies = {
        p.id: p for p in db.query(Pharmacy).filter(Pharmacy.id.in_({o.pharmacy_id for o in open_rides} or {0}))
    }
    open_rides = [
        o for o in open_rides
        if o.pharmacy_id in pharmacies and _within_radius(courier, pharmacies[o.pharmacy_id], _dispatch_radius(o), now)
    ]
    # Les livreurs habituels d'une officine voient ses courses en premier
    # (Officine 6) ; les autres coursiers, passé ce délai.
    attached_to = {
        row[0] for row in db.query(PharmacyCourier.pharmacy_id).filter(PharmacyCourier.courier_id == courier.id)
    }
    with_attached = {
        row[0] for row in db.query(PharmacyCourier.pharmacy_id).filter(
            PharmacyCourier.pharmacy_id.in_({o.pharmacy_id for o in open_rides} or {0})
        )
    }
    priority_cutoff = now - timedelta(minutes=rules.ATTACHED_PRIORITY_MINUTES)
    # L'avance des livreurs habituels repart de zéro à chaque relance.
    open_rides = [
        o for o in open_rides
        if o.pharmacy_id in attached_to or o.pharmacy_id not in with_attached
        or (o.dispatch_started_at or o.updated_at) < priority_cutoff
    ][:50]
    open_rides.sort(key=lambda o: (o.pharmacy_id not in attached_to, o.updated_at))
    mine = db.query(HonamOrder).filter(
        HonamOrder.courier_id == user.id, HonamOrder.status.in_(("READY", "IN_DELIVERY", "DELIVERED")),
    ).order_by(HonamOrder.updated_at.desc()).limit(50).all()
    return {
        # « Proposée d'abord à toi » (maquette Coursiers 9) : la course d'une
        # officine qui a rattaché ce coursier à ses livreurs habituels.
        "available": [
            {**_order_json(db, o, "courier"), "priority": o.pharmacy_id in attached_to} for o in open_rides
        ],
        "mine": [_order_json(db, o, "courier") for o in mine],
    }


def _courier_order(db: Session, order_id: int, user_id: int) -> HonamOrder:
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id, HonamOrder.courier_id == user_id).first()
    if order is None:
        raise HTTPException(status_code=404, detail="Course introuvable")
    return order


@router.post("/courier/rides/{order_id}/accept")
def accept_ride(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    courier = _courier(db, user)
    allowed, reason = rules.courier_can_accept(db, courier)
    if not allowed:
        raise HTTPException(status_code=402, detail=reason)
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id).with_for_update().first()
    if order is None or order.status != "READY" or order.courier_id is not None:
        raise HTTPException(status_code=409, detail="Course déjà prise")
    if order.dispatch_cancelled_at is not None or order.pickup_at_pharmacy:
        raise HTTPException(status_code=409, detail="L'officine a retiré cette course")
    order.courier_id = user.id
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status="READY", note="Coursier en route vers l'officine"))
    db.commit()
    return _order_json(db, order, "courier")


@router.post("/courier/rides/{order_id}/pickup")
def pickup_ride(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _courier_order(db, order_id, user.id)
    _move(db, order, "IN_DELIVERY", user.id)
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "courier")


@router.post("/courier/rides/{order_id}/deliver")
def deliver_ride(order_id: int, body: DeliverBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """La remise : le patient donne son code. C'est le seul moment où la
    course est décomptée du pack (BM-04)."""
    user = _user(db, current_user)
    courier = _courier(db, user)
    order = _courier_order(db, order_id, user.id)
    if order.status != "IN_DELIVERY":
        raise HTTPException(status_code=409, detail="Course pas encore récupérée")
    # 5 essais au plus, chacun enregistré (maquette Coursiers 11).
    if (order.code_attempts or 0) >= rules.MAX_CODE_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Trop d'essais : contacte l'officine")
    if body.code != order.delivery_code:
        order.code_attempts = (order.code_attempts or 0) + 1
        db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status=order.status,
                               note=f"Code de remise refusé (essai {order.code_attempts} sur {rules.MAX_CODE_ATTEMPTS})"))
        db.commit()
        raise HTTPException(status_code=422, detail="Code de remise incorrect")
    if order.original_required:
        order.original_collected_at = datetime.utcnow()
    order.delivered_at = datetime.utcnow()
    # La position n'est jamais conservée après la livraison.
    order.courier_latitude = order.courier_longitude = order.courier_location_at = None
    _move(db, order, "DELIVERED", user.id)
    rules.record_ride(db, courier, order)
    rules.reward_referrer(db, courier)
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "courier")


@router.post("/courier/rides/{order_id}/incident")
def ride_incident(order_id: int, body: IncidentBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Un problème pendant la course ? » (maquette Coursiers 19).

    - NO_ANSWER : le patient ne répond pas. Pokou le prévient ; au bout de
      10 minutes, le coursier peut rapporter le colis (voir `return`).
    - ADDRESS : adresse introuvable. Le patient est prévenu et peut guider
      le coursier par message.
    - CODE : le code est refusé. Rien ne change : le coursier vérifie avec
      le patient et réessaie.
    - ACCIDENT : accident ou panne. La course est rendue à l'officine, qui la
      réattribue ; ce n'est pas un défaut.
    """
    from app.services.notifications.inbox import notify

    user = _user(db, current_user)
    order = _courier_order(db, order_id, user.id)
    if order.status not in _TRACKABLE:
        raise HTTPException(status_code=409, detail="Aucune course en cours")
    now = datetime.utcnow()
    order.incident_kind = body.kind
    order.incident_at = now
    notes = {
        "NO_ANSWER": "Le coursier n'arrive pas à joindre le patient",
        "ADDRESS": "Le coursier ne trouve pas l'adresse",
        "CODE": "Le code de remise est refusé",
        "ACCIDENT": "Accident ou panne du coursier : course à réattribuer",
    }
    if body.kind == "ACCIDENT":
        if order.status == "IN_DELIVERY":
            _move(db, order, "READY", user.id, notes["ACCIDENT"])
        else:
            db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status=order.status, note=notes["ACCIDENT"]))
        order.courier_id = None
        order.courier_latitude = order.courier_longitude = order.courier_location_at = None
        _commit_order_change(db, order, user.id)
        return _order_json(db, order, "courier")
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status=order.status, note=notes[body.kind]))
    if body.kind in ("NO_ANSWER", "ADDRESS"):
        message = (
            "Ton coursier est devant chez toi et n'arrive pas à te joindre : réponds-lui vite."
            if body.kind == "NO_ANSWER" else
            "Ton coursier ne trouve pas ton adresse : guide-le par message depuis ta commande."
        )
        notify(db, [order.patient_id], service="honam", title="Ta commande Honam", body=message)
    db.commit()
    return _order_json(db, order, "courier")


@router.post("/courier/rides/{order_id}/return")
def ride_return(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Rapporter le colis à l'officine » : après 10 minutes sans réponse
    du patient, le colis revient fermé à l'officine. Ce n'est pas un défaut
    du coursier, et la course n'est pas décomptée."""
    user = _user(db, current_user)
    order = _courier_order(db, order_id, user.id)
    if order.status != "IN_DELIVERY" or order.incident_kind != "NO_ANSWER" or order.incident_at is None:
        raise HTTPException(status_code=409, detail="Signale d'abord que le patient ne répond pas")
    waited = datetime.utcnow() - order.incident_at
    if waited < timedelta(minutes=rules.NO_ANSWER_WAIT_MINUTES):
        raise HTTPException(status_code=409, detail="Attends encore le patient")
    _move(db, order, "READY", user.id, "Patient injoignable : colis rapporté fermé à l'officine")
    order.courier_id = None
    order.courier_latitude = order.courier_longitude = order.courier_location_at = None
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "courier")


@router.post("/courier/rides/{order_id}/paid")
def courier_paid(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le coursier confirme que l'officine lui a versé le prix de la course."""
    user = _user(db, current_user)
    order = _courier_order(db, order_id, user.id)
    if order.status != "DELIVERED":
        raise HTTPException(status_code=409, detail="Course non livrée")
    order.courier_paid_at = datetime.utcnow()
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
    rules.refresh_pharmacy_status(db, pharmacy)
    db.commit()
    return _order_json(db, order, "courier")


@router.post("/courier/membership")
def courier_membership(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    courier = _courier(db, user)
    vat = rules.pharmacy_prices(db, courier.country)["vat_rate"]
    payment = open_payment(
        db, user.id, kind="HONAM_COURIER_MEMBERSHIP", amount=rules.ttc(rules.COURIER_MEMBERSHIP_HT, vat),
        description="Adhésion Win Pokou — 1 mois", metadata={"courier_id": courier.id},
    )
    db.commit()
    return payment_json(payment)


@router.post("/courier/pack")
def courier_pack(body: PackBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    courier = _courier(db, user)
    if body.pack not in rules.PACKS:
        raise HTTPException(status_code=422, detail="Pack inconnu")
    if courier.status != "MEMBER":
        raise HTTPException(status_code=402, detail="Adhésion Win Pokou nécessaire")
    vat = rules.pharmacy_prices(db, courier.country)["vat_rate"]
    pack_active = courier.pack_until and courier.pack_until > datetime.utcnow()
    current = courier.current_pack if pack_active else None
    if current and rules.PACK_ORDER.index(body.pack) <= rules.PACK_ORDER.index(current):
        raise HTTPException(status_code=409, detail="Les packs ne se cumulent pas : choisissez un pack supérieur")
    if body.pack == "QUEEN" and not rules.queen_unlocked(db, courier):
        raise HTTPException(status_code=403, detail="Queen Pokou se débloque après un mois sans défaut de livraison")
    price_ht = rules.upgrade_price(courier.country, current, body.pack)
    payment = open_payment(
        db, user.id, kind="HONAM_COURIER_PACK", amount=rules.ttc(price_ht, vat),
        description=f"Pack {rules.PACKS[body.pack]['label']}",
        metadata={"courier_id": courier.id, "pack": body.pack, "upgrade_from": current},
    )
    db.commit()
    return payment_json(payment)


# ── Suivi de la course ──────────────────────────────────────────────────


@router.post("/courier/rides/{order_id}/location")
def courier_location(order_id: int, body: LocationBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Envoyée toutes les 15 s par le téléphone du coursier. Une seule
    position est gardée, écrasée à chaque envoi et effacée à la remise."""
    user = _user(db, current_user)
    order = _courier_order(db, order_id, user.id)
    if order.status not in _TRACKABLE:
        raise HTTPException(status_code=409, detail="Le suivi s'arrête à la livraison")
    order.courier_latitude = body.latitude
    order.courier_longitude = body.longitude
    order.courier_location_at = datetime.utcnow()
    db.commit()
    return {"ok": True}


def _tracking_json(order: HonamOrder, db: Session) -> dict:
    active = order.status in _TRACKABLE and order.courier_id is not None
    at = order.courier_location_at if active else None
    data = {
        "order_id": order.id,
        "status": order.status,
        "active": active,
        "courier_name": _name(db, order.courier_id),
        "latitude": order.courier_latitude if at else None,
        "longitude": order.courier_longitude if at else None,
        "at": at.isoformat() if at else None,
        "stale": bool(at and (datetime.utcnow() - at).total_seconds() > rules.LOCATION_STALE_SECONDS),
        "refresh_seconds": 15,
        "distance_km": None,
        "eta_minutes": None,
        # Les deux bouts du trajet, pour la carte (maquette « Suivi sur la
        # carte ») : l'officine, publique, et l'adresse que le patient a
        # lui-même donnée.
        "pharmacy_latitude": None,
        "pharmacy_longitude": None,
        "delivery_latitude": order.delivery_latitude if active else None,
        "delivery_longitude": order.delivery_longitude if active else None,
        "courier_user_id": order.courier_id if active else None,
        "courier_transport": None,
        "courier_verified": False,
        "picked_up": order.status == "IN_DELIVERY",
    }
    if active:
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == order.pharmacy_id).first()
        courier = _courier_profile_of(db, order.courier_id)
        if pharmacy is not None:
            data["pharmacy_latitude"] = pharmacy.latitude
            data["pharmacy_longitude"] = pharmacy.longitude
        if courier is not None:
            data["courier_transport"] = courier.transport
            data["courier_verified"] = courier.validated_at is not None
    if at and order.delivery_latitude is not None and order.delivery_longitude is not None:
        data["distance_km"] = round(rules.distance_km(
            order.courier_latitude, order.courier_longitude, order.delivery_latitude, order.delivery_longitude,
        ), 2)
        # Avant le retrait, le coursier va d'abord à l'officine : pas d'heure.
        if order.status == "IN_DELIVERY":
            data["eta_minutes"] = rules.eta_minutes(data["distance_km"], data["courier_transport"])
    return data


@router.get("/orders/{order_id}/tracking")
def patient_tracking(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« Suivi sur la carte » et « Suivi sans carte » lisent la même chose :
    c'est l'application qui choisit d'afficher une carte, à la demande."""
    user = _user(db, current_user)
    return _tracking_json(_patient_order(db, order_id, user.id), db)


@router.get("/pharmacy/orders/{order_id}/tracking")
def pharmacy_tracking(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Officine 7 : l'officine suit la livraison qu'elle a confiée."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    return _tracking_json(_pharmacy_order(db, order_id, pharmacy), db)


# ── Villes desservies et liste d'attente ────────────────────────────────


@router.get("/cities")
def cities(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Lisible même là où Honam n'est pas ouvert : c'est ce qui permet de
    proposer la liste d'attente au lieu de l'offre."""
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    country = country_of_phone(user.phone if user else None)
    entry = db.query(HonamWaitlistEntry).filter(HonamWaitlistEntry.user_id == current_user["user_id"]).first()
    dismissed = db.query(CourierOfferDismissal.id).filter(
        CourierOfferDismissal.user_id == current_user["user_id"]
    ).first() is not None
    return {
        "country": country,
        "honam_open": bool(user and module_open(db, user.phone, "honam")),
        "served_cities": rules.served_cities(db, country),
        "waitlist": {"city": entry.city, "role": entry.role, "since": entry.created_at.isoformat(),
                     "count": _waitlist_count(db, entry.country, entry.city)} if entry else None,
        "courier_offer_dismissed": dismissed,
    }


def _waitlist_count(db: Session, country: str, city: str) -> int:
    """Combien de personnes, coursiers et patients, attendent Honam dans
    cette ville (maquette Coursiers 16). Sans casse ni accents."""
    key = rules.city_served_key(city)
    return sum(
        1 for (name,) in db.query(HonamWaitlistEntry.city).filter(HonamWaitlistEntry.country == country)
        if rules.city_served_key(name) == key
    )


@router.get("/waitlist/count")
def waitlist_count(city: str, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    country = country_of_phone(user.phone if user else None) or "TG"
    return {"city": city.strip(), "count": _waitlist_count(db, country, city)}


@router.post("/waitlist", status_code=201)
def join_waitlist(body: WaitlistBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    role = body.role.upper()
    if role not in ("COURIER", "PATIENT"):
        raise HTTPException(status_code=422, detail="Rôle inconnu")
    country = country_of_phone(user.phone) or "TG"
    entry = db.query(HonamWaitlistEntry).filter(
        HonamWaitlistEntry.user_id == user.id, HonamWaitlistEntry.role == role
    ).first()
    if entry is None:
        entry = HonamWaitlistEntry(user_id=user.id, role=role, country=country, city=body.city.strip())
        db.add(entry)
    else:
        entry.city = body.city.strip()
    db.commit()
    return {"city": entry.city, "role": entry.role, "since": entry.created_at.isoformat(),
            "count": _waitlist_count(db, entry.country, entry.city)}


@router.delete("/waitlist")
def leave_waitlist(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(HonamWaitlistEntry).filter(HonamWaitlistEntry.user_id == current_user["user_id"]).delete()
    db.commit()
    return {"ok": True}


# ── Vos coursiers (officine) ────────────────────────────────────────────


def _attached_json(db: Session, pharmacy: Pharmacy, courier: CourierProfile, link: PharmacyCourier) -> dict:
    rules.refresh_courier_status(courier)
    delivered = db.query(func.count(HonamOrder.id)).filter(
        HonamOrder.pharmacy_id == pharmacy.id, HonamOrder.courier_id == courier.user_id,
        HonamOrder.status == "DELIVERED",
    ).scalar() or 0
    unpaid = db.query(func.count(HonamOrder.id)).filter(
        HonamOrder.pharmacy_id == pharmacy.id, HonamOrder.courier_id == courier.user_id,
        HonamOrder.status == "DELIVERED", HonamOrder.courier_paid_at.is_(None),
    ).scalar() or 0
    return {
        "user_id": courier.user_id,
        "name": _name(db, courier.user_id),
        "phone": _phone(db, courier.user_id),
        "status": courier.status,
        "zones": courier.zones,
        "delivered_count": delivered,
        "unpaid_count": unpaid,
        "defaults_count": courier.defaults_count,
        "added_at": link.added_at.isoformat(),
    }


@router.get("/pharmacy/couriers")
def pharmacy_couriers(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    rows = (
        db.query(PharmacyCourier, CourierProfile)
        .join(CourierProfile, CourierProfile.id == PharmacyCourier.courier_id)
        .filter(PharmacyCourier.pharmacy_id == pharmacy.id)
        .order_by(PharmacyCourier.added_at)
        .all()
    )
    items = [_attached_json(db, pharmacy, courier, link) for link, courier in rows]
    db.commit()
    return {"items": items, "priority_minutes": rules.ATTACHED_PRIORITY_MINUTES}


@router.post("/pharmacy/couriers", status_code=201)
def attach_courier(body: AttachCourierBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Rattacher un livreur habituel par son numéro. Il doit déjà être
    coursier Pokou validé : l'officine ne contourne pas la validation."""
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    phone = normalize_e164(body.phone, pharmacy.country)
    target = db.query(User).filter(User.phone == phone).first() if phone else None
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == target.id).first() if target else None
    if courier is None or courier.status == "PENDING" or courier.country != pharmacy.country:
        raise HTTPException(status_code=404, detail="Aucun coursier Pokou validé avec ce numéro")
    link = db.query(PharmacyCourier).filter(
        PharmacyCourier.pharmacy_id == pharmacy.id, PharmacyCourier.courier_id == courier.id
    ).first()
    if link is None:
        link = PharmacyCourier(pharmacy_id=pharmacy.id, courier_id=courier.id)
        db.add(link)
        db.flush()
    data = _attached_json(db, pharmacy, courier, link)
    db.commit()
    return data


@router.delete("/pharmacy/couriers/{courier_user_id}")
def detach_courier(courier_user_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == courier_user_id).first()
    if courier is not None:
        db.query(PharmacyCourier).filter(
            PharmacyCourier.pharmacy_id == pharmacy.id, PharmacyCourier.courier_id == courier.id
        ).delete()
        db.commit()
    return {"ok": True}


# ── Paiements confirmés (appelé par confirm_payment) ────────────────────


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    metadata = payment.metadata_json or {}
    now = datetime.utcnow()
    if payment.kind == "HONAM_PHARMACY_SUB":
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == metadata.get("pharmacy_id")).first()
        if pharmacy is None:
            return None
        days = 365 if metadata.get("plan") == "EPE" else 30
        start = pharmacy.subscription_until if pharmacy.subscription_until and pharmacy.subscription_until > now else now
        pharmacy.subscription_until = start + timedelta(days=days)
        pharmacy.subscription_plan = metadata.get("plan")
        return {"pharmacy_id": pharmacy.id, "subscription_until": pharmacy.subscription_until.isoformat()}
    if payment.kind == "HONAM_CREDIT":
        pharmacy = db.query(Pharmacy).filter(Pharmacy.id == metadata.get("pharmacy_id")).first()
        if pharmacy is None:
            return None
        pharmacy.credit_balance += int(metadata.get("amount_ht") or 0)
        if pharmacy.credit_balance >= rules.CREDIT_PER_ORDER:
            pharmacy.credit_exhausted_at = None
        return {"pharmacy_id": pharmacy.id, "credit_balance": pharmacy.credit_balance}
    courier = db.query(CourierProfile).filter(CourierProfile.id == metadata.get("courier_id")).first()
    if courier is None:
        return None
    if payment.kind == "HONAM_COURIER_MEMBERSHIP":
        start = courier.membership_until if courier.membership_until and courier.membership_until > now else now
        courier.membership_until = start + timedelta(days=30)
        if courier.status != "SUSPENDED":
            courier.status = "MEMBER"
        return {"courier_status": courier.status}
    if payment.kind == "HONAM_COURIER_PACK":
        pack = metadata.get("pack")
        rides = rules.PACKS[pack]["rides"]
        if metadata.get("upgrade_from"):
            # Le pack supérieur REMPLACE l'ancien sur la même période : on
            # ajoute la différence de courses, pas un second pack.
            rides -= rules.PACKS[metadata["upgrade_from"]]["rides"]
            period_end = courier.pack_until
            kind = "UPGRADE"
        else:
            # Courses non utilisées du mois précédent : expirées (fin de
            # période), pas reportées.
            period_end = now + timedelta(days=30)
            courier.pack_until = period_end
            kind = "PURCHASE"
        courier.current_pack = pack
        db.add(CourierLedgerEntry(courier_id=courier.id, kind=kind, rides=rides, pack=pack,
                                  payment_id=payment.id, period_end=period_end))
        return {"courier_pack": pack}
    return None


# ── Équipe Pokou ────────────────────────────────────────────────────────

_TEAM = [UserRole.SUPER_ADMIN, UserRole.ADMIN]


@admin_router.post("/pharmacies", status_code=201)
def create_pharmacy(body: PharmacyCreate, current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    from app.models import AuditLog
    """Le commercial crée l'officine pendant sa visite (BM-06), puis envoie
    le lien de paiement de l'abonnement."""
    titulaire_phone = normalize_e164(body.titulaire_phone, body.country.upper())
    titulaire = db.query(User).filter(User.phone == titulaire_phone).first()
    if titulaire is None:
        raise HTTPException(status_code=422, detail="Le titulaire doit d'abord installer Pokou avec ce numéro")
    pharmacy = Pharmacy(
        country=body.country.upper(), name=body.name, address=body.address,
        phone=normalize_e164(body.phone, body.country.upper()) or body.phone,
        opening_hours=body.opening_hours, latitude=body.latitude, longitude=body.longitude,
        wallet_phone=normalize_e164(body.wallet_phone, body.country.upper()),
    )
    db.add(pharmacy)
    db.flush()
    db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=titulaire.id, role="TITULAIRE"))
    db.add(AuditLog(user_id=current_user["user_id"], action="pharmacy_create", entity_type="pharmacy",
                    entity_id=pharmacy.id, changes={"name": pharmacy.name, "country": pharmacy.country}))
    db.commit()
    return {**_pharmacy_json(pharmacy), "status": pharmacy.status}


def _application_admin_json(db: Session, a: PharmacyApplication) -> dict:
    return {
        "id": a.id, "user_id": a.user_id, "titulaire": _name(db, a.user_id), "titulaire_phone": _phone(db, a.user_id),
        "country": a.country, "name": a.name, "address": a.address, "license_number": a.license_number,
        "wallet_phone": a.wallet_phone, "authorization_media_id": a.authorization_media_id, "plan": a.plan,
        "latitude": a.latitude, "longitude": a.longitude, "status": a.status, "review_note": a.review_note,
        "submitted_at": a.submitted_at.isoformat(), "review_due_at": a.review_due_at.isoformat(),
        "overdue": a.status == "PENDING" and a.review_due_at < datetime.utcnow(),
        "reviewed_at": _iso(a.reviewed_at), "pharmacy_id": a.pharmacy_id,
    }


@admin_router.get("/pharmacy-applications")
def pharmacy_applications(
    status: str = "PENDING",
    current_user: dict = Depends(require_permission_claims("honam.view")), db: Session = Depends(get_db),
):
    """Les dossiers « Référencer votre officine », le plus proche de son
    échéance d'abord."""
    query = db.query(PharmacyApplication)
    if status != "ALL":
        query = query.filter(PharmacyApplication.status == status.upper())
    rows = query.order_by(PharmacyApplication.review_due_at).all()
    return {"items": [_application_admin_json(db, a) for a in rows]}


@admin_router.post("/pharmacy-applications/{application_id}/review")
def review_pharmacy_application(
    application_id: int, body: RegistrationReviewBody,
    current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db),
):
    """La décision du support, motivée en cas de refus. Valider crée
    l'officine, son titulaire et le wallet vérifié — comme la création par
    un commercial (`create_pharmacy`) ; l'officine reste hors de l'annuaire
    jusqu'au paiement de sa formule."""
    from app.models import AuditLog
    from app.services.notifications.inbox import notify

    application = db.query(PharmacyApplication).filter(PharmacyApplication.id == application_id).first()
    if application is None or application.status != "PENDING":
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    note = (body.note or "").strip() or None
    if body.decision == "REJECT":
        if note is None:
            raise HTTPException(status_code=422, detail="Dites au pharmacien ce qui ne va pas")
        application.status = "REJECTED"
        message = f"Votre dossier d'officine n'a pas été retenu. Motif : « {note} »"
    else:
        latitude = body.latitude if body.latitude is not None else application.latitude
        longitude = body.longitude if body.longitude is not None else application.longitude
        if latitude is None or longitude is None:
            raise HTTPException(status_code=422, detail="Indiquez la position de l'officine")
        if db.query(PharmacyStaff.id).filter(PharmacyStaff.user_id == application.user_id).first() is not None:
            raise HTTPException(status_code=409, detail="Ce compte appartient déjà à l'équipe d'une officine")
        titulaire_phone = _phone(db, application.user_id)
        phone = normalize_e164(body.phone, application.country) if body.phone else titulaire_phone
        pharmacy = Pharmacy(
            country=application.country, name=application.name, address=application.address,
            phone=phone or titulaire_phone or "", opening_hours=body.opening_hours,
            latitude=latitude, longitude=longitude,
            wallet_phone=application.wallet_phone, wallet_verified=True,
        )
        db.add(pharmacy)
        db.flush()
        db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=application.user_id, role="TITULAIRE"))
        application.status = "APPROVED"
        application.pharmacy_id = pharmacy.id
        application.latitude, application.longitude = latitude, longitude
        db.add(AuditLog(user_id=current_user["user_id"], action="pharmacy_create", entity_type="pharmacy",
                        entity_id=pharmacy.id, changes={"name": pharmacy.name, "country": pharmacy.country,
                                                        "application_id": application.id}))
        message = "Votre officine est validée : payez votre formule depuis l'espace officine pour l'ouvrir aux patients."
    application.review_note = note
    application.reviewed_at = datetime.utcnow()
    application.reviewer_id = current_user["user_id"]
    db.add(AuditLog(user_id=current_user["user_id"], action="pharmacy_application_review",
                    entity_type="pharmacy_application", entity_id=application.id,
                    changes={"decision": body.decision, "note": note}))
    notify(db, [application.user_id], service="honam", title=application.name, body=message)
    db.commit()
    return _application_admin_json(db, application)


@admin_router.post("/pharmacies/{pharmacy_id}/verify-wallet")
def verify_wallet(pharmacy_id: int, current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()
    if pharmacy is None:
        raise HTTPException(status_code=404, detail="Officine introuvable")
    if pharmacy.wallet_phone_pending:
        # Le nouveau wallet demandé par le titulaire devient celui des
        # paiements, une fois vérifié.
        pharmacy.wallet_phone = pharmacy.wallet_phone_pending
        pharmacy.wallet_phone_pending = None
    pharmacy.wallet_verified = True
    from app.models import AuditLog
    db.add(AuditLog(user_id=current_user["user_id"], action="pharmacy_verify_wallet", entity_type="pharmacy",
                    entity_id=pharmacy.id, changes={"wallet_phone": pharmacy.wallet_phone}))
    db.commit()
    return {"id": pharmacy.id, "wallet_verified": True}


@admin_router.get("/couriers/pending")
def pending_couriers(current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    rows = db.query(CourierProfile).filter(CourierProfile.status == "PENDING").order_by(CourierProfile.created_at).all()
    return {"items": [{"user_id": c.user_id, "name": _name(db, c.user_id), "country": c.country,
                       "zones": c.zones, "wallet_phone": c.wallet_phone} for c in rows]}


@admin_router.post("/couriers/{user_id}/validate")
def validate_courier(user_id: int, current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()
    if courier is None or courier.status != "PENDING":
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    courier.validated_at = datetime.utcnow()
    courier.referral_code = courier.referral_code or rules.new_referral_code(db)
    db.flush()
    rules.start_trial(db, courier)
    from app.models import AuditLog
    from app.services.notifications.inbox import notify
    db.add(AuditLog(user_id=current_user["user_id"], action="courier_validate", entity_type="courier",
                    entity_id=user_id, changes={"status": courier.status}))
    notify(db, [user_id], service="honam", title="Mode coursier",
           body="Ta candidature de coursier est acceptée : tes courses d'essai t'attendent.")
    db.commit()
    return {"user_id": user_id, "status": courier.status}


@admin_router.post("/pharmacies/{pharmacy_id}/exclude")
def exclude_pharmacy(pharmacy_id: int, body: ReasonBody, current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    """L'exclusion, quand la suspension persiste (HON-35) : décision humaine."""
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()
    if pharmacy is None:
        raise HTTPException(status_code=404, detail="Officine introuvable")
    pharmacy.status = "EXCLUDED"
    pharmacy.suspension_reason = body.reason
    from app.models import AuditLog
    db.add(AuditLog(user_id=current_user["user_id"], action="pharmacy_exclude", entity_type="pharmacy",
                    entity_id=pharmacy.id, changes={"reason": body.reason}))
    db.commit()
    return {"id": pharmacy.id, "status": pharmacy.status}


@admin_router.get("/waitlist")
def waitlist_by_city(current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    """Où ouvrir ensuite : le nombre d'inscrits par ville et par rôle."""
    rows = (
        db.query(HonamWaitlistEntry.country, HonamWaitlistEntry.city, HonamWaitlistEntry.role, func.count(HonamWaitlistEntry.id))
        .group_by(HonamWaitlistEntry.country, HonamWaitlistEntry.city, HonamWaitlistEntry.role)
        .order_by(func.count(HonamWaitlistEntry.id).desc())
        .all()
    )
    return {"items": [{"country": c, "city": city, "role": r, "count": n} for c, city, r, n in rows]}
