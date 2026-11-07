"""Kory, de bout en bout : un journal, jamais un portefeuille (BM-01)."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.core.countries import country_config
from app.main import app
from app.models import SystemSetting
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_kory.db"

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


def test_configuration_du_pays_suit_le_numero(client):
    togo, _ = _signup(client, "+22890112233")
    ivoire, _ = _signup(client, "+2250700112233")

    tg = client.get("/api/v1/config/country", headers=togo).json()
    ci = client.get("/api/v1/config/country", headers=ivoire).json()

    assert tg["country"] == "TG" and "kory" in tg["modules"]
    assert "honam" in tg["modules"]
    assert tg["delivery_price"] == 1000
    assert ci["country"] == "CI" and "kory" in ci["modules"]
    assert "honam" in ci["modules"]
    assert ci["pharmacy_monthly_price"] == 7500


def test_honam_est_actif_par_defaut_meme_sans_pays_connu(client):
    with TestingSessionLocal() as db:
        assert "honam" in country_config(db, None)["modules"]


def test_reglage_systeme_ne_ferme_pas_kory_ni_honam(client):
    ivoire, _ = _signup(client, "+2250700445566")
    with TestingSessionLocal() as db:
        db.add(SystemSetting(key="country.CI", value='{"modules": ["discussions", "kory"]}'))
        db.commit()
    modules = client.get("/api/v1/config/country", headers=ivoire).json()["modules"]
    assert "kory" in modules
    assert "honam" in modules
    assert client.get("/api/v1/kory/pots", headers=ivoire).status_code == 200


def test_kory_est_ouvert_en_cote_divoire(client):
    ivoire, _ = _signup(client, "+2250700778899")
    assert client.get("/api/v1/kory/pots", headers=ivoire).status_code == 200


def test_pays_sans_configuration_active_kory_et_honam(client):
    with TestingSessionLocal() as db:
        modules = country_config(db, "BJ")["modules"]
    assert "kory" in modules
    assert "honam" in modules


def test_journal_declaration_puis_confirmation_par_le_collecteur(client):
    organizer, _ = _signup(client)
    member, _ = _signup(client)

    pot = client.post(
        "/api/v1/kory/pots",
        json={"title": "Mariage d'Afi", "goal_amount": 100000},
        headers=organizer,
    ).json()
    assert pot["confirmed_total"] == 0
    assert "balance" not in pot and "wallet" not in pot

    # Sans le code, la cagnotte n'existe pas pour un tiers.
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=member).status_code == 404
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=member)

    entry = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 5000, "wallet_reference": "MP2611.1234"},
        headers=member,
    ).json()
    assert entry["status"] == "DECLARED"

    # Une déclaration ne compte pas tant que le collecteur ne l'a pas reçue.
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=member).json()["confirmed_total"] == 0

    # Le membre ne confirme pas sa propre contribution.
    refused = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "CONFIRM"},
        headers=member,
    )
    assert refused.status_code == 403

    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "CONFIRM"},
        headers=organizer,
    )
    detail = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=member).json()
    assert detail["confirmed_total"] == 5000
    assert detail["my_confirmed_total"] == 5000
    assert client.get("/api/v1/kory/summary", headers=member).json()["month_confirmed_total"] == 5000


def test_refus_reste_au_journal(client):
    organizer, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Cotisation"}, headers=organizer).json()
    member, _ = _signup(client)
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=member)
    entry = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 2000}, headers=member
    ).json()
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "REJECT"},
        headers=organizer,
    )
    detail = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer).json()
    assert [e["status"] for e in detail["entries"]] == ["REJECTED"]
    assert detail["confirmed_total"] == 0


def test_reference_de_transaction_reservee_au_collecteur_et_a_l_auteur(client):
    organizer, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    author, _ = _signup(client)
    other, _ = _signup(client)
    for headers in (author, other):
        client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=headers)
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 1000, "wallet_reference": "REF-1"},
        headers=author,
    )
    seen_by = lambda h: client.get(f"/api/v1/kory/pots/{pot['id']}", headers=h).json()["entries"][0]  # noqa: E731
    assert seen_by(organizer)["wallet_reference"] == "REF-1"
    assert seen_by(author)["wallet_reference"] == "REF-1"
    assert "wallet_reference" not in seen_by(other)


def test_cotisation_demande_montant_et_periode(client):
    organizer, _ = _signup(client)
    bad = client.post("/api/v1/kory/pots", json={"kind": "COTISATION", "title": "Mensuelle"}, headers=organizer)
    assert bad.status_code == 422
    ok = client.post(
        "/api/v1/kory/pots",
        json={"kind": "COTISATION", "title": "Mensuelle", "amount_per_member": 2000, "period": "monthly"},
        headers=organizer,
    ).json()
    assert ok["period"] == "MONTHLY" and ok["amount_per_member"] == 2000


def test_tontine_reservee_a_kory_plus(client):
    organizer, _ = _signup(client)
    response = client.post("/api/v1/kory/pots", json={"kind": "TONTINE", "title": "Tontine"}, headers=organizer)
    assert response.status_code == 403


def test_cloture_par_l_organisateur_seulement(client):
    organizer, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Deuil"}, headers=organizer).json()
    member, _ = _signup(client)
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=member)
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=member).status_code == 403
    assert client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=organizer).json()["status"] == "CLOSED"
    late = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 500}, headers=member)
    assert late.status_code == 409


def test_une_contribution_previent_le_collecteur_en_temps_reel(client):
    from unittest.mock import AsyncMock

    from app.api.v1.messaging.ws import manager

    organizer, organizer_id = _signup(client)
    member, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=member)

    with patch.object(manager, "send_to_user", new=AsyncMock(return_value=True)) as envoi:
        client.post(
            f"/api/v1/kory/pots/{pot['id']}/entries",
            json={"amount": 1500, "wallet_reference": "MP1"},
            headers=member,
        )
        # La poussée part APRÈS le commit, dans une tâche : une requête de
        # plus laisse à la boucle le temps de l'exécuter.
        client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer)
        events = [(c.args[0], c.args[1]) for c in envoi.await_args_list]
    assert (organizer_id, {"type": "kory:updated", "pot_id": pot["id"]}) in events


def _pot_with_member(client, **pot):
    organizer, _ = _signup(client)
    body = {"title": "Anniversaire de Papa", **pot}
    created = client.post("/api/v1/kory/pots", json=body, headers=organizer).json()
    member, member_id = _signup(client)
    client.post("/api/v1/kory/join", json={"code": created["join_code"]}, headers=member)
    return organizer, member, member_id, created


def test_engagement_modifiable_8h_puis_ferme(client):
    from datetime import datetime, timedelta

    from app.models import KoryMember

    due = (datetime.utcnow() + timedelta(days=6)).isoformat()
    organizer, member, member_id, pot = _pot_with_member(client, due_at=due)
    url = f"/api/v1/kory/pots/{pot['id']}/pledge"

    first = client.put(url, json={"base": 15000, "daily": 500}, headers=member).json()
    mine = first["my_pledge"]
    assert mine["total"] == 15000 + 500 * mine["days"] and mine["days"] >= 5
    assert mine["is_firm"] is False and mine["remaining"] == mine["total"]
    # Le collecteur ne voit pas encore un engagement modifiable.
    seen = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer).json()
    assert seen["pledge_summary"]["engaged_count"] == 0

    # Corrigé dans les 8 h : accepté.
    assert client.put(url, json={"base": 10000}, headers=member).json()["my_pledge"]["total"] == 10000

    # 8 h plus tard (heure du serveur) : ferme, plus modifiable.
    with TestingSessionLocal() as db:
        row = db.query(KoryMember).filter(KoryMember.user_id == member_id).first()
        row.pledged_at = datetime.utcnow() - timedelta(hours=9)
        db.commit()
    assert client.put(url, json={"base": 5000}, headers=member).status_code == 409
    summary = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=organizer).json()["pledge_summary"]
    assert summary["engaged_total"] == 10000 and summary["remaining_count"] == 1

    # Seul le collecteur l'annule.
    cancel = f"/api/v1/kory/pots/{pot['id']}/pledges/{member_id}/cancel"
    assert client.post(cancel, headers=member).status_code == 403
    assert client.post(cancel, headers=organizer).status_code == 200
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=member).json()["my_pledge"] is None


def test_contribution_contestee_puis_renvoyee(client):
    organizer, member, _, pot = _pot_with_member(client)
    entry = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 5000, "wallet_reference": "TG26"}, headers=member
    ).json()
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "REJECT", "reason": "Rien reçu sur Flooz à cette heure-là."},
        headers=organizer,
    )
    seen = client.get(f"/api/v1/kory/pots/{pot['id']}", headers=member).json()["entries"][0]
    assert seen["status"] == "REJECTED" and seen["review_reason"].startswith("Rien reçu")

    resubmitted = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/resubmit",
        json={"wallet_reference": "TG2610311320B2"},
        headers=member,
    ).json()
    assert resubmitted["status"] == "DECLARED" and resubmitted["wallet_reference"] == "TG2610311320B2"


def test_le_collecteur_prolonge_la_collecte(client):
    from datetime import datetime, timedelta

    organizer, member, _, pot = _pot_with_member(client, due_at=(datetime.utcnow() + timedelta(days=1)).isoformat())
    later = (datetime.utcnow() + timedelta(days=8)).isoformat()
    url = f"/api/v1/kory/pots/{pot['id']}/extend"
    assert client.post(url, json={"due_at": later}, headers=member).status_code == 403
    extended = client.post(url, json={"due_at": later}, headers=organizer).json()
    assert extended["due_at"].startswith(later[:10]) and extended["extended_at"]
    past = (datetime.utcnow() - timedelta(days=1)).isoformat()
    assert client.post(url, json={"due_at": past}, headers=organizer).status_code == 422


def test_le_centre_de_notifications_recoit_les_evenements_kory(client):
    organizer, member, _, pot = _pot_with_member(client)
    entry = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 10000}, headers=member).json()
    inbox = client.get("/api/v1/notifications", headers=organizer).json()
    assert inbox["unread"] == 1
    assert inbox["items"][0]["service"] == "kory" and "a déclaré 10 000 FCFA. À confirmer." in inbox["items"][0]["body"]
    assert inbox["items"][0]["route"] == f"kory/{pot['id']}"

    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "CONFIRM"}, headers=organizer,
    )
    assert "a confirmé tes 10 000 FCFA" in client.get("/api/v1/notifications", headers=member).json()["items"][0]["body"]

    assert client.post("/api/v1/notifications/read-all", headers=organizer).json()["unread"] == 0
    assert client.get("/api/v1/notifications", headers=organizer).json()["unread"] == 0


def test_apres_la_cloture_on_verse_encore_le_reste_de_son_engagement(client):
    organizer, member, _, pot = _pot_with_member(client)
    other, _ = _signup(client)
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=other)
    client.put(f"/api/v1/kory/pots/{pot['id']}/pledge", json={"base": 8000}, headers=member)
    client.post(f"/api/v1/kory/pots/{pot['id']}/close", headers=organizer)
    ok = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 8000}, headers=member)
    assert ok.status_code == 201
    # Sans engagement, plus rien à déclarer après la clôture.
    late = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 500}, headers=other)
    assert late.status_code == 409


def test_une_capture_doit_venir_de_son_auteur(client):
    from app.models import MediaAsset

    organizer, member, _, pot = _pot_with_member(client)
    entry = client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 5000}, headers=member).json()
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "REJECT"}, headers=organizer,
    )
    stranger, stranger_id = _signup(client)
    with TestingSessionLocal() as db:
        asset = MediaAsset(uploader_id=stranger_id, mime_type="image/jpeg", size_bytes=10, storage_path="x")
        db.add(asset)
        db.commit()
        foreign_id = asset.id
    bad = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/resubmit",
        json={"proof_media_id": foreign_id}, headers=member,
    )
    assert bad.status_code == 403


def test_participants_de_pokou_et_invites_par_numero(client):
    organizer, _ = _signup(client, "+22890400001")
    friend, friend_id = _signup(client, "+22890400002")
    pot = client.post("/api/v1/kory/pots", json={"title": "Mariage d’Akossiwa"}, headers=organizer).json()
    with patch("app.services.notifications.sms_service.send_sms", return_value=True) as sms:
        added = client.post(
            f"/api/v1/kory/pots/{pot['id']}/participants",
            json={"user_ids": [friend_id], "phones": [{"phone": "+22891000007", "name": "Mensah Yawa"}]},
            headers=organizer,
        ).json()
    assert sms.call_count == 1 and "t'invite à la cagnotte" in sms.call_args.args[2]
    people = {p["name"]: p for p in added["participants"]}
    assert people["Mensah Yawa"]["on_pokou"] is False
    assert people["Mensah Yawa"]["phone"].endswith("•• •• 07")
    assert any(p.get("user_id") == friend_id for p in added["participants"])
    # Le participant de Pokou voit la cagnotte.
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=friend).status_code == 200

    # À l'inscription, l'invitée devient membre.
    yawa, _ = _signup(client, "+22891000007")
    assert client.get(f"/api/v1/kory/pots/{pot['id']}", headers=yawa).status_code == 200
