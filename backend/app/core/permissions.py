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
    "kory.view", "kory.manage",
    "honam.view", "honam.manage",
    "assime.view", "assime.manage",
    "certified.view", "certified.manage",
    "modules.manage",
    "banners.view", "banners.manage",
    "audit.view",
    "countries.view", "countries.manage",
    "settings.manage",
    "roles.manage",
}

#: Ce que chaque permission autorise, regroupé comme dans la console.
PERMISSION_CATALOG = [
    ("Général", [("dashboard.view", "Voir le tableau de bord"), ("audit.view", "Voir le journal d'audit")]),
    ("Utilisateurs", [("users.view", "Voir les comptes"), ("users.manage", "Suspendre, réactiver, modifier les comptes")]),
    ("Équipe", [("team.view", "Voir l'équipe"), ("team.manage", "Ajouter des membres, changer leur rôle"),
                ("roles.manage", "Créer et modifier les rôles")]),
    ("Signalements", [("reports.view", "Voir les signalements"), ("reports.manage", "Traiter les signalements")]),
    ("Kory", [("kory.view", "Voir les collectes"), ("kory.manage", "Geler, intervenir sur une collecte")]),
    ("Honam", [("honam.view", "Voir officines, commandes, coursiers"), ("honam.manage", "Valider officines et coursiers, intervenir")]),
    ("Assimé", [("assime.view", "Voir les annonces"), ("assime.manage", "Modérer les annonces")]),
    ("Pokou certifié", [("certified.view", "Voir les dossiers"), ("certified.manage", "Valider ou refuser les dossiers")]),
    ("Contenus", [("banners.view", "Voir les bannières"), ("banners.manage", "Gérer les bannières"),
                  ("modules.manage", "Ouvrir ou fermer les modules")]),
    ("Configuration", [("countries.view", "Voir les réglages par pays"), ("countries.manage", "Modifier les réglages par pays"),
                       ("settings.manage", "Modifier les réglages système")]),
]
assert {k for _, items in PERMISSION_CATALOG for k, _ in items} == ALL

#: Réservée au super-administrateur : un rôle qui pourrait modifier les rôles
#: pourrait se donner tous les droits.
SUPER_ADMIN_ONLY = {"roles.manage"}

ROLE_PERMISSIONS = {
    UserRole.SUPER_ADMIN: ALL,
    UserRole.ADMIN: ALL - {"team.manage", "roles.manage"},
    UserRole.SUPPORT: {
        "dashboard.view", "users.view", "users.manage", "team.view",
        "reports.view", "reports.manage", "kory.view", "honam.view",
        "assime.view", "certified.view", "banners.view", "countries.view",
        "honam.manage", "audit.view",
    },
    UserRole.AI_OPERATOR: {
        "dashboard.view", "reports.view", "assime.view", "assime.manage",
        "certified.view", "team.view",
        "reports.manage", "certified.manage",
    },
    UserRole.VIEWER: {
        "dashboard.view", "users.view", "kory.view", "honam.view", "reports.view",
        "assime.view", "certified.view", "team.view", "banners.view",
        "countries.view",
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


#: Les rôles prédéfinis dont les permissions se modifient dans la console.
EDITABLE_SYSTEM_ROLES = [UserRole.ADMIN, UserRole.SUPPORT, UserRole.AI_OPERATOR, UserRole.VIEWER]


def permissions_of(user: User) -> set:
    """Les permissions effectives d'un compte.

    Super-administrateur : toutes, toujours. Sinon, le rôle créé par
    l'équipe s'il en a un, puis le rôle prédéfini tel que modifié dans la
    console, puis sa valeur par défaut."""
    from sqlalchemy.orm import object_session

    from app.models import AdminRole

    role = user.role or UserRole.USER
    if role == UserRole.SUPER_ADMIN:
        return set(ALL)
    if role == UserRole.USER:
        return set()
    allowed = ALL - SUPER_ADMIN_ONLY
    custom = getattr(user, "admin_role", None)
    if custom is not None:
        return custom.permission_set() & allowed
    session = object_session(user)
    if session is not None:
        row = session.query(AdminRole).filter(AdminRole.key == role.value).first()
        if row is not None:
            return row.permission_set() & allowed
    return set(ROLE_PERMISSIONS.get(role, set())) & allowed


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
