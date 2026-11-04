"""La page web de suppression de compte (AUTH-06).

Exigée par Google Play et l'App Store : on doit pouvoir demander la
suppression depuis un navigateur, sans installer l'application.
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_la_page_est_servie_sans_authentification():
    """C'est une page publique : quelqu'un qui a désinstallé l'application
    doit pouvoir l'ouvrir."""
    reponse = client.get("/compte/suppression/")
    assert reponse.status_code == 200
    assert "text/html" in reponse.headers["content-type"]
    corps = reponse.text
    # Le store exige que la page DISE ce qui est supprimé et ce qui reste.
    assert "Ce qui est supprimé" in corps
    assert "Ce qui est conservé" in corps


def test_l_adresse_sans_barre_oblique_redirige():
    reponse = client.get("/compte/suppression", follow_redirects=False)
    assert reponse.status_code in (307, 308)
    assert reponse.headers["location"] == "/compte/suppression/"


def test_politique_de_securite_stricte():
    """Aucun script ni style en ligne, aucun domaine tiers : la page
    manipule un jeton de session, elle ne doit rien charger d'ailleurs."""
    entetes = client.get("/compte/suppression/").headers
    csp = entetes["content-security-policy"]
    assert "default-src 'self'" in csp
    assert "script-src 'self'" in csp
    assert "frame-ancestors 'none'" in csp
    assert entetes["x-content-type-options"] == "nosniff"


def test_les_fichiers_de_la_page_sont_servis():
    for nom, type_attendu in (("suppression.css", "text/css"), ("suppression.js", "text/javascript")):
        reponse = client.get(f"/compte/suppression/{nom}")
        assert reponse.status_code == 200, nom
        assert type_attendu in reponse.headers["content-type"]


def test_aucun_autre_fichier_n_est_accessible():
    """Pas de traversée : la liste des fichiers servis est fermée."""
    for chemin in ("../main.py", "index.html.bak", "../../.env"):
        assert client.get(f"/compte/suppression/{chemin}").status_code in (404, 400)


# ── Chaîne fonctionnelle : ce que la page enchaîne (request-otp, verify-otp,
# puis DELETE sur la même route que l'application) ──────────────────────────
import re
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.models import User
from app.services.auth import otp_service

_URL = "sqlite:///./test_suppression_web.db"
_engine = create_engine(_URL, connect_args={"check_same_thread": False})
_Session = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


def _override_db():
    db = _Session()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture()
def flow_client():
    Base.metadata.create_all(bind=_engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _override_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=_engine)


def test_suppression_de_bout_en_bout_comme_la_page(flow_client):
    phone = "+22890555001"
    # 1. Le numéro → un code par SMS (ici intercepté).
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as sms:
        flow_client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", sms.call_args.args[2]).group(1)

    # 2. Le code → un jeton de session.
    verif = flow_client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    assert verif.status_code == 200, verif.text
    token = verif.json()["access_token"]

    # 3. Le numéro retapé → la suppression, sur la MÊME route que l'app.
    suppr = flow_client.request(
        "DELETE", "/api/v1/account-privacy/account",
        json={"confirm_phone": phone},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert suppr.status_code == 200, suppr.text

    # Le compte est désactivé et anonymisé ; le numéro est libéré.
    db = _Session()
    try:
        user = db.query(User).filter(User.phone == phone).first()
        assert user is None  # numéro libéré
    finally:
        db.close()
