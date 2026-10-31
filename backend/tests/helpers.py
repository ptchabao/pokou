"""Outils partagés des tests."""
from fastapi import Response

from app.api.v1.auth.auth import _issue_session
from app.models import User


def bearer_for_email(session_factory, email: str) -> dict:
    """En-tête d'authentification d'un compte déjà en base, sans passer par
    l'OTP — pour les comptes d'équipe que les tests créent directement.

    La session est ouverte par la MÊME fonction que la vraie connexion : le
    jeton est révocable et vérifié exactement comme en production."""
    db = session_factory()
    try:
        user = db.query(User).filter(User.email == email).one()
        access_token, _, _ = _issue_session(db, Response(), user)
        return {"Authorization": f"Bearer {access_token}"}
    finally:
        db.close()
