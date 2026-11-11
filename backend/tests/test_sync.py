from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app
from app.models.sync import SyncEvent
from app.services.messaging import sync_service
from app.core.security import get_current_user


def test_sync_events_are_cursor_paginated_and_account_scoped():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    previous_db = app.dependency_overrides.get(get_db)
    previous_user = app.dependency_overrides.get(get_current_user)
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = lambda: {"user_id": 11}
    try:
        with testing_session() as db:
            db.add_all([
                SyncEvent(user_id=11, event_type="message:new", payload={"message_id": "a"}),
                SyncEvent(user_id=22, event_type="message:new", payload={"message_id": "private"}),
                SyncEvent(user_id=11, event_type="group:updated", payload={"group_id": 4}),
            ])
            db.commit()

        with TestClient(app) as client:
            first = client.get("/api/v1/sync/events?cursor=0&limit=1")
            assert first.status_code == 200
            assert [event["payload"] for event in first.json()["events"]] == [
                {"message_id": "a"}
            ]
            assert first.json()["has_more"] is True
            cursor = first.json()["next_cursor"]

            second = client.get(f"/api/v1/sync/events?cursor={cursor}&limit=1")
            assert second.status_code == 200
            assert [event["payload"] for event in second.json()["events"]] == [
                {"group_id": 4}
            ]
            assert second.json()["has_more"] is False

            empty = client.get(f"/api/v1/sync/events?cursor={second.json()['next_cursor']}")
            assert empty.status_code == 200
            assert empty.json()["events"] == []
    finally:
        if previous_db is None:
            app.dependency_overrides.pop(get_db, None)
        else:
            app.dependency_overrides[get_db] = previous_db
        if previous_user is None:
            app.dependency_overrides.pop(get_current_user, None)
        else:
            app.dependency_overrides[get_current_user] = previous_user
        engine.dispose()


def test_only_durable_events_are_added_to_the_sync_journal(monkeypatch):
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    monkeypatch.setattr(sync_service, "SessionLocal", testing_session)

    assert sync_service.persist_delivered_event(
        11, {"type": "call:invite", "room": "room-1"}
    ) is None
    event_id = sync_service.persist_delivered_event(
        11, {"type": "message:new", "message": {"id": "message-1"}}
    )

    assert event_id is not None
    with testing_session() as db:
        rows = db.query(SyncEvent).all()
        assert len(rows) == 1
        assert rows[0].event_type == "message:new"
        assert rows[0].payload["message"]["id"] == "message-1"

    engine.dispose()


def test_transactional_sync_event_rolls_back_with_business_transaction():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    with testing_session() as db:
        event = sync_service.append_sync_event(
            db,
            11,
            {"type": "message:deleted", "message_id": "message-1"},
        )
        assert event is not None
        db.rollback()

    with testing_session() as db:
        assert db.query(SyncEvent).count() == 0

    engine.dispose()

def test_un_curseur_d_une_base_precedente_repart_du_debut():
    """Après une remise à zéro, les numéros repartent de 1. Un téléphone qui
    garde « après 93 » sautait tout ce qui arrivait ensuite : son curseur
    est reconnu comme venant d'une autre base, et la lecture repart de 0."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    testing_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    previous_db = app.dependency_overrides.get(get_db)
    previous_user = app.dependency_overrides.get(get_current_user)
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = lambda: {"user_id": 7}
    try:
        with testing_session() as db:
            db.add_all([
                SyncEvent(user_id=7, event_type="message:new", payload={"n": 1}),
                SyncEvent(user_id=7, event_type="message:new", payload={"n": 2}),
            ])
            db.commit()
        with TestClient(app) as client:
            # Entier nu d'une ancienne version, plus grand que tout ce qui existe.
            stale = client.get("/api/v1/sync/events?cursor=93").json()
            assert [e["payload"]["n"] for e in stale["events"]] == [1, 2]
            assert stale["cursor_reset"] is True
            # Les numéros publiés portent la génération de la base.
            generation = stale["next_cursor"].split(".")[0]
            assert all(e["id"].startswith(generation + ".") for e in stale["events"])
            # Curseur d'une autre génération : même chose.
            other = client.get("/api/v1/sync/events?cursor=deadbeef.1").json()
            assert [e["payload"]["n"] for e in other["events"]] == [1, 2]
            assert other["cursor_reset"] is True
            # Curseur de la génération courante : lecture normale.
            ok = client.get(f"/api/v1/sync/events?cursor={generation}.1").json()
            assert [e["payload"]["n"] for e in ok["events"]] == [2]
            assert ok["cursor_reset"] is False
            # Entier nu plausible (version actuelle de l'app) : accepté.
            legacy = client.get("/api/v1/sync/events?cursor=1").json()
            assert [e["payload"]["n"] for e in legacy["events"]] == [2]
            assert legacy["cursor_reset"] is False
    finally:
        if previous_db is None:
            app.dependency_overrides.pop(get_db, None)
        else:
            app.dependency_overrides[get_db] = previous_db
        if previous_user is None:
            app.dependency_overrides.pop(get_current_user, None)
        else:
            app.dependency_overrides[get_current_user] = previous_user
        engine.dispose()
