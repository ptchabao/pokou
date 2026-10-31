"""Kory, de bout en bout : un journal, jamais un portefeuille (BM-01)."""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
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
    assert tg["delivery_price"] == 1000
    assert ci["country"] == "CI" and "kory" not in ci["modules"]
    assert ci["pharmacy_monthly_price"] == 7500


def test_reglage_systeme_ouvre_un_module_sans_publication(client):
    ivoire, _ = _signup(client, "+2250700445566")
    with TestingSessionLocal() as db:
        db.add(SystemSetting(key="country.CI", value='{"modules": ["discussions", "kory"]}'))
        db.commit()
    assert "kory" in client.get("/api/v1/config/country", headers=ivoire).json()["modules"]
    assert client.get("/api/v1/kory/pots", headers=ivoire).status_code == 200


def test_kory_ferme_hors_pays_lance(client):
    ivoire, _ = _signup(client, "+2250700778899")
    assert client.get("/api/v1/kory/pots", headers=ivoire).status_code == 404


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
