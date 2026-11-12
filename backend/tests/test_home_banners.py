"""Le carrousel de l'accueil : des bannières par pays et par région, gérées
depuis la console."""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AuditLog, HomeBanner, User, UserRole
from app.services.auth import otp_service
from tests.helpers import console_bearer

engine = create_engine("sqlite:///./test_pokou_banners.db", connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _db
    yield TestClient(app)
    if previous is None:
        app.dependency_overrides.pop(get_db, None)
    else:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone, role=None):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    if role:
        with TestingSessionLocal() as db:
            db.query(User).filter(User.id == body["user"]["id"]).update({User.role: role})
            db.commit()
        return console_bearer(TestingSessionLocal, body["user"]["id"]), body["user"]["id"]
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _create(client, admin, **fields):
    response = client.post("/api/v1/admin/banners", json={"title": "Promo", **fields}, headers=admin)
    assert response.status_code == 200, response.text
    return response.json()


def _titles(client, headers, **params):
    response = client.get("/api/v1/home/banners", headers=headers, params=params)
    assert response.status_code == 200, response.text
    return [item["title"] for item in response.json()["items"]]


def test_chacun_voit_les_bannieres_de_son_pays_et_celles_de_partout(client):
    admin, _ = _signup(client, "+22890600001", UserRole.ADMIN)
    togo, _ = _signup(client, "+22890600002")
    ivoire, _ = _signup(client, "+2250700000003")
    _create(client, admin, title="Partout")
    _create(client, admin, title="Togo", country="tg")
    _create(client, admin, title="Côte d'Ivoire", country="CI")

    assert set(_titles(client, togo)) == {"Partout", "Togo"}
    assert set(_titles(client, ivoire)) == {"Partout", "Côte d'Ivoire"}
    assert client.get("/api/v1/home/banners", headers=togo).json()["country"] == "TG"


def test_une_banniere_regionale_ne_va_qu_a_sa_region(client):
    admin, _ = _signup(client, "+22890600011", UserRole.ADMIN)
    user, _ = _signup(client, "+22890600012")
    _create(client, admin, title="Kara", country="TG", region="Kara")
    _create(client, admin, title="Lomé", country="TG", region="Lomé")
    _create(client, admin, title="Togo", country="TG")

    # Région inconnue : seulement le national.
    assert _titles(client, user) == ["Togo"]
    # Région connue — sans tenir compte de la casse ni des accents — et la
    # plus précise passe en tête.
    assert _titles(client, user, region="lome") == ["Lomé", "Togo"]


def test_hors_periode_ou_desactivee_une_banniere_ne_s_affiche_pas(client):
    admin, _ = _signup(client, "+22890600021", UserRole.ADMIN)
    user, _ = _signup(client, "+22890600022")
    now = datetime.utcnow()
    _create(client, admin, title="En cours", starts_at=(now - timedelta(days=1)).isoformat(),
            ends_at=(now + timedelta(days=1)).isoformat())
    _create(client, admin, title="Pas encore", starts_at=(now + timedelta(days=1)).isoformat())
    _create(client, admin, title="Terminée", ends_at=(now - timedelta(hours=1)).isoformat())
    off = _create(client, admin, title="Coupée")
    client.put(f"/api/v1/admin/banners/{off['id']}", json={"title": "Coupée", "is_active": False}, headers=admin)

    assert _titles(client, user) == ["En cours"]


def test_l_ordre_suit_la_position(client):
    admin, _ = _signup(client, "+22890600031", UserRole.ADMIN)
    user, _ = _signup(client, "+22890600032")
    _create(client, admin, title="Deuxième", position=2)
    _create(client, admin, title="Première", position=1)

    assert _titles(client, user) == ["Première", "Deuxième"]


def test_seule_l_equipe_habilitee_gere_les_bannieres(client):
    admin, _ = _signup(client, "+22890600041", UserRole.ADMIN)
    viewer, _ = _signup(client, "+22890600042", UserRole.VIEWER)
    user, _ = _signup(client, "+22890600043")
    banner = _create(client, admin, title="Promo")

    assert client.get("/api/v1/admin/banners", headers=user).status_code == 403
    assert client.get("/api/v1/admin/banners", headers=viewer).status_code == 200
    assert client.post("/api/v1/admin/banners", json={"title": "x"}, headers=viewer).status_code == 403
    assert client.delete(f"/api/v1/admin/banners/{banner['id']}", headers=viewer).status_code == 403
    assert client.delete(f"/api/v1/admin/banners/{banner['id']}", headers=admin).status_code == 200
    with TestingSessionLocal() as db:
        assert db.query(HomeBanner).count() == 0
        actions = {row.action for row in db.query(AuditLog).filter(AuditLog.entity_type == "home_banner")}
    assert actions == {"banner_create", "banner_delete"}


@pytest.mark.parametrize("url", ["http://exemple.com", "javascript:alert(1)", "app:reglages", "exemple.com"])
def test_un_lien_dangereux_est_refuse(client, url):
    admin, _ = _signup(client, "+22890600051", UserRole.ADMIN)
    response = client.post("/api/v1/admin/banners", json={"title": "Promo", "cta_url": url}, headers=admin)
    assert response.status_code == 422


def test_l_image_d_une_banniere_en_cours_est_visible_de_tous(client):
    admin, _ = _signup(client, "+22890600061", UserRole.ADMIN)
    user, _ = _signup(client, "+22890600062")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("promo.jpg", b"\xff\xd8\xff\xe0fake-jpeg-bytes", "image/jpeg")},
        headers=admin,
    )
    assert uploaded.status_code == 200, uploaded.text
    media_id = uploaded.json()["id"]

    # Pas encore attachée à une bannière : privée.
    assert client.get(f"/api/v1/media/{media_id}", headers=user).status_code in (403, 404)

    banner = _create(client, admin, title="Promo", image_media_id=media_id)
    assert banner["image"]["id"] == media_id
    assert client.get(f"/api/v1/media/{media_id}", headers=user).status_code == 200

    # Coupée : l'image redevient privée.
    client.put(f"/api/v1/admin/banners/{banner['id']}", json={"title": "Promo", "image_media_id": media_id,
                                                              "is_active": False}, headers=admin)
    assert client.get(f"/api/v1/media/{media_id}", headers=user).status_code in (403, 404)
