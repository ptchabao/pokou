"""Heart League — le classement, vu depuis l'application.

Toutes les règles vivent dans `services/heart_league_service.py`. Ce module
ne fait que les appliquer à des lignes de base : c'est la séparation qui
permet de tester la mécanique sans base ni requête, et de la relire sans
avoir à démêler du SQL.

Le module doit être ACTIVÉ pour que ces routes répondent. Sans cette
vérification, une fonctionnalité fermée par l'équipe resterait joignable en
appelant l'API directement — ce qui viderait l'interrupteur de son sens.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import AppModule, HeartLeaguePass, HeartLeagueProfile, User, UserModuleActivation
from app.services.modules import heart_league_service as league
from app.services.marketplace.marketplace_monetization_service import create_payment
from app.core.security import get_current_user

router = APIRouter(prefix="/heart-league", tags=["Pokou Heart League"])

MODULE_SLUG = "heart_league"

#: Protection hebdomadaire contre le décompte. Une semaine, renouvelable.
PROTECTION_AMOUNT = 500
PROTECTION_DAYS = 7

#: Laissez-passer pour écrire à quelqu'un de deux ligues au-dessus.
PASS_AMOUNT = 500
PASS_DAYS = 7


def _require_module(db: Session, user_id: int) -> None:
    """Le module doit être ouvert par l'équipe ET activé par la personne.

    Les deux, et pas seulement le second : sans la première condition, une
    fonctionnalité fermée resterait joignable par appel direct à l'API, et
    l'interrupteur d'équipe ne servirait plus à rien au moment précis où il
    doit servir — quand il faut couper vite.
    """
    row = (
        db.query(AppModule.id)
        .join(UserModuleActivation, UserModuleActivation.module_id == AppModule.id)
        .filter(
            AppModule.slug == MODULE_SLUG,
            AppModule.is_enabled.is_(True),
            UserModuleActivation.user_id == user_id,
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Module indisponible")


def _profile(db: Session, user_id: int) -> HeartLeagueProfile:
    """Charge le profil en appliquant le décompte dû AU PASSAGE.

    Calculé à la lecture plutôt que par une tâche de fond : un ordonnanceur
    en panne gèlerait sinon tout le classement sans que personne ne s'en
    aperçoive, et la panne ne se verrait qu'au moment où quelqu'un
    remarquerait que ses points ne bougent plus.
    """
    profile = (
        db.query(HeartLeagueProfile)
        .filter(HeartLeagueProfile.user_id == user_id)
        .first()
    )
    now = datetime.utcnow()
    if profile is None:
        profile = HeartLeagueProfile(user_id=user_id, week_start=now)
        db.add(profile)
        db.commit()
        db.refresh(profile)
        return profile

    points, week_start = league.apply_decay(
        profile.points, profile.best_points, profile.week_start,
        profile.protected_until, now,
    )
    if points != profile.points or week_start != profile.week_start:
        profile.points = points
        profile.week_start = week_start
        db.commit()
    return profile


def _serialize(profile: HeartLeagueProfile, *, now: datetime) -> dict:
    current = league.league_for(profile.points)
    upper = league.next_league(profile.points)
    protected = profile.protected_until is not None and profile.protected_until > now
    return {
        "points": profile.points,
        "best_points": profile.best_points,
        "league": {"code": current.code, "label": current.label, "rank": current.rank},
        "next_league": (
            {"code": upper.code, "label": upper.label, "points_needed": upper.threshold - profile.points}
            if upper
            else None
        ),
        "progress": round(league.progress_to_next(profile.points), 3),
        "is_protected": protected,
        "protected_until": profile.protected_until.isoformat() if protected else None,
        # Le nombre de jours avant le prochain décompte, pour que l'écran
        # puisse le DIRE au lieu de laisser découvrir la perte après coup.
        "days_until_decay": max(
            0, 7 - (now - profile.week_start).days
        ),
    }


def award_points(db: Session, user_id: int, points: int) -> None:
    """Crédite des points — appelé par les autres modules, jamais par une
    route publique.

    Publique, elle permettrait à n'importe qui de s'attribuer le sommet du
    classement en une requête. Les points ne viennent que de signaux reçus,
    constatés côté serveur.

    Silencieux si le module n'est pas actif pour cette personne : les autres
    modules n'ont pas à savoir qui l'a activé, et une exception ici ferait
    échouer l'envoi d'un message pour une raison sans rapport.
    """
    active = (
        db.query(AppModule.id)
        .join(UserModuleActivation, UserModuleActivation.module_id == AppModule.id)
        .filter(
            AppModule.slug == MODULE_SLUG,
            AppModule.is_enabled.is_(True),
            UserModuleActivation.user_id == user_id,
        )
        .first()
    )
    if active is None:
        return

    profile = _profile(db, user_id)
    profile.points += points
    profile.best_points = max(profile.best_points, profile.points)
    db.commit()


@router.get("/me")
async def my_league(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    _require_module(db, current_user["user_id"])
    profile = _profile(db, current_user["user_id"])
    return _serialize(profile, now=datetime.utcnow())


@router.get("/leaderboard")
async def leaderboard(
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le classement, et MA place dedans.

    La place personnelle est renvoyée même hors du top : un classement où
    l'on ne se voit pas ne dit rien à celui qui le consulte, et c'est
    précisément lui qu'on cherche à faire revenir.
    """
    user_id = current_user["user_id"]
    _require_module(db, user_id)
    mine = _profile(db, user_id)

    rows = (
        db.query(HeartLeagueProfile, User)
        .join(User, User.id == HeartLeagueProfile.user_id)
        .order_by(HeartLeagueProfile.points.desc(), HeartLeagueProfile.user_id)
        .limit(limit)
        .all()
    )
    my_rank = (
        db.query(HeartLeagueProfile)
        .filter(HeartLeagueProfile.points > mine.points)
        .count()
        + 1
    )
    return {
        "items": [
            {
                "rank": index + 1,
                "user_id": profile.user_id,
                "display_name": user.full_name or user.phone or "Joueur",
                "points": profile.points,
                "league": league.league_for(profile.points).code,
                "is_me": profile.user_id == user_id,
            }
            for index, (profile, user) in enumerate(rows)
        ],
        "my_rank": my_rank,
        "my_points": mine.points,
    }


@router.get("/can-write/{target_id}")
async def can_write(
    target_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Puis-je écrire à cette personne sans laissez-passer ?

    Consultée par l'écran AVANT d'ouvrir la conversation : découvrir le
    péage après avoir tapé son message est la pire façon de le présenter.
    """
    user_id = current_user["user_id"]
    _require_module(db, user_id)
    if target_id == user_id:
        return {"allowed": True, "needs_pass": False}

    mine = _profile(db, user_id)
    target = (
        db.query(HeartLeagueProfile)
        .filter(HeartLeagueProfile.user_id == target_id)
        .first()
    )
    target_points = target.points if target else 0

    if not league.needs_pass(mine.points, target_points):
        return {"allowed": True, "needs_pass": False}

    now = datetime.utcnow()
    has_pass = (
        db.query(HeartLeaguePass)
        .filter(
            HeartLeaguePass.buyer_id == user_id,
            HeartLeaguePass.target_id == target_id,
            HeartLeaguePass.expires_at > now,
        )
        .first()
    )
    return {
        "allowed": has_pass is not None,
        "needs_pass": has_pass is None,
        "pass_amount": PASS_AMOUNT,
        "target_league": league.league_for(target_points).label,
    }


def _start_payment(db: Session, user_id: int, kind: str, amount: int, description: str, metadata: dict):
    user = db.query(User).filter(User.id == user_id).first()
    try:
        return create_payment(db, user, kind=kind, amount=amount, description=description, metadata=metadata)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/protection")
async def buy_protection(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Suspend le décompte pour une semaine.

    L'effet n'est posé qu'à la CONFIRMATION du paiement (voir
    `apply_confirmed_payment`) : accorder la protection avant que l'argent
    n'arrive la rendrait gratuite pour qui abandonne à l'écran de paiement.
    """
    user_id = current_user["user_id"]
    _require_module(db, user_id)
    payment = _start_payment(
        db, user_id, "LEAGUE_PROTECTION", PROTECTION_AMOUNT,
        "Heart League — protection hebdomadaire",
        {"module": MODULE_SLUG, "days": PROTECTION_DAYS},
    )
    db.commit()
    return {
        "payment_id": payment.id,
        "status": payment.status.lower(),
        "amount": payment.amount,
        "currency": payment.currency,
        "payment_url": payment.payment_url,
    }


@router.post("/pass/{target_id}")
async def buy_pass(
    target_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_module(db, user_id)
    if target_id == user_id:
        raise HTTPException(status_code=400, detail="Destinataire invalide")
    if not db.query(User.id).filter(User.id == target_id).first():
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    payment = _start_payment(
        db, user_id, "LEAGUE_PASS", PASS_AMOUNT,
        "Heart League — laissez-passer",
        {"module": MODULE_SLUG, "target_id": target_id, "days": PASS_DAYS},
    )
    db.commit()
    return {
        "payment_id": payment.id,
        "status": payment.status.lower(),
        "amount": payment.amount,
        "currency": payment.currency,
        "payment_url": payment.payment_url,
    }


def apply_confirmed_payment(db: Session, payment) -> Optional[dict]:
    """Pose l'effet d'un paiement Heart League, une fois l'argent confirmé.

    Appelé par `marketplace_monetization_service.confirm_payment`, qui est le
    SEUL endroit où un paiement devient effectif — tous les modules passent
    par là plutôt que d'avoir chacun son chemin, pour qu'il n'existe qu'un
    seul endroit où vérifier qu'on n'accorde rien avant d'avoir été payé.
    """
    metadata = payment.metadata_json or {}
    now = datetime.utcnow()

    if payment.kind == "LEAGUE_PROTECTION":
        profile = _profile(db, payment.user_id)
        base = profile.protected_until if (profile.protected_until and profile.protected_until > now) else now
        # Cumulatif : acheter deux semaines d'affilée en donne deux, pas une.
        profile.protected_until = base + timedelta(days=int(metadata.get("days", PROTECTION_DAYS)))
        return {"protected_until": profile.protected_until.isoformat()}

    if payment.kind == "LEAGUE_PASS":
        target_id = metadata.get("target_id")
        if not target_id:
            return None
        db.add(HeartLeaguePass(
            buyer_id=payment.user_id,
            target_id=int(target_id),
            payment_id=payment.id,
            expires_at=now + timedelta(days=int(metadata.get("days", PASS_DAYS))),
        ))
        return {"pass_target_id": int(target_id)}

    return None
