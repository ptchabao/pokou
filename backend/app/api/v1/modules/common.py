"""Ce que les cinq modules partagent.

Écrit une fois plutôt que cinq : le verrou d'activation et l'ouverture d'un
paiement sont les deux points où une inattention coûte cher. Recopiés dans
chaque module, ils finiraient par diverger — et c'est celui qu'on a oublié de
corriger qui laisserait passer quelque chose.
"""
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models import AppModule, MarketplacePayment, User, UserModuleActivation
from app.services.marketplace.marketplace_monetization_service import create_payment


def require_module(db: Session, user_id: int, slug: str) -> None:
    """Le module doit être ouvert par l'équipe ET activé par la personne.

    Les deux. Sans la première condition, une fonctionnalité fermée resterait
    joignable par appel direct à l'API — et l'interrupteur d'équipe ne
    servirait plus à rien au moment précis où il doit servir, quand il faut
    couper vite.

    404 et non 403 : un refus distinct révélerait l'existence d'un module non
    publié.
    """
    row = (
        db.query(AppModule.id)
        .join(UserModuleActivation, UserModuleActivation.module_id == AppModule.id)
        .filter(
            AppModule.slug == slug,
            AppModule.is_enabled.is_(True),
            UserModuleActivation.user_id == user_id,
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Module indisponible")


def open_payment(
    db: Session, user_id: int, *, kind: str, amount: int, description: str, metadata: dict
) -> MarketplacePayment:
    """Ouvre un paiement Mobile Money, sans rien accorder.

    L'effet est posé à la CONFIRMATION, dans
    `marketplace_monetization_service.confirm_payment` — le seul endroit où
    un paiement devient effectif. Un module qui accorderait ici serait
    gratuit pour qui abandonne à l'écran de la passerelle.
    """
    user = db.query(User).filter(User.id == user_id).first()
    try:
        return create_payment(
            db, user, kind=kind, amount=amount, description=description, metadata=metadata
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def payment_json(payment: MarketplacePayment) -> dict:
    return {
        "payment_id": payment.id,
        "status": payment.status.lower(),
        "amount": payment.amount,
        "currency": payment.currency,
        "payment_url": payment.payment_url,
    }
