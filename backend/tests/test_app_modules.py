"""Pokou — catalogue des modules activables.

La propriété qui domine ce fichier est une propriété d'ABSENCE : un module
que l'équipe n'a pas ouvert ne doit apparaître NULLE PART côté utilisateur.
Une régression ne casserait rien de visible — elle publierait simplement une
fonctionnalité inachevée à tout le monde, et personne ne s'en apercevrait
avant de recevoir des retours sur un écran vide.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AppModule, User, UserModuleActivation, UserRole
from app.services.auth import otp_service
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_app_modules.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _admin(client, email="admin@example.com"):
    with TestingSessionLocal() as db:
        if db.query(User).filter(User.email == email).first() is None:
            db.add(User(
                email=email,
                full_name="Admin", role=UserRole.ADMIN,
            ))
            db.commit()
    client.cookies.clear()
    return bearer_for_email(TestingSessionLocal, email)


def _seed(**overrides):
    defaults = dict(
        slug="secret_crush", name="Secret Crush", tagline="Dites-le sans le dire",
        description="…", icon="favorite", accent_color="#E0245E",
        category="SOCIAL", is_enabled=True, is_recommended=False, position=0,
    )
    defaults.update(overrides)
    with TestingSessionLocal() as db:
        module = AppModule(**defaults)
        db.add(module)
        db.commit()
        return module.id


# ── Ce que l'utilisateur ne doit PAS voir ────────────────────────────────


def test_un_module_ferme_par_l_equipe_est_invisible(client):
    headers, _ = _signup(client, "+22894000001")
    _seed(slug="brouillon", is_enabled=False, is_recommended=True)

    catalogue = client.get("/api/v1/modules", headers=headers).json()
    # Dans AUCUN des trois rayons — y compris « recommandés », que le
    # drapeau éditorial aurait pu laisser passer.
    assert catalogue == {"mine": [], "recommended": [], "popular": []}


def test_on_ne_peut_pas_activer_un_module_ferme(client):
    headers, _ = _signup(client, "+22894000002")
    _seed(slug="brouillon", is_enabled=False)

    response = client.post("/api/v1/modules/brouillon/activate", headers=headers)
    # 404 et non 403 : un refus distinct révélerait l'existence d'un module
    # non publié.
    assert response.status_code == 404


def test_fermer_un_module_le_retire_meme_a_ceux_qui_l_avaient_active(client):
    headers, _ = _signup(client, "+22894000003")
    admin = _admin(client)
    _seed(slug="secret_crush")
    client.post("/api/v1/modules/secret_crush/activate", headers=headers)
    assert len(client.get("/api/v1/modules", headers=headers).json()["mine"]) == 1

    client.put("/api/v1/admin/modules/secret_crush", json={"is_enabled": False}, headers=admin)
    assert client.get("/api/v1/modules", headers=headers).json()["mine"] == []


def test_l_activation_survit_a_une_fermeture_temporaire(client):
    """On ne redemande pas à quelqu'un de réactiver ce qu'il avait choisi.

    C'est aussi la seule donnée qui permette de décider s'il faut rouvrir un
    module : combien de gens s'y intéressaient avant la fermeture.
    """
    headers, user_id = _signup(client, "+22894000004")
    admin = _admin(client)
    module_id = _seed(slug="secret_crush")
    client.post("/api/v1/modules/secret_crush/activate", headers=headers)

    client.put("/api/v1/admin/modules/secret_crush", json={"is_enabled": False}, headers=admin)
    with TestingSessionLocal() as db:
        assert db.query(UserModuleActivation).filter(
            UserModuleActivation.user_id == user_id,
            UserModuleActivation.module_id == module_id,
        ).count() == 1

    client.put("/api/v1/admin/modules/secret_crush", json={"is_enabled": True}, headers=admin)
    assert len(client.get("/api/v1/modules", headers=headers).json()["mine"]) == 1


# ── Les trois rayons ─────────────────────────────────────────────────────


def test_un_module_active_quitte_recommandes_et_populaires(client):
    """Recommander à quelqu'un ce qu'il utilise déjà est le plus sûr moyen
    de lui apprendre à ignorer la section."""
    headers, _ = _signup(client, "+22894000005")
    _seed(slug="secret_crush", is_recommended=True)

    before = client.get("/api/v1/modules", headers=headers).json()
    assert [m["slug"] for m in before["recommended"]] == ["secret_crush"]

    client.post("/api/v1/modules/secret_crush/activate", headers=headers)
    after = client.get("/api/v1/modules", headers=headers).json()
    assert [m["slug"] for m in after["mine"]] == ["secret_crush"]
    assert after["recommended"] == []
    assert after["popular"] == []


def test_populaires_est_trie_par_nombre_d_utilisateurs(client):
    _seed(slug="peu_utilise", name="Peu", position=0)
    _seed(slug="tres_utilise", name="Beaucoup", position=1)

    for phone in ("+22894000010", "+22894000011", "+22894000012"):
        other, _ = _signup(client, phone)
        client.post("/api/v1/modules/tres_utilise/activate", headers=other)
    solo, _ = _signup(client, "+22894000013")
    client.post("/api/v1/modules/peu_utilise/activate", headers=solo)

    viewer, _ = _signup(client, "+22894000014")
    popular = client.get("/api/v1/modules", headers=viewer).json()["popular"]
    assert [m["slug"] for m in popular] == ["tres_utilise", "peu_utilise"]
    assert popular[0]["user_count"] == 3


def test_activer_deux_fois_ne_produit_pas_d_erreur(client):
    headers, _ = _signup(client, "+22894000006")
    _seed(slug="secret_crush")

    assert client.post("/api/v1/modules/secret_crush/activate", headers=headers).status_code == 200
    # Un double appui sur un interrupteur ne doit pas produire une erreur
    # pour un état déjà obtenu.
    assert client.post("/api/v1/modules/secret_crush/activate", headers=headers).status_code == 200
    assert len(client.get("/api/v1/modules", headers=headers).json()["mine"]) == 1


def test_desactiver_retire_bien_le_module(client):
    headers, _ = _signup(client, "+22894000007")
    _seed(slug="secret_crush")
    client.post("/api/v1/modules/secret_crush/activate", headers=headers)

    client.delete("/api/v1/modules/secret_crush/activate", headers=headers)
    assert client.get("/api/v1/modules", headers=headers).json()["mine"] == []


# ── Administration ───────────────────────────────────────────────────────


def test_l_equipe_voit_aussi_les_modules_non_publies(client):
    admin = _admin(client)
    _seed(slug="brouillon", is_enabled=False)

    items = client.get("/api/v1/admin/modules", headers=admin).json()["items"]
    # C'est la différence avec la route utilisateur, et c'est ce qui permet
    # de préparer un module avant de le publier.
    assert [m["slug"] for m in items] == ["brouillon"]
    assert items[0]["is_enabled"] is False


def test_un_simple_utilisateur_n_atteint_pas_l_administration(client):
    headers, _ = _signup(client, "+22894000008")
    assert client.get("/api/v1/admin/modules", headers=headers).status_code == 403
    _seed(slug="secret_crush")
    assert client.put(
        "/api/v1/admin/modules/secret_crush", json={"is_enabled": False}, headers=headers
    ).status_code == 403
