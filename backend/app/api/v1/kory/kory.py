"""Kory — le journal des cagnottes et des cotisations.

Aucune route ici ne déplace d'argent, et aucune ne le pourra : il n'y a ni
solde, ni retrait, ni intention de paiement (BM-01). Un membre DÉCLARE avoir
envoyé une somme au collecteur, depuis son propre wallet ; le collecteur
CONFIRME l'avoir reçue. Le total affiché est la somme des confirmations.

Qui voit une cagnotte : l'organisateur, le collecteur, les membres du groupe
rattaché et ceux qui l'ont rejointe par son code. Les autres reçoivent 404,
pour ne pas révéler qu'elle existe.
"""
import secrets
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.countries import module_open
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import GroupMember, KoryEntry, KoryMember, KoryPot, User
from app.services.events.outbox import record_event

router = APIRouter(prefix="/kory", tags=["Pokou Kory"])

#: Le flux Kafka de Kory. Clé = la cagnotte : ses évènements restent
#: ordonnés. Aucune donnée de contact ni référence de transaction n'y entre :
#: les consommateurs (statistiques, notifications) n'en ont pas besoin.
EVENTS_TOPIC = "kory.events"

KINDS = {"CAGNOTTE", "COTISATION"}
PERIODS = {"WEEKLY", "MONTHLY"}
MAX_AMOUNT = 10_000_000
#: Sans 0, O, 1, I : un code se dicte au téléphone.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class PotCreate(BaseModel):
    kind: str = Field("CAGNOTTE")
    title: str = Field(..., min_length=3, max_length=120)
    description: Optional[str] = Field(None, max_length=500)
    group_id: Optional[int] = None
    collector_id: Optional[int] = None
    goal_amount: Optional[int] = Field(None, ge=100, le=MAX_AMOUNT)
    amount_per_member: Optional[int] = Field(None, ge=100, le=MAX_AMOUNT)
    period: Optional[str] = None
    due_at: Optional[datetime] = None


class EntryCreate(BaseModel):
    amount: int = Field(..., ge=1, le=MAX_AMOUNT)
    wallet_reference: Optional[str] = Field(None, max_length=64)
    period_label: Optional[str] = Field(None, max_length=12)
    note: Optional[str] = Field(None, max_length=280)


class EntryReview(BaseModel):
    decision: str  # CONFIRM|REJECT


class JoinBody(BaseModel):
    code: str = Field(..., min_length=4, max_length=12)


def _me(current_user: dict) -> int:
    return current_user["user_id"]


def _require_kory_open(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not module_open(db, user.phone, "kory"):
        raise HTTPException(status_code=404, detail="Kory n'est pas disponible dans votre pays")
    return user


def _is_group_member(db: Session, group_id: Optional[int], user_id: int) -> bool:
    if group_id is None:
        return False
    return db.query(GroupMember.id).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first() is not None


def _can_see(db: Session, pot: KoryPot, user_id: int) -> bool:
    if user_id in (pot.organizer_id, pot.collector_id):
        return True
    if _is_group_member(db, pot.group_id, user_id):
        return True
    return db.query(KoryMember.id).filter(
        KoryMember.pot_id == pot.id, KoryMember.user_id == user_id
    ).first() is not None


def _get_visible_pot(db: Session, pot_id: int, user_id: int) -> KoryPot:
    pot = db.query(KoryPot).filter(KoryPot.id == pot_id).first()
    if pot is None or not _can_see(db, pot, user_id):
        raise HTTPException(status_code=404, detail="Cagnotte introuvable")
    return pot


def _name(db: Session, user_id: int) -> Optional[str]:
    user = db.query(User).filter(User.id == user_id).first()
    return user.full_name if user else None


def _new_code(db: Session) -> str:
    while True:
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))
        if not db.query(KoryPot.id).filter(KoryPot.join_code == code).first():
            return code


def _confirmed_total(db: Session, pot_id: int, contributor_id: Optional[int] = None) -> int:
    query = db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.status == "CONFIRMED"
    )
    if contributor_id is not None:
        query = query.filter(KoryEntry.contributor_id == contributor_id)
    return int(query.scalar() or 0)


def _pending_count(db: Session, pot_id: int) -> int:
    return db.query(func.count(KoryEntry.id)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.status == "DECLARED"
    ).scalar() or 0


def _entry_json(db: Session, entry: KoryEntry, viewer_id: int, pot: KoryPot) -> dict:
    data = {
        "id": entry.id,
        "contributor_id": entry.contributor_id,
        "contributor_name": _name(db, entry.contributor_id),
        "amount": entry.amount,
        "period_label": entry.period_label,
        "note": entry.note,
        "status": entry.status,
        "declared_at": entry.declared_at.isoformat(),
        "reviewed_at": entry.reviewed_at.isoformat() if entry.reviewed_at else None,
        "is_mine": entry.contributor_id == viewer_id,
    }
    # La référence de transaction ne sert qu'au rapprochement : le collecteur
    # et l'auteur la voient, pas tout le groupe.
    if viewer_id in (entry.contributor_id, pot.collector_id):
        data["wallet_reference"] = entry.wallet_reference
    return data


def _emit(db: Session, pot: KoryPot, event_type: str, **data) -> None:
    record_event(
        db,
        EVENTS_TOPIC,
        event_type,
        {"pot_id": pot.id, "group_id": pot.group_id, "kind": pot.kind, **data},
        key=f"pot-{pot.id}",
    )


def _pot_json(db: Session, pot: KoryPot, viewer_id: int, *, with_entries: bool = False) -> dict:
    total = _confirmed_total(db, pot.id)
    data = {
        "id": pot.id,
        "kind": pot.kind,
        "title": pot.title,
        "description": pot.description,
        "group_id": pot.group_id,
        "organizer_id": pot.organizer_id,
        "organizer_name": _name(db, pot.organizer_id),
        "collector_id": pot.collector_id,
        "collector_name": _name(db, pot.collector_id),
        "goal_amount": pot.goal_amount,
        "amount_per_member": pot.amount_per_member,
        "period": pot.period,
        "due_at": pot.due_at.isoformat() if pot.due_at else None,
        "status": pot.status,
        "confirmed_total": total,
        "my_confirmed_total": _confirmed_total(db, pot.id, viewer_id),
        "pending_count": _pending_count(db, pot.id) if viewer_id == pot.collector_id else None,
        "is_organizer": viewer_id == pot.organizer_id,
        "is_collector": viewer_id == pot.collector_id,
        "join_code": pot.join_code,
        "created_at": pot.created_at.isoformat(),
        "closed_at": pot.closed_at.isoformat() if pot.closed_at else None,
    }
    # Le numéro du collecteur est ce à quoi on envoie l'argent : visible
    # des seuls participants, ce que `_get_visible_pot` a déjà vérifié.
    collector = db.query(User).filter(User.id == pot.collector_id).first()
    data["collector_phone"] = collector.phone if collector else None
    if with_entries:
        entries = (
            db.query(KoryEntry)
            .filter(KoryEntry.pot_id == pot.id)
            .order_by(KoryEntry.declared_at.desc(), KoryEntry.id.desc())
            .all()
        )
        data["entries"] = [_entry_json(db, e, viewer_id, pot) for e in entries]
    return data


@router.post("/pots", status_code=201)
def create_pot(
    body: PotCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me = _me(current_user)
    _require_kory_open(db, me)
    kind = body.kind.upper()
    if kind == "TONTINE":
        # Kory Plus, ouvert au mois 13 (BM-13) : refusé tant que le pays ne
        # l'a pas, plutôt que de créer une tontine que personne ne peut payer.
        raise HTTPException(status_code=403, detail="La tontine en rotation demande Kory Plus")
    if kind not in KINDS:
        raise HTTPException(status_code=422, detail="Type de cagnotte inconnu")
    if kind == "COTISATION":
        if body.amount_per_member is None or (body.period or "").upper() not in PERIODS:
            raise HTTPException(status_code=422, detail="Une cotisation demande un montant et une période")
    if body.group_id is not None and not _is_group_member(db, body.group_id, me):
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")

    collector_id = body.collector_id or me
    if collector_id != me:
        # Le collecteur reçoit l'argent : il doit faire partie du groupe, et
        # une cagnotte sans groupe ne peut avoir que son organisateur comme
        # collecteur — on ne désigne pas un inconnu.
        if body.group_id is None or not _is_group_member(db, body.group_id, collector_id):
            raise HTTPException(status_code=422, detail="Le collecteur doit être membre du groupe")

    pot = KoryPot(
        group_id=body.group_id,
        organizer_id=me,
        collector_id=collector_id,
        kind=kind,
        title=body.title.strip(),
        description=(body.description or "").strip() or None,
        goal_amount=body.goal_amount if kind == "CAGNOTTE" else None,
        amount_per_member=body.amount_per_member if kind == "COTISATION" else None,
        period=((body.period or "").upper() or None) if kind == "COTISATION" else None,
        due_at=body.due_at,
        join_code=_new_code(db),
    )
    db.add(pot)
    db.flush()
    _emit(db, pot, "kory.pot.created", organizer_id=me, collector_id=collector_id)
    db.commit()
    db.refresh(pot)
    return _pot_json(db, pot, me, with_entries=True)


@router.get("/pots")
def list_pots(
    group_id: Optional[int] = None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me = _me(current_user)
    _require_kory_open(db, me)
    my_groups = db.query(GroupMember.group_id).filter(GroupMember.user_id == me)
    joined = db.query(KoryMember.pot_id).filter(KoryMember.user_id == me)
    query = db.query(KoryPot).filter(
        or_(
            KoryPot.organizer_id == me,
            KoryPot.collector_id == me,
            KoryPot.group_id.in_(my_groups),
            KoryPot.id.in_(joined),
        )
    )
    if group_id is not None:
        query = query.filter(KoryPot.group_id == group_id)
    pots = query.order_by(KoryPot.status.desc(), KoryPot.created_at.desc()).limit(100).all()
    return {"items": [_pot_json(db, pot, me) for pot in pots]}


@router.get("/summary")
def summary(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le total de MES contributions confirmées du mois (écran APP-3).

    « Mes contributions », jamais « mon solde » : rien n'est détenu.
    """
    me = _me(current_user)
    _require_kory_open(db, me)
    now = datetime.utcnow()
    month_start = datetime(now.year, now.month, 1)
    total = db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.contributor_id == me,
        KoryEntry.status == "CONFIRMED",
        KoryEntry.reviewed_at >= month_start,
    ).scalar()
    to_review = db.query(func.count(KoryEntry.id)).join(
        KoryPot, KoryPot.id == KoryEntry.pot_id
    ).filter(KoryPot.collector_id == me, KoryEntry.status == "DECLARED").scalar()
    return {"month_confirmed_total": int(total or 0), "to_review_count": int(to_review or 0)}


@router.get("/pots/{pot_id}")
def get_pot(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _me(current_user)
    _require_kory_open(db, me)
    return _pot_json(db, _get_visible_pot(db, pot_id, me), me, with_entries=True)


@router.post("/join")
def join_pot(body: JoinBody, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = db.query(KoryPot).filter(KoryPot.join_code == body.code.strip().upper()).first()
    if pot is None or pot.status != "OPEN":
        raise HTTPException(status_code=404, detail="Code inconnu ou cagnotte clôturée")
    if not _can_see(db, pot, me):
        db.add(KoryMember(pot_id=pot.id, user_id=me))
        db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/entries", status_code=201)
def declare_entry(
    pot_id: int,
    body: EntryCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    entry = KoryEntry(
        pot_id=pot.id,
        contributor_id=me,
        amount=body.amount,
        wallet_reference=(body.wallet_reference or "").strip() or None,
        period_label=(body.period_label or "").strip() or None,
        note=(body.note or "").strip() or None,
    )
    # Le collecteur qui note ce qu'il a lui-même mis dans la cagnotte n'a
    # personne à qui le faire confirmer : c'est confirmé d'emblée.
    if me == pot.collector_id:
        entry.status = "CONFIRMED"
        entry.reviewed_at = datetime.utcnow()
    db.add(entry)
    db.flush()
    _emit(
        db, pot, "kory.entry.declared",
        entry_id=entry.id, contributor_id=me, amount=entry.amount, status=entry.status,
    )
    db.commit()
    db.refresh(entry)
    return _entry_json(db, entry, me, pot)


@router.post("/pots/{pot_id}/entries/{entry_id}/review")
def review_entry(
    pot_id: int,
    entry_id: int,
    body: EntryReview,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me != pot.collector_id:
        raise HTTPException(status_code=403, detail="Seul le collecteur confirme une contribution")
    entry = db.query(KoryEntry).filter(KoryEntry.id == entry_id, KoryEntry.pot_id == pot.id).first()
    if entry is None:
        raise HTTPException(status_code=404, detail="Contribution introuvable")
    if entry.status != "DECLARED":
        raise HTTPException(status_code=409, detail="Contribution déjà traitée")
    decision = body.decision.upper()
    if decision not in ("CONFIRM", "REJECT"):
        raise HTTPException(status_code=422, detail="Décision inconnue")
    entry.status = "CONFIRMED" if decision == "CONFIRM" else "REJECTED"
    entry.reviewed_at = datetime.utcnow()
    _emit(
        db, pot, f"kory.entry.{entry.status.lower()}",
        entry_id=entry.id, contributor_id=entry.contributor_id, amount=entry.amount,
    )
    db.commit()
    return _entry_json(db, entry, me, pot)


@router.post("/pots/{pot_id}/close")
def close_pot(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me != pot.organizer_id:
        raise HTTPException(status_code=403, detail="Seul l'organisateur clôture la cagnotte")
    if pot.status != "CLOSED":
        pot.status = "CLOSED"
        pot.closed_at = datetime.utcnow()
        _emit(db, pot, "kory.pot.closed", confirmed_total=_confirmed_total(db, pot.id))
        db.commit()
    return _pot_json(db, pot, me, with_entries=True)
