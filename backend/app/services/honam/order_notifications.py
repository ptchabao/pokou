"""Privacy-safe push notifications for HONAM order state changes."""

from sqlalchemy.orm import Session

from app.models import HonamOrder, PharmacyStaff
from app.services.notifications.push_service import send_push


_TITLE = "Mise à jour HONAM"
_BODY = "Un changement est disponible dans le suivi de votre commande."


def notify_order_state_changed(
    db: Session,
    order: HonamOrder,
    *,
    actor_id: int | None,
) -> None:
    """Notify only the users participating in this order, excluding its actor."""
    recipient_ids = {order.patient_id}
    recipient_ids.update(
        row[0]
        for row in db.query(PharmacyStaff.user_id)
        .filter(PharmacyStaff.pharmacy_id == order.pharmacy_id)
        .all()
    )
    if order.courier_id is not None:
        recipient_ids.add(order.courier_id)
    if actor_id is not None:
        recipient_ids.discard(actor_id)

    payload = {
        "type": "honam_order_status",
        "order_id": str(order.id),
        "status": order.status,
        "priority": "normal",
        "muted": "0",
    }
    for user_id in recipient_ids:
        send_push(db, user_id, _TITLE, _BODY, data=payload)
