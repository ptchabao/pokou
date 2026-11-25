"""Kory : archiver ses collectes finies, ajouter des membres, et raconter
l'activité dans le fil du groupe.

Toujours un journal, jamais un portefeuille (BM-01) : rien ici ne déplace
d'argent, et le fil du groupe ne dit que ce que le serveur sait déjà.
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Group, GroupMember, GroupMessage, KoryArchive, KoryPot, SystemSetting
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_kory_archives.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


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
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


_PHONE = iter(range(1000, 9999))


def _signup(client, name=None):
    phone = f"+2289{next(_PHONE)}000"[:12]
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    if name:
        from app.models import User

        with TestingSessionLocal() as db:
            db.get(User, body["user"]["id"]).full_name = name
            db.commit()
    return headers, body["user"]["id"]


def _group(user_ids, name="Les Amis de Bè"):
    with TestingSessionLocal() as db:
        group = Group(name=name, created_by=user_ids[0])
        db.add(group)
        db.flush()
        for index, uid in enumerate(user_ids):
            db.add(GroupMember(group_id=group.id, user_id=uid, role="OWNER" if index == 0 else "MEMBER"))
        db.commit()
        return group.id


def _cagnotte(client, headers, **extra):
    response = client.post(
        "/api/v1/kory/pots",
        json={"kind": "CAGNOTTE", "title": "Mariage de Kossi", "goal_amount": 100000, **extra},
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()


def _ids(client, headers, **params):
    return [p["id"] for p in client.get("/api/v1/kory/pots", params=params, headers=headers).json()["items"]]


def _activity(client, headers, group_id):
    items = client.get(f"/api/v1/groups/{group_id}/messages", headers=headers).json()["items"]
    return [m["payload"] for m in items if (m.get("payload") or {}).get("kind") == "kory_activity"]


# ── Archives : un réglage par membre ──────────────────────────────────────

def test_seule_une_collecte_finie_s_archive_et_pour_soi_seulement(client):
    (organizer, _), (friend, _) = _signup(client), _signup(client)
    pot = _cagnotte(client, organizer)
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=friend)
    url = f"/api/v1/kory/pots/{pot['id']}/archive"

    assert pot["archivable"] is False and pot["archived"] is False
    assert client.put(url, json={"archived": True}, headers=organizer).status_code == 409

    client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=organizer)
    archived = client.put(url, json={"archived": True}, headers=organizer)
    assert archived.status_code == 200 and archived.json()["archived"] is True
    # Deux fois : toujours une seule ligne.
    client.put(url, json={"archived": True}, headers=organizer)
    with TestingSessionLocal() as db:
        assert db.query(KoryArchive).count() == 1

    assert pot["id"] not in _ids(client, organizer)
    assert _ids(client, organizer, archived="true") == [pot["id"]]
    # L'amie, elle, la voit toujours dans sa liste.
    assert pot["id"] in _ids(client, friend)
    assert _ids(client, friend, archived="true") == []

    restored = client.put(url, json={"archived": False}, headers=organizer).json()
    assert restored["archived"] is False
    assert pot["id"] in _ids(client, organizer)
    assert _ids(client, organizer, archived="true") == []


def test_une_cagnotte_expiree_s_archive_et_revient_si_on_la_prolonge(client):
    organizer, _ = _signup(client)
    pot = _cagnotte(client, organizer)
    with TestingSessionLocal() as db:
        db.get(KoryPot, pot["id"]).due_at = datetime.utcnow() - timedelta(days=1)
        db.commit()
    url = f"/api/v1/kory/pots/{pot['id']}"
    assert client.put(f"{url}/archive", json={"archived": True}, headers=organizer).json()["archived"] is True
    assert pot["id"] not in _ids(client, organizer)

    # Prolongée, elle n'est plus finie : elle revient dans la liste.
    later = (datetime.utcnow() + timedelta(days=10)).isoformat()
    client.post(f"{url}/extend", json={"due_at": later}, headers=organizer)
    assert pot["id"] in _ids(client, organizer)
    assert _ids(client, organizer, archived="true") == []


def test_la_vue_du_groupe_ignore_mes_archives(client):
    (organizer, me), (friend, other) = _signup(client), _signup(client)
    group_id = _group([me, other])
    pot = _cagnotte(client, organizer, group_id=group_id)
    client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=organizer)
    client.put(f"/api/v1/kory/pots/{pot['id']}/archive", json={"archived": True}, headers=organizer)
    assert _ids(client, organizer, group_id=group_id) == [pot["id"]]


def test_archiver_la_collecte_d_un_autre_sans_la_voir_est_introuvable(client):
    (organizer, _), (stranger, _) = _signup(client), _signup(client)
    pot = _cagnotte(client, organizer)
    client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=organizer)
    response = client.put(f"/api/v1/kory/pots/{pot['id']}/archive", json={"archived": True}, headers=stranger)
    assert response.status_code == 404


# ── L'activité Kory dans le fil du groupe ──────────────────────────────────

def test_creation_contribution_et_cloture_racontees_dans_le_groupe(client):
    (organizer, me), (friend, friend_id) = _signup(client, "Afi Mensah"), _signup(client, "Ama Lawson")
    group_id = _group([me, friend_id])
    pot = _cagnotte(client, organizer, group_id=group_id)
    url = f"/api/v1/kory/pots/{pot['id']}"

    entry = client.post(
        f"{url}/entries", json={"amount": 5000, "wallet_reference": "MP2611.1234.A00001"}, headers=friend
    ).json()
    # Déclarée seulement : rien dans le fil tant que ce n'est pas confirmé.
    assert [a["event"] for a in _activity(client, friend, group_id)] == ["created"]
    client.post(f"{url}/entries/{entry['id']}/review", json={"decision": "CONFIRM"}, headers=organizer)
    client.post(f"{url}/close", headers=organizer)

    events = _activity(client, friend, group_id)
    assert [a["event"] for a in events] == ["created", "contribution", "closed"]
    created, contribution, closed = events
    assert created["title"] == "Mariage de Kossi" and created["actor_name"] == "Afi Mensah"
    assert created["goal"] == 100000 and created["pot_id"] == pot["id"]
    assert contribution["contributor_name"] == "Ama Lawson" and contribution["amount"] == 5000
    assert contribution["total"] == 5000
    assert closed["total"] == 5000
    # Ni référence de transaction ni numéro : le serveur n'écrit pas ce que
    # le groupe n'a pas à savoir.
    blob = repr(events)
    assert "MP2611" not in blob and "+228" not in blob
    # Le message n'est pas chiffré (c'est le serveur qui l'écrit) et porte un
    # aperçu lisible pour la liste des discussions.
    with TestingSessionLocal() as db:
        rows = db.query(GroupMessage).filter(GroupMessage.group_id == group_id).all()
        assert all(r.encryption is None and r.content == "Kory · Mariage de Kossi" for r in rows)


def test_montants_masques_le_fil_dit_qui_pas_combien(client):
    (organizer, me), (friend, friend_id) = _signup(client), _signup(client)
    group_id = _group([me, friend_id])
    pot = _cagnotte(client, organizer, group_id=group_id, amounts_visible=False)
    url = f"/api/v1/kory/pots/{pot['id']}"
    entry = client.post(f"{url}/entries", json={"amount": 7000}, headers=friend).json()
    client.post(f"{url}/entries/{entry['id']}/review", json={"decision": "CONFIRM"}, headers=organizer)
    contribution = [a for a in _activity(client, organizer, group_id) if a["event"] == "contribution"][0]
    assert "amount" not in contribution and contribution["amounts_visible"] is False
    # Le total, lui, reste visible, comme dans Kory.
    assert contribution["total"] == 7000


def test_sans_groupe_pas_de_fil(client):
    organizer, _ = _signup(client)
    _cagnotte(client, organizer)
    with TestingSessionLocal() as db:
        assert db.query(GroupMessage).count() == 0


def test_les_messages_chiffres_du_groupe_restent_sans_charge_lisible(client):
    (organizer, me), (_, friend_id) = _signup(client), _signup(client)
    group_id = _group([me, friend_id])
    with TestingSessionLocal() as db:
        db.add(GroupMessage(
            group_id=group_id, sender_id=me, encryption="sender-key-v1", ciphertext="xx",
            payload={"kind": "kory_activity", "event": "created"},
        ))
        db.commit()
    assert _activity(client, organizer, group_id) == []


# ── Tontine : membres du groupe, tours, rappel ─────────────────────────────

def _kory_plus():
    with TestingSessionLocal() as db:
        db.add(SystemSetting(
            key="country.TG",
            value='{"modules": ["discussions", "kory", "kory_plus", "honam", "assime"], "kory_plus_fee_ht": 0}',
        ))
        db.commit()


def test_tontine_en_attente_accueille_des_membres_du_groupe(client):
    _kory_plus()
    people = [_signup(client) for _ in range(4)]
    ids = [uid for _, uid in people]
    outsider_headers, outsider = _signup(client)
    group_id = _group(ids)
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "TONTINE", "title": "Tontine des voisines", "amount_per_member": 5000,
              "period": "MONTHLY", "group_id": group_id, "rotation": ids[:2], "draw_mode": "FIXED"},
        headers=people[0][0],
    ).json()
    url = f"/api/v1/kory/pots/{pot['id']}"

    assert client.post(f"{url}/participants", json={"user_ids": [outsider]}, headers=people[0][0]).status_code == 422
    assert client.post(
        f"{url}/participants", json={"phones": [{"phone": "+22890000001"}]}, headers=people[0][0]
    ).status_code == 422
    assert client.post(f"{url}/participants", json={"user_ids": [ids[2]]}, headers=people[1][0]).status_code == 403

    added = client.post(f"{url}/participants", json={"user_ids": [ids[2], ids[3], ids[2]]}, headers=people[0][0])
    assert added.status_code == 200, added.text
    members = added.json()["members"]
    assert sorted(m["user_id"] for m in members) == sorted(ids)
    assert added.json()["status"] == "PENDING"

    for headers, _ in people[1:]:
        client.post(f"{url}/accept", headers=headers)
    started = client.get(url, headers=people[0][0]).json()
    assert started["status"] == "OPEN" and [r["beneficiary_id"] for r in started["rounds"]] == ids
    # Une fois l'ordre tiré, plus personne n'entre.
    assert client.post(f"{url}/participants", json={"user_ids": [ids[3]]}, headers=people[0][0]).status_code == 409

    client.post(f"{url}/next-round", headers=people[0][0])
    events = [a["event"] for a in _activity(client, people[3][0], group_id)]
    assert events == ["created", "started", "round"]
    round_ = _activity(client, people[3][0], group_id)[-1]
    assert round_["round"] == 2 and round_["rounds"] == 4 and round_["beneficiary_id"] == ids[1]
    assert outsider_headers  # l'inconnu n'a rien vu : il n'est pas du groupe
    assert client.get(f"/api/v1/groups/{group_id}/messages", headers=outsider_headers).status_code == 403


def test_un_rappel_se_lit_dans_le_groupe(client):
    (organizer, me), (_, friend_id) = _signup(client), _signup(client)
    group_id = _group([me, friend_id])
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "COTISATION", "title": "Cotisation du lycée", "amount_per_member": 5000,
              "period": "MONTHLY", "group_id": group_id,
              "due_at": (datetime.utcnow() - timedelta(days=2)).isoformat()},
        headers=organizer,
    ).json()
    reminded = client.post(f"/api/v1/kory/pots/{pot['id']}/remind", headers=organizer).json()
    assert reminded["reminded"] >= 1
    reminder = _activity(client, organizer, group_id)[-1]
    assert reminder["event"] == "reminder" and reminder["count"] == reminded["reminded"]
    assert reminder["pot_kind"] == "COTISATION"
