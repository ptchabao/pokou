"""La règle du nom affiché (utils/identity.py::nom_affiche).

Un compte certifié qui a un nom garde CE nom partout — y compris chez qui
l'a enregistré autrement ; sinon le carnet l'emporte, puis le nom choisi,
puis le numéro."""
from types import SimpleNamespace

from app.utils.identity import nom_affiche, nom_certifie


def _user(full_name=None, phone="+22890000000", verified=False):
    return SimpleNamespace(full_name=full_name, phone=phone, is_verified=verified)


def test_un_compte_certifie_garde_son_nom_malgre_le_carnet():
    assert nom_affiche(_user("Banque Atlantique", verified=True), "Mon banquier") == "Banque Atlantique"


def test_un_compte_certifie_garde_son_nom_meme_hors_carnet():
    assert nom_affiche(_user("Banque Atlantique", verified=True), None) == "Banque Atlantique"


def test_un_compte_certifie_sans_nom_retombe_sur_le_carnet():
    assert nom_certifie(_user("  ", verified=True)) is None
    assert nom_affiche(_user("  ", verified=True), "Mon banquier") == "Mon banquier"


def test_sans_certification_le_carnet_l_emporte():
    assert nom_affiche(_user("Kossi A.", verified=False), "Tonton Kossi") == "Tonton Kossi"


def test_sans_carnet_le_nom_choisi_puis_le_numero():
    assert nom_affiche(_user("Kossi A."), None) == "Kossi A."
    assert nom_affiche(_user(None, phone="+22891111111"), None) == "+22891111111"
    assert nom_affiche(None, None, repli="Pokou") == "Pokou"
