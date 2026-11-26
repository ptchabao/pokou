"""L'identité de la base : stable, et différente d'une base à l'autre."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_instance_id_is_stable_and_public():
    first = client.get("/api/v1/instance")
    assert first.status_code == 200
    value = first.json()["instance_id"]
    assert len(value) == 32
    assert client.get("/api/v1/instance").json()["instance_id"] == value
