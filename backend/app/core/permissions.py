"""RBAC de l'espace d'administration Pokou.

Un rôle donne un ensemble de PERMISSIONS ; chaque route d'administration
exige une permission, jamais un rôle en dur. SUPER_ADMIN les a toutes.
Les rôles se changent depuis l'espace d'administration (« Équipe »), par un
SUPER_ADMIN seulement.
"""
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, UserRole

ALL = {
    "dashboard.view",
    "users.view", "users.manage",
    "team.view", "team.manage",
    "reports.view", "reports.manage",
    "kory.view",
    "honam.view", "honam.manage",
    "assime.view", "assime.manage",
    "certified.view", "certified.manage",
    "modules.manage",
    "audit.view",
}

ROLE_PERMISSIONS = {
    UserRole.SUPER_ADMIN: ALL,
    UserRole.ADMIN: ALL - {"team.manage"},
    UserRole.SUPPORT: {
        "dashboard.view", "users.view", "users.manage", "team.view",
        "reports.view", "reports.manage", "kory.view", "honam.view",
        "assime.view", "certified.view",
    },
    UserRole.AI_OPERATOR: {
        "dashboard.view", "reports.view", "assime.view", "assime.manage",
        "certified.view", "team.view",
    },
    UserRole.VIEWER: {
        "dashboard.view", "users.view", "kory.view", "honam.view",
        "assime.view", "certified.view", "team.view",
    },
    UserRole.USER: set(),
}

ROLE_LABELS = {
    UserRole.SUPER_ADMIN: "Super-administrateur",
    UserRole.ADMIN: "Administrateur",
    UserRole.SUPPORT: "Support",
    UserRole.AI_OPERATOR: "Opérateur IA / modération",
    UserRole.VIEWER: "Lecture seule",
    UserRole.USER: "Utilisateur",
}


def permissions_of(user: User) -> set:
    return set(ROLE_PERMISSIONS.get(user.role or UserRole.USER, set()))


def require_permission(permission: str):
    """Dépendance FastAPI : le rôle est relu en base à CHAQUE requête."""
    assert permission in ALL, permission

    async def checker(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)) -> User:
        # La console seulement : une session de l'app (code SMS) n'ouvre
        # aucune route d'administration — voir services/auth/console_session.
        if current_user.get("scope") != "console":
            raise HTTPException(status_code=403, detail="Connecte-toi à la console avec ton e-mail")
        user = db.query(User).filter(User.id == current_user.get("user_id")).first()
        if user is None or not user.is_active:
            raise HTTPException(status_code=401, detail="Compte introuvable")
        if permission not in permissions_of(user):
            raise HTTPException(status_code=403, detail="Permission refusée")
        return user

    return checker


def require_permission_claims(permission: str):
    """Comme require_permission, mais rend les claims du jeton (dict avec
    `user_id`) : pour les routes d'administration plus anciennes, écrites
    contre `require_admin_role`, sans toucher leur corps."""
    check = require_permission(permission)

    async def checker(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
        await check(current_user, db)
        return current_user

    return checker
