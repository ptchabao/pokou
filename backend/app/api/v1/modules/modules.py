"""Pokou — catalogue des modules activables.

Deux publics dans un seul fichier, et la frontière est nette : les routes
sans préfixe d'administration s'adressent à l'utilisateur et ne montrent
QUE ce que l'équipe a ouvert ; celles sous `/admin` s'adressent à l'équipe et
montrent tout, y compris ce qui n'est pas encore publié.

C'est cette séparation qui permet de préparer un module — le décrire, le
positionner, le recommander — sans qu'il apparaisse à personne avant d'être
prêt.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.rbac import require_admin_role
from app.core.database import get_db
from app.models import AppModule, UserModuleActivation, UserRole
from app.core.audit import AuditLogger
from app.core.security import get_current_user

router = APIRouter(prefix="/modules", tags=["Pokou modules"])
admin_router = APIRouter(prefix="/admin/modules", tags=["Admin modules"])

_TEAM_ROLES = [UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR]

#: Au-delà, « Populaires » ne veut plus rien dire — tout y serait.
_POPULAR_LIMIT = 6


def _activation_counts(db: Session, module_ids: List[int]) -> dict[int, int]:
    """Combien de personnes ont activé chaque module, en UNE requête.

    Compté à la volée plutôt que tenu dans une colonne : un compteur
    dénormalisé se désynchronise au premier chemin qui oublie de
    l'incrémenter, et « populaire » deviendrait faux sans que personne ne
    s'en aperçoive.
    """
    if not module_ids:
        return {}
    rows = (
        db.query(UserModuleActivation.module_id, func.count(UserModuleActivation.id))
        .filter(UserModuleActivation.module_id.in_(module_ids))
        .group_by(UserModuleActivation.module_id)
        .all()
    )
    return {module_id: count for module_id, count in rows}


def _serialize(module: AppModule, *, activated: bool, users: int) -> dict:
    return {
        "id": module.id,
        "slug": module.slug,
        "name": module.name,
        "tagline": module.tagline,
        "description": module.description,
        "icon": module.icon,
        "accent_color": module.accent_color,
        "category": module.category,
        "is_recommended": bool(module.is_recommended),
        "is_activated": activated,
        "user_count": users,
    }


@router.get("")
async def list_modules(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le catalogue, en trois rayons.

    Le serveur construit les trois listes plutôt que de renvoyer un tas que
    le client trierait : « recommandé » est un choix ÉDITORIAL de l'équipe et
    « populaire » se calcule sur l'ensemble des utilisateurs — deux
    informations que le client n'a pas et ne doit pas avoir à deviner.

    Un module que l'équipe a coupé n'apparaît nulle part, y compris pour
    quelqu'un qui l'avait activé : son activation est conservée en base et
    reprendra effet à la réouverture, sans qu'on lui redemande quoi que ce
    soit.
    """
    user_id = current_user["user_id"]
    modules = (
        db.query(AppModule)
        .filter(AppModule.is_enabled.is_(True))
        .order_by(AppModule.position, AppModule.name)
        .all()
    )
    if not modules:
        return {"mine": [], "recommended": [], "popular": []}

    module_ids = [m.id for m in modules]
    counts = _activation_counts(db, module_ids)
    activated_ids = {
        row[0]
        for row in db.query(UserModuleActivation.module_id).filter(
            UserModuleActivation.user_id == user_id,
            UserModuleActivation.module_id.in_(module_ids),
        )
    }

    serialized = [
        _serialize(m, activated=m.id in activated_ids, users=counts.get(m.id, 0))
        for m in modules
    ]

    mine = [m for m in serialized if m["is_activated"]]
    # « Recommandés » exclut ce qu'on a déjà : recommander à quelqu'un ce
    # qu'il utilise déjà est le plus sûr moyen de lui apprendre à ignorer la
    # section.
    recommended = [m for m in serialized if m["is_recommended"] and not m["is_activated"]]
    popular = sorted(
        (m for m in serialized if not m["is_activated"]),
        key=lambda m: (-m["user_count"], m["name"]),
    )[:_POPULAR_LIMIT]

    return {"mine": mine, "recommended": recommended, "popular": popular}


def _enabled_module(db: Session, slug: str) -> AppModule:
    module = db.query(AppModule).filter(AppModule.slug == slug).first()
    if not module or not module.is_enabled:
        # Même réponse pour « n'existe pas » et « fermé par l'équipe » : un
        # 403 distinct révélerait l'existence d'un module non publié.
        raise HTTPException(status_code=404, detail="Module introuvable")
    return module


@router.post("/{slug}/activate")
async def activate_module(
    slug: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Idempotent : réactiver ce qui l'est déjà répond 200.

    Un double appui sur un interrupteur ne doit pas produire une erreur pour
    un état déjà obtenu.
    """
    module = _enabled_module(db, slug)
    user_id = current_user["user_id"]
    existing = (
        db.query(UserModuleActivation)
        .filter(
            UserModuleActivation.user_id == user_id,
            UserModuleActivation.module_id == module.id,
        )
        .first()
    )
    if existing is None:
        db.add(UserModuleActivation(user_id=user_id, module_id=module.id))
        db.commit()
    return {"slug": module.slug, "is_activated": True}


@router.delete("/{slug}/activate")
async def deactivate_module(
    slug: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    module = _enabled_module(db, slug)
    db.query(UserModuleActivation).filter(
        UserModuleActivation.user_id == current_user["user_id"],
        UserModuleActivation.module_id == module.id,
    ).delete()
    db.commit()
    return {"slug": module.slug, "is_activated": False}


# ─── Administration ─────────────────────────────────────────────────────────


@admin_router.get("")
async def admin_list_modules(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """TOUT le catalogue, ouvert ou non — c'est la différence avec la route
    utilisateur, et c'est ce qui permet de préparer un module avant de le
    publier."""
    modules = db.query(AppModule).order_by(AppModule.position, AppModule.name).all()
    counts = _activation_counts(db, [m.id for m in modules])
    return {
        "items": [
            {
                **_serialize(m, activated=False, users=counts.get(m.id, 0)),
                "is_enabled": bool(m.is_enabled),
            }
            for m in modules
        ]
    }


class ModuleUpdate(BaseModel):
    is_enabled: Optional[bool] = None
    is_recommended: Optional[bool] = None
    position: Optional[int] = Field(None, ge=0, le=999)


@admin_router.put("/{slug}")
async def admin_update_module(
    slug: str,
    payload: ModuleUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_role(_TEAM_ROLES)),
):
    """Ouvrir, fermer, recommander, ordonner.

    Fermer un module ne touche PAS les activations : elles sont conservées et
    reprennent effet à la réouverture. On ne redemande pas à quelqu'un de
    réactiver ce qu'il avait choisi parce qu'on a fermé la fonctionnalité une
    semaine — et surtout, on garde la trace de qui s'y intéressait, qui est
    la seule donnée permettant de décider s'il faut la rouvrir.
    """
    module = db.query(AppModule).filter(AppModule.slug == slug).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")

    changes = {}
    if payload.is_enabled is not None:
        module.is_enabled = payload.is_enabled
        changes["is_enabled"] = payload.is_enabled
    if payload.is_recommended is not None:
        module.is_recommended = payload.is_recommended
        changes["is_recommended"] = payload.is_recommended
    if payload.position is not None:
        module.position = payload.position
        changes["position"] = payload.position
    db.commit()

    if changes:
        await AuditLogger.log(
            db, current_user["user_id"], "update", "app_module", module.id, changes=changes
        )
    return {
        "slug": module.slug,
        "is_enabled": bool(module.is_enabled),
        "is_recommended": bool(module.is_recommended),
        "position": module.position,
    }
