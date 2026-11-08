"""Pokou — réglages personnels d'une conversation (épingler, archiver, mettre
en sourdine, bloquer/signaler) et liste unifiée de l'écran d'accueil.

Une conversation est soit un contact (1:1), soit un groupe. Épingler,
archiver et mettre en sourdine sont des choix PERSONNELS : ils vivent donc
sur `Contact` (qui appartient déjà à une personne) et sur `GroupMember`
(l'appartenance), jamais sur `Group` — sinon mettre un groupe en sourdine le
rendrait muet pour ses 200 membres.

C'est ce qui explique la forme des routes : `{kind, id}` plutôt que deux jeux
d'endpoints. Les deux types de conversation portent les mêmes quatre
colonnes de réglages, seule la ligne qui les porte change, et le client
affiche une seule liste où les deux se mélangent.
"""
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import and_, case, func, or_
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models import Community, Contact, DirectMessage, Group, GroupMember, GroupMessage, MediaAsset, MessageStatus, User
from app.utils.identity import est_certifie, nom_affiche
from app.core.security import get_current_user

router = APIRouter(prefix="/conversations", tags=["Pokou conversations"])

logger = logging.getLogger(__name__)

# Trois épingles au total, comme WhatsApp — et volontairement pas trois par
# type : la limite protège le HAUT DE LA LISTE, qui est commun aux contacts
# et aux groupes. Au-delà, l'épingle ne distingue plus rien.
MAX_PINNED_CONVERSATIONS = 3

# « Toujours » = une date si lointaine qu'elle n'arrivera pas (≈ 100 ans).
# Aucune colonne booléenne en plus : `muted_until` étant déjà une date, « 8
# heures » et « toujours » se disent de la même façon, le silence expire tout
# seul sans tâche de fond, et il n'y a pas deux sources de vérité à garder
# cohérentes (un `is_muted=true` avec une date échue serait indécidable).
MUTE_FOREVER_SECONDS = 3155760000

# Les trois durées de WhatsApp : 8 h, 1 semaine, toujours. Liste fermée
# comme les durées d'éphémère de messages.py : le client affiche trois
# libellés, une valeur libre n'aurait aucun libellé à afficher, et la borne
# haute évite au passage qu'un `duration_seconds` absurde (10**18) fasse
# déborder l'addition de dates en 500.
MUTE_DURATIONS = (28800, 604800, MUTE_FOREVER_SECONDS)

# Aperçu du dernier message dans la liste : de quoi remplir une ligne, pas
# de quoi transférer tout l'historique à chaque ouverture de l'écran.
LAST_MESSAGE_PREVIEW_LENGTH = 80


class ConversationRef(BaseModel):
    kind: str = Field(..., pattern="^(contact|group)$")
    id: int


class PinRequest(ConversationRef):
    pinned: bool


class ArchiveRequest(ConversationRef):
    archived: bool


class MuteRequest(ConversationRef):
    """`duration_seconds` est obligatoire mais peut valoir `null` (= réactiver
    le son). Obligatoire et non optionnel à défaut : un champ oublié ne doit
    pas se traduire silencieusement par « remets le son »."""
    duration_seconds: Optional[int] = Field(...)


class BlockRequest(BaseModel):
    """Pas de `kind` ici : bloquer n'a de sens qu'en 1:1. « Bloquer un
    groupe » se dit déjà autrement — le quitter, ou le mettre en sourdine."""
    contact_user_id: int
    blocked: bool


class ReportRequest(BaseModel):
    contact_user_id: int
    reason: str = Field(..., min_length=1, max_length=500)
    # Deux gestes distincts : on peut signaler un abus sans se couper de la
    # personne (un litige commercial en cours, par exemple), et l'immense
    # majorité des signalements s'accompagne quand même d'un blocage — d'où
    # l'option, plutôt qu'un blocage automatique ou deux appels à enchaîner.
    also_block: bool = False


# ─── Sérialisation ────────────────────────────────────────────────────────────

def _serialize_media(asset: Optional[MediaAsset]) -> Optional[dict]:
    if asset is None:
        return None
    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _is_muted(muted_until: Optional[datetime]) -> bool:
    """Le seul juge de « est-ce en sourdine ? ». Calculé côté serveur et
    exposé dans chaque réponse : laisser le client comparer la date à son
    horloge, c'est accepter qu'un téléphone mal réglé rate des notifications
    (ou en reçoive alors qu'il devrait se taire)."""
    return muted_until is not None and muted_until > datetime.utcnow()


def _settings_payload(kind: str, conversation_id: int, row: Any) -> dict:
    """Les réglages tels que les renvoient pin/archive/mute : la même forme
    pour un contact et pour un groupe, puisque le client stocke les deux dans
    la même liste."""
    payload = {
        "kind": kind,
        "id": conversation_id,
        "is_pinned": bool(row.is_pinned),
        "pinned_at": row.pinned_at.isoformat() if row.pinned_at else None,
        "is_archived": bool(row.is_archived),
        "muted_until": row.muted_until.isoformat() if row.muted_until else None,
        "is_muted": _is_muted(row.muted_until),
    }
    if kind == "contact":
        payload["is_blocked"] = bool(row.is_blocked)
    return payload


def _preview(content: Optional[str]) -> Optional[str]:
    if not content:
        return None
    if len(content) <= LAST_MESSAGE_PREVIEW_LENGTH:
        return content
    return content[:LAST_MESSAGE_PREVIEW_LENGTH] + "…"


def _message_type_value(message_type: Any) -> str:
    return getattr(message_type, "value", message_type)


# ─── Autorisation ─────────────────────────────────────────────────────────────

def _require_own_contact(db: Session, contact_id: int, user_id: int) -> Contact:
    """404 et non 403 sur le contact d'autrui : `contacts.id` est une suite
    d'entiers, répondre « interdit » confirmerait à qui les essaie que la
    ligne existe — donc qu'une personne donnée est dans le carnet d'un
    autre."""
    contact = db.query(Contact).filter(
        Contact.id == contact_id, Contact.owner_user_id == user_id
    ).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Conversation introuvable")
    return contact


def _require_membership(db: Session, group_id: int, user_id: int) -> GroupMember:
    """403 ici, à la différence du contact : l'existence d'un groupe n'est pas
    un secret (un lien d'invitation la révèle déjà), et c'est le code que
    routes/groups.py renvoie partout — le client a déjà le message d'erreur
    correspondant."""
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")
    return membership


def _resolve_target(db: Session, ref: ConversationRef, user_id: int) -> Any:
    """Rend la LIGNE qui porte les réglages : `Contact` pour un 1:1,
    `GroupMember` pour un groupe. Toutes les routes de réglage passent par
    ici, pour qu'aucune ne puisse oublier la vérification d'appartenance."""
    if ref.kind == "contact":
        return _require_own_contact(db, ref.id, user_id)
    return _require_membership(db, ref.id, user_id)


def _require_contact_by_user(db: Session, owner_id: int, contact_user_id: int) -> Contact:
    """Même garde-fou que messages.py::_require_contact : on n'agit que sur
    les gens de son propre carnet d'adresses. `is_blocked` vit sur la ligne
    Contact, il n'y a donc rien où inscrire le blocage d'un inconnu."""
    contact = db.query(Contact).filter(
        Contact.owner_user_id == owner_id, Contact.contact_user_id == contact_user_id
    ).first()
    if not contact:
        raise HTTPException(
            status_code=403, detail="Ce contact n'est pas dans votre carnet d'adresses"
        )
    return contact


def is_blocked_between(db: Session, sender_id: int, recipient_id: int) -> bool:
    """Le canal entre deux personnes est-il coupé par un blocage ?

    DESTINÉE AUX ROUTES D'ENVOI : routes/messages.py (envoi, transfert,
    réaction) et routes/calls.py (émission d'appel) doivent l'appeler avant
    de persister quoi que ce soit, et refuser l'envoi si elle est vraie. Elle
    vit ici parce que le blocage est un réglage de conversation ; elle est
    exposée (pas préfixée `_`) précisément pour être importée ailleurs.

    Volontairement SYMÉTRIQUE : un seul blocage, dans un sens ou dans
    l'autre, suffit à la rendre vraie. Ne regarder que « le destinataire
    m'a-t-il bloqué ? » laisserait celui qui bloque continuer à écrire à
    quelqu'un qui ne peut plus lui répondre — une conversation à sens unique
    imposée, exactement ce que le blocage doit empêcher.

    Une seule requête, quel que soit le sens : la fonction est appelée sur le
    chemin critique de chaque envoi de message.
    """
    blocked = db.query(Contact.id).filter(
        Contact.is_blocked.is_(True),
        or_(
            and_(Contact.owner_user_id == recipient_id, Contact.contact_user_id == sender_id),
            and_(Contact.owner_user_id == sender_id, Contact.contact_user_id == recipient_id),
        ),
    ).first()
    return blocked is not None


# ─── Épingler ─────────────────────────────────────────────────────────────────

def _pinned_count(db: Session, user_id: int) -> int:
    contacts = db.query(func.count(Contact.id)).filter(
        Contact.owner_user_id == user_id, Contact.is_pinned.is_(True)
    ).scalar() or 0
    groups = db.query(func.count(GroupMember.id)).filter(
        GroupMember.user_id == user_id, GroupMember.is_pinned.is_(True)
    ).scalar() or 0
    return contacts + groups


@router.put("/pin")
async def set_pinned(
    payload: PinRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Épingle ou désépingle. `pinned_at` est renseignée à l'épinglage et
    remise à null au retrait : c'est elle qui ordonne les épingles entre
    elles, et la garder après un retrait ferait remonter une conversation
    réépinglée à sa place d'il y a trois mois."""
    user_id = current_user["user_id"]
    row = _resolve_target(db, payload, user_id)

    # Déjà dans l'état demandé : on sort avant de compter, sinon réépingler
    # la 3ᵉ conversation déjà épinglée se verrait refusée par sa propre
    # présence dans le total.
    if bool(row.is_pinned) == payload.pinned:
        return _settings_payload(payload.kind, payload.id, row)

    if payload.pinned and _pinned_count(db, user_id) >= MAX_PINNED_CONVERSATIONS:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Vous ne pouvez épingler que {MAX_PINNED_CONVERSATIONS} conversations. "
                "Retirez-en une avant d'en épingler une autre."
            ),
        )

    row.is_pinned = payload.pinned
    row.pinned_at = datetime.utcnow() if payload.pinned else None
    db.commit()
    db.refresh(row)
    return _settings_payload(payload.kind, payload.id, row)


# ─── Archiver ─────────────────────────────────────────────────────────────────

@router.put("/archive")
async def set_archived(
    payload: ArchiveRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Archiver sort la conversation de la liste principale sans rien
    supprimer : les messages, l'épingle et la sourdine restent en place, et
    `GET /conversations?archived=true` la retrouve intacte. C'est ce qui
    distingue « archiver » de « quitter » ou « supprimer »."""
    user_id = current_user["user_id"]
    row = _resolve_target(db, payload, user_id)

    row.is_archived = payload.archived
    db.commit()
    db.refresh(row)
    return _settings_payload(payload.kind, payload.id, row)


# ─── Sourdine ─────────────────────────────────────────────────────────────────

@router.put("/mute")
async def set_muted(
    payload: MuteRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Met en sourdine pour une durée, ou réactive le son avec
    `duration_seconds: null`. La durée est convertie en DATE tout de suite
    (voir MUTE_FOREVER_SECONDS) : ainsi 8 h, 1 semaine et « toujours » ne
    sont qu'une même colonne, et personne n'a à repasser derrière pour
    éteindre le silence quand il a expiré."""
    user_id = current_user["user_id"]
    row = _resolve_target(db, payload, user_id)

    duration = payload.duration_seconds
    if duration is not None and duration not in MUTE_DURATIONS:
        raise HTTPException(
            status_code=400,
            detail="Durée invalide : 28800 (8 h), 604800 (1 semaine) ou 3155760000 (toujours)",
        )
    row.muted_until = None if duration is None else datetime.utcnow() + timedelta(seconds=duration)

    db.commit()
    db.refresh(row)
    return _settings_payload(payload.kind, payload.id, row)


# ─── Bloquer / signaler ───────────────────────────────────────────────────────

@router.put("/block")
async def set_blocked(
    payload: BlockRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Bloque ou débloque une personne. Le drapeau est posé sur MA ligne de
    contact : le blocage est mon geste, l'autre n'en est jamais informé (voir
    aussi list_conversations, qui ne fait donc disparaître la conversation que
    de MA liste)."""
    user_id = current_user["user_id"]
    if payload.contact_user_id == user_id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous bloquer vous-même")

    contact = _require_contact_by_user(db, user_id, payload.contact_user_id)
    contact.is_blocked = payload.blocked
    db.commit()
    db.refresh(contact)
    return _settings_payload("contact", contact.id, contact)


@router.get("/blocked")
async def list_blocked(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les personnes bloquées, pour l'écran « Contacts bloqués » où on les
    débloque. Elles sont volontairement absentes de `GET /conversations` : ce
    sont deux écrans différents, et une conversation bloquée qui traînerait
    dans la liste d'accueil annulerait l'intérêt du blocage."""
    user_id = current_user["user_id"]
    contacts = (
        db.query(Contact)
        .options(joinedload(Contact.contact_user).joinedload(User.avatar_media))
        .filter(Contact.owner_user_id == user_id, Contact.is_blocked.is_(True))
        .order_by(Contact.display_name)
        .all()
    )
    items = [
        {
            "contact_id": contact.id,
            "contact_user_id": contact.contact_user_id,
            "display_name": nom_affiche(contact.contact_user, contact.display_name),
            "phone": contact.phone,
            "avatar": _serialize_media(
                contact.contact_user.avatar_media if contact.contact_user else None
            ),
        }
        for contact in contacts
    ]
    return {"items": items, "total": len(items)}


@router.post("/report")
async def report_conversation(
    payload: ReportRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Signale un abus. Le signalement part dans les JOURNAUX de
    l'application, pas dans une table de modération : il n'existe aujourd'hui
    ni file de traitement ni écran d'administration pour les abus, et rendre
    un identifiant de dossier laisserait croire à un suivi que rien
    n'implémente. Le jour où la modération existera, ce `logger.warning` sera
    remplacé par une insertion — le contrat de la route ne changera pas.

    Répond 200 même pour un `contact_user_id` inconnu : renvoyer 404 ferait
    de cette route un oracle d'existence de comptes, alors qu'elle est
    ouverte à tout utilisateur connecté et ne demande aucune relation
    préalable (on signale souvent quelqu'un qu'on n'a pas dans son carnet —
    c'est même le cas le plus fréquent).
    """
    user_id = current_user["user_id"]
    if payload.contact_user_id == user_id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous signaler vous-même")

    # Le blocage, lui, exige la ligne de contact : il est vérifié AVANT de
    # journaliser, pour ne pas laisser derrière soi un signalement enregistré
    # dans une requête qui a fini en erreur.
    contact = (
        _require_contact_by_user(db, user_id, payload.contact_user_id)
        if payload.also_block
        else None
    )

    target_exists = db.query(User.id).filter(User.id == payload.contact_user_id).first() is not None
    logger.warning(
        "Pokou: signalement de l'utilisateur %s par l'utilisateur %s (cible connue: %s, "
        "blocage demandé: %s) — motif: %s",
        payload.contact_user_id,
        user_id,
        target_exists,
        payload.also_block,
        payload.reason,
    )

    if target_exists:
        # File de modération de l'espace d'administration.
        from app.models import AbuseReport

        db.add(AbuseReport(
            reporter_id=user_id,
            target_user_id=payload.contact_user_id,
            reason=(payload.reason or "")[:280] or None,
            blocked=1 if contact is not None else 0,
        ))
    if contact is not None:
        contact.is_blocked = True
    db.commit()

    return {
        "reported": True,
        "contact_user_id": payload.contact_user_id,
        "blocked": contact is not None,
        # Formulation prudente : on confirme la RÉCEPTION, on ne promet aucun
        # traitement (voir la docstring).
        "message": "Votre signalement a été transmis à notre équipe.",
    }


# ─── Liste unifiée ────────────────────────────────────────────────────────────

def _not_expired():
    """Même règle qu'à la lecture d'une conversation (messages.py) : un
    message éphémère échu ne doit pas rester en aperçu dans la liste
    d'accueil alors qu'il a disparu de l'historique."""
    return or_(DirectMessage.expires_at.is_(None), DirectMessage.expires_at > datetime.utcnow())


def _latest_direct_messages(db: Session, user_id: int, partner_ids: set) -> Dict[int, Any]:
    """Dernier message de CHAQUE conversation 1:1, en une seule requête.

    La liste d'accueil est l'écran le plus souvent ouvert de l'app : une
    requête « dernier message » par conversation la mettrait à N+1 requêtes,
    donc à plusieurs dizaines d'allers-retours pour un carnet ordinaire.
    Un `ORDER BY created_at DESC` suivi d'un dédoublonnage en Python est
    tentant, mais il rapatrierait TOUT l'historique de l'utilisateur pour
    n'en garder que quelques lignes. On numérote donc les messages par
    conversation côté base (`row_number`) et on ne remonte que le premier de
    chaque : une requête, et autant de lignes que de conversations.

    L'interlocuteur n'est pas une colonne (il est tantôt `sender_id`, tantôt
    `recipient_id`), d'où le CASE qui le calcule et qui sert de partition.
    """
    if not partner_ids:
        return {}

    partner = case(
        (DirectMessage.sender_id == user_id, DirectMessage.recipient_id),
        else_=DirectMessage.sender_id,
    ).label("partner_id")

    ranked = (
        db.query(
            partner,
            DirectMessage.id.label("message_id"),
            DirectMessage.sender_id.label("sender_id"),
            DirectMessage.message_type.label("message_type"),
            DirectMessage.content.label("content"),
            # Remonté jusqu'à l'aperçu : un message chiffré a un `content`
            # NULL, et sans ce drapeau la liste d'accueil afficherait une
            # ligne blanche sans que rien n'en dise la raison.
            DirectMessage.encryption.label("encryption"),
            DirectMessage.created_at.label("created_at"),
            func.row_number()
            .over(
                partition_by=partner,
                # `id` en second critère : deux messages de la même seconde
                # ne doivent pas donner un aperçu qui change d'un appel à
                # l'autre.
                order_by=(DirectMessage.created_at.desc(), DirectMessage.id.desc()),
            )
            .label("row_rank"),
        )
        .filter(
            or_(
                and_(
                    DirectMessage.sender_id == user_id,
                    DirectMessage.recipient_id.in_(partner_ids),
                ),
                and_(
                    DirectMessage.recipient_id == user_id,
                    DirectMessage.sender_id.in_(partner_ids),
                ),
            ),
            _not_expired(),
        )
        .subquery()
    )

    rows = db.query(ranked).filter(ranked.c.row_rank == 1).all()
    return {row.partner_id: row for row in rows}


def _latest_group_messages(db: Session, group_ids: set) -> Dict[int, Any]:
    """Pendant de _latest_direct_messages pour les groupes — même raison,
    partition plus simple puisque `group_id` est une vraie colonne."""
    if not group_ids:
        return {}

    ranked = (
        db.query(
            GroupMessage.group_id.label("group_id"),
            GroupMessage.id.label("message_id"),
            GroupMessage.sender_id.label("sender_id"),
            GroupMessage.message_type.label("message_type"),
            GroupMessage.content.label("content"),
            GroupMessage.created_at.label("created_at"),
            func.row_number()
            .over(
                partition_by=GroupMessage.group_id,
                order_by=(GroupMessage.created_at.desc(), GroupMessage.id.desc()),
            )
            .label("row_rank"),
        )
        .filter(
            GroupMessage.group_id.in_(group_ids),
            or_(
                GroupMessage.expires_at.is_(None),
                GroupMessage.expires_at > datetime.utcnow(),
            ),
        )
        .subquery()
    )

    rows = db.query(ranked).filter(ranked.c.row_rank == 1).all()
    return {row.group_id: row for row in rows}


def _unread_direct_counts(db: Session, user_id: int, partner_ids: set) -> Dict[int, int]:
    """Non-lus par interlocuteur, en une requête agrégée côté base — même
    motif que pour les derniers messages."""
    if not partner_ids:
        return {}
    rows = (
        db.query(DirectMessage.sender_id, func.count(DirectMessage.id))
        .filter(
            DirectMessage.recipient_id == user_id,
            DirectMessage.sender_id.in_(partner_ids),
            DirectMessage.status != MessageStatus.READ,
            _not_expired(),
        )
        .group_by(DirectMessage.sender_id)
        .all()
    )
    return {sender_id: count for sender_id, count in rows}


def _sender_names(db: Session, sender_ids: set) -> Dict[int, str]:
    """Une requête pour tous les auteurs des aperçus. Sans elle, afficher
    « Awa : d'accord » dans un groupe coûterait une requête par ligne de la
    liste."""
    if not sender_ids:
        return {}
    rows = db.query(User.id, User.full_name, User.phone).filter(User.id.in_(sender_ids)).all()
    return {row[0]: (row[1] or row[2] or f"#{row[0]}") for row in rows}


def _last_message_payload(row: Any, user_id: int, sender_name: Optional[str]) -> dict:
    # `encrypted` dit au client pourquoi `content` est vide. Sans ce drapeau,
    # l'aperçu d'une conversation chiffrée serait une ligne BLANCHE dans la
    # liste d'accueil — et rien n'indiquerait s'il s'agit d'un message vide,
    # d'une panne, ou d'un chiffrement qui fonctionne. Le client va alors
    # chercher le clair dans son propre cache, où il l'a déjà déchiffré.
    encrypted = bool(getattr(row, "encryption", None))
    return {
        "id": row.message_id,
        "message_type": _message_type_value(row.message_type),
        "encrypted": encrypted,
        "content": None if encrypted else _preview(row.content),
        "created_at": row.created_at.isoformat(),
        "sender_id": row.sender_id,
        "sender_name": sender_name,
        # Le client dessine « ✓✓ » et aligne la bulle à droite d'après ce
        # drapeau, plutôt que de comparer lui-même à l'identité connectée.
        "is_mine": row.sender_id == user_id,
    }


@router.get("")
async def list_conversations(
    archived: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """L'écran d'accueil : contacts avec qui j'ai au moins un message, groupes
    dont je suis membre, ET personnes qui m'ont écrit sans que je les aie moi-
    même ajoutées — façon WhatsApp, un numéro qui vous écrit apparaît même
    sans figurer dans votre répertoire (`is_unknown_contact: true`, `id: null`
    puisqu'il n'y a pas de ligne Contact à épingler/archiver/muter tant que la
    personne n'a pas été ajoutée).

    Un groupe apparaît dès l'appartenance, même sans un seul message — on y a
    été ajouté, il doit être visible pour qu'on puisse y écrire le premier.
    Un contact CONNU, lui, n'apparaît qu'à partir du premier message : sinon
    la liste des conversations serait le carnet d'adresses entier (des
    centaines de lignes après une synchronisation du téléphone).

    Les personnes que J'AI bloquées sont exclues. Celles qui m'ont bloqué
    restent visibles : faire disparaître la conversation de la liste de la
    personne bloquée lui apprendrait qu'elle l'est, ce que le blocage ne
    révèle jamais (le message est refusé à l'envoi, sans explication — voir
    is_blocked_between).
    """
    user_id = current_user["user_id"]

    contacts = (
        db.query(Contact)
        .options(joinedload(Contact.contact_user).joinedload(User.avatar_media))
        .filter(
            Contact.owner_user_id == user_id,
            # Un numéro pas encore inscrit sur Pokou ne peut avoir aucun
            # message : rien à afficher comme conversation.
            Contact.contact_user_id.isnot(None),
            Contact.is_blocked.is_(False),
            Contact.is_archived == archived,
        )
        .all()
    )
    memberships = (
        db.query(GroupMember)
        .options(
            joinedload(GroupMember.group).joinedload(Group.avatar_media),
            # La communauté et SON avatar sont chargés ici : sans ça,
            # composer les lignes de communauté déclencherait deux
            # requêtes par groupe, sur le chemin le plus chaud de l'app.
            joinedload(GroupMember.group)
            .joinedload(Group.community)
            .joinedload(Community.avatar_media),
        )
        .filter(GroupMember.user_id == user_id, GroupMember.is_archived == archived)
        .all()
    )

    partner_ids = {contact.contact_user_id for contact in contacts}
    group_ids = {membership.group_id for membership in memberships}

    # Quelqu'un qui n'est PAS dans mon carnet a pu m'écrire quand même —
    # `_require_contact` (messages.py) ne vérifie que le carnet de
    # l'EXPÉDITEUR, pas le mien. Sans ce bloc, ce fil resterait invisible
    # dans l'app : aucune Contact row de mon côté pour le porter, donc
    # aucune ligne dans la boucle ci-dessous. Exclus des archives : un
    # inconnu n'a pas de case à cocher « archiver ».
    stranger_ids = set()
    if not archived:
        # (sender_id, recipient_id) de chaque paire où je suis partie : on en
        # déduit l'AUTRE bout, on retire moi-même (un message à soi-même
        # n'existe pas mais autant s'en prémunir) et ceux déjà couverts par un
        # Contact ci-dessus.
        raw_pairs = (
            db.query(DirectMessage.sender_id, DirectMessage.recipient_id)
            .filter(
                or_(DirectMessage.sender_id == user_id, DirectMessage.recipient_id == user_id),
                _not_expired(),
            )
            .distinct()
            .all()
        )
        stranger_ids = {
            (sender if sender != user_id else recipient)
            for sender, recipient in raw_pairs
        }
        stranger_ids.discard(user_id)
        stranger_ids -= partner_ids
        # Bloqués par moi : mêmes règles que pour un contact.
        if stranger_ids:
            blocked_strangers = {
                cid
                for (cid,) in db.query(Contact.contact_user_id).filter(
                    Contact.owner_user_id == user_id,
                    Contact.contact_user_id.in_(stranger_ids),
                    Contact.is_blocked.is_(True),
                ).all()
            }
            stranger_ids -= blocked_strangers

    strangers = (
        db.query(User).options(joinedload(User.avatar_media)).filter(User.id.in_(stranger_ids)).all()
        if stranger_ids
        else []
    )

    latest_direct = _latest_direct_messages(db, user_id, partner_ids | stranger_ids)
    latest_group = _latest_group_messages(db, group_ids)
    unread_direct = _unread_direct_counts(db, user_id, partner_ids | stranger_ids)
    names = _sender_names(
        db,
        {row.sender_id for row in latest_direct.values()}
        | {row.sender_id for row in latest_group.values()},
    )

    # (payload, date d'activité, date d'épinglage) — les deux dates servent
    # au tri puis sont jetées, elles n'ont pas à sortir dans la réponse.
    rows: List[Tuple[dict, datetime, Optional[datetime]]] = []

    for contact in contacts:
        last = latest_direct.get(contact.contact_user_id)
        if last is None:
            continue
        # Dans un 1:1, le nom du carnet d'adresses l'emporte sur le nom de
        # profil : c'est celui que le propriétaire a choisi et reconnaît.
        sender_name = (
            names.get(last.sender_id)
            if last.sender_id == user_id
            else nom_affiche(contact.contact_user, contact.display_name)
        )
        payload = {
            "kind": "contact",
            # L'identifiant du Contact, et non du User : c'est lui qu'on
            # renvoie à /pin, /archive et /mute.
            "id": contact.id,
            "contact_user_id": contact.contact_user_id,
            # Toujours présent (même valant faux) : un client ne doit pas
            # deviner que la clé est absente pour un contact connu, elle
            # existe pour CHAQUE ligne, connue ou non.
            "is_unknown_contact": False,
            # Le carnet l'emporte, SAUF pour un compte certifié qui a un nom
            # (voir utils/identity.py::nom_affiche).
            "name": nom_affiche(contact.contact_user, contact.display_name),
            "avatar": _serialize_media(
                contact.contact_user.avatar_media if contact.contact_user else None
            ),
            "is_verified": est_certifie(contact.contact_user) if contact.contact_user else False,
            "is_bot": bool(contact.contact_user.is_bot) if contact.contact_user else False,
            "is_pinned": bool(contact.is_pinned),
            "is_muted": _is_muted(contact.muted_until),
            "muted_until": contact.muted_until.isoformat() if contact.muted_until else None,
            "is_archived": bool(contact.is_archived),
            "last_message": _last_message_payload(last, user_id, sender_name),
            "unread_count": unread_direct.get(contact.contact_user_id, 0),
        }
        rows.append((payload, last.created_at, contact.pinned_at))

    for stranger in strangers:
        last = latest_direct.get(stranger.id)
        if last is None:
            continue
        # Pas de petname possible (pas de Contact) : nom de profil, puis le
        # numéro — jamais une ligne vide dans la liste.
        display_name = stranger.full_name or stranger.phone or "Utilisateur Pokou"
        payload = {
            "kind": "contact",
            "is_verified": est_certifie(stranger),
            # Un bot n'est pas « un inconnu qui vous écrit » : l'application
            # ne propose ni de l'ajouter ni de le signaler comme tel.
            "is_bot": bool(stranger.is_bot),
            # Pas de ligne Contact : rien à épingler/archiver/muter tant que
            # cette personne n'a pas été ajoutée. Le client doit distinguer
            # cette conversation (proposer « Ajouter aux contacts » plutôt
            # que le menu habituel) via ce marqueur.
            "id": None,
            "contact_user_id": stranger.id,
            "is_unknown_contact": True,
            "name": display_name,
            "avatar": _serialize_media(stranger.avatar_media),
            "is_pinned": False,
            "is_muted": False,
            "muted_until": None,
            "is_archived": False,
            "last_message": _last_message_payload(
                last, user_id, names.get(last.sender_id) if last.sender_id == user_id else display_name
            ),
            "unread_count": unread_direct.get(stranger.id, 0),
        }
        rows.append((payload, last.created_at, None))

    # ── Les COMMUNAUTÉS, et leurs groupes rangés dedans ───────────────────
    #
    # Une communauté est une ligne de la liste d'accueil, comme un groupe ou
    # une discussion. Ses groupes, eux, n'y apparaissent PAS séparément : les
    # afficher aux deux endroits ferait figurer la même conversation deux
    # fois, et viderait la communauté de son sens — on n'ouvrirait jamais
    # celle dont on voit déjà tous les groupes au-dessus.
    #
    # L'aperçu d'une communauté est le message le plus récent de TOUS ses
    # groupes : c'est la seule information qui dise s'il s'y passe quelque
    # chose sans avoir à l'ouvrir.
    community_rows: dict[int, dict] = {}
    community_activity: dict[int, datetime] = {}
    grouped_into_community: set[int] = set()

    for membership in memberships:
        group = membership.group
        if group is None or group.community is None:
            continue
        community = group.community
        grouped_into_community.add(membership.group_id)
        last = latest_group.get(membership.group_id)
        activity = last.created_at if last else membership.joined_at

        existing = community_rows.get(community.id)
        if existing is None:
            community_rows[community.id] = {
                "kind": "community",
                "id": community.id,
                "name": community.name,
                "community_name": None,
                "avatar": _serialize_media(community.avatar_media),
                # Épingler/archiver/couper une COMMUNAUTÉ n'existe pas encore :
                # ces réglages vivent sur l'appartenance à un groupe, pas sur
                # celle à une communauté. Renvoyés à faux plutôt qu'omis, pour
                # que le client garde une seule forme de ligne.
                "is_pinned": False,
                "is_muted": False,
                "muted_until": None,
                "is_archived": False,
                "last_message": None,
                "unread_count": 0,
                "group_count": 0,
            }
        row = community_rows[community.id]
        row["group_count"] += 1
        if last is not None and (
            community_activity.get(community.id) is None
            or activity > community_activity[community.id]
        ):
            row["last_message"] = _last_message_payload(
                last, user_id, names.get(last.sender_id)
            )
        if community_activity.get(community.id) is None or activity > community_activity[community.id]:
            community_activity[community.id] = activity

    for community_id, payload in community_rows.items():
        rows.append((payload, community_activity[community_id], None))

    for membership in memberships:
        group = membership.group
        if group is None:
            continue
        # Déjà compté dans sa communauté.
        if membership.group_id in grouped_into_community:
            continue
        last = latest_group.get(membership.group_id)
        payload = {
            "kind": "group",
            "id": group.id,
            "name": group.name,
            "community_name": group.community.name if group.community else None,
            "avatar": _serialize_media(group.avatar_media),
            "is_pinned": bool(membership.is_pinned),
            "is_muted": _is_muted(membership.muted_until),
            "muted_until": membership.muted_until.isoformat() if membership.muted_until else None,
            "is_archived": bool(membership.is_archived),
            "last_message": (
                _last_message_payload(last, user_id, names.get(last.sender_id))
                if last
                else None
            ),
            # Toujours 0 : GroupMessage n'a délibérément aucun accusé de
            # lecture par membre (voir sa docstring dans models/orm.py), il
            # n'existe donc aucune date « lu jusqu'ici » à laquelle comparer.
            # Le champ est quand même renvoyé pour que le client n'ait pas à
            # changer de forme le jour où les accusés de groupe arriveront.
            "unread_count": 0,
        }
        # Un groupe sans message se range à la date où j'y suis entré : c'est
        # l'événement qui l'a fait apparaître dans ma liste.
        rows.append(
            (payload, last.created_at if last else membership.joined_at, membership.pinned_at)
        )

    # Tri en deux temps parce que les épinglées ne suivent PAS le même
    # critère que les autres : entre elles, c'est l'ordre d'épinglage qui
    # compte (le plus récemment épinglé en tête), pas l'activité.
    rows.sort(key=lambda row: row[1], reverse=True)
    pinned = [row for row in rows if row[0]["is_pinned"]]
    pinned.sort(key=lambda row: row[2] or row[1], reverse=True)
    ordered = pinned + [row for row in rows if not row[0]["is_pinned"]]

    return {"items": [row[0] for row in ordered], "total": len(ordered)}
