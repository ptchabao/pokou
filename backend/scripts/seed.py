"""Données de départ, jouées à CHAQUE déploiement, juste après les migrations.

Idempotent : ne crée que ce qui manque, et ne modifie jamais ce que l'équipe
a réglé depuis la console (un module fermé reste fermé).

1. Le catalogue des modules (sans lui, l'onglet Modules de l'app est vide).
2. Le super-administrateur de la console :
     POKOU_SUPERADMIN_EMAIL     (défaut : admin@pokou.app)
     POKOU_SUPERADMIN_PASSWORD  (facultatif : sinon, un mot de passe aléatoire)
     POKOU_SUPERADMIN_PHONE     (facultatif : rattache un compte Pokou existant)
     POKOU_SUPERADMIN_NAME      (défaut : « Administrateur Pokou »)
   Le mot de passe n'est affiché qu'UNE fois, dans les journaux du
   déploiement qui crée le compte — à changer dès la première connexion
   (Console → menu du compte). Les déploiements suivants ne l'affichent plus.

    python -m scripts.seed
"""
import os
import secrets
import sys

from app import models  # noqa: F401
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models import AppModule, User, UserRole

# (slug, nom, accroche, description, icône, couleur, catégorie, recommandé)
MODULES = [
    ("heart_league", "Ligue des cœurs", "Qui fait battre le plus de cœurs ?",
     "Un classement amical entre amis, renouvelé chaque semaine.", "favorite", "#A4512A", "SOCIAL", True),
    ("streak_lock", "Série de flammes", "Ne laisse pas s'éteindre la flamme",
     "Échangez chaque jour pour faire grandir votre série.", "local_fire_department", "#B86D3B", "SOCIAL", True),
    ("truth_market", "Marché de la vérité", "Pariez sur ce que pensent vos amis",
     "Des questions, des pronostics, et la vérité au bout.", "help_center", "#245C9E", "JEUX", False),
    ("social_tax", "Taxe sociale", "Une petite cagnotte pour les retardataires",
     "Le groupe fixe les règles, les retards alimentent la caisse commune.", "savings", "#1E7A46", "SOCIAL", False),
    ("vip_room", "Salon VIP", "Un espace réservé à vos meilleurs fans",
     "Partagez du contenu exclusif avec un cercle choisi.", "verified_user", "#D4AF37", "CREATEURS", False),
    ("hype_train", "Hype Train", "Faites monter la hype ensemble",
     "Chaque soutien fait avancer le train jusqu'au prochain palier.", "rocket_launch", "#7F3D1E", "CREATEURS", False),
    ("spark", "Spark", "Des rencontres près de chez toi (18+)",
     "Découvre des personnes à moins de 5 km, en toute sécurité.", "auto_awesome", "#C2410C", "RENCONTRES", False),
    ("bible_verses", "Versets bibliques", "Un verset pour chaque jour",
     "Une parole de la Bible chaque matin, à partager.", "menu_book", "#5E3418", "SPIRITUALITE", True),
    ("quran_verses", "Versets du Coran", "Un verset pour chaque jour",
     "Une parole du Coran chaque matin, à partager.", "auto_stories", "#1E7A46", "SPIRITUALITE", False),
]


def seed_modules(db) -> int:
    existing = {slug for (slug,) in db.query(AppModule.slug)}
    added = 0
    for position, (slug, name, tagline, description, icon, color, category, recommended) in enumerate(MODULES):
        if slug in existing:
            continue
        db.add(AppModule(
            slug=slug, name=name, tagline=tagline, description=description, icon=icon,
            accent_color=color, category=category, is_enabled=True,
            is_recommended=recommended, position=position * 10,
        ))
        added += 1
    db.commit()
    return added


def seed_superadmin(db) -> None:
    email = os.environ.get("POKOU_SUPERADMIN_EMAIL", "admin@pokou.app").strip().lower()
    phone = os.environ.get("POKOU_SUPERADMIN_PHONE", "").strip()
    name = os.environ.get("POKOU_SUPERADMIN_NAME", "Administrateur Pokou").strip()

    user = db.query(User).filter(User.email == email).first()
    if user is None and phone:
        from app.services.auth.otp_service import normalize_phone
        user = db.query(User).filter(User.phone == normalize_phone(phone)).first()
        if user is not None and not user.email:
            user.email = email
    created = user is None
    if created:
        user = User(email=email, full_name=name, role=UserRole.SUPER_ADMIN, is_active=True)
        db.add(user)
    user.role = UserRole.SUPER_ADMIN
    user.is_active = True

    password = None
    if not user.console_password_hash:
        password = os.environ.get("POKOU_SUPERADMIN_PASSWORD") or secrets.token_urlsafe(12)
        user.console_password_hash = hash_password(password)
    db.commit()

    base = os.environ.get("PUBLIC_LINK_BASE_URL", "https://apipokou.cabinet-p-et-associes.com").rstrip("/")
    print("─" * 64)
    print(f"Console d'administration : {base}/console/")
    print(f"Super-administrateur     : {email}" + (" (créé)" if created else ""))
    if password and not os.environ.get("POKOU_SUPERADMIN_PASSWORD"):
        print(f"Mot de passe             : {password}")
        print("→ affiché une seule fois : change-le dès la première connexion.")
    elif password:
        print("Mot de passe             : celui de POKOU_SUPERADMIN_PASSWORD")
    else:
        print("Mot de passe             : inchangé (déjà défini)")
    print("─" * 64)


def main() -> int:
    db = SessionLocal()
    try:
        added = seed_modules(db)
        print(f"Seed : {added} module(s) ajouté(s) au catalogue.")
        seed_superadmin(db)
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
