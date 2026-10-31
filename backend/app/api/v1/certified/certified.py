"""Pokou certifié — le badge d'identité et le mode preuve.

Le parcours (écrans de la section 9.5 du cahier des charges) :

1. **Essai** : le mode preuve s'ouvre aussitôt, le badge non (CERT-11). Un
   badge s'affiche à côté d'un nom ; il ne peut le faire que si quelqu'un a
   vérifié ce nom, et c'est le paiement qui le vérifie.
2. **Paiement** CashPay (Semoa) : le webhook renvoie le nom du titulaire du
   wallet. Il est comparé au nom affiché.
3. **Noms concordants** : badge actif. **Noms différents** : le badge
   attend, et la personne corrige le nom qu'elle a saisi. Le nom du
   titulaire n'est JAMAIS montré (maquette « 2b. Noms différents ») : le
   révéler permettrait de lire le nom de qui détient n'importe quel wallet
   en payant depuis lui.

Prix hors taxes, TVA du pays en sus (BM-10). Les officines HONAM ont le
badge Pro inclus dans leur abonnement.
"""
import re
import unicodedata
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.v1.modules.common import open_payment, payment_json
from app.core.countries import country_config, country_of_phone, module_open
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import CertifiedSubscription, User
from app.services.events.outbox import record_event

router = APIRouter(prefix="/certified", tags=["Pokou certifié"])

PAYMENT_KIND = "CERTIFIED_SUBSCRIPTION"
#: Hypothèse : la durée de l'essai n'est pas fixée dans les parties du
#: cahier des charges dont on dispose. Trente jours, à confirmer.
TRIAL_DAYS = 30

PLANS = {
    "PARTICULIER_MONTHLY": {"label": "Particulier, mensuel", "price_ht": 500, "days": 30},
    "PARTICULIER_YEARLY": {"label": "Particulier, annuel", "price_ht": 5000, "days": 365},
    "PRO_MONTHLY": {"label": "Pro, mensuel", "price_ht": 2500, "days": 30},
}


class SubscribeBody(BaseModel):
    plan: str


class ResolveNameBody(BaseModel):
    #: Le nom corrigé, tel qu'il figure sur la pièce du titulaire du wallet.
    full_name: str = Field(..., min_length=2, max_length=160)


def _normalize(name: Optional[str]) -> str:
    """« Kossi  AMEGAN » == « amégan kossi » : sans accents, sans casse, et
    sans ordre — l'opérateur écrit souvent NOM Prénom, le profil l'inverse."""
    if not name:
        return ""
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    words = re.findall(r"[a-z]+", ascii_name.lower())
    return " ".join(sorted(words))


def names_match(profile_name: Optional[str], wallet_name: Optional[str]) -> bool:
    return bool(_normalize(wallet_name)) and _normalize(profile_name) == _normalize(wallet_name)


def _ttc(db: Session, user: User, price_ht: int) -> tuple[float, int]:
    rate = country_config(db, country_of_phone(user.phone)).get("vat_rate") or 0
    return rate, int(round(price_ht * (1 + rate)))


def _user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not module_open(db, user.phone, "certified"):
        raise HTTPException(status_code=404, detail="Pokou certifié n'est pas disponible dans votre pays")
    return user


def _subscription(db: Session, user_id: int) -> Optional[CertifiedSubscription]:
    return db.query(CertifiedSubscription).filter(CertifiedSubscription.user_id == user_id).first()


def refresh_status(sub: CertifiedSubscription, now: Optional[datetime] = None) -> str:
    """Fait expirer ce qui doit l'être, à la lecture."""
    now = now or datetime.utcnow()
    if sub.status == "TRIAL" and sub.trial_ends_at and sub.trial_ends_at < now:
        sub.status = "EXPIRED"
    elif sub.status in ("ACTIVE", "NAME_MISMATCH") and sub.current_period_end and sub.current_period_end < now:
        sub.status = "EXPIRED"
    return sub.status


def proof_mode_allowed(db: Session, user_id: int) -> bool:
    """Le mode preuve est ouvert pendant l'essai ET après paiement, même si
    les noms diffèrent : il prouve ce qui a été écrit, pas qui l'a écrit."""
    sub = _subscription(db, user_id)
    return sub is not None and refresh_status(sub) in ("TRIAL", "ACTIVE", "NAME_MISMATCH")


def _apply_badge(user: User, sub: CertifiedSubscription) -> None:
    if sub.status == "ACTIVE":
        if not user.is_verified:
            user.is_verified = True
            user.verified_at = datetime.utcnow()
            sub.badge_granted = True
    elif sub.badge_granted:
        user.is_verified = False
        user.verified_at = None
        sub.badge_granted = False


def _status_json(db: Session, user: User, sub: Optional[CertifiedSubscription]) -> dict:
    if sub is not None:
        previous = sub.status
        if refresh_status(sub) != previous:
            _apply_badge(user, sub)
            db.commit()
    return {
        "status": sub.status if sub else "NONE",
        "plan": sub.plan if sub else None,
        "trial_ends_at": sub.trial_ends_at.isoformat() if sub and sub.trial_ends_at else None,
        "current_period_end": sub.current_period_end.isoformat() if sub and sub.current_period_end else None,
        "badge_visible": bool(user.is_verified),
        "proof_mode_allowed": bool(sub and sub.status in ("TRIAL", "ACTIVE", "NAME_MISMATCH")),
        "profile_name": user.full_name,
        "name_mismatch": bool(sub and sub.status == "NAME_MISMATCH"),
        # « Badge payant » : seul un paiement donne le droit de couper le
        # mode preuve d'un groupe en tant qu'administrateur.
        "paid": bool(sub and sub.first_paid_at and sub.status in ("ACTIVE", "NAME_MISMATCH")),
        "trial_available": sub is None,
    }


@router.get("/offer")
def offer(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user["user_id"])
    plans = []
    for code, plan in PLANS.items():
        rate, ttc = _ttc(db, user, plan["price_ht"])
        plans.append({
            "code": code, "label": plan["label"], "days": plan["days"],
            "price_ht": plan["price_ht"], "vat_rate": rate, "price_ttc": ttc,
        })
    return {"trial_days": TRIAL_DAYS, "plans": plans}


@router.get("/me")
def my_status(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user["user_id"])
    return _status_json(db, user, _subscription(db, user.id))


@router.post("/trial")
def start_trial(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user["user_id"])
    if _subscription(db, user.id) is not None:
        raise HTTPException(status_code=409, detail="L'essai a déjà été utilisé")
    sub = CertifiedSubscription(
        user_id=user.id, status="TRIAL",
        trial_ends_at=datetime.utcnow() + timedelta(days=TRIAL_DAYS),
    )
    db.add(sub)
    db.commit()
    return _status_json(db, user, sub)


@router.post("/subscribe")
def subscribe(body: SubscribeBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user["user_id"])
    plan = PLANS.get(body.plan)
    if plan is None:
        raise HTTPException(status_code=422, detail="Formule inconnue")
    _, ttc = _ttc(db, user, plan["price_ht"])
    payment = open_payment(
        db, user.id, kind=PAYMENT_KIND, amount=ttc,
        description=f"Pokou certifié — {plan['label']}",
        metadata={"plan": body.plan, "price_ht": plan["price_ht"]},
    )
    db.commit()
    return payment_json(payment)


@router.post("/resolve-name")
def resolve_name(body: ResolveNameBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Corriger son nom après « noms différents ». Le badge s'allume si le
    nom corrigé correspond ; sinon la réponse dit seulement « toujours
    différent », sans jamais renvoyer le nom attendu."""
    user = _user(db, current_user["user_id"])
    sub = _subscription(db, user.id)
    if sub is None or sub.status != "NAME_MISMATCH":
        raise HTTPException(status_code=409, detail="Aucune différence de nom à résoudre")
    if not names_match(body.full_name, sub.wallet_holder_name):
        raise HTTPException(status_code=422, detail="Ce nom ne correspond toujours pas à celui du titulaire du wallet")
    user.full_name = body.full_name.strip()
    sub.status = "ACTIVE"
    _apply_badge(user, sub)
    db.commit()
    return _status_json(db, user, sub)


def has_paid_badge(db: Session, user_id: int) -> bool:
    sub = _subscription(db, user_id)
    return bool(sub and sub.first_paid_at and refresh_status(sub) in ("ACTIVE", "NAME_MISMATCH"))


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """Appelé par `confirm_payment`, à la confirmation signée du webhook."""
    metadata = payment.metadata_json or {}
    plan = PLANS.get(metadata.get("plan"))
    if plan is None:
        return None
    user = db.query(User).filter(User.id == payment.user_id).first()
    sub = _subscription(db, payment.user_id)
    now = datetime.utcnow()
    if sub is None:
        sub = CertifiedSubscription(user_id=payment.user_id)
        db.add(sub)
    # Renouveler d'avance prolonge, ne fait pas perdre les jours restants.
    start = sub.current_period_end if sub.current_period_end and sub.current_period_end > now else now
    sub.current_period_end = start + timedelta(days=plan["days"])
    sub.plan = metadata["plan"]
    sub.first_paid_at = sub.first_paid_at or now
    wallet_name = metadata.get("payer_name")
    if wallet_name:
        sub.wallet_holder_name = wallet_name
    sub.status = "ACTIVE" if names_match(user.full_name if user else None, sub.wallet_holder_name) else "NAME_MISMATCH"
    if user is not None:
        _apply_badge(user, sub)
    db.flush()
    record_event(
        db, "analytics.events", "certified.subscription.paid",
        {"user_id": payment.user_id, "plan": sub.plan, "status": sub.status, "amount": payment.amount},
        key=f"user-{payment.user_id}",
    )
    return {"certified_status": sub.status}
