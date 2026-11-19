"""Une position traduite en nom de lieu — Nominatim simulé."""
import re
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.api.v1.config import geo
from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

engine = create_engine("sqlite:///./test_geo.db", connect_args={"check_same_thread": False})
Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _db():
    db = Session()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _db
    geo._cache.clear()
    yield TestClient(app)
    if previous is None:
        app.dependency_overrides.pop(get_db, None)
    else:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": "+22890990001"})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": "+22890990001", "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}


def _fake_client(payload=None, fail=False):
    response = MagicMock()
    response.raise_for_status = MagicMock(side_effect=Exception("down") if fail else None)
    response.json.return_value = payload or {}
    instance = MagicMock()
    instance.get = AsyncMock(return_value=response)
    instance.__aenter__ = AsyncMock(return_value=instance)
    instance.__aexit__ = AsyncMock(return_value=False)
    return MagicMock(return_value=instance), instance


def test_la_position_devient_quartier_et_ville(client):
    headers = _signup(client)
    factory, instance = _fake_client({"address": {"suburb": "Bè", "city": "Lomé", "country_code": "tg"}})
    with patch.object(geo.httpx, "AsyncClient", factory):
        body = client.get("/api/v1/geo/reverse?lat=6.1319&lon=1.2228", headers=headers).json()
        assert body["label"] == "Bè, Lomé" and body["country_code"] == "TG"
        # Même quartier : servi par le cache, sans nouvel appel.
        client.get("/api/v1/geo/reverse?lat=6.13191&lon=1.22281", headers=headers)
    assert instance.get.await_count == 1


def test_sans_reponse_rien_n_est_invente(client):
    headers = _signup(client)
    factory, _ = _fake_client(fail=True)
    with patch.object(geo.httpx, "AsyncClient", factory):
        body = client.get("/api/v1/geo/reverse?lat=6.1&lon=1.2", headers=headers).json()
    assert body["label"] is None


def test_il_faut_etre_connecte(client):
    assert client.get("/api/v1/geo/reverse?lat=6.1&lon=1.2").status_code == 401
