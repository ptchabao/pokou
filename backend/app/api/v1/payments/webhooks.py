"""Rappels des prestataires de paiement (Semoa Mobile Money).

Une commande Semoa porte son URL de rappel (voir
services/payments/semoa_client.py::build_callback_url) : c'est ici qu'elle
aboutit, et c'est le SEUL chemin par lequel un paiement est confirmé — boost,
publicité, dossier vendeur, certification de chaîne, modules payants,
recharge Pokou Business.
"""
import hmac

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services import settings_service
from app.services.marketplace import marketplace_monetization_service

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

_PAID_STATUSES = {"paid", "success", "completed", "confirmed"}


def _verify_webhook_secret(db: Session, request: Request) -> None:
    """Fermé par défaut : sans `semoa_webhook_secret` configuré, le rappel
    est refusé — sinon n'importe qui pourrait confirmer un paiement.
    Comparaison à temps constant."""
    configured_secret = settings_service.get_setting(db, "semoa_webhook_secret")
    if not configured_secret:
        raise HTTPException(status_code=401, detail="Webhook non configuré (secret manquant)")

    provided_secret = request.headers.get("X-Webhook-Secret") or request.query_params.get("secret") or ""
    if not hmac.compare_digest(provided_secret, configured_secret):
        raise HTTPException(status_code=401, detail="Signature webhook invalide")


@router.post("/marketplace-payment/semoa")
async def semoa_marketplace_payment_webhook(request: Request, db: Session = Depends(get_db)):
    """Confirme un paiement Mobile Money."""
    _verify_webhook_secret(db, request)
    body = await request.json()
    reference = body.get("reference") or body.get("order_reference") or request.query_params.get("reference")
    status_value = str(body.get("status") or "").lower()
    if not reference:
        raise HTTPException(status_code=400, detail="reference manquante")
    if status_value and status_value not in _PAID_STATUSES:
        return {"status": "ignored", "reason": f"payment status is '{status_value}'"}
    try:
        return marketplace_monetization_service.confirm_payment(db, reference)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
