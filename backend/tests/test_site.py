"""Le site pokou.app et l'aiguillage des sous-domaines (api/public/site.py)."""
from fastapi.testclient import TestClient

from app.api.public.site import markdown_to_html
from app.main import app

client = TestClient(app)


def test_the_site_is_served_on_pokou_app():
    response = client.get("/", headers={"host": "pokou.app"})
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Pokou" in response.text and "/site/site.css" in response.text
    assert "script-src 'none'" in response.headers["content-security-policy"]


def test_the_api_root_is_unchanged_on_api_host():
    response = client.get("/", headers={"host": "api.pokou.app"})
    assert response.status_code == 200
    assert response.json()["name"] == "Pokou API"


def test_www_redirects_to_the_bare_domain():
    response = client.get("/confidentialite?x=1", headers={"host": "www.pokou.app"}, follow_redirects=False)
    assert response.status_code == 301
    assert response.headers["location"] == "https://pokou.app/confidentialite?x=1"


def test_extranet_root_leads_to_the_admin_console():
    response = client.get("/", headers={"host": "extranet.pokou.app"}, follow_redirects=False)
    assert response.status_code == 302 and response.headers["location"] == "/console/"


def test_console_lives_only_on_extranet():
    moved = client.get("/console/login/", headers={"host": "api.pokou.app"}, follow_redirects=False)
    assert moved.status_code == 301
    assert moved.headers["location"] == "https://extranet.pokou.app/console/login/"
    here = client.get("/console/login/", headers={"host": "extranet.pokou.app"}, follow_redirects=False)
    assert here.status_code != 301


def test_deep_link_root_leads_to_the_site():
    response = client.get("/", headers={"host": "deep.pokou.app"}, follow_redirects=False)
    assert response.status_code == 302 and response.headers["location"] == "https://pokou.app/"


def test_privacy_policy_page_is_complete():
    response = client.get("/confidentialite", headers={"host": "pokou.app"})
    assert response.status_code == 200
    text = response.text
    assert "<h1>Politique de confidentialité de Pokou</h1>" in text
    for needed in ("confidentialite@pokou.app", "Supprimer votre compte", "Vos droits",
                   "donnée de santé", "Les enfants", "pokou.app/compte/suppression/"):
        assert needed in text, needed


def test_terms_page():
    response = client.get("/conditions", headers={"host": "pokou.app"})
    assert response.status_code == 200 and "Conditions d'utilisation" in response.text


def test_site_assets_and_traversal():
    assert client.get("/site/site.css").status_code == 200
    image = client.get("/site/img/04-kory.jpg")
    assert image.status_code == 200 and image.headers["content-type"] == "image/jpeg"
    assert client.get("/site/../main.py").status_code == 404
    assert client.get("/site/%2e%2e/main.py").status_code == 404


def test_markdown_is_escaped():
    out = markdown_to_html("# T\n\n<script>x</script> **gras**\n\n- a\n  suite\n\n> note")
    assert "<script>" not in out and "&lt;script&gt;" in out
    assert "<strong>gras</strong>" in out
    assert "<li>a suite</li>" in out and "<blockquote>" in out
