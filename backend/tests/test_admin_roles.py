"""Rôles de la console modifiables (RBAC) : matrice de permissions, rôles
créés par l'équipe, et garde-fous contre l'escalade de droits."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.core.permissions import ALL
from app.core.security import hash_password
from app.main import app
from app.models import User, UserRole
from app.services.auth import otp_service
from tests.helpers import console_bearer

engine = create_engine("sqlite:///./test_pokou_admin_roles.db", connect_args={"check_same_thread": False})
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


def _member(client, phone, role):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == body["user"]["id"]).update(
            {User.role: role, User.console_password_hash: hash_password("motdepasse-solide")})
        db.commit()
    return console_bearer(TestingSessionLocal, body["user"]["id"]), body["user"]["id"]


def test_roles_list_and_catalog(client):
    boss, _ = _member(client, "+22890700101", UserRole.SUPER_ADMIN)
    body = client.get("/api/v1/admin/roles", headers=boss).json()
    keys = [r["key"] for r in body["items"]]
    assert keys[0] == "SUPER_ADMIN" and {"ADMIN", "SUPPORT", "AI_OPERATOR", "VIEWER"} <= set(keys)
    catalog = {p["key"] for g in body["catalog"] for p in g["permissions"]}
    assert catalog == ALL
    assert body["items"][0]["editable"] is False


def test_custom_role_controls_what_a_member_can_do(client):
    boss, _ = _member(client, "+22890700102", UserRole.SUPER_ADMIN)
    staff, staff_id = _member(client, "+22890700103", UserRole.VIEWER)

    created = client.post("/api/v1/admin/roles", headers=boss, json={
        "label": "Modération Assimé", "description": "Annonces seulement",
        "permissions": ["dashboard.view", "assime.view", "assime.manage"]})
    assert created.status_code == 200, created.text
    role_id = created.json()["id"]
    assigned = client.put(f"/api/v1/admin/team/{staff_id}", headers=boss, json={"role": f"custom:{role_id}"})
    assert assigned.status_code == 200 and assigned.json()["role_label"] == "Modération Assimé"

    me = client.get("/api/v1/admin/me", headers=staff).json()
    assert set(me["permissions"]) == {"dashboard.view", "assime.view", "assime.manage"}
    assert client.get("/api/v1/admin/users", headers=staff).status_code == 403

    # Le rôle évolue : le membre suit, sans réassignation.
    client.put(f"/api/v1/admin/roles/{role_id}", headers=boss, json={
        "label": "Modération", "permissions": ["dashboard.view", "users.view"]})
    assert client.get("/api/v1/admin/users", headers=staff).status_code == 200

    # Pas de suppression tant qu'un membre l'a.
    assert client.delete(f"/api/v1/admin/roles/{role_id}", headers=boss).status_code == 409
    client.put(f"/api/v1/admin/team/{staff_id}", headers=boss, json={"role": "VIEWER"})
    assert client.delete(f"/api/v1/admin/roles/{role_id}", headers=boss).status_code == 200


def test_system_role_permissions_are_editable(client):
    boss, _ = _member(client, "+22890700104", UserRole.SUPER_ADMIN)
    support, _ = _member(client, "+22890700105", UserRole.SUPPORT)
    roles = client.get("/api/v1/admin/roles", headers=boss).json()["items"]
    support_role = next(r for r in roles if r["key"] == "SUPPORT")
    assert "users.view" in support_role["permissions"]
    client.put(f"/api/v1/admin/roles/{support_role['id']}", headers=boss,
               json={"permissions": ["dashboard.view", "reports.view"]})
    assert client.get("/api/v1/admin/users", headers=support).status_code == 403


def test_no_privilege_escalation(client):
    boss, _ = _member(client, "+22890700106", UserRole.SUPER_ADMIN)
    admin, _ = _member(client, "+22890700107", UserRole.ADMIN)
    staff, staff_id = _member(client, "+22890700108", UserRole.VIEWER)

    # Un administrateur ne touche pas aux rôles.
    assert client.post("/api/v1/admin/roles", headers=admin,
                       json={"label": "X", "permissions": ["dashboard.view"]}).status_code == 403
    # Personne ne met « modifier les rôles » dans un rôle.
    assert client.post("/api/v1/admin/roles", headers=boss,
                       json={"label": "Y", "permissions": ["roles.manage"]}).status_code == 422

    # Un rôle créé avec « gérer l'équipe » ne peut pas nommer de super-administrateur.
    team_role = client.post("/api/v1/admin/roles", headers=boss, json={
        "label": "RH", "permissions": ["dashboard.view", "team.view", "team.manage"]}).json()
    client.put(f"/api/v1/admin/team/{staff_id}", headers=boss, json={"role": f"custom:{team_role['id']}"})
    other, other_id = _member(client, "+22890700109", UserRole.VIEWER)
    assert client.put(f"/api/v1/admin/team/{other_id}", headers=staff,
                      json={"role": "SUPER_ADMIN"}).status_code == 403
    assert client.post("/api/v1/admin/team", headers=staff, json={
        "email": "chef@pokou.app", "full_name": "Chef", "role": "SUPER_ADMIN"}).status_code == 403
    # Mais il peut attribuer un rôle ordinaire.
    assert client.put(f"/api/v1/admin/team/{other_id}", headers=staff,
                      json={"role": "SUPPORT"}).status_code == 200


def test_super_admin_always_has_everything(client):
    boss, _ = _member(client, "+22890700110", UserRole.SUPER_ADMIN)
    me = client.get("/api/v1/admin/me", headers=boss).json()
    assert set(me["permissions"]) == ALL


def test_all_countries_of_the_world_are_listed(client):
    from app.core.countries import country_config

    boss, _ = _member(client, "+22890700111", UserRole.SUPER_ADMIN)
    body = client.get("/api/v1/admin/countries", headers=boss).json()
    codes = [c["code"] for c in body["items"]]
    assert len(codes) >= 245 and {"TG", "CI", "NG", "FR", "US", "JP", "BR"} <= set(codes)
    # Les pays configurés d'abord, puis tous les autres par ordre alphabétique.
    assert codes[0] in {"TG", "CI", "FR", "BJ", "SN"}
    nigeria = next(c for c in body["items"] if c["code"] == "NG")
    assert nigeria["name"] == "Nigéria" and nigeria["dial"] == "+234" and nigeria["currency"] == "NGN"
    with TestingSessionLocal() as db:
        assert country_config(db, "JP")["currency"] == "JPY"
        assert country_config(db, "TG")["currency"] == "XOF"


def test_anyone_can_edit_their_own_profile(client):
    viewer, viewer_id = _member(client, "+22890700112", UserRole.VIEWER)
    done = client.put("/api/v1/admin/me/profile", headers=viewer,
                      json={"full_name": "Afi  Mensah", "email": "Afi@Pokou.app"})
    assert done.status_code == 200, done.text
    assert done.json()["full_name"] == "Afi Mensah" and done.json()["email"] == "afi@pokou.app"
    # Mais pas celui des autres.
    _, other_id = _member(client, "+22890700113", UserRole.SUPPORT)
    assert client.put(f"/api/v1/admin/team/{other_id}/profile", headers=viewer,
                      json={"full_name": "X Y", "email": "x@pokou.app"}).status_code == 403
