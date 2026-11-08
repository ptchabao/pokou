"""Outils partagés des tests."""
from fastapi import Response

from app.api.v1.auth.auth import _issue_session
from app.models import User, UserRole


def bearer_for_email(session_factory, email: str) -> dict:
    """En-tête d'authentification d'un compte déjà en base, sans passer par
    l'OTP — pour les comptes d'équipe que les tests créent directement.

    La session est ouverte par la MÊME fonction que la vraie connexion : le
    jeton est révocable et vérifié exactement comme en production."""
    db = session_factory()
    try:
        user = db.query(User).filter(User.email == email).one()
        if user.role is not None and user.role != UserRole.USER:
            # Un compte d'équipe n'entre dans l'administration que par la
            # console (e-mail + mot de passe) : sa session en porte la marque.
            return console_bearer(session_factory, user.id)
        access_token, _, _ = _issue_session(db, Response(), user)
        return {"Authorization": f"Bearer {access_token}"}
    finally:
        db.close()


def console_bearer(session_factory, user_id: int) -> dict:
    """Session de console (celle de POST /admin/auth/login) pour un compte."""
    from app.services.auth.console_session import issue_console_session
    db = session_factory()
    try:
        user = db.get(User, user_id)
        return {"Authorization": f"Bearer {issue_console_session(db, user)}"}
    finally:
        db.close()
