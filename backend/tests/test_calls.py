from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import CallParticipant, CallLog, GroupMember, User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_calls.db"

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


def _fake_livekit_settings():
    settings = MagicMock()
    settings.livekit_enabled = True
    settings.livekit_api_key = "fake-key"
    settings.livekit_api_secret = "fake-secret-fake-secret-32bytes!"
    settings.livekit_url = "wss://fake.livekit.cloud"
    settings.livekit_token_ttl_minutes = 15
    settings.call_max_group_ring = 32
    return settings


def _unconfigured_livekit_settings():
    """LiveKit explicitement ABSENT. Sans ce faux, la prémisse du test venait
    du .env de la machine : il passait là où LiveKit n'est pas configuré et
    échouait sur une machine où il l'est — c'est-à-dire justement celle du
    développement, depuis que les vraies clés y sont."""
    settings = MagicMock()
    settings.livekit_enabled = False
    settings.livekit_api_key = ""
    settings.livekit_api_secret = ""
    settings.livekit_url = ""
    return settings


def _patched_livekit():
    settings = _fake_livekit_settings()
    return (
        patch("app.services.calls.livekit_service.get_settings", return_value=settings),
        patch("app.api.v1.calls.calls.get_settings", return_value=settings),
    )


def test_call_token_requires_contact_ids_or_room(client):
    headers, _, _ = _signup(client, "+22893000001")
    response = client.post("/api/v1/calls/token", json={}, headers=headers)
    assert response.status_code == 400


def test_call_token_rejects_non_contact(client):
    headers_a, _, _ = _signup(client, "+22893000002")
    _, user_id_b, _ = _signup(client, "+22893000003")
    response = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    assert response.status_code == 403


def test_call_token_returns_503_when_livekit_not_configured(client):
    headers_a, _, _ = _signup(client, "+22893000004")
    _, user_id_b, _ = _signup(client, "+22893000005")
    client.post("/api/v1/contacts", json={"phone": "+22893000005", "display_name": "Bob"}, headers=headers_a)

    unconfigured = _unconfigured_livekit_settings()
    with patch("app.services.calls.livekit_service.get_settings", return_value=unconfigured), patch(
        "app.api.v1.calls.calls.get_settings", return_value=unconfigured
    ):
        response = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    assert response.status_code == 503


def test_call_token_generated_and_invite_pushed_over_websocket(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000006")
    _, user_id_b, token_b = _signup(client, "+22893000007")
    client.post("/api/v1/contacts", json={"phone": "+22893000007", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
            response = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
            assert response.status_code == 200, response.text
            body = response.json()
            assert body["token"]
            assert body["livekit_url"] == "wss://fake.livekit.cloud"

            event = ws.receive_json()
            assert event["type"] == "call:invite"
            assert event["room"] == body["room"]
            assert event["from_user_id"] == user_id_a
            assert event["call_type"] == "1:1"
            # B n'a PAS A dans son carnet : le nom arrive quand même avec
            # l'invitation (avant, l'écran affichait « Appel entrant »).
            assert event["caller_name"]
            assert "caller_avatar" in event


def test_call_token_group_call_has_group_call_type(client):
    headers_a, _, _ = _signup(client, "+22893000008")
    _, user_id_b, _ = _signup(client, "+22893000009")
    _, user_id_c, _ = _signup(client, "+22893000010")
    client.post("/api/v1/contacts", json={"phone": "+22893000009", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893000010", "display_name": "Charlie"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = client.post(
            "/api/v1/calls/token",
            json={
                "contact_ids": [user_id_b, user_id_c],
                "sealed_keys": {
                    str(user_id_b): _sealed("bob"),
                    str(user_id_c): _sealed("charlie"),
                },
            },
            headers=headers_a,
        )
    assert response.status_code == 200, response.text


def test_call_token_join_existing_room_skips_contact_check(client):
    """L'invité rejoint le salon de l'appel qu'il reçoit sans avoir l'appelant
    dans son carnet : c'est l'invitation qui l'autorise, pas le carnet."""
    headers_a, _, _ = _signup(client, "+22893000011")
    headers_b, user_id_b, _ = _signup(client, "+22893000010")
    client.post("/api/v1/contacts", json={"phone": "+22893000010", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        room = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()["room"]
        response = client.post("/api/v1/calls/token", json={"room": room}, headers=headers_b)
    assert response.status_code == 200, response.text
    assert response.json()["room"] == room


def test_signal_relays_event_over_websocket(client):
    """Le signal d'un PARTICIPANT est relayé à l'autre participant. (Ce test
    utilisait un salon inventé : c'était précisément la faille — n'importe qui
    pouvait signaler sur n'importe quel salon.)"""
    headers_a, user_id_a, token_a = _signup(client, "+22893000012")
    headers_b, user_id_b, _ = _signup(client, "+22893000013")
    client.post("/api/v1/contacts", json={"phone": "+22893000013", "display_name": "Bob"}, headers=headers_a)
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        room = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()["room"]

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws:
        response = client.post(
            "/api/v1/calls/signal",
            json={"room": room, "target_user_id": user_id_a, "event": "accept"},
            headers=headers_b,
        )
        assert response.status_code == 200

        event = ws.receive_json()
        assert event["type"] == "call:accept"
        assert event["room"] == room
        assert event["from_user_id"] == user_id_b


def test_signal_rejects_invalid_event(client):
    headers_a, _, _ = _signup(client, "+22893000014")
    response = client.post(
        "/api/v1/calls/signal",
        json={"room": "x", "target_user_id": 1, "event": "bogus"},
        headers=headers_a,
    )
    assert response.status_code == 400


# ─── Journal d'appels ─────────────────────────────────────────────────────────

def test_starting_a_call_logs_it_for_both_sides(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000015")
    headers_b, user_id_b, _ = _signup(client, "+22893000016")
    client.post("/api/v1/contacts", json={"phone": "+22893000016", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post(
            "/api/v1/calls/token", json={"contact_ids": [user_id_b], "is_video": False}, headers=headers_a
        )
    assert started.status_code == 200, started.text
    room = started.json()["room"]

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert len(log_a) == 1
    assert log_a[0]["direction"] == "outgoing"
    assert log_a[0]["status"] == "ringing"
    assert log_a[0]["is_video"] is False
    # Le nom du carnet de A (« Bob ») : le journal nomme comme les
    # discussions — voir utils/identity.py::nom_affiche.
    assert log_a[0]["others"] == [
        {"id": user_id_b, "display_name": "Bob", "avatar": None, "is_verified": False}
    ]

    log_b = client.get("/api/v1/calls/log", headers=headers_b).json()["items"]
    assert len(log_b) == 1
    assert log_b[0]["direction"] == "incoming"
    assert log_b[0]["status"] == "invited"
    assert log_b[0]["others"][0]["id"] == user_id_a


def test_call_log_porte_le_badge_d_identite_de_l_autre(client):
    """Le ✓ s'affichait dans la liste des discussions, pas dans le journal
    d'appels : celui-ci ne le recevait pas."""
    headers_a, _, _ = _signup(client, "+22893000019")
    _, user_id_b, _ = _signup(client, "+22893000020")
    client.post("/api/v1/contacts", json={"phone": "+22893000020", "display_name": "Bob"}, headers=headers_a)
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id_b).update({"is_verified": True})
        db.commit()
    finally:
        db.close()

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert log_a[0]["others"][0]["is_verified"] is True


def test_le_journal_d_appels_nomme_comme_le_carnet_sauf_compte_certifie(client):
    """Le journal affichait le nom choisi par l'autre, pas celui du carnet —
    un contact n'y portait pas le même nom que dans les discussions. Un
    compte certifié qui a un nom garde, lui, le sien."""
    headers_a, _, _ = _signup(client, "+22893000031")
    _, user_id_b, _ = _signup(client, "+22893000032")
    _, user_id_c, _ = _signup(client, "+22893000033")
    client.post("/api/v1/contacts", json={"phone": "+22893000032", "display_name": "Tonton Kossi"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893000033", "display_name": "Mon banquier"}, headers=headers_a)
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id_b).update({"full_name": "Kossi A."})
        db.query(User).filter(User.id == user_id_c).update({"full_name": "Banque Atlantique", "is_verified": True})
        db.commit()
    finally:
        db.close()

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
        client.post("/api/v1/calls/token", json={"contact_ids": [user_id_c]}, headers=headers_a)

    noms = {
        entry["others"][0]["id"]: entry["others"][0]["display_name"]
        for entry in client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    }
    assert noms[user_id_b] == "Tonton Kossi"
    assert noms[user_id_c] == "Banque Atlantique"


def test_le_carnet_affiche_le_nom_d_un_compte_certifie(client):
    headers_a, _, _ = _signup(client, "+22893000034")
    _, user_id_b, _ = _signup(client, "+22893000035")
    client.post("/api/v1/contacts", json={"phone": "+22893000035", "display_name": "Mon banquier"}, headers=headers_a)
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id_b).update({"full_name": "Banque Atlantique", "is_verified": True})
        db.commit()
    finally:
        db.close()

    contacts = client.get("/api/v1/contacts", headers=headers_a).json()
    items = contacts["items"] if isinstance(contacts, dict) else contacts
    assert [c["display_name"] for c in items if c["contact_user_id"] == user_id_b] == ["Banque Atlantique"]


def test_call_log_includes_the_other_users_avatar_when_they_have_one(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000017")
    headers_b, user_id_b, _ = _signup(client, "+22893000018")
    client.post("/api/v1/contacts", json={"phone": "+22893000018", "display_name": "Bob"}, headers=headers_a)

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"\xff\xd8\xff\xfake-jpeg-bytes", "image/jpeg")},
        headers=headers_b,
    )
    media_id = uploaded.json()["id"]
    client.put("/api/v1/users/me/profile", json={"avatar_media_id": media_id}, headers=headers_b)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    avatar = log_a[0]["others"][0]["avatar"]
    assert avatar is not None
    assert avatar["id"] == media_id


def test_accept_marks_call_ongoing_and_participant_accepted(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000017")
    headers_b, user_id_b, _ = _signup(client, "+22893000018")
    client.post("/api/v1/contacts", json={"phone": "+22893000018", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    room = started.json()["room"]

    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "target_user_id": user_id_a, "event": "accept"},
        headers=headers_b,
    )

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert log_a[0]["status"] == "ongoing"
    log_b = client.get("/api/v1/calls/log", headers=headers_b).json()["items"]
    assert log_b[0]["status"] == "accepted"


def test_decline_marks_1on1_call_declined(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000019")
    headers_b, user_id_b, _ = _signup(client, "+22893000020")
    client.post("/api/v1/contacts", json={"phone": "+22893000020", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    room = started.json()["room"]

    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "target_user_id": user_id_a, "event": "decline"},
        headers=headers_b,
    )

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert log_a[0]["status"] == "declined"
    assert log_a[0]["ended_at"] is not None


def test_end_before_accept_marks_call_missed(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000021")
    headers_b, user_id_b, _ = _signup(client, "+22893000022")
    client.post("/api/v1/contacts", json={"phone": "+22893000022", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    room = started.json()["room"]

    # A raccroche avant que B ne réponde.
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "target_user_id": user_id_b, "event": "end"},
        headers=headers_a,
    )

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert log_a[0]["status"] == "missed"
    log_b = client.get("/api/v1/calls/log", headers=headers_b).json()["items"]
    assert log_b[0]["status"] == "missed"


def test_end_after_accept_marks_call_ended_with_duration(client):
    headers_a, user_id_a, _ = _signup(client, "+22893000023")
    headers_b, user_id_b, _ = _signup(client, "+22893000024")
    client.post("/api/v1/contacts", json={"phone": "+22893000024", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a)
    room = started.json()["room"]

    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "target_user_id": user_id_a, "event": "accept"},
        headers=headers_b,
    )
    client.post(
        "/api/v1/calls/signal",
        json={"room": room, "target_user_id": user_id_b, "event": "end"},
        headers=headers_a,
    )

    log_a = client.get("/api/v1/calls/log", headers=headers_a).json()["items"]
    assert log_a[0]["status"] == "ended"
    assert log_a[0]["duration_seconds"] is not None
    assert log_a[0]["duration_seconds"] >= 0


def test_signal_for_unknown_room_is_not_found(client):
    """Un salon inconnu n'est plus accepté en silence : il n'y a pas d'appel à
    signaler, et répondre 200 laissait passer n'importe quel salon."""
    headers_a, _, _ = _signup(client, "+22893000025")
    response = client.post(
        "/api/v1/calls/signal",
        json={"room": "pokou-call-nonexistent", "target_user_id": 999999, "event": "end"},
        headers=headers_a,
    )
    assert response.status_code == 404


# ─── Appels de groupe (depuis une conversation de groupe) ─────────────────────

def _accepter_invitations(client, user_ids):
    """Depuis que Pokou INVITE au lieu d'ajouter (migration 20260928), créer un
    groupe avec des membres ne les y met plus : ils reçoivent une invitation.
    Ces tests portent sur le comportement du groupe une fois constitué, pas sur
    le flux d'invitation (test_group_invitations.py) : on rend donc aux membres
    leur place, en acceptant pour eux."""
    from app.core.security import create_access_token

    for user_id in user_ids:
        headers = {"Authorization": f"Bearer {create_access_token({'user_id': user_id})}"}
        for invitation in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers)


def _make_group(client, headers, name, member_phones_and_ids):
    for phone, _ in member_phones_and_ids:
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers)
    created = client.post(
        "/api/v1/groups",
        json={"name": name, "member_user_ids": [user_id for _, user_id in member_phones_and_ids]},
        headers=headers,
    )
    assert created.status_code == 200, created.text
    _accepter_invitations(client, [user_id for _, user_id in member_phones_and_ids])
    return created.json()


def _start_group_call(client, headers, group, **fields):
    db = TestingSessionLocal()
    try:
        member_ids = [
            row.user_id
            for row in db.query(GroupMember).filter(GroupMember.group_id == group["id"]).all()
        ]
    finally:
        db.close()
    return client.post(
        "/api/v1/calls/token",
        json={
            "group_id": group["id"],
            "sealed_keys": {str(user_id): _sealed(str(user_id)) for user_id in member_ids},
            **fields,
        },
        headers=headers,
    )


def test_group_call_rings_every_member_without_needing_contacts(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100001")
    _, user_id_b, token_b = _signup(client, "+22893100002")
    _, user_id_c, _ = _signup(client, "+22893100003")
    group = _make_group(client, headers_a, "Chantier", [("+22893100002", user_id_b), ("+22893100003", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
            response = _start_group_call(
                client, headers_a, group, is_video=False
            )
            assert response.status_code == 200, response.text
            body = response.json()
            assert body["joined_existing"] is False
            assert sorted(body["participant_ids"]) == sorted([user_id_b, user_id_c])

            event = ws.receive_json()
            assert event["type"] == "call:invite"
            assert event["call_type"] == "group"
            assert event["group_id"] == group["id"]
            assert event["group_name"] == "Chantier"
            assert event["is_video"] is False


def test_group_call_does_not_require_members_to_be_in_the_address_book(client):
    """B et C sont dans le groupe mais pas dans le carnet de B — c'est B qui
    appelle, et il ne connaît « personne » au sens des contacts."""
    headers_a, user_id_a, _ = _signup(client, "+22893100004")
    headers_b, user_id_b, _ = _signup(client, "+22893100005")
    _, user_id_c, _ = _signup(client, "+22893100006")
    group = _make_group(client, headers_a, "Sans carnet", [("+22893100005", user_id_b), ("+22893100006", user_id_c)])

    # La preuve par contraste a changé, et avec elle la RÈGLE.
    #
    # Ce test montrait qu'appeler C par `contact_ids` échouait pour B, faute
    # de fiche au carnet. Ce n'est plus vrai : `calls.py` partageait une
    # règle « uniquement mon carnet » qui avait divergé de celle de l'envoi,
    # et appelle désormais la même — un groupe commun suffit à joindre
    # quelqu'un, pour écrire comme pour appeler.
    #
    # On prouve donc la même chose autrement : un INCONNU, avec qui rien
    # n'est partagé, reste refusé. C'est le garde-fou qui compte — les
    # identifiants sont séquentiels, et sans lui on appellerait toute la
    # base en incrémentant un compteur.
    _, user_id_inconnu, _ = _signup(client, "+22893100099")
    assert client.post(
        "/api/v1/calls/token", json={"contact_ids": [user_id_inconnu]}, headers=headers_b
    ).status_code == 403

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = _start_group_call(client, headers_b, group)
    assert response.status_code == 200, response.text
    assert sorted(response.json()["participant_ids"]) == sorted([user_id_a, user_id_c])


def test_non_member_cannot_call_a_group(client):
    headers_a, _, _ = _signup(client, "+22893100007")
    headers_b, user_id_b, _ = _signup(client, "+22893100008")
    _, user_id_c, _ = _signup(client, "+22893100009")
    group = _make_group(client, headers_a, "Privé", [("+22893100009", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = _start_group_call(client, headers_b, group)
    assert response.status_code == 403


def test_second_caller_joins_the_ongoing_call_instead_of_opening_a_second_room(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100010")
    headers_b, user_id_b, _ = _signup(client, "+22893100011")
    _, user_id_c, _ = _signup(client, "+22893100012")
    group = _make_group(client, headers_a, "Convergence", [("+22893100011", user_id_b), ("+22893100012", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        first = _start_group_call(client, headers_a, group).json()
        second = _start_group_call(client, headers_b, group).json()

    # Même salon : les deux se retrouvent dans le même appel.
    assert second["room"] == first["room"]
    assert second["joined_existing"] is True
    assert second["e2ee"] is True
    assert second["sealed_key"]["ciphertext"] == f"chiffre-{user_id_b}"
    assert second["sealed_key"]["from_user_id"] == user_id_a
    # Un seul appel journalisé, pas deux.
    assert len(client.get("/api/v1/calls/log", headers=headers_a).json()["items"]) == 1


def test_active_call_endpoint_reports_the_ongoing_group_call(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100013")
    headers_b, user_id_b, _ = _signup(client, "+22893100014")
    group = _make_group(client, headers_a, "Bandeau", [("+22893100014", user_id_b)])

    # Aucun appel : « active: false », pas un 404 — l'absence est le cas normal.
    idle = client.get(f"/api/v1/calls/active?group_id={group['id']}", headers=headers_b)
    assert idle.status_code == 200
    assert idle.json() == {"active": False}

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = _start_group_call(client, headers_a, group).json()

    active = client.get(f"/api/v1/calls/active?group_id={group['id']}", headers=headers_b).json()
    assert active["active"] is True
    assert active["room"] == started["room"]
    assert active["caller_id"] == user_id_a


def test_active_call_is_not_visible_to_non_members(client):
    headers_a, _, _ = _signup(client, "+22893100015")
    headers_b, _, _ = _signup(client, "+22893100016")
    _, user_id_c, _ = _signup(client, "+22893100017")
    group = _make_group(client, headers_a, "Fermé", [("+22893100017", user_id_c)])

    response = client.get(f"/api/v1/calls/active?group_id={group['id']}", headers=headers_b)
    assert response.status_code == 403


def test_group_call_survives_the_first_participant_hanging_up(client):
    """Le bandeau « Appel en cours » ne doit pas disparaître parce qu'UNE
    personne a raccroché — les autres se parlent encore."""
    headers_a, user_id_a, _ = _signup(client, "+22893100018")
    headers_b, user_id_b, _ = _signup(client, "+22893100019")
    headers_c, user_id_c, _ = _signup(client, "+22893100020")
    group = _make_group(client, headers_a, "Trois", [("+22893100019", user_id_b), ("+22893100020", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = _start_group_call(client, headers_a, group).json()
    room = started["room"]

    for headers, target in ((headers_b, user_id_a), (headers_c, user_id_a)):
        client.post(
            "/api/v1/calls/signal", json={"room": room, "target_user_id": target, "event": "accept"}, headers=headers
        )

    # C quitte : A et B continuent.
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "end"}, headers=headers_c
    )
    assert client.get(f"/api/v1/calls/active?group_id={group['id']}", headers=headers_b).json()["active"] is True

    # B quitte : il ne reste que A, l'appel est terminé.
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "end"}, headers=headers_b
    )
    assert client.get(f"/api/v1/calls/active?group_id={group['id']}", headers=headers_b).json()["active"] is False
    assert client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]["status"] == "ended"


def test_one_to_one_call_still_ends_on_the_first_hang_up(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100021")
    headers_b, user_id_b, _ = _signup(client, "+22893100022")
    client.post("/api/v1/contacts", json={"phone": "+22893100022", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()
    room = started["room"]
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "accept"}, headers=headers_b
    )
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_b, "event": "end"}, headers=headers_a
    )
    assert client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]["status"] == "ended"


# ─── Ajouter quelqu'un à un appel en cours ────────────────────────────────────

def test_invite_turns_a_one_to_one_call_into_a_group_call(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100023")
    _, user_id_b, _ = _signup(client, "+22893100024")
    _, user_id_c, token_c = _signup(client, "+22893100025")
    client.post("/api/v1/contacts", json={"phone": "+22893100024", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893100025", "display_name": "Charlie"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post(
            "/api/v1/calls/token",
            json={
                "contact_ids": [user_id_b],
                "sealed_keys": {str(user_id_b): _sealed("bob")},
            },
            headers=headers_a,
        ).json()

        with client.websocket_connect(f"/api/v1/ws?token={token_c}") as ws:
            invited = client.post(
                "/api/v1/calls/invite",
                json={
                    "room": started["room"],
                    "user_ids": [user_id_c],
                    "sealed_keys": {str(user_id_c): _sealed("charlie")},
                },
                headers=headers_a,
            )
            assert invited.status_code == 200, invited.text
            assert invited.json()["invited"] == [user_id_c]
            assert sorted(invited.json()["participant_ids"]) == sorted([user_id_b, user_id_c])

            event = ws.receive_json()
            assert event["type"] == "call:invite"
            # Même salon : personne n'a besoin de se reconnecter.
            assert event["room"] == started["room"]
            assert event["call_type"] == "group"

    assert client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]["call_type"] == "group"


def test_only_someone_in_the_call_can_invite(client):
    headers_a, _, _ = _signup(client, "+22893100026")
    _, user_id_b, _ = _signup(client, "+22893100027")
    headers_d, _, _ = _signup(client, "+22893100028")
    _, user_id_c, _ = _signup(client, "+22893100029")
    client.post("/api/v1/contacts", json={"phone": "+22893100027", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893100029", "display_name": "Charlie"}, headers=headers_d)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()

    response = client.post(
        "/api/v1/calls/invite", json={"room": started["room"], "user_ids": [user_id_c]}, headers=headers_d
    )
    assert response.status_code == 403


def test_cannot_invite_a_stranger_to_a_call(client):
    headers_a, _, _ = _signup(client, "+22893100030")
    _, user_id_b, _ = _signup(client, "+22893100031")
    _, user_id_c, _ = _signup(client, "+22893100032")
    client.post("/api/v1/contacts", json={"phone": "+22893100031", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()

    response = client.post(
        "/api/v1/calls/invite", json={"room": started["room"], "user_ids": [user_id_c]}, headers=headers_a
    )
    assert response.status_code == 403


def test_inviting_an_existing_participant_is_a_no_op(client):
    headers_a, _, _ = _signup(client, "+22893100033")
    _, user_id_b, _ = _signup(client, "+22893100034")
    client.post("/api/v1/contacts", json={"phone": "+22893100034", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()

    response = client.post(
        "/api/v1/calls/invite", json={"room": started["room"], "user_ids": [user_id_b]}, headers=headers_a
    )
    assert response.status_code == 200
    assert response.json()["invited"] == []
    # Reste un appel 1:1, pas de participant en double.
    entry = client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]
    assert entry["call_type"] == "1:1"
    assert len(entry["others"]) == 1


def test_cannot_invite_to_a_finished_call(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100035")
    headers_b, user_id_b, _ = _signup(client, "+22893100036")
    _, user_id_c, _ = _signup(client, "+22893100037")
    client.post("/api/v1/contacts", json={"phone": "+22893100036", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893100037", "display_name": "Charlie"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()
    room = started["room"]
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "accept"}, headers=headers_b
    )
    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_b, "event": "end"}, headers=headers_a
    )

    response = client.post(
        "/api/v1/calls/invite", json={"room": room, "user_ids": [user_id_c]}, headers=headers_a
    )
    assert response.status_code == 409


def test_group_member_can_be_invited_to_an_ongoing_call_without_being_a_contact(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100038")
    headers_b, user_id_b, _ = _signup(client, "+22893100039")
    _, user_id_c, _ = _signup(client, "+22893100040")
    group = _make_group(client, headers_a, "Élargi", [("+22893100039", user_id_b), ("+22893100040", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        # B lance l'appel de groupe (C est sonné), C refuse, puis B le rappelle
        # dans l'appel alors que C n'est PAS dans son carnet d'adresses.
        started = _start_group_call(client, headers_b, group).json()
        response = client.post(
            "/api/v1/calls/invite", json={"room": started["room"], "user_ids": [user_id_c]}, headers=headers_b
        )
    # C est déjà participant (sonné à la création) : rien à ajouter, et
    # surtout pas de 403 comme la voie « contacts » l'aurait donné.
    assert response.status_code == 200
    assert response.json()["invited"] == []


def test_a_departed_group_call_participant_can_be_invited_back(client):
    headers_a, user_id_a, _ = _signup(client, "+22893100046")
    headers_b, user_id_b, token_b = _signup(client, "+22893100047")
    headers_c, user_id_c, _ = _signup(client, "+22893100048")
    group = _make_group(
        client,
        headers_a,
        "Retour d'appel",
        [("+22893100047", user_id_b), ("+22893100048", user_id_c)],
    )

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = _start_group_call(client, headers_a, group).json()
        room = started["room"]
        client.post("/api/v1/calls/token", json={"room": room}, headers=headers_b)
        client.post("/api/v1/calls/token", json={"room": room}, headers=headers_c)
        left = client.post(
            "/api/v1/calls/signal",
            json={"room": room, "target_user_id": user_id_a, "event": "end"},
            headers=headers_b,
        )
        assert left.status_code == 200

        with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
            reinvited = client.post(
                "/api/v1/calls/invite",
                json={
                    "room": room,
                    "user_ids": [user_id_b],
                    "sealed_keys": {str(user_id_b): _sealed("bob-return")},
                },
                headers=headers_a,
            )
            assert reinvited.status_code == 200, reinvited.text
            assert reinvited.json()["invited"] == [user_id_b]
            assert ws.receive_json()["type"] == "call:invite"

        client.post("/api/v1/calls/token", json={"room": room}, headers=headers_b)

    db = TestingSessionLocal()
    try:
        call = db.query(CallLog).filter(CallLog.room == room).one()
        participant = (
            db.query(CallParticipant)
            .filter(
                CallParticipant.call_log_id == call.id,
                CallParticipant.user_id == user_id_b,
            )
            .one()
        )
        assert participant.status == "accepted"
        assert participant.left_at is None
    finally:
        db.close()


def test_call_log_names_the_group(client):
    headers_a, _, _ = _signup(client, "+22893100041")
    _, user_id_b, _ = _signup(client, "+22893100042")
    group = _make_group(client, headers_a, "Dépôt Adidogomé", [("+22893100042", user_id_b)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        _start_group_call(client, headers_a, group)

    entry = client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]
    assert entry["group_id"] == group["id"]
    assert entry["group_name"] == "Dépôt Adidogomé"
    assert entry["call_type"] == "group"


# ── Appels chiffrés de bout en bout ───────────────────────────────────────


def _sealed(marker="clé"):
    """Une clé d'appel « scellée » — opaque pour le serveur, qui ne fait que
    la ranger et la rendre."""
    return {"encryption": "v1", "ciphertext": f"chiffre-{marker}", "envelope": {"v": 1, "n": 0}}


def test_un_appel_chiffre_rend_a_l_invite_la_cle_scellee_pour_lui(client):
    headers_a, user_id_a, _ = _signup(client, "+22893200001")
    headers_b, user_id_b, _ = _signup(client, "+22893200002")
    client.post("/api/v1/contacts", json={"phone": "+22893200002", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post(
            "/api/v1/calls/token",
            json={"contact_ids": [user_id_b], "sealed_keys": {str(user_id_b): _sealed("bob")}},
            headers=headers_a,
        )
        assert started.status_code == 200, started.text
        assert started.json()["e2ee"] is True
        # L'appelant a tiré la clé lui-même : rien à lui rendre.
        assert started.json()["sealed_key"] is None

        joined = client.post("/api/v1/calls/token", json={"room": started.json()["room"]}, headers=headers_b)
    assert joined.status_code == 200, joined.text
    body = joined.json()
    assert body["e2ee"] is True
    assert body["sealed_key"]["ciphertext"] == "chiffre-bob"
    # L'invité ouvre l'enveloppe avec la session qu'il a avec l'appelant.
    assert body["sealed_key"]["from_user_id"] == user_id_a


def test_un_appel_sans_cle_n_est_pas_chiffre(client):
    headers_a, _, _ = _signup(client, "+22893200003")
    headers_b, user_id_b, _ = _signup(client, "+22893200004")
    client.post("/api/v1/contacts", json={"phone": "+22893200004", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()
        joined = client.post("/api/v1/calls/token", json={"room": started["room"]}, headers=headers_b).json()
    assert started["e2ee"] is False
    assert joined["e2ee"] is False
    assert joined["sealed_key"] is None


def test_un_appel_chiffre_refuse_un_invite_sans_cle(client):
    headers_a, _, _ = _signup(client, "+22893200005")
    _, user_id_b, _ = _signup(client, "+22893200006")
    _, user_id_c, _ = _signup(client, "+22893200007")
    client.post("/api/v1/contacts", json={"phone": "+22893200006", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893200007", "display_name": "Charlie"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = client.post(
            "/api/v1/calls/token",
            json={"contact_ids": [user_id_b, user_id_c], "sealed_keys": {str(user_id_b): _sealed()}},
            headers=headers_a,
        )
    assert response.status_code == 400


def test_on_n_ajoute_pas_a_un_appel_chiffre_quelqu_un_sans_sa_cle(client):
    headers_a, _, _ = _signup(client, "+22893200008")
    _, user_id_b, _ = _signup(client, "+22893200009")
    headers_c, user_id_c, _ = _signup(client, "+22893200010")
    client.post("/api/v1/contacts", json={"phone": "+22893200009", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893200010", "display_name": "Charlie"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        room = client.post(
            "/api/v1/calls/token",
            json={"contact_ids": [user_id_b], "sealed_keys": {str(user_id_b): _sealed()}},
            headers=headers_a,
        ).json()["room"]

        sans_cle = client.post(
            "/api/v1/calls/invite", json={"room": room, "user_ids": [user_id_c]}, headers=headers_a
        )
        assert sans_cle.status_code == 409

        avec_cle = client.post(
            "/api/v1/calls/invite",
            json={"room": room, "user_ids": [user_id_c], "sealed_keys": {str(user_id_c): _sealed("charlie")}},
            headers=headers_a,
        )
        assert avec_cle.status_code == 200, avec_cle.text
        joined = client.post("/api/v1/calls/token", json={"room": room}, headers=headers_c).json()
    assert joined["e2ee"] is True
    assert joined["sealed_key"]["ciphertext"] == "chiffre-charlie"


def test_un_appel_de_groupe_exige_une_cle_pour_chaque_invite(client):
    headers_a, _, _ = _signup(client, "+22893200011")
    _, user_id_b, _ = _signup(client, "+22893200012")
    group_id = _make_group(client, headers_a, "Famille", [("+22893200012", user_id_b)])["id"]

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        missing = client.post(
            "/api/v1/calls/token", json={"group_id": group_id}, headers=headers_a
        )
        response = client.post(
            "/api/v1/calls/token",
            json={"group_id": group_id, "sealed_keys": {str(user_id_b): _sealed()}},
            headers=headers_a,
        )
    assert missing.status_code == 400
    assert response.status_code == 200, response.text
    assert response.json()["e2ee"] is True
    assert response.json()["sealed_key"] is None

    db = TestingSessionLocal()
    try:
        call = db.query(CallLog).filter(CallLog.room == response.json()["room"]).one()
        stored = db.query(CallParticipant).filter(
            CallParticipant.call_log_id == call.id, CallParticipant.user_id == user_id_b
        ).one().sealed_key
        assert stored["ciphertext"] == "chiffre-clé"
        assert set(stored) == {"encryption", "ciphertext", "envelope", "from_user_id"}
    finally:
        db.close()


def test_un_refus_apres_avoir_rejoint_un_appel_chiffre_le_clot(client):
    """L'invité rejoint le salon (l'appel passe « en cours »), mais la clé
    ne s'ouvre pas chez lui : il refuse. L'appel ne doit pas rester « en
    cours » pour toujours dans le journal."""
    headers_a, user_id_a, _ = _signup(client, "+22893200013")
    headers_b, user_id_b, _ = _signup(client, "+22893200014")
    client.post("/api/v1/contacts", json={"phone": "+22893200014", "display_name": "Bob"}, headers=headers_a)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        room = client.post(
            "/api/v1/calls/token",
            json={"contact_ids": [user_id_b], "sealed_keys": {str(user_id_b): _sealed()}},
            headers=headers_a,
        ).json()["room"]
        client.post("/api/v1/calls/token", json={"room": room}, headers=headers_b)
        declined = client.post(
            "/api/v1/calls/signal",
            json={"room": room, "target_user_id": user_id_a, "event": "decline"},
            headers=headers_b,
        )
    assert declined.status_code == 200, declined.text
    entry = client.get("/api/v1/calls/log", headers=headers_a).json()["items"][0]
    assert entry["status"] == "declined"


def test_un_membre_sans_cle_ne_bloque_pas_l_appel_de_groupe(client):
    """Un membre que l'appelant n'a pas pu chiffrer n'est pas appelé, mais
    l'appel part pour les autres (avant : « participants invalides »)."""
    import re as _re
    from unittest.mock import patch as _patch

    from app.services.auth import otp_service as _otp

    def signup(phone):
        with _patch.object(_otp.sms_service, "send_sms", return_value=True) as send:
            client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
        code = _re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
        body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
        return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]

    owner, _ = signup("+22890000801")
    a, a_id = signup("+22890000802")
    b, b_id = signup("+22890000803")
    for phone, name in (("+22890000802", "A"), ("+22890000803", "B")):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=owner)
    group = client.post("/api/v1/groups", json={"name": "G", "member_user_ids": [a_id, b_id]}, headers=owner).json()
    for headers in (a, b):
        for inv in client.get("/api/v1/groups/invitations", headers=headers).json()["items"]:
            client.post(f"/api/v1/groups/invitations/{inv['id']}/accept", headers=headers)

    sealed = {str(a_id): {"encryption": "v1", "ciphertext": "k", "envelope": {"sid": "s"}}}
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        started = client.post(
            "/api/v1/calls/token",
            json={"group_id": group["id"], "is_video": False, "sealed_keys": sealed},
            headers=owner,
        )
    assert started.status_code == 200, started.text
    assert started.json()["e2ee"] is True
    assert started.json()["participant_ids"] == [a_id]
