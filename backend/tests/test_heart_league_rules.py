"""Heart League — les règles du classement, sans base ni requête.

Ces fonctions ont une propriété désagréable : une erreur ne PLANTE pas. Un
seuil mal placé classe simplement les gens au mauvais endroit, un décompte
trop fort vide le classement en un mois, et personne ne peut le prouver
depuis l'extérieur. D'où des tests sur les règles elles-mêmes, et pas
seulement sur les routes qui les appellent.
"""
from datetime import datetime, timedelta

from app.services.modules.heart_league_service import DECAY_FLOOR_RATIO, LEAGUES, apply_decay, league_for, needs_pass, next_league, progress_to_next

NOW = datetime(2026, 9, 17, 12, 0, 0)


# ── Les ligues ───────────────────────────────────────────────────────────


def test_chaque_seuil_ouvre_exactement_sa_ligue():
    for code, label, threshold in LEAGUES:
        assert league_for(threshold).code == code, f"{label} n'ouvre pas à {threshold}"
        if threshold > 0:
            # Un point en dessous appartient encore à la ligue précédente —
            # c'est la frontière, et c'est là que les erreurs de comparaison
            # (>= contre >) se cachent.
            assert league_for(threshold - 1).code != code


def test_zero_point_est_bronze_et_non_une_erreur():
    # Le cas du tout premier utilisateur. Sans ligue de départ, l'écran
    # n'aurait rien à afficher au moment précis où il doit convaincre.
    assert league_for(0).code == "BRONZE"
    assert league_for(0).rank == 0


def test_les_ecarts_se_creusent_vers_le_haut():
    """Une progression linéaire encombrerait le sommet.

    Si Couronne s'atteignait aussi vite qu'Argent, y être ne vaudrait rien —
    et c'est précisément la valeur du sommet qui fait tenir le classement.
    """
    seuils = [threshold for _, _, threshold in LEAGUES]
    ecarts = [b - a for a, b in zip(seuils, seuils[1:])]
    assert ecarts == sorted(ecarts), f"les paliers ne se creusent pas : {ecarts}"


def test_le_sommet_affiche_une_barre_pleine():
    # Une barre vide au sommet se lirait comme « vous n'avez rien accompli ».
    assert next_league(99999) is None
    assert progress_to_next(99999) == 1.0


def test_l_avancement_reste_borne():
    for points in (0, 1, 149, 150, 3000, 10**9):
        assert 0.0 <= progress_to_next(points) <= 1.0


# ── Le décompte hebdomadaire ─────────────────────────────────────────────


def test_rien_ne_se_perd_avant_une_semaine_pleine():
    points, week = apply_decay(1000, 1000, NOW - timedelta(days=6), None, NOW)
    assert points == 1000
    assert week == NOW - timedelta(days=6)


def test_une_semaine_d_absence_coute_des_points():
    points, _ = apply_decay(1000, 1000, NOW - timedelta(days=7), None, NOW)
    assert points < 1000
    # Mais pas au point de faire dégringoler de deux ligues : une semaine de
    # vacances ne doit pas annuler un mois d'activité.
    assert league_for(points).rank >= league_for(1000).rank - 1


def test_la_protection_payee_suspend_la_perte_sans_la_reporter():
    """On ne paie pas pour RETARDER une perte, on paie pour ne pas la subir.

    L'inverse serait une dette déguisée, qui se découvrirait au pire moment —
    juste après l'expiration de la protection qu'on vient de payer.
    """
    protege = NOW + timedelta(days=30)
    points, week = apply_decay(1000, 1000, NOW - timedelta(days=21), protege, NOW)
    assert points == 1000
    # La fenêtre avance quand même : sinon la dette s'accumulerait, ce qui
    # est exactement ce qu'on veut éviter.
    assert week == NOW


def test_le_plancher_empeche_de_repartir_de_zero():
    """Quelqu'un qui s'absente un mois ne doit pas tout perdre.

    Repartir de zéro n'incite pas à revenir — c'est l'inverse de l'effet
    recherché par un classement.
    """
    points, _ = apply_decay(4000, 4000, NOW - timedelta(weeks=52), None, NOW)
    assert points == int(4000 * DECAY_FLOOR_RATIO)


def test_le_plancher_suit_le_MEILLEUR_score_pas_le_courant():
    # Quelqu'un tombé à 100 points mais monté un jour à 4000 garde son
    # plancher : c'est ce qui rend une remontée possible plutôt que de
    # condamner un compte à ramer indéfiniment.
    points, _ = apply_decay(100, 4000, NOW - timedelta(weeks=10), None, NOW)
    assert points == int(4000 * DECAY_FLOOR_RATIO)


def test_plusieurs_semaines_se_cumulent_sans_boucle_infinie():
    points, week = apply_decay(10000, 10000, NOW - timedelta(weeks=3), None, NOW)
    assert points < 10000
    assert week == NOW


# ── Le laissez-passer ────────────────────────────────────────────────────


def test_un_cran_d_ecart_ne_demande_rien():
    """Sans cette tolérance, la mécanique couperait la moitié des
    conversations ordinaires entre voisins de classement."""
    assert needs_pass(150, 600) is False   # Argent → Or
    assert needs_pass(600, 2000) is False  # Or → Diamant


def test_deux_crans_demandent_un_pass():
    assert needs_pass(0, 600) is True      # Bronze → Or
    assert needs_pass(0, 6000) is True     # Bronze → Couronne


def test_ecrire_vers_le_BAS_est_toujours_libre():
    """Faire payer les mieux classés pour parler à tout le monde les
    pousserait simplement à ne plus parler à personne."""
    assert needs_pass(6000, 0) is False
    assert needs_pass(2000, 150) is False


def test_meme_ligue_est_toujours_libre():
    assert needs_pass(700, 1900) is False
