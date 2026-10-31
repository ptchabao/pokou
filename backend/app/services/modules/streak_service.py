"""Streak Lock — la chaîne d'une conversation.

Isolé des routes parce que le calcul de jours est exactement le genre de
chose qui se trompe d'UN, et qu'une chaîne fausse d'un jour ne plante
jamais : elle fait simplement perdre à quelqu'un un compteur qu'il entretient
depuis trois mois, et il n'a aucun moyen de prouver l'erreur.
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Optional

#: Délai de grâce pour racheter une chaîne rompue.
#:
#: Court À DESSEIN. Un rachat possible une semaine plus tard ne rachète plus
#: rien — la chaîne aurait de toute façon été rompue chaque jour depuis. Dix
#: minutes, c'est le temps de voir la notification et de décider.
GRACE_PERIOD = timedelta(minutes=10)

#: Prix du rachat.
RESTORE_AMOUNT = 300


def ordered_pair(a: int, b: int) -> tuple[int, int]:
    """Range une paire dans un ordre stable.

    Sans cet ordre, la même conversation produirait DEUX lignes selon qui
    écrit le premier, et chacune compterait sa propre chaîne — deux chiffres
    différents pour la même relation, sur les deux téléphones.
    """
    return (a, b) if a < b else (b, a)


@dataclass(frozen=True)
class StreakOutcome:
    """Ce que devient une chaîne après un message."""
    current_days: int
    last_exchange_day: Optional[date]
    broke: bool


def apply_message(
    *,
    today: date,
    sender_last_day: Optional[date],
    other_last_day: Optional[date],
    current_days: int,
    last_exchange_day: Optional[date],
) -> StreakOutcome:
    """Fait avancer la chaîne, ou la rompt.

    Un jour compte quand les DEUX ont écrit — pas quand l'un a envoyé. Une
    chaîne mesure une relation ; la faire monter en écrivant dans le vide la
    viderait de son sens, et récompenserait précisément le comportement
    qu'une messagerie doit décourager.

    La rupture se constate ICI plutôt que par une tâche de fond quotidienne :
    l'ordonnanceur qui la manquerait laisserait des chaînes vivantes que
    personne n'entretient, et l'incohérence ne se verrait jamais.
    """
    del sender_last_day  # l'appelant l'a déjà inscrit avant d'appeler

    # Rupture : plus d'un jour sans échange complet.
    broke = (
        last_exchange_day is not None
        and current_days > 0
        and (today - last_exchange_day).days > 1
    )
    if broke:
        current_days = 0
        last_exchange_day = None

    exchanged_today = other_last_day == today
    if not exchanged_today:
        # L'autre n'a pas encore écrit aujourd'hui : rien n'avance.
        return StreakOutcome(current_days, last_exchange_day, broke)

    if last_exchange_day == today:
        # Déjà compté. Écrire vingt fois dans la journée ne fait pas vingt
        # jours — sans cette garde, la chaîne se gonflerait en une soirée.
        return StreakOutcome(current_days, last_exchange_day, broke)

    if last_exchange_day is None or (today - last_exchange_day).days == 1:
        return StreakOutcome(current_days + 1, today, broke)

    # Écart supérieur à un jour, déjà traité par la rupture ci-dessus : on
    # repart à un.
    return StreakOutcome(1, today, broke)


def can_restore(broken_at: Optional[datetime], now: datetime) -> bool:
    """La fenêtre de rachat est-elle encore ouverte ?"""
    return broken_at is not None and (now - broken_at) <= GRACE_PERIOD


def seconds_left(broken_at: Optional[datetime], now: datetime) -> int:
    """Secondes restantes pour racheter — affiché en compte à rebours.

    Un délai qu'on ne voit pas courir n'incite à rien : on découvre qu'il
    est passé.
    """
    if broken_at is None:
        return 0
    remaining = GRACE_PERIOD - (now - broken_at)
    return max(0, int(remaining.total_seconds()))
