"""Pokou — aperçu de lien (api/app/routes/link_preview.py).

Le point qui compte : le serveur récupère une URL fournie par n'importe quel
utilisateur, donc les protections SSRF (schéma, résolution IP) sont testées
directement, sans réseau. Le succès HTML, lui, est testé avec `httpx.AsyncClient`
mocké — pas de dépendance à un vrai site externe pendant la suite."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.api.v1.messaging.link_preview import _is_public_hostname, _validate_url
from app.services.auth import otp_service
from fastapi import HTTPException

TEST_DATABASE_URL = "sqlite:///./test_link_preview.db"

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
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}


# ─── Garde-fou SSRF — pas de réseau, la logique de résolution suffit ────────────

def test_rejects_non_http_schemes():
    with pytest.raises(HTTPException) as exc:
        _validate_url("ftp://example.com/file")
    assert exc.value.status_code == 400


@pytest.mark.parametrize(
    "hostname",
    ["localhost", "127.0.0.1", "169.254.169.254", "10.0.0.5", "192.168.1.1", "::1"],
)
def test_rejects_private_loopback_and_link_local_hosts(hostname):
    assert _is_public_hostname(hostname) is False


def test_a_public_hostname_is_accepted():
    # example.com est réservé par l'IANA précisément pour ce genre d'usage :
    # une résolution DNS réelle mais un contenu stable, jamais privé.
    assert _is_public_hostname("example.com") is True


def test_validate_url_rejects_a_url_whose_hostname_resolves_privately():
    with pytest.raises(HTTPException) as exc:
        _validate_url("http://127.0.0.1/anything")
    assert exc.value.status_code == 400


# ─── Route — authentification requise, récupération mockée ──────────────────────

def test_link_preview_requires_authentication(client):
    assert client.get("/api/v1/link-preview", params={"url": "https://example.com"}).status_code in (401, 403)


def test_link_preview_extracts_open_graph_metadata(client):
    headers = _signup(client, "+22896100001")
    html = (
        "<html><head>"
        '<meta property="og:title" content="Super article">'
        '<meta property="og:description" content="Un aper\u00e7u de test">'
        '<meta property="og:image" content="https://cdn.example.com/img.png">'
        "</head></html>"
    ).encode("utf-8")

    class _FakeResponse:
        is_redirect = False
        encoding = "utf-8"
        headers = {"content-type": "text/html; charset=utf-8"}

        async def aiter_bytes(self):
            yield html

    class _FakeStream:
        def __init__(self, response):
            self._response = response

        async def __aenter__(self):
            return self._response

        async def __aexit__(self, *exc_info):
            return False

    class _FakeAsyncClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *exc_info):
            return False

        def stream(self, method, url):
            return _FakeStream(_FakeResponse())

    with patch("app.api.v1.messaging.link_preview.httpx.AsyncClient", _FakeAsyncClient):
        response = client.get(
            "/api/v1/link-preview", params={"url": "https://example.com/article"}, headers=headers
        )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["title"] == "Super article"
    assert body["description"] == "Un aper\u00e7u de test"
    assert body["image"] == "https://cdn.example.com/img.png"


def test_link_preview_rejects_a_private_ip_link(client):
    headers = _signup(client, "+22896100002")
    response = client.get("/api/v1/link-preview", params={"url": "http://127.0.0.1/"}, headers=headers)
    assert response.status_code == 400


def test_link_preview_degrades_gracefully_when_unreachable(client):
    """Un lien mort ne doit jamais faire échouer l'affichage du message :
    l'aperçu manquant se traduit par des champs null, pas une erreur."""
    headers = _signup(client, "+22896100003")

    class _FailingAsyncClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *exc_info):
            return False

        def stream(self, method, url):
            raise OSError("connexion refusée")

    with patch("app.api.v1.messaging.link_preview.httpx.AsyncClient", _FailingAsyncClient):
        response = client.get(
            "/api/v1/link-preview", params={"url": "https://example.com/deja-mort"}, headers=headers
        )
    assert response.status_code == 200
    assert response.json() == {"url": "https://example.com/deja-mort", "title": None, "description": None, "image": None}
