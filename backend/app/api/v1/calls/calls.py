"""Pokou — appels audio/vidéo/de groupe (LiveKit Cloud). Signalisation via
WebSocket (voir app/routes/ws.py::manager). Le déroulé d'un appel (qui a
répondu, statut final, durée) est journalisé dans call_logs/
call_participants au fil des événements de signalisation reçus par
/calls/signal — il n'y a pas de webhook LiveKit dans cette phase, donc
cette journalisation ne peut être plus précise que ce que le client
signale explicitement (voir CallScreen._hangUp côté Flutter, qui doit
notifier chaque autre participant à la fin de l'appel)."""
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db
from app.models import CallLog, CallParticipant, Contact, Group, GroupMember, User
from app.api.v1.account.profile import _serialize_avatar
from app.api.v1.messaging.ws import manager
from app.services.auth import action_token_service
from app.services.calls import call_housekeeping, call_thread_service, livekit_service
from app.services.messaging import notification_policy
from app.services.notifications.push_service import send_push
from app.utils.identity import est_certifie, nom_affiche, nom_certifie
from app.core.security import get_current_user

router = APIRouter(prefix="/calls", tags=["Pokou calls"])


def _require_contact(db: Session, owner_id: int, contact_user_id: int) -> None:
    """Qui ai-je le droit d'appeler ?

    La MÊME règle que pour écrire, et c'est la troisième fois qu'il faut le
    rappeler : messages.py a été assoupli, presence.py était resté en
    arrière, et celui-ci aussi.

    Le symptôme était le même à chaque fois, mais plus déroutant ici :
    depuis une conversation avec quelqu'un qui n'est pas dans le carnet, on
    pouvait écrire — la règle d'envoi l'autorise — et le bouton d'appel
    renvoyait 403. Aucun appel n'était créé, donc rien n'apparaissait dans
    l'onglet Appels, et l'utilisateur ne voyait qu'un échec sans cause.

    Appeler quelqu'un à qui l'on a le droit d'écrire est le comportement
    attendu de n'importe quelle messagerie. Une seule règle, définie à un
    seul endroit.
    """
    # Import local : messages.py importe déjà de ce module au chargement.
    from app.api.v1.messaging.messages import _require_reachable

    _require_reachable(db, owner_id, contact_user_id)


def _require_group_membership(db: Session, group_id: int, user_id: int) -> Group:
    """Appeler un groupe n'exige PAS que ses membres soient dans le carnet
    d'adresses : l'appartenance au groupe est la mise en relation (même règle
    que pour les messages de groupe, voir routes/groups.py). Sans ça
    `_require_contact` refuserait d'appeler un membre qu'on n'a pas ajouté."""
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, GroupMember.user_id == user_id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Vous n'êtes pas membre de ce groupe")
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    return group


# Un appel « en cours » n'est connu que par ce que les clients signalent (pas
# de webhook LiveKit dans cette phase) : un client qui plante laisserait une
# ligne ringing/ongoing éternelle, et donc un bandeau « Rejoindre » fantôme.
# D'où ces bornes de fraîcheur, volontairement larges.
# Mêmes valeurs que le balayage qui clôt les appels abandonnés.
_RINGING_TTL = call_housekeeping.RINGING_TTL
_ONGOING_TTL = call_housekeeping.ONGOING_TTL


def _active_group_call(db: Session, group_id: int) -> Optional[CallLog]:
    """Appel encore joignable pour ce groupe, ou None. Sert à deux choses :
    afficher « Appel en cours — Rejoindre », et faire converger deux
    personnes qui lancent un appel au même moment vers le MÊME salon."""
    now = datetime.utcnow()
    candidates = (
        db.query(CallLog)
        .filter(
            CallLog.group_id == group_id,
            CallLog.ended_at.is_(None),
            CallLog.status.in_(["ringing", "ongoing"]),
        )
        .order_by(CallLog.created_at.desc())
        .limit(5)
        .all()
    )
    for call in candidates:
        ttl = _RINGING_TTL if call.status == "ringing" else _ONGOING_TTL
        if now - call.created_at <= ttl:
            return call
    return None


def _participant_user_ids(call: CallLog) -> List[int]:
    # dict.fromkeys : dédoublonne en gardant l'ordre — l'appelant peut aussi
    # avoir une ligne CallParticipant (créée pour enregistrer son départ).
    return list(dict.fromkeys([call.caller_id] + [p.user_id for p in call.participants]))


#: Les issues après lesquelles un appel n'accepte plus personne.
_TERMINAL_STATUSES = {"ended", "declined", "missed"}


def _is_over(call: CallLog) -> bool:
    """L'appel est-il fini, ou abandonné ?

    « Abandonné » au sens des bornes de fraîcheur : un appel qui sonne depuis
    plus de 90 s ou « en cours » depuis plus de 4 h sans qu'aucun client ne
    l'ait clos n'existe plus en pratique (le balayage du planificateur le
    clôt, voir close_stale_calls)."""
    if call.ended_at is not None or call.status in _TERMINAL_STATUSES:
        return True
    ttl = _RINGING_TTL if call.status == "ringing" else _ONGOING_TTL
    return datetime.utcnow() - call.created_at > ttl


def _may_join(db: Session, call: CallLog, user_id: int) -> bool:
    """Qui peut entrer dans le salon d'un appel : ses participants (appelant
    et invités), et pour un appel de groupe tout membre du groupe — c'est le
    bandeau « Appel en cours · Rejoindre ». Connaître le NOM du salon ne
    suffit plus : c'est un identifiant, pas une autorisation."""
    if user_id in _participant_user_ids(call):
        return True
    if call.group_id is not None:
        return (
            db.query(GroupMember.id)
            .filter(GroupMember.group_id == call.group_id, GroupMember.user_id == user_id)
            .first()
            is not None
        )
    return False


def _ringable_group_members(db: Session, group: Group, caller_id: int) -> List[int]:
    """Les membres qu'un appel de groupe a le droit de faire sonner.

    Le blocage s'applique ici comme en 1:1 (voir messages.py::_require_reachable) :
    il était vérifié pour un appel à deux, pas pour un appel de groupe, si
    bien qu'une personne bloquée faisait sonner celle qui l'avait bloquée en
    passant par un groupe commun. Symétrique, comme partout ailleurs."""
    from app.api.v1.messaging.conversations import is_blocked_between# import local : cycle via messages.py

    return [
        member.user_id
        for member in group.members
        if member.user_id != caller_id and not is_blocked_between(db, caller_id, member.user_id)
    ]


async def _ring(
    db: Session,
    call: CallLog,
    *,
    caller: User,
    invitee_ids: List[int],
    is_video: bool,
    group: Optional[Group] = None,
) -> None:
    """Sonne chez chaque invité : WebSocket si connecté, push sinon. Partagé
    par le lancement d'appel et l'ajout de participants en cours d'appel."""
    caller_verified = est_certifie(caller)
    for invitee_id in invitee_ids:
        delivered = await manager.send_to_user(invitee_id, {
            "type": "call:invite",
            "room": call.room,
            "from_user_id": caller.id,
            # Le ✓ et le nom d'un compte certifié, pour l'écran d'appel
            # entrant : l'application ne peut pas les deviner pour quelqu'un
            # qui n'est pas dans son carnet.
            "caller_is_verified": caller_verified,
            "caller_certified_name": nom_certifie(caller),
            "call_type": call.call_type,
            "is_video": is_video,
            "group_id": call.group_id,
            "group_name": group.name if group else None,
        })
        if delivered:
            continue
        # Le petname que CET invité a posé sur l'appelant l'emporte sur le
        # nom que l'appelant s'est choisi — propre à chaque destinataire,
        # donc résolu DANS la boucle (voir la même priorité dans
        # messages.py::_deliver).
        invitee_contact = db.query(Contact).filter(
            Contact.owner_user_id == invitee_id, Contact.contact_user_id == caller.id
        ).first()
        caller_name = nom_affiche(
            caller, invitee_contact.display_name if invitee_contact else None, repli="Pokou"
        )
        send_push(
            db,
            invitee_id,
            title=group.name if group else caller_name,
            body=(
                f"{caller_name} — appel de groupe" if group
                else ("Appel vidéo entrant" if is_video else "Appel audio entrant")
            ),
            data={
                # Un appel passe toujours et au maximum : une conversation en
                # sourdine ne couvre pas les appels (notification_policy.py).
                **notification_policy.decide(
                    db,
                    recipient_id=invitee_id,
                    event=notification_policy.NotificationEvent.CALL,
                ).as_payload(),
                "type": "call",
                "room": call.room,
                "from_user_id": str(caller.id),
                "is_video": "1" if is_video else "0",
                "caller_name": caller_name,
                "caller_is_verified": "1" if caller_verified else "0",
                # Les deux laissez-passer que la couche native rendra pour
                # accepter ou refuser SANS que Flutter démarre — le jeton de
                # session vit côté Dart et ne lui est pas accessible. Voir
                # services/action_token_service.py et
                # docs/native-call-layer.md §3.
                **action_token_service.issue_call_pair(
                    db, user_id=invitee_id, room=call.room
                ),
                **({"group_id": str(call.group_id), "group_name": group.name} if group else {}),
            },
            # data-only : le client construit lui-même la notification
            # d'appel (plein écran, actions Répondre/Refuser) depuis
            # l'isolate d'arrière-plan — voir push_service.dart. Un
            # payload "notification" ferait qu'Android affiche EN PLUS
            # sa propre notification par défaut, sans sonnerie/actions.
            silent=True,
        )


class SealedCallKey(BaseModel):
    """La clé d'un appel chiffrée de bout en bout pour UN invité — même forme
    qu'un message chiffré (voir messages.py::MessageCreate). Le serveur ne
    peut pas l'ouvrir : il la range et la rend à l'invité quand il rejoint."""
    encryption: str = Field(..., pattern="^v1$")
    ciphertext: str = Field(..., max_length=4000)
    envelope: Dict[str, Any]


class CallTokenRequest(BaseModel):
    # Nouvel appel : un ou plusieurs destinataires (2+ = appel de groupe).
    contact_ids: Optional[List[int]] = None
    # Appel lancé depuis une conversation de groupe : tous les membres sont
    # sonnés, sans avoir à les énumérer ni à les avoir dans ses contacts.
    group_id: Optional[int] = None
    # Rejoindre un salon existant, reçu via l'événement WS call:invite.
    room: Optional[str] = None
    is_video: bool = True
    # Appel chiffré de bout en bout : la clé du salon, scellée pour CHAQUE
    # invité (clé = son identifiant, en texte — c'est du JSON). Tout ou rien :
    # un invité sans clé ne pourrait ni voir ni entendre les autres.
    sealed_keys: Optional[Dict[str, SealedCallKey]] = None


class CallInviteRequest(BaseModel):
    """Ajout de participants à un appel DÉJÀ en cours."""
    room: str
    user_ids: List[int] = Field(..., min_length=1)
    # Obligatoire si l'appel est chiffré — voir CallTokenRequest.sealed_keys.
    sealed_keys: Optional[Dict[str, SealedCallKey]] = None


def _sealed_keys_for(
    sealed_keys: Optional[Dict[str, SealedCallKey]], invitee_ids: List[int], sealer_id: int
) -> Dict[int, Dict[str, Any]]:
    """Les clés scellées par invité, ou 400 s'il en manque une.

    Un appel chiffré où un invité n'a pas reçu la clé n'est pas « presque
    chiffré » : cet invité ne verrait que du bruit. On refuse plutôt que de
    créer un appel que quelqu'un ne pourra pas suivre."""
    if not sealed_keys:
        return {}
    keyed: Dict[int, Dict[str, Any]] = {}
    for invitee_id in invitee_ids:
        sealed = sealed_keys.get(str(invitee_id))
        if sealed is None:
            raise HTTPException(
                status_code=400,
                detail=f"Clé d'appel chiffré manquante pour l'invité {invitee_id}",
            )
        # `from_user_id` : l'invité ouvre l'enveloppe avec la session qu'il a
        # avec CELUI QUI L'A SCELLÉE — l'appelant, ou la personne qui l'a
        # ajouté en cours d'appel.
        keyed[invitee_id] = {**sealed.model_dump(), "from_user_id": sealer_id}
    return keyed


class CallSignal(BaseModel):
    room: str
    target_user_id: int
    event: str  # accept | decline | end


@router.post("/token")
async def get_call_token(
    payload: CallTokenRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    group: Optional[Group] = None
    invitee_ids: List[int] = []
    joined: Optional[CallLog] = None

    if payload.room:
        # Rejoindre un salon dont on a reçu le nom (événement call:invite).
        #
        # Le salon doit être celui d'un appel CONNU, encore ouvert, auquel on a
        # droit. Auparavant n'importe quel nom suffisait : un jeton valable six
        # heures pour une salle inventée, c'est-à-dire le LiveKit payé de Pokou
        # offert comme service de visioconférence à tout compte. 404 pour
        # « inconnu » comme pour « pas pour vous » : on ne confirme pas
        # l'existence d'un appel à qui n'y est pas invité.
        joined = db.query(CallLog).filter(CallLog.room == payload.room).first()
        if joined is None or not _may_join(db, joined, user_id):
            raise HTTPException(status_code=404, detail="Appel introuvable")
        if _is_over(joined):
            raise HTTPException(status_code=409, detail="Cet appel est terminé")
        room_name = joined.room
        call_type = None
    elif payload.group_id:
        group = _require_group_membership(db, payload.group_id, user_id)
        joined = _active_group_call(db, group.id)
        if joined:
            # Convergence : un seul appel par groupe. Deux membres qui
            # appuient sur « appeler » au même moment rejoignent le même
            # salon au lieu d'ouvrir deux appels parallèles.
            room_name = joined.room
            call_type = None
        else:
            room_name = livekit_service.new_room_name()
            call_type = "group"
            invitee_ids = _ringable_group_members(db, group, user_id)
            if not invitee_ids:
                raise HTTPException(status_code=400, detail="Ce groupe n'a aucun autre membre à appeler")
            limit = get_settings().call_max_group_ring
            if len(invitee_ids) > limit:
                raise HTTPException(
                    status_code=400,
                    detail=f"Ce groupe est trop grand pour un appel ({len(invitee_ids)} membres, {limit} au plus)",
                )
    elif payload.contact_ids:
        for contact_id in payload.contact_ids:
            _require_contact(db, user_id, contact_id)
        room_name = livekit_service.new_room_name()
        call_type = "group" if len(payload.contact_ids) > 1 else "1:1"
        invitee_ids = list(payload.contact_ids)
    else:
        raise HTTPException(status_code=400, detail="contact_ids, group_id ou room requis")

    # Seul un NOUVEL appel vers des contacts peut être chiffré : un appel de
    # groupe sonne des membres que l'appelant n'énumère pas, et rejoindre un
    # salon reprend le chiffrement que son créateur a choisi.
    if payload.sealed_keys and not (call_type and payload.contact_ids):
        raise HTTPException(
            status_code=400, detail="Seul un nouvel appel vers des contacts peut être chiffré"
        )
    sealed_by_invitee = _sealed_keys_for(payload.sealed_keys, invitee_ids, user_id)

    try:
        token = livekit_service.generate_token(room_name, user)
    except livekit_service.LiveKitNotConfiguredError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    if call_type:
        call_log = CallLog(
            caller_id=user_id,
            room=room_name,
            group_id=group.id if group else None,
            call_type=call_type,
            is_video=payload.is_video,
            status="ringing",
            e2ee=bool(sealed_by_invitee),
        )
        db.add(call_log)
        db.flush()
        for invitee_id in invitee_ids:
            db.add(
                CallParticipant(
                    call_log_id=call_log.id,
                    user_id=invitee_id,
                    status="invited",
                    sealed_key=sealed_by_invitee.get(invitee_id),
                )
            )
        db.commit()
        db.refresh(call_log)
        await _ring(
            db,
            call_log,
            caller=user,
            invitee_ids=invitee_ids,
            is_video=payload.is_video,
            group=group,
        )
    else:
        call_log = joined or db.query(CallLog).filter(CallLog.room == room_name).first()
        if call_log:
            _join_existing(db, call_log, user_id)

    settings = get_settings()
    return {
        "room": room_name,
        "token": token,
        "livekit_url": settings.livekit_url,
        # Le client s'en sert pour signaler `end` à tout le monde en
        # raccrochant, y compris aux gens ajoutés en cours d'appel.
        "participant_ids": (
            [pid for pid in _participant_user_ids(call_log) if pid != user_id] if call_log else []
        ),
        "joined_existing": call_type is None,
        # Chiffré de bout en bout : le client règle LiveKit en conséquence,
        # avec la clé scellée pour lui — absente pour l'appelant, qui l'a
        # tirée lui-même, et pour quelqu'un à qui elle n'a pas été donnée.
        "e2ee": bool(call_log.e2ee) if call_log else False,
        "sealed_key": _sealed_key_of(call_log, user_id) if call_log else None,
    }


def _sealed_key_of(call: CallLog, user_id: int) -> Optional[Dict[str, Any]]:
    for participant in call.participants:
        if participant.user_id == user_id and participant.sealed_key:
            return participant.sealed_key
    return None


def _join_existing(db: Session, call: CallLog, user_id: int) -> None:
    """Inscrit celui qui rejoint un appel déjà ouvert s'il n'y figurait pas —
    cas du membre qui rejoint de son propre chef depuis le bandeau « Appel en
    cours » : sans ça l'appel n'apparaîtrait pas dans son journal et il ne
    recevrait pas le signal de fin."""
    if call.caller_id == user_id:
        return
    participant = db.query(CallParticipant).filter(
        CallParticipant.call_log_id == call.id, CallParticipant.user_id == user_id
    ).first()
    now = datetime.utcnow()
    if participant is None:
        db.add(CallParticipant(
            call_log_id=call.id, user_id=user_id, status="accepted", responded_at=now
        ))
    if call.status == "ringing":
        call.status = "ongoing"
    db.commit()


@router.get("/active")
async def get_active_group_call(
    group_id: int = Query(..., description="Groupe dont on cherche l'appel en cours"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Alimente le bandeau « Appel en cours — Rejoindre » d'une conversation
    de groupe. Renvoie `{"active": false}` plutôt qu'un 404 : l'absence
    d'appel est le cas NORMAL, pas une erreur."""
    user_id = current_user["user_id"]
    _require_group_membership(db, group_id, user_id)
    call = _active_group_call(db, group_id)
    if not call:
        return {"active": False}

    participant_ids = [pid for pid in _participant_user_ids(call) if pid != user_id]
    return {
        "active": True,
        "room": call.room,
        "is_video": call.is_video,
        "started_at": call.created_at.isoformat(),
        "caller_id": call.caller_id,
        "participant_ids": participant_ids,
    }


@router.post("/invite")
async def invite_to_call(
    payload: CallInviteRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ajoute des participants à un appel EN COURS. Marche aussi en 1:1 : un
    appel à deux devient un appel de groupe dès qu'un tiers est invité (même
    comportement que WhatsApp). Le salon reste le même — inutile de
    reconnecter ceux qui sont déjà dedans."""
    user_id = current_user["user_id"]
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    call = db.query(CallLog).filter(CallLog.room == payload.room).first()
    if not call:
        raise HTTPException(status_code=404, detail="Appel introuvable")
    # Seul quelqu'un qui est dans l'appel peut y faire entrer du monde.
    if user_id not in _participant_user_ids(call):
        raise HTTPException(status_code=403, detail="Vous ne participez pas à cet appel")
    if call.ended_at is not None or call.status in {"ended", "declined", "missed"}:
        raise HTTPException(status_code=409, detail="Cet appel est terminé")

    group = db.query(Group).filter(Group.id == call.group_id).first() if call.group_id else None
    already = set(_participant_user_ids(call))
    # Un appel chiffré n'accueille que des invités à qui l'on a donné la clé.
    if call.e2ee:
        new_ids = [i for i in payload.user_ids if i not in already]
        sealed_by_invitee = (
            _sealed_keys_for(payload.sealed_keys, new_ids, user_id) if new_ids else {}
        )
        if new_ids and not payload.sealed_keys:
            raise HTTPException(
                status_code=409,
                detail="Cet appel est chiffré : chaque invité doit recevoir sa clé",
            )
    else:
        sealed_by_invitee = {}
    invitee_ids: List[int] = []
    for invitee_id in payload.user_ids:
        if invitee_id in already:
            continue
        # Un membre du groupe est joignable sans être dans le carnet
        # d'adresses — sauf blocage ; hors groupe, la règle habituelle
        # (blocage compris) s'applique.
        if group is not None and db.query(GroupMember).filter(
            GroupMember.group_id == group.id, GroupMember.user_id == invitee_id
        ).first():
            from app.api.v1.messaging.conversations import is_blocked_between

            if is_blocked_between(db, user_id, invitee_id):
                raise HTTPException(status_code=403, detail="Impossible d'inviter cette personne")
        else:
            _require_contact(db, user_id, invitee_id)
        db.add(
            CallParticipant(
                call_log_id=call.id,
                user_id=invitee_id,
                status="invited",
                sealed_key=sealed_by_invitee.get(invitee_id),
            )
        )
        invitee_ids.append(invitee_id)
        already.add(invitee_id)

    if not invitee_ids:
        return {"invited": [], "participant_ids": [pid for pid in already if pid != user_id]}
    if len(already) > get_settings().call_max_group_ring + 1:
        db.rollback()
        raise HTTPException(status_code=400, detail="Trop de participants pour cet appel")

    # Un appel à deux qui s'ouvre à un tiers EST un appel de groupe.
    if call.call_type == "1:1":
        call.call_type = "group"
    db.commit()
    db.refresh(call)

    await _ring(
        db,
        call,
        caller=user,
        invitee_ids=invitee_ids,
        is_video=call.is_video,
        group=group,
    )
    return {
        "invited": invitee_ids,
        "participant_ids": [pid for pid in _participant_user_ids(call) if pid != user_id],
    }


class CallActionRequest(BaseModel):
    """Ce que la couche NATIVE envoie, sans jeton de session.

    Pas de `target_user_id` : le jeton porte déjà le salon et son
    destinataire. Le laisser au client permettrait de signaler à la place de
    quelqu'un d'autre avec un jeton légitime."""

    token: str
    event: str = Field(..., pattern="^(accept|decline)$")


@router.post("/action")
async def call_action(
    payload: CallActionRequest,
    db: Session = Depends(get_db),
):
    """Accepter ou refuser un appel avec un JETON D'ACTION.

    Aucune authentification par `Authorization` — c'est tout l'objet de la
    manœuvre. La couche native, réveillée par un push alors que Flutter
    n'existe pas, ne peut pas produire de jeton de session : elle rend celui
    que le push lui a donné, qui n'autorise que cette action, sur ce salon,
    pour ce destinataire.

    ── Idempotence ──────────────────────────────────────────────────────

    Android peut délivrer deux fois la même action : réseau lent, double
    appui, intent rejoué après un redémarrage du processus. Un jeton déjà
    consommé renvoie donc **200 avec l'état courant**, et non une erreur.

    Un 4xx pousserait le natif à réessayer, ou afficherait un échec à
    quelqu'un dont l'action a en réalité réussi. Le corps porte l'état réel,
    dont le natif se sert pour se synchroniser.
    """
    scope = (
        action_token_service.SCOPE_CALL_ACCEPT
        if payload.event == "accept"
        else action_token_service.SCOPE_CALL_DECLINE
    )

    row = action_token_service.consume(db, payload.token, expected_scope=scope)
    if row is None:
        # Déjà consommé : l'action a eu lieu, on le dit sans la refaire.
        if action_token_service.was_consumed(db, payload.token, expected_scope=scope):
            return {"ok": True, "already_applied": True}
        # Inconnu, périmé, mauvaise portée, session révoquée : une seule
        # réponse pour tous les cas. Les distinguer dirait à un attaquant
        # quel jeton vaut la peine d'être rejoué.
        raise HTTPException(status_code=403, detail="Action impossible")

    call_log = db.query(CallLog).filter(CallLog.room == row.room).first()
    if call_log is None:
        raise HTTPException(status_code=404, detail="Appel introuvable")

    # Le serveur reste l'autorité sur les transitions : accepter un appel
    # déjà terminé, ou refuser un appel déjà accepté, n'a pas de sens et ne
    # doit pas écraser un état plus récent.
    if call_log.status in {"ended", "missed"}:
        return {"ok": False, "call_status": call_log.status, "reason": "call_over"}

    signal = CallSignal(
        room=row.room,
        target_user_id=call_log.caller_id,
        event=payload.event,
    )
    _apply_signal_to_log(db, signal, row.user_id)

    await manager.send_to_user(call_log.caller_id, {
        "type": f"call:{payload.event}",
        "room": row.room,
        "from_user_id": row.user_id,
    })

    # Un refus depuis la notification termine l'appel pour un 1:1. Les autres
    # appareils du destinataire — il peut en avoir plusieurs — doivent cesser
    # de sonner, et le WebSocket ne les atteint pas s'ils sont fermés.
    if payload.event == "decline" and call_log.call_type != "group":
        _push_call_ended(db, row.user_id, row.room)

    return {"ok": True, "call_status": call_log.status}


@router.post("/signal")
async def signal_call(
    payload: CallSignal,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    if payload.event not in {"accept", "decline", "end"}:
        raise HTTPException(status_code=400, detail="Événement invalide")

    actor_id = current_user["user_id"]
    # L'autorisation, avant TOUT effet — journal, WebSocket ou push.
    #
    # Ce contrôle n'existait pas : connaître le nom d'un salon suffisait pour
    # terminer, accepter ou refuser l'appel des autres, et faire envoyer un
    # événement (et un push `call_end`) à n'importe quel identifiant
    # d'utilisateur. Le salon n'est qu'un identifiant, pas une preuve.
    call_log = db.query(CallLog).filter(CallLog.room == payload.room).first()
    if call_log is None:
        raise HTTPException(status_code=404, detail="Appel introuvable")
    members = set(_participant_user_ids(call_log))
    if actor_id not in members:
        raise HTTPException(status_code=404, detail="Appel introuvable")
    if payload.target_user_id not in members or payload.target_user_id == actor_id:
        raise HTTPException(status_code=400, detail="Ce destinataire ne participe pas à cet appel")
    if payload.event in {"accept", "decline"} and actor_id == call_log.caller_id:
        raise HTTPException(status_code=400, detail="L'appelant ne répond pas à son propre appel")
    if _is_over(call_log):
        if payload.event == "accept":
            raise HTTPException(status_code=409, detail="Cet appel est terminé")
        # Refuser ou raccrocher un appel déjà fini : rien à faire, et rien à
        # signaler — deux raccrochés simultanés sont le cas normal.
        return {"ok": True, "already_over": True}

    _apply_signal_to_log(db, payload, actor_id)

    delivered = await manager.send_to_user(payload.target_user_id, {
        "type": f"call:{payload.event}",
        "room": payload.room,
        "from_user_id": actor_id,
    })

    # La fin d'un appel doit atteindre le destinataire MÊME si son
    # application est fermée.
    #
    # Elle ne partait qu'en WebSocket, qui n'existe que tant que
    # l'application tourne. Résultat constaté : l'appelant raccrochait, et le
    # téléphone du destinataire continuait de sonner jusqu'à l'expiration des
    # 45 secondes — la couche native n'ayant aucun moyen d'apprendre que
    # l'appel était terminé.
    if payload.event == "end" and not delivered:
        _push_call_ended(db, payload.target_user_id, payload.room)

    return {"ok": True}


def _push_call_ended(db: Session, user_id: int, room: str) -> None:
    """Prévient un appareil fermé qu'un appel est terminé.

    Message DATA-ONLY : il ne doit afficher aucune notification. Son seul
    rôle est de réveiller la couche native pour qu'elle fasse taire la
    sonnerie et retire la notification d'appel — voir
    PokouFirebaseMessagingService, qui intercepte `type == "call_end"`.

    Priorité haute et volontairement : un push ordinaire peut être retardé
    de plusieurs minutes par le regroupement d'Android, et un téléphone qui
    sonne pendant ce temps-là est exactement le défaut qu'on corrige.
    """
    send_push(
        db,
        user_id,
        title="",
        body="",
        data={"type": "call_end", "room": room},
        silent=True,
    )


def _apply_signal_to_log(db: Session, payload: CallSignal, actor_id: int) -> None:
    call_log = db.query(CallLog).filter(CallLog.room == payload.room).first()
    if not call_log:
        return  # signalisation sans journal correspondant — ne bloque pas l'appel

    now = datetime.utcnow()

    if payload.event == "accept":
        participant = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call_log.id, CallParticipant.user_id == actor_id
        ).first()
        if participant:
            participant.status = "accepted"
            participant.responded_at = now
        if call_log.status == "ringing":
            call_log.status = "ongoing"

    elif payload.event == "decline":
        participant = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call_log.id, CallParticipant.user_id == actor_id
        ).first()
        if participant:
            participant.status = "declined"
            participant.responded_at = now
        db.flush()  # rend le changement visible à la requête suivante (autoflush=False en tests)
        still_pending = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call_log.id, CallParticipant.status == "invited"
        ).first()
        # « ongoing » sans personne qui ait accepté : l'invité a rejoint le
        # salon (ce qui fait passer l'appel en cours) puis a dû refuser —
        # la clé d'un appel chiffré ne s'ouvrait pas chez lui. Sans ce cas,
        # l'appel restait « en cours » pour toujours dans le journal.
        someone_accepted = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call_log.id, CallParticipant.status == "accepted"
        ).first()
        if not still_pending and (
            call_log.status == "ringing"
            or (call_log.status == "ongoing" and not someone_accepted)
        ):
            call_log.status = "declined"
            call_log.ended_at = now

    elif payload.event == "end" and call_log.call_type == "group":
        _apply_group_end(db, call_log, actor_id, now)

    elif payload.event == "end":
        if call_log.ended_at is None:
            call_log.ended_at = now
        if call_log.status == "ringing":
            call_log.status = "missed"
        elif call_log.status == "ongoing":
            call_log.status = "ended"
        # Le destinataire de ce "end" n'a peut-être jamais répondu (l'appelant
        # a raccroché avant décroché) — marque sa ligne comme manquée.
        target_participant = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call_log.id, CallParticipant.user_id == payload.target_user_id
        ).first()
        if target_participant and target_participant.status == "invited":
            target_participant.status = "missed"
            target_participant.responded_at = now

    # ── L'appel entre dans l'histoire de la conversation ─────────────────
    #
    # UN SEUL point de dépôt, juste avant le commit, et non un appel dans
    # chacune des branches ci-dessus. Les trois chemins terminaux (refus de
    # tous les invités, raccrochage à deux, dernier partant d'un appel de
    # groupe) convergent ici ; le service ne fait rien si l'appel n'est pas
    # terminé ou s'il l'a déjà journalisé.
    #
    # Avant le commit, délibérément : le message et la marque d'idempotence
    # doivent être écrits dans la MÊME transaction que l'état final, sinon
    # une panne entre les deux laisse un appel terminé sans trace, ou une
    # trace sans marque qui se dupliquera au prochain passage.
    call_thread_service.journaliser(db, call_log)

    db.commit()


def _apply_group_end(db: Session, call_log: CallLog, actor_id: int, now: datetime) -> None:
    """Dans un appel de groupe, « end » veut dire « JE quitte », pas « l'appel
    est fini » : les autres continuent de se parler. L'appel n'est clos que
    quand il ne reste plus au plus une personne — sinon le bandeau « Appel en
    cours » d'une conversation de groupe disparaîtrait dès le premier départ.

    Le départ est enregistré dans `left_at` et non dans `status`, qui garde la
    réponse à l'invitation (c'est d'elle que `_serialize_call_log` déduit la
    durée de l'appel)."""
    participant = db.query(CallParticipant).filter(
        CallParticipant.call_log_id == call_log.id, CallParticipant.user_id == actor_id
    ).first()
    if participant is None:
        # L'appelant n'a pas de ligne à la création de l'appel : on en crée
        # une pour pouvoir enregistrer SON départ comme celui des autres.
        participant = CallParticipant(
            call_log_id=call_log.id,
            user_id=actor_id,
            status="accepted",
            responded_at=call_log.created_at,
        )
        db.add(participant)
    participant.left_at = now
    if participant.status == "invited":
        # Il quitte sans avoir jamais décroché (il a fermé l'écran d'appel).
        participant.status = "missed"
        participant.responded_at = now
    db.flush()  # autoflush=False en tests : rend le départ visible ci-dessous

    # Qui reste ? Les invités qui ont décroché et pas encore quitté, plus
    # l'appelant tant qu'il n'a pas quitté (il n'a de ligne que depuis son
    # propre départ, d'où ce traitement à part).
    rows = db.query(CallParticipant).filter(CallParticipant.call_log_id == call_log.id).all()
    still_in_call = {
        row.user_id for row in rows if row.status == "accepted" and row.left_at is None
    }
    caller_row = next((row for row in rows if row.user_id == call_log.caller_id), None)
    if caller_row is None or caller_row.left_at is None:
        still_in_call.add(call_log.caller_id)

    if len(still_in_call) > 1:
        return

    if call_log.ended_at is None:
        call_log.ended_at = now
    if call_log.status == "ringing":
        call_log.status = "missed"
    elif call_log.status == "ongoing":
        call_log.status = "ended"


@router.get("/log")
async def get_call_log(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    calls = (
        db.query(CallLog)
        .outerjoin(CallParticipant, CallParticipant.call_log_id == CallLog.id)
        .filter((CallLog.caller_id == user_id) | (CallParticipant.user_id == user_id))
        .order_by(CallLog.created_at.desc())
        .distinct()
        .limit(100)
        .all()
    )
    return {"items": [_serialize_call_log(db, call, user_id) for call in calls]}


def _serialize_call_log(db: Session, call: CallLog, viewer_id: int) -> dict:
    direction = "outgoing" if call.caller_id == viewer_id else "incoming"

    other_user_ids = {p.user_id for p in call.participants} | {call.caller_id}
    other_user_ids.discard(viewer_id)
    others = db.query(User).filter(User.id.in_(other_user_ids)).all() if other_user_ids else []
    # Le nom que CE spectateur a mis dans son carnet — sauf compte certifié,
    # voir utils/identity.py::nom_affiche.
    petnames = {
        row.contact_user_id: row.display_name
        for row in db.query(Contact).filter(
            Contact.owner_user_id == viewer_id,
            Contact.contact_user_id.in_(other_user_ids),
        ).all()
    } if other_user_ids else {}

    status = call.status
    if direction == "incoming":
        mine = next((p for p in call.participants if p.user_id == viewer_id), None)
        if mine:
            status = mine.status

    accepted_at = next(
        (p.responded_at for p in call.participants if p.status == "accepted" and p.responded_at), None
    )
    duration_seconds = None
    if accepted_at and call.ended_at:
        duration_seconds = max(0, int((call.ended_at - accepted_at).total_seconds()))

    return {
        "id": call.id,
        "direction": direction,
        "call_type": call.call_type,
        "group_id": call.group_id,
        # Nom du groupe plutôt que la liste des membres pour intituler un
        # appel de groupe dans le journal.
        "group_name": call.group.name if call.group else None,
        "is_video": call.is_video,
        "status": status,
        "created_at": call.created_at.isoformat(),
        "ended_at": call.ended_at.isoformat() if call.ended_at else None,
        "duration_seconds": duration_seconds,
        "others": [
            {
                "id": u.id,
                "display_name": nom_affiche(u, petnames.get(u.id)),
                "avatar": _serialize_avatar(u.avatar_media),
                "is_verified": est_certifie(u),
            }
            for u in others
        ],
    }
