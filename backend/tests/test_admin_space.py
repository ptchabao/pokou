"""Espace d'administration : chaque route exige une permission, chaque
action est journalisée, et l'équipe garde toujours un super-administrateur."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AuditLog, User, UserRole
from app.services.auth import otp_service

engine = create_engine("sqlite:///./test_pokou_admin.db", connect_args={"check_same_thread": False})
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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def test_un_utilisateur_n_entre_pas(client):
    user, _ = _signup(client, "+22890500001")
    assert client.get("/api/v1/admin/me", headers=user).status_code == 403
    assert client.get("/api/v1/admin/overview", headers=user).status_code == 403


def test_les_permissions_suivent_le_role(client):
    viewer, _ = _signup(client, "+22890500002", UserRole.VIEWER)
    me = client.get("/api/v1/admin/me", headers=viewer).json()
    assert "users.view" in me["permissions"] and "users.manage" not in me["permissions"]
    assert client.get("/api/v1/admin/overview", headers=viewer).status_code == 200
    _, target = _signup(client, "+22890500003")
    refused = client.post(f"/api/v1/admin/users/{target}/suspend", json={"reason": "abus"}, headers=viewer)
    assert refused.status_code == 403


def test_suspendre_et_reactiver_est_journalise(client):
    support, _ = _signup(client, "+22890500004", UserRole.SUPPORT)
    target_headers, target = _signup(client, "+22890500005")
    done = client.post(f"/api/v1/admin/users/{target}/suspend", json={"reason": "arnaque signalée"}, headers=support)
    assert done.status_code == 200 and done.json()["is_active"] is False
    assert client.post(f"/api/v1/admin/users/{target}/reactivate", headers=support).json()["is_active"] is True
    with TestingSessionLocal() as db:
        actions = [a.action for a in db.query(AuditLog).order_by(AuditLog.id)]
        assert actions[-2:] == ["suspend", "reactivate"]


def test_seul_le_super_admin_gere_l_equipe_et_il_en_reste_toujours_un(client):
    root, root_id = _signup(client, "+22890500006", UserRole.SUPER_ADMIN)
    admin, _ = _signup(client, "+22890500007", UserRole.ADMIN)
    _, newbie = _signup(client, "+22890500008")
    assert client.post("/api/v1/admin/team", json={"phone": "+22890500008", "role": "SUPPORT"},
                       headers=admin).status_code == 403
    added = client.post("/api/v1/admin/team", json={"phone": "+22890500008", "role": "SUPPORT"}, headers=root)
    assert added.json()["role"] == "SUPPORT"
    assert {m["id"] for m in client.get("/api/v1/admin/team", headers=admin).json()["items"]} >= {root_id, newbie}
    last = client.put(f"/api/v1/admin/team/{root_id}", json={"role": "ADMIN"}, headers=root)
    assert last.status_code == 409


def test_un_signalement_arrive_dans_la_file_et_se_traite(client):
    reporter, _ = _signup(client, "+22890500009")
    _, target = _signup(client, "+22890500010")
    moderator, _ = _signup(client, "+22890500011", UserRole.SUPPORT)
    client.post("/api/v1/conversations/report", json={"contact_user_id": target, "reason": "spam"}, headers=reporter)
    queue = client.get("/api/v1/admin/reports", headers=moderator).json()
    assert queue["total"] == 1 and queue["items"][0]["reason"] == "spam"
    report_id = queue["items"][0]["id"]
    done = client.post(f"/api/v1/admin/reports/{report_id}/resolve", json={"action": "suspend"}, headers=moderator)
    assert done.json()["status"] == "ACTIONED" and done.json()["target"]["is_active"] is False


def test_suspendre_deconnecte_tout_de_suite(client):
    support, _ = _signup(client, "+22890500020", UserRole.SUPPORT)
    target_headers, target = _signup(client, "+22890500021")
    assert client.get("/api/v1/auth/me", headers=target_headers).status_code == 200
    client.post(f"/api/v1/admin/users/{target}/suspend", json={"reason": "arnaque"}, headers=support)
    assert client.get("/api/v1/auth/me", headers=target_headers).status_code == 401


def test_un_signalement_ne_contourne_pas_la_regle_de_l_equipe(client):
    support, _ = _signup(client, "+22890500022", UserRole.SUPPORT)
    reporter, _ = _signup(client, "+22890500023")
    other, _ = _signup(client, "+22890500024")
    _, colleague = _signup(client, "+22890500025", UserRole.VIEWER)
    client.post("/api/v1/conversations/report", json={"contact_user_id": colleague, "reason": "spam"}, headers=reporter)
    client.post("/api/v1/conversations/report", json={"contact_user_id": colleague, "reason": "spam"}, headers=other)
    queue = client.get("/api/v1/admin/reports", headers=support).json()["items"]
    refused = client.post(f"/api/v1/admin/reports/{queue[0]['id']}/resolve", json={"action": "suspend"}, headers=support)
    assert refused.status_code == 403


def test_sanctionner_regle_tous_les_signalements_du_compte(client):
    moderator, _ = _signup(client, "+22890500026", UserRole.ADMIN)
    a, _ = _signup(client, "+22890500027")
    b, _ = _signup(client, "+22890500028")
    _, target = _signup(client, "+22890500029")
    for h in (a, b):
        client.post("/api/v1/conversations/report", json={"contact_user_id": target, "reason": "spam"}, headers=h)
    queue = client.get("/api/v1/admin/reports", headers=moderator).json()["items"]
    assert len(queue) == 2
    client.post(f"/api/v1/admin/reports/{queue[0]['id']}/resolve", json={"action": "suspend"}, headers=moderator)
    assert client.get("/api/v1/admin/reports", headers=moderator).json()["items"] == []


def test_le_seed_cree_le_super_admin_et_se_connecte_a_la_console(client, monkeypatch, capsys):
    from scripts import seed
    monkeypatch.setenv("POKOU_SUPERADMIN_EMAIL", "chef@pokou.test")
    monkeypatch.delenv("POKOU_SUPERADMIN_PASSWORD", raising=False)
    with TestingSessionLocal() as db:
        seed.seed_modules(db)
        seed.seed_superadmin(db)
        assert seed.seed_modules(db) == 0  # idempotent
    out = capsys.readouterr().out
    password = re.search(r"Mot de passe\s+: (\S+)", out).group(1)

    with TestingSessionLocal() as db:
        seed.seed_superadmin(db)  # second déploiement : rien de nouveau
    assert "inchangé" in capsys.readouterr().out

    bad = client.post("/api/v1/admin/auth/login", json={"email": "chef@pokou.test", "password": "faux"})
    assert bad.status_code == 401
    ok = client.post("/api/v1/admin/auth/login", json={"email": "CHEF@pokou.test", "password": password})
    assert ok.status_code == 200
    client.cookies.clear()
    headers = {"Authorization": f"Bearer {ok.json()['access_token']}"}
    me = client.get("/api/v1/admin/me", headers=headers).json()
    assert me["role"] == "SUPER_ADMIN" and "team.manage" in me["permissions"]

    changed = client.put("/api/v1/admin/me/password",
                         json={"current_password": password, "new_password": "un-nouveau-mot-de-passe"}, headers=headers)
    assert changed.status_code == 200
    assert client.post("/api/v1/admin/auth/login",
                       json={"email": "chef@pokou.test", "password": password}).status_code == 401


def test_la_console_se_verrouille_apres_des_echecs(client, monkeypatch):
    from scripts import seed
    monkeypatch.setenv("POKOU_SUPERADMIN_EMAIL", "lock@pokou.test")
    monkeypatch.setenv("POKOU_SUPERADMIN_PASSWORD", "le-bon-mot-de-passe")
    with TestingSessionLocal() as db:
        seed.seed_superadmin(db)
    for _ in range(5):
        client.post("/api/v1/admin/auth/login", json={"email": "lock@pokou.test", "password": "x"})
    locked = client.post("/api/v1/admin/auth/login", json={"email": "lock@pokou.test", "password": "le-bon-mot-de-passe"})
    assert locked.status_code == 429


def test_un_utilisateur_sans_role_n_entre_pas_par_mot_de_passe(client):
    from app.core.security import hash_password
    with TestingSessionLocal() as db:
        db.add(User(email="simple@pokou.test", role=UserRole.USER, is_active=True,
                    console_password_hash=hash_password("mot-de-passe-123")))
        db.commit()
    r = client.post("/api/v1/admin/auth/login", json={"email": "simple@pokou.test", "password": "mot-de-passe-123"})
    assert r.status_code == 403
