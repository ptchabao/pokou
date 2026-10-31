"""Pokou — présence (« en ligne », « vu à ») et indicateur de saisie.

Deux états de nature opposée cohabitent ici, et c'est ce qui dicte leur
stockage :

- « vu à » est durable, et n'est écrit qu'aux transitions de connexion du
  WebSocket (voir app/routes/ws.py::_touch_last_seen) ;
- « en train d'écrire » ne dure que quelques secondes et n'est JAMAIS
  persisté : il ne vit que dans l'événement WebSocket diffusé.

« En ligne » n'est pas davantage une colonne : c'est le registre de sockets
du ConnectionManager qui répond. Un drapeau en base survivrait au crash du
processus et laisserait des utilisateurs éternellement « en ligne ».

Réciprocité façon WhatsApp, appliquée à la LECTURE et non seulement
documentée : masquer son « vu à » prive aussi de celui de ses contacts.
Sans cela le réglage serait un avantage gratuit — tout voir sans être vu.
"""
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Contact, GroupMember, User
from app.api.v1.messaging.ws import manager
from app.services.privacy import privacy_service
from app.core.security import get_current_user

router = APIRouter(prefix="/presence", tags=["Pokou presence"])

# Borne de la version groupée : la liste de conversations demande la présence
# des lignes qu'elle affiche, pas de l'annuaire entier. Sans plafond, un
# `IN (…)` de plusieurs milliers d'identifiants serait constructible par un
# seul appel.
MAX_BATCH_IDS = 200


class PresenceSettings(BaseModel):
    presence_visible: bool


class TypingSignal(BaseModel):
    """`kind` distingue les deux formes de conversation, `id` désigne le
    contact ou le groupe selon `kind` — un seul champ pour les deux, comme le
    client n'a jamais qu'une conversation ouverte à la fois."""
    kind: str = Field(..., pattern="^(contact|group)$")
    id: int
    typing: bool


# ─── Autorisation ─────────────────────────────────────────────────────────────

def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> None:
    """Qui ai-je le droit de savoir en train d'écrire ?

    La règle doit être EXACTEMENT celle de l'envoi, et elle ne l'était pas.
    messages.py a été assoupli — on peut écrire à quelqu'un hors carnet dès
    qu'on peut le désigner autrement qu'en devinant son identifiant — et
    cette fonction est restée sur l'ancienne règle, « uniquement mon
    carnet ».

    Le résultat se voyait : on ouvrait la conversation, on écrivait, le
    message partait, et chaque frappe déclenchait un 403 silencieux sur
    /presence/typing. Le correspondant ne voyait jamais « écrit… », sans que
    rien n'explique pourquoi.

    Deux règles pour une même relation finissent toujours par diverger. On
    réutilise donc celle de l'envoi, qui est la plus complète — carnet,
    conversation existante, ou groupe commun. Le numéro n'en fait pas partie
    ici : il sert de laissez-passer pour un PREMIER message, et signaler sa
    frappe avant d'avoir écrit quoi que ce soit n'a pas de sens.
    """
    # Import local : messages.py importe déjà de ce module au chargement.
    from app.api.v1.messaging.messages import _require_reachable

    _require_reachable(db, owner_id, contact_user_id)


def _require_membership(db: Session, group_id: int, user_id: int) -> None:
    """Dans un groupe, l'appartenance remplace la relation de contact (même
    règle que groups.py) : être ajouté au groupe EST la mise en relation."""
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")


# ─── Lecture de la présence ───────────────────────────────────────────────────

def _display_name(user: Optional[User]) -> str:
    if not user:
        return "Inconnu"
    return user.full_name or user.phone or f"#{user.id}"


def _load_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user


def _is_visible(viewer: User, target: User) -> bool:
    """La RÉCIPROCITÉ, conservée : il faut que les deux aient gardé leur
    « vu à » visible. Se cacher des autres n'a pas de raison de se cacher de
    soi-même.

    C'est un préalable, pas la règle complète : les deux aspects
    « en ligne » et « dernière activité » sont réglés SÉPARÉMENT par
    `privacy_service` — quelqu'un peut vouloir montrer qu'il est en ligne
    sans montrer à quelle heure il l'était hier soir. Voir
    `_serialize_presence`.
    """
    if viewer.id == target.id:
        return True
    return bool(viewer.presence_visible) and bool(target.presence_visible)


async def _serialize_presence(db: Session, viewer: User, target: User) -> dict:
    """Présence masquée = champs à `null`, jamais une erreur : l'absence
    d'information n'est pas une faute, et un 403 apprendrait au demandeur
    que la personne se cache — exactement ce qu'elle ne veut pas dire.

    Asynchrone depuis que « en ligne » se lit dans le registre PARTAGÉ et
    non dans le dictionnaire du processus : quelqu'un connecté à une autre
    instance était vu hors ligne, ce qui affichait un « vu à » périmé et
    envoyait une notification à quelqu'un qui regardait son écran."""
    reciproque = _is_visible(viewer, target)
    # DEUX règles, et non une. « En ligne maintenant » et « vu à 23 h 14 »
    # ne disent pas la même chose : on peut vouloir qu'un correspondant sache
    # qu'on est joignable à l'instant, sans lui apprendre à quelle heure on
    # s'est couché. Les fondre aurait obligé à renoncer aux deux pour en
    # cacher une.
    montre_en_ligne = reciproque and privacy_service.peut_voir(
        db, target.id, viewer.id, privacy_service.Aspect.EN_LIGNE, cible=target
    )
    montre_vu_a = reciproque and privacy_service.peut_voir(
        db, target.id, viewer.id, privacy_service.Aspect.DERNIERE_ACTIVITE, cible=target
    )
    return {
        "user_id": target.id,
        # `null` et non `false` : « je ne dis pas » n'est pas « hors ligne ».
        # Le client ne dessine le point vert que sur un oui franc, et ne doit
        # jamais transformer une absence de réponse en absence tout court.
        "is_online": (await manager.is_online(target.id)) if montre_en_ligne else None,
        "last_seen_at": (
            target.last_seen_at.isoformat()
            if montre_vu_a and target.last_seen_at
            else None
        ),
    }


def _parse_ids(raw: str) -> List[int]:
    """`user_ids=1,2,3` plutôt qu'un corps de requête : c'est un GET, et le
    client construit cette liste à partir de la liste de conversations qu'il
    vient d'afficher."""
    ids: List[int] = []
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            value = int(chunk)
        except ValueError:
            raise HTTPException(status_code=400, detail="Liste d'identifiants invalide")
        if value not in ids:
            ids.append(value)
    if not ids:
        raise HTTPException(status_code=400, detail="Liste d'identifiants invalide")
    if len(ids) > MAX_BATCH_IDS:
        raise HTTPException(
            status_code=400,
            detail=f"Au plus {MAX_BATCH_IDS} identifiants par appel",
        )
    return ids


# ─── Réglages ─────────────────────────────────────────────────────────────────
# Déclarés AVANT `/{user_id}` : FastAPI teste les routes dans l'ordre
# d'enregistrement, et `/presence/settings` serait sinon capturé par le
# chemin paramétré, qui refuserait « settings » comme entier.

@router.get("/settings")
async def get_presence_settings(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = _load_user(db, current_user["user_id"])
    return {"presence_visible": bool(user.presence_visible)}


@router.put("/settings")
async def update_presence_settings(
    payload: PresenceSettings,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le client doit voir la contrepartie avant de basculer : couper son
    « vu à » coupe aussi celui de ses contacts (voir `_is_visible`)."""
    user = _load_user(db, current_user["user_id"])
    user.presence_visible = payload.presence_visible
    db.commit()
    return {"presence_visible": bool(user.presence_visible)}


# ─── Consultation ─────────────────────────────────────────────────────────────

@router.get("")
async def get_presence_batch(
    user_ids: str = Query(..., description="Identifiants séparés par des virgules"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Version groupée pour que la liste de conversations ne fasse pas un
    appel par ligne. Les identifiants qui ne sont pas des contacts sont
    simplement ABSENTS de la réponse plutôt que refusés : un seul id devenu
    hors carnet ne doit pas priver tout l'écran de sa présence."""
    viewer = _load_user(db, current_user["user_id"])
    ids = _parse_ids(user_ids)

    allowed = {
        row[0]
        for row in db.query(Contact.contact_user_id).filter(
            Contact.owner_user_id == viewer.id, Contact.contact_user_id.in_(ids)
        ).all()
    }
    if viewer.id in ids:
        allowed.add(viewer.id)

    found: Dict[int, User] = {
        user.id: user
        for user in (db.query(User).filter(User.id.in_(allowed)).all() if allowed else [])
    }
    # Ordre de la requête conservé : le client aligne la réponse sur les
    # lignes qu'il a déjà dessinées.
    return {
        "items": [
            await _serialize_presence(db, viewer, found[uid]) for uid in ids if uid in found
        ]
    }


@router.get("/{user_id}")
async def get_presence(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    viewer = _load_user(db, current_user["user_id"])
    if user_id != viewer.id:
        _require_contact(db, viewer.id, user_id)
    return await _serialize_presence(db, viewer, _load_user(db, user_id))


# ─── Indicateur de saisie ─────────────────────────────────────────────────────

@router.post("/typing")
async def notify_typing(
    payload: TypingSignal,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Diffusion pure, sans AUCUNE écriture en base : l'état ne vaut que
    trois secondes et le client le renvoie tant que la frappe continue, donc
    persister chaque signal reviendrait à un UPDATE par mot tapé pour une
    donnée périmée avant d'être relue. Pas de notification push non plus —
    « est en train d'écrire » n'a aucun sens pour qui n'est pas devant
    l'écran.

    Le réglage `presence_visible` ne s'applique pas ici : écrire dans une
    conversation est un acte volontaire adressé à quelqu'un, pas
    l'observation passive que masque le « vu à »."""
    author = _load_user(db, current_user["user_id"])

    if payload.kind == "contact":
        _require_contact(db, author.id, payload.id)
        recipient_ids = [payload.id]
    else:
        _require_membership(db, payload.id, author.id)
        # L'auteur est exclu : il sait qu'il écrit, et se voir soi-même
        # « en train d'écrire » afficherait un indicateur fantôme sur ses
        # autres appareils.
        recipient_ids = [
            row[0]
            for row in db.query(GroupMember.user_id).filter(
                GroupMember.group_id == payload.id, GroupMember.user_id != author.id
            ).all()
        ]

    event = {
        "type": "typing",
        "kind": payload.kind,
        "id": payload.id,
        "user_id": author.id,
        "typing": payload.typing,
        # Nom résolu côté serveur, comme `sender_name` dans groups.py : en
        # groupe le client doit écrire « Awa écrit… » immédiatement, il n'a
        # pas le temps de résoudre un nom par un second appel pour un état
        # qui aura disparu avant la réponse.
        "user_name": _display_name(author),
    }

    reached = 0
    for recipient_id in recipient_ids:
        if await manager.send_to_user(recipient_id, event):
            reached += 1
    return {"notified": reached}
