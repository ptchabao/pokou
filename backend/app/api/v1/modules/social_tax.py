"""Social Tax — les cagnottes de cérémonie.

**Le reversement à l'organisateur n'est pas automatisé, et ne peut pas
l'être ici.** L'argent arrive sur le compte marchand de Pokou ; le renvoyer
vers un compte Mobile Money tiers est un transfert sortant, que le contrat
Semoa actuel ne couvre pas. Les routes exposent donc `payout` en clair
(« à reverser », mode manuel) plutôt que de laisser croire à un virement
qui n'arrivera pas. C'est le point à régler avant d'ouvrir ce module au
public, pas un détail d'implémentation.
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import CeremonyContribution, CeremonyFund, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.core.security import get_current_user

router = APIRouter(prefix="/ceremonies", tags=["Pokou Social Tax"])

MODULE_SLUG = "social_tax"

KINDS = {"MARIAGE", "BAPTEME", "DEUIL", "AUTRE"}
MIN_CONTRIBUTION = 100
MAX_CONTRIBUTION = 500000
#: Part retenue par Pokou sur ce qui est collecté. Affichée à l'organisateur
#: dès la création : découvrir une commission au moment de récupérer l'argent
#: est la meilleure façon de perdre quelqu'un pour de bon.
PLATFORM_FEE_RATE = 0.05


class FundCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=120)
    description: str | None = Field(None, max_length=500)
    kind: str = Field("AUTRE")
    goal_amount: int | None = Field(None, ge=1000)
    days_open: int = Field(30, ge=1, le=180)


class ContributionCreate(BaseModel):
    amount: int = Field(..., ge=MIN_CONTRIBUTION, le=MAX_CONTRIBUTION)
    message: str | None = Field(None, max_length=280)
    is_anonymous: bool = False


def _payout(fund: CeremonyFund) -> dict:
    fee = int(fund.collected_amount * PLATFORM_FEE_RATE)
    return {
        "collected": fund.collected_amount,
        "platform_fee": fee,
        "due_to_organizer": fund.collected_amount - fee,
        # Dit une fois, en clair, plutôt qu'une promesse implicite.
        "mode": "manual",
        "note": "Le reversement se fait par l'équipe Pokou, sur demande.",
    }


def _fund_json(fund: CeremonyFund, *, viewer_id: int, organizer_name: str | None) -> dict:
    is_organizer = fund.organizer_id == viewer_id
    data = {
        "id": fund.id,
        "title": fund.title,
        "description": fund.description,
        "kind": fund.kind,
        "goal_amount": fund.goal_amount,
        "collected_amount": fund.collected_amount,
        "is_closed": fund.is_closed,
        "is_organizer": is_organizer,
        "organizer_name": organizer_name,
        "created_at": fund.created_at.isoformat(),
        "closes_at": fund.closes_at.isoformat() if fund.closes_at else None,
    }
    if is_organizer:
        data["payout"] = _payout(fund)
    return data


def _get_fund(db: Session, fund_id: int) -> CeremonyFund:
    fund = db.query(CeremonyFund).filter(CeremonyFund.id == fund_id).first()
    if fund is None:
        raise HTTPException(status_code=404, detail="Cagnotte introuvable")
    return fund


@router.post("")
async def create_fund(
    payload: FundCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    kind = payload.kind.upper()
    if kind not in KINDS:
        raise HTTPException(status_code=400, detail="Type de cérémonie inconnu")

    fund = CeremonyFund(
        organizer_id=user_id,
        title=payload.title.strip(),
        description=(payload.description or "").strip() or None,
        kind=kind,
        goal_amount=payload.goal_amount,
        closes_at=datetime.utcnow() + timedelta(days=payload.days_open),
    )
    db.add(fund)
    db.commit()
    db.refresh(fund)
    user = db.query(User).filter(User.id == user_id).first()
    return _fund_json(fund, viewer_id=user_id, organizer_name=user.full_name if user else None)


@router.get("")
async def my_funds(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Celles que j'organise, et celles où j'ai mis quelque chose."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)

    contributed_ids = {
        row[0]
        for row in db.query(CeremonyContribution.fund_id).filter(
            CeremonyContribution.contributor_id == user_id,
            CeremonyContribution.status == "CONFIRMED",
        )
    }
    query = db.query(CeremonyFund).filter(
        (CeremonyFund.organizer_id == user_id) | (CeremonyFund.id.in_(contributed_ids or {-1}))
    )
    funds = query.order_by(CeremonyFund.created_at.desc()).limit(50).all()
    names = {
        u.id: u.full_name
        for u in db.query(User).filter(User.id.in_({f.organizer_id for f in funds} or {-1}))
    }
    return {
        "items": [
            _fund_json(f, viewer_id=user_id, organizer_name=names.get(f.organizer_id))
            for f in funds
        ]
    }


@router.get("/{fund_id}")
async def fund_detail(
    fund_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """La cagnotte et son mur de contributeurs.

    Pas de vérification d'appartenance : une cagnotte se partage par lien, et
    exiger d'être invité empêcherait exactement ce pour quoi elle existe.
    L'activation du module reste requise.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    fund = _get_fund(db, fund_id)

    rows = (
        db.query(CeremonyContribution)
        .filter(
            CeremonyContribution.fund_id == fund.id,
            CeremonyContribution.status == "CONFIRMED",
        )
        .order_by(CeremonyContribution.confirmed_at.desc())
        .limit(200)
        .all()
    )
    names = {
        u.id: (u.full_name or "Contributeur")
        for u in db.query(User).filter(
            User.id.in_({c.contributor_id for c in rows} | {fund.organizer_id})
        )
    }
    wall = [
        {
            "id": c.id,
            "amount": c.amount,
            "message": c.message,
            # L'anonymat masque le NOM, pas le montant : le total doit rester
            # vérifiable par l'organisateur, sinon la cagnotte ne prouve rien.
            "name": None if c.is_anonymous else names.get(c.contributor_id),
            "is_anonymous": c.is_anonymous,
            "is_mine": c.contributor_id == user_id,
            "at": c.confirmed_at.isoformat() if c.confirmed_at else None,
        }
        for c in rows
    ]
    return {
        **_fund_json(fund, viewer_id=user_id, organizer_name=names.get(fund.organizer_id)),
        "contributors": wall,
        "contributor_count": len(wall),
    }


@router.post("/{fund_id}/contribute")
async def contribute(
    fund_id: int,
    payload: ContributionCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    fund = _get_fund(db, fund_id)
    if fund.is_closed:
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    if fund.closes_at and fund.closes_at <= datetime.utcnow():
        raise HTTPException(status_code=409, detail="Cette cagnotte est terminée")

    contribution = CeremonyContribution(
        fund_id=fund.id,
        contributor_id=user_id,
        amount=payload.amount,
        message=(payload.message or "").strip() or None,
        is_anonymous=payload.is_anonymous,
        status="PENDING",
    )
    db.add(contribution)
    db.flush()

    payment = open_payment(
        db, user_id,
        kind="CEREMONY_CONTRIBUTION",
        amount=payload.amount,
        description=f"Cagnotte — {fund.title}",
        metadata={"module": MODULE_SLUG, "contribution_id": contribution.id, "fund_id": fund.id},
    )
    contribution.payment_id = payment.id
    db.commit()
    return {"contribution_id": contribution.id, **payment_json(payment)}


@router.post("/{fund_id}/close")
async def close_fund(
    fund_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    fund = _get_fund(db, fund_id)
    if fund.organizer_id != user_id:
        raise HTTPException(status_code=403, detail="Vous n'organisez pas cette cagnotte")
    fund.is_closed = True
    db.commit()
    return _fund_json(fund, viewer_id=user_id, organizer_name=None)


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    contribution_id = (payment.metadata_json or {}).get("contribution_id")
    if not contribution_id:
        return None
    contribution = (
        db.query(CeremonyContribution)
        .filter(CeremonyContribution.id == int(contribution_id))
        .first()
    )
    if contribution is None or contribution.status != "PENDING":
        return None
    contribution.status = "CONFIRMED"
    contribution.confirmed_at = datetime.utcnow()
    fund = db.query(CeremonyFund).filter(CeremonyFund.id == contribution.fund_id).first()
    if fund is not None:
        # Le total suit la contribution CONFIRMÉE, jamais l'intention : une
        # cagnotte qui affiche de l'argent non encaissé ment à l'organisateur.
        fund.collected_amount += contribution.amount
    return {
        "contribution_id": contribution.id,
        "fund_id": contribution.fund_id,
        "collected_amount": fund.collected_amount if fund else None,
    }
