"""Spark — l'intention, le flux, le swipe, la Salle d'Entrée, le Wingman.

Les rendez-vous payés et la sécurité vivent dans `spark_dates.py` : ce sont
les deux endroits où de l'argent et l'intégrité physique de quelqu'un sont en
jeu, et les mélanger au flux rendrait les deux plus difficiles à relire.
"""
from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import MediaAsset, SparkIntent, SparkLike, SparkMatch, SparkPass, SparkPhoto, SparkProfile, SparkRoomMessage, SparkWingmanVote, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.services.modules import spark_rules as rules
from app.core.security import get_current_user

router = APIRouter(prefix="/spark", tags=["Pokou Spark"])

MODULE_SLUG = "spark"

GENDERS = {"F", "M", "AUTRE"}
STICKERS = {
    "feu", "coeur", "rire", "surprise", "pouce", "danse", "salut", "cool",
}


# ─── Schémas ─────────────────────────────────────────────────────────────────


class ProfileUpsert(BaseModel):
    display_name: str = Field(..., min_length=2, max_length=60)
    bio: str | None = Field(None, max_length=300)
    birth_date: date
    gender: str
    is_visible: bool = True


class LocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)


class PhotoAdd(BaseModel):
    media_asset_id: int


class IntentCreate(BaseModel):
    kind: str


class LikeCreate(BaseModel):
    kind: str = Field("LIKE", pattern="^(LIKE|SUPER)$")
    #: Le vocal de cinq secondes d'un Super Spark.
    voice_media_id: int | None = None


class RoomMessageCreate(BaseModel):
    kind: str = Field(..., pattern="^(VOICE|STICKER)$")
    media_asset_id: int | None = None
    sticker: str | None = None


class WingmanRequest(BaseModel):
    friend_ids: list[int] = Field(..., min_length=1, max_length=rules.MAX_WINGMEN)


class WingmanVote(BaseModel):
    vote: str = Field(..., pattern="^(GREEN|RED)$")


class LikePackPurchase(BaseModel):
    size: int


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _profile(db: Session, user_id: int) -> SparkProfile:
    profile = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
    if profile is None:
        raise HTTPException(status_code=404, detail="Créez d'abord votre fiche Spark")
    return profile


def _live_intent(db: Session, user_id: int, now: datetime) -> SparkIntent | None:
    return (
        db.query(SparkIntent)
        .filter(SparkIntent.user_id == user_id, SparkIntent.expires_at > now)
        .order_by(SparkIntent.created_at.desc())
        .first()
    )


def _ordered(a: int, b: int) -> tuple[int, int]:
    return (a, b) if a < b else (b, a)


def _photo_payload(profile: SparkProfile) -> list[dict]:
    return [
        {
            "id": photo.id,
            "media": {
                "id": photo.media.id,
                "mime_type": photo.media.mime_type,
                "size_bytes": photo.media.size_bytes,
                "original_filename": photo.media.original_filename,
            } if photo.media else None,
        }
        for photo in profile.photos
    ]


def _card(profile: SparkProfile, *, intent: str, distance: float | None, today: date) -> dict:
    """Une carte du flux.

    Ne porte NI le nom Pokou, NI le numéro de la personne — seulement ce
    qu'elle a mis sur sa fiche Spark. C'est ce qui permet d'ouvrir Spark sans
    exposer son compte de messagerie.
    """
    return {
        "user_id": profile.user_id,
        "display_name": profile.display_name,
        "bio": profile.bio,
        "age": rules.age_on(profile.birth_date, today),
        "gender": profile.gender,
        "karma": profile.karma,
        "intent": intent,
        "intent_label": rules.INTENTS.get(intent, intent),
        "distance_km": round(distance, 1) if distance is not None else None,
        "photos": _photo_payload(profile),
    }


def _profile_payload(profile: SparkProfile, *, now: datetime) -> dict:
    allowance = rules.like_allowance(
        gender=profile.gender,
        free_day=profile.free_likes_day,
        free_used=profile.free_likes_used,
        balance=profile.likes_balance,
        today=now.date(),
    )
    _, views_left = rules.view_allowance(
        plus_until=profile.plus_until,
        views_day=profile.views_day,
        views_used=profile.views_used,
        now=now,
    )
    return {
        "display_name": profile.display_name,
        "bio": profile.bio,
        "birth_date": profile.birth_date.isoformat(),
        "age": rules.age_on(profile.birth_date, now.date()),
        "gender": profile.gender,
        "is_visible": profile.is_visible,
        "karma": profile.karma,
        "can_invite": rules.can_invite(profile.karma),
        "likes_left": allowance.free_left,
        "likes_balance": profile.likes_balance,
        "views_left": views_left,
        "has_plus": profile.plus_until is not None and profile.plus_until > now,
        "plus_until": profile.plus_until.isoformat() if profile.plus_until else None,
        "can_see_likers": profile.see_likers_until is not None and profile.see_likers_until > now,
        "is_boosted": profile.boost_until is not None and profile.boost_until > now,
        "location_is_fresh": rules.location_is_fresh(profile.location_updated_at, now),
        "photos": _photo_payload(profile),
    }


# ─── La fiche ────────────────────────────────────────────────────────────────


@router.put("/profile")
async def upsert_profile(
    payload: ProfileUpsert,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Crée ou met à jour ma fiche Spark.

    La date de naissance n'est modifiable qu'à la CRÉATION. La laisser
    éditable reviendrait à laisser quelqu'un contourner la vérification d'âge
    après coup, en s'inscrivant majeur puis en corrigeant.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()

    if payload.gender not in GENDERS:
        raise HTTPException(status_code=400, detail="Genre inconnu")

    profile = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
    if profile is None:
        if not rules.is_adult(payload.birth_date, now.date()):
            raise HTTPException(
                status_code=403,
                detail=f"Spark est réservé aux {rules.MINIMUM_AGE} ans et plus",
            )
        profile = SparkProfile(
            user_id=user_id,
            birth_date=payload.birth_date,
            gender=payload.gender,
            karma=rules.KARMA_START,
        )
        db.add(profile)
    elif payload.birth_date != profile.birth_date:
        raise HTTPException(
            status_code=409,
            detail="La date de naissance ne peut plus être modifiée. Contactez l'équipe.",
        )

    profile.display_name = payload.display_name.strip()
    profile.bio = (payload.bio or "").strip() or None
    profile.is_visible = payload.is_visible
    db.commit()
    db.refresh(profile)
    return _profile_payload(profile, now=now)


@router.get("/profile")
async def my_profile(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    profile = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
    if profile is None:
        return {"profile": None}
    return {"profile": _profile_payload(profile, now=datetime.utcnow())}


@router.post("/profile/location")
async def update_location(
    payload: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ma position, horodatée.

    Horodatée parce qu'une position sans date ne vaut rien : c'est elle qui
    permet d'écarter du flux quelqu'un dont le dernier relevé date d'hier.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    profile = _profile(db, user_id)
    profile.latitude = payload.latitude
    profile.longitude = payload.longitude
    profile.location_updated_at = datetime.utcnow()
    db.commit()
    return {"ok": True}


@router.post("/photos")
async def add_photo(
    payload: PhotoAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    profile = _profile(db, user_id)
    media = (
        db.query(MediaAsset)
        .filter(MediaAsset.id == payload.media_asset_id, MediaAsset.uploader_id == user_id)
        .first()
    )
    # Sans ce contrôle, on publierait la photo de quelqu'un d'autre en citant
    # son identifiant — ce qui, sur une application de rencontres, est
    # exactement comment on fabrique un faux profil.
    if media is None:
        raise HTTPException(status_code=404, detail="Photo introuvable")
    if len(profile.photos) >= 6:
        raise HTTPException(status_code=409, detail="Six photos au maximum")

    photo = SparkPhoto(
        profile_id=profile.id,
        media_asset_id=media.id,
        position=len(profile.photos),
    )
    db.add(photo)
    db.commit()
    db.refresh(profile)
    return {"photos": _photo_payload(profile)}


@router.delete("/photos/{photo_id}")
async def remove_photo(
    photo_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    profile = _profile(db, user_id)
    photo = (
        db.query(SparkPhoto)
        .filter(SparkPhoto.id == photo_id, SparkPhoto.profile_id == profile.id)
        .first()
    )
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo introuvable")
    db.delete(photo)
    db.commit()
    db.refresh(profile)
    return {"photos": _photo_payload(profile)}


# ─── La Carte du Moment ──────────────────────────────────────────────────────


@router.get("/intents")
async def list_intents():
    """Les quatre intentions, libellées par le serveur.

    Par le serveur, pour que la liste puisse changer sans qu'une version
    ancienne de l'application affiche une intention qui n'existe plus.
    """
    return {"items": [{"kind": kind, "label": label} for kind, label in rules.INTENTS.items()]}


@router.post("/intent")
async def set_intent(
    payload: IntentCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Déclare ce que je cherche aujourd'hui. Vingt-quatre heures, puis ça meurt."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    _profile(db, user_id)
    kind = payload.kind.upper()
    if kind not in rules.INTENTS:
        raise HTTPException(status_code=400, detail="Intention inconnue")

    now = datetime.utcnow()
    # La PRÉCÉDENTE s'éteint tout de suite. Sans ça, celle de ce matin reste
    # vivante vingt-quatre heures et continue de nous afficher dans son flux :
    # quelqu'un qui a dit « after maquis » à 2 h et « sérieux » au réveil
    # resterait proposé aux deux, ce qui est exactement le désaccord de fond
    # que ce module existe pour supprimer.
    #
    # Éteinte, pas effacée : `expires_at` devient la date où l'intention a
    # cessé d'être vraie, qu'elle ait expiré d'elle-même ou été remplacée.
    # Ce qui a été cherché, et quand, reste lisible.
    (
        db.query(SparkIntent)
        .filter(SparkIntent.user_id == user_id, SparkIntent.expires_at > now)
        .update({SparkIntent.expires_at: now}, synchronize_session=False)
    )

    intent = SparkIntent(user_id=user_id, kind=kind, expires_at=rules.intent_expiry(now))
    db.add(intent)
    db.commit()
    db.refresh(intent)
    return {
        "kind": intent.kind,
        "label": rules.INTENTS[intent.kind],
        "expires_at": intent.expires_at.isoformat(),
        "seconds_left": int((intent.expires_at - now).total_seconds()),
    }


@router.get("/intent")
async def current_intent(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    intent = _live_intent(db, user_id, now)
    if intent is None:
        return {"intent": None}
    return {
        "intent": {
            "kind": intent.kind,
            "label": rules.INTENTS.get(intent.kind, intent.kind),
            "expires_at": intent.expires_at.isoformat(),
            "seconds_left": int((intent.expires_at - now).total_seconds()),
        }
    }


# ─── Le flux ─────────────────────────────────────────────────────────────────


@router.get("/feed")
async def feed(
    limit: int = Query(20, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Qui cherche la même chose que moi, à moins de 5 km, maintenant.

    Quatre filtres, et chacun retire un problème :
    l'INTENTION supprime le désaccord de fond avant qu'il n'existe ; la
    DISTANCE rend le rendez-vous possible ce soir ; la FRAÎCHEUR de la
    position empêche d'annoncer « à 2 km » d'après un relevé d'hier ; l'ÂGE
    est vérifié à l'affichage et pas seulement à l'inscription.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    today = now.date()
    me = _profile(db, user_id)

    intent = _live_intent(db, user_id, now)
    if intent is None:
        return {
            "items": [],
            "needs_intent": True,
            "message": "Choisissez d'abord ce que vous cherchez aujourd'hui.",
        }
    if me.latitude is None or not rules.location_is_fresh(me.location_updated_at, now):
        return {
            "items": [],
            "needs_location": True,
            "message": "Activez votre position pour voir qui est autour de vous.",
        }

    allowed, views_left = rules.view_allowance(
        plus_until=me.plus_until, views_day=me.views_day, views_used=me.views_used, now=now
    )
    if not allowed:
        return {
            "items": [],
            "quota_reached": True,
            "message": f"Vous avez vu vos {rules.FREE_VIEWS_PER_DAY} profils du jour.",
        }

    # Les intentions vivantes du même type, sauf la mienne.
    peer_ids = {
        row[0]
        for row in db.query(SparkIntent.user_id).filter(
            SparkIntent.kind == intent.kind,
            SparkIntent.expires_at > now,
            SparkIntent.user_id != user_id,
        )
    }
    if not peer_ids:
        return {"items": [], "views_left": views_left}

    # Déjà tranchés : ni re-liker, ni revoir demain ce qu'on a écarté.
    seen = {row[0] for row in db.query(SparkLike.to_user_id).filter(SparkLike.from_user_id == user_id)}
    seen |= {row[0] for row in db.query(SparkPass.to_user_id).filter(SparkPass.from_user_id == user_id)}
    candidates = peer_ids - seen
    if not candidates:
        return {"items": [], "views_left": views_left}

    profiles = (
        db.query(SparkProfile)
        .filter(SparkProfile.user_id.in_(candidates), SparkProfile.is_visible.is_(True))
        .all()
    )

    cards = []
    for profile in profiles:
        if profile.latitude is None or not rules.location_is_fresh(profile.location_updated_at, now):
            continue
        # L'âge est revérifié ICI. Une vérification qui n'a lieu qu'à
        # l'inscription ne protège que le jour de l'inscription.
        if not rules.is_adult(profile.birth_date, today):
            continue
        km = rules.distance_km(me.latitude, me.longitude, profile.latitude, profile.longitude)
        if km > rules.MATCH_RADIUS_KM:
            continue
        cards.append((profile, km))

    # Les profils boostés d'abord, puis les plus proches. Un boost déplace
    # dans la file, il n'ouvre jamais le périmètre : payer ne doit pas faire
    # apparaître quelqu'un à 40 km.
    cards.sort(key=lambda pair: (
        not (pair[0].boost_until is not None and pair[0].boost_until > now),
        pair[1],
    ))
    page = cards[:limit]

    # L'ordre compte : lire le compteur AVANT de redater la ligne. En
    # redatant d'abord, la comparaison est toujours vraie et le quota ne se
    # remet jamais à zéro — un compteur qui ne repart pas est un quota
    # épuisé pour toujours.
    used_today = me.views_used if me.views_day == today else 0
    me.views_day = today
    me.views_used = used_today + len(page)
    db.commit()

    return {
        "items": [
            _card(profile, intent=intent.kind, distance=km, today=today)
            for profile, km in page
        ],
        "views_left": views_left,
        "intent": intent.kind,
    }


# ─── Le swipe ────────────────────────────────────────────────────────────────


def _create_match(db: Session, a: int, b: int, now: datetime) -> SparkMatch:
    low, high = _ordered(a, b)
    match = SparkMatch(
        low_user_id=low,
        high_user_id=high,
        room_expires_at=now + rules.ROOM_DURATION,
        status="ROOM",
    )
    db.add(match)
    db.flush()
    return match


@router.post("/like/{target_id}")
async def like(
    target_id: int,
    payload: LikeCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Un like. Gratuit tant qu'il reste du quota, sinon puisé dans le solde.

    Le Super Spark n'est PAS accordé ici : il se paie, et son effet est posé à
    la confirmation. Un vocal envoyé avant paiement serait un Super Spark
    gratuit pour qui abandonne à l'écran de la passerelle.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    if target_id == user_id:
        raise HTTPException(status_code=400, detail="Destinataire invalide")
    now = datetime.utcnow()
    me = _profile(db, user_id)
    target = db.query(SparkProfile).filter(SparkProfile.user_id == target_id).first()
    if target is None:
        raise HTTPException(status_code=404, detail="Profil introuvable")

    existing = (
        db.query(SparkLike)
        .filter(SparkLike.from_user_id == user_id, SparkLike.to_user_id == target_id)
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="Vous avez déjà liké ce profil")

    if payload.kind == "SUPER":
        if payload.voice_media_id is None:
            raise HTTPException(status_code=400, detail="Un Super Spark porte un vocal")
        voice = (
            db.query(MediaAsset)
            .filter(
                MediaAsset.id == payload.voice_media_id,
                MediaAsset.uploader_id == user_id,
            )
            .first()
        )
        if voice is None:
            raise HTTPException(status_code=404, detail="Vocal introuvable")
        payment = open_payment(
            db, user_id,
            kind="SPARK_SUPER",
            amount=rules.SUPER_SPARK_PRICE,
            description="Spark — un Super Spark",
            metadata={
                "module": MODULE_SLUG,
                "action": "super",
                "target_id": target_id,
                "voice_media_id": voice.id,
            },
        )
        db.commit()
        return {"pending_payment": True, **payment_json(payment)}

    allowance = rules.like_allowance(
        gender=me.gender,
        free_day=me.free_likes_day,
        free_used=me.free_likes_used,
        balance=me.likes_balance,
        today=now.date(),
    )
    if not allowance.allowed:
        raise HTTPException(status_code=402, detail=allowance.reason)

    if allowance.source == "free":
        if me.free_likes_day != now.date():
            me.free_likes_day = now.date()
            me.free_likes_used = 0
        me.free_likes_used += 1
    elif allowance.source == "balance":
        me.likes_balance -= 1

    db.add(SparkLike(from_user_id=user_id, to_user_id=target_id, kind="LIKE"))
    db.flush()

    match = _match_if_mutual(db, user_id, target_id, now)
    db.commit()
    return {
        "liked": True,
        "matched": match is not None,
        "match_id": match.id if match else None,
        # -1 signifie « sans limite » et doit le rester : le décrémenter
        # afficherait « -2 likes » à quelqu'un qui n'en manque jamais.
        "likes_left": (
            allowance.free_left - 1 if allowance.source == "free" else allowance.free_left
        ),
        "likes_balance": me.likes_balance,
    }


def _match_if_mutual(db: Session, user_id: int, target_id: int, now: datetime) -> SparkMatch | None:
    """Crée le match si l'autre avait déjà liké — et seulement alors."""
    reciprocal = (
        db.query(SparkLike)
        .filter(SparkLike.from_user_id == target_id, SparkLike.to_user_id == user_id)
        .first()
    )
    if reciprocal is None:
        return None
    low, high = _ordered(user_id, target_id)
    already = (
        db.query(SparkMatch)
        .filter(SparkMatch.low_user_id == low, SparkMatch.high_user_id == high)
        .first()
    )
    if already is not None:
        return already
    return _create_match(db, user_id, target_id, now)


@router.post("/pass/{target_id}")
async def pass_profile(
    target_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Écarter un profil. Gratuit, et définitif pour le flux."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    existing = (
        db.query(SparkPass)
        .filter(SparkPass.from_user_id == user_id, SparkPass.to_user_id == target_id)
        .first()
    )
    if existing is None:
        db.add(SparkPass(from_user_id=user_id, to_user_id=target_id))
        db.commit()
    return {"ok": True}


@router.get("/likers")
async def likers(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Qui m'a liké. Payant, sauf pour les abonnés.

    Le NOMBRE est toujours donné, même sans abonnement : cacher jusqu'à
    l'existence des likes rendrait l'offre invérifiable — on paierait sans
    savoir s'il y a quelque chose à voir.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    me = _profile(db, user_id)

    rows = db.query(SparkLike).filter(SparkLike.to_user_id == user_id).all()
    unlocked = (me.see_likers_until is not None and me.see_likers_until > now) or (
        me.plus_until is not None and me.plus_until > now
    )
    if not unlocked:
        return {"count": len(rows), "locked": True, "items": []}

    profiles = {
        profile.user_id: profile
        for profile in db.query(SparkProfile).filter(
            SparkProfile.user_id.in_({row.from_user_id for row in rows} or {-1})
        )
    }
    today = now.date()
    return {
        "count": len(rows),
        "locked": False,
        "items": [
            {
                **_card(profiles[row.from_user_id], intent="", distance=None, today=today),
                "kind": row.kind,
                "at": row.created_at.isoformat(),
            }
            for row in rows
            if row.from_user_id in profiles
        ],
    }


# ─── La Salle d'Entrée ───────────────────────────────────────────────────────


def _match_of(db: Session, match_id: int, user_id: int) -> SparkMatch:
    match = (
        db.query(SparkMatch)
        .filter(
            SparkMatch.id == match_id,
            or_(SparkMatch.low_user_id == user_id, SparkMatch.high_user_id == user_id),
        )
        .first()
    )
    if match is None:
        raise HTTPException(status_code=404, detail="Match introuvable")
    return match


def _resolve_if_expired(db: Session, match: SparkMatch, now: datetime) -> SparkMatch:
    """Referme la salle dont le temps est écoulé.

    À la LECTURE, et non par une tâche de fond : une salle dont la fermeture
    dépend d'un ordonnanceur reste ouverte le jour où l'ordonnanceur tombe, et
    c'est précisément le compte à rebours qui fait tout le produit.
    """
    if match.status != "ROOM" or match.room_expires_at > now:
        return match

    outcome = rules.resolve_room(
        low_continued=match.low_continued_at is not None,
        high_continued=match.high_continued_at is not None,
    )
    match.status = outcome.status
    match.resolved_at = now
    if outcome.karma_penalty_for is not None:
        loser_id = (
            match.high_user_id if outcome.karma_penalty_for == "high" else match.low_user_id
        )
        loser = db.query(SparkProfile).filter(SparkProfile.user_id == loser_id).first()
        if loser is not None:
            loser.karma = rules.apply_karma(loser.karma, rules.KARMA_ROOM_IGNORED)
    db.commit()
    return match


def _match_payload(db: Session, match: SparkMatch, user_id: int, now: datetime) -> dict:
    peer_id = match.high_user_id if match.low_user_id == user_id else match.low_user_id
    peer = db.query(SparkProfile).filter(SparkProfile.user_id == peer_id).first()
    i_am_low = match.low_user_id == user_id
    mine_continued = (match.low_continued_at if i_am_low else match.high_continued_at) is not None
    peer_continued = (match.high_continued_at if i_am_low else match.low_continued_at) is not None

    return {
        "id": match.id,
        "status": match.status,
        "peer": _card(peer, intent="", distance=None, today=now.date()) if peer else None,
        "room_seconds_left": rules.room_seconds_left(match.room_expires_at, now),
        "extensions": match.extensions,
        "can_extend": rules.can_extend(match.extensions),
        "extension_price": rules.ROOM_EXTENSION_PRICE,
        "i_continued": mine_continued,
        # On ne dit PAS si l'autre a déjà appuyé tant que la salle est
        # ouverte : le savoir transformerait « veux-tu continuer ? » en
        # « oseras-tu refuser ? ».
        "peer_continued": peer_continued if match.status != "ROOM" else None,
        "created_at": match.created_at.isoformat(),
    }


@router.get("/matches")
async def matches(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    rows = (
        db.query(SparkMatch)
        .filter(
            or_(SparkMatch.low_user_id == user_id, SparkMatch.high_user_id == user_id),
            SparkMatch.status.in_(["ROOM", "CONTINUED", "SAVED"]),
        )
        .order_by(SparkMatch.created_at.desc())
        .limit(50)
        .all()
    )
    rows = [_resolve_if_expired(db, match, now) for match in rows]
    return {
        "items": [
            _match_payload(db, match, user_id, now)
            for match in rows
            if match.status in {"ROOM", "CONTINUED", "SAVED"}
        ]
    }


@router.get("/matches/{match_id}")
async def match_detail(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    match = _resolve_if_expired(db, _match_of(db, match_id, user_id), now)

    messages = (
        db.query(SparkRoomMessage)
        .filter(SparkRoomMessage.match_id == match.id)
        .order_by(SparkRoomMessage.created_at)
        .all()
    )
    return {
        **_match_payload(db, match, user_id, now),
        "messages": [
            {
                "id": message.id,
                "kind": message.kind,
                "sticker": message.sticker,
                "is_mine": message.sender_id == user_id,
                "media": {
                    "id": message.media.id,
                    "mime_type": message.media.mime_type,
                    "size_bytes": message.media.size_bytes,
                    "original_filename": message.media.original_filename,
                } if message.media else None,
                "created_at": message.created_at.isoformat(),
            }
            for message in messages
        ],
    }


@router.post("/matches/{match_id}/messages")
async def send_room_message(
    match_id: int,
    payload: RoomMessageCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Un vocal ou un sticker. Le texte est refusé par le SERVEUR.

    Refusé ici et pas seulement absent de l'interface : une interdiction qui
    ne vit que dans l'écran se contourne par un appel direct, et c'est
    justement l'impossibilité du copier-coller qui fait le tri.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    match = _resolve_if_expired(db, _match_of(db, match_id, user_id), now)
    if match.status != "ROOM":
        raise HTTPException(status_code=409, detail="La salle est fermée")

    if payload.kind == "STICKER":
        if payload.sticker not in STICKERS:
            raise HTTPException(status_code=400, detail="Sticker inconnu")
        message = SparkRoomMessage(
            match_id=match.id, sender_id=user_id, kind="STICKER", sticker=payload.sticker
        )
    else:
        if payload.media_asset_id is None:
            raise HTTPException(status_code=400, detail="Vocal manquant")
        media = (
            db.query(MediaAsset)
            .filter(
                MediaAsset.id == payload.media_asset_id,
                MediaAsset.uploader_id == user_id,
            )
            .first()
        )
        if media is None:
            raise HTTPException(status_code=404, detail="Vocal introuvable")
        if not (media.mime_type or "").startswith("audio/"):
            raise HTTPException(status_code=400, detail="Seuls les vocaux sont acceptés")
        message = SparkRoomMessage(
            match_id=match.id, sender_id=user_id, kind="VOICE", media_asset_id=media.id
        )

    db.add(message)
    db.commit()
    db.refresh(message)
    return {"id": message.id, "created_at": message.created_at.isoformat()}


@router.post("/matches/{match_id}/continue")
async def continue_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """« Continuer ». Ouvre la discussion si les deux ont appuyé."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    match = _resolve_if_expired(db, _match_of(db, match_id, user_id), now)
    if match.status != "ROOM":
        raise HTTPException(status_code=409, detail="La salle est fermée")

    if match.low_user_id == user_id:
        match.low_continued_at = match.low_continued_at or now
    else:
        match.high_continued_at = match.high_continued_at or now

    if match.low_continued_at and match.high_continued_at:
        match.status = "CONTINUED"
        match.resolved_at = now
    db.commit()
    return _match_payload(db, match, user_id, now)


@router.post("/matches/{match_id}/extend")
async def extend_room(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Prolonge la salle de dix minutes. Le temps est ajouté à la CONFIRMATION."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    match = _resolve_if_expired(db, _match_of(db, match_id, user_id), now)
    if match.status != "ROOM":
        raise HTTPException(status_code=409, detail="La salle est fermée")
    if not rules.can_extend(match.extensions):
        raise HTTPException(
            status_code=409,
            detail="Cette salle a déjà été prolongée au maximum. Appuyez sur Continuer.",
        )

    payment = open_payment(
        db, user_id,
        kind="SPARK_EXTEND",
        amount=rules.ROOM_EXTENSION_PRICE,
        description="Spark — dix minutes de plus",
        metadata={"module": MODULE_SLUG, "action": "extend", "match_id": match.id},
    )
    db.commit()
    return payment_json(payment)


# ─── Le Wingman ──────────────────────────────────────────────────────────────


@router.post("/wingman/{candidate_id}")
async def ask_wingmen(
    candidate_id: int,
    payload: WingmanRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Demander l'avis de trois amis avant d'entrer dans la salle."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    if candidate_id == user_id:
        raise HTTPException(status_code=400, detail="Profil invalide")
    if db.query(SparkProfile).filter(SparkProfile.user_id == candidate_id).first() is None:
        raise HTTPException(status_code=404, detail="Profil introuvable")

    friend_ids = {fid for fid in payload.friend_ids if fid not in {user_id, candidate_id}}
    if not friend_ids:
        raise HTTPException(status_code=400, detail="Choisissez au moins un ami")
    known = {row[0] for row in db.query(User.id).filter(User.id.in_(friend_ids))}

    created = 0
    for friend_id in known:
        existing = (
            db.query(SparkWingmanVote)
            .filter(
                SparkWingmanVote.owner_id == user_id,
                SparkWingmanVote.candidate_id == candidate_id,
                SparkWingmanVote.voter_id == friend_id,
            )
            .first()
        )
        if existing is not None:
            continue
        db.add(
            SparkWingmanVote(
                owner_id=user_id, candidate_id=candidate_id, voter_id=friend_id
            )
        )
        created += 1
    db.commit()
    return {"asked": created, "total": len(known)}


@router.get("/wingman/requests")
async def wingman_requests(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les avis qu'on me demande.

    Ne requiert PAS que Spark soit activé chez le votant : on peut rendre ce
    service à un ami sans être soi-même sur Spark, et c'est exactement par là
    que le module se diffuse.
    """
    user_id = current_user["user_id"]
    rows = (
        db.query(SparkWingmanVote)
        .filter(SparkWingmanVote.voter_id == user_id, SparkWingmanVote.vote.is_(None))
        .order_by(SparkWingmanVote.created_at.desc())
        .limit(30)
        .all()
    )
    profiles = {
        profile.user_id: profile
        for profile in db.query(SparkProfile).filter(
            SparkProfile.user_id.in_({row.candidate_id for row in rows} or {-1})
        )
    }
    owners = {
        user.id: (user.full_name or "Un ami")
        for user in db.query(User).filter(User.id.in_({row.owner_id for row in rows} or {-1}))
    }
    today = datetime.utcnow().date()
    return {
        "items": [
            {
                "id": row.id,
                "asked_by": owners.get(row.owner_id, "Un ami"),
                "candidate": _card(
                    profiles[row.candidate_id], intent="", distance=None, today=today
                ),
            }
            for row in rows
            if row.candidate_id in profiles
        ]
    }


@router.post("/wingman/requests/{vote_id}")
async def cast_wingman_vote(
    vote_id: int,
    payload: WingmanVote,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    row = (
        db.query(SparkWingmanVote)
        .filter(SparkWingmanVote.id == vote_id, SparkWingmanVote.voter_id == user_id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    if row.vote is not None:
        raise HTTPException(status_code=409, detail="Vous avez déjà donné votre avis")
    row.vote = payload.vote
    row.voted_at = datetime.utcnow()
    db.commit()
    return {"ok": True}


@router.get("/wingman/{candidate_id}")
async def wingman_verdict(
    candidate_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """L'avis du groupe, agrégé — jamais qui a dit quoi."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    rows = (
        db.query(SparkWingmanVote)
        .filter(
            SparkWingmanVote.owner_id == user_id,
            SparkWingmanVote.candidate_id == candidate_id,
        )
        .all()
    )
    verdict = rules.wingman_verdict([row.vote for row in rows])
    return {
        "verdict": verdict,
        "asked": len(rows),
        "answered": sum(1 for row in rows if row.vote is not None),
        "label": {
            "GREEN": "Tes potes valident ce profil",
            "RED": "Tes potes ne le sentent pas",
            "SPLIT": "Tes potes sont partagés",
        }.get(verdict),
    }


# ─── L'économie ──────────────────────────────────────────────────────────────


@router.get("/shop")
async def shop(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce qui s'achète, et à quel prix. Dit par le serveur, une seule fois."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    return {
        "like_packs": [{"size": size, "price": price} for size, price in rules.LIKE_PACKS.items()],
        "super_spark": rules.SUPER_SPARK_PRICE,
        "room_extension": rules.ROOM_EXTENSION_PRICE,
        "plus_monthly": SPARK_PLUS_PRICE,
        "see_likers_weekly": SEE_LIKERS_PRICE,
        "boost_hour": BOOST_PRICE,
    }


SPARK_PLUS_PRICE = 2000
SPARK_PLUS_DAYS = 30
SEE_LIKERS_PRICE = 1000
SEE_LIKERS_DAYS = 7
BOOST_PRICE = 1000
BOOST_HOURS = 1


@router.post("/likes/purchase")
async def purchase_likes(
    payload: LikePackPurchase,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    _profile(db, user_id)
    price = rules.LIKE_PACKS.get(payload.size)
    if price is None:
        raise HTTPException(status_code=400, detail="Pack inconnu")
    payment = open_payment(
        db, user_id,
        kind="SPARK_LIKES",
        amount=price,
        description=f"Spark — {payload.size} likes",
        metadata={"module": MODULE_SLUG, "action": "likes", "size": payload.size},
    )
    db.commit()
    return payment_json(payment)


@router.post("/plus")
async def subscribe_plus(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    _profile(db, user_id)
    payment = open_payment(
        db, user_id,
        kind="SPARK_PLUS",
        amount=SPARK_PLUS_PRICE,
        description="Spark+ — un mois",
        metadata={"module": MODULE_SLUG, "action": "plus"},
    )
    db.commit()
    return payment_json(payment)


@router.post("/see-likers")
async def unlock_likers(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    _profile(db, user_id)
    payment = open_payment(
        db, user_id,
        kind="SPARK_LIKERS",
        amount=SEE_LIKERS_PRICE,
        description="Spark — voir qui vous a liké (7 jours)",
        metadata={"module": MODULE_SLUG, "action": "likers"},
    )
    db.commit()
    return payment_json(payment)


@router.post("/boost")
async def buy_boost(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    _profile(db, user_id)
    payment = open_payment(
        db, user_id,
        kind="SPARK_BOOST",
        amount=BOOST_PRICE,
        description="Spark — Top Profil pendant une heure",
        metadata={"module": MODULE_SLUG, "action": "boost"},
    )
    db.commit()
    return payment_json(payment)


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """Tout ce que Spark accorde, accordé ici et nulle part ailleurs."""
    metadata = payment.metadata_json or {}
    action = metadata.get("action")
    profile = db.query(SparkProfile).filter(SparkProfile.user_id == payment.user_id).first()
    if profile is None:
        return None
    now = datetime.utcnow()

    if action == "likes":
        size = int(metadata.get("size", 0))
        profile.likes_balance += size
        return {"likes_balance": profile.likes_balance}

    if action == "plus":
        # Prolonge au lieu de repartir de zéro : renouveler tôt ne doit pas
        # faire perdre les jours restants.
        start = profile.plus_until if profile.plus_until and profile.plus_until > now else now
        profile.plus_until = start + timedelta(days=SPARK_PLUS_DAYS)
        return {"plus_until": profile.plus_until.isoformat()}

    if action == "likers":
        start = (
            profile.see_likers_until
            if profile.see_likers_until and profile.see_likers_until > now
            else now
        )
        profile.see_likers_until = start + timedelta(days=SEE_LIKERS_DAYS)
        return {"see_likers_until": profile.see_likers_until.isoformat()}

    if action == "boost":
        start = profile.boost_until if profile.boost_until and profile.boost_until > now else now
        profile.boost_until = start + timedelta(hours=BOOST_HOURS)
        return {"boost_until": profile.boost_until.isoformat()}

    if action == "extend":
        match = db.query(SparkMatch).filter(SparkMatch.id == int(metadata["match_id"])).first()
        if match is None or match.status != "ROOM":
            # La salle s'est refermée pendant le paiement. On ne prolonge pas
            # une salle close, et on le DIT — l'équipe doit pouvoir retrouver
            # ce cas pour rembourser.
            return {"extended": False, "reason": "salle déjà fermée"}
        match.room_expires_at = match.room_expires_at + rules.ROOM_EXTENSION
        match.extensions += 1
        return {"extended": True, "match_id": match.id, "extensions": match.extensions}

    if action == "super":
        target_id = int(metadata["target_id"])
        existing = (
            db.query(SparkLike)
            .filter(
                SparkLike.from_user_id == payment.user_id,
                SparkLike.to_user_id == target_id,
            )
            .first()
        )
        if existing is not None:
            return {"super": False, "reason": "déjà liké"}
        db.add(
            SparkLike(
                from_user_id=payment.user_id,
                to_user_id=target_id,
                kind="SUPER",
                voice_media_id=metadata.get("voice_media_id"),
            )
        )
        db.flush()
        match = _match_if_mutual(db, payment.user_id, target_id, now)
        return {
            "super": True,
            "matched": match is not None,
            "match_id": match.id if match else None,
        }

    return None
