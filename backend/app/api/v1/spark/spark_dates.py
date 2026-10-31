"""Spark — le Date Pack, sa séquestre, et la sécurité silencieuse.

Séparé du flux parce que ce fichier tient deux choses qui ne pardonnent pas
l'à-peu-près : de l'argent qui n'appartient plus à celui qui l'a versé et pas
encore à celui qui le recevra, et l'alerte qui part quand quelqu'un ne répond
plus.

**Sur le reversement** : Pokou n'a pas de rail de virement sortant (voir VIP
Room, Social Tax). Les montants dus au commerçant, les remboursements et les
pénalités sont donc CALCULÉS et INSCRITS, pas virés. `/spark/dates/{id}` les
expose en clair sous « dû », jamais « versé ».
"""
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import SparkCheckin, SparkDate, SparkDatePack, SparkMatch, SparkProfile, SparkSafetyAlert, SparkSafetyContact, User
from app.api.v1.modules.common import open_payment, payment_json, require_module
from app.services.modules import spark_rules as rules
from app.core.security import get_current_user

router = APIRouter(prefix="/spark", tags=["Pokou Spark"])

MODULE_SLUG = "spark"


class DateBooking(BaseModel):
    match_id: int
    pack_id: int
    scheduled_at: datetime


class SafetyContactAdd(BaseModel):
    contact_user_id: int


class SafeWordTrigger(BaseModel):
    date_id: int | None = None
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)


class NoShowReport(BaseModel):
    #: Qui n'est pas venu, vu par celui qui signale. Le serveur en déduit le
    #: rôle : un client qui enverrait « payer » ou « guest » pourrait
    #: s'attribuer la pénalité.
    absent_user_id: int


def _voucher_code() -> str:
    """Un code court, lisible à voix haute, et imprévisible.

    Imprévisible parce qu'un code séquentiel se devine : il suffirait d'en
    voir un pour commander gratuitement chez le commerçant suivant.
    """
    alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # sans I, L, O, 0, 1
    return "".join(secrets.choice(alphabet) for _ in range(8))


def _pack_payload(pack: SparkDatePack) -> dict:
    return {
        "id": pack.id,
        "title": pack.title,
        "description": pack.description,
        "venue_name": pack.venue_name,
        "venue_address": pack.venue_address,
        "price": pack.price,
        "media": {
            "id": pack.image.id,
            "mime_type": pack.image.mime_type,
            "size_bytes": pack.image.size_bytes,
            "original_filename": pack.image.original_filename,
        } if pack.image else None,
    }


def _date_payload(db: Session, spark_date: SparkDate, viewer_id: int, now: datetime) -> dict:
    pack = db.query(SparkDatePack).filter(SparkDatePack.id == spark_date.pack_id).first()
    is_payer = spark_date.payer_id == viewer_id
    peer_id = spark_date.guest_id if is_payer else spark_date.payer_id
    peer = db.query(SparkProfile).filter(SparkProfile.user_id == peer_id).first()
    mine_validated = (
        spark_date.payer_validated_at if is_payer else spark_date.guest_validated_at
    )

    payload = {
        "id": spark_date.id,
        "match_id": spark_date.match_id,
        "status": spark_date.status,
        "amount": spark_date.amount,
        "scheduled_at": spark_date.scheduled_at.isoformat(),
        "is_payer": is_payer,
        # L'identifiant de l'autre, pour que le client puisse signaler SON
        # absence. Sans lui, l'écran n'a que son nom — et le serveur exige un
        # identifiant, précisément pour qu'on ne puisse pas se désigner
        # soi-même absent.
        "peer_id": peer_id,
        "peer_name": peer.display_name if peer else None,
        "pack": _pack_payload(pack) if pack else None,
        "i_validated": mine_validated is not None,
        "can_validate": (
            spark_date.status == "HELD"
            and rules.can_validate(scheduled_at=spark_date.scheduled_at, now=now)
        ),
        # Annuler sans frais reste possible tant qu'on est à plus de 24 h.
        # Le dire à l'avance évite la seule mauvaise surprise de ce module.
        "free_cancel_until": (
            spark_date.scheduled_at - rules.FREE_CANCEL_WINDOW
        ).isoformat(),
        "can_cancel_free": spark_date.scheduled_at - now >= rules.FREE_CANCEL_WINDOW,
    }
    # Le bon n'est montré qu'une fois l'argent encaissé, et seulement aux deux
    # intéressés — c'est lui qui vaut le repas.
    if spark_date.status in {"HELD", "RELEASED", "PENALIZED"} and spark_date.voucher_code:
        payload["voucher_code"] = spark_date.voucher_code
    if spark_date.settled_at:
        payload["settlement"] = {
            "merchant_due": spark_date.merchant_due,
            "platform_fee": spark_date.platform_fee,
            "penalty_amount": spark_date.penalty_amount,
            "penalty_to_me": spark_date.penalty_to_user_id == viewer_id,
            "settled_at": spark_date.settled_at.isoformat(),
            "mode": "manual",
            "note": "Les versements sont effectués par l'équipe Pokou.",
        }
    return payload


# ─── Le catalogue ────────────────────────────────────────────────────────────


@router.get("/packs")
async def list_packs(
    latitude: float | None = Query(None, ge=-90, le=90),
    longitude: float | None = Query(None, ge=-180, le=180),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Les formules disponibles, les plus proches d'abord."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    packs = (
        db.query(SparkDatePack)
        .filter(SparkDatePack.is_active.is_(True))
        .order_by(SparkDatePack.price)
        .all()
    )
    if latitude is not None and longitude is not None:
        def key(pack: SparkDatePack):
            if pack.latitude is None or pack.longitude is None:
                return (1, float("inf"), pack.price)
            return (0, rules.distance_km(latitude, longitude, pack.latitude, pack.longitude), pack.price)

        packs.sort(key=key)
    return {"items": [_pack_payload(pack) for pack in packs]}


# ─── Réserver ────────────────────────────────────────────────────────────────


@router.post("/dates")
async def book_date(
    payload: DateBooking,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Réserve un rendez-vous et ouvre le paiement.

    Rien n'est bloqué ici : le bon n'existe pas, le commerçant n'est prévenu
    de rien. La séquestre commence à la CONFIRMATION du paiement — un bon
    émis avant serait un repas gratuit.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    me = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
    if me is None:
        raise HTTPException(status_code=404, detail="Créez d'abord votre fiche Spark")
    if not rules.can_invite(me.karma):
        # Quelqu'un qui a posé des lapins ne doit pas pouvoir bloquer
        # l'argent d'un quatrième rendez-vous.
        raise HTTPException(
            status_code=403,
            detail="Votre Street Cred est trop bas pour inviter. Honorez vos prochains rendez-vous.",
        )

    match = (
        db.query(SparkMatch)
        .filter(
            SparkMatch.id == payload.match_id,
            or_(SparkMatch.low_user_id == user_id, SparkMatch.high_user_id == user_id),
        )
        .first()
    )
    if match is None:
        raise HTTPException(status_code=404, detail="Match introuvable")
    if match.status not in {"CONTINUED", "SAVED"}:
        raise HTTPException(
            status_code=409,
            detail="Terminez d'abord la salle d'entrée avec « Continuer ».",
        )

    pack = (
        db.query(SparkDatePack)
        .filter(SparkDatePack.id == payload.pack_id, SparkDatePack.is_active.is_(True))
        .first()
    )
    if pack is None:
        raise HTTPException(status_code=404, detail="Formule introuvable")
    if payload.scheduled_at <= now:
        raise HTTPException(status_code=400, detail="Choisissez une date à venir")
    if payload.scheduled_at > now + timedelta(days=30):
        raise HTTPException(status_code=400, detail="Un mois au maximum")

    guest_id = match.high_user_id if match.low_user_id == user_id else match.low_user_id
    existing = (
        db.query(SparkDate)
        .filter(
            SparkDate.match_id == match.id,
            SparkDate.status.in_(["PENDING", "HELD"]),
        )
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="Un rendez-vous est déjà en cours")

    spark_date = SparkDate(
        match_id=match.id,
        pack_id=pack.id,
        payer_id=user_id,
        guest_id=guest_id,
        amount=pack.price,
        scheduled_at=payload.scheduled_at,
        status="PENDING",
    )
    db.add(spark_date)
    db.flush()

    payment = open_payment(
        db, user_id,
        kind="SPARK_DATE",
        amount=pack.price,
        description=f"Spark — {pack.title} ({pack.venue_name})",
        metadata={"module": MODULE_SLUG, "action": "date", "date_id": spark_date.id},
    )
    spark_date.payment_id = payment.id
    db.commit()
    return {"date_id": spark_date.id, **payment_json(payment)}


@router.get("/dates")
async def my_dates(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    rows = (
        db.query(SparkDate)
        .filter(or_(SparkDate.payer_id == user_id, SparkDate.guest_id == user_id))
        .order_by(SparkDate.scheduled_at.desc())
        .limit(50)
        .all()
    )
    return {"items": [_date_payload(db, row, user_id, now) for row in rows]}


def _own_date(db: Session, date_id: int, user_id: int) -> SparkDate:
    spark_date = (
        db.query(SparkDate)
        .filter(
            SparkDate.id == date_id,
            or_(SparkDate.payer_id == user_id, SparkDate.guest_id == user_id),
        )
        .first()
    )
    if spark_date is None:
        raise HTTPException(status_code=404, detail="Rendez-vous introuvable")
    return spark_date


@router.get("/dates/{date_id}")
async def date_detail(
    date_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    return _date_payload(db, _own_date(db, date_id, user_id), user_id, datetime.utcnow())


# ─── Dénouer la séquestre ────────────────────────────────────────────────────


def _write_settlement(spark_date: SparkDate, settlement: rules.Settlement, now: datetime) -> None:
    """Inscrit le dénouement. Une seule fois, définitivement."""
    spark_date.status = settlement.status
    spark_date.merchant_due = settlement.merchant_due or None
    spark_date.platform_fee = settlement.platform_fee or None
    spark_date.penalty_amount = settlement.penalty_amount or None
    spark_date.settled_at = now


@router.post("/dates/{date_id}/validate")
async def validate_date(
    date_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """« Ça s'est bien passé ». L'argent ne bouge qu'une fois les DEUX d'accord.

    Une validation unilatérale suffirait à libérer l'argent d'un rendez-vous
    qui n'a pas eu lieu, et c'est exactement ce que la séquestre existe pour
    empêcher.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    spark_date = _own_date(db, date_id, user_id)
    if spark_date.status != "HELD":
        raise HTTPException(status_code=409, detail="Ce rendez-vous n'est pas en attente")
    if not rules.can_validate(scheduled_at=spark_date.scheduled_at, now=now):
        raise HTTPException(
            status_code=409,
            detail="La validation se fait autour de l'heure du rendez-vous.",
        )

    if spark_date.payer_id == user_id:
        spark_date.payer_validated_at = spark_date.payer_validated_at or now
    else:
        spark_date.guest_validated_at = spark_date.guest_validated_at or now

    if spark_date.payer_validated_at and spark_date.guest_validated_at:
        _write_settlement(spark_date, rules.settle_completed(amount=spark_date.amount), now)
        for participant_id in (spark_date.payer_id, spark_date.guest_id):
            profile = (
                db.query(SparkProfile).filter(SparkProfile.user_id == participant_id).first()
            )
            if profile is not None:
                profile.karma = rules.apply_karma(profile.karma, rules.KARMA_DATE_COMPLETED)
    db.commit()
    return _date_payload(db, spark_date, user_id, now)


@router.post("/dates/{date_id}/cancel")
async def cancel_date(
    date_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Annuler. Remboursé intégralement à plus de 24 h, sinon le commerçant garde."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    spark_date = _own_date(db, date_id, user_id)
    if spark_date.status not in {"PENDING", "HELD"}:
        raise HTTPException(status_code=409, detail="Ce rendez-vous est déjà dénoué")

    if spark_date.status == "PENDING":
        # Rien n'a été encaissé : il n'y a rien à rendre.
        spark_date.status = "CANCELLED"
        spark_date.settled_at = now
        db.commit()
        return _date_payload(db, spark_date, user_id, now)

    settlement = rules.settle_cancellation(
        amount=spark_date.amount, scheduled_at=spark_date.scheduled_at, now=now
    )
    _write_settlement(spark_date, settlement, now)
    if settlement.status == "CANCELLED":
        profile = db.query(SparkProfile).filter(SparkProfile.user_id == user_id).first()
        if profile is not None:
            profile.karma = rules.apply_karma(profile.karma, rules.KARMA_LATE_CANCEL)
    db.commit()
    return _date_payload(db, spark_date, user_id, now)


@router.post("/dates/{date_id}/no-show")
async def report_no_show(
    date_id: int,
    payload: NoShowReport,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Signaler que l'autre n'est pas venu.

    On ne peut signaler QUE l'autre, et le serveur en déduit le rôle. Laisser
    le client dire « le payeur est absent » permettrait à celui qui a payé de
    se désigner lui-même absent et de récupérer la moitié de sa mise.

    Ce que ça ne fait pas : constater. Un signalement reste la parole d'une
    seule personne, et le dénouement n'attend pas l'autre — c'est un choix
    assumé, parce qu'exiger l'accord de l'absent rendrait la pénalité
    inapplicable. C'est le Karma qui rattrape les signalements abusifs, et
    l'équipe qui tranche les litiges.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    spark_date = _own_date(db, date_id, user_id)
    if spark_date.status != "HELD":
        raise HTTPException(status_code=409, detail="Ce rendez-vous n'est pas en attente")
    if payload.absent_user_id == user_id:
        raise HTTPException(status_code=400, detail="Signalez l'absence de l'autre personne")
    if payload.absent_user_id not in {spark_date.payer_id, spark_date.guest_id}:
        raise HTTPException(status_code=400, detail="Cette personne n'est pas concernée")
    if now < spark_date.scheduled_at:
        raise HTTPException(
            status_code=409,
            detail="Attendez l'heure du rendez-vous avant de signaler une absence.",
        )

    absent = "payer" if payload.absent_user_id == spark_date.payer_id else "guest"
    settlement = rules.settle_no_show(amount=spark_date.amount, absent=absent)
    _write_settlement(spark_date, settlement, now)
    spark_date.penalty_to_user_id = user_id

    absent_profile = (
        db.query(SparkProfile).filter(SparkProfile.user_id == payload.absent_user_id).first()
    )
    if absent_profile is not None:
        absent_profile.karma = rules.apply_karma(absent_profile.karma, rules.KARMA_NO_SHOW)
    db.commit()
    return _date_payload(db, spark_date, user_id, now)


def apply_confirmed_payment(db: Session, payment) -> dict | None:
    """L'argent est encaissé : la séquestre commence, le bon existe.

    C'est aussi ici que naissent les check-ins de sécurité — posés À L'AVANCE
    plutôt que par une tâche de fond, pour qu'une panne d'ordonnanceur ne
    supprime pas la question « tout va bien ? ».
    """
    date_id = (payment.metadata_json or {}).get("date_id")
    if not date_id:
        return None
    spark_date = db.query(SparkDate).filter(SparkDate.id == int(date_id)).first()
    if spark_date is None or spark_date.status != "PENDING":
        return None

    spark_date.status = "HELD"
    spark_date.voucher_code = _voucher_code()

    due_at = rules.checkin_due_at(spark_date.scheduled_at)
    for participant_id in (spark_date.payer_id, spark_date.guest_id):
        db.add(
            SparkCheckin(
                date_id=spark_date.id,
                user_id=participant_id,
                due_at=due_at,
                status="PENDING",
            )
        )
    db.flush()
    return {
        "date_id": spark_date.id,
        "status": spark_date.status,
        "voucher_code": spark_date.voucher_code,
    }


# ─── Le commerçant ───────────────────────────────────────────────────────────


@router.post("/vouchers/{code}/redeem")
async def redeem_voucher(
    code: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le commerçant encaisse le bon.

    Marquer le bon ne libère PAS l'argent : ce sont les deux personnes qui
    libèrent, en validant. Un commerçant qui pourrait à la fois scanner et
    libérer serait payé pour un rendez-vous auquel personne n'est venu.
    """
    user_id = current_user["user_id"]
    spark_date = (
        db.query(SparkDate).filter(SparkDate.voucher_code == code.strip().upper()).first()
    )
    if spark_date is None:
        raise HTTPException(status_code=404, detail="Bon inconnu")
    pack = db.query(SparkDatePack).filter(SparkDatePack.id == spark_date.pack_id).first()
    if pack is None or pack.merchant_id != user_id:
        raise HTTPException(status_code=403, detail="Ce bon ne concerne pas votre établissement")
    if spark_date.status != "HELD":
        raise HTTPException(status_code=409, detail="Ce bon n'est plus valable")
    if spark_date.voucher_used_at is not None:
        raise HTTPException(status_code=409, detail="Ce bon a déjà été utilisé")

    spark_date.voucher_used_at = datetime.utcnow()
    db.commit()
    return {
        "ok": True,
        "pack": pack.title,
        "amount": spark_date.amount,
        "used_at": spark_date.voucher_used_at.isoformat(),
    }


# ─── La sécurité silencieuse ─────────────────────────────────────────────────


@router.get("/safety/contacts")
async def safety_contacts(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    rows = (
        db.query(SparkSafetyContact)
        .filter(SparkSafetyContact.user_id == user_id)
        .all()
    )
    names = {
        user.id: (user.full_name or user.phone or "Contact")
        for user in db.query(User).filter(
            User.id.in_({row.contact_user_id for row in rows} or {-1})
        )
    }
    return {
        "items": [
            {
                "id": row.id,
                "user_id": row.contact_user_id,
                "name": names.get(row.contact_user_id, "Contact"),
            }
            for row in rows
        ]
    }


@router.post("/safety/contacts")
async def add_safety_contact(
    payload: SafetyContactAdd,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ajouter quelqu'un à mon cercle de sécurité.

    Distinct des Wingmen, volontairement : demander un avis sur un profil et
    confier sa position en direct sont deux choses différentes, et les
    confondre partagerait une localisation avec quelqu'un qu'on avait
    seulement consulté.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    if payload.contact_user_id == user_id:
        raise HTTPException(status_code=400, detail="Choisissez quelqu'un d'autre")
    if db.query(User.id).filter(User.id == payload.contact_user_id).first() is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    existing = (
        db.query(SparkSafetyContact)
        .filter(
            SparkSafetyContact.user_id == user_id,
            SparkSafetyContact.contact_user_id == payload.contact_user_id,
        )
        .first()
    )
    if existing is None:
        db.add(
            SparkSafetyContact(user_id=user_id, contact_user_id=payload.contact_user_id)
        )
        db.commit()
    return {"ok": True}


@router.delete("/safety/contacts/{contact_id}")
async def remove_safety_contact(
    contact_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    row = (
        db.query(SparkSafetyContact)
        .filter(SparkSafetyContact.id == contact_id, SparkSafetyContact.user_id == user_id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Contact introuvable")
    db.delete(row)
    db.commit()
    return {"ok": True}


@router.post("/safety/alert")
async def trigger_safe_word(
    payload: SafeWordTrigger,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le Safe Word. Part sans rien afficher à l'écran.

    Répond 200 même sans cercle de sécurité configuré : un écran qui
    afficherait une erreur au moment où quelqu'un déclenche discrètement une
    alerte le mettrait en danger. L'alerte est enregistrée dans tous les cas —
    c'est la seule trace de ce qui s'est passé ce soir-là.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    alert = SparkSafetyAlert(
        user_id=user_id,
        date_id=payload.date_id,
        kind="SAFE_WORD",
        latitude=payload.latitude,
        longitude=payload.longitude,
    )
    db.add(alert)
    db.flush()

    contacts = (
        db.query(SparkSafetyContact)
        .filter(SparkSafetyContact.user_id == user_id)
        .all()
    )
    _notify_circle(db, user_id, alert, [row.contact_user_id for row in contacts])
    db.commit()
    return {"ok": True, "notified": len(contacts)}


def _notify_circle(
    db: Session, user_id: int, alert: SparkSafetyAlert, contact_ids: list[int]
) -> None:
    """Prévenir le cercle, sans jamais faire échouer l'alerte.

    La notification passe par le même chemin que le reste de l'application.
    Si elle échoue, l'alerte reste enregistrée : perdre la notification est
    grave, perdre la TRACE l'est davantage.
    """
    if not contact_ids:
        return
    try:
        from app.services.notifications.push_service import send_push

        sender = db.query(User).filter(User.id == user_id).first()
        name = (sender.full_name if sender else None) or "Un contact"
        where = (
            f"https://maps.google.com/?q={alert.latitude},{alert.longitude}"
            if alert.latitude is not None and alert.longitude is not None
            else None
        )
        for contact_id in contact_ids:
            send_push(
                db,
                contact_id,
                title="Alerte Spark",
                body=f"{name} a déclenché une alerte." + (f" Position : {where}" if where else ""),
                data={"type": "spark_safety", "alert_id": str(alert.id)},
            )
    except Exception:  # noqa: BLE001 — voir docstring
        import logging

        logging.getLogger(__name__).exception(
            "Notification du cercle de sécurité impossible (alerte %s conservée)", alert.id
        )


@router.get("/safety/checkins")
async def pending_checkins(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """« Tout va bien ? », quand c'est l'heure.

    L'escalade est évaluée à la LECTURE, comme la fermeture des salles : une
    question dont l'existence dépend d'un ordonnanceur est une question qui ne
    sera pas posée le jour où il tombe.
    """
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    now = datetime.utcnow()
    rows = (
        db.query(SparkCheckin)
        .filter(
            SparkCheckin.user_id == user_id,
            SparkCheckin.status == "PENDING",
            SparkCheckin.due_at <= now,
        )
        .all()
    )
    escalated = 0
    for row in rows:
        if rules.checkin_should_escalate(
            due_at=row.due_at, answered_at=row.answered_at, now=now
        ):
            row.status = "ESCALATED"
            alert = SparkSafetyAlert(
                user_id=user_id, date_id=row.date_id, kind="CHECKIN_MISSED"
            )
            db.add(alert)
            db.flush()
            contacts = (
                db.query(SparkSafetyContact)
                .filter(SparkSafetyContact.user_id == user_id)
                .all()
            )
            _notify_circle(db, user_id, alert, [c.contact_user_id for c in contacts])
            escalated += 1
    db.commit()

    return {
        "items": [
            {
                "id": row.id,
                "date_id": row.date_id,
                "due_at": row.due_at.isoformat(),
                "status": row.status,
            }
            for row in rows
            if row.status == "PENDING"
        ],
        "escalated": escalated,
    }


@router.post("/safety/checkins/{checkin_id}")
async def answer_checkin(
    checkin_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """« Tout va bien. » Un seul geste, et c'est fini."""
    user_id = current_user["user_id"]
    require_module(db, user_id, MODULE_SLUG)
    row = (
        db.query(SparkCheckin)
        .filter(SparkCheckin.id == checkin_id, SparkCheckin.user_id == user_id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Aucune vérification en attente")
    row.answered_at = datetime.utcnow()
    # Un « tout va bien » tardif referme le check-in mais n'efface PAS une
    # alerte déjà partie : le cercle a été prévenu, il doit pouvoir le rester.
    if row.status == "PENDING":
        row.status = "OK"
    db.commit()
    return {"ok": True, "status": row.status}
