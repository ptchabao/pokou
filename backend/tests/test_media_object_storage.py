"""Pokou — pièces jointes stockées dans un stockage objet S3-compatible
(MinIO en production, S3 simulé par moto ici).

Les deux backends sont testés dans le même fichier, parce que ce qui compte
n'est pas que chacun marche isolément mais que la BASCULE se fasse sans
casser l'existant : une pièce jointe déposée sur disque avant la bascule doit
rester lisible après."""
import re
from unittest.mock import patch

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import Settings
from app.core.database import Base, get_db
from app.main import app
from app.models import MediaAsset
from app.services.media import media_storage, object_storage
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_media_object_storage.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

BUCKET = "pokou-media-test"


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    """L'override est posé PAR TEST et non à l'import du module, contrairement
    aux autres suites : `app` est un singleton partagé, donc quand plusieurs
    modules s'installent à l'import c'est le dernier importé qui gagne pour
    tout le monde. Ce module relit la base directement (voir `_asset`), il lui
    faut donc la certitude que l'app écrit bien dans SON moteur. L'override
    précédent est restauré à la sortie pour ne pas casser les suites
    suivantes."""
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


# Endpoint AWS et non une URL MinIO : le mock en-processus de moto
# n'intercepte que les endpoints AWS reconnus — pointer sur un hôte
# quelconque partirait vraiment sur le réseau. Le code exercé est le même
# (même client, même style d'adressage, même signature v4) ; seule l'URL
# change, et en production c'est celle de MinIO qui est lue depuis .env.
TEST_ENDPOINT = "https://s3.amazonaws.com"


def _object_storage_settings(**overrides):
    """Réglages avec stockage objet activé. `Settings` réel et non MagicMock :
    on veut que la vraie logique de is_enabled() soit exercée."""
    values = {
        "s3_endpoint_url": TEST_ENDPOINT,
        "s3_access_key": "test-access-key",
        "s3_secret_key": "test-secret-key",
        "s3_bucket": BUCKET,
        "s3_region": "us-east-1",
    }
    values.update(overrides)
    return Settings(**values)


class _ObjectStorageEnabled:
    """Active le stockage objet pour la durée du bloc, sur un S3 simulé.

    `reset_client_cache()` à l'entrée ET à la sortie : le client boto3 et la
    vérification de bucket sont mémoïsés par @lru_cache, donc un client
    construit sous moto fuirait sur les tests suivants (et inversement)."""

    def __init__(self, **overrides):
        self._settings = _object_storage_settings(**overrides)
        self._mock = mock_aws()
        self._patches = []

    def __enter__(self):
        self._mock.start()
        object_storage.reset_client_cache()
        for target in ("app.services.media.object_storage.get_settings", "app.core.config.get_settings"):
            patcher = patch(target, return_value=self._settings)
            patcher.start()
            self._patches.append(patcher)
        return self

    def __exit__(self, *exc_info):
        for patcher in reversed(self._patches):
            patcher.stop()
        object_storage.reset_client_cache()
        self._mock.stop()
        return False


def _upload(client, headers, content=b"contenu-de-la-piece-jointe", filename="facture.jpg"):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": (filename, content, "image/jpeg")},
        headers=headers,
    )


def _asset(asset_id):
    db = TestingSessionLocal()
    try:
        return db.query(MediaAsset).filter(MediaAsset.id == asset_id).first()
    finally:
        db.close()


# ─── Bascule ─────────────────────────────────────────────────────────────────

def test_upload_goes_to_object_storage_when_configured(client):
    headers, _ = _signup(client, "+22895000001")

    with _ObjectStorageEnabled():
        uploaded = _upload(client, headers)
        assert uploaded.status_code == 200, uploaded.text
        asset_id = uploaded.json()["id"]

        asset = _asset(asset_id)
        assert asset.storage_backend == "s3"
        # Clé préfixée : le bucket reste navigable si d'autres usages
        # viennent s'y ajouter.
        assert asset.storage_path.startswith("pokou/media/")

        # Le contenu est réellement dans le bucket, pas seulement en base.
        s3 = boto3.client("s3", endpoint_url=TEST_ENDPOINT, region_name="us-east-1")
        stored = s3.get_object(Bucket=BUCKET, Key=asset.storage_path)["Body"].read()
        assert stored == b"contenu-de-la-piece-jointe"


def test_upload_falls_back_to_local_disk_when_not_configured(client):
    """Sans endpoint ni clés, rien ne change : c'est ce qui fait tourner les
    tests et un poste de dev sans MinIO."""
    headers, _ = _signup(client, "+22895000002")
    uploaded = _upload(client, headers)
    assert uploaded.status_code == 200

    asset = _asset(uploaded.json()["id"])
    assert asset.storage_backend == "local"
    assert media_storage.resolve_path(asset) is not None


def test_bucket_is_created_on_first_upload(client):
    headers, _ = _signup(client, "+22895000003")

    with _ObjectStorageEnabled():
        s3 = boto3.client("s3", endpoint_url=TEST_ENDPOINT, region_name="us-east-1")
        assert BUCKET not in [b["Name"] for b in s3.list_buckets()["Buckets"]]

        assert _upload(client, headers).status_code == 200
        assert BUCKET in [b["Name"] for b in s3.list_buckets()["Buckets"]]


# ─── Lecture ─────────────────────────────────────────────────────────────────

def test_download_streams_the_object_back(client):
    headers, _ = _signup(client, "+22895000004")

    with _ObjectStorageEnabled():
        asset_id = _upload(client, headers, content=b"des-octets-de-photo").json()["id"]

        response = client.get(f"/api/v1/media/{asset_id}", headers=headers)
        assert response.status_code == 200
        assert response.content == b"des-octets-de-photo"
        assert response.headers["content-type"].startswith("image/jpeg")
        # Content-Length repris du stockage : le client peut afficher une
        # progression de téléchargement.
        assert response.headers["content-length"] == str(len(b"des-octets-de-photo"))


def test_locally_stored_attachment_stays_readable_after_the_switch(client):
    """Le vrai risque de la bascule : les pièces jointes d'avant. Elles n'ont
    pas d'objet dans le bucket et doivent continuer à être servies du disque."""
    headers, _ = _signup(client, "+22895000005")

    before = _upload(client, headers, content=b"depose-avant-la-bascule").json()["id"]
    assert _asset(before).storage_backend == "local"

    with _ObjectStorageEnabled():
        after = _upload(client, headers, content=b"depose-apres-la-bascule").json()["id"]
        assert _asset(after).storage_backend == "s3"

        # Les deux se lisent, chacune depuis son propre stockage.
        assert client.get(f"/api/v1/media/{before}", headers=headers).content == b"depose-avant-la-bascule"
        assert client.get(f"/api/v1/media/{after}", headers=headers).content == b"depose-apres-la-bascule"


def test_object_storage_download_still_enforces_access_control(client):
    """Le relais par l'API existe pour ça : le contrôle d'accès de
    /media/{id} reste la seule porte d'entrée, aucune URL présignée ne
    circule hors de lui."""
    headers_a, _ = _signup(client, "+22895000006")
    headers_b, _ = _signup(client, "+22895000007")

    with _ObjectStorageEnabled():
        asset_id = _upload(client, headers_a, content=b"prive").json()["id"]
        # B n'est ni l'auteur, ni destinataire d'un message la portant.
        assert client.get(f"/api/v1/media/{asset_id}", headers=headers_b).status_code == 404


# ─── Pannes ──────────────────────────────────────────────────────────────────

def test_upload_returns_503_when_object_storage_is_unreachable(client):
    """503 et non 400 : la requête du client est valide, c'est le stockage
    qui est en panne — il peut réessayer telle quelle."""
    headers, _ = _signup(client, "+22895000008")

    with _ObjectStorageEnabled():
        with patch.object(
            object_storage, "put_object", side_effect=OSError("connexion refusée")
        ):
            response = _upload(client, headers)
    assert response.status_code == 503
    assert "indisponible" in response.json()["detail"]


def test_nothing_is_recorded_in_database_when_the_write_fails(client):
    """Une pièce jointe référencée en base mais absente du stockage
    s'afficherait comme une image cassée à jamais."""
    headers, _ = _signup(client, "+22895000009")

    db = TestingSessionLocal()
    try:
        before = db.query(MediaAsset).count()
    finally:
        db.close()

    with _ObjectStorageEnabled():
        with patch.object(object_storage, "put_object", side_effect=OSError("panne")):
            _upload(client, headers)

    db = TestingSessionLocal()
    try:
        assert db.query(MediaAsset).count() == before
    finally:
        db.close()


def test_download_returns_503_when_the_object_cannot_be_read(client):
    headers, _ = _signup(client, "+22895000010")

    with _ObjectStorageEnabled():
        asset_id = _upload(client, headers).json()["id"]
        with patch.object(object_storage, "open_stream", side_effect=OSError("panne")):
            response = client.get(f"/api/v1/media/{asset_id}", headers=headers)
    assert response.status_code == 503


def test_upload_still_validates_type_and_size_before_touching_storage(client):
    """Les garde-fous existants ne doivent pas dépendre du backend."""
    headers, _ = _signup(client, "+22895000011")

    with _ObjectStorageEnabled():
        mismatched = client.post(
            "/api/v1/media/upload",
            data={"message_type": "IMAGE"},
            files={"file": ("notes.txt", b"pas une image", "text/plain")},
            headers=headers,
        )
        assert mismatched.status_code == 400

        empty = client.post(
            "/api/v1/media/upload",
            data={"message_type": "DOCUMENT"},
            files={"file": ("vide.pdf", b"", "application/pdf")},
            headers=headers,
        )
        assert empty.status_code == 400


def test_is_enabled_requires_every_credential(client):
    """Un endpoint sans clés (ou l'inverse) ne doit PAS activer à moitié le
    stockage objet : on retombe proprement sur le disque."""
    with patch("app.services.media.object_storage.get_settings", return_value=_object_storage_settings()):
        assert object_storage.is_enabled() is True
    for missing in ("s3_endpoint_url", "s3_access_key", "s3_secret_key"):
        with patch(
            "app.services.media.object_storage.get_settings",
            return_value=_object_storage_settings(**{missing: ""}),
        ):
            assert object_storage.is_enabled() is False, missing
