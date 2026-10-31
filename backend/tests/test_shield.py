from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.services.auth import otp_service
from app.services.privacy import shield_service as svc

TEST_DATABASE_URL = "sqlite:///./test_pokou_shield.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()




@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    # L'override est posé PAR TEST et retiré ensuite, jamais au niveau du
    # module : pytest importe tous les fichiers de test avant d'en exécuter
    # un seul, donc une affectation au niveau module est écrasée par celle
    # du dernier fichier importé. Toutes les suites se retrouvaient alors à
    # lire la base d'une autre — ce qui ne se voit qu'en lançant la suite
    # entière, et jamais un fichier seul.
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    import re
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    response = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    body = response.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"], body["access_token"]


# ─── Tags de contact (prérequis Mode Bouclier) ────────────────────────────────

def test_set_contact_priority_tag(client):
    headers_a, _, _ = _signup(client, "+22894000001")
    _, _, _ = _signup(client, "+22894000002")
    created = client.post(
        "/api/v1/contacts", json={"phone": "+22894000002", "display_name": "Fournisseur X"}, headers=headers_a
    ).json()

    response = client.put(
        f"/api/v1/contacts/{created['id']}", json={"priority_tag": "fournisseur"}, headers=headers_a
    )
    assert response.status_code == 200, response.text
    assert response.json()["priority_tag"] == "FOURNISSEUR"


def test_invalid_priority_tag_rejected(client):
    headers_a, _, _ = _signup(client, "+22894000003")
    _, _, _ = _signup(client, "+22894000004")
    created = client.post(
        "/api/v1/contacts", json={"phone": "+22894000004", "display_name": "Bob"}, headers=headers_a
    ).json()

    response = client.put(f"/api/v1/contacts/{created['id']}", json={"priority_tag": "bogus"}, headers=headers_a)
    assert response.status_code == 400


def test_cannot_tag_someone_elses_contact(client):
    headers_a, _, _ = _signup(client, "+22894000005")
    headers_b, _, _ = _signup(client, "+22894000006")
    _, _, _ = _signup(client, "+22894000007")
    created_by_b = client.post(
        "/api/v1/contacts", json={"phone": "+22894000007", "display_name": "Charlie"}, headers=headers_b
    ).json()

    response = client.put(
        f"/api/v1/contacts/{created_by_b['id']}", json={"priority_tag": "boss"}, headers=headers_a
    )
    assert response.status_code == 404


# ─── /shield/context ──────────────────────────────────────────────────────────

def test_context_falls_back_to_low_score_without_llm(client):
    headers, _, _ = _signup(client, "+22894000008")

    async def _no_provider(_messages):
        return None

    with patch.object(svc, "_call_llm_json", _no_provider):
        response = client.post(
            "/api/v1/shield/context",
            json={"recent_messages": ["[NOM] dit [MONTANT] pour [OBJET] à [LIEU] sont prêts."]},
            headers=headers,
        )
    assert response.status_code == 200, response.text
    assert response.json()["focus_score"] == 1


def test_context_empty_messages_returns_low_score(client):
    headers, _, _ = _signup(client, "+22894000009")
    response = client.post("/api/v1/shield/context", json={"recent_messages": []}, headers=headers)
    assert response.status_code == 200
    assert response.json()["focus_score"] == 1


def test_context_uses_llm_score_when_available(client):
    headers, _, _ = _signup(client, "+22894000010")

    async def _fake_provider(_messages):
        return {"focus_score": 9}

    with patch.object(svc, "_call_llm_json", _fake_provider):
        response = client.post(
            "/api/v1/shield/context",
            json={"recent_messages": ["[NOM] confirme la commande de [MONTANT]."]},
            headers=headers,
        )
    assert response.status_code == 200
    assert response.json()["focus_score"] == 9


def test_context_clamps_out_of_range_score(client):
    headers, _, _ = _signup(client, "+22894000011")

    async def _fake_provider(_messages):
        return {"focus_score": 42}

    with patch.object(svc, "_call_llm_json", _fake_provider):
        response = client.post(
            "/api/v1/shield/context", json={"recent_messages": ["salut"]}, headers=headers
        )
    assert response.json()["focus_score"] == 10


# ─── /shield/evaluate ──────────────────────────────────────────────────────────

def test_evaluate_allows_when_context_score_below_threshold(client):
    headers, _, _ = _signup(client, "+22894000012")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={"context_score": 3, "event_type": "message", "sender_known": True},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["decision"] == "ALLOW"


def test_evaluate_allows_whitelisted_keyword(client):
    headers, _, _ = _signup(client, "+22894000013")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={
            "context_score": 9,
            "event_type": "message",
            "hashed_text": "[SALUT] c'est urgent, rappelle-moi",
            "sender_known": True,
        },
        headers=headers,
    )
    assert response.json()["decision"] == "ALLOW"


def test_evaluate_allows_priority_contact(client):
    headers, _, _ = _signup(client, "+22894000014")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={"context_score": 9, "event_type": "call", "sender_tag": "boss", "sender_known": True},
        headers=headers,
    )
    assert response.json()["decision"] == "ALLOW"


def test_evaluate_defers_message_from_non_priority_contact(client):
    headers, _, _ = _signup(client, "+22894000015")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={"context_score": 9, "event_type": "message", "sender_tag": "ami", "sender_known": True},
        headers=headers,
    )
    assert response.json()["decision"] == "DEFER"


def test_evaluate_defers_call_from_unknown_number(client):
    headers, _, _ = _signup(client, "+22894000016")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={"context_score": 8, "event_type": "call", "sender_known": False},
        headers=headers,
    )
    assert response.json()["decision"] == "DEFER"


def test_evaluate_defers_large_group_message(client):
    headers, _, _ = _signup(client, "+22894000017")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={"context_score": 9, "event_type": "message", "sender_known": True, "group_size": 25},
        headers=headers,
    )
    assert response.json()["decision"] == "DEFER"


def test_evaluate_allows_spam_burst_override(client):
    headers, _, _ = _signup(client, "+22894000018")
    response = client.post(
        "/api/v1/shield/evaluate",
        json={
            "context_score": 9,
            "event_type": "message",
            "sender_tag": "ami",
            "sender_known": True,
            "sender_message_count_last_minute": 15,
        },
        headers=headers,
    )
    assert response.json()["decision"] == "ALLOW"
