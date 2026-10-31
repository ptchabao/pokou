import hashlib
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Response, status, Request
from fastapi.responses import JSONResponse
from jose import jwt
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.core.database import get_db
from app.schemas.auth import UserResponse, TokenSchema, ErrorResponse, LoginResponse
from app.models import DeviceToken, User, Token
from app.core.security import create_access_token, create_refresh_token, verify_token, get_current_user
from app.core.audit import AuditLogger
# Réutilise la vérification et la limitation de tentatives du module de
# confidentialité plutôt que d'en refaire une : partager le compteur est ce
# qui empêche cette route d'être une porte de devinage non protégée.
from app.api.v1.account.account_privacy import _check_pin, _reject_if_throttled, two_step_required
from app.core.config import get_settings
from app.services.auth import contact_linking, otp_service
from app.api.v1.messaging.ws import manager
from pydantic import BaseModel, Field
import logging
import secrets

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["authentication"])
settings = get_settings()


# ─── Session cookie (admin/ only — frontend/ keeps using the JSON body) ──────
ACCESS_TOKEN_COOKIE_NAME = "access_token"


def _set_access_token_cookie(response: Response, access_token: str) -> None:
    """httpOnly cookie so JS on admin/ never touches the token directly
    (mitigates XSS token theft). Same-origin only in this app (the admin
    Next.js app proxies /api/* to this backend server-side), so plain
    SameSite=Lax works without needing Secure+SameSite=None — that
    combination would require HTTPS, which local dev doesn't have."""
    response.set_cookie(
        key=ACCESS_TOKEN_COOKIE_NAME,
        value=access_token,
        httponly=True,
        secure=settings.environment == "production",
        samesite="lax",
        max_age=settings.access_token_expire_minutes * 60,
        path="/",
    )


# Type de jeton distinct : `verify_token` refuse un jeton dont le `type` ne
# correspond pas, ce qui empêche de présenter un jeton d'accès normal comme
# laissez-passer de seconde étape (et inversement).
_TWO_STEP_TOKEN_TYPE = "two_step_pending"
_TWO_STEP_PENDING_TTL = timedelta(minutes=5)


def _create_two_step_pending_token(user: User) -> str:
    """Laissez-passer court prouvant que l'OTP est passé. Volontairement sans
    `jti` et non persisté : il n'ouvre aucun accès, il ne fait qu'autoriser la
    présentation du code du compte, et il expire en 5 minutes."""
    return jwt.encode(
        {
            "sub": user.email or user.phone or str(user.id),
            "user_id": user.id,
            "type": _TWO_STEP_TOKEN_TYPE,
            "exp": datetime.utcnow() + _TWO_STEP_PENDING_TTL,
        },
        settings.secret_key,
        algorithm=settings.algorithm,
    )


def _token_digest(token: str) -> str:
    """L'empreinte d'un jeton, pour la ligne de session.

    Les jetons COMPLETS étaient écrits en base. Personne ne les relit —
    la révocation passe uniquement par le `jti` — mais un export de la base,
    une sauvegarde, un accès en lecture chez l'hébergeur livraient des
    sessions immédiatement utilisables. Une table de sessions ne doit pas
    être une réserve de mots de passe.

    Une empreinte garde ce qui servait vraiment : partant d'un jeton trouvé
    quelque part, retrouver la session qui l'a émis. Elle ne permet pas le
    chemin inverse.

    Pas de sel : un JWT contient déjà 128 bits d'aléa dans son `jti` et sa
    signature, il n'est pas devinable par dictionnaire — ce contre quoi un
    sel protège.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


#: Combien de temps un jeton de rafraîchissement déjà échangé reste rejouable.
#:
#: Assez pour rattraper une réponse perdue — le client réessaie dans les
#: secondes qui suivent —, trop court pour qu'un jeton intercepté serve
#: longtemps. Et la grâce ne se consomme qu'UNE fois, voir `grace_used_at`.
REFRESH_GRACE = timedelta(seconds=60)


def _issue_session(db: Session, response: Response, user: User) -> tuple[str, str, str]:
    """Mints an access+refresh token pair sharing one `jti`, persists a
    Token row so the session is revocable (see /auth/logout), and sets the
    admin-only httpOnly cookie. Returns (access_token, refresh_token, jti).

    Le `jti` est RENDU, et non rangé quelque part pour être relu ensuite :
    cette fonction sert plusieurs requêtes en parallèle, et un attribut de
    module aurait été écrasé par la connexion de quelqu'un d'autre entre
    l'émission et la lecture. La rotation en a besoin pour chaîner l'ancien
    jeton à son successeur (voir /refresh).

    La ligne ne garde que l'EMPREINTE des jetons — voir _token_digest."""
    # `sub` must be a non-empty string — a Pokou (phone-only) account has no
    # email, and python-jose rejects a null/non-string `sub` claim on decode.
    subject = user.email or user.phone or str(user.id)
    jti = secrets.token_urlsafe(16)
    access_token = create_access_token({"sub": subject, "user_id": user.id}, jti=jti)
    refresh_token = create_refresh_token({"sub": subject, "user_id": user.id}, jti=jti)

    db.add(Token(
        user_id=user.id,
        access_token=_token_digest(access_token),
        refresh_token=_token_digest(refresh_token),
        jti=jti,
        expires_at=datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days),
    ))
    db.commit()

    _set_access_token_cookie(response, access_token)
    return access_token, refresh_token, jti


# CORS preflight handler
@router.options("/{path_name:path}", include_in_schema=False)
async def preflight_handler(path_name: str):
    """CORS preflight handler for all auth routes."""
    return {}


class PhoneOTPRequest(BaseModel):
    phone: str = Field(..., min_length=6, max_length=32)
    #: « both » (défaut), « sms » ou « whatsapp » — voir OTP_CHANNELS. Sert
    #: au renvoi ciblé quand le premier code n'est jamais arrivé.
    channel: str = Field("both", max_length=16)


class PhoneOTPVerify(BaseModel):
    phone: str = Field(..., min_length=6, max_length=32)
    code: str = Field(..., min_length=4, max_length=8)
    # Cochés sur l'écran du numéro, avant le code. Facultatifs ici : un
    # compte existant qui se reconnecte ne les renvoie pas.
    accept_terms: bool = False
    age_confirmed: bool = False
    consent_analytics: Optional[bool] = None
    consent_marketing: Optional[bool] = None


@router.post("/phone/request-otp", responses={400: {"model": ErrorResponse}, 429: {"model": ErrorResponse}})
async def request_phone_otp(payload: PhoneOTPRequest, db: Session = Depends(get_db)):
    """Inscription/connexion façon WhatsApp : envoie un code à usage unique
    par SMS, aucun mot de passe. Un numéro validé par SMS est une preuve de
    possession suffisante pour ouvrir un compte.

    `channel` permet un RENVOI ciblé : quelqu'un dont le code a expiré sans
    jamais arriver peut redemander par WhatsApp seul, plutôt que de repayer
    un SMS sur le chemin qui vient d'échouer. La limite de débit reste la
    même quel que soit le canal — sinon elle se contournerait en alternant."""
    try:
        expires_in = otp_service.generate_and_send_otp(db, payload.phone, payload.channel)
    except otp_service.OTPRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except otp_service.OTPInvalidError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return {"expires_in": expires_in}


@router.post("/phone/verify-otp", response_model=LoginResponse, responses={400: {"model": ErrorResponse}})
async def verify_phone_otp(
    payload: PhoneOTPVerify,
    response: Response,
    db: Session = Depends(get_db),
    request: Request = None,
):
    try:
        user = otp_service.verify_otp(db, payload.phone, payload.code)
        # Inscription en un écran (maquette « 1. Bienvenue et numéro ») : les
        # conditions se cochent AVANT le code, et s'enregistrent ici, une
        # fois le numéro prouvé.
        if payload.accept_terms and payload.age_confirmed:
            now = datetime.utcnow()
            user.terms_accepted_at = now
            user.terms_version = TERMS_VERSION
            user.age_confirmed_at = now
            if payload.consent_analytics is not None:
                user.consent_analytics = payload.consent_analytics
            if payload.consent_marketing is not None:
                user.consent_marketing = payload.consent_marketing
            db.commit()
    except otp_service.OTPRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except otp_service.OTPInvalidError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is inactive")

    # Vérification en deux étapes : le code SMS ne suffit plus, il faut aussi
    # le code du compte. On ne délivre donc AUCUNE session ici — juste un
    # laissez-passer court prouvant que l'OTP est passé, à présenter avec le
    # code sur /auth/phone/two-step. Émettre la session puis exiger le code
    # ensuite laisserait une session valide à qui n'a que le SMS, ce qui
    # viderait la seconde étape de son sens.
    if two_step_required(db, user.id):
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "two_step_required": True,
                "verification_token": _create_two_step_pending_token(user),
                "expires_in": int(_TWO_STEP_PENDING_TTL.total_seconds()),
            },
        )

    access_token, refresh_token, _ = _issue_session(db, response, user)
    await _announce_arrival(db, user)

    ip_address = request.client.host if request else None
    await AuditLogger.log(db, user.id, "login", "user", user.id, ip_address=ip_address, changes={"method": "phone_otp"})

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=user,
    )


async def _announce_arrival(db: Session, user: User) -> None:
    """Rattache les fiches de carnet qui attendaient ce numéro, et prévient
    en temps réel ceux qui les ont écrites.

    Appelé sur les DEUX chemins d'entrée par téléphone (code seul, et code +
    vérification en deux étapes) : n'en couvrir qu'un laisserait la moitié
    des utilisateurs sans rattachement, selon un réglage de sécurité qui n'a
    rien à voir avec le carnet d'adresses.

    Best-effort de bout en bout — une panne de la poussée temps réel ne doit
    jamais faire échouer une connexion. Le rattachement en base, lui, est
    déjà commité : au pire l'information arrive au prochain rafraîchissement.
    """
    try:
        owners = contact_linking.link_pending_contacts(db, user)
        if not owners:
            return
        event = contact_linking.contact_registered_event(user)
        for owner_id in owners:
            await manager.send_to_user(owner_id, event)
    except Exception:  # noqa: BLE001 — voir docstring
        logger.warning("Pokou: annonce d'arrivée impossible pour %s", user.id, exc_info=True)


class PhoneTwoStepVerify(BaseModel):
    verification_token: str
    pin: str = Field(..., min_length=4, max_length=12)


@router.post(
    "/phone/two-step",
    response_model=LoginResponse,
    responses={400: {"model": ErrorResponse}, 403: {"model": ErrorResponse}, 429: {"model": ErrorResponse}},
)
async def verify_phone_two_step(
    payload: PhoneTwoStepVerify,
    response: Response,
    db: Session = Depends(get_db),
    request: Request = None,
):
    """Seconde étape de la connexion : le code du compte, après l'OTP.

    Le laissez-passer présenté ici prouve seulement que l'OTP est passé (voir
    /phone/verify-otp) ; c'est ce code-ci qui débloque la session.

    La limitation de tentatives est CELLE d'account_privacy, partagée
    volontairement : un compteur propre à cette route en ferait un oracle de
    devinage illimité, alors que l'autre porte est protégée."""
    try:
        claims = verify_token(payload.verification_token, token_type=_TWO_STEP_TOKEN_TYPE)
    except HTTPException as exc:
        # Message explicite plutôt que « identifiants invalides » : le
        # laissez-passer expire en 5 minutes et il faut savoir recommencer.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vérification expirée — recommencez la connexion.",
        ) from exc

    user = db.query(User).filter(User.id == claims.get("user_id")).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Compte indisponible")

    _reject_if_throttled(user.id)
    _check_pin(user, payload.pin)

    access_token, refresh_token, _ = _issue_session(db, response, user)
    await _announce_arrival(db, user)

    ip_address = request.client.host if request else None
    await AuditLogger.log(
        db, user.id, "login", "user", user.id,
        ip_address=ip_address,
        changes={"method": "phone_otp+two_step"},
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=user,
    )


def _token_row_for(db: Session, payload: dict) -> Optional[Token]:
    """La ligne de session derrière ce jeton, si elle existe.

    Un jeton sans `jti` (émis avant que la révocation existe) n'en a
    aucune : il reste valable jusqu'à son échéance naturelle, comme le
    documente `_reject_if_revoked`."""
    jti = payload.get("jti")
    if not jti:
        return None
    return db.query(Token).filter(Token.jti == jti).first()


def _refresh_row_is_usable(db: Session, row: Optional[Token], request: Request) -> bool:
    """Ce jeton peut-il encore être échangé ?

    Trois cas, et la nuance porte tout :

    - **jamais échangé** → oui, c'est le cas courant ;
    - **échangé il y a moins d'une minute, grâce intacte** → oui, une fois.
      C'est très probablement un client dont la réponse s'est perdue : il
      redemande avec le seul jeton qu'il ait jamais eu. Le refuser
      détruirait une session que rien ne justifie de détruire ;
    - **le reste** → non. Révoqué à la déconnexion, révoqué avec un
      appareil, ou rejoué au-delà de la fenêtre.

    Le rejeu est JOURNALISÉ : c'est le seul signal qui distingue un réseau
    capricieux d'un jeton qui circule là où il ne devrait pas.
    """
    if row is None:
        # Pas de ligne : soit un jeton sans jti (hérité, non révocable),
        # soit une session dont la ligne a disparu. `_reject_if_revoked`
        # refuse déjà le second cas ; ici on laisse passer le premier.
        return True

    if row.revoked_at is None:
        return True

    if row.grace_used_at is not None:
        logger.warning(
            "[Auth] Rejeu d'un jeton de rafraîchissement dont la grâce est "
            "déjà consommée — utilisateur %s, session %s",
            row.user_id, row.jti,
        )
        return False

    rotated = row.rotated_at
    if rotated is None or datetime.utcnow() - rotated > REFRESH_GRACE:
        logger.warning(
            "[Auth] Jeton de rafraîchissement révoqué présenté hors fenêtre "
            "de grâce — utilisateur %s, session %s",
            row.user_id, row.jti,
        )
        return False

    logger.info(
        "[Auth] Rotation rejouée dans la fenêtre de grâce — utilisateur %s, "
        "session %s, depuis %s",
        row.user_id, row.jti,
        request.client.host if request and request.client else "inconnu",
    )
    return True


@router.post("/refresh", response_model=TokenSchema, responses={
    401: {"model": ErrorResponse},
    403: {"model": ErrorResponse}
})
async def refresh_access_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_db)
):
    """
    Refresh access token using refresh token.

    **Header**: Authorization: Bearer {refresh_token}

    Returns new access and refresh tokens.

    **Security notes:**
    - Refresh token rotation: old refresh token becomes invalid (its jti is
      revoked, so it can't be replayed even if it were somehow reused)
    """

    # Get token from header
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )

    token = auth_header.split(" ")[1]

    # Verify refresh token
    #
    # La signature et l'échéance d'abord — un jeton illisible ou périmé est
    # refusé quoi qu'il arrive. La révocation ensuite, et c'est là que la
    # fenêtre de grâce intervient : un jeton qui vient d'être échangé n'est
    # pas forcément un jeton volé, c'est le plus souvent un client dont la
    # réponse s'est perdue.
    try:
        payload = verify_token(token, "refresh")
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid refresh token"
        )

    presente = _token_row_for(db, payload)
    if not _refresh_row_is_usable(db, presente, request):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid refresh token"
        )

    # `sub` is email OR phone OR the user id itself (see _issue_session) —
    # `user_id` is the one field that reliably identifies the account
    # regardless of which auth method it was created with.
    user = db.query(User).filter(User.id == payload.get("user_id")).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not found"
        )

    # Rotation : l'ancien est révoqué avant que le nouveau soit émis, pour
    # qu'il ne puisse pas servir deux fois — sauf dans la fenêtre de grâce,
    # et une seule fois, ce que `_refresh_row_is_usable` a déjà tranché.
    maintenant = datetime.utcnow()
    if presente is not None:
        if presente.revoked_at is None:
            presente.revoked_at = maintenant
            presente.rotated_at = maintenant
        else:
            # ── Rejeu dans la fenêtre de grâce : le MÊME successeur ─────────
            #
            # Il révoquait le successeur et en émettait un troisième. Or le
            # cas courant n'est pas « la réponse s'est perdue » mais deux
            # rafraîchissements CONCURRENTS du même appareil, partis avec le
            # même jeton à quelques millisecondes d'écart. Le premier
            # recevait la session B, le second révoquait B et recevait C :
            # selon l'ordre d'arrivée des réponses, l'appareil gardait B —
            # révoquée — et toutes ses requêtes tombaient en 401, puis son
            # rafraîchissement suivant en 403. Déconnecté, sans rien avoir
            # fait (journal de prod du 2026-10-02, utilisateur 8).
            #
            # Les deux réponses désignent désormais la même session B : quel
            # que soit l'ordre, l'appareil converge. Ce n'est pas plus
            # permissif qu'avant — la grâce reste unique et limitée à une
            # minute, et elle donnait déjà une session valide.
            presente.grace_used_at = maintenant
            successeur = (
                db.query(Token)
                .filter(Token.jti == presente.replaced_by_jti, Token.revoked_at.is_(None))
                .first()
                if presente.replaced_by_jti
                else None
            )
            if successeur is None:
                db.commit()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Invalid refresh token",
                )
            db.commit()
            sujet = user.email or user.phone or str(user.id)
            jeton_acces = create_access_token({"sub": sujet, "user_id": user.id}, jti=successeur.jti)
            jeton_rafraichissement = create_refresh_token({"sub": sujet, "user_id": user.id}, jti=successeur.jti)
            _set_access_token_cookie(response, jeton_acces)
            return TokenSchema(
                access_token=jeton_acces,
                refresh_token=jeton_rafraichissement,
                expires_in=settings.access_token_expire_minutes * 60,
            )
        db.commit()

    # Create new tokens (refresh token rotation)
    new_access_token, new_refresh_token, nouveau_jti = _issue_session(db, response, user)
    if presente is not None:
        presente.replaced_by_jti = nouveau_jti
        # ── L'APPAREIL suit sa session ───────────────────────────────────
        #
        # `DeviceToken.session_jti` rattache un téléphone à la session qui
        # l'a enregistré, et c'est ce lien que « révoquer cet appareil »
        # utilise pour couper sa session (voir routes/devices.py).
        #
        # Il était posé UNE fois, à l'enregistrement, et jamais reporté. Au
        # premier rafraîchissement — c'est-à-dire au bout de trente minutes —
        # il désignait un jeton déjà révoqué, pendant que la vraie session
        # continuait sous un autre `jti`. Révoquer un téléphone perdu
        # révoquait donc quelque chose de mort, et laissait la porte ouverte.
        #
        # Le défaut était invisible tant que la session expirait d'elle-même
        # au bout de sept jours. Il ne l'est plus : une session qui ne périme
        # plus n'a que la révocation pour la fermer, et il faut donc qu'elle
        # ferme la bonne.
        if presente.jti:
            db.query(DeviceToken).filter(
                DeviceToken.session_jti == presente.jti
            ).update({"session_jti": nouveau_jti}, synchronize_session=False)
        db.commit()

    # Audit log token refresh
    ip_address = request.client.host if request else None
    await AuditLogger.log(
        db, user.id, "token_refresh", "user", user.id, ip_address=ip_address
    )

    return TokenSchema(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.access_token_expire_minutes * 60
    )


@router.post("/logout")
async def logout(
    response: Response,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
    request: Request = None,
):
    """Revoke every active session (Token row) for the current user and
    clear the admin-only httpOnly cookie. Authenticates via the same
    header-or-cookie flow as every other endpoint (see get_current_user)."""
    user_id = current_user["user_id"]

    db.query(Token).filter(
        Token.user_id == user_id, Token.revoked_at.is_(None)
    ).update({"revoked_at": datetime.utcnow()})
    db.commit()

    response.delete_cookie(ACCESS_TOKEN_COOKIE_NAME, path="/")

    ip_address = request.client.host if request else None
    await AuditLogger.log(db, user_id, "logout", "user", user_id, ip_address=ip_address)

    return {"success": True}


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user information."""
    
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return user


@router.patch("/me", response_model=UserResponse)
async def update_current_user_info(
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update the current user's own profile (full name only)."""

    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if "full_name" in payload:
        user.full_name = (payload.get("full_name") or "").strip() or None

    db.commit()
    db.refresh(user)
    return user


#: Version des conditions d'utilisation acceptées. À changer quand le texte
#: change : `needs_onboarding` redevient vrai et l'écran est présenté de
#: nouveau à la prochaine connexion.
TERMS_VERSION = "2026-10"


@router.post("/me/consents", response_model=UserResponse)
async def record_consents(
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Les conditions, l'âge et les deux consentements DISTINCTS (section 8.1).

    Les conditions et l'âge sont obligatoires pour utiliser Pokou ; les
    statistiques et les communications marketing sont facultatives et
    révocables, chacune séparément — un consentement groupé ne vaut pas
    consentement au sens des lois togolaise et ivoirienne sur les données.
    """
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    now = datetime.utcnow()
    if "accept_terms" in payload:
        if payload.get("accept_terms") is not True or payload.get("age_confirmed") is not True:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Les conditions et l'âge requis doivent être acceptés.",
            )
        user.terms_accepted_at = now
        user.terms_version = TERMS_VERSION
        user.age_confirmed_at = now
    if "consent_analytics" in payload:
        user.consent_analytics = bool(payload.get("consent_analytics"))
    if "consent_marketing" in payload:
        user.consent_marketing = bool(payload.get("consent_marketing"))
    db.commit()
    db.refresh(user)
    return user
