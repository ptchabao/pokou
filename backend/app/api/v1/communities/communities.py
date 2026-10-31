"""Pokou — communautés : un contenant qui regroupe plusieurs groupes autour
d'un même ensemble de personnes (une école, un marché, une entreprise).

Ce n'est pas un groupe géant. Une communauté n'a pas de conversation propre :
elle a un GROUPE D'ANNONCES, créé avec elle, où seuls ses administrateurs
écrivent et où tous ses membres lisent. C'est ce qui la distingue d'un simple
dossier de groupes, et c'est pour ça que rejoindre une communauté inscrit
d'office dans ce groupe.

Réutilise délibérément les groupes existants (routes/groups.py) plutôt que
d'introduire un second type de conversation : un groupe de communauté est un
groupe normal, avec un `community_id`.
"""
import secrets
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Community, CommunityMember, Group, GroupMember, MediaAsset, User
from app.api.v1.messaging.ws import manager
from app.core.security import get_current_user

router = APIRouter(prefix="/communities", tags=["Pokou communities"])

MANAGER_ROLES = ("OWNER", "ADMIN")

ANNOUNCEMENTS_NAME = "Annonces"


class CommunityCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    # Groupes existants à rattacher dès la création — on ne peut rattacher
    # que des groupes qu'on administre soi-même (voir _attach_group).
    group_ids: List[int] = Field(default_factory=list)


class CommunityUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    avatar_media_id: Optional[int] = None
    clear_avatar: bool = False


class CommunityMemberRole(BaseModel):
    role: str = Field(..., pattern="^(ADMIN|MEMBER)$")


class CommunityGroupAdd(BaseModel):
    """Rattache un groupe existant, ou en crée un neuf si `name` est fourni."""
    group_id: Optional[int] = None
    name: Optional[str] = Field(None, min_length=1, max_length=255)


# ─── Sérialisation ────────────────────────────────────────────────────────────

def _serialize_media(asset: MediaAsset) -> dict:
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _serialize_group_summary(group: Group) -> dict:
    return {
        "id": group.id,
        "name": group.name,
        "member_count": len(group.members),
        "is_announcement": group.is_announcement,
        "community_name": group.community.name if group.community else None,
        "avatar": _serialize_media(group.avatar_media) if group.avatar_media else None,
    }


def _serialize_community(community: Community, viewer_id: int, *, with_groups: bool = False) -> dict:
    role = next((m.role for m in community.members if m.user_id == viewer_id), None)
    can_manage = role in MANAGER_ROLES
    payload: Dict[str, Any] = {
        "id": community.id,
        "name": community.name,
        "description": community.description,
        "avatar_media_id": community.avatar_media_id,
        "avatar": _serialize_media(community.avatar_media) if community.avatar_media else None,
        "created_by": community.created_by,
        "created_at": community.created_at.isoformat(),
        "member_count": len(community.members),
        "group_count": len(community.groups),
        "my_role": role,
        "can_manage": can_manage,
        # Comme pour les groupes : le lien n'est visible que des
        # administrateurs, un membre simple ne doit pas faire entrer qui il
        # veut.
        "invite_code": community.invite_code if can_manage else None,
    }
    if with_groups:
        # Le groupe d'annonces d'abord : c'est le cœur de la communauté.
        groups = sorted(community.groups, key=lambda g: (not g.is_announcement, g.id))
        payload["groups"] = [_serialize_group_summary(group) for group in groups]
    return payload


# ─── Autorisation ─────────────────────────────────────────────────────────────

def _require_membership(db: Session, community_id: int, user_id: int) -> CommunityMember:
    membership = db.query(CommunityMember).filter(
        CommunityMember.community_id == community_id, CommunityMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de cette communauté")
    return membership


def _require_manager(db: Session, community_id: int, user_id: int) -> CommunityMember:
    membership = _require_membership(db, community_id, user_id)
    if membership.role not in MANAGER_ROLES:
        raise HTTPException(
            status_code=403, detail="Seuls les administrateurs de la communauté peuvent faire cela"
        )
    return membership


def _require_owner(db: Session, community_id: int, user_id: int) -> CommunityMember:
    membership = _require_membership(db, community_id, user_id)
    if membership.role != "OWNER":
        raise HTTPException(
            status_code=403, detail="Seul le créateur de la communauté peut nommer des administrateurs"
        )
    return membership


def _get_community(db: Session, community_id: int) -> Community:
    community = db.query(Community).filter(Community.id == community_id).first()
    if not community:
        raise HTTPException(status_code=404, detail="Communauté introuvable")
    return community


def _announcement_group(db: Session, community_id: int) -> Optional[Group]:
    return db.query(Group).filter(
        Group.community_id == community_id, Group.is_announcement.is_(True)
    ).first()


def _add_to_announcements(db: Session, community_id: int, user_id: int) -> None:
    """Tous les membres de la communauté lisent les annonces — c'est la
    raison d'être du groupe. Inscrire à part serait un oubli garanti."""
    group = _announcement_group(db, community_id)
    if group is None:
        return
    existing = db.query(GroupMember).filter(
        GroupMember.group_id == group.id, GroupMember.user_id == user_id
    ).first()
    if existing is None:
        db.add(GroupMember(group_id=group.id, user_id=user_id, role="MEMBER"))


def _new_invite_code() -> str:
    return secrets.token_urlsafe(12)[:16]


# ─── Communautés ──────────────────────────────────────────────────────────────

@router.post("")
async def create_community(
    payload: CommunityCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée la communauté ET son groupe d'annonces. Les deux vont ensemble :
    une communauté sans annonces n'aurait aucun moyen de s'adresser à tous
    ses membres, ce qui est son seul intérêt propre."""
    user_id = current_user["user_id"]

    community = Community(
        name=payload.name.strip(),
        description=(payload.description or "").strip() or None,
        created_by=user_id,
    )
    db.add(community)
    db.flush()
    db.add(CommunityMember(community_id=community.id, user_id=user_id, role="OWNER"))

    announcements = Group(
        name=ANNOUNCEMENTS_NAME,
        created_by=user_id,
        community_id=community.id,
        is_announcement=True,
    )
    db.add(announcements)
    db.flush()
    db.add(GroupMember(group_id=announcements.id, user_id=user_id, role="OWNER"))

    for group_id in payload.group_ids:
        _attach_group(db, community, group_id, user_id)

    db.commit()
    db.refresh(community)
    return _serialize_community(community, user_id, with_groups=True)


@router.get("")
async def list_my_communities(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    community_ids = [
        row[0]
        for row in db.query(CommunityMember.community_id)
        .filter(CommunityMember.user_id == user_id)
        .all()
    ]
    communities = (
        db.query(Community).filter(Community.id.in_(community_ids)).order_by(Community.name).all()
        if community_ids
        else []
    )
    return {"items": [_serialize_community(community, user_id) for community in communities]}


@router.get("/{community_id}")
async def get_community(
    community_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_membership(db, community_id, user_id)
    return _serialize_community(_get_community(db, community_id), user_id, with_groups=True)


@router.patch("/{community_id}")
async def update_community(
    community_id: int,
    payload: CommunityUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_manager(db, community_id, user_id)
    community = _get_community(db, community_id)

    if payload.name is not None:
        name = payload.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Le nom de la communauté ne peut pas être vide")
        community.name = name
    if payload.description is not None:
        community.description = payload.description.strip() or None

    if payload.clear_avatar:
        community.avatar_media_id = None
    elif payload.avatar_media_id is not None:
        asset = db.query(MediaAsset).filter(MediaAsset.id == payload.avatar_media_id).first()
        if not asset:
            raise HTTPException(status_code=404, detail="Image introuvable")
        # L'image devient visible par toute la communauté : on ne rattache
        # pas la pièce jointe d'un tiers en devinant son identifiant.
        if asset.uploader_id != user_id:
            raise HTTPException(status_code=403, detail="Cette image ne vous appartient pas")
        community.avatar_media_id = asset.id

    db.commit()
    db.refresh(community)
    return _serialize_community(community, user_id, with_groups=True)


# ─── Groupes de la communauté ─────────────────────────────────────────────────

def _attach_group(db: Session, community: Community, group_id: int, requester_id: int) -> Group:
    """Rattache un groupe EXISTANT. On exige d'en être administrateur : sans
    ça, n'importe qui pourrait absorber le groupe d'autrui dans sa
    communauté, et en exposer le nom à tous ses membres."""
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")

    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == requester_id
    ).first()
    if not membership or membership.role not in MANAGER_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Vous devez être administrateur de ce groupe pour le rattacher",
        )
    if group.community_id is not None and group.community_id != community.id:
        raise HTTPException(status_code=409, detail="Ce groupe appartient déjà à une autre communauté")
    if group.is_announcement:
        raise HTTPException(status_code=400, detail="Un groupe d'annonces ne se rattache pas")

    group.community_id = community.id
    return group


@router.post("/{community_id}/groups")
async def add_group_to_community(
    community_id: int,
    payload: CommunityGroupAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Rattache un groupe existant (`group_id`) ou en crée un dans la
    communauté (`name`)."""
    user_id = current_user["user_id"]
    _require_manager(db, community_id, user_id)
    community = _get_community(db, community_id)

    if payload.group_id is not None:
        group = _attach_group(db, community, payload.group_id, user_id)
    elif payload.name and payload.name.strip():
        group = Group(name=payload.name.strip(), created_by=user_id, community_id=community.id)
        db.add(group)
        db.flush()
        db.add(GroupMember(group_id=group.id, user_id=user_id, role="OWNER"))
    else:
        raise HTTPException(status_code=400, detail="group_id ou name requis")

    db.commit()
    db.refresh(group)
    return _serialize_group_summary(group)


@router.delete("/{community_id}/groups/{group_id}")
async def remove_group_from_community(
    community_id: int,
    group_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Détache le groupe SANS le supprimer : ses conversations continuent
    hors de la communauté."""
    user_id = current_user["user_id"]
    _require_manager(db, community_id, user_id)

    group = db.query(Group).filter(Group.id == group_id, Group.community_id == community_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Ce groupe n'appartient pas à cette communauté")
    if group.is_announcement:
        raise HTTPException(
            status_code=400,
            detail="Le groupe d'annonces ne peut pas être détaché de sa communauté",
        )

    group.community_id = None
    db.commit()
    return {"detached": True, "group_id": group_id}


# ─── Membres ──────────────────────────────────────────────────────────────────

@router.put("/{community_id}/members/{user_id}/role")
async def set_community_member_role(
    community_id: int,
    user_id: int,
    payload: CommunityMemberRole,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    requester_id = current_user["user_id"]
    _require_owner(db, community_id, requester_id)

    if user_id == requester_id:
        raise HTTPException(status_code=400, detail="Le créateur ne peut pas changer son propre rôle")

    membership = db.query(CommunityMember).filter(
        CommunityMember.community_id == community_id, CommunityMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=404, detail="Cette personne n'est pas membre de la communauté")

    membership.role = payload.role
    # Un administrateur de communauté doit pouvoir écrire les annonces :
    # sinon son rôle serait purement décoratif là où il compte le plus.
    announcements = _announcement_group(db, community_id)
    if announcements is not None:
        group_membership = db.query(GroupMember).filter(
            GroupMember.group_id == announcements.id, GroupMember.user_id == user_id
        ).first()
        if group_membership is not None and group_membership.role != "OWNER":
            group_membership.role = "ADMIN" if payload.role == "ADMIN" else "MEMBER"

    db.commit()
    return {"user_id": user_id, "role": membership.role}


@router.delete("/{community_id}/members/{user_id}")
async def leave_community(
    community_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Quitter, ou retirer quelqu'un (administrateurs). Les groupes de la
    communauté ne sont PAS quittés au passage : on n'expulse pas quelqu'un de
    conversations où il a été invité personnellement. Seul le groupe
    d'annonces, qui n'existe que par la communauté, est quitté."""
    requester_id = current_user["user_id"]
    requester = _require_membership(db, community_id, requester_id)
    if user_id != requester_id and requester.role not in MANAGER_ROLES:
        raise HTTPException(
            status_code=403, detail="Seuls les administrateurs peuvent retirer un autre membre"
        )

    target = db.query(CommunityMember).filter(
        CommunityMember.community_id == community_id, CommunityMember.user_id == user_id
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="Cette personne n'est pas membre de la communauté")
    if target.role == "OWNER" and user_id != requester_id:
        raise HTTPException(status_code=403, detail="Le créateur ne peut pas être retiré")

    announcements = _announcement_group(db, community_id)
    if announcements is not None:
        db.query(GroupMember).filter(
            GroupMember.group_id == announcements.id, GroupMember.user_id == user_id
        ).delete()

    db.delete(target)
    db.commit()
    return {"removed": True, "community_id": community_id, "user_id": user_id}


# ─── Lien d'invitation ────────────────────────────────────────────────────────

@router.post("/{community_id}/invite-link")
async def create_community_invite_link(
    community_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_manager(db, community_id, user_id)
    community = _get_community(db, community_id)
    community.invite_code = _new_invite_code()
    db.commit()
    return {"invite_code": community.invite_code}


@router.delete("/{community_id}/invite-link")
async def revoke_community_invite_link(
    community_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    _require_manager(db, community_id, user_id)
    community = _get_community(db, community_id)
    community.invite_code = None
    db.commit()
    return {"revoked": True}


@router.get("/invite/{invite_code}")
async def preview_community_invite(
    invite_code: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    community = db.query(Community).filter(Community.invite_code == invite_code).first()
    if not community:
        raise HTTPException(status_code=404, detail="Ce lien d'invitation n'est plus valide")

    already_member = db.query(CommunityMember).filter(
        CommunityMember.community_id == community.id,
        CommunityMember.user_id == current_user["user_id"],
    ).first() is not None
    # Ni la liste des membres ni celle des groupes : on ne révèle pas la
    # composition d'une communauté à quelqu'un qui n'y est pas encore.
    return {
        "id": community.id,
        "name": community.name,
        "description": community.description,
        "avatar": _serialize_media(community.avatar_media) if community.avatar_media else None,
        "member_count": len(community.members),
        "group_count": len(community.groups),
        "already_member": already_member,
    }


@router.post("/invite/{invite_code}/join")
async def join_community_by_invite(
    invite_code: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Rejoindre inscrit dans la communauté ET dans son groupe d'annonces —
    mais dans AUCUN autre groupe : les rejoindre reste un choix, un par un."""
    user_id = current_user["user_id"]
    community = db.query(Community).filter(Community.invite_code == invite_code).first()
    if not community:
        raise HTTPException(status_code=404, detail="Ce lien d'invitation n'est plus valide")

    existing = db.query(CommunityMember).filter(
        CommunityMember.community_id == community.id, CommunityMember.user_id == user_id
    ).first()
    if existing is None:
        db.add(CommunityMember(community_id=community.id, user_id=user_id, role="MEMBER"))
    _add_to_announcements(db, community.id, user_id)
    db.commit()
    db.refresh(community)

    joiner = db.query(User).filter(User.id == user_id).first()
    display_name = (joiner.full_name or joiner.phone or "Utilisateur") if joiner else "Utilisateur"
    for member in community.members:
        if member.user_id == user_id:
            continue
        await manager.send_to_user(
            member.user_id,
            {
                "type": "community:member:added",
                "community_id": community.id,
                "member": {"user_id": user_id, "display_name": display_name, "role": "MEMBER"},
            },
        )
    await manager.send_to_user(
        user_id,
        {
            "type": "community:member:added",
            "community_id": community.id,
            "member": {"user_id": user_id, "display_name": display_name, "role": "MEMBER"},
        },
    )
    return _serialize_community(community, user_id, with_groups=True)
