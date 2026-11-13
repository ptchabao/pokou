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
from app.core.permissions import require_permission_claims
from app.core.rbac import require_admin_role
from app.core.security import get_current_user
from app.models import CertifiedProApplication, CertifiedSubscription, MediaAsset, Pharmacy, PharmacyStaff, User, UserRole
from app.services.events.outbox import record_event

router = APIRouter(prefix="/certified", tags=["Pokou certifié"])
admin_router = APIRouter(prefix="/admin/certified", tags=["Admin Pokou certifié"])

PAYMENT_KIND = "CERTIFIED_SUBSCRIPTION"
#: Hypothèse : la durée de l'essai n'est pas fixée dans les parties du
#: cahier des charges dont on dispose. Trente jours, à confirmer.
TRIAL_DAYS = 30
#: Le support répond à un dossier Pro sous 48 h (maquette Pro 3).
PRO_REVIEW_HOURS = 48
PRO_PLANS = {"PRO_MONTHLY"}

PLANS = {
    "PARTICULIER_MONTHLY": {"label": "Particulier, mensuel", "price_ht": 500, "days": 30},
    "PARTICULIER_YEARLY": {"label": "Particulier, annuel", "price_ht": 5000, "days": 365},
    "PRO_MONTHLY": {"label": "Pro, mensuel", "price_ht": 2500, "days": 30},
}


class SubscribeBody(BaseModel):
    plan: str


class ProApplicationBody(BaseModel):
    business_name: str = Field(..., min_length=2, max_length=160)
    activity: str = Field(..., min_length=2, max_length=120)
    city: Optional[str] = Field(None, max_length=80)
    document_media_id: int


class ProReviewBody(BaseModel):
    decision: str  # APPROVE|CORRECTION|REJECT
    note: Optional[str] = Field(None, max_length=500)


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


#: CRT-5 : après un paiement manqué, le badge reste visible 7 jours de grâce,
#: puis il est mis EN PAUSE — masqué, sans rien effacer.
GRACE_DAYS = 7


def refresh_status(sub: CertifiedSubscription, now: Optional[datetime] = None) -> str:
    """Fait expirer ce qui doit l'être, à la lecture."""
    now = now or datetime.utcnow()
    if sub.status == "TRIAL" and sub.trial_ends_at and sub.trial_ends_at < now:
        sub.status = "EXPIRED"
    elif (
        sub.status in ("ACTIVE", "NAME_MISMATCH")
        and sub.current_period_end
        and sub.current_period_end + timedelta(days=GRACE_DAYS) < now
    ):
        # Un abonnement PAYÉ ne s'éteint pas : il se met en pause, et se
        # réactive au paiement suivant. Les traces du mode preuve restent.
        sub.status = "PAUSED"
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
        # CRT-5 : la date du paiement manqué, et celle où le badge a été masqué.
        "paused_since": (
            (sub.current_period_end + timedelta(days=GRACE_DAYS)).isoformat()
            if sub and sub.status == "PAUSED" and sub.current_period_end else None
        ),
        "grace_days": GRACE_DAYS,
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
    if body.plan in PRO_PLANS:
        # Le justificatif d'abord, le paiement ensuite (maquettes Pro) :
        # on ne fait pas payer un dossier que le support pourrait refuser.
        application = _pro_application(db, user.id)
        if application is None or application.status != "APPROVED":
            raise HTTPException(status_code=409, detail="La formule Pro se paie après la validation du justificatif")
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



# ── Pokou certifié Pro ──────────────────────────────────────────────────


def _pro_application(db: Session, user_id: int) -> Optional[CertifiedProApplication]:
    return db.query(CertifiedProApplication).filter(CertifiedProApplication.user_id == user_id).first()


def _pro_json(application: Optional[CertifiedProApplication]) -> dict:
    if application is None:
        return {"status": "NONE", "review_hours": PRO_REVIEW_HOURS}
    return {
        "status": application.status,
        "business_name": application.business_name,
        "activity": application.activity,
        "city": application.city,
        "review_note": application.review_note,
        "submitted_at": application.submitted_at.isoformat(),
        "review_due_at": application.review_due_at.isoformat(),
        "reviewed_at": application.reviewed_at.isoformat() if application.reviewed_at else None,
        "review_hours": PRO_REVIEW_HOURS,
    }


@router.get("/pro/me")
def pro_status(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = _user(db, current_user["user_id"])
    return _pro_json(_pro_application(db, user.id))


@router.post("/pro/apply")
def pro_apply(body: ProApplicationBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Envoyer (ou renvoyer, après « justificatif à corriger ») le dossier."""
    user = _user(db, current_user["user_id"])
    media = db.query(MediaAsset).filter(MediaAsset.id == body.document_media_id, MediaAsset.uploader_id == user.id).first()
    if media is None:
        raise HTTPException(status_code=404, detail="Justificatif introuvable")
    application = _pro_application(db, user.id)
    if application is not None and application.status in ("PENDING", "APPROVED"):
        raise HTTPException(status_code=409, detail="Un dossier est déjà en cours ou validé")
    now = datetime.utcnow()
    if application is None:
        application = CertifiedProApplication(user_id=user.id)
        db.add(application)
    application.business_name = body.business_name.strip()
    application.activity = body.activity.strip()
    application.city = (body.city or "").strip() or None
    application.document_media_id = media.id
    application.status = "PENDING"
    application.review_note = None
    application.submitted_at = now
    application.review_due_at = now + timedelta(hours=PRO_REVIEW_HOURS)
    application.reviewed_at = None
    db.flush()
    record_event(db, "analytics.events", "certified.pro.submitted", {"user_id": user.id}, key=f"user-{user.id}")
    db.commit()
    return _pro_json(application)


def pharmacy_pro(db: Session, user_id: int) -> Optional[Pharmacy]:
    """Le badge Pro est inclus dans l'abonnement d'une officine HONAM : son
    titulaire l'a tant que l'abonnement court."""
    staff = db.query(PharmacyStaff).filter(PharmacyStaff.user_id == user_id, PharmacyStaff.role == "TITULAIRE").first()
    if staff is None:
        return None
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == staff.pharmacy_id).first()
    if pharmacy is None or pharmacy.status == "EXCLUDED":
        return None
    if pharmacy.subscription_until is None or pharmacy.subscription_until < datetime.utcnow():
        return None
    return pharmacy


def public_badge(db: Session, user: User) -> dict:
    """Ce qu'un profil montre : le badge, et pour un Pro le nom commercial
    en premier, puis « Géré par » suivi du nom vérifié (maquette Pro 5)."""
    pharmacy = pharmacy_pro(db, user.id)
    if pharmacy is not None:
        return {"badge": "PRO", "display_name": pharmacy.name, "managed_by": user.full_name, "activity": "Officine"}
    sub = _subscription(db, user.id)
    application = _pro_application(db, user.id)
    if (
        sub is not None and sub.plan in PRO_PLANS and refresh_status(sub) == "ACTIVE"
        and application is not None and application.status == "APPROVED"
    ):
        return {
            "badge": "PRO", "display_name": application.business_name,
            "managed_by": user.full_name, "activity": application.activity,
        }
    return {"badge": "CERTIFIED" if user.is_verified else None, "display_name": user.full_name, "managed_by": None, "activity": None}


@router.get("/profile/{user_id}")
def profile_badge(user_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Profil introuvable")
    return {"user_id": user.id, **public_badge(db, user)}


_TEAM = [UserRole.SUPER_ADMIN, UserRole.ADMIN]


@admin_router.get("/pro/pending")
def pro_pending(current_user: dict = Depends(require_permission_claims("certified.view")), db: Session = Depends(get_db)):
    """Les dossiers à vérifier, le plus proche de son échéance d'abord."""
    rows = (
        db.query(CertifiedProApplication)
        .filter(CertifiedProApplication.status == "PENDING")
        .order_by(CertifiedProApplication.review_due_at)
        .all()
    )
    now = datetime.utcnow()
    names = dict(db.query(User.id, User.full_name).filter(User.id.in_([a.user_id for a in rows])).all()) if rows else {}
    return {"items": [{
        "id": a.id, "user_id": a.user_id, "verified_name": names.get(a.user_id),
        "business_name": a.business_name, "activity": a.activity, "city": a.city,
        "document_media_id": a.document_media_id,
        "review_due_at": a.review_due_at.isoformat(), "overdue": a.review_due_at < now,
    } for a in rows]}


@admin_router.post("/pro/{application_id}/review")
def pro_review(
    application_id: int, body: ProReviewBody,
    current_user: dict = Depends(require_permission_claims("certified.manage")), db: Session = Depends(get_db),
):
    application = db.query(CertifiedProApplication).filter(CertifiedProApplication.id == application_id).first()
    if application is None or application.status != "PENDING":
        raise HTTPException(status_code=404, detail="Dossier introuvable")
    decision = body.decision.upper()
    statuses = {"APPROVE": "APPROVED", "CORRECTION": "CORRECTION", "REJECT": "REJECTED"}
    if decision not in statuses:
        raise HTTPException(status_code=422, detail="Décision inconnue")
    if decision != "APPROVE" and not (body.note or "").strip():
        # « Justificatif à corriger » doit dire QUOI corriger (maquette Pro 4).
        raise HTTPException(status_code=422, detail="Dites à la personne ce qui ne va pas")
    application.status = statuses[decision]
    application.review_note = (body.note or "").strip() or None
    application.reviewed_at = datetime.utcnow()
    application.reviewer_id = current_user["user_id"]
    from app.models import AuditLog
    from app.services.notifications.inbox import notify
    db.add(AuditLog(user_id=current_user["user_id"], action="certified_pro_review", entity_type="certified_pro",
                    entity_id=application.id, changes={"decision": decision, "note": application.review_note}))
    messages = {
        "APPROVE": "Ton dossier Pro est validé : tu peux souscrire la formule Pro.",
        "CORRECTION": f"Ton justificatif Pro est à corriger : {application.review_note}",
        "REJECT": f"Ton dossier Pro n'a pas été retenu. Motif : « {application.review_note} »",
    }
    notify(db, [application.user_id], service="certified", title="Pokou certifié Pro", body=messages[decision])
    db.commit()
    return _pro_json(application)
