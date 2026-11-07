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
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.countries import module_open
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import GroupMember, KoryEntry, KoryInvite, KoryMember, KoryPot, KoryRound, User
from app.services.events.outbox import record_event
from app.services.notifications.inbox import notify

router = APIRouter(prefix="/kory", tags=["Pokou Kory"])

#: Le flux Kafka de Kory. Clé = la cagnotte : ses évènements restent
#: ordonnés. Aucune donnée de contact ni référence de transaction n'y entre :
#: les consommateurs (statistiques, notifications) n'en ont pas besoin.
EVENTS_TOPIC = "kory.events"

KINDS = {"CAGNOTTE", "COTISATION", "TONTINE"}
PERIODS = {"WEEKLY", "MONTHLY"}
_PERIOD_DAYS = {"WEEKLY": 7, "MONTHLY": 30}
#: Une tontine se tient entre gens qui se connaissent : au moins 2 tours,
#: et pas plus que ce qu'un groupe de discussion tient raisonnablement.
MIN_ROUNDS, MAX_ROUNDS = 2, 50
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
    #: Tontine : l'ordre des bénéficiaires, tour par tour. Fixé à
    #: l'ouverture, il ne change plus (maquette Kory 8).
    rotation: Optional[List[int]] = Field(None, max_length=MAX_ROUNDS)
    starts_at: Optional[datetime] = None


class EntryCreate(BaseModel):
    amount: int = Field(..., ge=1, le=MAX_AMOUNT)
    wallet_reference: Optional[str] = Field(None, max_length=64)
    period_label: Optional[str] = Field(None, max_length=12)
    note: Optional[str] = Field(None, max_length=280)


class EntryReview(BaseModel):
    decision: str  # CONFIRM|REJECT
    #: Motif du refus, montré au contributeur (KOR-5).
    reason: Optional[str] = Field(None, max_length=280)


class EntryResubmit(BaseModel):
    """KOR-5 : le contributeur corrige sa référence ou joint la capture du
    SMS ; la contribution redevient « à confirmer »."""
    wallet_reference: Optional[str] = Field(None, max_length=64)
    note: Optional[str] = Field(None, max_length=280)
    proof_media_id: Optional[int] = None


class PledgeBody(BaseModel):
    base: int = Field(..., ge=100, le=MAX_AMOUNT)
    daily: Optional[int] = Field(None, ge=0, le=MAX_AMOUNT)


class ExtendBody(BaseModel):
    due_at: datetime


class InvitePhone(BaseModel):
    phone: str = Field(..., min_length=6, max_length=32)
    name: Optional[str] = Field(None, max_length=120)


class ParticipantsBody(BaseModel):
    """KOR-11 : des personnes de Pokou (par identifiant) et d'autres par
    leur numéro."""
    user_ids: List[int] = Field(default_factory=list, max_length=200)
    phones: List[InvitePhone] = Field(default_factory=list, max_length=200)


#: KORY-13 : un engagement se corrige pendant 8 h, compté par le serveur.
PLEDGE_EDIT_WINDOW = timedelta(hours=8)


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


def _declared_total(db: Session, pot_id: int) -> int:
    """« Total déclaré » : ce que les membres disent avoir envoyé, confirmé
    ou non. Jamais un solde : c'est une somme de déclarations."""
    return int(db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.status.in_(("DECLARED", "CONFIRMED"))
    ).scalar() or 0)


def _pending_count(db: Session, pot_id: int) -> int:
    return db.query(func.count(KoryEntry.id)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.status == "DECLARED"
    ).scalar() or 0


def _entry_reviewer(db: Session, pot: KoryPot, entry: KoryEntry) -> int:
    if pot.kind == "TONTINE" and entry.round_number is not None:
        round_ = db.query(KoryRound).filter(
            KoryRound.pot_id == pot.id, KoryRound.number == entry.round_number
        ).first()
        if round_ is not None:
            return round_.beneficiary_id
    return pot.collector_id


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
        "round_number": entry.round_number,
        "review_reason": entry.review_reason,
        "proof_media_id": entry.proof_media_id,
    }
    reviewer_id = _entry_reviewer(db, pot, entry)
    data["can_review"] = viewer_id == reviewer_id and entry.status == "DECLARED"
    # La référence de transaction ne sert qu'au rapprochement : le collecteur
    # et l'auteur la voient, pas tout le groupe.
    if viewer_id in (entry.contributor_id, reviewer_id):
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


def _fcfa(amount: int) -> str:
    return f"{amount:,}".replace(",", " ") + " FCFA"


def _participants(db: Session, pot: KoryPot) -> set:
    """Tous ceux qui suivent la cagnotte : collecteur, organisateur, membres
    par code et membres du groupe rattaché."""
    users = {pot.collector_id, pot.organizer_id} | {
        uid for (uid,) in db.query(KoryMember.user_id).filter(KoryMember.pot_id == pot.id)
    }
    if pot.group_id:
        users |= {uid for (uid,) in db.query(GroupMember.user_id).filter(GroupMember.group_id == pot.group_id)}
    return {u for u in users if u}


def _mask(phone: Optional[str]) -> str:
    """« +228 91 •• •• 07 » : assez pour reconnaître, pas pour recopier."""
    digits = (phone or "").replace(" ", "")
    if len(digits) < 8:
        return "••"
    return f"{digits[:4]} {digits[4:6]} •• •• {digits[-2:]}"


def _participants_json(db: Session, pot: KoryPot) -> list:
    members = [
        {"user_id": m.user_id, "name": _name(db, m.user_id) or "Pokou", "on_pokou": True,
         "is_collector": m.user_id == pot.collector_id}
        for m in db.query(KoryMember).filter(KoryMember.pot_id == pot.id).all()
    ]
    invited = [
        {"invite_id": i.id, "name": i.display_name or _mask(i.phone), "phone": _mask(i.phone),
         "on_pokou": False, "is_collector": False}
        for i in db.query(KoryInvite).filter(KoryInvite.pot_id == pot.id, KoryInvite.joined_user_id.is_(None)).all()
    ]
    return members + invited


def _notify(db: Session, pot: KoryPot, user_ids, body: str) -> None:
    notify(db, user_ids, service="kory", title=pot.title, body=body, route=f"kory/{pot.id}")


def _pledge_days(pot: KoryPot, member: KoryMember) -> int:
    """Le nombre de jours où le montant journalier s'ajoute : de la date
    d'engagement à la date de fin (KOR-12 : « 500 FCFA × 6 jours »)."""
    if not member.pledge_daily or not pot.due_at or not member.pledged_at:
        return 0
    return max((pot.due_at.date() - member.pledged_at.date()).days, 0)


def _pledge_total(pot: KoryPot, member: KoryMember) -> int:
    return (member.pledge_base or 0) + (member.pledge_daily or 0) * _pledge_days(pot, member)


def _active_pledges(db: Session, pot: KoryPot) -> List[KoryMember]:
    return db.query(KoryMember).filter(
        KoryMember.pot_id == pot.id,
        KoryMember.pledged_at.isnot(None),
        KoryMember.pledge_cancelled_at.is_(None),
    ).all()


def _is_firm(member: KoryMember, now: datetime) -> bool:
    return member.pledged_at is not None and now >= member.pledged_at + PLEDGE_EDIT_WINDOW


def _owes_after_close(db: Session, pot: KoryPot, user_id: int) -> bool:
    """KOR-16 : après la clôture, un participant engagé peut encore déclarer
    ce qu'il lui reste à verser — et rien d'autre."""
    if pot.kind == "TONTINE":
        return False
    member = db.query(KoryMember).filter(
        KoryMember.pot_id == pot.id, KoryMember.user_id == user_id,
        KoryMember.pledged_at.isnot(None), KoryMember.pledge_cancelled_at.is_(None),
    ).first()
    return member is not None and _pledge_total(pot, member) > _confirmed_total(db, pot.id, user_id)


def _pledge_json(db: Session, pot: KoryPot, member: KoryMember, now: datetime) -> dict:
    total = _pledge_total(pot, member)
    confirmed = _confirmed_total(db, pot.id, member.user_id)
    firm_at = member.pledged_at + PLEDGE_EDIT_WINDOW
    next_add = None
    if member.pledge_daily and pot.due_at and now < pot.due_at and pot.status == "OPEN":
        next_add = (now + timedelta(days=1)).date().isoformat()
    return {
        "base": member.pledge_base,
        "daily": member.pledge_daily,
        "days": _pledge_days(pot, member),
        "total": total,
        "pledged_at": member.pledged_at.isoformat(),
        "firm_at": firm_at.isoformat(),
        "is_firm": _is_firm(member, now),
        "confirmed": confirmed,
        # KORY-13 : reste à verser = engagé − confirmé.
        "remaining": max(total - confirmed, 0),
        "next_daily_add": next_add,
    }


def _pledge_summary(db: Session, pot: KoryPot, now: datetime) -> dict:
    """La vue du collecteur (KOR-15). Il ne voit que les engagements
    FERMES : pendant 8 h, un engagement reste l'affaire de son auteur."""
    firm = [m for m in _active_pledges(db, pot) if _is_firm(m, now)]
    remaining = [(m, max(_pledge_total(pot, m) - _confirmed_total(db, pot.id, m.user_id), 0)) for m in firm]
    to_confirm = db.query(
        func.coalesce(func.sum(KoryEntry.amount), 0), func.count(KoryEntry.id)
    ).filter(KoryEntry.pot_id == pot.id, KoryEntry.status == "DECLARED").one()
    return {
        "engaged_total": sum(_pledge_total(pot, m) for m in firm),
        "engaged_count": len(firm),
        "confirmed_total": _confirmed_total(db, pot.id),
        "to_confirm_total": int(to_confirm[0] or 0),
        "to_confirm_count": int(to_confirm[1] or 0),
        "remaining_total": sum(r for _, r in remaining),
        "remaining_count": sum(1 for _, r in remaining if r > 0),
        "pledges": [
            {
                "user_id": m.user_id,
                "name": _name(db, m.user_id),
                "total": _pledge_total(pot, m),
                "remaining": r,
            }
            for m, r in remaining
        ],
    }


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
        "declared_total": _declared_total(db, pot.id),
        # « Reste à collecter » : vers l'objectif, à partir du confirmé.
        "remaining_to_collect": max(pot.goal_amount - total, 0) if pot.goal_amount else None,
        "my_confirmed_total": _confirmed_total(db, pot.id, viewer_id),
        "pending_count": _pending_count(db, pot.id) if viewer_id == pot.collector_id else None,
        "is_organizer": viewer_id == pot.organizer_id,
        "is_collector": viewer_id == pot.collector_id,
        # Une tontine ne se rejoint pas par code : l'ordre des tours est
        # fixé entre les membres du groupe.
        "join_code": pot.join_code if pot.kind != "TONTINE" else None,
        "created_at": pot.created_at.isoformat(),
        "closed_at": pot.closed_at.isoformat() if pot.closed_at else None,
        "extended_at": pot.extended_at.isoformat() if pot.extended_at else None,
    }
    # KOR-11 : les participants, numéros masqués (KORY-15).
    if viewer_id in (pot.organizer_id, pot.collector_id):
        data["participants"] = _participants_json(db, pot)
    # Engagements (KOR-12 à 16). L'heure du SERVEUR accompagne la réponse :
    # le délai de 8 h ne dépend pas de l'horloge du téléphone.
    now = datetime.utcnow()
    data["server_now"] = now.isoformat()
    data["is_due"] = bool(pot.due_at and now >= pot.due_at and pot.status == "OPEN")
    if pot.kind != "TONTINE":
        mine = db.query(KoryMember).filter(
            KoryMember.pot_id == pot.id,
            KoryMember.user_id == viewer_id,
            KoryMember.pledged_at.isnot(None),
            KoryMember.pledge_cancelled_at.is_(None),
        ).first()
        data["my_pledge"] = _pledge_json(db, pot, mine, now) if mine else None
        if viewer_id in (pot.collector_id, pot.organizer_id):
            data["pledge_summary"] = _pledge_summary(db, pot, now)
    # Le numéro du collecteur est ce à quoi on envoie l'argent : visible
    # des seuls participants, ce que `_get_visible_pot` a déjà vérifié.
    collector = db.query(User).filter(User.id == pot.collector_id).first()
    data["collector_phone"] = collector.phone if collector else None
    if pot.kind == "TONTINE":
        data["rounds"] = _rounds_json(db, pot)
        current = next((r for r in data["rounds"] if r["status"] == "CURRENT"), None)
        data["current_round"] = current["number"] if current else None
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
    if kind not in KINDS:
        raise HTTPException(status_code=422, detail="Type de cagnotte inconnu")
    if kind == "TONTINE":
        return _create_tontine(db, me, body)
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


def _round_total(db: Session, pot_id: int, number: int) -> int:
    return int(db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.round_number == number, KoryEntry.status == "CONFIRMED",
    ).scalar() or 0)


def _rounds_json(db: Session, pot: KoryPot) -> list:
    rounds = db.query(KoryRound).filter(KoryRound.pot_id == pot.id).order_by(KoryRound.number).all()
    # Chaque tour, chacun des autres membres mise : le bénéficiaire reçoit
    # la mise de tous sauf la sienne.
    expected = (pot.amount_per_member or 0) * max(len(rounds) - 1, 0)
    return [{
        "number": r.number,
        "beneficiary_id": r.beneficiary_id,
        "beneficiary_name": _name(db, r.beneficiary_id),
        "due_at": r.due_at.isoformat() if r.due_at else None,
        "status": r.status,
        "confirmed_total": _round_total(db, pot.id, r.number),
        "expected_total": expected,
    } for r in rounds]


def _current_round(db: Session, pot: KoryPot) -> Optional[KoryRound]:
    return db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.status == "CURRENT").first()


def _create_tontine(db: Session, me: int, body: PotCreate) -> dict:
    """Kory Plus (BM-13), ouvert par pays (mois 13). Tenue comme le reste de
    Kory : un journal, jamais un solde. Chaque tour, les membres envoient
    leur mise au wallet du bénéficiaire, qui confirme seul ce qu'il a reçu."""
    user = db.query(User).filter(User.id == me).first()
    if not module_open(db, user.phone, "kory_plus"):
        raise HTTPException(status_code=403, detail="La tontine en rotation demande Kory Plus")
    period = (body.period or "").upper()
    if body.amount_per_member is None or period not in PERIODS:
        raise HTTPException(status_code=422, detail="Une tontine demande une mise et une période")
    if body.group_id is None or not _is_group_member(db, body.group_id, me):
        raise HTTPException(status_code=422, detail="Une tontine s'ouvre depuis un groupe dont vous êtes membre")
    rotation = list(body.rotation or [])
    if len(rotation) < MIN_ROUNDS or len(set(rotation)) != len(rotation):
        raise HTTPException(status_code=422, detail="L'ordre des tours doit nommer au moins deux membres, chacun une fois")
    if any(not _is_group_member(db, body.group_id, uid) for uid in rotation):
        raise HTTPException(status_code=422, detail="Chaque bénéficiaire doit être membre du groupe")
    start = body.starts_at or datetime.utcnow()
    pot = KoryPot(
        group_id=body.group_id, organizer_id=me, collector_id=rotation[0], kind="TONTINE",
        title=body.title.strip(), description=(body.description or "").strip() or None,
        amount_per_member=body.amount_per_member, period=period, join_code=_new_code(db),
    )
    db.add(pot)
    db.flush()
    for index, beneficiary in enumerate(rotation):
        db.add(KoryRound(
            pot_id=pot.id, number=index + 1, beneficiary_id=beneficiary,
            due_at=start + timedelta(days=_PERIOD_DAYS[period] * (index + 1)),
            status="CURRENT" if index == 0 else "UPCOMING",
        ))
    db.flush()
    _emit(db, pot, "kory.pot.created", organizer_id=me, collector_id=rotation[0], rounds=len(rotation))
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
    if pot is None or pot.status != "OPEN" or pot.kind == "TONTINE":
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
    if pot.status != "OPEN" and not _owes_after_close(db, pot, me):
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    round_number = None
    if pot.kind == "TONTINE":
        current = _current_round(db, pot)
        if current is None:
            raise HTTPException(status_code=409, detail="Aucun tour en cours")
        if current.beneficiary_id == me:
            raise HTTPException(status_code=409, detail="C'est votre tour : vous recevez, vous ne misez pas")
        round_number = current.number
    entry = KoryEntry(
        round_number=round_number,
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
    if entry.status == "DECLARED":
        reviewer = _entry_reviewer(db, pot, entry)
        _notify(db, pot, [reviewer], f"{_name(db, me) or 'Un membre'} a déclaré {_fcfa(entry.amount)}. À confirmer.")
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
    entry = db.query(KoryEntry).filter(KoryEntry.id == entry_id, KoryEntry.pot_id == pot.id).first()
    if entry is None:
        raise HTTPException(status_code=404, detail="Contribution introuvable")
    # Dans une tontine, c'est le bénéficiaire DU TOUR de la contribution qui
    # confirme — y compris après le passage au tour suivant.
    reviewer_id = _entry_reviewer(db, pot, entry)
    if me != reviewer_id:
        raise HTTPException(status_code=403, detail="Seul le collecteur confirme une contribution")
    if entry.status != "DECLARED":
        raise HTTPException(status_code=409, detail="Contribution déjà traitée")
    decision = body.decision.upper()
    if decision not in ("CONFIRM", "REJECT"):
        raise HTTPException(status_code=422, detail="Décision inconnue")
    entry.status = "CONFIRMED" if decision == "CONFIRM" else "REJECTED"
    entry.reviewed_at = datetime.utcnow()
    entry.review_reason = (
        (body.reason or "").strip() or None if decision == "REJECT" else None
    )
    _emit(
        db, pot, f"kory.entry.{entry.status.lower()}",
        entry_id=entry.id, contributor_id=entry.contributor_id, amount=entry.amount,
    )
    reviewer_name = _name(db, me) or "Le collecteur"
    _notify(
        db, pot, [entry.contributor_id],
        f"{reviewer_name} a confirmé tes {_fcfa(entry.amount)}." if entry.status == "CONFIRMED"
        else f"{reviewer_name} n’a pas constaté ton envoi de {_fcfa(entry.amount)}.",
    )
    db.commit()
    return _entry_json(db, entry, me, pot)


@router.post("/pots/{pot_id}/next-round")
def next_round(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'organisateur passe au tour suivant. Le dernier tour clôt la
    tontine. Les contributions déjà déclarées restent au journal, à
    confirmer par le bénéficiaire de leur tour."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind != "TONTINE":
        raise HTTPException(status_code=409, detail="Seule une tontine a des tours")
    if me != pot.organizer_id:
        raise HTTPException(status_code=403, detail="Seul l'organisateur passe au tour suivant")
    current = _current_round(db, pot)
    if current is None or pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette tontine est terminée")
    now = datetime.utcnow()
    current.status = "DONE"
    current.closed_at = now
    following = db.query(KoryRound).filter(
        KoryRound.pot_id == pot.id, KoryRound.number == current.number + 1
    ).first()
    if following is None:
        pot.status = "CLOSED"
        pot.closed_at = now
        _emit(db, pot, "kory.pot.closed", rounds=current.number)
    else:
        following.status = "CURRENT"
        pot.collector_id = following.beneficiary_id
        _emit(db, pot, "kory.round.started", number=following.number, beneficiary_id=following.beneficiary_id)
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/close")
def close_pot(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me not in (pot.organizer_id, pot.collector_id):
        raise HTTPException(status_code=403, detail="Seul le collecteur clôture la cagnotte")
    if pot.status != "CLOSED":
        pot.status = "CLOSED"
        pot.closed_at = datetime.utcnow()
        _emit(db, pot, "kory.pot.closed", confirmed_total=_confirmed_total(db, pot.id))
        # KOR-16 : chacun est prévenu, avec ce qu'il lui reste à verser.
        closer = _name(db, me) or "Le collecteur"
        now = datetime.utcnow()
        for member in _active_pledges(db, pot):
            remaining = max(_pledge_total(pot, member) - _confirmed_total(db, pot.id, member.user_id), 0)
            if member.user_id != me and remaining > 0:
                _notify(db, pot, [member.user_id], f"{closer} a clôturé la collecte. Il te reste {_fcfa(remaining)} à verser.")
        pledged = {m.user_id for m in _active_pledges(db, pot)}
        others = _participants(db, pot) - pledged - {me}
        _notify(db, pot, others, f"{closer} a clôturé la collecte.")
        db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.put("/pots/{pot_id}/pledge")
def set_pledge(
    pot_id: int,
    body: PledgeBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-12 et 13 : s'engager, ou corriger son engagement pendant 8 h."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind == "TONTINE":
        raise HTTPException(status_code=409, detail="Une tontine a un montant fixe par tour")
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    if body.daily and not pot.due_at:
        raise HTTPException(status_code=422, detail="Un montant journalier demande une date de fin")
    now = datetime.utcnow()
    member = db.query(KoryMember).filter(KoryMember.pot_id == pot.id, KoryMember.user_id == me).first()
    if member is None:
        # Membre par le groupe rattaché : il n'a pas encore de ligne.
        member = KoryMember(pot_id=pot.id, user_id=me)
        db.add(member)
    active = member.pledged_at is not None and member.pledge_cancelled_at is None
    if active and _is_firm(member, now):
        raise HTTPException(
            status_code=409,
            detail="Ton engagement est ferme : seul le collecteur peut l'annuler",
        )
    if not active:
        member.pledged_at = now
        member.pledge_cancelled_at = None
    member.pledge_base = body.base
    member.pledge_daily = body.daily or None
    db.flush()
    _emit(db, pot, "kory.pledge.saved", user_id=me, total=_pledge_total(pot, member))
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/pledges/{user_id}/cancel")
def cancel_pledge(
    pot_id: int,
    user_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-14 : un engagement ferme ne s'annule que par le collecteur, et
    c'est noté au journal (évènement)."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me != pot.collector_id:
        raise HTTPException(status_code=403, detail="Seul le collecteur annule un engagement")
    member = db.query(KoryMember).filter(
        KoryMember.pot_id == pot.id, KoryMember.user_id == user_id,
        KoryMember.pledged_at.isnot(None), KoryMember.pledge_cancelled_at.is_(None),
    ).first()
    if member is None:
        raise HTTPException(status_code=404, detail="Engagement introuvable")
    member.pledge_cancelled_at = datetime.utcnow()
    _emit(db, pot, "kory.pledge.cancelled", user_id=user_id)
    _notify(db, pot, [user_id], f"{_name(db, me) or 'Le collecteur'} a annulé ton engagement. C’est noté au journal.")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/extend")
def extend_pot(
    pot_id: int,
    body: ExtendBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-15 : prolonger la collecte. Les engagements restent fermes."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me not in (pot.collector_id, pot.organizer_id):
        raise HTTPException(status_code=403, detail="Seul le collecteur prolonge la collecte")
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    new_due = body.due_at.replace(tzinfo=None)
    now = datetime.utcnow()
    if new_due <= now or (pot.due_at and new_due <= pot.due_at):
        raise HTTPException(status_code=422, detail="La nouvelle date doit être plus tard")
    pot.due_at = new_due
    pot.extended_at = now
    _emit(db, pot, "kory.pot.extended", due_at=new_due.isoformat())
    _notify(
        db, pot, _participants(db, pot) - {me},
        f"La collecte est prolongée jusqu’au {new_due.strftime('%d/%m/%Y')}. Les engagements restent fermes.",
    )
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/entries/{entry_id}/resubmit")
def resubmit_entry(
    pot_id: int,
    entry_id: int,
    body: EntryResubmit,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-5 : le contributeur dont l'envoi est contesté corrige sa
    référence ou joint la capture du SMS. La contribution redevient « à
    confirmer » ; elle n'entrait dans aucun total pendant la contestation."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    entry = db.query(KoryEntry).filter(KoryEntry.id == entry_id, KoryEntry.pot_id == pot.id).first()
    if entry is None or entry.contributor_id != me:
        raise HTTPException(status_code=404, detail="Contribution introuvable")
    if entry.status != "REJECTED":
        raise HTTPException(status_code=409, detail="Cette contribution n'est pas contestée")
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    if body.wallet_reference is not None:
        entry.wallet_reference = body.wallet_reference.strip() or None
    if body.note is not None:
        entry.note = body.note.strip() or None
    if body.proof_media_id is not None:
        # Seulement un fichier envoyé par l'auteur lui-même : sinon, désigner
        # le média d'un autre l'ouvrirait au collecteur (voir media.py).
        from app.models import MediaAsset

        asset = db.get(MediaAsset, body.proof_media_id)
        if asset is None or asset.uploader_id != me:
            raise HTTPException(status_code=403, detail="Capture introuvable")
        entry.proof_media_id = body.proof_media_id
    entry.status = "DECLARED"
    entry.reviewed_at = None
    _emit(db, pot, "kory.entry.resubmitted", entry_id=entry.id, contributor_id=me, amount=entry.amount)
    db.commit()
    return _entry_json(db, entry, me, pot)


@router.post("/pots/{pot_id}/participants")
def add_participants(
    pot_id: int,
    body: ParticipantsBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-11 : l'organisateur ajoute des participants. Ceux de Pokou entrent
    tout de suite ; les autres reçoivent un SMS et restent « Invités »
    jusqu'à leur inscription."""
    from app.core.config import get_settings
    from app.services.auth.otp_service import normalize_phone
    from app.services.notifications import sms_service

    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if me not in (pot.organizer_id, pot.collector_id):
        raise HTTPException(status_code=403, detail="Seul l'organisateur ajoute des participants")
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cagnotte est clôturée")
    organizer = _name(db, me) or "Un proche"
    added = []

    def add_member(user_id: int) -> None:
        if user_id == me or db.query(KoryMember).filter(
            KoryMember.pot_id == pot.id, KoryMember.user_id == user_id
        ).first():
            return
        db.add(KoryMember(pot_id=pot.id, user_id=user_id))
        added.append(user_id)

    for user_id in body.user_ids:
        if db.query(User.id).filter(User.id == user_id).first():
            add_member(user_id)
    for item in body.phones:
        try:
            phone = normalize_phone(item.phone)
        except Exception:
            raise HTTPException(status_code=422, detail=f"Numéro invalide : {item.phone}")
        existing = db.query(User).filter(User.phone == phone).first()
        if existing is not None:
            add_member(existing.id)
            continue
        if db.query(KoryInvite).filter(KoryInvite.pot_id == pot.id, KoryInvite.phone == phone).first():
            continue
        db.add(KoryInvite(pot_id=pot.id, phone=phone, display_name=(item.name or "").strip() or None, invited_by=me))
        link = f"{get_settings().public_link_base_url}/k/{pot.join_code}"
        try:
            sms_service.send_sms(
                db, phone,
                f"{organizer} t'invite à la cagnotte « {pot.title} » sur Pokou. Installe Pokou : {link}",
                get_settings().sms_sender_id,
            )
        except Exception:  # SMS best-effort : l'invitation reste enregistrée
            pass
    db.flush()
    if added:
        _notify(db, pot, added, f"{organizer} t’a ajouté·e à la cagnotte. Tu peux t’y engager.")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)
