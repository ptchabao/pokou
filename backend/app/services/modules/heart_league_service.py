"""Heart League — ligues, points et décompte hebdomadaire.

Toute la règle du jeu vit ICI, hors des routes, pour une raison précise :
c'est la partie qui se teste sans base de données ni requête HTTP, et c'est
aussi celle où une erreur ne se voit pas. Un seuil mal placé ne plante pas :
il classe simplement les gens au mauvais endroit, et personne ne peut le
prouver depuis l'extérieur.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

#: Les cinq ligues, du bas vers le haut, avec leur seuil d'entrée.
#:
#: Les écarts se creusent volontairement : passer Bronze → Argent doit
#: arriver dans la première semaine, atteindre Couronne doit rester rare.
#: Une progression linéaire rendrait le haut du classement encombré, et le
#: fait d'y être n'aurait plus aucune valeur.
LEAGUES = [
    ("BRONZE", "Bronze", 0),
    ("ARGENT", "Argent", 150),
    ("OR", "Or", 600),
    ("DIAMANT", "Diamant", 2000),
    ("COURONNE", "Couronne", 6000),
]

#: Points accordés par type de signal REÇU. Jamais pour ce qu'on envoie :
#: sinon on monte en écrivant à tout le monde, et le classement devient un
#: concours de spam au détriment des destinataires.
POINTS_INBOUND_MESSAGE = 1
POINTS_GIFT_RECEIVED = 10

#: Part des points perdue chaque semaine d'inactivité. 15 % : assez pour
#: qu'une absence prolongée se voie, assez peu pour qu'une semaine de
#: vacances ne fasse pas dégringoler de deux ligues.
WEEKLY_DECAY_RATE = 0.15

#: Plancher : le décompte ne fait jamais redescendre en dessous du seuil
#: d'entrée de la ligue ATTEINTE juste en dessous de son maximum historique.
#: Sans plancher, quelqu'un qui s'absente un mois repart de zéro, ce qui
#: n'incite pas à revenir — c'est l'inverse de l'effet recherché.
DECAY_FLOOR_RATIO = 0.5

#: Écart de ligues au-delà duquel il faut un laissez-passer pour écrire.
#: UN cran de tolérance : sans lui, la mécanique couperait la moitié des
#: conversations ordinaires entre voisins de classement.
PASS_REQUIRED_GAP = 2


@dataclass(frozen=True)
class League:
    code: str
    label: str
    threshold: int
    rank: int


def league_for(points: int) -> League:
    """La ligue correspondant à un nombre de points."""
    chosen = 0
    for index, (_code, _label, threshold) in enumerate(LEAGUES):
        if points >= threshold:
            chosen = index
    code, label, threshold = LEAGUES[chosen]
    return League(code=code, label=label, threshold=threshold, rank=chosen)


def next_league(points: int) -> Optional[League]:
    """La ligue suivante, ou `None` au sommet."""
    current = league_for(points)
    if current.rank + 1 >= len(LEAGUES):
        return None
    code, label, threshold = LEAGUES[current.rank + 1]
    return League(code=code, label=label, threshold=threshold, rank=current.rank + 1)


def progress_to_next(points: int) -> float:
    """Avancement vers la ligue suivante, entre 0 et 1.

    Renvoie 1 au sommet plutôt que 0 : une barre vide en haut du classement
    se lirait comme « vous n'avez rien accompli ».
    """
    current = league_for(points)
    upper = next_league(points)
    if upper is None:
        return 1.0
    span = upper.threshold - current.threshold
    return min(1.0, max(0.0, (points - current.threshold) / span)) if span else 1.0


def weeks_elapsed(week_start: datetime, now: datetime) -> int:
    """Semaines pleines écoulées depuis le dernier décompte."""
    return max(0, (now - week_start).days // 7)


def apply_decay(
    points: int,
    best_points: int,
    week_start: datetime,
    protected_until: Optional[datetime],
    now: datetime,
) -> tuple[int, datetime]:
    """Applique le décompte dû, et renvoie (points, nouveau début de semaine).

    Calculé À LA LECTURE plutôt que par une tâche de fond qui passerait sur
    tous les comptes chaque semaine. Deux raisons : la tâche de fond coûte
    cher pour des comptes que personne ne regarde, et surtout elle rend le
    résultat dépendant de son bon fonctionnement — un ordonnanceur en panne
    gèlerait tout le classement sans que personne ne s'en aperçoive.

    La protection payée SUSPEND le décompte sans le reporter : on ne paie pas
    pour retarder une perte, on paie pour ne pas la subir. L'inverse serait
    une dette déguisée, et se découvrirait au pire moment.
    """
    elapsed = weeks_elapsed(week_start, now)
    if elapsed <= 0:
        return points, week_start

    if protected_until is not None and protected_until > now:
        # Protégé : la fenêtre avance, les points ne bougent pas.
        return points, week_start + timedelta(weeks=elapsed)

    floor = int(best_points * DECAY_FLOOR_RATIO)
    decayed = points
    for _ in range(elapsed):
        decayed = int(decayed * (1 - WEEKLY_DECAY_RATE))
    return max(floor, decayed), week_start + timedelta(weeks=elapsed)


def needs_pass(sender_points: int, target_points: int) -> bool:
    """Faut-il un laissez-passer pour écrire ?

    Uniquement vers le HAUT : écrire à quelqu'un d'une ligue inférieure n'a
    jamais besoin d'être payé. Le contraire ferait payer les mieux classés
    pour parler à tout le monde, ce qui les pousserait simplement à ne plus
    parler à personne.
    """
    gap = league_for(target_points).rank - league_for(sender_points).rank
    return gap >= PASS_REQUIRED_GAP
