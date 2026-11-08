"""La console d'administration est servie par l'API, sous /console/."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_la_console_est_servie():
    page = client.get("/console/login/")
    assert page.status_code == 200
    assert "text/html" in page.headers["content-type"]
    assert "frame-ancestors 'none'" in page.headers["content-security-policy"]
    assert client.get("/console", follow_redirects=False).status_code in (307, 308)


def test_on_ne_sort_pas_du_dossier_de_la_console():
    assert client.get("/console/..%2F..%2Fcore%2Fconfig.py").status_code == 404
    assert client.get("/console/inexistant.js").status_code == 404
