"""Les règles de HONAM qui ne dépendent pas d'une route.

Tarifs (section 4 du cahier des charges), visibilité des officines (BM-02,
BM-11, BM-12, HON-35), registre des coursiers (BM-03, BM-04, BM-05, BM-07)
et transitions de commande.
"""
import math
import secrets
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.countries import country_config
from app.models import CourierLedgerEntry, CourierProfile, HonamOrder, HonamOrderEvent, Pharmacy
from app.services.events.outbox import record_event

EVENTS_TOPIC = "honam.events"

#: Crédit officine : 100 FCFA HT par commande payée (BM-11).
CREDIT_PER_ORDER = 100
#: Alerte à 10 commandes restantes.
CREDIT_ALERT_ORDERS = 10
#: À crédit épuisé, l'officine reçoit encore ses ordonnances 7 jours.
CREDIT_GRACE_DAYS = 7
#: Hypothèse (BM-02 : « délai de grâce à fixer ») : 7 jours après la fin de
#: l'abonnement.
SUBSCRIPTION_GRACE_DAYS = 7
#: Hypothèse : un devis sans réponse expire au bout de 24 heures.
QUOTE_TTL_HOURS = 24
#: Le remboursement d'un produit manquant se fait sous 2 h (maquette A2) ;
#: au-delà, l'officine est suspendue jusqu'à régularisation (HON-35).
REFUND_DEADLINE_HOURS = 2
#: Hypothèse : une course impayée au coursier depuis 72 h suspend l'officine.
UNPAID_SUSPENSION_HOURS = 72
#: Suspension automatique au 3e défaut de livraison (BM-05).
MAX_COURIER_DEFAULTS = 3

COURIER_MEMBERSHIP_HT = 1000
COURIER_TRIAL_RIDES = 5
UNLIMITED = 9999
#: Hypothèse (maquette Coursiers 15, montant non dit) : le parrain reçoit
#: 2 courses offertes à la première course livrée de son filleul.
REFERRAL_GIFT_RIDES = 2
#: Les livreurs habituels d'une officine (Officine 6) voient ses courses
#: seuls pendant ce délai, puis tous les coursiers de la ville. Hypothèse.
ATTACHED_PRIORITY_MINUTES = 5
#: Une position plus vieille que ça est montrée « position non à jour ».
LOCATION_STALE_SECONDS = 60

#: Nombre de courses et prix HT au Togo. La Côte d'Ivoire paie 1,5 fois,
#: comme le prix de sa course (1 500 FCFA contre 1 000).
PACKS = {
    "ABLAVI": {"label": "ABLAVI 1er", "rides": 5, "price_tg": 500},
    "POKOU_VI": {"label": "Pokou Vi", "rides": 10, "price_tg": 900},
    "OSEI_TUTU": {"label": "Oseï Tutu", "rides": 20, "price_tg": 1600},
    "QUEEN": {"label": "Queen Pokou", "rides": UNLIMITED, "price_tg": 3000},
}
PACK_ORDER = ["ABLAVI", "POKOU_VI", "OSEI_TUTU", "QUEEN"]


def pack_price(country: str, pack: str) -> int:
    base = PACKS[pack]["price_tg"]
    return base * 3 // 2 if country == "CI" else base


def pharmacy_prices(db: Session, country: str) -> dict:
    config = country_config(db, country)
    return {
        "WETRI": config.get("pharmacy_monthly_price"),
        "EPE": config.get("pharmacy_yearly_price"),
        "vat_rate": config.get("vat_rate") or 0,
        "delivery_price": config.get("delivery_price"),
    }


def ttc(amount_ht: int, vat_rate: float) -> int:
    return int(round(amount_ht * (1 + vat_rate)))


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance à vol d'oiseau. Suffit à trier un annuaire de quartier."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


# ── Officines ────────────────────────────────────────────────────────────


def _has_overdue_obligation(db: Session, pharmacy: Pharmacy, now: datetime) -> Optional[str]:
    cutoff = now - timedelta(hours=UNPAID_SUSPENSION_HOURS)
    refund = db.query(HonamOrder.id).filter(
        HonamOrder.pharmacy_id == pharmacy.id,
        HonamOrder.refund_due > 0,
        HonamOrder.refund_confirmed_at.is_(None),
        HonamOrder.refund_requested_at < now - timedelta(hours=REFUND_DEADLINE_HOURS),
    ).first()
    if refund:
        return "Remboursement patient en attente"
    unpaid = db.query(HonamOrder.id).filter(
        HonamOrder.pharmacy_id == pharmacy.id,
        HonamOrder.status == "DELIVERED",
        HonamOrder.courier_id.isnot(None),
        HonamOrder.courier_paid_at.is_(None),
        HonamOrder.delivered_at < cutoff,
    ).first()
    if unpaid:
        return "Course non payée au coursier"
    return None


def refresh_pharmacy_status(db: Session, pharmacy: Pharmacy, now: Optional[datetime] = None) -> str:
    """Suspend ou rétablit l'officine selon ses obligations (HON-35).

    L'exclusion, elle, reste une décision de l'équipe : elle ne se lève pas
    toute seule.
    """
    now = now or datetime.utcnow()
    if pharmacy.status == "EXCLUDED":
        return pharmacy.status
    reason = _has_overdue_obligation(db, pharmacy, now)
    if reason and pharmacy.status != "SUSPENDED":
        pharmacy.status = "SUSPENDED"
        pharmacy.suspension_reason = reason
        record_event(db, EVENTS_TOPIC, "honam.pharmacy.suspended",
                     {"pharmacy_id": pharmacy.id, "reason": reason}, key=f"pharmacy-{pharmacy.id}")
    elif not reason and pharmacy.status == "SUSPENDED" and pharmacy.suspension_reason in (
        "Remboursement patient en attente", "Course non payée au coursier"
    ):
        pharmacy.status = "ACTIVE"
        pharmacy.suspension_reason = None
    return pharmacy.status


def pharmacy_accepts_orders(db: Session, pharmacy: Pharmacy, now: Optional[datetime] = None) -> bool:
    """Visible dans l'annuaire et destinataire d'ordonnances (BM-02, BM-11)."""
    now = now or datetime.utcnow()
    if refresh_pharmacy_status(db, pharmacy, now) != "ACTIVE":
        return False
    if not pharmacy.wallet_verified or not pharmacy.wallet_phone:
        return False
    if pharmacy.subscription_until is None:
        return False
    if pharmacy.subscription_until + timedelta(days=SUBSCRIPTION_GRACE_DAYS) < now:
        return False
    if pharmacy.credit_exhausted_at and pharmacy.credit_exhausted_at + timedelta(days=CREDIT_GRACE_DAYS) < now:
        return False
    return True


def charge_order_credit(db: Session, pharmacy: Pharmacy, order: HonamOrder) -> None:
    """100 FCFA HT à la commande PAYÉE — jamais pour un devis refusé,
    expiré ou annulé avant paiement (BM-11)."""
    if pharmacy.credit_balance >= CREDIT_PER_ORDER:
        pharmacy.credit_balance -= CREDIT_PER_ORDER
        if pharmacy.credit_balance < CREDIT_PER_ORDER:
            pharmacy.credit_exhausted_at = datetime.utcnow()
    elif pharmacy.credit_exhausted_at is None:
        pharmacy.credit_exhausted_at = datetime.utcnow()
    remaining = pharmacy.credit_balance // CREDIT_PER_ORDER
    if remaining == CREDIT_ALERT_ORDERS:
        record_event(db, EVENTS_TOPIC, "honam.pharmacy.credit_low",
                     {"pharmacy_id": pharmacy.id, "orders_left": remaining}, key=f"pharmacy-{pharmacy.id}")


# ── Coursiers ────────────────────────────────────────────────────────────


def rides_left(db: Session, courier: CourierProfile, now: Optional[datetime] = None) -> int:
    """Le solde de courses, RECALCULÉ depuis le registre (BM-07)."""
    now = now or datetime.utcnow()
    total = db.query(func.coalesce(func.sum(CourierLedgerEntry.rides), 0)).filter(
        CourierLedgerEntry.courier_id == courier.id,
        (CourierLedgerEntry.period_end.is_(None)) | (CourierLedgerEntry.period_end > now),
    ).scalar()
    return max(int(total or 0), 0)


def refresh_courier_status(courier: CourierProfile, now: Optional[datetime] = None) -> str:
    now = now or datetime.utcnow()
    if courier.status == "TRIAL" and courier.trial_ends_at and courier.trial_ends_at < now:
        courier.status = "ENDED"
    elif courier.status == "MEMBER" and courier.membership_until and courier.membership_until < now:
        courier.status = "ENDED"
    return courier.status


def launch_active(db: Session, country: str, now: Optional[datetime] = None) -> bool:
    """Les deux premiers mois de Honam dans le pays : les coursiers livrent
    sans adhésion ni pack. Fixé par l'équipe (`honam_launch_until` dans la
    configuration du pays), jamais déduit."""
    until = country_config(db, country).get("honam_launch_until")
    if not until:
        return False
    try:
        return (now or datetime.utcnow()) < datetime.fromisoformat(str(until))
    except ValueError:
        return False


def courier_can_accept(db: Session, courier: CourierProfile) -> tuple[bool, Optional[str]]:
    """BM-03 : essai en cours, ou adhésion Win Pokou active, ET au moins une
    course dans le pack — sauf pendant la période de lancement."""
    status = refresh_courier_status(courier)
    if status == "SUSPENDED":
        return False, "Compte coursier suspendu"
    if status == "PENDING":
        return False, "Candidature en cours de vérification"
    if status == "REJECTED":
        # Candidature refusée par l'équipe : pas de course, même pendant
        # la période de lancement.
        return False, "Candidature non retenue"
    if launch_active(db, courier.country):
        return True, None
    if status == "ENDED":
        return False, "Adhésion Win Pokou nécessaire"
    if rides_left(db, courier) <= 0:
        return False, "Plus de course dans votre pack : passez au pack supérieur"
    return True, None


def start_trial(db: Session, courier: CourierProfile) -> None:
    now = datetime.utcnow()
    courier.status = "TRIAL"
    courier.trial_ends_at = now + timedelta(days=30)
    db.add(CourierLedgerEntry(
        courier_id=courier.id, kind="TRIAL", rides=COURIER_TRIAL_RIDES,
        pack="TRIAL", period_end=courier.trial_ends_at,
    ))


def record_ride(db: Session, courier: CourierProfile, order: HonamOrder) -> None:
    """BM-04 : une course n'est décomptée qu'à la remise validée par le code.
    Pendant le lancement, elle est inscrite au registre sans être décomptée.
    Une adhésion expirée entre-temps ne change rien : on ne coupe jamais une
    course en cours."""
    if launch_active(db, courier.country):
        db.add(CourierLedgerEntry(courier_id=courier.id, kind="LAUNCH", rides=0, order_id=order.id))
        return
    if courier.current_pack == "QUEEN" and courier.pack_until and courier.pack_until > datetime.utcnow():
        db.add(CourierLedgerEntry(courier_id=courier.id, kind="RIDE", rides=0, order_id=order.id, pack="QUEEN"))
        return
    db.add(CourierLedgerEntry(
        courier_id=courier.id, kind="RIDE", rides=-1, order_id=order.id,
        period_end=courier.pack_until or courier.trial_ends_at,
    ))


def record_default(db: Session, courier: CourierProfile, order: HonamOrder) -> bool:
    """Renvoie vrai si ce défaut suspend le coursier (BM-05)."""
    courier.defaults_count += 1
    db.add(CourierLedgerEntry(courier_id=courier.id, kind="DEFAULT", rides=0, order_id=order.id))
    if courier.defaults_count >= MAX_COURIER_DEFAULTS and courier.status != "SUSPENDED":
        courier.status = "SUSPENDED"
        courier.suspended_at = datetime.utcnow()
        record_event(db, EVENTS_TOPIC, "honam.courier.suspended",
                     {"courier_user_id": courier.user_id, "defaults": courier.defaults_count},
                     key=f"courier-{courier.user_id}")
        return True
    return False


def queen_unlocked(db: Session, courier: CourierProfile, now: Optional[datetime] = None) -> bool:
    """Queen Pokou : débloqué sans défaut de livraison le mois précédent."""
    now = now or datetime.utcnow()
    month_start = datetime(now.year, now.month, 1)
    previous_start = (month_start - timedelta(days=1)).replace(day=1)
    return db.query(CourierLedgerEntry.id).filter(
        CourierLedgerEntry.courier_id == courier.id,
        CourierLedgerEntry.kind == "DEFAULT",
        CourierLedgerEntry.created_at >= previous_start,
        CourierLedgerEntry.created_at < month_start,
    ).first() is None


def served_cities(db: Session, country: Optional[str]) -> list[str]:
    return list(country_config(db, country).get("honam_cities") or [])


def city_served(db: Session, country: Optional[str], city: Optional[str]) -> bool:
    """Comparaison sans casse ni accents : « lome » vaut « Lomé »."""
    import unicodedata

    def key(value: str) -> str:
        return unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().strip().lower()

    return bool(city) and key(city) in {key(c) for c in served_cities(db, country)}


def new_referral_code(db: Session) -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        code = "".join(secrets.choice(alphabet) for _ in range(6))
        if not db.query(CourierProfile.id).filter(CourierProfile.referral_code == code).first():
            return code


def reward_referrer(db: Session, courier: CourierProfile) -> bool:
    """À la PREMIÈRE course livrée du filleul, une seule fois : le parrain
    reçoit ses courses offertes. Écrites au registre comme le reste."""
    if courier.referred_by_id is None or courier.referral_rewarded_at is not None:
        return False
    referrer = db.query(CourierProfile).filter(CourierProfile.id == courier.referred_by_id).first()
    courier.referral_rewarded_at = datetime.utcnow()
    if referrer is None or referrer.status == "SUSPENDED":
        return False
    now = datetime.utcnow()
    period_end = max(
        [d for d in (referrer.pack_until, referrer.trial_ends_at) if d and d > now],
        default=now + timedelta(days=30),
    )
    db.add(CourierLedgerEntry(courier_id=referrer.id, kind="GIFT", rides=REFERRAL_GIFT_RIDES,
                              pack="GIFT", period_end=period_end))
    record_event(db, EVENTS_TOPIC, "honam.courier.referral_rewarded",
                 {"courier_user_id": referrer.user_id, "rides": REFERRAL_GIFT_RIDES}, key=f"courier-{referrer.user_id}")
    return True


def recommended_pack(db: Session, courier: CourierProfile, now: Optional[datetime] = None) -> str:
    """Fin d'essai (maquette Coursiers 12) : le pack qui couvre l'activité
    RÉELLE des 30 derniers jours, pas le plus cher."""
    now = now or datetime.utcnow()
    delivered = db.query(func.count(CourierLedgerEntry.id)).filter(
        CourierLedgerEntry.courier_id == courier.id,
        CourierLedgerEntry.kind.in_(("RIDE", "LAUNCH")),
        CourierLedgerEntry.created_at >= now - timedelta(days=30),
    ).scalar() or 0
    for code in PACK_ORDER[:-1]:
        if delivered <= PACKS[code]["rides"]:
            return code
    return "QUEEN" if queen_unlocked(db, courier, now) else "OSEI_TUTU"


def upgrade_price(country: str, current: Optional[str], target: str) -> int:
    """Passer au pack supérieur en payant la différence (BM-03)."""
    if current and current in PACKS and PACK_ORDER.index(target) > PACK_ORDER.index(current):
        return pack_price(country, target) - pack_price(country, current)
    return pack_price(country, target)


# ── Commandes ────────────────────────────────────────────────────────────

#: Les transitions permises. Toute autre est refusée par `transition`.
TRANSITIONS = {
    "SUBMITTED": {"QUOTED", "REJECTED", "CANCELLED"},
    "QUOTED": {"ACCEPTED", "EXPIRED", "CANCELLED", "QUOTED"},
    "ACCEPTED": {"PAID", "CANCELLED"},
    "PAID": {"READY", "CANCELLED"},
    "READY": {"IN_DELIVERY"},
    "IN_DELIVERY": {"DELIVERED", "READY"},
    "DELIVERED": set(),
    "REJECTED": set(),
    "EXPIRED": set(),
    "CANCELLED": set(),
}


class TransitionError(Exception):
    pass


def transition(db: Session, order: HonamOrder, status: str, actor_id: Optional[int], note: Optional[str] = None) -> None:
    if status not in TRANSITIONS.get(order.status, set()):
        raise TransitionError(f"Impossible de passer de {order.status} à {status}")
    order.status = status
    order.updated_at = datetime.utcnow()
    db.add(HonamOrderEvent(order_id=order.id, actor_id=actor_id, status=status, note=note))
    # Aucune donnée de santé dans le flux : ni ordonnance, ni médicament.
    record_event(db, EVENTS_TOPIC, f"honam.order.{status.lower()}", {
        "order_id": order.id, "pharmacy_id": order.pharmacy_id,
        "patient_id": order.patient_id, "courier_id": order.courier_id,
    }, key=f"order-{order.id}")


def expire_quote_if_due(db: Session, order: HonamOrder) -> None:
    if order.status == "QUOTED" and order.quote_expires_at and order.quote_expires_at < datetime.utcnow():
        transition(db, order, "EXPIRED", None, "Devis sans réponse")


def new_delivery_code() -> str:
    return f"{secrets.randbelow(10 ** 6):06d}"
