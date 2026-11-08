"""Les sessions de la console d'administration.

La console ne s'ouvre QUE par e-mail et mot de passe (POST /admin/auth/login),
jamais par le numéro de téléphone de l'app. Ses jetons portent donc une
marque, `scope = "console"`, que exigent toutes les routes d'administration
(app/core/permissions.py) : une session de l'app — obtenue par code SMS —
ne donne accès à aucune d'elles, même pour un membre de l'équipe.

Huit heures, une journée de travail : au-delà, on se reconnecte. Le jeton est
adossé à une ligne Token, donc révocable (suspension, déconnexion).
"""
import secrets
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.models import Token, User

CONSOLE_SCOPE = "console"
CONSOLE_SESSION = timedelta(hours=8)


def issue_console_session(db: Session, user: User) -> str:
    jti = secrets.token_urlsafe(16)
    subject = user.email or user.phone or str(user.id)
    token = create_access_token(
        {"sub": subject, "user_id": user.id, "scope": CONSOLE_SCOPE},
        expires_delta=CONSOLE_SESSION, jti=jti,
    )
    from app.api.v1.auth.auth import _token_digest

    db.add(Token(
        user_id=user.id,
        access_token=_token_digest(token),
        # Pas de jeton de rafraîchissement pour la console : une empreinte
        # aléatoire occupe la colonne, qui ne correspondra à aucun jeton.
        refresh_token=_token_digest(secrets.token_urlsafe(32)),
        jti=jti,
        expires_at=datetime.utcnow() + CONSOLE_SESSION,
    ))
    db.commit()
    return token
