"""Un appel terminé se dépose dans le fil de sa conversation.

Un appel n'existait que dans le journal d'appels, écran séparé : l'histoire
d'une relation se lisait à deux endroits, et rien dans la conversation ne
rappelait qu'on s'était parlé mardi.

**Ce que ce fichier protège avant tout, c'est l'idempotence.** Un appel
atteint son état final par plusieurs chemins — tous les invités refusent,
l'appelant raccroche, le dernier participant quitte un appel de groupe — et
chacun passe par le même `db.commit()`. Sans la marque
`CallLog.thread_message_id`, le même appel déposerait deux bulles, et le
défaut ne se verrait qu'en production, sur les appels de groupe,
c'est-à-dire tard.

Le reste vérifie que la bulle dit la VÉRITÉ : la durée se compte depuis le
premier décroché et non depuis la sonnerie, un appel jamais décroché est
« manqué » et non « 0 seconde », et un appel encore en cours ne dépose rien
du tout.
"""
import re
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import CallLog, DirectMessage, GroupMessage, MessageType
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_call_thread_events.db"

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
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _patched_livekit():
    settings = MagicMock()
    settings.livekit_enabled = True
    settings.livekit_url = "wss://livekit.test"
    settings.livekit_token_ttl_minutes = 15
    settings.call_max_group_ring = 32
    settings.livekit_api_key = "cle"
    settings.livekit_api_secret = "secret"
    return (
        patch("app.services.calls.livekit_service.get_settings", return_value=settings),
        patch("app.api.v1.calls.calls.get_settings", return_value=settings),
    )


def _appeler(client, headers_a, user_id_b, is_video=False):
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        reponse = client.post(
            "/api/v1/calls/token",
            json={"contact_ids": [user_id_b], "is_video": is_video},
            headers=headers_a,
        )
    assert reponse.status_code == 200, reponse.text
    return reponse.json()["room"]


def _duo(client, phone_a, phone_b):
    headers_a, user_id_a = _signup(client, phone_a)
    headers_b, user_id_b = _signup(client, phone_b)
    client.post(
        "/api/v1/contacts",
        json={"phone": phone_b, "display_name": "Bob"},
        headers=headers_a,
    )
    return (headers_a, user_id_a), (headers_b, user_id_b)


def _messages_appel(db) -> list:
    return (
        db.query(DirectMessage)
        .filter(DirectMessage.message_type == MessageType.CALL)
        .all()
    )


# ── Le cas nominal ────────────────────────────────────────────────────────


def test_un_appel_decroche_puis_raccroche_laisse_une_trace(client):
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100001", "+22893100002"
    )
    room = _appeler(client, headers_a, user_id_b)

    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_b},
        headers=headers_a,
    )

    with TestingSessionLocal() as db:
        messages = _messages_appel(db)
        assert len(messages) == 1
        charge = messages[0].payload
        assert charge["status"] == "ended"
        assert charge["call_type"] == "1:1"
        assert charge["is_video"] is False
        # Décroché puis raccroché dans la même seconde : une durée EXISTE,
        # même nulle. C'est ce qui distingue « on s'est parlé brièvement »
        # de « personne n'a décroché ».
        assert charge["duration_seconds"] is not None
        # L'appelant reste l'auteur : c'est lui qui a composé le numéro.
        assert messages[0].sender_id == user_id_a
        assert messages[0].recipient_id == user_id_b


def test_la_bulle_apparait_dans_la_conversation(client):
    """La trace doit être lisible par l'API des messages, pas seulement en base."""
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100003", "+22893100004"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_b},
        headers=headers_a,
    )

    fil = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a)
    assert fil.status_code == 200, fil.text
    items = fil.json()["items"] if isinstance(fil.json(), dict) else fil.json()
    appels = [m for m in items if m["message_type"] == "CALL"]
    assert len(appels) == 1
    assert appels[0]["payload"]["status"] == "ended"

    # Et des DEUX côtés : la conversation est la même pour les deux personnes.
    fil_b = client.get(f"/api/v1/messages/{user_id_a}", headers=headers_b)
    items_b = fil_b.json()["items"] if isinstance(fil_b.json(), dict) else fil_b.json()
    assert len([m for m in items_b if m["message_type"] == "CALL"]) == 1


# ── L'idempotence, le vrai sujet ──────────────────────────────────────────


def test_raccrocher_deux_fois_ne_depose_qu_une_bulle(client):
    """Le réseau fait répéter les signaux ; la conversation ne doit pas bégayer."""
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100005", "+22893100006"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )
    for _ in range(3):
        client.post(
            "/api/v1/calls/signal",
            json={"room": room, "event": "end", "target_user_id": user_id_b},
            headers=headers_a,
        )

    with TestingSessionLocal() as db:
        assert len(_messages_appel(db)) == 1


def test_les_deux_cotes_qui_raccrochent_ne_deposent_qu_une_bulle(client):
    """Chacun ferme son écran : deux « end », un seul appel."""
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100007", "+22893100008"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_b},
        headers=headers_a,
    )
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_a},
        headers=headers_b,
    )

    with TestingSessionLocal() as db:
        assert len(_messages_appel(db)) == 1
        # La marque est posée, et c'est elle qui a tenu.
        log = db.query(CallLog).filter(CallLog.room == room).one()
        assert log.thread_message_id == _messages_appel(db)[0].id


# ── Ce qui ne doit RIEN déposer ───────────────────────────────────────────


def test_un_appel_qui_sonne_encore_ne_depose_rien(client):
    """Le bandeau « Appel en cours » s'en charge, en direct."""
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100009", "+22893100010"
    )
    _appeler(client, headers_a, user_id_b)

    with TestingSessionLocal() as db:
        assert _messages_appel(db) == []


def test_un_appel_decroche_mais_pas_termine_ne_depose_rien(client):
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100011", "+22893100012"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )

    with TestingSessionLocal() as db:
        assert _messages_appel(db) == []


# ── Les issues qui ne sont pas « ended » ──────────────────────────────────


def test_un_appel_jamais_decroche_est_manque_et_sans_duree(client):
    """« Manqué », et surtout pas « 0 seconde ».

    La durée se compte depuis le PREMIER DÉCROCHÉ. Personne n'a décroché,
    donc il n'y a pas de durée — annoncer zéro laisserait croire qu'on s'est
    parlé une fraction de seconde.
    """
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100013", "+22893100014"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_b},
        headers=headers_a,
    )

    with TestingSessionLocal() as db:
        messages = _messages_appel(db)
        assert len(messages) == 1
        assert messages[0].payload["status"] == "missed"
        assert messages[0].payload["duration_seconds"] is None


def test_un_appel_refuse_le_dit(client):
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100015", "+22893100016"
    )
    room = _appeler(client, headers_a, user_id_b)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "decline", "target_user_id": user_id_a},
        headers=headers_b,
    )

    with TestingSessionLocal() as db:
        messages = _messages_appel(db)
        assert len(messages) == 1
        assert messages[0].payload["status"] == "declined"


def test_un_appel_video_le_dit(client):
    (headers_a, user_id_a), (headers_b, user_id_b) = _duo(
        client, "+22893100017", "+22893100018"
    )
    room = _appeler(client, headers_a, user_id_b, is_video=True)
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "end", "target_user_id": user_id_b},
        headers=headers_a,
    )

    with TestingSessionLocal() as db:
        assert _messages_appel(db)[0].payload["is_video"] is True


# ── Appel de groupe ───────────────────────────────────────────────────────


def test_un_appel_de_groupe_se_depose_dans_le_groupe(client):
    headers_a, user_id_a = _signup(client, "+22893100019")
    headers_b, user_id_b = _signup(client, "+22893100020")
    headers_c, user_id_c = _signup(client, "+22893100021")
    # `_require_contact` : on ne met dans un groupe que des gens de son
    # carnet.
    for phone in ("+22893100020", "+22893100021"):
        client.post(
            "/api/v1/contacts",
            json={"phone": phone, "display_name": "X"},
            headers=headers_a,
        )
    groupe = client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [user_id_b, user_id_c]},
        headers=headers_a,
    )
    assert groupe.status_code in (200, 201), groupe.text
    group_id = groupe.json()["id"]

    # Depuis que Pokou INVITE au lieu d'ajouter, un groupe naît avec son seul
    # créateur. Ce test porte sur l'appel de groupe, pas sur l'invitation :
    # on fait donc accepter pour retrouver un groupe à trois.
    for entetes in (headers_b, headers_c):
        for invitation in client.get(
            "/api/v1/groups/invitations", headers=entetes
        ).json()["items"]:
            client.post(
                f"/api/v1/groups/invitations/{invitation['id']}/accept",
                headers=entetes,
            )

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        demarre = client.post(
            "/api/v1/calls/token",
            json={"group_id": group_id, "is_video": False},
            headers=headers_a,
        )
    assert demarre.status_code == 200, demarre.text
    room = demarre.json()["room"]

    # B décroche, puis tout le monde quitte.
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "event": "accept", "target_user_id": user_id_a},
        headers=headers_b,
    )
    for entetes in (headers_b, headers_a):
        client.post(
            "/api/v1/calls/signal",
            json={"room": room, "event": "end", "target_user_id": user_id_a},
            headers=entetes,
        )

    with TestingSessionLocal() as db:
        messages = (
            db.query(GroupMessage)
            .filter(GroupMessage.message_type == MessageType.CALL)
            .all()
        )
        assert len(messages) == 1
        assert messages[0].group_id == group_id
        assert messages[0].payload["call_type"] == "group"
        # Aucune bulle ne part en conversation privée : l'appel appartient
        # au groupe.
        assert _messages_appel(db) == []
