"""Kory : les données que la maquette du 11 novembre 2026 ajoute aux écrans.

Opérateur de l'envoi (écrans 4 et 5), jour d'échéance d'une cotisation
(17, 19, 21), rappels par membre (21), frais Kory Plus réglés pour les
autres (8). Toujours un journal, jamais un portefeuille (BM-01).
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
from app.models import Group, GroupMember, SystemSetting
from app.models.service_notifications import ServiceNotification
from app.services.auth import otp_service
from app.services.kory import cotisation as cotisation_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_kory_maquette.db"

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


def test_numero_masque_de_l_auteur_pour_reconnaitre_son_operateur(client):
    """Écran 4 : « Flooz · réf. … » sous chaque déclaration. Le numéro de
    l'auteur, masqué, va au collecteur et à l'auteur ; pas au reste du groupe."""
    organizer, _ = _signup(client)
    pot = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    author, _ = _signup(client, "+22896112233")
    other, _ = _signup(client)
    for headers in (author, other):
        client.post("/api/v1/kory/join", json={"code": pot["join_code"]}, headers=headers)
    client.post(
        f"/api/v1/kory/pots/{pot['id']}/entries",
        json={"amount": 1000, "wallet_reference": "REF-1"},
        headers=author,
    )
    seen_by = lambda h: client.get(f"/api/v1/kory/pots/{pot['id']}", headers=h).json()["entries"][0]  # noqa: E731
    assert seen_by(organizer)["contributor_phone_masked"] == "+228 96 •• •• 33"
    assert seen_by(author)["contributor_phone_masked"] == "+228 96 •• •• 33"
    assert "contributor_phone_masked" not in seen_by(other)


# ── Cotisation : rappels J−2, jour J, J+1 (écran 21) ──────────────────────

def _group(user_ids, name="Les Amis de Bè"):
    with TestingSessionLocal() as db:
        group = Group(name=name, created_by=user_ids[0])
        db.add(group)
        db.flush()
        for index, uid in enumerate(user_ids):
            db.add(GroupMember(group_id=group.id, user_id=uid, role="OWNER" if index == 0 else "MEMBER"))
        db.commit()
        return group.id


def _cotisation(client, first_due):
    (organizer, organizer_id), (ama, ama_id), (edem, edem_id) = [_signup(client) for _ in range(3)]
    group_id = _group([organizer_id, ama_id, edem_id])
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "COTISATION", "title": "Cotisation des Amis de Bè", "amount_per_member": 2000,
              "period": "MONTHLY", "group_id": group_id, "due_at": first_due.isoformat()},
        headers=organizer,
    ).json()
    return pot, (organizer, organizer_id), (ama, ama_id), (edem, edem_id)


def _inbox(user_id):
    with TestingSessionLocal() as db:
        return [n.body for n in db.query(ServiceNotification).filter(ServiceNotification.user_id == user_id)]


def test_rappels_j_moins_2_une_seule_fois_et_coupables_par_membre(client):
    now = datetime(2026, 12, 3, 9, 0)
    pot, (organizer, organizer_id), (ama, ama_id), (edem, edem_id) = _cotisation(client, datetime(2026, 12, 5, 12))
    assert pot["cotisation"]["my_reminders"] is True

    # Edem coupe ses rappels : l'interrupteur le dit, et il n'est plus prévenu.
    muted = client.put(f"/api/v1/kory/pots/{pot['id']}/reminders", json={"enabled": False}, headers=edem)
    assert muted.status_code == 200 and muted.json()["cotisation"]["my_reminders"] is False

    with TestingSessionLocal() as db:
        assert cotisation_service.send_due_reminders(db, now) == 2  # l'organisateur et Ama
        # Le planificateur repasse : rien de plus.
        assert cotisation_service.send_due_reminders(db, now + timedelta(minutes=15)) == 0
    assert any("2 jours" in body for body in _inbox(ama_id))
    assert not any("2 jours" in body for body in _inbox(edem_id))

    # Le jour J, Ama a déclaré : seul l'organisateur est rappelé.
    client.post(f"/api/v1/kory/pots/{pot['id']}/entries", json={"amount": 2000}, headers=ama)
    with TestingSessionLocal() as db:
        assert cotisation_service.send_due_reminders(db, datetime(2026, 12, 5, 8)) == 1

    # Il remet ses rappels : la relance J+1 le concerne de nouveau.
    client.put(f"/api/v1/kory/pots/{pot['id']}/reminders", json={"enabled": True}, headers=edem)
    with TestingSessionLocal() as db:
        assert cotisation_service.send_due_reminders(db, datetime(2026, 12, 6, 8)) == 2
    assert any("Échéance passée" in body for body in _inbox(edem_id))


def test_les_rappels_ne_concernent_que_les_membres_d_une_cotisation(client):
    organizer, _ = _signup(client)
    stranger, _ = _signup(client)
    cagnotte = client.post("/api/v1/kory/pots", json={"title": "Baptême"}, headers=organizer).json()
    assert client.put(
        f"/api/v1/kory/pots/{cagnotte['id']}/reminders", json={"enabled": False}, headers=organizer
    ).status_code == 409
    pot, *_ = _cotisation(client, datetime.utcnow() + timedelta(days=10))
    assert client.put(
        f"/api/v1/kory/pots/{pot['id']}/reminders", json={"enabled": False}, headers=stranger
    ).status_code in (403, 404)


# ── Kory Plus : l'administrateur paie pour les autres (écran 8) ──────────

@pytest.fixture
def cashpay():
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.side_effect = lambda db, **kw: {
            "order_reference": kw["merchant_reference"], "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


def _paid_tontine(client, size=4):
    people = [_signup(client) for _ in range(size)]
    ids = [uid for _, uid in people]
    with TestingSessionLocal() as db:
        db.query(SystemSetting).filter(SystemSetting.key == "country.TG").delete()
        db.add(SystemSetting(key="country.TG", value='{"modules": ["discussions", "kory", "kory_plus", "honam"]}'))
        db.commit()
    pot = client.post(
        "/api/v1/kory/pots",
        json={"kind": "TONTINE", "title": "Tontine des voisins", "amount_per_member": 5000, "period": "MONTHLY",
              "group_id": _group(ids, "Voisins de Bè"), "rotation": ids, "draw_mode": "FIXED"},
        headers=people[0][0],
    )
    assert pot.status_code == 201, pot.text
    return people, pot.json()


def _confirm(opened):
    from app.models import MarketplacePayment
    from app.services.marketplace.marketplace_monetization_service import confirm_payment

    with TestingSessionLocal() as db:
        reference = db.get(MarketplacePayment, opened["payment_id"]).provider_reference
        confirm_payment(db, reference)


def test_payer_pour_les_restants_regle_leurs_frais_sans_accepter_a_leur_place(client, cashpay):
    people, pot = _paid_tontine(client, size=4)
    url = f"/api/v1/kory/pots/{pot['id']}"
    # Un membre paie pour lui-même ; l'administrateur règle les 3 autres.
    _confirm(client.post(f"{url}/fee", headers=people[1][0]).json())
    opened = client.post(f"{url}/fee", json={"for_others": True}, headers=people[0][0])
    assert opened.status_code == 200 and opened.json()["amount"] == 3 * 1180
    _confirm(opened.json())

    seen = client.get(url, headers=people[0][0]).json()
    assert seen["plus_fee"]["paid_count"] == 4 and seen["status"] == "PENDING"
    others = [m for m in seen["members"] if m["user_id"] in (people[2][1], people[3][1])]
    assert all(m["fee_paid"] and not m["accepted"] for m in others)

    # Chacun accepte encore lui-même ; le dernier « oui » démarre la tontine.
    for headers, _ in people[2:]:
        assert client.post(f"{url}/accept", headers=headers).status_code == 200
    assert client.get(url, headers=people[0][0]).json()["status"] == "OPEN"


def test_seul_l_administrateur_paie_pour_les_autres(client, cashpay):
    people, pot = _paid_tontine(client, size=3)
    response = client.post(f"/api/v1/kory/pots/{pot['id']}/fee", json={"for_others": True}, headers=people[1][0])
    assert response.status_code == 403
