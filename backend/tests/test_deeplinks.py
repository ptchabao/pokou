"""Les pages d'atterrissage des liens d'invitation.

Le symptôme corrigé : « les liens profonds mènent souvent à une page
introuvable avant de parfois mener au bon endroit ». `assetlinks.json`
autorisait Pokou à ouvrir ces adresses, mais rien ne les SERVAIT — dès qu'un
lien n'était pas intercepté par l'application, le navigateur allait vraiment
chercher la page, et tombait sur un 404.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.api.public.deeplinks import PLAY_STORE_URL

client = TestClient(app)


@pytest.mark.parametrize(
    "path",
    [
        "/invite/group/AB12CD34",
        "/invite/community/AB12CD34",
        "/invite/channel/AB12CD34",
        # Format historique des groupes — group_model.dart::inviteLinkFor.
        "/invite/AB12CD34",
        # Format historique des communautés — community_model.dart.
        "/c/AB12CD34",
        "/channel/AB12CD34",
    ],
)
def test_chaque_forme_de_lien_sert_une_page(path):
    """Les six formes que l'application produit et que le client sait lire.
    N'en servir qu'une laisserait les autres en 404."""
    response = client.get(path)
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


def test_la_page_propose_d_ouvrir_l_application_et_de_l_installer():
    response = client.get("/invite/group/AB12CD34")
    # `intent://` fait ce qu'un lien https ne peut pas depuis une page déjà
    # ouverte : forcer l'ouverture de CETTE application.
    assert "intent://pok.app/invite/group/AB12CD34" in response.text
    assert "package=com.pokou.pokou" in response.text
    # Et le repli pour qui ne l'a pas — c'est tout l'intérêt d'un lien
    # d'invitation.
    assert PLAY_STORE_URL in response.text


def test_la_page_ne_revele_rien_du_contenu_prive():
    """Le code circule dans des conversations et finit dans des historiques
    de navigation. La page dit la NATURE de l'invitation, jamais le nom du
    groupe ni qui invite."""
    response = client.get("/invite/community/SECRET99")
    lowered = response.text.lower()
    assert "membre" not in lowered
    assert "SECRET99" not in response.text.replace(
        "intent://pok.app/invite/community/SECRET99", ""
    ).replace(f"{PLAY_STORE_URL}", ""), "le code ne doit pas s'afficher en clair"


def test_un_lien_inconnu_sert_quand_meme_une_page():
    """Un lien qu'on ne comprend pas vaut toujours mieux qu'une page
    introuvable."""
    response = client.get("/invite/inconnu/XYZ")
    assert response.status_code == 200
    assert "Pokou" in response.text


def test_la_page_n_est_pas_mise_en_cache():
    """Un lien d'invitation peut être révoqué : une page gardée par un
    navigateur ou un proxy continuerait de le proposer."""
    response = client.get("/c/AB12CD34")
    assert response.headers.get("cache-control") == "no-store"


def test_les_pages_ne_demandent_aucune_authentification():
    """Elles s'ouvrent depuis un lien reçu, chez quelqu'un qui n'a peut-être
    même pas l'application."""
    response = client.get("/invite/group/AB12CD34", headers={})
    assert response.status_code == 200


def test_les_pages_incluent_les_balises_open_graph_et_twitter():
    """Vérifie que les balises Open Graph et Twitter Cards sont présentes
    pour permettre aux applications externes (WhatsApp, Telegram, etc.)
    d'afficher une carte d'aperçu riche."""
    response = client.get("/invite/group/AB12CD34")
    assert response.status_code == 200
    html = response.text
    assert '<meta property="og:site_name" content="Pokou Messenger">' in html
    assert '<meta property="og:title"' in html
    assert '<meta property="og:description"' in html
    assert '<meta property="og:image"' in html
    assert '<meta name="twitter:card" content="summary_large_image">' in html


def test_lien_publication_chaine_sert_une_page():
    """Une publication ou un article de chaîne partagé vers l'extérieur doit
    avoir sa propre URL profonde avec métadonnées article."""
    response = client.get("/channel/CHANN123/post/42")
    assert response.status_code == 200
    assert "intent://pok.app/channel/CHANN123/post/42" in response.text
    assert '<meta property="og:title"' in response.text

