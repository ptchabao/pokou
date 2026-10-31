"""Contrôle d'accès des routes d'administration.

Un membre de l'équipe Pokou est un compte ordinaire dont `User.role` n'est pas
USER (voir models/user.py::UserRole). Le rôle se promeut en base, jamais
depuis l'application : `python -m scripts.promote_admin +228…`.
"""
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, UserRole


def require_admin_role(allowed_roles: list):
    """Dépendance FastAPI : refuse quiconque n'a pas l'un des `allowed_roles`.

    SUPER_ADMIN passe toujours.

    Le rôle est relu en base à CHAQUE requête : le JWT ne porte que
    `sub`/`user_id`, et un rôle embarqué dans le jeton survivrait à sa
    révocation jusqu'à l'expiration de celui-ci.
    """

    async def role_checker(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
        user_id = current_user.get("user_id")
        user = db.query(User).filter(User.id == user_id).first() if user_id is not None else None
        if not user:
            raise HTTPException(status_code=401, detail="Utilisateur introuvable")

        user_role = user.role.value if user.role else UserRole.USER.value
        try:
            role_enum = UserRole(user_role)
        except ValueError:
            raise HTTPException(status_code=403, detail="Invalid user role")

        if role_enum == UserRole.SUPER_ADMIN or role_enum in allowed_roles:
            return {**current_user, "role": user_role}

        raise HTTPException(
            status_code=403,
            detail=f"Role '{user_role}' does not have access. Required: {[r.value for r in allowed_roles]}",
        )

    return role_checker
