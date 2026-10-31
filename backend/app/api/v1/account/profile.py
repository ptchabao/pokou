"""Pokou — profil utilisateur (nom, bio, avatar). L'avatar est un
MediaAsset comme les autres pièces jointes (voir media_storage.py) —
uploadé via POST /media/upload puis référencé ici par son id."""
import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session, aliased, joinedload

from app.core.database import get_db
from app.models import Contact, DirectMessage, Group, GroupMember, MediaAsset, MessageType, SellerVerificationApplication, User
from app.services.privacy import privacy_service
from app.utils.identity import est_certifie, est_vendeur_verifie
from app.core.security import get_current_user

# Bornes de la fiche contact : on remplit des sections (médias, documents,
# liens), pas un historique complet — la conversation elle-même reste la
# source de vérité et se pagine, elle.
_SHARED_MEDIA_LIMIT = 100
_SHARED_LINK_SCAN_LIMIT = 200
_LINK_PATTERN = re.compile(r"https?://[^\s]+|www\.[^\s]+")

router = APIRouter(tags=["Pokou profile"])


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=255)
    about: Optional[str] = Field(None, max_length=140)
    avatar_media_id: Optional[int] = None


def _serialize_avatar(asset: Optional[MediaAsset]) -> Optional[dict]:
    if asset is None:
        return None
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


# Un avatar est un média comme un autre : même forme sérialisée, deux noms
# pour que les appels se lisent (`_serialize_media(piece_jointe)`).
_serialize_media = _serialize_avatar


def _serialize(user: User) -> dict:
    return {
        "id": user.id,
        "phone": user.phone,
        "full_name": user.full_name,
        "about": user.about,
        "is_verified": est_certifie(user),
        "is_bot": bool(user.is_bot),
        "avatar_media_id": user.avatar_media_id,
        "avatar": _serialize_avatar(user.avatar_media),
        "products": [
            {
                "id": product.id,
                "name": product.name,
                "description": product.description,
                "price": str(product.price),
                "currency": product.currency,
                "image": _serialize_avatar(product.image_media),
            }
            for product in user.marketplace_products
            if product.is_active
        ],
    }


@router.get("/users/me/profile")
async def get_my_profile(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    profile = _serialize(user)
    # Le statut VENDEUR, en plus du ✓ d'identité de `_serialize`. C'est lui
    # que pose l'approbation du dossier ouvert depuis « Vérifier mon compte »
    # (voir marketplace_admin.py::decide_verification) : sans ces deux champs,
    # un vendeur approuvé voyait encore l'invitation à se faire vérifier et
    # aucune trace de sa certification. Réservé à `me` — la date de fin ne
    # regarde que le titulaire.
    profile["is_certified_seller"] = est_vendeur_verifie(user)
    profile["certified_seller_until"] = (
        user.certified_seller_until.isoformat()
        if profile["is_certified_seller"] and user.certified_seller_until
        else None
    )
    profile["is_certification_pending"] = (
        db.query(SellerVerificationApplication.id)
        .filter(
            SellerVerificationApplication.seller_id == user.id,
            SellerVerificationApplication.status == "PENDING",
        )
        .first()
        is not None
    )
    return profile


@router.put("/users/me/profile")
async def update_my_profile(
    payload: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.about is not None:
        user.about = payload.about
    if payload.avatar_media_id is not None:
        asset = db.query(MediaAsset).filter(MediaAsset.id == payload.avatar_media_id).first()
        # L'upload doit avoir été fait par l'utilisateur lui-même — même
        # garde que pour les pièces jointes de messages/statuts.
        if not asset or asset.uploader_id != user.id:
            raise HTTPException(status_code=404, detail="Pièce jointe introuvable")
        user.avatar_media_id = asset.id

    db.commit()
    db.refresh(user)
    return _serialize(user)


@router.get("/users/{user_id}/profile")
async def get_user_profile(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Visible pour qui CONNAÎT déjà la personne — jamais par un identifiant
    deviné : les `user_id` sont séquentiels, et sans garde-fou n'importe quel
    compte connecté parcourrait toute la base en incrémentant un compteur.

    « Connaître », c'est la règle d'envoi de messages.py::_require_reachable,
    et non plus « l'avoir dans MON carnet ». L'ancienne règle donnait un
    écran vide — 403 — à la question la plus naturelle qui soit : « qui
    m'écrit ? ». Quelqu'un qui vous a dans son répertoire vous écrit, vous
    n'avez pas son numéro (ou il est enregistré sans indicatif et la
    synchronisation ne l'a pas retrouvé) : on pouvait lui répondre, pas
    regarder sa fiche, ni donc l'enregistrer depuis celle-ci.

    Ce qui ouvre la fiche, du moins cher au plus cher :
    - l'un des deux a l'autre dans son carnet ;
    - une conversation existe entre les deux ;
    - un groupe les réunit.

    Les champs que la personne a choisi de masquer restent masqués : la
    fiche s'ouvre, ses réglages de confidentialité s'appliquent ensuite."""
    viewer_id = current_user["user_id"]
    is_contact = db.query(Contact).filter(
        Contact.owner_user_id == viewer_id, Contact.contact_user_id == user_id
    ).first()
    if not is_contact and not _se_connaissent(db, viewer_id, user_id):
        raise HTTPException(status_code=403, detail="Ce profil n'est pas accessible")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    profile = _serialize(user)

    # ── Ce que la personne a choisi de ne pas montrer ne PART PAS ────────
    #
    # Pas « le client ne l'affiche pas » : le client ne le reçoit pas. Un
    # champ masqué côté application se retrouve tôt ou tard dans un cache,
    # une capture de requête, ou un écran qui a oublié la règle.
    #
    # `null` plutôt qu'un 403 sur tout le profil : un refus explicite
    # apprendrait au demandeur que quelqu'un se cache, exactement ce qu'il ne
    # veut pas dire. Un champ vide se lit comme « rien à afficher ».
    if not privacy_service.peut_voir(
        db, user.id, viewer_id, privacy_service.Aspect.PHOTO_DE_PROFIL, cible=user
    ):
        profile["avatar"] = None
        profile["avatar_media_id"] = None
    if not privacy_service.peut_voir(
        db, user.id, viewer_id, privacy_service.Aspect.INFOS_DE_PROFIL, cible=user
    ):
        profile["about"] = None
    conversation = or_(
        and_(DirectMessage.sender_id == viewer_id, DirectMessage.recipient_id == user_id),
        and_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == viewer_id),
    )

    # Pièces jointes échangées, séparées comme dans la fiche contact de
    # WhatsApp : les visuels se regardent en grille, les documents se lisent
    # en liste. Un seul type mélangé obligerait le client à retrier.
    shared = (
        db.query(DirectMessage)
        .options(joinedload(DirectMessage.media_asset))
        .filter(conversation, DirectMessage.media_asset_id.isnot(None))
        .order_by(DirectMessage.created_at.desc())
        .limit(_SHARED_MEDIA_LIMIT)
        .all()
    )
    visuals: list[dict] = []
    documents: list[dict] = []
    for message in shared:
        asset = message.media_asset
        if asset is None:
            continue
        # Métadonnée complète (mime + taille) et non juste un id : le client
        # a besoin du type MIME pour nommer le fichier qu'il met en cache
        # (voir mediaExtension côté Flutter) et de la taille pour l'afficher.
        entry = {
            "media": _serialize_media(asset),
            "message_type": message.message_type.value,
            "created_at": message.created_at.isoformat(),
        }
        if message.message_type in (MessageType.IMAGE, MessageType.VIDEO):
            visuals.append(entry)
        else:
            documents.append(entry)

    # Liens cités dans la conversation, dédoublonnés en gardant l'ordre du
    # plus récent au plus ancien (un `set` seul les remonterait dans un
    # ordre arbitraire, ce qui rend la liste illisible à la relecture).
    seen_links: dict[str, str] = {}
    for message in (
        db.query(DirectMessage)
        .filter(conversation, DirectMessage.content.isnot(None))
        .order_by(DirectMessage.created_at.desc())
        .limit(_SHARED_LINK_SCAN_LIMIT)
        .all()
    ):
        for link in _LINK_PATTERN.findall(message.content or ""):
            seen_links.setdefault(link, message.created_at.isoformat())

    profile["shared_media"] = visuals
    profile["shared_documents"] = documents
    profile["shared_links"] = [
        {"url": url, "created_at": created_at} for url, created_at in seen_links.items()
    ]

    # Groupes en commun — ceux dont NOUS DEUX sommes membres. Une seule
    # requête avec auto-jointure sur group_members plutôt que deux listes
    # rapatriées puis intersectées en Python.
    mine = aliased(GroupMember)
    theirs = aliased(GroupMember)
    common_groups = (
        db.query(Group)
        .join(mine, mine.group_id == Group.id)
        .join(theirs, theirs.group_id == Group.id)
        .filter(mine.user_id == viewer_id, theirs.user_id == user_id)
        .order_by(Group.name)
        .all()
    )
    # ── La règle « visibilité de mon appartenance aux groupes » ─────────
    #
    # Elle s'applique ICI, et nulle part ailleurs — ce qui demande une
    # explication, parce que ça ne saute pas aux yeux.
    #
    # Pokou n'expose JAMAIS l'appartenance à un non-membre : la liste des
    # membres d'un groupe passe par `_require_membership`, et l'aperçu d'un
    # lien d'invitation donne le nombre de personnes sans leurs noms
    # (groups.py::preview_invite). Il n'y a donc rien à fermer de ce côté.
    #
    # « Groupes en commun » est différent par NATURE. Ce n'est pas un membre
    # qu'on regarde dans un groupe, c'est un AGRÉGAT remis sans qu'on l'ait
    # demandé : « voici tous les groupes que cette personne partage avec
    # vous ». Aller chercher la même chose à la main demanderait d'ouvrir
    # chaque groupe et d'en parcourir la liste ; l'agrégation est
    # précisément ce qui transforme une information disponible en
    # information servie.
    #
    # Ce que cette règle ne touche PAS : la liste des membres d'un groupe.
    # Les membres d'un groupe continuent de se connaître entre eux quoi
    # qu'il arrive — sinon la confidentialité casserait le fonctionnement du
    # groupe, ce qui n'aiderait personne. Quelqu'un réglé sur « Personne »
    # reste donc parfaitement visible DANS les groupes qu'il partage ; il
    # n'apparaît simplement plus dans cette liste-là.
    if privacy_service.peut_voir(
        db,
        user.id,
        viewer_id,
        privacy_service.Aspect.APPARTENANCE_GROUPES,
        cible=user,
    ):
        profile["common_groups"] = [
            {"id": group.id, "name": group.name, "member_count": len(group.members)}
            for group in common_groups
        ]
    else:
        # Liste VIDE et non champ absent : le client affiche « aucun groupe
        # en commun », ce qui se lit naturellement. Retirer la clé
        # l'obligerait à distinguer « pas de groupe » de « je n'ai pas le
        # droit de savoir », distinction qui n'a pas à exister côté écran.
        profile["common_groups"] = []

    # État de blocage tel que MOI je l'ai posé (voir routes/conversations.py) —
    # c'est ce qui permet à la fiche d'afficher « Bloquer » ou « Débloquer »
    # sans un second appel.
    profile["is_blocked"] = bool(is_contact and is_contact.is_blocked)
    profile["contact_display_name"] = is_contact.display_name if is_contact else None
    # Absent de MON carnet : la fiche propose de l'y ajouter.
    profile["is_contact"] = is_contact is not None
    return profile


def _se_connaissent(db: Session, viewer_id: int, other_id: int) -> bool:
    """Le reste de la règle de get_user_profile, une fois MON carnet écarté
    (il a déjà été lu par l'appelant, qui a besoin de la ligne)."""
    if viewer_id == other_id:
        return True
    if (
        db.query(Contact.id)
        .filter(Contact.owner_user_id == other_id, Contact.contact_user_id == viewer_id)
        .first()
    ):
        return True
    if (
        db.query(DirectMessage.id)
        .filter(
            or_(
                and_(DirectMessage.sender_id == viewer_id, DirectMessage.recipient_id == other_id),
                and_(DirectMessage.sender_id == other_id, DirectMessage.recipient_id == viewer_id),
            )
        )
        .first()
    ):
        return True
    mine = aliased(GroupMember)
    theirs = aliased(GroupMember)
    return (
        db.query(mine.id)
        .join(theirs, theirs.group_id == mine.group_id)
        .filter(mine.user_id == viewer_id, theirs.user_id == other_id)
        .first()
        is not None
    )
