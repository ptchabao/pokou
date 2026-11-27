"""Les packs Pokoumoji : seuls les chemins du contrat sont servis."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_manifeste_et_image_du_pack_dev():
    r = client.get("/pokoumoji/packs/dev/manifest.json")
    assert r.status_code == 200
    assert r.json()["status"] == "placeholder"
    assert client.get("/pokoumoji/packs/dev/manifest.sig").status_code == 200
    img = client.get("/pokoumoji/packs/dev/128/assets/kimia/kimia_joie.webp")
    assert img.status_code == 200
    assert img.headers["content-type"] == "image/webp"
    assert img.content[:4] == b"RIFF"


def test_chemins_hors_contrat_refuses():
    for path in [
        "dev/128/assets/kimia/../../manifest.json",
        "dev/512/assets/kimia/kimia_joie.webp",
        "dev/128/assets/kimia/kimia_joie.png",
        "autre/manifest.json",
        "dev/LISEZMOI.md",
    ]:
        assert client.get(f"/pokoumoji/packs/{path}").status_code == 404, path


def test_canal_prod_signe_en_production():
    r = client.get("/pokoumoji/packs/prod/manifest.json")
    assert r.status_code == 200
    assert r.json()["status"] == "production"
    assert r.json()["signature"]["key_id"] == "pokoumoji-prod"
