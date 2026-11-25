"""Retour de l'équipe de test sur la messagerie :

- « Mon numéro de téléphone » visible par mes contacts ou masqué (avec une
  liste de personnes autorisées), et jamais le numéro d'un membre de groupe ;
- position et fiche contact CHIFFRÉES dans une discussion à deux, position
  chiffrée dans un groupe, et pas de fiche contact dans un groupe ;
- « Supprimer la discussion » pour soi seulement.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import DirectMessage, GroupInvitation, GroupInvitationStatus, GroupMessage
from app.services.auth import otp_service
from app.services.messaging import group_invitation_service
from tests.helpers import GroupCryptoClient

TEST_DATABASE_URL = "sqlite:///./test_pokou_chat_numero.db"

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
    yield GroupCryptoClient(TestClient(app))
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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _add(client, headers, phone, name):
    response = client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers)
    assert response.status_code in (200, 201), response.text


def _profile(client, headers, user_id):
    response = client.get(f"/api/v1/users/{user_id}/profile", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _group_of_three(client, prefix):
    """A crée le groupe (et a donc B et C dans son carnet) ; B et C ne se
    connaissent que par le groupe."""
    headers_a, user_a = _signup(client, f"{prefix}1")
    headers_b, user_b = _signup(client, f"{prefix}2")
    headers_c, user_c = _signup(client, f"{prefix}3")
    _add(client, headers_a, f"{prefix}2", "Bob")
    _add(client, headers_a, f"{prefix}3", "Carla")
    group = client.post(
        "/api/v1/groups",
        json={"name": "Marché", "member_user_ids": [user_b, user_c]},
        headers=headers_a,
    ).json()
    with TestingSessionLocal() as db:
        for user_id in (user_b, user_c):
            invitation = db.query(GroupInvitation).filter(
                GroupInvitation.group_id == group["id"],
                GroupInvitation.user_id == user_id,
                GroupInvitation.status == GroupInvitationStatus.PENDING,
            ).first()
            if invitation is not None:
                group_invitation_service.accepter(db, invitation)
        db.commit()
    return group, (headers_a, user_a), (headers_b, user_b), (headers_c, user_c)


_SEALED = {"encryption": "v1", "ciphertext": "Y2hpZmZyZQ==", "envelope": {"v": 1}}


# ─── Numéro de téléphone ─────────────────────────────────────────────────────

def test_par_defaut_le_numero_est_visible_par_les_contacts_seulement(client):
    group, (headers_a, _), (headers_b, user_b), (headers_c, user_c) = _group_of_three(
        client, "+2289440000"
    )
    # A a C dans son carnet : il voit son numéro.
    profile = _profile(client, headers_a, user_c)
    assert profile["phone"] == "+22894400003"
    assert profile["phone_hidden"] is False
    # B ne connaît C que par le groupe : pas de numéro.
    profile = _profile(client, headers_b, user_c)
    assert profile["phone"] is None
    assert profile["phone_hidden"] is True

    settings = client.get("/api/v1/account-privacy/privacy", headers=headers_c).json()
    assert settings["phone_number"] == "CONTACTS"


def test_un_numero_masque_ne_part_plus_sauf_aux_personnes_autorisees(client):
    headers_a, user_a = _signup(client, "+22894400011")
    headers_b, user_b = _signup(client, "+22894400012")
    headers_c, user_c = _signup(client, "+22894400013")
    _add(client, headers_a, "+22894400012", "Bob")
    _add(client, headers_a, "+22894400013", "Carla")
    assert _profile(client, headers_b, user_a)["phone"] == "+22894400011"

    response = client.put(
        "/api/v1/account-privacy/privacy", json={"phone_number": "HIDDEN"}, headers=headers_a
    )
    assert response.status_code == 200, response.text
    assert response.json()["phone_number"] == "HIDDEN"
    for headers in (headers_b, headers_c):
        profile = _profile(client, headers, user_a)
        assert profile["phone"] is None and profile["phone_hidden"] is True

    response = client.put(
        "/api/v1/account-privacy/privacy/phone-exceptions",
        json={"user_ids": [user_c]},
        headers=headers_a,
    )
    assert response.status_code == 200, response.text
    assert response.json()["user_ids"] == [user_c]
    assert client.get(
        "/api/v1/account-privacy/privacy/phone-exceptions", headers=headers_a
    ).json()["user_ids"] == [user_c]
    assert _profile(client, headers_c, user_a)["phone"] == "+22894400011"
    assert _profile(client, headers_b, user_a)["phone"] is None
    # Soi-même : toujours.
    assert _profile(client, headers_a, user_a)["phone"] == "+22894400011"


def test_seuls_des_contacts_peuvent_etre_autorises(client):
    headers_a, _ = _signup(client, "+22894400021")
    _, user_x = _signup(client, "+22894400022")
    response = client.put(
        "/api/v1/account-privacy/privacy/phone-exceptions",
        json={"user_ids": [user_x]},
        headers=headers_a,
    )
    assert response.status_code == 403


def test_une_valeur_inconnue_pour_le_numero_est_refusee(client):
    headers_a, _ = _signup(client, "+22894400031")
    response = client.put(
        "/api/v1/account-privacy/privacy", json={"phone_number": "EVERYONE"}, headers=headers_a
    )
    assert response.status_code == 422
    assert client.get("/api/v1/account-privacy/privacy", headers=headers_a).json()[
        "phone_number"
    ] == "CONTACTS"


def test_un_groupe_ne_montre_jamais_le_numero_de_ses_membres(client):
    group, (headers_a, _), (headers_b, _), (headers_c, user_c) = _group_of_three(
        client, "+2289440004"
    )
    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "salut"}, headers=headers_c
    )
    assert sent.status_code == 200, sent.text
    for response in (
        client.get(f"/api/v1/groups/{group['id']}", headers=headers_b),
        client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_b),
        client.get("/api/v1/conversations", headers=headers_b),
    ):
        assert response.status_code == 200, response.text
        assert "94400043" not in response.text
        assert "22894400043" not in response.text


# ─── Position et fiche contact chiffrées ─────────────────────────────────────

def test_position_et_fiche_contact_chiffrees_dans_une_discussion_a_deux(client):
    headers_a, user_a = _signup(client, "+22894400051")
    headers_b, user_b = _signup(client, "+22894400052")
    _add(client, headers_a, "+22894400052", "Bob")

    for message_type in ("LOCATION", "CONTACT"):
        response = client.post(
            "/api/v1/messages",
            json={"recipient_id": user_b, "message_type": message_type, **_SEALED},
            headers=headers_a,
        )
        assert response.status_code == 200, response.text
        assert response.json()["message_type"] == message_type
        assert response.json()["content"] is None

        # En clair par cette route : refusé, le serveur ne doit pas le lire.
        response = client.post(
            "/api/v1/messages",
            json={"recipient_id": user_b, "message_type": message_type, "content": "6.13,1.22"},
            headers=headers_a,
        )
        assert response.status_code == 400

    with TestingSessionLocal() as db:
        rows = db.query(DirectMessage).filter(DirectMessage.sender_id == user_a).all()
        assert len(rows) == 2
        assert all(row.content is None and row.payload is None for row in rows)


def test_position_chiffree_dans_un_groupe_mais_pas_de_fiche_contact(client):
    group, (headers_a, _), _, _ = _group_of_three(client, "+2289440006")
    response = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "LOCATION", "content": "chiffré"},
        headers=headers_a,
    )
    assert response.status_code == 200, response.text
    response = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "CONTACT", "content": "chiffré"},
        headers=headers_a,
    )
    assert response.status_code == 400
    response = client.post(
        "/api/v1/polls/contact-card",
        json={
            "kind": "group",
            "target_id": group["id"],
            "contacts": [{"display_name": "Awa", "phone": "+22890000000"}],
        },
        headers=headers_a,
    )
    assert response.status_code == 400
    with TestingSessionLocal() as db:
        assert db.query(GroupMessage).filter(GroupMessage.group_id == group["id"]).count() == 1


# ─── Supprimer la discussion (pour moi) ──────────────────────────────────────

def test_supprimer_la_discussion_pour_moi_seulement(client):
    headers_a, user_a = _signup(client, "+22894400071")
    headers_b, user_b = _signup(client, "+22894400072")
    _add(client, headers_a, "+22894400072", "Bob")
    _add(client, headers_b, "+22894400071", "Alice")
    for text in ("un", "deux"):
        assert client.post(
            "/api/v1/messages", json={"recipient_id": user_b, "content": text}, headers=headers_a
        ).status_code == 200

    response = client.delete(f"/api/v1/messages/{user_a}/history", headers=headers_b)
    assert response.status_code == 200, response.text

    # Chez B : plus d'historique, plus de ligne dans la liste, plus de non-lus.
    history = client.get(f"/api/v1/messages/{user_a}", headers=headers_b).json()
    assert history["items"] == [] and history["total"] == 0
    items = client.get("/api/v1/conversations", headers=headers_b).json()["items"]
    assert all(row.get("contact_user_id") != user_a for row in items)

    # Chez A : rien n'a bougé.
    assert client.get(f"/api/v1/messages/{user_b}", headers=headers_a).json()["total"] == 2

    # Un nouveau message fait revenir la discussion, sans ce qui précède.
    assert client.post(
        "/api/v1/messages", json={"recipient_id": user_b, "content": "trois"}, headers=headers_a
    ).status_code == 200
    history = client.get(f"/api/v1/messages/{user_a}", headers=headers_b).json()
    assert [m["content"] for m in history["items"]] == ["trois"]
    items = client.get("/api/v1/conversations", headers=headers_b).json()["items"]
    row = next(r for r in items if r.get("contact_user_id") == user_a)
    assert row["unread_count"] == 1


def test_supprimer_une_discussion_inconnue(client):
    headers_a, user_a = _signup(client, "+22894400081")
    assert client.delete(f"/api/v1/messages/{user_a}/history", headers=headers_a).status_code == 400
    assert client.delete("/api/v1/messages/999999/history", headers=headers_a).status_code == 404
