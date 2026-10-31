"""Les règles de Spark, vérifiées sans base.

Ce fichier couvre les décisions qui coûtent cher : qui peut liker, ce que
devient l'argent d'un rendez-vous manqué, et à partir de quand le silence de
quelqu'un déclenche une alerte.
"""
from datetime import date, datetime, timedelta

import pytest

from app.services.modules import spark_rules as rules


# ── La Carte du Moment ───────────────────────────────────────────────────


def test_une_intention_meurt_au_bout_de_vingt_quatre_heures():
    now = datetime(2026, 9, 17, 20, 0)
    expiry = rules.intent_expiry(now)
    assert rules.intent_is_live(expiry, now)
    # C'est toute la mécanique du produit : sans expiration, l'intention
    # redevient un profil que personne ne relit.
    assert not rules.intent_is_live(expiry, now + timedelta(hours=24, seconds=1))


def test_une_position_trop_vieille_n_est_plus_une_position():
    now = datetime(2026, 9, 17, 20, 0)
    assert rules.location_is_fresh(now - timedelta(hours=2), now)
    # Afficher « à 2 km » d'après un relevé d'avant-hier est une information
    # fausse — et pour une rencontre physique, c'est un risque.
    assert not rules.location_is_fresh(now - timedelta(hours=13), now)
    assert not rules.location_is_fresh(None, now)


def test_la_distance_est_calculee_en_kilometres():
    # Lomé centre → aéroport de Lomé, environ 5 km.
    km = rules.distance_km(6.1319, 1.2228, 6.1656, 1.2545)
    assert 4 < km < 6


# ── L'âge ────────────────────────────────────────────────────────────────


def test_un_mineur_ne_peut_pas_entrer():
    today = date(2026, 9, 17)
    assert not rules.is_adult(date(2009, 9, 18), today)
    # La veille de ses dix-huit ans : toujours non.
    assert not rules.is_adult(date(2008, 9, 18), today)
    assert rules.is_adult(date(2008, 9, 17), today)


# ── Le swipe à crédit ────────────────────────────────────────────────────


def test_les_cinq_premiers_likes_du_jour_sont_gratuits():
    today = date(2026, 9, 17)
    allowance = rules.like_allowance(
        gender="M", free_day=today, free_used=4, balance=0, today=today
    )
    assert allowance.allowed and allowance.source == "free"
    assert allowance.free_left == 1


def test_le_quota_gratuit_repart_le_lendemain():
    """Sans la DATE, un compteur seul ne saurait pas de quel jour il parle —
    et c'est ainsi qu'un quota se retrouve épuisé pour toujours."""
    allowance = rules.like_allowance(
        gender="M",
        free_day=date(2026, 9, 16),
        free_used=5,
        balance=0,
        today=date(2026, 9, 17),
    )
    assert allowance.allowed and allowance.source == "free"
    assert allowance.free_left == rules.FREE_LIKES_PER_DAY


def test_le_quota_epuise_puise_dans_les_likes_achetes():
    today = date(2026, 9, 17)
    allowance = rules.like_allowance(
        gender="M", free_day=today, free_used=5, balance=10, today=today
    )
    assert allowance.allowed and allowance.source == "balance"


def test_sans_quota_ni_solde_on_refuse_en_le_disant():
    today = date(2026, 9, 17)
    allowance = rules.like_allowance(
        gender="M", free_day=today, free_used=5, balance=0, today=today
    )
    assert not allowance.allowed
    assert allowance.reason


def test_les_femmes_likent_sans_limite():
    today = date(2026, 9, 17)
    allowance = rules.like_allowance(
        gender="F", free_day=today, free_used=999, balance=0, today=today
    )
    assert allowance.allowed and allowance.source == "unlimited"


def test_un_abonne_voit_sans_compter():
    now = datetime(2026, 9, 17, 20, 0)
    allowed, left = rules.view_allowance(
        plus_until=now + timedelta(days=5), views_day=now.date(), views_used=500, now=now
    )
    assert allowed and left == -1


def test_sans_abonnement_la_consultation_est_bornee():
    now = datetime(2026, 9, 17, 20, 0)
    allowed, left = rules.view_allowance(
        plus_until=None, views_day=now.date(), views_used=rules.FREE_VIEWS_PER_DAY, now=now
    )
    assert not allowed and left == 0


# ── La Salle d'Entrée ────────────────────────────────────────────────────


def test_les_deux_continuent_le_match_tient():
    outcome = rules.resolve_room(low_continued=True, high_continued=True)
    assert outcome.status == "CONTINUED"
    assert outcome.karma_penalty_for is None


def test_un_seul_continue_le_match_est_sauve_et_l_autre_paie_en_karma():
    outcome = rules.resolve_room(low_continued=True, high_continued=False)
    assert outcome.status == "SAVED"
    assert outcome.karma_penalty_for == "high"


def test_le_silence_des_deux_ne_punit_personne():
    """Se taire ensemble n'est pas un manque de respect, c'est un désaccord."""
    outcome = rules.resolve_room(low_continued=False, high_continued=False)
    assert outcome.status == "EXPIRED"
    assert outcome.karma_penalty_for is None


def test_la_salle_ne_se_prolonge_pas_indefiniment():
    assert rules.can_extend(0)
    assert not rules.can_extend(rules.MAX_EXTENSIONS)


# ── Le Wingman ───────────────────────────────────────────────────────────


def test_l_avis_des_amis_est_agrege_jamais_detaille():
    assert rules.wingman_verdict(["GREEN", "GREEN", "RED"]) == "GREEN"
    assert rules.wingman_verdict(["RED", "RED", "GREEN"]) == "RED"
    assert rules.wingman_verdict(["GREEN", "RED"]) == "SPLIT"


def test_sans_vote_il_n_y_a_pas_d_avis():
    assert rules.wingman_verdict([]) is None
    assert rules.wingman_verdict([None, None]) is None


# ── Le Karma ─────────────────────────────────────────────────────────────


def test_le_karma_reste_dans_ses_bornes():
    assert rules.apply_karma(5, rules.KARMA_NO_SHOW) == rules.KARMA_MIN
    assert rules.apply_karma(rules.KARMA_MAX, rules.KARMA_DATE_COMPLETED) == rules.KARMA_MAX


def test_un_karma_trop_bas_ne_peut_plus_inviter():
    """Quelqu'un qui a posé trois lapins ne doit pas pouvoir bloquer
    l'argent d'un quatrième."""
    assert rules.can_invite(rules.KARMA_START)
    assert not rules.can_invite(rules.KARMA_INVITE_FLOOR - 1)


# ── L'argent d'un rendez-vous ────────────────────────────────────────────


def test_annuler_a_temps_rend_tout():
    scheduled = datetime(2026, 9, 20, 19, 0)
    settlement = rules.settle_cancellation(
        amount=5000, scheduled_at=scheduled, now=scheduled - timedelta(hours=25)
    )
    assert settlement.status == "REFUNDED"
    assert settlement.refund_to_payer == 5000


def test_annuler_trop_tard_paie_le_commercant_et_rien_a_l_application():
    """Se rémunérer sur un rendez-vous qui n'a pas eu lieu serait
    indéfendable."""
    scheduled = datetime(2026, 9, 20, 19, 0)
    settlement = rules.settle_cancellation(
        amount=5000, scheduled_at=scheduled, now=scheduled - timedelta(hours=2)
    )
    assert settlement.status == "CANCELLED"
    assert settlement.merchant_due == 5000
    assert settlement.platform_fee == 0
    assert settlement.refund_to_payer == 0


def test_un_rendez_vous_honore_paie_le_commercant_moins_la_commission():
    settlement = rules.settle_completed(amount=5000)
    assert settlement.status == "RELEASED"
    assert settlement.platform_fee == 500
    assert settlement.merchant_due == 4500
    # Rien ne se perd : ce qui sort égale ce qui est entré.
    assert settlement.merchant_due + settlement.platform_fee == 5000


def test_un_lapin_verse_la_moitie_a_celui_qui_s_est_deplace():
    settlement = rules.settle_no_show(amount=5000, absent="payer")
    assert settlement.status == "PENALIZED"
    assert settlement.penalty_to == "guest"
    assert settlement.penalty_amount == 2500
    assert settlement.merchant_due == 2500
    # Un lapin n'est pas un revenu.
    assert settlement.platform_fee == 0
    assert settlement.penalty_amount + settlement.merchant_due == 5000


def test_le_lapin_de_l_invite_verse_a_celui_qui_a_paye():
    settlement = rules.settle_no_show(amount=3000, absent="guest")
    assert settlement.penalty_to == "payer"


def test_un_absent_inconnu_est_refuse():
    with pytest.raises(ValueError):
        rules.settle_no_show(amount=1000, absent="personne")


def test_le_silence_des_deux_rend_l_argent():
    """On ne peut affirmer ni que le rendez-vous a eu lieu, ni qu'il a été
    manqué. Dans le doute, on ne prend rien à personne."""
    settlement = rules.settle_silence(amount=3500)
    assert settlement.status == "REFUNDED"
    assert settlement.refund_to_payer == 3500


@pytest.mark.parametrize("amount", [100, 333, 999, 1001, 3500, 8000, 12345])
def test_aucun_franc_ne_disparait_quel_que_soit_le_montant(amount):
    """Un arrondi qui se promène sur de l'argent finit par manquer quelque
    part. On vérifie que la somme se conserve sur des montants qui tombent
    mal."""
    completed = rules.settle_completed(amount=amount)
    assert completed.merchant_due + completed.platform_fee == amount

    no_show = rules.settle_no_show(amount=amount, absent="payer")
    assert no_show.merchant_due + no_show.penalty_amount == amount


def test_on_ne_valide_pas_un_rendez_vous_trois_jours_apres():
    scheduled = datetime(2026, 9, 20, 19, 0)
    assert rules.can_validate(scheduled_at=scheduled, now=scheduled + timedelta(hours=1))
    assert not rules.can_validate(scheduled_at=scheduled, now=scheduled + timedelta(days=3))


# ── La sécurité silencieuse ──────────────────────────────────────────────


def test_le_check_in_arrive_une_demi_heure_apres_le_debut():
    scheduled = datetime(2026, 9, 20, 19, 0)
    assert rules.checkin_due_at(scheduled) == scheduled + timedelta(minutes=30)


def test_une_reponse_ferme_le_check_in():
    due = datetime(2026, 9, 20, 19, 30)
    assert not rules.checkin_should_escalate(
        due_at=due, answered_at=due + timedelta(minutes=1), now=due + timedelta(hours=1)
    )


def test_le_silence_previent_le_cercle_de_securite():
    due = datetime(2026, 9, 20, 19, 30)
    # Assez pour ne pas alerter quelqu'un qui pose son téléphone…
    assert not rules.checkin_should_escalate(
        due_at=due, answered_at=None, now=due + timedelta(minutes=4)
    )
    # …trop peu pour qu'un vrai problème attende.
    assert rules.checkin_should_escalate(
        due_at=due, answered_at=None, now=due + timedelta(minutes=6)
    )
