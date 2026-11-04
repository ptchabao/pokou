"""Relances push avant l'expiration d'un abonnement d'officine."""
from datetime import datetime

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models import Pharmacy, PharmacyStaff
from app.services.notifications.push_service import send_push

_REMINDERS = {
    7: ("subscription_reminder_7d_for", "dans 7 jours"),
    1: ("subscription_reminder_1d_for", "demain"),
}


def send_due_subscription_reminders(
    db: Session, now: datetime | None = None
) -> dict[str, int]:
    """Envoie les relances J-7/J-1 une seule fois pour chaque échéance."""
    now = now or datetime.utcnow()
    result = {"j7": 0, "j1": 0}
    pharmacies = (
        db.query(Pharmacy)
        .filter(Pharmacy.subscription_until.isnot(None))
        .all()
    )

    for pharmacy in pharmacies:
        expiry = pharmacy.subscription_until
        days_remaining = (expiry.date() - now.date()).days
        reminder = _REMINDERS.get(days_remaining)
        if reminder is None:
            continue

        tracking_column, timing = reminder
        state_column = getattr(Pharmacy, tracking_column)
        claimed = (
            db.query(Pharmacy)
            .filter(
                Pharmacy.id == pharmacy.id,
                Pharmacy.subscription_until == expiry,
                or_(state_column.is_(None), state_column != expiry),
            )
            .update(
                {tracking_column: expiry},
                synchronize_session=False,
            )
        )
        if not claimed:
            continue

        # Commit the claim before sending: repeated scheduler passes (or a
        # second worker) cannot emit another push for the same expiry.
        db.commit()
        staff_user_ids = {
            row[0]
            for row in db.query(PharmacyStaff.user_id)
            .filter(PharmacyStaff.pharmacy_id == pharmacy.id)
            .all()
        }
        interval_key = f"j{days_remaining}"
        result[interval_key] += 1
        for user_id in staff_user_ids:
            send_push(
                db,
                user_id,
                "Abonnement officine bientôt expiré",
                f"Votre abonnement HONAM expire {timing}. Renouvelez-le pour continuer à recevoir des ordonnances.",
                data={
                    "type": "honam_subscription_reminder",
                    "interval_days": str(days_remaining),
                    "pharmacy_id": str(pharmacy.id),
                },
            )
    return result
