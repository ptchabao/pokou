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
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
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
    CourierLedgerEntry,
    CourierProfile,
    HonamOrder,
    HonamOrderEvent,
    HonamOrderMessage,
    HonamWaitlistEntry,
    Pharmacy,
    PharmacyCourier,
    PharmacyStaff,
    User,
    UserRole,
)
from app.services.honam import rules
from app.services.honam.order_notifications import notify_order_state_changed
from app.utils.phone import normalize_e164

router = APIRouter(prefix="/honam", tags=["HONAM"])
admin_router = APIRouter(prefix="/admin/honam", tags=["Admin HONAM"])

#: Une officine ne voit que ses commandes ; les plus anciennes d'abord dans
#: la file à traiter.
_PHARMACY_QUEUE = ("SUBMITTED", "ACCEPTED", "PAID", "READY", "IN_DELIVERY")


# ── Corps de requêtes ───────────────────────────────────────────────────


class OrderCreate(BaseModel):
    pharmacy_id: int
    prescription_media_id: int
    delivery_address: str = Field(..., min_length=3, max_length=255)
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    note: Optional[str] = Field(None, max_length=500)


class ResendBody(BaseModel):
    pharmacy_id: int


class QuoteItem(BaseModel):
    name: str = Field(..., min_length=1, max_length=160)
    quantity: int = Field(1, ge=1, le=100)
    unit_price: int = Field(..., ge=0, le=5_000_000)
    available: bool = True


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


class CourierApplication(BaseModel):
    zones: str = Field(..., min_length=2, max_length=255)
    wallet_phone: str
    accept_rules: bool
    #: Ville où la personne livrerait. Hors des villes desservies, la
    #: candidature est refusée et l'application propose la liste d'attente.
    city: Optional[str] = Field(None, max_length=80)
    #: Code de parrainage d'un coursier déjà validé (maquette Coursiers 15).
    referral_code: Optional[str] = Field(None, max_length=12)


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
        "courier_name": _name(db, order.courier_id),
        "created_at": order.created_at.isoformat(),
        "updated_at": order.updated_at.isoformat(),
        "delivered_at": order.delivered_at.isoformat() if order.delivered_at else None,
    }
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
            # Le remboursement part UNIQUEMENT vers le numéro qui a payé.
            "refund_to_phone": _phone(db, order.patient_id) if order.refund_due > 0 else None,
        })
    if viewer == "courier":
        data.update({
            "courier_paid_at": order.courier_paid_at.isoformat() if order.courier_paid_at else None,
            "delivery_latitude": order.delivery_latitude,
            "delivery_longitude": order.delivery_longitude,
        })
    return data


def _order_message_json(db: Session, message: HonamOrderMessage) -> dict:
    sender = db.query(User).filter(User.id == message.sender_id).first() if message.sender_id else None
    return {
        "id": message.id,
        "sender_id": message.sender_id,
        "sender_name": sender.full_name if sender else None,
        "sender_role": message.sender_role,
        "body": message.body,
        "created_at": message.created_at.isoformat(),
    }


def _order_message_role(db: Session, order: HonamOrder, user_id: int) -> Optional[str]:
    if order.patient_id == user_id:
        return "PATIENT"
    if order.courier_id == user_id:
        return "COURIER"
    if db.query(PharmacyStaff.id).filter(
        PharmacyStaff.pharmacy_id == order.pharmacy_id,
        PharmacyStaff.user_id == user_id,
    ).first():
        return "PHARMACY"
    return None


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
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _user(db, current_user)
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id).first()
    if order is None or _order_message_role(db, order, user.id) is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    messages = (
        db.query(HonamOrderMessage)
        .filter(HonamOrderMessage.order_id == order.id)
        .order_by(HonamOrderMessage.created_at, HonamOrderMessage.id)
        .limit(500)
        .all()
    )
    return {"items": [_order_message_json(db, message) for message in messages]}


@router.post("/orders/{order_id}/messages", status_code=201)
def send_order_message(
    order_id: int,
    body: OrderMessageBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = _user(db, current_user)
    order = db.query(HonamOrder).filter(HonamOrder.id == order_id).first()
    role = _order_message_role(db, order, user.id) if order else None
    if order is None or role is None:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    message = HonamOrderMessage(
        order_id=order.id,
        sender_id=user.id,
        sender_role=role,
        body=body.body.strip(),
    )
    if not message.body:
        raise HTTPException(status_code=422, detail="Le message ne peut pas être vide")
    db.add(message)
    db.commit()
    db.refresh(message)
    return _order_message_json(db, message)


@router.post("/orders/{order_id}/accept")
def accept_quote(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    _move(db, order, "ACCEPTED", user.id)
    _commit_order_change(db, order, user.id)
    return _order_json(db, order, "patient")


@router.post("/orders/{order_id}/declare-paid")
def declare_paid(order_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """« J'ai payé l'officine » : l'officine doit encore le confirmer."""
    user = _user(db, current_user)
    order = _patient_order(db, order_id, user.id)
    if order.status != "ACCEPTED":
        raise HTTPException(status_code=409, detail="Le devis doit être accepté")
    order.patient_paid_declared_at = datetime.utcnow()
    order.payment_not_received_at = None
    db.add(HonamOrderEvent(order_id=order.id, actor_id=user.id, status="ACCEPTED", note="Paiement déclaré par le patient"))
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
    db.commit()
    return {
        "pharmacy": {**_pharmacy_json(pharmacy), "wallet_phone": pharmacy.wallet_phone,
                     "wallet_verified": pharmacy.wallet_verified, "status": pharmacy.status,
                     "suspension_reason": pharmacy.suspension_reason},
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
    if order.courier_id is None or order.status not in ("READY", "IN_DELIVERY"):
        raise HTTPException(status_code=409, detail="Aucun coursier sur cette commande")
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == order.courier_id).first()
    suspended = rules.record_default(db, courier, order) if courier else False
    state_changed = order.status == "IN_DELIVERY"
    if state_changed:
        _move(db, order, "READY", current_user["user_id"], f"Défaut du coursier : {body.reason}")
    order.courier_id = None
    db.commit()
    if state_changed:
        notify_order_state_changed(db, order, actor_id=current_user["user_id"])
    return {"courier_suspended": suspended, "order": _order_json(db, order, "pharmacy")}


@router.post("/pharmacy/on-duty")
def set_on_duty(body: OnDutyBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy = _staff_pharmacy(db, current_user["user_id"])
    pharmacy.is_on_duty = body.on_duty
    db.commit()
    return _pharmacy_json(pharmacy)


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
    }


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
    wallet = normalize_e164(body.wallet_phone, country)
    if wallet is None:
        raise HTTPException(status_code=422, detail="Numéro de wallet invalide")
    courier = db.query(CourierProfile).filter(CourierProfile.user_id == user.id).first()
    if courier is None:
        courier = CourierProfile(user_id=user.id, country=country, status="PENDING")
        db.add(courier)
    if courier.status == "PENDING":
        courier.zones = body.zones.strip()
        courier.city = (body.city or "").strip() or courier.city
        courier.wallet_phone = wallet
        courier.rules_accepted_at = datetime.utcnow()
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


@router.get("/courier/rides")
def available_rides(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user)
    courier = _courier(db, user)
    pharmacy_ids = db.query(Pharmacy.id).filter(Pharmacy.country == courier.country)
    open_rides = db.query(HonamOrder).filter(
        HonamOrder.status == "READY", HonamOrder.courier_id.is_(None), HonamOrder.pharmacy_id.in_(pharmacy_ids),
    ).order_by(HonamOrder.updated_at).limit(100).all()
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
    priority_cutoff = datetime.utcnow() - timedelta(minutes=rules.ATTACHED_PRIORITY_MINUTES)
    open_rides = [
        o for o in open_rides
        if o.pharmacy_id in attached_to or o.pharmacy_id not in with_attached or o.updated_at < priority_cutoff
    ][:50]
    open_rides.sort(key=lambda o: (o.pharmacy_id not in attached_to, o.updated_at))
    mine = db.query(HonamOrder).filter(
        HonamOrder.courier_id == user.id, HonamOrder.status.in_(("READY", "IN_DELIVERY", "DELIVERED")),
    ).order_by(HonamOrder.updated_at.desc()).limit(50).all()
    return {
        "available": [_order_json(db, o, "courier") for o in open_rides],
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
    if body.code != order.delivery_code:
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

#: Le suivi n'existe que pendant la course : de l'acceptation par le
#: coursier à la remise.
_TRACKABLE = ("READY", "IN_DELIVERY")


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
    }
    if at and order.delivery_latitude is not None and order.delivery_longitude is not None:
        data["distance_km"] = round(rules.distance_km(
            order.courier_latitude, order.courier_longitude, order.delivery_latitude, order.delivery_longitude,
        ), 2)
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
    return {
        "country": country,
        "honam_open": bool(user and module_open(db, user.phone, "honam")),
        "served_cities": rules.served_cities(db, country),
        "waitlist": {"city": entry.city, "role": entry.role, "since": entry.created_at.isoformat()} if entry else None,
    }


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
    return {"city": entry.city, "role": entry.role, "since": entry.created_at.isoformat()}


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


@admin_router.post("/pharmacies/{pharmacy_id}/verify-wallet")
def verify_wallet(pharmacy_id: int, current_user: dict = Depends(require_permission_claims("honam.manage")), db: Session = Depends(get_db)):
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()
    if pharmacy is None:
        raise HTTPException(status_code=404, detail="Officine introuvable")
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
