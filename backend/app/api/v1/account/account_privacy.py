"""Pokou — confidentialité du compte : accusés de lecture, vérification en
deux étapes, suppression du compte.

DEUX VERROUS QUI SE RESSEMBLENT ET NE PROTÈGENT PAS LA MÊME CHOSE. Le
« verrou d'application » (déjà en place côté Flutter) est un code LOCAL :
il ne quitte jamais le téléphone, le serveur n'en sait rien, et il ne
protège que l'écran de CET appareil — quelqu'un qui prend le compte depuis
un autre téléphone ne le rencontre jamais. La « vérification en deux
étapes » implémentée ici est un code du COMPTE : stocké haché en base,
exigé EN PLUS de l'OTP lors d'une connexion sur un nouvel appareil, il fait
qu'intercepter un SMS ne suffit plus à prendre le compte. Confondre les deux
— croire que le verrou d'app protège le compte — laisserait précisément le
trou que cette route existe pour fermer.

La réciprocité des accusés de lecture est appliquée ici par
`read_receipts_visible_between`, destinée à la sérialisation des messages :
le réglage n'aurait aucun sens comme simple filtre d'affichage local.
"""
import logging
from datetime import datetime, timedelta
from typing import Dict, Iterable, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import BabaMessage, CallLog, Community, CommunityMember, Contact, DeviceToken, DirectMessage, Group, GroupMember, GroupMessage, GroupMessageMention, GroupMessageReaction, MediaAsset, MessageReaction, PollVote, Status, StatusPrivacy, StatusPrivacyEntry, StatusView, Token, User
from app.services.media import media_storage
from app.services.privacy import privacy_service
from app.core.security import get_current_user, hash_password, verify_password

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/account-privacy", tags=["Pokou account_privacy"])

TWO_STEP_PIN_LENGTH = 6

# Au-delà de 5 échecs consécutifs, le code est refusé pendant 15 minutes —
# mêmes valeurs que le verrouillage de /auth/login, pour que les deux portes
# d'entrée du compte résistent pareil.
TWO_STEP_MAX_ATTEMPTS = 5
TWO_STEP_LOCKOUT = timedelta(minutes=15)

# ATTENTION — compteur d'échecs EN MÉMOIRE du processus : user_id -> (échecs
# consécutifs, date du dernier échec). Il est PERDU au redémarrage et n'est
# PAS partagé entre plusieurs workers/instances : un attaquant patient (ou
# qui tombe sur un autre worker) retrouve donc ses 5 tentatives. Ce n'est
# volontairement pas présenté comme un vrai verrouillage : il faudrait pour
# cela des colonnes persistantes sur `users`. En attendant, ceci coupe le
# martèlement d'un script naïf, rien de plus.
_two_step_failures: Dict[int, Tuple[int, datetime]] = {}


class ReadReceiptsUpdate(BaseModel):
    enabled: bool


class TwoStepEnable(BaseModel):
    pin: str = Field(..., max_length=64)


class TwoStepChange(BaseModel):
    """`current_pin` est optionnel dans le schéma pour pouvoir répondre 400
    avec un message explicite quand il manque, plutôt que le 422 illisible
    d'un champ obligatoire absent — ce que le client affiche tel quel."""
    current_pin: Optional[str] = Field(None, max_length=64)
    new_pin: str = Field(..., max_length=64)


class TwoStepDisable(BaseModel):
    current_pin: Optional[str] = Field(None, max_length=64)


class TwoStepVerify(BaseModel):
    pin: str = Field(..., max_length=64)


class AccountDelete(BaseModel):
    """Retaper son propre numéro, comme GitHub fait retaper le nom d'un dépôt
    avant de le supprimer : la suppression est irréversible et le geste ne
    doit pas pouvoir être un glissement de doigt."""
    confirm_phone: str = Field(..., max_length=32)


def _load_me(db: Session, current_user: dict) -> User:
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user


# ─── Accusés de lecture ───────────────────────────────────────────────────────

def read_receipts_visible_between(db: Session, viewer_id: int, other_id: int) -> bool:
    """Les accusés de LECTURE (deux coches) sont-ils échangeables entre ces
    deux personnes ? Destinée à la sérialisation des messages (`read_at` /
    `status` dans routes/messages.py et routes/groups.py), qui doit masquer
    l'information au lieu de la servir à tout le monde.

    RÉCIPROCITÉ, façon WhatsApp : désactiver ses accusés me prive AUSSI de
    ceux des autres, donc les deux réglages doivent être vrais. Sans cette
    règle appliquée à la LECTURE, le réglage serait un cadeau à sens unique
    — je saurais quand on me lit sans jamais dire quand je lis — et la
    fonctionnalité n'aurait plus de raison d'exister.

    Ce que ce réglage ne touche PAS : les accusés de LIVRAISON (une coche,
    `delivered_at`). Savoir que le message est arrivé sur le téléphone n'est
    pas savoir qu'il a été lu ; WhatsApp continue de montrer la première
    coche, et la couper ici ferait croire à un message perdu.
    """
    # Mes propres messages : rien à cacher à moi-même.
    if viewer_id == other_id:
        return True

    flags = dict(
        db.query(User.id, User.read_receipts_enabled)
        .filter(User.id.in_([viewer_id, other_id]))
        .all()
    )
    # Compte introuvable (supprimé entre-temps) : on se taît plutôt que de
    # supposer un réglage.
    if viewer_id not in flags or other_id not in flags:
        return False
    # `None` vaut « activé » : c'est le défaut documenté de la colonne, et
    # une ligne antérieure à son ajout ne doit pas perdre ses accusés.
    return flags[viewer_id] is not False and flags[other_id] is not False


# ── L'écran « Confidentialité », en un seul aller-retour ──────────────────
#
# Les réglages existaient, éparpillés : `/read-receipts` ici,
# `/presence/settings` là, `/status/privacy` ailleurs, et rien du tout pour
# la photo de profil ou les invitations de groupe. Une page de réglages qui
# fait quatre appels pour s'afficher et quatre autres pour enregistrer finit
# par montrer un état incohérent dès qu'un des quatre échoue.
#
# Les anciennes routes RESTENT : un client déjà déployé continue de
# fonctionner. Elles écrivent les mêmes colonnes.


class ReglagesConfidentialite(BaseModel):
    """Tout est optionnel, et c'est la règle centrale de cette route.

    L'écran change une ligne à la fois. Un envoi partiel ne doit pas remettre
    les cinq autres à leur défaut — c'est le genre d'erreur qui rouvre en
    silence ce que quelqu'un avait fermé, et que personne ne remarque avant
    des semaines.
    """

    last_seen: Optional[str] = None
    online: Optional[str] = None
    profile_photo: Optional[str] = None
    profile_info: Optional[str] = None
    group_membership: Optional[str] = None
    group_invites: Optional[str] = None
    read_receipts: Optional[bool] = None
    presence_reciprocal: Optional[bool] = None


@router.get("/privacy")
async def get_privacy_settings(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce que l'écran « Confidentialité » affiche."""
    return privacy_service.reglages(_load_me(db, current_user))


@router.put("/privacy")
async def update_privacy_settings(
    payload: ReglagesConfidentialite,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Enregistre les règles envoyées, et LAISSE les autres.

    Sémantique de PATCH bien que la méthode soit PUT : voir
    `ReglagesConfidentialite`.
    """
    try:
        return privacy_service.appliquer(
            db, _load_me(db, current_user), payload.model_dump(exclude_unset=True)
        )
    except ValueError:
        # Une audience inconnue est un défaut de client, pas une raison de
        # perdre les réglages déjà en place : rien n'a été écrit, le service
        # valide avant d'affecter.
        raise HTTPException(
            status_code=422,
            detail="Valeur de confidentialité inconnue — attendu EVERYONE, CONTACTS ou NOBODY",
        )


@router.get("/read-receipts")
async def get_read_receipts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = _load_me(db, current_user)
    return {"enabled": user.read_receipts_enabled is not False}


@router.put("/read-receipts")
async def update_read_receipts(
    payload: ReadReceiptsUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le client doit annoncer la contrepartie AVANT l'appel : couper ses
    accusés coupe aussi ceux qu'on reçoit (voir
    `read_receipts_visible_between`)."""
    user = _load_me(db, current_user)
    user.read_receipts_enabled = payload.enabled
    db.commit()
    return {
        "enabled": user.read_receipts_enabled,
        # Rappelé dans la réponse pour que l'écran puisse l'afficher sans
        # dupliquer la règle côté client.
        "reciprocal": True,
        "delivery_receipts_unaffected": True,
    }


# ─── Vérification en deux étapes ──────────────────────────────────────────────

def two_step_required(db: Session, user_id: int) -> bool:
    """Ce compte exige-t-il le code de vérification en plus de l'OTP ?
    Destinée au flux de connexion (routes/auth.py, /auth/phone/verify-otp) :
    c'est lui qui doit s'arrêter pour demander le code, sinon la protection
    ne s'appliquerait jamais au moment où elle compte."""
    pin_hash = (
        db.query(User.two_step_pin_hash).filter(User.id == user_id).scalar()
    )
    return bool(pin_hash)


def _validate_pin(pin: str) -> str:
    """Exactement 6 chiffres. Une longueur libre laisserait passer un code à
    2 chiffres, deviné avant même que le compteur d'échecs ne serve."""
    candidate = (pin or "").strip()
    if len(candidate) != TWO_STEP_PIN_LENGTH or not candidate.isdigit():
        raise HTTPException(
            status_code=400,
            detail=f"Le code de vérification doit contenir exactement {TWO_STEP_PIN_LENGTH} chiffres",
        )
    return candidate


def _reject_if_throttled(user_id: int) -> None:
    entry = _two_step_failures.get(user_id)
    if not entry:
        return
    failures, last_failure_at = entry
    if failures < TWO_STEP_MAX_ATTEMPTS:
        return
    elapsed = datetime.utcnow() - last_failure_at
    if elapsed >= TWO_STEP_LOCKOUT:
        # La pénalité est purgée : on repart de zéro, sinon un compte resterait
        # bloqué pour toujours après une mauvaise journée.
        _two_step_failures.pop(user_id, None)
        return
    minutes = max(1, int((TWO_STEP_LOCKOUT - elapsed).total_seconds() // 60) + 1)
    raise HTTPException(
        status_code=429,
        detail=f"Trop de tentatives — réessayez dans {minutes} minutes.",
    )


def _check_pin(user: User, pin: str) -> None:
    """Vérifie le code du compte et tient le compteur d'échecs. TOUTES les
    routes qui exigent le code passent par ici : ne limiter que
    /two-step/verify laisserait PUT et DELETE servir d'oracle de devinage à
    volume illimité, ce qui reviendrait à ne rien limiter."""
    if not user.two_step_pin_hash:
        raise HTTPException(
            status_code=409, detail="La vérification en deux étapes n'est pas activée"
        )

    # Vérifié AVANT le bcrypt : sinon une salve de tentatives coûterait un
    # hachage à chaque coup, ce qui suffirait à saturer le serveur.
    _reject_if_throttled(user.id)

    if not verify_password(pin, user.two_step_pin_hash):
        failures, _ = _two_step_failures.get(user.id, (0, None))
        _two_step_failures[user.id] = (failures + 1, datetime.utcnow())
        # Jamais le code, ni son haché : un log est lu par bien plus de monde
        # que la base.
        logger.info("Code de vérification en deux étapes incorrect (user %s)", user.id)
        raise HTTPException(status_code=403, detail="Code de vérification incorrect")

    _two_step_failures.pop(user.id, None)


@router.get("/two-step")
async def get_two_step(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Seul l'état, jamais le code ni son haché : un haché sorti de la base
    se casse hors ligne, sans compteur d'échecs pour gêner."""
    user = _load_me(db, current_user)
    return {"enabled": bool(user.two_step_pin_hash)}


@router.post("/two-step")
async def enable_two_step(
    payload: TwoStepEnable,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = _load_me(db, current_user)
    if user.two_step_pin_hash:
        raise HTTPException(
            status_code=409,
            detail="La vérification en deux étapes est déjà activée — utilisez la modification du code",
        )

    pin = _validate_pin(payload.pin)
    user.two_step_pin_hash = hash_password(pin)
    db.commit()
    return {"enabled": True}


@router.put("/two-step")
async def change_two_step(
    payload: TwoStepChange,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le code actuel est exigé même en étant déjà authentifié : un téléphone
    déverrouillé qu'on laisse traîner suffirait sinon à remplacer le code du
    compte, c'est-à-dire à s'en emparer définitivement."""
    user = _load_me(db, current_user)
    if not user.two_step_pin_hash:
        raise HTTPException(
            status_code=409, detail="La vérification en deux étapes n'est pas activée"
        )
    if not (payload.current_pin or "").strip():
        raise HTTPException(status_code=400, detail="Le code actuel est requis")

    new_pin = _validate_pin(payload.new_pin)
    _check_pin(user, payload.current_pin)

    user.two_step_pin_hash = hash_password(new_pin)
    db.commit()
    return {"enabled": True}


@router.delete("/two-step")
async def disable_two_step(
    payload: TwoStepDisable,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Même exigence que pour le changement : désactiver, c'est retirer la
    protection, donc l'opération la plus intéressante pour qui n'est pas le
    propriétaire du compte."""
    user = _load_me(db, current_user)
    if not user.two_step_pin_hash:
        raise HTTPException(
            status_code=409, detail="La vérification en deux étapes n'est pas activée"
        )
    if not (payload.current_pin or "").strip():
        raise HTTPException(status_code=400, detail="Le code actuel est requis")

    _check_pin(user, payload.current_pin)

    user.two_step_pin_hash = None
    db.commit()
    return {"enabled": False}


@router.post("/two-step/verify")
async def verify_two_step(
    payload: TwoStepVerify,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Point d'entrée que le flux de connexion appellera après l'OTP, quand
    `two_step_required` répond vrai."""
    user = _load_me(db, current_user)
    _check_pin(user, payload.pin)
    return {"verified": True}


# ─── Suppression du compte ────────────────────────────────────────────────────

def _delete_media_if_orphan(db: Session, asset_ids: Iterable[int]) -> int:
    """Ne supprime une pièce jointe que si plus RIEN ne la référence. Une
    même ligne `media_assets` peut servir d'avatar personnel et de photo de
    groupe : l'effacer aveuglément remplacerait une fuite de vie privée par
    une image cassée chez les autres, et violerait une clé étrangère en
    Postgres (où elles sont réellement vérifiées, contrairement au SQLite
    des tests)."""
    removed = 0
    for asset_id in {aid for aid in asset_ids if aid}:
        still_used = (
            db.query(User.id).filter(User.avatar_media_id == asset_id).first()
            or db.query(Group.id).filter(Group.avatar_media_id == asset_id).first()
            or db.query(Community.id).filter(Community.avatar_media_id == asset_id).first()
            or db.query(DirectMessage.id).filter(DirectMessage.media_asset_id == asset_id).first()
            or db.query(GroupMessage.id).filter(GroupMessage.media_asset_id == asset_id).first()
            or db.query(Status.id).filter(Status.media_asset_id == asset_id).first()
        )
        if still_used:
            continue
        asset = db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
        if not asset:
            continue
        try:
            media_storage.delete_content(asset)
        except Exception:
            # Best-effort, comme la purge des statuts : un objet orphelin
            # coûte de l'espace, échouer ici ne doit pas laisser une
            # suppression de compte à moitié faite.
            logger.warning("Contenu média %s non supprimé", asset_id, exc_info=True)
        db.delete(asset)
        removed += 1
    return removed


@router.delete("/account")
async def delete_my_account(
    payload: AccountDelete,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Supprime le compte. Le partage de la décision, qui est le vrai sujet
    de cette route :

    EFFACÉ — tout ce qui n'appartient qu'à moi : mon carnet d'adresses
    (`Contact` dont je suis propriétaire), mes statuts et les vues qu'ils ont
    reçues, mes propres vues des statuts d'autrui, mes réglages d'audience de
    statuts, mes appartenances aux groupes et communautés (je les quitte),
    mes votes de sondage, mes réactions, mes jetons d'appareil (`DeviceToken`,
    sinon les notifications continueraient d'arriver sur un téléphone
    revendu) et mes sessions (`Token`).

    ANONYMISÉ, PAS SUPPRIMÉ — la LIGNE `users` elle-même. `direct_messages`,
    `group_messages` et `media_assets` la référencent par des clés étrangères
    NON NULLES : effacer la ligne effacerait des messages reçus par d'autres,
    ou casserait la base. On vide donc ce qui identifie — numéro, e-mail,
    nom, bio, photo, empreinte de mot de passe, code en deux étapes — et on
    désactive le compte (`is_active`), ce qui referme les deux portes
    d'entrée : plus de mot de passe, et l'OTP est refusé sur un compte
    inactif. Le numéro libéré permet de se réinscrire, sur un compte NEUF.

    CONSERVÉ — ce qui ne m'appartient plus. Les messages déjà reçus sont dans
    la conversation de l'autre personne : ici une seule ligne sert les deux
    côtés, les supprimer supprimerait donc SES messages autant que les miens.
    Même raisonnement pour le journal d'appels (`CallLog`/`CallParticipant`),
    qui est l'historique partagé de deux personnes, et pour les mentions
    reçues par d'autres. Les écritures comptables (paiements, factures
    Business) restent rattachées à la ligne anonymisée : cette route ferme
    un compte, elle n'est pas un effacement comptable.

    Le carnet d'adresses des autres n'est pas touché — c'est le leur — mais
    le lien `Contact.contact_user_id` qui pointait vers moi est coupé : sans
    ça leur application croirait pouvoir encore m'écrire, et enverrait des
    messages dans un compte mort.
    """
    user = _load_me(db, current_user)

    # Comparaison tolérante aux espaces/tirets de saisie, mais on ne
    # « devine » aucun indicatif : c'est une confirmation, pas une
    # normalisation de numéro.
    typed = "".join(ch for ch in (payload.confirm_phone or "") if ch.isdigit())
    mine = "".join(ch for ch in (user.phone or "") if ch.isdigit())
    if not mine or typed != mine:
        raise HTTPException(
            status_code=400,
            detail="Le numéro saisi ne correspond pas à celui du compte — la suppression est annulée",
        )

    # Le fil avec Baba n'appartient qu'à moi.
    db.query(BabaMessage).filter(BabaMessage.user_id == user.id).delete(synchronize_session=False)

    statuses = db.query(Status).filter(Status.user_id == user.id).all()
    status_ids = [status_row.id for status_row in statuses]
    media_candidates = [status_row.media_asset_id for status_row in statuses]
    media_candidates.append(user.avatar_media_id)

    views_received = 0
    if status_ids:
        views_received = (
            db.query(StatusView)
            .filter(StatusView.status_id.in_(status_ids))
            .delete(synchronize_session=False)
        )
    views_made = (
        db.query(StatusView)
        .filter(StatusView.viewer_id == user.id)
        .delete(synchronize_session=False)
    )
    statuses_removed = (
        db.query(Status).filter(Status.user_id == user.id).delete(synchronize_session=False)
    )

    db.query(StatusPrivacyEntry).filter(
        or_(
            StatusPrivacyEntry.user_id == user.id,
            StatusPrivacyEntry.target_user_id == user.id,
        )
    ).delete(synchronize_session=False)
    db.query(StatusPrivacy).filter(StatusPrivacy.user_id == user.id).delete(
        synchronize_session=False
    )

    contacts_removed = (
        db.query(Contact)
        .filter(Contact.owner_user_id == user.id)
        .delete(synchronize_session=False)
    )
    contacts_unlinked = (
        db.query(Contact)
        .filter(Contact.contact_user_id == user.id)
        .update({Contact.contact_user_id: None}, synchronize_session=False)
    )

    groups_left = (
        db.query(GroupMember)
        .filter(GroupMember.user_id == user.id)
        .delete(synchronize_session=False)
    )
    communities_left = (
        db.query(CommunityMember)
        .filter(CommunityMember.user_id == user.id)
        .delete(synchronize_session=False)
    )

    reactions_removed = (
        db.query(MessageReaction)
        .filter(MessageReaction.user_id == user.id)
        .delete(synchronize_session=False)
    ) + (
        db.query(GroupMessageReaction)
        .filter(GroupMessageReaction.user_id == user.id)
        .delete(synchronize_session=False)
    )
    votes_removed = (
        db.query(PollVote).filter(PollVote.user_id == user.id).delete(synchronize_session=False)
    )
    # Les mentions QUI ME DÉSIGNENT dans les messages d'autrui : le texte du
    # message reste le leur, mais l'index qui pointe sur mon compte n'a plus
    # personne à notifier.
    mentions_removed = (
        db.query(GroupMessageMention)
        .filter(GroupMessageMention.user_id == user.id)
        .delete(synchronize_session=False)
    )

    device_tokens_removed = (
        db.query(DeviceToken)
        .filter(DeviceToken.user_id == user.id)
        .delete(synchronize_session=False)
    )
    sessions_removed = (
        db.query(Token).filter(Token.user_id == user.id).delete(synchronize_session=False)
    )

    messages_kept = (
        db.query(DirectMessage)
        .filter(or_(DirectMessage.sender_id == user.id, DirectMessage.recipient_id == user.id))
        .count()
    )
    group_messages_kept = (
        db.query(GroupMessage).filter(GroupMessage.sender_id == user.id).count()
    )
    calls_kept = db.query(CallLog).filter(CallLog.caller_id == user.id).count()

    user.phone = None
    user.email = None
    user.full_name = None
    user.about = None
    user.avatar_media_id = None
    user.two_step_pin_hash = None
    user.last_seen_at = None
    user.is_active = False
    # Le détachement de l'avatar doit être visible en base avant le test
    # d'orphelin, sinon la pièce jointe se croira encore utilisée.
    db.flush()

    media_removed = _delete_media_if_orphan(db, media_candidates)

    db.commit()

    _two_step_failures.pop(user.id, None)
    logger.info("Compte Pokou supprimé et anonymisé (user %s)", user.id)

    return {
        "deleted": True,
        "anonymized_user_id": user.id,
        "removed": {
            "contacts": contacts_removed,
            "contacts_unlinked_from_me": contacts_unlinked,
            "group_memberships": groups_left,
            "community_memberships": communities_left,
            "statuses": statuses_removed,
            "status_views_received": views_received,
            "status_views_made": views_made,
            "reactions": reactions_removed,
            "poll_votes": votes_removed,
            "mentions": mentions_removed,
            "device_tokens": device_tokens_removed,
            "sessions": sessions_removed,
            "media_assets": media_removed,
        },
        # Ce qui survit, dit explicitement : une suppression de compte qui
        # laisserait croire que les messages envoyés disparaissent chez les
        # destinataires serait une promesse fausse.
        "kept": {
            "direct_messages": messages_kept,
            "group_messages": group_messages_kept,
            "call_logs": calls_kept,
            "reason": "Les messages et appels déjà reçus appartiennent aussi à l'autre personne",
        },
    }
