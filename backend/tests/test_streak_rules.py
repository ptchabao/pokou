"""Streak Lock — le calcul de la chaîne, sans base ni requête.

Un calcul de jours se trompe d'UN, et une chaîne fausse d'un jour ne plante
jamais : elle fait simplement perdre à quelqu'un un compteur qu'il entretient
depuis trois mois, sans qu'il ait aucun moyen de prouver l'erreur.
"""
from datetime import date, datetime, timedelta

from app.services.modules.streak_service import GRACE_PERIOD, apply_message, can_restore, ordered_pair, seconds_left

TODAY = date(2026, 9, 17)
YESTERDAY = TODAY - timedelta(days=1)
NOW = datetime(2026, 9, 17, 12, 0, 0)


def test_la_paire_se_range_toujours_dans_le_meme_ordre():
    """Sans cet ordre, la même conversation produirait DEUX lignes selon qui
    écrit le premier — deux chiffres différents pour la même relation, un sur
    chaque téléphone."""
    assert ordered_pair(7, 3) == ordered_pair(3, 7) == (3, 7)


def test_ecrire_seul_ne_fait_pas_avancer_la_chaine():
    """Une chaîne mesure une RELATION. La faire monter en écrivant dans le
    vide la viderait de son sens, et récompenserait exactement le
    comportement qu'une messagerie doit décourager."""
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=None,
        current_days=0, last_exchange_day=None,
    )
    assert outcome.current_days == 0


def test_un_echange_le_meme_jour_fait_avancer_d_un():
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=TODAY,
        current_days=4, last_exchange_day=YESTERDAY,
    )
    assert outcome.current_days == 5
    assert outcome.last_exchange_day == TODAY


def test_vingt_messages_dans_la_journee_ne_font_pas_vingt_jours():
    """Sans cette garde, la chaîne se gonflerait en une soirée."""
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=TODAY,
        current_days=5, last_exchange_day=TODAY,
    )
    assert outcome.current_days == 5


def test_un_jour_saute_rompt_la_chaine():
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=TODAY,
        current_days=40, last_exchange_day=TODAY - timedelta(days=3),
    )
    assert outcome.broke is True
    assert outcome.current_days == 1  # l'échange du jour redémarre à un


def test_la_premiere_chaine_demarre_a_un():
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=TODAY,
        current_days=0, last_exchange_day=None,
    )
    assert outcome.current_days == 1


def test_une_chaine_jamais_commencee_ne_se_rompt_pas():
    # Sans cette garde, un premier message déclencherait une notification de
    # rupture pour une chaîne qui n'a jamais existé.
    outcome = apply_message(
        today=TODAY, sender_last_day=TODAY, other_last_day=None,
        current_days=0, last_exchange_day=None,
    )
    assert outcome.broke is False


def test_la_fenetre_de_rachat_se_ferme():
    assert can_restore(NOW - timedelta(minutes=5), NOW) is True
    assert can_restore(NOW - GRACE_PERIOD - timedelta(seconds=1), NOW) is False
    # Chaîne intacte : il n'y a rien à racheter.
    assert can_restore(None, NOW) is False


def test_le_compte_a_rebours_est_borne():
    """Un délai qu'on ne voit pas courir n'incite à rien : on découvre qu'il
    est passé."""
    assert seconds_left(NOW, NOW) == int(GRACE_PERIOD.total_seconds())
    assert seconds_left(NOW - timedelta(hours=1), NOW) == 0
    assert seconds_left(None, NOW) == 0
