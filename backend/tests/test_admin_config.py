"""Console : configuration des pays, réglages système, gestion des comptes et
de l'équipe. Droits refusés, validation, audit et effet de chaque route."""
import json
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.core.security import hash_password
from app.main import app
from app.models import AuditLog, DeviceToken, MediaAsset, SystemSetting, Token, User, UserRole
from app.services.auth import otp_service
from tests.helpers import console_bearer

engine = create_engine("sqlite:///./test_pokou_admin_config.db", connect_args={"check_same_thread": False})
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
            db.query(User).filter(User.id == body["user"]["id"]).update(
                {User.role: role, User.console_password_hash: hash_password("motdepasse-solide")})
            db.commit()
        return console_bearer(TestingSessionLocal, body["user"]["id"]), body["user"]["id"]
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _last_audit():
    with TestingSessionLocal() as db:
        return db.query(AuditLog).order_by(AuditLog.id.desc()).first()


def _country_body(**patch_):
    body = {
        "currency": "XOF", "vat_rate": 0.18, "delivery_price": 1200,
        "pharmacy_monthly_price": 6000, "pharmacy_yearly_price": 60000,
        "kory_plus_fee_ht": 1500, "honam_cities": ["Lomé", " Kara ", "lomé"],
        "emergency_numbers": {"police": "117", "pompiers": "118", "samu": None},
        "modules": ["discussions", "assime"],
    }
    body.update(patch_)
    return body


# ── Pays ─────────────────────────────────────────────────────────────────

def test_pays_droits(client):
    viewer, _ = _signup(client, "+22890600001", UserRole.VIEWER)
    app_user, _ = _signup(client, "+22890600002")
    assert client.get("/api/v1/admin/countries", headers=app_user).status_code == 403
    listing = client.get("/api/v1/admin/countries", headers=viewer)
    assert listing.status_code == 200
    assert {"TG", "CI"} <= {c["code"] for c in listing.json()["items"]}
    assert client.get("/api/v1/admin/countries/TG", headers=viewer).status_code == 200
    assert client.put("/api/v1/admin/countries/TG", json=_country_body(), headers=viewer).status_code == 403
    assert client.delete("/api/v1/admin/countries/TG", headers=viewer).status_code == 403


def test_pays_modifier_ajouter_et_revenir(client):
    admin, _ = _signup(client, "+22890600003", UserRole.ADMIN)
    done = client.put("/api/v1/admin/countries/tg", json=_country_body(), headers=admin)
    assert done.status_code == 200, done.text
    config = done.json()["config"]
    assert config["delivery_price"] == 1200 and config["kory_plus_fee_ht"] == 1500
    assert config["honam_cities"] == ["Lomé", "Kara"]
    assert config["emergency_numbers"] == {"police": "117", "pompiers": "118"}
    # Kory et HONAM restent ouverts quoi qu'on coche.
    assert config["modules"] == ["discussions", "kory", "honam", "assime"]
    with TestingSessionLocal() as db:
        stored = json.loads(db.query(SystemSetting).filter(SystemSetting.key == "country.TG").one().value)
        assert stored["delivery_price"] == 1200
    audit = _last_audit()
    assert audit.action == "country_update" and audit.changes["country"] == "TG"
    assert audit.changes["changes"]["delivery_price"] == {"from": 1000, "to": 1200}

    # Un nouveau pays apparaît dans la liste.
    assert client.put("/api/v1/admin/countries/SN", json=_country_body(), headers=admin).status_code == 200
    codes = {c["code"] for c in client.get("/api/v1/admin/countries", headers=admin).json()["items"]}
    assert "SN" in codes

    # Retour aux valeurs par défaut.
    reset = client.delete("/api/v1/admin/countries/TG", headers=admin)
    assert reset.status_code == 200 and reset.json()["config"]["delivery_price"] == 1000
    assert _last_audit().action == "country_reset"
    assert client.delete("/api/v1/admin/countries/TG", headers=admin).status_code == 404
    client.delete("/api/v1/admin/countries/SN", headers=admin)
    codes = {c["code"] for c in client.get("/api/v1/admin/countries", headers=admin).json()["items"]}
    assert "SN" not in codes


@pytest.mark.parametrize("patch_", [
    {"modules": ["discussions", "casino"]},
    {"vat_rate": 0.9},
    {"vat_rate": "0.18"},
    {"delivery_price": -1},
    {"delivery_price": "1000"},
    {"kory_plus_fee_ht": True},
    {"currency": "fcfa"},
    {"emergency_numbers": {"police": "11a"}},
    {"emergency_numbers": {"ambulance": "112"}},
    {"honam_cities": ["L"]},
    {"pharmacy_monthly_price": 9000, "pharmacy_yearly_price": 5000},
    {"inconnu": 1},
])
def test_pays_validation(client, patch_):
    admin, _ = _signup(client, "+22890600004", UserRole.ADMIN)
    assert client.put("/api/v1/admin/countries/TG", json=_country_body(**patch_), headers=admin).status_code == 422
    assert client.put("/api/v1/admin/countries/TOG", json=_country_body(), headers=admin).status_code == 422
    with TestingSessionLocal() as db:
        assert db.query(SystemSetting).filter(SystemSetting.key == "country.TG").first() is None


# ── Réglages système ─────────────────────────────────────────────────────

def test_reglages_secrets_jamais_renvoyes(client):
    admin, _ = _signup(client, "+22890600005", UserRole.ADMIN)
    support, _ = _signup(client, "+22890600006", UserRole.SUPPORT)
    assert client.get("/api/v1/admin/settings", headers=support).status_code == 403
    assert client.put("/api/v1/admin/settings/ngh_api_key", json={"value": "abcd1234"}, headers=support).status_code == 403

    done = client.put("/api/v1/admin/settings/ngh_api_key", json={"value": "cle-tres-secrete-42"}, headers=admin)
    assert done.status_code == 200 and done.json()["value"] is None and done.json()["configured"] is True
    listing = client.get("/api/v1/admin/settings", headers=admin)
    assert "cle-tres-secrete-42" not in listing.text
    audit = _last_audit()
    assert audit.action == "setting_update" and "cle-tres-secrete-42" not in json.dumps(audit.changes)
    with TestingSessionLocal() as db:
        assert db.query(SystemSetting).filter(SystemSetting.key == "ngh_api_key").one().value == "cle-tres-secrete-42"

    plain = client.put("/api/v1/admin/settings/semoa_gateway_id", json={"value": "12"}, headers=admin)
    assert plain.status_code == 200 and plain.json()["value"] == "12"
    assert _last_audit().changes == {"key": "semoa_gateway_id", "from": None, "to": "12"}


def test_reglages_validation(client):
    admin, _ = _signup(client, "+22890600007", UserRole.ADMIN)
    assert client.put("/api/v1/admin/settings/inexistant", json={"value": "x"}, headers=admin).status_code == 404
    assert client.put("/api/v1/admin/settings/country.TG", json={"value": "{}"}, headers=admin).status_code == 404
    assert client.put("/api/v1/admin/settings/semoa_gateway_id", json={"value": "abc"}, headers=admin).status_code == 422
    assert client.put("/api/v1/admin/settings/twilio_verify_service_sid", json={"value": "VA123"}, headers=admin).status_code == 422
    assert client.put("/api/v1/admin/settings/twilio_verify_service_sid",
                      json={"value": "VA" + "a" * 32}, headers=admin).status_code == 200
    assert client.put("/api/v1/admin/settings/semoa_webhook_secret", json={"value": ""}, headers=admin).status_code == 422


def test_tarifs_business(client):
    admin, _ = _signup(client, "+22890600008", UserRole.ADMIN)
    body = {"service_price": 6, "initiated_price": 30, "tax_rate_bp": 1800, "min_recharge": 1000, "max_recharge": 100000}
    done = client.put("/api/v1/admin/settings/business/pricing", json=body, headers=admin)
    assert done.status_code == 200 and done.json()["service_price"] == 6
    assert client.get("/api/v1/admin/settings", headers=admin).json()["business_pricing"]["values"]["tax_rate_bp"] == 1800
    assert _last_audit().changes["changes"]["service_price"] == {"from": 5, "to": 6}
    bad = dict(body, min_recharge=200000)
    assert client.put("/api/v1/admin/settings/business/pricing", json=bad, headers=admin).status_code == 422
    assert client.put("/api/v1/admin/settings/business/pricing", json=dict(body, tax_rate_bp=9000), headers=admin).status_code == 422


# ── Comptes utilisateurs ─────────────────────────────────────────────────

def test_actions_compte_refusees_sans_droit(client):
    viewer, _ = _signup(client, "+22890600010", UserRole.VIEWER)
    _, target = _signup(client, "+22890600011")
    for method, path, body in [
        ("post", f"/users/{target}/logout-all", None),
        ("put", f"/users/{target}/name", {"full_name": "X", "reason": "abus"}),
        ("post", f"/users/{target}/avatar/remove", {"reason": "photo choquante"}),
        ("delete", f"/users/{target}/devices/1", None),
        ("post", f"/users/{target}/delete", {"confirm": "22890600011", "reason": "demande"}),
    ]:
        kwargs = {"headers": viewer}
        if body is not None:
            kwargs["json"] = body
        assert getattr(client, method)("/api/v1/admin" + path, **kwargs).status_code == 403, path


def test_deconnecter_renommer_retirer_photo_et_appareil(client):
    support, _ = _signup(client, "+22890600012", UserRole.SUPPORT)
    target_headers, target = _signup(client, "+22890600013")
    with TestingSessionLocal() as db:
        asset = MediaAsset(uploader_id=target, mime_type="image/jpeg", size_bytes=10, storage_path="x")
        db.add(asset)
        db.flush()
        db.query(User).filter(User.id == target).update({User.avatar_media_id: asset.id})
        device = DeviceToken(user_id=target, token="fcm-test", platform="android")
        db.add(device)
        db.commit()
        device_id = device.id

    detail = client.get(f"/api/v1/admin/users/{target}", headers=support).json()
    assert detail["has_avatar"] is True and detail["devices"][0]["id"] == device_id
    assert detail["active_sessions"] >= 1

    renamed = client.put(f"/api/v1/admin/users/{target}/name",
                         json={"full_name": "  Ama   Koffi ", "reason": "nom injurieux"}, headers=support)
    assert renamed.status_code == 200 and renamed.json()["full_name"] == "Ama Koffi"
    assert _last_audit().action == "user_rename"
    assert client.put(f"/api/v1/admin/users/{target}/name", json={"full_name": "", "reason": "x"},
                      headers=support).status_code == 422

    assert client.post(f"/api/v1/admin/users/{target}/avatar/remove", json={"reason": "ok"},
                       headers=support).status_code == 422
    removed = client.post(f"/api/v1/admin/users/{target}/avatar/remove", json={"reason": "photo choquante"},
                          headers=support)
    assert removed.status_code == 200 and _last_audit().action == "user_avatar_removed"
    assert client.post(f"/api/v1/admin/users/{target}/avatar/remove", json={"reason": "encore"},
                       headers=support).status_code == 409

    assert client.delete(f"/api/v1/admin/users/{target}/devices/999999", headers=support).status_code == 404
    assert client.delete(f"/api/v1/admin/users/{target}/devices/{device_id}", headers=support).status_code == 200
    assert _last_audit().action == "user_device_removed"
    with TestingSessionLocal() as db:
        assert db.get(DeviceToken, device_id) is None

    out = client.post(f"/api/v1/admin/users/{target}/logout-all", headers=support)
    assert out.status_code == 200 and out.json()["revoked"] >= 1
    assert _last_audit().action == "user_sessions_revoked"
    with TestingSessionLocal() as db:
        assert db.query(Token).filter(Token.user_id == target, Token.revoked_at.is_(None)).count() == 0
    assert client.get("/api/v1/users/me/profile", headers=target_headers).status_code == 401


def test_support_ne_gere_pas_un_membre_de_l_equipe(client):
    support, support_id = _signup(client, "+22890600014", UserRole.SUPPORT)
    _, admin_id = _signup(client, "+22890600015", UserRole.ADMIN)
    assert client.post(f"/api/v1/admin/users/{admin_id}/logout-all", headers=support).status_code == 403
    assert client.post(f"/api/v1/admin/users/{support_id}/logout-all", headers=support).status_code == 409


def test_supprimer_un_compte(client):
    super_admin, _ = _signup(client, "+22890600016", UserRole.SUPER_ADMIN)
    _, target = _signup(client, "+22890600017")
    _, member = _signup(client, "+22890600018", UserRole.SUPPORT)
    assert client.post(f"/api/v1/admin/users/{target}/delete", json={"confirm": "22890600017"},
                       headers=super_admin).status_code == 422
    wrong = client.post(f"/api/v1/admin/users/{target}/delete", json={"confirm": "22890600000", "reason": "demande"},
                        headers=super_admin)
    assert wrong.status_code == 400
    assert client.post(f"/api/v1/admin/users/{member}/delete", json={"confirm": "22890600018", "reason": "demande"},
                       headers=super_admin).status_code == 409
    done = client.post(f"/api/v1/admin/users/{target}/delete",
                       json={"confirm": "+228 90 60 00 17", "reason": "demande écrite"}, headers=super_admin)
    assert done.status_code == 200, done.text
    with TestingSessionLocal() as db:
        row = db.get(User, target)
        assert row.phone is None and row.full_name is None and row.is_active is False
        assert db.query(Token).filter(Token.user_id == target).count() == 0
    audit = _last_audit()
    assert audit.action == "user_delete" and audit.changes == {"reason": "demande écrite"}
    assert client.post(f"/api/v1/admin/users/{target}/delete", json={"confirm": "SUPPRIMER", "reason": "encore"},
                       headers=super_admin).status_code == 409


def test_recherche_par_email_et_filtre_equipe(client):
    admin, admin_id = _signup(client, "+22890600019", UserRole.ADMIN)
    _signup(client, "+22890600020")
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == admin_id).update({User.email: "ama@pokou.app"})
        db.commit()
    found = client.get("/api/v1/admin/users?q=ama@pokou", headers=admin).json()
    assert [u["id"] for u in found["items"]] == [admin_id]
    team = client.get("/api/v1/admin/users?team=true", headers=admin).json()
    assert all(u["role"] != "USER" for u in team["items"]) and team["total"] == 1


# ── Équipe ───────────────────────────────────────────────────────────────

def test_equipe_profil_et_acces_console(client):
    super_admin, sa_id = _signup(client, "+22890600021", UserRole.SUPER_ADMIN)
    admin, admin_id = _signup(client, "+22890600022", UserRole.ADMIN)
    _, other_id = _signup(client, "+22890600023", UserRole.SUPPORT)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == other_id).update({User.email: "pris@pokou.app"})
        db.commit()

    body = {"full_name": "Kossi Admin", "email": "Kossi@Pokou.app"}
    assert client.put(f"/api/v1/admin/team/{admin_id}/profile", json=body, headers=admin).status_code == 403
    done = client.put(f"/api/v1/admin/team/{admin_id}/profile", json=body, headers=super_admin)
    assert done.status_code == 200 and done.json()["email"] == "kossi@pokou.app"
    assert _last_audit().action == "team_profile_update"
    assert client.put(f"/api/v1/admin/team/{admin_id}/profile", json={**body, "email": "pris@pokou.app"},
                      headers=super_admin).status_code == 409
    assert client.put(f"/api/v1/admin/team/{admin_id}/profile", json={**body, "email": "pas-un-email"},
                      headers=super_admin).status_code == 422

    assert client.post(f"/api/v1/admin/team/{admin_id}/console-access/disable", headers=admin).status_code == 403
    assert client.post(f"/api/v1/admin/team/{sa_id}/console-access/disable", headers=super_admin).status_code == 409
    off = client.post(f"/api/v1/admin/team/{admin_id}/console-access/disable", headers=super_admin)
    assert off.status_code == 200 and off.json()["console_access"] is False
    assert off.json()["role"] == "ADMIN" and off.json()["is_active"] is True
    assert _last_audit().action == "console_access_disabled"
    # La session de console ouverte est révoquée.
    assert client.get("/api/v1/admin/me", headers=admin).status_code == 401
    login = client.post("/api/v1/admin/auth/login", json={"email": "kossi@pokou.app", "password": "motdepasse-solide"})
    assert login.status_code == 401
    # « Nouveau mot de passe » rétablit l'accès.
    reset = client.post(f"/api/v1/admin/team/{admin_id}/reset-password", headers=super_admin).json()
    login = client.post("/api/v1/admin/auth/login",
                        json={"email": "kossi@pokou.app", "password": reset["temporary_password"]})
    assert login.status_code == 200


def test_equipe_garde_fous(client):
    super_admin, sa_id = _signup(client, "+22890600024", UserRole.SUPER_ADMIN)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == sa_id).update({User.email: "chef@pokou.app"})
        db.commit()
    # Se rétrograder soi-même : refusé, par les deux portes.
    assert client.put(f"/api/v1/admin/team/{sa_id}", json={"role": "ADMIN"}, headers=super_admin).status_code == 409
    again = client.post("/api/v1/admin/team", json={"email": "chef@pokou.app", "full_name": "Chef", "role": "ADMIN"},
                        headers=super_admin)
    assert again.status_code == 409
    # Le dernier super-administrateur ne se retire pas.
    _, other_sa = _signup(client, "+22890600025", UserRole.SUPER_ADMIN)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == other_sa).update({User.email: "second@pokou.app"})
        db.commit()
    assert client.put(f"/api/v1/admin/team/{other_sa}", json={"role": "ADMIN"}, headers=super_admin).status_code == 200
    # Ajouter un membre : mot de passe provisoire rendu une fois.
    added = client.post("/api/v1/admin/team", json={"email": "new@pokou.app", "full_name": "Nouvelle", "role": "SUPPORT"},
                        headers=super_admin)
    assert added.status_code == 200 and added.json()["temporary_password"]
    assert added.json()["console_access"] is True


# ── Mon compte ───────────────────────────────────────────────────────────

def test_changer_mon_mot_de_passe(client):
    viewer, viewer_id = _signup(client, "+22890600026", UserRole.VIEWER)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == viewer_id).update({User.email: "lecteur@pokou.app"})
        db.commit()
    wrong = client.put("/api/v1/admin/me/password",
                       json={"current_password": "mauvais", "new_password": "nouveau-mot-de-passe"}, headers=viewer)
    assert wrong.status_code == 403
    short = client.put("/api/v1/admin/me/password",
                       json={"current_password": "motdepasse-solide", "new_password": "court"}, headers=viewer)
    assert short.status_code == 422
    done = client.put("/api/v1/admin/me/password",
                      json={"current_password": "motdepasse-solide", "new_password": "nouveau-mot-de-passe"}, headers=viewer)
    assert done.status_code == 200 and _last_audit().action == "console_password_change"
    login = client.post("/api/v1/admin/auth/login", json={"email": "lecteur@pokou.app", "password": "nouveau-mot-de-passe"})
    assert login.status_code == 200
