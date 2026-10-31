"""Les règles de Spark, sans base de données.

Ici vivent les décisions qui coûtent cher si elles se trompent : qui voit
qui, combien de likes il reste, ce qu'il advient de l'argent d'un rendez-vous
manqué. Aucune n'a besoin d'une session SQL pour être vérifiée, et les tenir
à l'écart des routes est ce qui permet à un test de les couvrir vraiment.
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from math import asin, cos, radians, sin, sqrt

# ─── La Carte du Moment ──────────────────────────────────────────────────────

#: Les quatre intentions. Un flux ne mélange JAMAIS deux intentions : quelqu'un
#: qui cherche du sérieux et quelqu'un qui sort du maquis ne se verront pas, ce
#: qui supprime le désaccord de fond avant qu'il n'existe.
INTENTS = {
    "JASE": "On jase",
    "JUS": "Un jus ce soir",
    "AFTER": "After maquis",
    "SERIEUX": "Sérieux",
}

#: Vingt-quatre heures, et c'est tout le produit. Une intention permanente
#: redevient un profil — une description de soi que personne ne relit. Une
#: intention qui meurt oblige à revenir dire ce qu'on veut, et garantit que ce
#: qu'on lit d'un autre est vrai aujourd'hui.
INTENT_TTL = timedelta(hours=24)

#: Le flux est LOCAL. Au-delà, le rendez-vous « ce soir » n'a plus de sens.
MATCH_RADIUS_KM = 5.0

#: Une position plus vieille que ça n'est plus une position. Afficher « à
#: 2 km » d'après un relevé d'avant-hier est une information fausse — et pour
#: une rencontre physique, une information fausse est un risque.
LOCATION_MAX_AGE = timedelta(hours=12)

MINIMUM_AGE = 18


def intent_expiry(now: datetime) -> datetime:
    return now + INTENT_TTL


def intent_is_live(expires_at: datetime | None, now: datetime) -> bool:
    return expires_at is not None and expires_at > now


def distance_km(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
    """Distance à vol d'oiseau, en kilomètres."""
    dlat = radians(lat_b - lat_a)
    dlon = radians(lon_b - lon_a)
    value = (
        sin(dlat / 2) ** 2
        + cos(radians(lat_a)) * cos(radians(lat_b)) * sin(dlon / 2) ** 2
    )
    return 6371 * 2 * asin(sqrt(value))


def age_on(birth_date: date, today: date) -> int:
    years = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        years -= 1
    return years


def is_adult(birth_date: date, today: date) -> bool:
    return age_on(birth_date, today) >= MINIMUM_AGE


def location_is_fresh(updated_at: datetime | None, now: datetime) -> bool:
    return updated_at is not None and (now - updated_at) <= LOCATION_MAX_AGE


# ─── Le swipe à crédit ───────────────────────────────────────────────────────

FREE_LIKES_PER_DAY = 5
SUPER_SPARK_PRICE = 500
LIKE_PACKS = {10: 200, 50: 800}

#: Consultation libre pour les abonnés, bornée pour les autres.
FREE_VIEWS_PER_DAY = 20

#: Les femmes likent sans limite. C'est un choix de produit assumé : sur ce
#: marché, le déséquilibre d'initiative est tel qu'un quota symétrique vide le
#: flux d'un côté et le sature de l'autre, et personne n'obtient de
#: rendez-vous.
UNLIMITED_LIKE_GENDERS = {"F"}


@dataclass(frozen=True)
class LikeAllowance:
    """Ce qu'il reste, et ce qu'un like va consommer."""

    allowed: bool
    #: 'free', 'balance', 'unlimited' — d'où sortirait ce like.
    source: str | None
    free_left: int
    balance: int
    reason: str | None = None


def like_allowance(
    *,
    gender: str,
    free_day: date | None,
    free_used: int,
    balance: int,
    today: date,
) -> LikeAllowance:
    """De quoi dispose quelqu'un pour liker, maintenant.

    Le quota gratuit est rattaché à un JOUR. Sans cette date, un compteur seul
    ne saurait pas s'il parle d'aujourd'hui ou de la semaine dernière — et
    c'est ainsi qu'un quota se retrouve épuisé pour toujours.
    """
    if gender in UNLIMITED_LIKE_GENDERS:
        return LikeAllowance(True, "unlimited", free_left=-1, balance=balance)

    used_today = free_used if free_day == today else 0
    free_left = max(0, FREE_LIKES_PER_DAY - used_today)
    if free_left > 0:
        return LikeAllowance(True, "free", free_left=free_left, balance=balance)
    if balance > 0:
        return LikeAllowance(True, "balance", free_left=0, balance=balance)
    return LikeAllowance(
        False, None, free_left=0, balance=0,
        reason="Vos likes du jour sont épuisés. Prenez un pack pour continuer.",
    )


def view_allowance(
    *, plus_until: datetime | None, views_day: date | None, views_used: int, now: datetime
) -> tuple[bool, int]:
    """Peut-on afficher un profil de plus ? Et combien en reste-t-il ?"""
    if plus_until is not None and plus_until > now:
        return True, -1
    used_today = views_used if views_day == now.date() else 0
    left = max(0, FREE_VIEWS_PER_DAY - used_today)
    return left > 0, left


# ─── La Salle d'Entrée ───────────────────────────────────────────────────────

ROOM_DURATION = timedelta(minutes=10)
ROOM_EXTENSION = timedelta(minutes=10)
ROOM_EXTENSION_PRICE = 300
#: Au-delà, ce n'est plus une salle d'entrée, c'est une conversation — et une
#: conversation payée au quart d'heure est exactement ce que ce module
#: prétend remplacer.
MAX_EXTENSIONS = 3


@dataclass(frozen=True)
class RoomOutcome:
    """Ce que devient un match quand le compte à rebours tombe."""

    status: str
    #: Qui perd du Karma : celui qui n'a pas répondu alors que l'autre a
    #: tendu la main. Personne si les deux se sont tus — se taire ensemble
    #: n'est pas un manque de respect, c'est un désaccord.
    karma_penalty_for: str | None = None


def resolve_room(*, low_continued: bool, high_continued: bool) -> RoomOutcome:
    if low_continued and high_continued:
        return RoomOutcome("CONTINUED")
    if low_continued:
        return RoomOutcome("SAVED", karma_penalty_for="high")
    if high_continued:
        return RoomOutcome("SAVED", karma_penalty_for="low")
    return RoomOutcome("EXPIRED")


def room_seconds_left(room_expires_at: datetime, now: datetime) -> int:
    return max(0, int((room_expires_at - now).total_seconds()))


def can_extend(extensions: int) -> bool:
    return extensions < MAX_EXTENSIONS


# ─── Le Wingman ──────────────────────────────────────────────────────────────

MAX_WINGMEN = 3


def wingman_verdict(votes: list[str]) -> str | None:
    """L'avis du groupe, agrégé.

    Rend `None` tant que personne n'a voté, et jamais le détail : montrer qui
    a voté rouge transformerait un service rendu entre amis en dispute.
    """
    cast = [vote for vote in votes if vote in {"GREEN", "RED"}]
    if not cast:
        return None
    green = sum(1 for vote in cast if vote == "GREEN")
    if green * 2 > len(cast):
        return "GREEN"
    if green * 2 < len(cast):
        return "RED"
    return "SPLIT"


# ─── Le Karma (Street Cred) ──────────────────────────────────────────────────

KARMA_START = 100
KARMA_MIN = 0
KARMA_MAX = 200

KARMA_DATE_COMPLETED = 5
KARMA_ROOM_IGNORED = -3
KARMA_NO_SHOW = -20
KARMA_LATE_CANCEL = -5

#: En dessous, on ne peut plus inviter : quelqu'un qui a posé trois lapins ne
#: doit pas pouvoir bloquer l'argent d'un quatrième.
KARMA_INVITE_FLOOR = 60


def apply_karma(current: int, delta: int) -> int:
    return max(KARMA_MIN, min(KARMA_MAX, current + delta))


def can_invite(karma: int) -> bool:
    return karma >= KARMA_INVITE_FLOOR


# ─── Le Date Pack, et son argent ─────────────────────────────────────────────

#: Commission de l'application sur un rendez-vous honoré.
PLATFORM_FEE_RATE = 0.10
#: Annuler au-delà de ce délai rend tout. En deçà, le commerçant a déjà
#: réservé : lui faire supporter l'annulation le ferait quitter le réseau.
FREE_CANCEL_WINDOW = timedelta(hours=24)
#: Part versée à la personne posée en cas de lapin.
NO_SHOW_PENALTY_RATE = 0.50
#: Un rendez-vous se valide dans cette fenêtre autour de l'heure prévue.
VALIDATION_WINDOW = timedelta(hours=6)
#: Silence des deux côtés au-delà : ni l'un ni l'autre n'a validé, on ne peut
#: rien affirmer. L'argent revient à celui qui l'a versé.
AUTO_REFUND_AFTER = timedelta(days=3)


@dataclass(frozen=True)
class Settlement:
    """Ce que devient l'argent d'un rendez-vous.

    Les montants sont des ENTIERS de francs, jamais des flottants : un
    arrondi qui se promène sur de l'argent finit toujours par manquer
    quelque part. Le reste est absorbé par la commission, qui est la seule
    part qu'on puisse rogner sans léser quelqu'un.
    """

    status: str
    refund_to_payer: int = 0
    merchant_due: int = 0
    platform_fee: int = 0
    penalty_to: str | None = None   # 'payer' | 'guest'
    penalty_amount: int = 0


def settle_cancellation(*, amount: int, scheduled_at: datetime, now: datetime) -> Settlement:
    """Une annulation, à temps ou non."""
    if scheduled_at - now >= FREE_CANCEL_WINDOW:
        return Settlement("REFUNDED", refund_to_payer=amount)
    # Trop tard : le commerçant a préparé. Il garde sa part, l'application ne
    # prend rien — se rémunérer sur un rendez-vous qui n'a pas eu lieu serait
    # indéfendable.
    return Settlement("CANCELLED", merchant_due=amount, platform_fee=0)


def settle_completed(*, amount: int) -> Settlement:
    fee = int(amount * PLATFORM_FEE_RATE)
    return Settlement("RELEASED", merchant_due=amount - fee, platform_fee=fee)


def settle_no_show(*, amount: int, absent: str) -> Settlement:
    """Quelqu'un n'est pas venu.

    La moitié va à celui qui s'est déplacé pour rien ; l'autre moitié au
    commerçant, qui a tenu la table. L'application ne prend rien : un lapin
    n'est pas un revenu.
    """
    if absent not in {"payer", "guest"}:
        raise ValueError("absent doit être 'payer' ou 'guest'")
    penalty = int(amount * NO_SHOW_PENALTY_RATE)
    wronged = "guest" if absent == "payer" else "payer"
    return Settlement(
        "PENALIZED",
        merchant_due=amount - penalty,
        platform_fee=0,
        penalty_to=wronged,
        penalty_amount=penalty,
    )


def settle_silence(*, amount: int) -> Settlement:
    """Personne n'a rien validé, et le délai est passé.

    On ne peut affirmer ni que le rendez-vous a eu lieu, ni qu'il a été
    manqué. Dans le doute, l'argent retourne à celui qui l'a versé : c'est la
    seule issue qui ne prenne rien à personne sur une simple supposition.
    """
    return Settlement("REFUNDED", refund_to_payer=amount)


def can_validate(*, scheduled_at: datetime, now: datetime) -> bool:
    return abs(now - scheduled_at) <= VALIDATION_WINDOW


# ─── La sécurité silencieuse ─────────────────────────────────────────────────

#: Le « tout va bien ? » part une demi-heure après l'heure prévue.
CHECKIN_DELAY = timedelta(minutes=30)
#: Sans réponse au bout de ce délai, le cercle est prévenu. Cinq minutes :
#: assez pour ne pas alerter quelqu'un qui pose son téléphone, trop peu pour
#: qu'un vrai problème attende.
CHECKIN_GRACE = timedelta(minutes=5)


def checkin_due_at(scheduled_at: datetime) -> datetime:
    return scheduled_at + CHECKIN_DELAY


def checkin_should_escalate(*, due_at: datetime, answered_at: datetime | None, now: datetime) -> bool:
    if answered_at is not None:
        return False
    return now >= due_at + CHECKIN_GRACE
