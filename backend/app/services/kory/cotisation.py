"""Le calendrier d'une cotisation (maquettes Kory 17 à 22).

Une cotisation n'a pas de solde : elle a des ÉCHÉANCES. Chacune porte une
étiquette de période (« 2026-11 », « 2026-W45 », « 2026-Q4 »), et une
contribution déclarée pour cette étiquette la règle — une fois que le
collecteur l'a confirmée. Tout ici se recalcule à partir du journal ; rien
n'est stocké à part, pour qu'aucun chiffre ne puisse diverger des lignes.
"""
import calendar
from datetime import datetime, timedelta
from typing import Dict, Iterable, List, Optional, Tuple

from sqlalchemy.orm import Session

from app.models import GroupMember, KoryEntry, KoryMember, KoryPot

#: Au-delà, on ne regarde plus en arrière : le journal, lui, garde tout.
MAX_HISTORY = 12
#: Un garde-fou : jamais plus de 20 ans d'échéances hebdomadaires.
_MAX_STEPS = 1100
#: Le rang d'un statut : une échéance réglée l'emporte sur une déclaration,
#: qui l'emporte sur une contestation.
_RANK = {"CONFIRMED": 3, "DECLARED": 2, "REJECTED": 1}


def add_period(start: datetime, period: str, steps: int) -> datetime:
    """La `steps`-ième échéance après `start`. Un mois sans 31 garde son
    dernier jour : le 31 janvier mène au 28 (ou 29) février."""
    if period == "WEEKLY":
        return start + timedelta(days=7 * steps)
    if period == "BIWEEKLY":
        return start + timedelta(days=14 * steps)
    months = steps * (3 if period == "QUARTERLY" else 1)
    month_index = start.month - 1 + months
    year = start.year + month_index // 12
    month = month_index % 12 + 1
    day = min(start.day, calendar.monthrange(year, month)[1])
    return start.replace(year=year, month=month, day=day)


def period_label(due: datetime, period: str) -> str:
    if period in ("WEEKLY", "BIWEEKLY"):
        iso = due.isocalendar()
        return f"{iso[0]}-W{iso[1]:02d}"
    if period == "QUARTERLY":
        return f"{due.year}-Q{(due.month - 1) // 3 + 1}"
    return f"{due.year}-{due.month:02d}"


def dues(pot: KoryPot, until: datetime, extra: int = 0) -> List[Tuple[str, datetime]]:
    """Les échéances jusqu'à `until`, puis `extra` échéances à venir. Une
    échéance mise en pause est sautée ; rien après `ends_at`."""
    if pot.due_at is None or pot.period is None:
        return []
    result: List[Tuple[str, datetime]] = []
    upcoming = 0
    for step in range(_MAX_STEPS):
        due = add_period(pot.due_at, pot.period, step)
        if pot.ends_at is not None and due > pot.ends_at:
            break
        if due > until:
            if upcoming >= extra:
                break
            upcoming += 1
        label = period_label(due, pot.period)
        if label == pot.paused_period:
            if due > until:
                upcoming -= 1
            continue
        result.append((label, due))
    return result


def amount_for(pot: KoryPot, label: str) -> int:
    """KOR-22 : un nouveau montant vaut à partir de son échéance ; les
    étiquettes d'une même périodicité se comparent comme des chaînes."""
    if pot.next_amount and pot.next_amount_from and label >= pot.next_amount_from:
        return pot.next_amount
    return pot.amount_per_member or 0


def member_ids(db: Session, pot: KoryPot) -> List[int]:
    """Qui cotise. Membres choisis (KOR-18) : les seules lignes `KoryMember`.
    Sinon, tout le groupe rattaché, plus ceux qui ont rejoint par code — et
    l'organisateur, qui cotise comme les autres."""
    rows = {
        uid for (uid,) in db.query(KoryMember.user_id).filter(
            KoryMember.pot_id == pot.id, KoryMember.declined_at.is_(None)
        )
    }
    if pot.members_selected:
        return sorted(rows)
    users = set(rows) | {pot.organizer_id}
    if pot.group_id:
        users |= {uid for (uid,) in db.query(GroupMember.user_id).filter(GroupMember.group_id == pot.group_id)}
    return sorted(u for u in users if u)


def _statuses(db: Session, pot: KoryPot) -> Dict[Tuple[int, str], KoryEntry]:
    """La meilleure contribution de chacun pour chaque échéance."""
    best: Dict[Tuple[int, str], KoryEntry] = {}
    for entry in db.query(KoryEntry).filter(KoryEntry.pot_id == pot.id, KoryEntry.period_label.isnot(None)):
        key = (entry.contributor_id, entry.period_label)
        known = best.get(key)
        if known is None or _RANK.get(entry.status, 0) > _RANK.get(known.status, 0):
            best[key] = entry
    return best


def _contested(db: Session, pot: KoryPot, label: str) -> int:
    """Les contestations d'une échéance qu'aucune confirmation n'a suivies."""
    confirmed = {
        uid for (uid,) in db.query(KoryEntry.contributor_id).filter(
            KoryEntry.pot_id == pot.id, KoryEntry.period_label == label, KoryEntry.status == "CONFIRMED"
        )
    }
    return len({
        uid for (uid,) in db.query(KoryEntry.contributor_id).filter(
            KoryEntry.pot_id == pot.id, KoryEntry.period_label == label, KoryEntry.status == "REJECTED"
        )
    } - confirmed)


def current_due(pot: KoryPot, now: datetime) -> Optional[Tuple[str, datetime]]:
    """L'échéance en cours : la dernière passée, ou la première à venir."""
    schedule = dues(pot, now, extra=1)
    past = [d for d in schedule if d[1] <= now]
    if past:
        return past[-1]
    return schedule[0] if schedule else None


def next_label_after(pot: KoryPot, now: datetime) -> Optional[Tuple[str, datetime]]:
    """L'échéance qui suit celle en cours (KOR-22 : « à partir du 5 mars »)."""
    current = current_due(pot, now)
    if current is None:
        return None
    for label, due in dues(pot, current[1], extra=2):
        if due > current[1]:
            return label, due
    return None


def summary(db: Session, pot: KoryPot, viewer_id: int, now: datetime, name_of) -> dict:
    """Le bloc `cotisation` de la réponse : l'échéance en cours, vue de
    l'organisateur (KOR-20) et du membre (KOR-21), les mois précédents et
    les prochaines échéances (KOR-19)."""
    members = member_ids(db, pot)
    schedule = dues(pot, now, extra=3)
    past = [d for d in schedule if d[1] <= now]
    current = past[-1] if past else (schedule[0] if schedule else None)
    best = _statuses(db, pot)

    def state(user_id: int, label: str, due: datetime) -> str:
        entry = best.get((user_id, label))
        if entry is not None and entry.status in ("CONFIRMED", "DECLARED"):
            return entry.status
        if entry is not None and entry.status == "REJECTED":
            return "REJECTED"
        return "LATE" if due < now else "DUE"

    current_json = None
    if current is not None:
        label, due = current
        states = {uid: state(uid, label, due) for uid in members}
        late = [uid for uid, s in states.items() if s in ("LATE", "REJECTED") and due < now]
        current_json = {
            "label": label,
            "due_at": due.isoformat(),
            "amount": amount_for(pot, label),
            "expected_total": amount_for(pot, label) * len(members),
            "confirmed_total": sum(
                best[(uid, label)].amount for uid in members
                if states[uid] == "CONFIRMED" and best.get((uid, label)) is not None
            ),
            "up_to_date_count": sum(1 for s in states.values() if s == "CONFIRMED"),
            "to_confirm_count": sum(1 for s in states.values() if s == "DECLARED"),
            "late_count": len(late),
            "late": [{"user_id": uid, "name": name_of(uid)} for uid in late],
        }

    history = []
    for label, due in reversed(past[:-1] if past else []):
        if len(history) >= MAX_HISTORY:
            break
        history.append({
            "label": label,
            "due_at": due.isoformat(),
            "paid_count": sum(1 for uid in members if state(uid, label, due) == "CONFIRMED"),
            "members_count": len(members),
            "contested_count": _contested(db, pot, label),
        })

    mine = []
    if viewer_id in members:
        for label, due in reversed(past or ([current] if current else [])):
            if len(mine) >= MAX_HISTORY:
                break
            entry = best.get((viewer_id, label))
            mine.append({
                "label": label,
                "due_at": due.isoformat(),
                "amount": entry.amount if entry is not None else amount_for(pot, label),
                "status": state(viewer_id, label, due),
                "wallet_reference": entry.wallet_reference if entry is not None else None,
                "declared_at": entry.declared_at.isoformat() if entry is not None else None,
                # « contestée, puis confirmée » (KOR-21).
                "was_contested": entry is not None and entry.status == "CONFIRMED"
                and _was_contested(db, pot, viewer_id, label),
            })

    # La prochaine échéance du membre : la plus ancienne qu'il n'a ni
    # réglée ni déclarée, sinon la suivante à venir.
    my_next = None
    if viewer_id in members:
        for label, due in schedule:
            if state(viewer_id, label, due) not in ("CONFIRMED", "DECLARED"):
                my_next = {"label": label, "due_at": due.isoformat(), "amount": amount_for(pot, label),
                           "status": state(viewer_id, label, due)}
                break

    nxt = next_label_after(pot, now)
    return {
        "members_count": len(members),
        "members": [{"user_id": uid, "name": name_of(uid)} for uid in members],
        "is_member": viewer_id in members,
        "current": current_json,
        "history": history,
        "my_periods": mine,
        "my_next": my_next,
        "schedule": [
            {"label": label, "due_at": due.isoformat(), "amount": amount_for(pot, label)}
            for label, due in schedule if current is None or due >= current[1]
        ][:4],
        "next_period": {"label": nxt[0], "due_at": nxt[1].isoformat()} if nxt else None,
    }


def _was_contested(db: Session, pot: KoryPot, user_id: int, label: str) -> bool:
    return db.query(KoryEntry.id).filter(
        KoryEntry.pot_id == pot.id, KoryEntry.contributor_id == user_id,
        KoryEntry.period_label == label, KoryEntry.status == "REJECTED",
    ).first() is not None


def late_member_ids(db: Session, pot: KoryPot, now: datetime) -> Iterable[int]:
    """Ceux qui n'ont rien déclaré pour l'échéance en cours, déjà passée."""
    current = current_due(pot, now)
    if current is None or current[1] > now:
        return []
    label, due = current
    best = _statuses(db, pot)
    return [
        uid for uid in member_ids(db, pot)
        if (best.get((uid, label)) is None or best[(uid, label)].status == "REJECTED")
    ]
