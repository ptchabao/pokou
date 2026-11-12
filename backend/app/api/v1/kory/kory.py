"""Kory — le journal des cagnottes et des cotisations.

Aucune route ici ne déplace d'argent, et aucune ne le pourra : il n'y a ni
solde, ni retrait, ni intention de paiement (BM-01). Un membre DÉCLARE avoir
envoyé une somme au collecteur, depuis son propre wallet ; le collecteur
CONFIRME l'avoir reçue. Le total affiché est la somme des confirmations.

Qui voit une cagnotte : l'organisateur, le collecteur, les membres du groupe
rattaché et ceux qui l'ont rejointe par son code. Les autres reçoivent 404,
pour ne pas révéler qu'elle existe.
"""
import hashlib
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
from sqlalchemy.orm.attributes import flag_modified

from app.models import Group, GroupMember, KoryEntry, KoryInvite, KoryMember, KoryPot, KoryRound, User
from app.models.kory import KorySwap
from app.services.kory import cotisation as cotisation_service
from app.services.events.outbox import record_event
from app.services.notifications.inbox import notify

router = APIRouter(prefix="/kory", tags=["Pokou Kory"])

#: Le flux Kafka de Kory. Clé = la cagnotte : ses évènements restent
#: ordonnés. Aucune donnée de contact ni référence de transaction n'y entre :
#: les consommateurs (statistiques, notifications) n'en ont pas besoin.
EVENTS_TOPIC = "kory.events"

KINDS = {"CAGNOTTE", "COTISATION", "TONTINE"}
#: KOR-17 : une cotisation se règle chaque semaine, mois ou trimestre ;
#: KOR-23 : une tontine lève chaque semaine, quinzaine ou mois.
PERIODS = {"WEEKLY", "MONTHLY", "QUARTERLY"}
TONTINE_PERIODS = {"WEEKLY", "BIWEEKLY", "MONTHLY"}
DRAW_MODES = {"DRAW", "FIXED"}
#: KOR-8 / 20 : une relance par tranche de 12 h, pas davantage.
REMIND_EVERY = timedelta(hours=12)
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
    #: KOR-6 : pour qui l'on collecte.
    beneficiary_name: Optional[str] = Field(None, max_length=120)
    #: KOR-6 / 17 : « Montants individuels : visibles de tous ».
    amounts_visible: bool = True
    #: KOR-17 : dernière échéance d'une cotisation (sans : sans fin).
    ends_at: Optional[datetime] = None
    #: KOR-18 : seulement ces membres du groupe cotisent.
    member_ids: Optional[List[int]] = Field(None, max_length=500)
    #: KOR-18 : co-organisateur ; KOR-24 : suppléant de l'administrateur.
    deputy_id: Optional[int] = None
    #: KOR-24 : tirage au sort au démarrage (DRAW) ou ordre fixé (FIXED).
    draw_mode: Optional[str] = None


class EntryCreate(BaseModel):
    amount: int = Field(..., ge=1, le=MAX_AMOUNT)
    wallet_reference: Optional[str] = Field(None, max_length=64)
    period_label: Optional[str] = Field(None, max_length=12)
    note: Optional[str] = Field(None, max_length=280)
    #: KOR-3 : la capture du SMS de l'opérateur, jointe dès la déclaration.
    proof_media_id: Optional[int] = None


class SwapCreate(BaseModel):
    with_user_id: int
    message: Optional[str] = Field(None, max_length=280)


class DissolveBody(BaseModel):
    reason: str = Field(..., min_length=3, max_length=280)


class CotisationChange(BaseModel):
    """KOR-22 : ce que l'organisateur change d'une cotisation."""
    action: str  # AMOUNT | PAUSE | STOP | COLLECTOR
    amount: Optional[int] = Field(None, ge=100, le=MAX_AMOUNT)
    collector_id: Optional[int] = None


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


def _can_review(db: Session, pot: KoryPot, entry: KoryEntry, user_id: int) -> bool:
    """Le collecteur (dans une tontine : le bénéficiaire du tour) confirme ;
    pour une cotisation, le co-organisateur aussi (KOR-18)."""
    if user_id == _entry_reviewer(db, pot, entry):
        return True
    return pot.kind == "COTISATION" and pot.deputy_id is not None and user_id == pot.deputy_id


def _is_admin(pot: KoryPot, user_id: int) -> bool:
    """L'organisateur, ou son suppléant (KOR-24)."""
    return user_id == pot.organizer_id or (pot.deputy_id is not None and user_id == pot.deputy_id)


def _entry_json(db: Session, entry: KoryEntry, viewer_id: int, pot: KoryPot) -> dict:
    reviewer_id = _entry_reviewer(db, pot, entry)
    # KOR-6 : montants masqués — l'auteur, celui qui confirme et les
    # organisateurs les voient ; les autres ne voient que les totaux.
    hidden = not pot.amounts_visible and viewer_id not in (
        entry.contributor_id, reviewer_id, pot.organizer_id, pot.deputy_id,
    )
    data = {
        "id": entry.id,
        "contributor_id": entry.contributor_id,
        "contributor_name": _name(db, entry.contributor_id),
        "amount": None if hidden else entry.amount,
        "amount_hidden": hidden,
        "period_label": entry.period_label,
        "note": entry.note,
        "status": entry.status,
        "declared_at": entry.declared_at.isoformat(),
        "reviewed_at": entry.reviewed_at.isoformat() if entry.reviewed_at else None,
        "is_mine": entry.contributor_id == viewer_id,
        "round_number": entry.round_number,
        "review_reason": entry.review_reason,
        "reviewer_id": reviewer_id,
        "reviewer_name": _name(db, reviewer_id),
    }
    can_review = _can_review(db, pot, entry, viewer_id)
    data["can_review"] = can_review and entry.status == "DECLARED"
    # La référence de transaction et la capture ne servent qu'au
    # rapprochement : celui qui confirme et l'auteur les voient, pas tout le
    # groupe.
    if viewer_id == entry.contributor_id or can_review:
        data["wallet_reference"] = entry.wallet_reference
        data["proof_media_id"] = entry.proof_media_id
    else:
        data["proof_media_id"] = None
    return data


def _emit(db: Session, pot: KoryPot, event_type: str, **data) -> None:
    record_event(
        db,
        EVENTS_TOPIC,
        event_type,
        {"pot_id": pot.id, "group_id": pot.group_id, "kind": pot.kind, **data},
        key=f"pot-{pot.id}",
    )


def _group_name(db: Session, group_id: Optional[int]) -> Optional[str]:
    if group_id is None:
        return None
    group = db.query(Group).filter(Group.id == group_id).first()
    return group.name if group else None


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
        "group_name": _group_name(db, pot.group_id),
        "beneficiary_name": pot.beneficiary_name,
        "amounts_visible": bool(pot.amounts_visible) if pot.amounts_visible is not None else True,
        "deputy_id": pot.deputy_id,
        "deputy_name": _name(db, pot.deputy_id) if pot.deputy_id else None,
        "is_deputy": pot.deputy_id is not None and viewer_id == pot.deputy_id,
        "is_admin": _is_admin(pot, viewer_id),
        "ends_at": pot.ends_at.isoformat() if pot.ends_at else None,
        "dissolved_at": pot.dissolved_at.isoformat() if pot.dissolved_at else None,
        "dissolve_reason": pot.dissolve_reason,
        "reminded_at": pot.reminded_at.isoformat() if pot.reminded_at else None,
        "participants_count": len(_participants(db, pot)),
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
        data["draw_mode"] = pot.draw_mode
        data["draw_seal"] = pot.draw_seal
        data["drawn_at"] = pot.drawn_at.isoformat() if pot.drawn_at else None
        data["members"] = _tontine_members_json(db, pot)
        data["swaps"] = _swaps_json(db, pot, viewer_id)
    if pot.kind == "COTISATION" and pot.due_at is not None and pot.period:
        data["cotisation"] = cotisation_service.summary(
            db, pot, viewer_id, now, lambda uid: _name(db, uid)
        )
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

    # KOR-18 : des membres choisis dans le groupe, et un co-organisateur qui
    # confirme lui aussi les réceptions.
    selected = None
    if kind == "COTISATION" and body.member_ids is not None:
        if body.group_id is None:
            raise HTTPException(status_code=422, detail="Choisir des membres demande un groupe")
        selected = sorted(set(body.member_ids) | {me})
        if any(not _is_group_member(db, body.group_id, uid) for uid in selected):
            raise HTTPException(status_code=422, detail="Chaque membre choisi doit être dans le groupe")
    deputy_id = body.deputy_id if kind == "COTISATION" else None
    if deputy_id is not None:
        allowed = selected if selected is not None else None
        in_group = body.group_id is not None and _is_group_member(db, body.group_id, deputy_id)
        if deputy_id == me or not in_group or (allowed is not None and deputy_id not in allowed):
            raise HTTPException(status_code=422, detail="Le co-organisateur doit être un membre de la cotisation")

    due_at = body.due_at.replace(tzinfo=None) if body.due_at else None
    ends_at = body.ends_at.replace(tzinfo=None) if body.ends_at and kind == "COTISATION" else None
    if ends_at is not None and due_at is not None and ends_at < due_at:
        raise HTTPException(status_code=422, detail="La fin doit suivre la première échéance")

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
        due_at=due_at,
        ends_at=ends_at,
        join_code=_new_code(db),
        beneficiary_name=((body.beneficiary_name or "").strip() or None) if kind == "CAGNOTTE" else None,
        amounts_visible=body.amounts_visible,
        members_selected=selected is not None,
        deputy_id=deputy_id,
    )
    db.add(pot)
    db.flush()
    for uid in selected or []:
        db.add(KoryMember(pot_id=pot.id, user_id=uid))
    _emit(db, pot, "kory.pot.created", organizer_id=me, collector_id=collector_id)
    if pot.group_id:
        # « Les membres sont prévenus dans la discussion » (KOR-15, 19).
        _notify(db, pot, _participants(db, pot) - {me}, f"{_name(db, me) or 'Un membre'} a ouvert « {pot.title} ».")
    db.commit()
    db.refresh(pot)
    return _pot_json(db, pot, me, with_entries=True)


def _round_counts(db: Session, pot_id: int, number: int) -> dict:
    """Combien de membres ont confirmé, déclaré ou vu leur envoi contesté
    pour un tour (KOR-29) — chacun compté une fois, au meilleur statut."""
    best: dict = {}
    rank = {"CONFIRMED": 3, "DECLARED": 2, "REJECTED": 1}
    for uid, status in db.query(KoryEntry.contributor_id, KoryEntry.status).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.round_number == number
    ):
        if rank.get(status, 0) > rank.get(best.get(uid), 0):
            best[uid] = status
    return best


def _round_total(db: Session, pot_id: int, number: int) -> int:
    return int(db.query(func.coalesce(func.sum(KoryEntry.amount), 0)).filter(
        KoryEntry.pot_id == pot_id, KoryEntry.round_number == number, KoryEntry.status == "CONFIRMED",
    ).scalar() or 0)


def _tontine_member_ids(db: Session, pot: KoryPot, rounds: Optional[list] = None) -> List[int]:
    """Les membres d'une tontine : ses bénéficiaires une fois les tours
    posés, sinon ceux invités qui n'ont pas refusé."""
    rounds = rounds if rounds is not None else db.query(KoryRound).filter(KoryRound.pot_id == pot.id).all()
    if rounds:
        return sorted({r.beneficiary_id for r in rounds})
    return [
        uid for (uid,) in db.query(KoryMember.user_id).filter(
            KoryMember.pot_id == pot.id, KoryMember.declined_at.is_(None)
        ).order_by(KoryMember.position)
    ]


def _rounds_json(db: Session, pot: KoryPot) -> list:
    rounds = db.query(KoryRound).filter(KoryRound.pot_id == pot.id).order_by(KoryRound.number).all()
    members = _tontine_member_ids(db, pot, rounds)
    # Chaque tour, chacun des autres membres mise : le bénéficiaire reçoit
    # la mise de tous sauf la sienne.
    expected = (pot.amount_per_member or 0) * max(len(members) - 1, 0)
    now = datetime.utcnow()
    result = []
    for r in rounds:
        best = _round_counts(db, pot.id, r.number)
        contributors = [uid for uid in members if uid != r.beneficiary_id]
        started = r.status in ("CURRENT", "DONE")
        statuses = {}
        for uid in contributors:
            status = best.get(uid)
            if status in ("CONFIRMED", "DECLARED"):
                statuses[uid] = status
            elif started and (r.status == "DONE" or (r.due_at is not None and r.due_at < now)):
                statuses[uid] = "LATE"
            else:
                statuses[uid] = "REJECTED" if status == "REJECTED" else "DUE"
        result.append({
            "number": r.number,
            "beneficiary_id": r.beneficiary_id,
            "beneficiary_name": _name(db, r.beneficiary_id),
            "due_at": r.due_at.isoformat() if r.due_at else None,
            "status": r.status,
            "confirmed_total": _round_total(db, pot.id, r.number),
            "expected_total": expected,
            "expected_count": len(contributors),
            "confirmed_count": sum(1 for v in statuses.values() if v == "CONFIRMED"),
            "declared_count": sum(1 for v in statuses.values() if v == "DECLARED"),
            "rejected_count": sum(1 for v in best.values() if v == "REJECTED"),
            "late_count": sum(1 for v in statuses.values() if v == "LATE"),
            # KOR-7 : où en est chacun pour le tour en cours.
            "contributors": [
                {"user_id": uid, "name": _name(db, uid), "status": statuses[uid]} for uid in contributors
            ] if r.status == "CURRENT" else [],
        })
    return result


def _tontine_members_json(db: Session, pot: KoryPot) -> list:
    """KOR-8 / 24 / 25 : qui est invité, qui a accepté, qui administre."""
    rows = db.query(KoryMember).filter(KoryMember.pot_id == pot.id).order_by(KoryMember.position).all()
    if not rows:
        rows_ids = _tontine_member_ids(db, pot)
        return [
            {"user_id": uid, "name": _name(db, uid), "accepted": True, "declined": False,
             "is_admin": uid == pot.organizer_id, "is_deputy": uid == pot.deputy_id}
            for uid in rows_ids
        ]
    return [
        {
            "user_id": m.user_id,
            "name": _name(db, m.user_id),
            "accepted": m.accepted_at is not None,
            "declined": m.declined_at is not None,
            "is_admin": m.user_id == pot.organizer_id,
            "is_deputy": m.user_id == pot.deputy_id,
        }
        for m in rows
    ]


def _swaps_json(db: Session, pot: KoryPot, viewer_id: int) -> list:
    """KOR-28 : les échanges de mois. Le calendrier est commun, donc les
    échanges aussi ; le message reste entre les deux membres et les
    administrateurs."""
    swaps = db.query(KorySwap).filter(KorySwap.pot_id == pot.id).order_by(KorySwap.created_at.desc()).all()
    admin = _is_admin(pot, viewer_id)
    return [
        {
            "id": s.id,
            "requester_id": s.requester_id,
            "requester_name": _name(db, s.requester_id),
            "target_id": s.target_id,
            "target_name": _name(db, s.target_id),
            "requester_round": s.requester_round,
            "target_round": s.target_round,
            "message": s.message if admin or viewer_id in (s.requester_id, s.target_id) else None,
            "status": s.status,
            "created_at": s.created_at.isoformat(),
            "decided_at": s.decided_at.isoformat() if s.decided_at else None,
        }
        for s in swaps
    ]


def _current_round(db: Session, pot: KoryPot) -> Optional[KoryRound]:
    return db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.status == "CURRENT").first()


def _create_tontine(db: Session, me: int, body: PotCreate) -> dict:
    """Kory Plus (BM-13), ouvert par pays (mois 13). Tenue comme le reste de
    Kory : un journal, jamais un solde. Chaque tour, les membres envoient
    leur mise au wallet du bénéficiaire, qui confirme seul ce qu'il a reçu.

    La tontine naît EN ATTENTE (KOR-8) : chaque membre invité accepte d'y
    entrer (KOR-25). Les tours ne sont posés qu'au démarrage — tirés au sort
    par Pokou, ou dans l'ordre fixé par l'administrateur (KOR-24, 26)."""
    user = db.query(User).filter(User.id == me).first()
    if not module_open(db, user.phone, "kory_plus"):
        raise HTTPException(status_code=403, detail="La tontine en rotation demande Kory Plus")
    period = (body.period or "").upper()
    if body.amount_per_member is None or period not in TONTINE_PERIODS:
        raise HTTPException(status_code=422, detail="Une tontine demande une mise et une période")
    if body.group_id is None or not _is_group_member(db, body.group_id, me):
        raise HTTPException(status_code=422, detail="Une tontine s'ouvre depuis un groupe dont vous êtes membre")
    rotation = list(body.rotation or [])
    if me not in rotation:
        rotation = [me] + rotation
    if len(rotation) < MIN_ROUNDS or len(set(rotation)) != len(rotation):
        raise HTTPException(status_code=422, detail="L'ordre des tours doit nommer au moins deux membres, chacun une fois")
    if any(not _is_group_member(db, body.group_id, uid) for uid in rotation):
        raise HTTPException(status_code=422, detail="Chaque bénéficiaire doit être membre du groupe")
    draw_mode = (body.draw_mode or "FIXED").upper()
    if draw_mode not in DRAW_MODES:
        raise HTTPException(status_code=422, detail="Ordre des tours inconnu")
    if body.deputy_id is not None and (body.deputy_id == me or body.deputy_id not in rotation):
        raise HTTPException(status_code=422, detail="Le suppléant doit être un membre de la tontine")
    start = (body.starts_at or body.due_at)
    start = start.replace(tzinfo=None) if start else None
    pot = KoryPot(
        group_id=body.group_id, organizer_id=me, collector_id=rotation[0], kind="TONTINE",
        title=body.title.strip(), description=(body.description or "").strip() or None,
        amount_per_member=body.amount_per_member, period=period, join_code=_new_code(db),
        status="PENDING", draw_mode=draw_mode, deputy_id=body.deputy_id, due_at=start,
        amounts_visible=body.amounts_visible,
    )
    db.add(pot)
    db.flush()
    now = datetime.utcnow()
    for index, uid in enumerate(rotation):
        db.add(KoryMember(pot_id=pot.id, user_id=uid, position=index, accepted_at=now if uid == me else None))
    db.flush()
    _emit(db, pot, "kory.pot.created", organizer_id=me, members=len(rotation), draw_mode=draw_mode)
    _notify(
        db, pot, set(rotation) - {me},
        f"{_name(db, me) or 'Un membre'} t’invite dans la tontine « {pot.title} ». Accepte pour qu’elle démarre.",
    )
    db.commit()
    db.refresh(pot)
    return _pot_json(db, pot, me, with_entries=True)


def _start_tontine(db: Session, pot: KoryPot) -> None:
    """KOR-26 : tous ont accepté, la tontine démarre. Le tirage est fait par
    le serveur, une seule fois ; son empreinte est publiée avec l'ordre, et
    il ne se rejoue pas (les tours existent désormais)."""
    rows = db.query(KoryMember).filter(
        KoryMember.pot_id == pot.id, KoryMember.declined_at.is_(None)
    ).order_by(KoryMember.position).all()
    order = [m.user_id for m in rows]
    now = datetime.utcnow()
    nonce = secrets.token_hex(16)
    if pot.draw_mode == "DRAW":
        secrets.SystemRandom().shuffle(order)
    digest = hashlib.sha256(f"{pot.id}:{','.join(map(str, order))}:{nonce}".encode()).hexdigest().upper()
    pot.draw_seal = f"{digest[:4]}-{digest[4:8]}"
    pot.drawn_at = now
    start = pot.due_at if pot.due_at and pot.due_at > now else cotisation_service.add_period(now, pot.period, 1)
    for index, beneficiary in enumerate(order):
        db.add(KoryRound(
            pot_id=pot.id, number=index + 1, beneficiary_id=beneficiary,
            due_at=cotisation_service.add_period(start, pot.period, index),
            status="CURRENT" if index == 0 else "UPCOMING",
        ))
    pot.collector_id = order[0]
    pot.status = "OPEN"
    db.flush()
    _emit(db, pot, "kory.tontine.started", rounds=len(order), draw_mode=pot.draw_mode, seal=pot.draw_seal)
    _notify(
        db, pot, set(order),
        "Tout le monde a accepté : la tontine démarre. Le calendrier des tours est prêt.",
    )


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
    period_label = (body.period_label or "").strip() or None
    if pot.kind == "COTISATION" and period_label is None:
        # KOR-21 : sans précision, la contribution règle la plus ancienne
        # échéance encore ouverte du membre.
        summary = cotisation_service.summary(db, pot, me, datetime.utcnow(), lambda uid: None)
        if summary["my_next"] is not None:
            period_label = summary["my_next"]["label"]
    proof_id = None
    if body.proof_media_id is not None:
        # Seulement un fichier envoyé par l'auteur lui-même (voir resubmit).
        from app.models import MediaAsset

        asset = db.get(MediaAsset, body.proof_media_id)
        if asset is None or asset.uploader_id != me:
            raise HTTPException(status_code=403, detail="Capture introuvable")
        proof_id = asset.id
    entry = KoryEntry(
        round_number=round_number,
        pot_id=pot.id,
        contributor_id=me,
        amount=body.amount,
        wallet_reference=(body.wallet_reference or "").strip() or None,
        period_label=period_label,
        note=(body.note or "").strip() or None,
        proof_media_id=proof_id,
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
    if not _can_review(db, pot, entry, me):
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
    if not _is_admin(pot, me):
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


@router.get("/preview/{code}")
def preview_pot(code: str, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """KOR-10 : ce qu'on voit d'une cagnotte AVANT de la rejoindre. Le code
    est le secret : qui l'a reçu peut lire ceci, rien de plus — ni le
    journal, ni les montants de chacun, ni le numéro entier du collecteur."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = db.query(KoryPot).filter(KoryPot.join_code == code.strip().upper()).first()
    if pot is None or pot.status != "OPEN" or pot.kind == "TONTINE":
        raise HTTPException(status_code=404, detail="Code inconnu ou cagnotte clôturée")
    collector = db.query(User).filter(User.id == pot.collector_id).first()
    return {
        "id": pot.id,
        "kind": pot.kind,
        "title": pot.title,
        "description": pot.description,
        "beneficiary_name": pot.beneficiary_name,
        "goal_amount": pot.goal_amount,
        "amount_per_member": pot.amount_per_member,
        "period": pot.period,
        "due_at": pot.due_at.isoformat() if pot.due_at else None,
        "group_name": _group_name(db, pot.group_id),
        "organizer_name": _name(db, pot.organizer_id),
        "collector_name": collector.full_name if collector else None,
        "collector_phone_masked": _mask(collector.phone) if collector else None,
        "participants_count": len(_participants(db, pot) | {me}),
        "amounts_visible": bool(pot.amounts_visible) if pot.amounts_visible is not None else True,
        "already_member": _can_see(db, pot, me),
        "join_code": pot.join_code,
    }


def _tontine_for_member(db: Session, pot_id: int, me: int) -> tuple:
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind != "TONTINE":
        raise HTTPException(status_code=409, detail="Seule une tontine se rejoint par invitation")
    member = db.query(KoryMember).filter(KoryMember.pot_id == pot.id, KoryMember.user_id == me).first()
    return pot, member


def _all_accepted(db: Session, pot: KoryPot) -> bool:
    rows = db.query(KoryMember).filter(KoryMember.pot_id == pot.id, KoryMember.declined_at.is_(None)).all()
    return len(rows) >= MIN_ROUNDS and all(m.accepted_at is not None for m in rows)


@router.post("/pots/{pot_id}/accept")
def accept_tontine(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """KOR-25 : l'invité accepte d'entrer. Le dernier « oui » démarre la
    tontine — si personne n'a refusé ; sinon l'administrateur décide."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot, member = _tontine_for_member(db, pot_id, me)
    if member is None or member.declined_at is not None:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas invité dans cette tontine")
    if pot.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cette tontine a déjà démarré")
    if member.accepted_at is None:
        member.accepted_at = datetime.utcnow()
        db.flush()
        _emit(db, pot, "kory.tontine.accepted", user_id=me)
        nobody_declined = db.query(KoryMember.id).filter(
            KoryMember.pot_id == pot.id, KoryMember.declined_at.isnot(None)
        ).first() is None
        if nobody_declined and _all_accepted(db, pot):
            _start_tontine(db, pot)
        db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/decline")
def decline_tontine(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """KOR-25 : refuser l'invitation. L'administrateur est prévenu ; il peut
    démarrer sans la personne, ou dissoudre."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot, member = _tontine_for_member(db, pot_id, me)
    if member is None:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas invité dans cette tontine")
    if pot.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cette tontine a déjà démarré")
    if me == pot.organizer_id:
        raise HTTPException(status_code=409, detail="L'administrateur dissout la tontine, il ne la refuse pas")
    if member.declined_at is None:
        member.declined_at = datetime.utcnow()
        member.accepted_at = None
        if pot.deputy_id == me:
            pot.deputy_id = None
        _emit(db, pot, "kory.tontine.declined", user_id=me)
        _notify(db, pot, [pot.organizer_id], f"{_name(db, me) or 'Un membre'} a refusé l’invitation.")
        db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/start")
def start_tontine(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'administrateur démarre sans ceux qui ont refusé — à condition que
    tous les autres aient accepté."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot, _ = _tontine_for_member(db, pot_id, me)
    if not _is_admin(pot, me):
        raise HTTPException(status_code=403, detail="Seul l'administrateur démarre la tontine")
    if pot.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cette tontine a déjà démarré")
    if not _all_accepted(db, pot):
        raise HTTPException(status_code=409, detail="Tous les membres n'ont pas encore accepté")
    _start_tontine(db, pot)
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


def _remind_targets(db: Session, pot: KoryPot, now: datetime) -> set:
    if pot.kind == "TONTINE" and pot.status == "PENDING":
        return {
            m.user_id for m in db.query(KoryMember).filter(
                KoryMember.pot_id == pot.id, KoryMember.accepted_at.is_(None), KoryMember.declined_at.is_(None)
            )
        }
    if pot.kind == "TONTINE":
        current = _current_round(db, pot)
        if current is None:
            return set()
        best = _round_counts(db, pot.id, current.number)
        return {
            uid for uid in _tontine_member_ids(db, pot)
            if uid != current.beneficiary_id and best.get(uid) not in ("CONFIRMED", "DECLARED")
        }
    if pot.kind == "COTISATION":
        return set(cotisation_service.late_member_ids(db, pot, now))
    return {
        m.user_id for m in _active_pledges(db, pot)
        if _is_firm(m, now) and _pledge_total(pot, m) > _confirmed_total(db, pot.id, m.user_id)
    }


@router.post("/pots/{pot_id}/remind")
def remind(pot_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """KOR-8 / 20 : relancer ceux qui n'ont pas encore répondu ou versé.
    Une relance par tranche de 12 h ; chacun reçoit une notification."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if not (_is_admin(pot, me) or me == pot.collector_id):
        raise HTTPException(status_code=403, detail="Seul l'organisateur relance")
    if pot.status not in ("OPEN", "PENDING"):
        raise HTTPException(status_code=409, detail="Cette collecte est clôturée")
    now = datetime.utcnow()
    if pot.reminded_at is not None and now - pot.reminded_at < REMIND_EVERY:
        raise HTTPException(status_code=429, detail="Une relance a déjà été envoyée il y a moins de 12 h")
    targets = _remind_targets(db, pot, now) - {me}
    if targets:
        body = (
            "Ta réponse est attendue pour que la tontine démarre."
            if pot.status == "PENDING" else "Petit rappel : ta contribution est attendue."
        )
        _notify(db, pot, targets, body)
        pot.reminded_at = now
        _emit(db, pot, "kory.reminded", count=len(targets))
    db.commit()
    return {"reminded": len(targets), "reminded_at": pot.reminded_at.isoformat() if pot.reminded_at else None}


def _my_upcoming_round(db: Session, pot: KoryPot, user_id: int) -> Optional[KoryRound]:
    return db.query(KoryRound).filter(
        KoryRound.pot_id == pot.id, KoryRound.beneficiary_id == user_id, KoryRound.status == "UPCOMING"
    ).first()


@router.post("/pots/{pot_id}/swaps", status_code=201)
def request_swap(
    pot_id: int,
    body: SwapCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-28 : proposer d'échanger son mois. Seuls deux tours À VENIR
    s'échangent : un tour commencé a déjà reçu des mises."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind != "TONTINE" or pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Seule une tontine en cours échange ses mois")
    mine = _my_upcoming_round(db, pot, me)
    theirs = _my_upcoming_round(db, pot, body.with_user_id)
    if mine is None or theirs is None or body.with_user_id == me:
        raise HTTPException(status_code=409, detail="Seuls deux mois à venir s'échangent")
    open_swap = db.query(KorySwap.id).filter(
        KorySwap.pot_id == pot.id, KorySwap.status.in_(("PENDING", "ACCEPTED")),
        or_(KorySwap.requester_id == me, KorySwap.target_id == me),
    ).first()
    if open_swap is not None:
        raise HTTPException(status_code=409, detail="Un échange est déjà en cours pour vous")
    swap = KorySwap(
        pot_id=pot.id, requester_id=me, target_id=body.with_user_id,
        requester_round=mine.number, target_round=theirs.number,
        message=(body.message or "").strip() or None,
    )
    db.add(swap)
    flag_modified(pot, "title")  # le calendrier de chacun se relit (temps réel)
    db.flush()
    _emit(db, pot, "kory.swap.requested", swap_id=swap.id, requester_id=me, target_id=body.with_user_id)
    _notify(db, pot, [body.with_user_id], f"{_name(db, me) or 'Un membre'} te propose d’échanger vos mois.")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


def _get_swap(db: Session, pot: KoryPot, swap_id: int) -> KorySwap:
    swap = db.query(KorySwap).filter(KorySwap.id == swap_id, KorySwap.pot_id == pot.id).first()
    if swap is None:
        raise HTTPException(status_code=404, detail="Échange introuvable")
    return swap


@router.post("/pots/{pot_id}/swaps/{swap_id}/accept")
def accept_swap(pot_id: int, swap_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    swap = _get_swap(db, pot, swap_id)
    if me != swap.target_id:
        raise HTTPException(status_code=403, detail="Seul le membre sollicité accepte")
    if swap.status != "PENDING":
        raise HTTPException(status_code=409, detail="Cet échange n'attend plus de réponse")
    swap.status = "ACCEPTED"
    flag_modified(pot, "title")
    _emit(db, pot, "kory.swap.accepted", swap_id=swap.id)
    admins = {pot.organizer_id, pot.deputy_id} - {None}
    _notify(db, pot, admins, f"{_name(db, me) or 'Un membre'} accepte d’échanger son mois. À toi de valider.")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/swaps/{swap_id}/approve")
def approve_swap(pot_id: int, swap_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """L'administrateur valide : les deux tours échangent leur bénéficiaire,
    pour tous, et c'est noté au journal."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    swap = _get_swap(db, pot, swap_id)
    if not _is_admin(pot, me):
        raise HTTPException(status_code=403, detail="Seul l'administrateur valide un échange")
    if swap.status != "ACCEPTED":
        raise HTTPException(status_code=409, detail="L'autre membre n'a pas encore accepté")
    first = db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.number == swap.requester_round).first()
    second = db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.number == swap.target_round).first()
    if (first is None or second is None or first.status != "UPCOMING" or second.status != "UPCOMING"
            or first.beneficiary_id != swap.requester_id or second.beneficiary_id != swap.target_id):
        swap.status = "REFUSED"
        swap.decided_at = datetime.utcnow()
        db.commit()
        raise HTTPException(status_code=409, detail="Ces tours ont changé depuis la demande")
    first.beneficiary_id, second.beneficiary_id = swap.target_id, swap.requester_id
    swap.status = "DONE"
    swap.decided_at = datetime.utcnow()
    _emit(db, pot, "kory.swap.done", swap_id=swap.id, rounds=[first.number, second.number])
    _notify(
        db, pot, set(_tontine_member_ids(db, pot)) - {me},
        f"{_name(db, swap.requester_id) or 'Un membre'} et {_name(db, swap.target_id) or 'un membre'} "
        "ont échangé leurs mois. Le calendrier est à jour.",
    )
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/swaps/{swap_id}/refuse")
def refuse_swap(pot_id: int, swap_id: int, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Le membre sollicité refuse, le demandeur retire sa demande, ou
    l'administrateur ne la valide pas. La demande reste, avec son statut."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    swap = _get_swap(db, pot, swap_id)
    if swap.status not in ("PENDING", "ACCEPTED"):
        raise HTTPException(status_code=409, detail="Cet échange est déjà tranché")
    if me not in (swap.requester_id, swap.target_id) and not _is_admin(pot, me):
        raise HTTPException(status_code=403, detail="Cet échange ne vous concerne pas")
    swap.status = "REFUSED"
    swap.decided_at = datetime.utcnow()
    flag_modified(pot, "title")
    _emit(db, pot, "kory.swap.refused", swap_id=swap.id, by=me)
    _notify(db, pot, {swap.requester_id, swap.target_id} - {me}, "La demande d’échange de mois n’a pas abouti.")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/dissolve")
def dissolve_tontine(
    pot_id: int,
    body: DissolveBody,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-30 : l'administrateur (ou son suppléant) dissout la tontine, avec
    un motif. Plus aucun tour n'est appelé ; le journal reste. Ce qui a été
    versé entre membres se règle entre eux : Pokou n'a jamais touché
    l'argent."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind != "TONTINE":
        raise HTTPException(status_code=409, detail="Seule une tontine se dissout")
    if not _is_admin(pot, me):
        raise HTTPException(status_code=403, detail="Seul l'administrateur dissout la tontine")
    if pot.status not in ("OPEN", "PENDING"):
        raise HTTPException(status_code=409, detail="Cette tontine est déjà terminée")
    now = datetime.utcnow()
    reason = body.reason.strip()
    cancelled = 0
    for round_ in db.query(KoryRound).filter(KoryRound.pot_id == pot.id, KoryRound.status != "DONE"):
        if round_.status == "CURRENT":
            # Le tour en cours garde ses mises au journal ; il s'arrête là.
            round_.status = "DONE"
            round_.closed_at = now
        else:
            round_.status = "CANCELLED"
            cancelled += 1
    db.query(KorySwap).filter(
        KorySwap.pot_id == pot.id, KorySwap.status.in_(("PENDING", "ACCEPTED"))
    ).update({"status": "REFUSED", "decided_at": now}, synchronize_session=False)
    pot.status = "CLOSED"
    pot.closed_at = now
    pot.dissolved_at = now
    pot.dissolve_reason = reason
    _emit(db, pot, "kory.tontine.dissolved", cancelled_rounds=cancelled)
    members = set(_tontine_member_ids(db, pot)) | {
        m.user_id for m in db.query(KoryMember).filter(KoryMember.pot_id == pot.id)
    }
    _notify(db, pot, members - {me}, f"La tontine est dissoute. Motif : « {reason} »")
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)


@router.post("/pots/{pot_id}/cotisation")
def change_cotisation(
    pot_id: int,
    body: CotisationChange,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """KOR-22 : changer le montant, mettre en pause, arrêter ou changer de
    collecteur. Ce qui est dû pour l'échéance en cours reste dû, et les
    échéances passées restent au journal : chaque changement ne vaut qu'à
    partir de l'échéance SUIVANTE."""
    me = _me(current_user)
    _require_kory_open(db, me)
    pot = _get_visible_pot(db, pot_id, me)
    if pot.kind != "COTISATION":
        raise HTTPException(status_code=409, detail="Seule une cotisation se modifie ainsi")
    if not _is_admin(pot, me):
        raise HTTPException(status_code=403, detail="Seul l'organisateur modifie la cotisation")
    if pot.status != "OPEN":
        raise HTTPException(status_code=409, detail="Cette cotisation est arrêtée")
    now = datetime.utcnow()
    action = body.action.upper()
    following = cotisation_service.next_label_after(pot, now)
    current = cotisation_service.current_due(pot, now)
    actor = _name(db, me) or "L'organisateur"
    if action == "AMOUNT":
        if body.amount is None or following is None:
            raise HTTPException(status_code=422, detail="Indiquez le nouveau montant")
        pot.next_amount, pot.next_amount_from = body.amount, following[0]
        message = f"{actor} a changé le montant : {_fcfa(body.amount)} à partir du {following[1].strftime('%d/%m/%Y')}."
    elif action == "PAUSE":
        if following is None:
            raise HTTPException(status_code=409, detail="Aucune échéance à venir")
        pot.paused_period = following[0]
        message = f"{actor} a mis la cotisation en pause : pas d’échéance le {following[1].strftime('%d/%m/%Y')}."
    elif action == "STOP":
        last = current[1] if current is not None and current[1] <= now else now
        pot.ends_at = last
        if current is None or current[1] > now:
            pot.status = "CLOSED"
            pot.closed_at = now
        message = f"{actor} a arrêté la cotisation. Ce qui est dû reste dû."
    elif action == "COLLECTOR":
        members = cotisation_service.member_ids(db, pot)
        if body.collector_id is None or body.collector_id not in members:
            raise HTTPException(status_code=422, detail="Le collecteur doit être un membre de la cotisation")
        pot.collector_id = body.collector_id
        message = f"{_name(db, body.collector_id) or 'Un membre'} est le nouveau collecteur. Vérifie son numéro avant d’envoyer."
    else:
        raise HTTPException(status_code=422, detail="Changement inconnu")
    _emit(db, pot, "kory.cotisation.changed", action=action)
    _notify(db, pot, _participants(db, pot) - {me}, message)
    db.commit()
    return _pot_json(db, pot, me, with_entries=True)
