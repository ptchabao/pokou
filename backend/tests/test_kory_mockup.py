"""Kory : ce que la maquette ajoute (écrans Kory 3, 6, 8, 10, 17 à 30).

Toujours un journal, jamais un portefeuille (BM-01) : aucune de ces routes
ne déplace d'argent.
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
from app.models import Group, GroupMember, KoryEntry, KoryPot, MediaAsset, SystemSetting
from app.services.auth import otp_service
from app.services.kory import cotisation as cotisation_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_kory_mockup.db"

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


def _signup(client, phone=None):
    phone = phone or f"+2289{next(_PHONE)}000"[:12]
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _group(user_ids, name="Les Amis de Bè"):
    with TestingSessionLocal() as db:
        group = Group(name=name, created_by=user_ids[0])
        db.add(group)
        db.flush()
        for index, uid in enumerate(user_ids):
            db.add(GroupMember(group_id=group.id, user_id=uid, role="OWNER" if index == 0 else "MEMBER"))
        db.commit()
        return group.id


def _people(client, count):
    return [_signup(client) for _ in range(count)]


def _kory_plus():
    with TestingSessionLocal() as db:
        db.add(SystemSetting(
            key="country.TG",
            value='{"modules": ["discussions", "kory", "kory_plus", "honam", "assime", "certified"]}',
        ))
        db.commit()


# ── KOR-6 / 10 : bénéficiaire, visibilité, aperçu d'invitation ─────────────

def test_apercu_avant_de_rejoindre_puis_montants_masques(client):
    (organizer, _), (guest, _), (third, _) = _people(client, 3)
    pot = client.post(
        "/api/v1/kory/pots",
        json={"title": "Mariage d’Akossiwa", "beneficiary_name": "Akossiwa K.", "goal_amount": 300000,
              "amounts_visible": False},
        headers=organizer,
    ).json()
    assert pot["beneficiary_name"] == "Akossiwa K." and pot["amounts_visible"] is False

    preview = client.get(f"/api/v1/kory/preview/{pot['join_code']}", headers=guest).json()
    assert preview["title"] == "Mariage d’Akossiwa" and preview["already_member"] is False
    assert "••" in preview["collector_phone_masked"] and "entries" not in preview
    # L'aperçu ne fait pas entrer : sans « Rejoindre », la cagnotte reste fermée.
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=guest).status_code == 404
    assert client.get("/api/v1/kory/preview/ZZZZZZZZ", headers=guest).status_code == 404

    for headers in (guest, third):
        client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=headers)
    client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 7000}, headers=guest)
    seen_by_third = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=third).json()
    assert seen_by_third["entries"][0]["amount"] is None and seen_by_third["entries"][0]["amount_hidden"]
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=guest).json()["entries"][0]["amount"] == 7000
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer).json()["entries"][0]["amount"] == 7000


# ── KOR-3 : capture jointe à la déclaration ───────────────────────────────

def test_capture_jointe_a_la_declaration_vue_du_seul_collecteur(client):
    (organizer, _), (member, member_id), (other, _) = _people(client, 3)
    pot = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    for headers in (member, other):
        client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=headers)
    with TestingSessionLocal() as db:
        asset = MediaAsset(uploader_id=member_id, mime_type="image/jpeg", size_bytes=10, storage_path="x")
        db.add(asset)
        db.commit()
        asset_id = asset.id
    created = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 10000, "wallet_reference": "TG2610311611C3", "proof_media_id": asset_id},
        headers=member,
    )
    assert created.status_code == 201 and created.json()["proof_media_id"] == asset_id
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer).json()["entries"][0]["proof_media_id"] == asset_id
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=other).json()["entries"][0]["proof_media_id"] is None
    # La capture d'un autre est refusée.
    stolen = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 500, "proof_media_id": asset_id}, headers=other,
    )
    assert stolen.status_code == 403


# ── KOR-17 à 22 : la cotisation ────────────────────────────────────────────

def test_calendrier_mensuel_et_trimestriel():
    pot = KoryPot(due_at=datetime(2026, 1, 31), period="MONTHLY")
    labels = cotisation_service.dues(pot, datetime(2026, 4, 1))
    assert [label for label, _ in labels] == ["2026-01", "2026-02", "2026-03"]
    assert labels[1][1] == datetime(2026, 2, 28)
    pot.paused_period = "2026-02"
    assert [label for label, _ in cotisation_service.dues(pot, datetime(2026, 4, 1))] == ["2026-01", "2026-03"]
    quarterly = KoryPot(due_at=datetime(2026, 12, 5), period="QUARTERLY")
    assert [label for label, _ in cotisation_service.dues(quarterly, datetime(2027, 6, 6))] == [
        "2026-Q4", "2027-Q1", "2027-Q2",
    ]


def test_cotisation_de_membres_choisis_avec_co_organisatrice(client):
    people = _people(client, 4)
    (organizer, organizer_id), (ama, ama_id), (edem, edem_id), (outsider, outsider_id) = people
    group_id = _group([organizer_id, ama_id, edem_id, outsider_id])
    first_due = datetime.utcnow() - timedelta(days=3)
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "COTISATION", "title": "Cotisation des Amis de Bè", "amount_per_member": 2000,
              "period": "MONTHLY", "group_id": group_id, "due_at": first_due.isoformat(),
              "member_ids": [ama_id, edem_id], "deputy_id": ama_id},
        headers=organizer,
    ).json()
    block = pot["cotisation"]
    assert block["members_count"] == 3 and outsider_id not in [m["user_id"] for m in block["members"]]
    assert block["current"]["expected_total"] == 6000 and block["current"]["late_count"] == 3
    assert len(block["schedule"]) >= 3

    # Edem déclare sans préciser l'échéance : elle va à l'échéance en cours.
    entry = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 2000}, headers=edem).json()
    assert entry["period_label"] == block["current"]["label"]
    # La co-organisatrice confirme ; quelqu'un d'autre, non.
    url = f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review"
    assert client.post(url, json={"decision": "CONFIRM"}, headers=outsider).status_code in (403, 404)
    assert client.post(url, json={"decision": "CONFIRM"}, headers=ama).status_code == 200

    seen = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=edem).json()["cotisation"]
    assert seen["current"]["up_to_date_count"] == 1 and seen["current"]["confirmed_total"] == 2000
    assert seen["my_periods"][0]["status"] == "CONFIRMED"
    assert seen["my_next"]["label"] != block["current"]["label"]

    # Relance des retardataires : une fois par tranche de 12 h.
    first = client.post(f"/api/v1/kory/pots/{pot['id']}/remind", headers=organizer)
    assert first.status_code == 200 and first.json()["reminded"] == 1  # Ama seule (l'organisateur ne se relance pas)
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/remind", headers=organizer).status_code == 429
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/remind", headers=edem).status_code == 403


def test_modifier_la_cotisation_a_partir_de_l_echeance_suivante(client):
    (organizer, organizer_id), (member, member_id) = _people(client, 2)
    group_id = _group([organizer_id, member_id])
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "COTISATION", "title": "Famille", "amount_per_member": 5000, "period": "MONTHLY",
              "group_id": group_id, "due_at": (datetime.utcnow() - timedelta(days=1)).isoformat()},
        headers=organizer,
    ).json()
    url = f"/api/v1/kory/pots/{pot['id']}/cotisation"
    current = pot["cotisation"]["current"]["label"]
    assert client.post(url, json={"action": "AMOUNT", "amount": 2500}, headers=member).status_code == 403
    changed = client.post(url, json={"action": "AMOUNT", "amount": 2500}, headers=organizer).json()
    # L'échéance en cours garde son montant ; la suivante passe à 2 500.
    assert changed["cotisation"]["current"]["amount"] == 5000
    upcoming = [s for s in changed["cotisation"]["schedule"] if s["label"] != current]
    assert upcoming[0]["amount"] == 2500

    paused = client.post(url, json={"action": "PAUSE"}, headers=organizer).json()
    labels = [s["label"] for s in paused["cotisation"]["schedule"]]
    with TestingSessionLocal() as db:
        skipped = db.get(KoryPot, pot["id"]).paused_period
    assert skipped not in labels and current in labels

    collector = client.post(url, json={"action": "COLLECTOR", "collector_id": member_id}, headers=organizer).json()
    assert collector["collector_id"] == member_id
    stopped = client.post(url, json={"action": "STOP"}, headers=organizer).json()
    assert stopped["ends_at"] is not None
    assert [s["label"] for s in stopped["cotisation"]["schedule"]] == [current]


# ── KOR-8, 23 à 30 : la tontine (Kory Plus) ────────────────────────────────

def _tontine(client, size=4, draw_mode="DRAW"):
    _kory_plus()
    people = _people(client, size)
    ids = [uid for _, uid in people]
    group_id = _group(ids, "Voisins de Bè")
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "TONTINE", "title": "Tontine des voisins", "amount_per_member": 5000, "period": "MONTHLY",
              "group_id": group_id, "rotation": ids, "draw_mode": draw_mode, "deputy_id": ids[1]},
        headers=people[0][0],
    )
    assert pot.status_code == 201, pot.text
    return people, pot.json()


def test_tontine_demarre_quand_tous_ont_accepte_avec_tirage_scelle(client):
    people, pot = _tontine(client, size=4, draw_mode="DRAW")
    assert pot["status"] == "PENDING" and pot["rounds"] == []
    assert sum(1 for m in pot["members"] if m["accepted"]) == 1
    # Pas de contribution tant qu'elle n'a pas démarré.
    early = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 5000}, headers=people[1][0])
    assert early.status_code == 409
    reminded = client.post(f"/api/v1/kory/pots/{pot['id']}/remind", headers=people[0][0]).json()
    assert reminded["reminded"] == 3

    for headers, _ in people[1:-1]:
        assert client.post(f"/api/v1/kory/pots/{pot['id']}/accept", headers=headers).json()["status"] == "PENDING"
    started = client.post(f"/api/v1/kory/pots/{pot['id']}/accept", headers=people[-1][0]).json()
    assert started["status"] == "OPEN" and len(started["rounds"]) == 4
    assert re.fullmatch(r"[0-9A-F]{4}-[0-9A-F]{4}", started["draw_seal"]) and started["drawn_at"]
    assert sorted(r["beneficiary_id"] for r in started["rounds"]) == sorted(uid for _, uid in people)
    # Le tirage ne se rejoue pas.
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/start", headers=people[0][0]).status_code == 409


def test_refus_puis_demarrage_sans_lui_par_l_administrateur(client):
    people, pot = _tontine(client, size=3, draw_mode="FIXED")
    url = f"/api/v1/kory/pots/{pot['id']}"
    assert client.post(f"{url}/decline", headers=people[2][0]).status_code == 200
    accepted = client.post(f"{url}/accept", headers=people[1][0]).json()
    # Quelqu'un a refusé : pas de démarrage automatique.
    assert accepted["status"] == "PENDING"
    assert client.post(f"{url}/start", headers=people[1][0]).status_code == 200  # le suppléant démarre
    detail = client.get(url, headers=people[0][0]).json()
    # Ordre fixé : celui de la rotation, sans le membre qui a refusé.
    assert [r["beneficiary_id"] for r in detail["rounds"]] == [people[0][1], people[1][1]]


def _started(client, size=4):
    people, pot = _tontine(client, size=size, draw_mode="FIXED")
    for headers, _ in people[1:]:
        client.post(f"/api/v1/kory/pots/{pot['id']}/accept", headers=headers)
    return people, client.get(f"/api/v1/kory/pots/{pot['id']}", headers=people[0][0]).json()


def test_etat_du_tour_et_rapport(client):
    people, pot = _started(client, size=4)
    url = f"/api/v1/kory/pots/{pot['id']}"
    # Tour 1 : le bénéficiaire est people[0] ; people[1] déclare, il confirme.
    entry = client.post(f"{url}/entries", json={"amount": 5000}, headers=people[1][0]).json()
    client.post(f"{url}/entries/{entry['id']}/review", json={"decision": "CONFIRM"}, headers=people[0][0])
    client.post(f"{url}/entries", json={"amount": 5000}, headers=people[2][0])
    current = client.get(url, headers=people[3][0]).json()["rounds"][0]
    assert current["expected_count"] == 3 and current["confirmed_count"] == 1 and current["declared_count"] == 1
    statuses = {c["user_id"]: c["status"] for c in current["contributors"]}
    assert statuses[people[1][1]] == "CONFIRMED" and statuses[people[3][1]] == "DUE"


def test_echange_de_mois_accepte_puis_valide(client):
    people, pot = _started(client, size=4)
    url = f"/api/v1/kory/pots/{pot['id']}"
    (admin, _), (deputy, _), (abla, abla_id), (komi, komi_id) = people
    # Le tour en cours ne s'échange pas.
    assert client.post(f"{url}/swaps", json={"with_user_id": abla_id}, headers=admin).status_code == 409
    created = client.post(f"{url}/swaps", json={"with_user_id": komi_id, "message": "Je préfère plus tard."},
                          headers=abla).json()
    swap = created["swaps"][0]
    assert swap["status"] == "PENDING" and swap["message"]
    # Un autre membre voit l'échange, pas son message.
    assert client.get(url, headers=deputy).json()["swaps"][0]["message"] == "Je préfère plus tard."  # suppléant
    assert client.post(f"{url}/swaps/{swap['id']}/approve", headers=admin).status_code == 409
    assert client.post(f"{url}/swaps/{swap['id']}/accept", headers=abla).status_code == 403
    client.post(f"{url}/swaps/{swap['id']}/accept", headers=komi)
    done = client.post(f"{url}/swaps/{swap['id']}/approve", headers=deputy).json()
    by_round = {r["number"]: r["beneficiary_id"] for r in done["rounds"]}
    assert by_round[swap["requester_round"]] == komi_id and by_round[swap["target_round"]] == abla_id
    assert done["swaps"][0]["status"] == "DONE"


def test_dissolution_avec_motif(client):
    people, pot = _started(client, size=3)
    url = f"/api/v1/kory/pots/{pot['id']}"
    assert client.post(f"{url}/dissolve", json={"reason": "Départ"}, headers=people[2][0]).status_code == 403
    assert client.post(f"{url}/dissolve", json={"reason": ""}, headers=people[0][0]).status_code == 422
    done = client.post(f"{url}/dissolve", json={"reason": "Trois membres ont quitté le quartier."},
                       headers=people[0][0]).json()
    assert done["status"] == "CLOSED" and done["dissolve_reason"].startswith("Trois membres")
    assert [r["status"] for r in done["rounds"]] == ["DONE", "CANCELLED", "CANCELLED"]
    assert client.post(f"{url}/entries", json={"amount": 5000}, headers=people[1][0]).status_code == 409
    inbox = client.get("/api/v1/notifications", headers=people[1][0]).json()
    assert any("Trois membres" in item["body"] for item in inbox["items"])


def test_aucune_route_kory_ne_parle_de_solde(client):
    people, pot = _started(client, size=2)
    body = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=people[0][0]).json()
    assert "balance" not in body and "wallet" not in body
    assert not any(k for k in body if "balance" in k)
    with TestingSessionLocal() as db:
        assert db.query(KoryEntry).count() == 0
