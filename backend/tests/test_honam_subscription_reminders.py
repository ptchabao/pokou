from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import Pharmacy, PharmacyStaff
from app.services.honam.subscription_reminders import send_due_subscription_reminders


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)
        engine.dispose()


def _pharmacy(db, *, expiry, staff_id):
    pharmacy = Pharmacy(
        country="TG",
        name="Pharmacie du Bè",
        address="Lomé",
        phone="+22822000000",
        latitude=6.13,
        longitude=1.22,
        subscription_plan="WETRI",
        subscription_until=expiry,
    )
    db.add(pharmacy)
    db.flush()
    db.add(PharmacyStaff(pharmacy_id=pharmacy.id, user_id=staff_id, role="TITULAIRE"))
    db.flush()
    return pharmacy


def test_sends_j7_and_j1_once_for_each_subscription_expiry(db):
    now = datetime(2026, 11, 4, 12)
    j7_pharmacy = _pharmacy(db, expiry=now + timedelta(days=7), staff_id=10)
    j1_pharmacy = _pharmacy(db, expiry=now + timedelta(days=1), staff_id=20)
    db.commit()

    with patch("app.services.honam.subscription_reminders.send_push") as push:
        assert send_due_subscription_reminders(db, now) == {"j7": 1, "j1": 1}
        assert send_due_subscription_reminders(db, now) == {"j7": 0, "j1": 0}

    assert push.call_count == 2
    assert {call.args[1] for call in push.call_args_list} == {10, 20}
    assert {call.kwargs["data"]["interval_days"] for call in push.call_args_list} == {"7", "1"}
    db.refresh(j7_pharmacy)
    db.refresh(j1_pharmacy)
    assert j7_pharmacy.subscription_reminder_7d_for == j7_pharmacy.subscription_until
    assert j1_pharmacy.subscription_reminder_1d_for == j1_pharmacy.subscription_until


def test_renewed_expiry_gets_a_new_j7_reminder(db):
    now = datetime(2026, 11, 4, 12)
    pharmacy = _pharmacy(db, expiry=now + timedelta(days=7), staff_id=10)
    db.commit()

    with patch("app.services.honam.subscription_reminders.send_push") as push:
        assert send_due_subscription_reminders(db, now) == {"j7": 1, "j1": 0}
        pharmacy.subscription_until = now + timedelta(days=30)
        db.commit()
        assert send_due_subscription_reminders(db, now + timedelta(days=23)) == {"j7": 1, "j1": 0}

    assert push.call_count == 2


def test_does_not_send_outside_j7_or_j1(db):
    now = datetime(2026, 11, 4, 12)
    _pharmacy(db, expiry=now + timedelta(days=6), staff_id=10)
    _pharmacy(db, expiry=now - timedelta(days=1), staff_id=20)
    db.commit()

    with patch("app.services.honam.subscription_reminders.send_push") as push:
        assert send_due_subscription_reminders(db, now) == {"j7": 0, "j1": 0}

    push.assert_not_called()
