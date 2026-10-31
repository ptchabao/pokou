from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import DeviceToken
from app.services.auth import otp_service
from app.services.notifications import push_service

TEST_DATABASE_URL = "sqlite:///./test_device_tokens.db"

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
    # L'override est posé PAR TEST et retiré ensuite, jamais au niveau du
    # module : pytest importe tous les fichiers de test avant d'en exécuter
    # un seul, donc une affectation au niveau module est écrasée par celle
    # du dernier fichier importé. Toutes les suites se retrouvaient alors à
    # lire la base d'une autre — ce qui ne se voit qu'en lançant la suite
    # entière, et jamais un fichier seul.
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
    import re
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    response = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    body = response.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _signup_with_tokens(client, phone):
    """Comme `_signup`, mais rend la réponse ENTIÈRE.

    `_signup` ne retient que l'en-tête d'autorisation, et une douzaine de
    tests en dépendent — le modifier les toucherait tous. Ici on a besoin du
    jeton de rafraîchissement, donc de la même session que celle qui
    enregistre l'appareil."""
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    import re
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    return client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()


def test_register_device_token_requires_auth(client):
    response = client.post("/api/v1/devices/register", json={"token": "abc"})
    assert response.status_code == 401


def test_register_device_token_persists_it(client):
    headers, user_id = _signup(client, "+22890000101")

    response = client.post("/api/v1/devices/register", json={"token": "fcm-token-1"}, headers=headers)
    assert response.status_code == 200

    db = TestingSessionLocal()
    try:
        stored = db.query(DeviceToken).filter(DeviceToken.token == "fcm-token-1").first()
        assert stored is not None
        assert stored.user_id == user_id
        assert stored.platform == "android"
    finally:
        db.close()


def test_registering_the_same_token_again_reattaches_it_instead_of_duplicating(client):
    headers_a, user_a = _signup(client, "+22890000102")
    headers_b, user_b = _signup(client, "+22890000103")

    client.post("/api/v1/devices/register", json={"token": "shared-device"}, headers=headers_a)
    client.post("/api/v1/devices/register", json={"token": "shared-device"}, headers=headers_b)

    db = TestingSessionLocal()
    try:
        rows = db.query(DeviceToken).filter(DeviceToken.token == "shared-device").all()
        assert len(rows) == 1
        assert rows[0].user_id == user_b
    finally:
        db.close()


def test_send_push_is_a_silent_noop_when_fcm_is_not_configured(client):
    headers, user_id = _signup(client, "+22890000104")
    client.post("/api/v1/devices/register", json={"token": "some-token"}, headers=headers)

    db = TestingSessionLocal()
    try:
        # fcm_enabled defaults to False in Settings — should not raise.
        push_service.send_push(db, user_id, title="Test", body="Hello")
    finally:
        db.close()


# ─── Appareils connectés (Profil > Appareils connectés) ──────────────────────

def test_devices_list_is_empty_before_any_registration(client):
    headers, _ = _signup(client, "+22894000010")
    response = client.get("/api/v1/devices", headers=headers)
    assert response.status_code == 200
    assert response.json() == {"items": []}


def test_devices_list_marks_the_calling_device_and_masks_tokens(client):
    headers, _ = _signup(client, "+22894000011")
    client.post("/api/v1/devices/register", json={"token": "token-de-ce-telephone-ABC123"}, headers=headers)
    client.post(
        "/api/v1/devices/register",
        json={"token": "token-de-la-tablette-XYZ789", "platform": "ios"},
        headers=headers,
    )

    items = client.get(
        "/api/v1/devices?current_token=token-de-ce-telephone-ABC123", headers=headers
    ).json()["items"]
    assert len(items) == 2
    current = [item for item in items if item["is_current"]]
    assert len(current) == 1
    assert current[0]["platform"] == "android"
    # Le jeton complet est un secret d'envoi : seule une empreinte sort.
    assert current[0]["token_hint"] == "ABC123"
    assert all("token-de-" not in str(item) for item in items)


def test_devices_list_only_shows_my_own_devices(client):
    headers_a, _ = _signup(client, "+22894000012")
    headers_b, _ = _signup(client, "+22894000013")
    client.post("/api/v1/devices/register", json={"token": "jeton-de-a"}, headers=headers_a)
    client.post("/api/v1/devices/register", json={"token": "jeton-de-b"}, headers=headers_b)

    items = client.get("/api/v1/devices", headers=headers_a).json()["items"]
    assert len(items) == 1
    assert items[0]["token_hint"] == "n-de-a"


def test_revoking_a_device_le_DECONNECTE_vraiment(client):
    """Révoquer un appareil, c'est le déconnecter — pas le rendre silencieux.

    La route ne supprimait que le jeton de notification. L'appareil perdait
    ses notifications et gardait TOUT le reste : lire les conversations,
    écrire, renouveler sa session pendant sept jours. Quelqu'un qui révoquait
    un téléphone perdu croyait avoir fermé la porte.
    """
    headers, user_id = _signup(client, "+22894000014")
    client.post("/api/v1/devices/register", json={"token": "jeton-a-revoquer"}, headers=headers)
    device_id = client.get("/api/v1/devices", headers=headers).json()["items"][0]["id"]

    reponse = client.delete(f"/api/v1/devices/{device_id}", headers=headers).json()
    assert reponse["revoked"] is True
    assert reponse["session_revoked"] is True, "la session de l'appareil doit tomber aussi"

    db = TestingSessionLocal()
    try:
        assert db.query(DeviceToken).filter(DeviceToken.user_id == user_id).count() == 0
    finally:
        db.close()

    # La suite du test se fait SANS cookie : le client de test en garde un de
    # la connexion, qui authentifierait la requête à la place de l'en-tête et
    # masquerait la révocation.
    client.cookies.clear()
    assert client.get("/api/v1/devices", headers=headers).status_code == 401, (
        "le jeton de l'appareil révoqué ne doit plus ouvrir aucune porte"
    )


def test_un_appareil_revoque_ne_peut_plus_renouveler_sa_session(client):
    """La contrepartie : sans ce contrôle, l'appareil se relancerait tout
    seul au prochain rafraîchissement et la révocation ne durerait que
    trente minutes."""
    # UNE SEULE session, et c'est tout le sujet : l'appareil est enregistré,
    # révoqué et testé avec les jetons de la MÊME session. Deux sessions
    # différentes feraient passer le test pour de mauvaises raisons — on
    # révoquerait l'une en éprouvant l'autre.
    jetons = _signup_with_tokens(client, "+22894000018")
    headers = {"Authorization": f"Bearer {jetons['access_token']}"}
    client.post("/api/v1/devices/register", json={"token": "jeton-du-perdu"}, headers=headers)
    device_id = client.get("/api/v1/devices", headers=headers).json()["items"][0]["id"]

    client.delete(f"/api/v1/devices/{device_id}", headers=headers)
    client.cookies.clear()

    refus = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {jetons['refresh_token']}"},
    )
    # 403 et non 401 : /auth/refresh convertit tout refus en « Invalid
    # refresh token », volontairement indistinct, pour ne pas dire à qui
    # présente un jeton s'il est périmé, révoqué, ou d'un autre type.
    assert refus.status_code == 403


def test_cannot_revoke_someone_elses_device(client):
    headers_a, _ = _signup(client, "+22894000015")
    headers_b, _ = _signup(client, "+22894000016")
    client.post("/api/v1/devices/register", json={"token": "jeton-de-a-prive"}, headers=headers_a)
    device_id = client.get("/api/v1/devices", headers=headers_a).json()["items"][0]["id"]

    # 404 et non 403 : ne pas révéler qu'un id existe sur un autre compte.
    assert client.delete(f"/api/v1/devices/{device_id}", headers=headers_b).status_code == 404
    assert len(client.get("/api/v1/devices", headers=headers_a).json()["items"]) == 1


def test_revoking_an_unknown_device_is_404(client):
    headers, _ = _signup(client, "+22894000017")
    assert client.delete("/api/v1/devices/999999", headers=headers).status_code == 404


def test_devices_endpoints_require_authentication(client):
    assert client.get("/api/v1/devices").status_code in (401, 403)
    assert client.delete("/api/v1/devices/1").status_code in (401, 403)
