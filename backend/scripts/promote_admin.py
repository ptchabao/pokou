"""Donne un rôle d'équipe à un compte existant.

    python -m scripts.promote_admin +22890123456            # ADMIN
    python -m scripts.promote_admin +22890123456 SUPER_ADMIN
    python -m scripts.promote_admin +22890123456 USER       # retire le rôle

Le compte doit exister : la personne se connecte d'abord une fois à
l'application avec ce numéro. Les rôles ne se donnent jamais depuis l'API,
pour qu'aucune faille d'une route ne puisse fabriquer un administrateur.
"""
import sys

from app import models  # noqa: F401
from app.core.database import SessionLocal
from app.models import User, UserRole
from app.services.auth.otp_service import OTPInvalidError, normalize_phone


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print(__doc__)
        return 2
    try:
        phone = normalize_phone(argv[1])
    except OTPInvalidError as exc:
        print(exc)
        return 2
    try:
        role = UserRole(argv[2].upper()) if len(argv) == 3 else UserRole.ADMIN
    except ValueError:
        print(f"Rôle inconnu. Possibles : {', '.join(r.value for r in UserRole)}")
        return 2

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.phone == phone).first()
        if user is None:
            print(f"Aucun compte pour {phone} — la personne doit d'abord se connecter une fois.")
            return 1
        user.role = role
        db.commit()
        print(f"{phone} (#{user.id}) → {role.value}")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
