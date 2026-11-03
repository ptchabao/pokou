"""L'outbox : un évènement par écriture, publié dans l'ordre, jamais perdu."""
import asyncio
import json
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import OutboxEvent
from app.services.auth import otp_service
from app.services.events.outbox import publish_pending, record_event

TEST_DATABASE_URL = "sqlite:///./test_pokou_outbox.db"

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


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}


def test_kory_ecrit_ses_evenements_sans_donnee_de_contact(client):
    organizer = _signup(client, "+22890123401")
    member = _signup(client, "+22890123402")
    pot = client.post("/api/v1/kory/pots", json={"title": "Mariage"}, headers=organizer).json()
    client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=member)
    entry = client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 5000, "wallet_reference": "SECRET-REF"},
        headers=member,
    ).json()
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries/{entry['id']}/review",
        json={"decision": "CONFIRM"},
        headers=organizer,
    )

    with TestingSessionLocal() as db:
        events = db.query(OutboxEvent).order_by(OutboxEvent.id).all()
    assert [e.event_type for e in events] == [
        "kory.pot.created",
        "kory.entry.declared",
        "kory.entry.confirmed",
    ]
    assert {e.key for e in events} == {f"pot-{pot['id']}"}
    for event in events:
        assert "SECRET-REF" not in event.payload
        assert "+228" not in event.payload
        envelope = json.loads(event.payload)
        assert envelope["version"] == 1 and envelope["data"]["pot_id"] == pot["id"]


def test_une_ecriture_annulee_n_emet_rien():
    Base.metadata.create_all(bind=engine)
    try:
        with TestingSessionLocal() as db:
            record_event(db, "kory.events", "kory.pot.created", {"pot_id": 1})
            db.rollback()
            assert db.query(OutboxEvent).count() == 0
    finally:
        Base.metadata.drop_all(bind=engine)


def test_relais_publie_dans_l_ordre_et_s_arrete_au_premier_echec():
    Base.metadata.create_all(bind=engine)
    try:
        with TestingSessionLocal() as db:
            for i in range(3):
                record_event(db, "kory.events", "kory.pot.created", {"pot_id": i}, key="pot-1")
            db.commit()

        sent = []

        async def flaky(topic, key, value):
            if len(sent) == 1:
                raise RuntimeError("courtier injoignable")
            sent.append((topic, key, json.loads(value)["data"]["pot_id"]))

        with TestingSessionLocal() as db:
            assert asyncio.run(publish_pending(db, flaky)) == 1

        async def ok(topic, key, value):
            sent.append((topic, key, json.loads(value)["data"]["pot_id"]))

        with TestingSessionLocal() as db:
            assert asyncio.run(publish_pending(db, ok)) == 2
            assert db.query(OutboxEvent).filter(OutboxEvent.published_at.is_(None)).count() == 0

        assert [s[2] for s in sent] == [0, 1, 2]
        assert sent[0][0] == "pokou.kory.events" and sent[0][1] == b"pot-1"
    finally:
        Base.metadata.drop_all(bind=engine)


def test_certificat_kafka_en_variable_pour_kubero():
    """Kubero ne monte pas de fichier depuis un Secret : le certificat de
    l'autorité arrive en PEM dans une variable, et passe avant le fichier."""
    from types import SimpleNamespace

    from app.workers import outbox_relay

    settings = SimpleNamespace(
        kafka_bootstrap_servers="kafka:9093", kafka_security_protocol="SASL_SSL",
        kafka_ssl_ca_pem="-----BEGIN CERTIFICATE-----\nAAA\n-----END CERTIFICATE-----\n",
        kafka_ssl_cafile="/etc/kafka-ca/ca.crt", kafka_sasl_mechanism="",
    )
    with patch.object(outbox_relay.ssl, "create_default_context") as context:
        outbox_relay._producer_kwargs(settings)
    context.assert_called_once_with(cadata=settings.kafka_ssl_ca_pem)
