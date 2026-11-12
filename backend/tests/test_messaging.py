from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import DirectMessage
from app.services.auth import otp_service
from app.utils.editing import MESSAGE_EDIT_WINDOW, MESSAGE_EDIT_WINDOW_MINUTES

TEST_DATABASE_URL = "sqlite:///./test_pokou_messaging.db"

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


# ─── Contacts ─────────────────────────────────────────────────────────────────

def test_add_contact_resolves_registered_user(client):
    headers_a, _, _ = _signup(client, "+22891000001")
    _, user_id_b, _ = _signup(client, "+22891000002")

    response = client.post("/api/v1/contacts", json={"phone": "+22891000002", "display_name": "Bob"}, headers=headers_a)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["is_registered"] is True
    assert body["contact_user_id"] == user_id_b


def test_add_contact_unregistered_phone_is_pending(client):
    headers_a, _, _ = _signup(client, "+22891000003")
    response = client.post("/api/v1/contacts", json={"phone": "+22899999999", "display_name": "Not on Pokou"}, headers=headers_a)
    assert response.status_code == 200
    assert response.json()["is_registered"] is False


def test_cannot_add_self_as_contact(client):
    headers_a, _, _ = _signup(client, "+22891000004")
    response = client.post("/api/v1/contacts", json={"phone": "+22891000004", "display_name": "Me"}, headers=headers_a)
    assert response.status_code == 400


def test_duplicate_contact_rejected(client):
    headers_a, _, _ = _signup(client, "+22891000005")
    _signup(client, "+22891000006")
    client.post("/api/v1/contacts", json={"phone": "+22891000006", "display_name": "Bob"}, headers=headers_a)
    dup = client.post("/api/v1/contacts", json={"phone": "+22891000006", "display_name": "Bob again"}, headers=headers_a)
    assert dup.status_code == 409


def test_sync_device_contacts_adds_matches_and_ignores_unregistered(client):
    headers_a, _, _ = _signup(client, "+22891000030")
    _, user_id_b, _ = _signup(client, "+22891000031")

    response = client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [
            {"phone": "+22891000031", "name": "Bob (téléphone)"},
            {"phone": "+22899999998", "name": "Personne pas sur Pokou"},
        ]},
        headers=headers_a,
    )
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["contact_user_id"] == user_id_b
    assert items[0]["display_name"] == "Bob (téléphone)"

    # Le numéro non-inscrit n'a créé aucune ligne.
    listed = client.get("/api/v1/contacts", headers=headers_a).json()["items"]
    assert len(listed) == 1


def test_sync_device_contacts_excludes_self(client):
    headers_a, _, _ = _signup(client, "+22891000032")
    response = client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [{"phone": "+22891000032", "name": "Moi-même"}]},
        headers=headers_a,
    )
    assert response.status_code == 200
    assert response.json()["items"] == []


def test_sync_device_contacts_updates_existing_display_name(client):
    headers_a, _, _ = _signup(client, "+22891000033")
    _, user_id_b, _ = _signup(client, "+22891000034")

    client.post("/api/v1/contacts", json={"phone": "+22891000034", "display_name": "Ancien nom"}, headers=headers_a)
    response = client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [{"phone": "+22891000034", "name": "Nouveau nom (téléphone)"}]},
        headers=headers_a,
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["display_name"] == "Nouveau nom (téléphone)"
    assert items[0]["contact_user_id"] == user_id_b

    # Toujours une seule ligne pour ce numéro, pas un doublon.
    listed = client.get("/api/v1/contacts", headers=headers_a).json()["items"]
    assert len(listed) == 1


def test_sync_device_contacts_skips_invalid_phone_entries(client):
    headers_a, _, _ = _signup(client, "+22891000035")
    _, user_id_b, _ = _signup(client, "+22891000036")

    response = client.post(
        "/api/v1/contacts/sync",
        json={"contacts": [
            {"phone": "not-a-phone-number", "name": "Numéro invalide"},
            {"phone": "+22891000036", "name": "Bob"},
        ]},
        headers=headers_a,
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["contact_user_id"] == user_id_b


def test_sync_device_contacts_rejects_oversized_batch(client):
    headers_a, _, _ = _signup(client, "+22891000037")
    payload = {"contacts": [{"phone": f"+2289100{i:04d}", "name": f"Contact {i}"} for i in range(3001)]}
    response = client.post("/api/v1/contacts/sync", json=payload, headers=headers_a)
    assert response.status_code == 422


def test_delete_contact(client):
    headers_a, _, _ = _signup(client, "+22891000007")
    _signup(client, "+22891000008")
    created = client.post("/api/v1/contacts", json={"phone": "+22891000008", "display_name": "Bob"}, headers=headers_a).json()
    deleted = client.delete(f"/api/v1/contacts/{created['id']}", headers=headers_a)
    assert deleted.status_code == 200
    assert client.get("/api/v1/contacts", headers=headers_a).json()["items"] == []


# ─── Messages ─────────────────────────────────────────────────────────────────

def test_cannot_message_a_non_contact(client):
    headers_a, _, _ = _signup(client, "+22891000009")
    _, user_id_b, _ = _signup(client, "+22891000010")

    response = client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut"}, headers=headers_a)
    assert response.status_code == 403


def test_send_and_fetch_conversation(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000011")
    headers_b, user_id_b, _ = _signup(client, "+22891000012")
    client.post("/api/v1/contacts", json={"phone": "+22891000012", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000011", "display_name": "Alice"}, headers=headers_b)

    sent = client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut Bob"}, headers=headers_a)
    assert sent.status_code == 200, sent.text
    assert sent.json()["status"] == "SENT"  # B isn't connected via WS in this test

    conversation = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()
    assert conversation["total"] == 1
    assert conversation["items"][0]["content"] == "salut Bob"


def test_message_delivered_live_over_websocket(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000013")
    headers_b, user_id_b, token_b = _signup(client, "+22891000014")
    client.post("/api/v1/contacts", json={"phone": "+22891000014", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000013", "display_name": "Alice"}, headers=headers_b)

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        sent = client.post(
            "/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut Bob"}, headers=headers_a
        )
        assert sent.status_code == 200
        assert sent.json()["status"] == "DELIVERED"

        event = ws.receive_json()
        assert event["type"] == "message:new"
        assert event["message"]["content"] == "salut Bob"


def test_mark_read_notifies_sender_over_websocket(client):
    headers_a, user_id_a, token_a = _signup(client, "+22891000015")
    headers_b, user_id_b, _ = _signup(client, "+22891000016")
    client.post("/api/v1/contacts", json={"phone": "+22891000016", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000015", "display_name": "Alice"}, headers=headers_b)

    sent = client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut"}, headers=headers_a).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws:
        read = client.post(f"/api/v1/messages/{sent['id']}/read", headers=headers_b)
        assert read.status_code == 200
        assert read.json()["status"] == "READ"

        event = ws.receive_json()
        assert event["type"] == "message:status"
        assert event["message"]["status"] == "READ"


def test_websocket_rejects_missing_token(client):
    with pytest.raises(Exception):
        with client.websocket_connect("/api/v1/ws"):
            pass


# ─── Media ────────────────────────────────────────────────────────────────────

def test_upload_and_fetch_own_media(client):
    headers_a, _, _ = _signup(client, "+22891000040")
    response = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"\xff\xd8\xff\xfake-jpeg-bytes", "image/jpeg")},
        headers=headers_a,
    )
    assert response.status_code == 200, response.text
    media_id = response.json()["id"]

    fetched = client.get(f"/api/v1/media/{media_id}", headers=headers_a)
    assert fetched.status_code == 200
    assert fetched.content == b"\xff\xd8\xff\xfake-jpeg-bytes"


def test_upload_rejects_mismatched_mime_type(client):
    headers_a, _, _ = _signup(client, "+22891000041")
    response = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("note.txt", b"pas une image", "text/plain")},
        headers=headers_a,
    )
    assert response.status_code == 400


def test_upload_rejects_denylisted_mime_type(client):
    headers_a, _, _ = _signup(client, "+22891000052")
    response = client.post(
        "/api/v1/media/upload",
        data={"message_type": "DOCUMENT"},
        files={"file": ("evil.exe", b"MZ-fake-binary", "application/x-msdownload")},
        headers=headers_a,
    )
    assert response.status_code == 400


def test_media_not_accessible_to_non_contact_stranger(client):
    headers_a, _, _ = _signup(client, "+22891000042")
    headers_b, _, _ = _signup(client, "+22891000043")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "DOCUMENT"},
        files={"file": ("note.txt", b"contenu prive", "text/plain")},
        headers=headers_a,
    ).json()

    response = client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b)
    assert response.status_code == 404


def test_send_message_with_media_attachment(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000044")
    headers_b, user_id_b, _ = _signup(client, "+22891000045")
    client.post("/api/v1/contacts", json={"phone": "+22891000045", "display_name": "Bob"}, headers=headers_a)

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "AUDIO"},
        files={"file": ("note.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=headers_a,
    ).json()

    sent = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "AUDIO", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )
    assert sent.status_code == 200, sent.text
    body = sent.json()
    assert body["media_asset_id"] == uploaded["id"]
    assert body["message_type"] == "AUDIO"

    # Le destinataire peut récupérer le média référencé par le message reçu,
    # même s'il n'a pas lui-même uploadé le fichier.
    fetched = client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b)
    assert fetched.status_code == 200


def test_cannot_send_media_message_with_someone_elses_asset(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000046")
    headers_b, user_id_b, _ = _signup(client, "+22891000047")
    client.post("/api/v1/contacts", json={"phone": "+22891000047", "display_name": "Bob"}, headers=headers_a)

    uploaded_by_b = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"bytes-de-bob", "image/jpeg")},
        headers=headers_b,
    ).json()

    response = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "IMAGE", "media_asset_id": uploaded_by_b["id"]},
        headers=headers_a,
    )
    assert response.status_code == 404


# ─── Stickers : l'exception à la règle du téléversement ───────────────────────
#
# Partout ailleurs, la pièce jointe doit venir de l'expéditeur — c'est le
# test ci-dessus. Un sticker doit y échapper, SANS ouvrir la brèche.


def _pack_public_avec_sticker(uploader_headers, client):
    """Un pack public et son sticker, comme le serait un pack officiel."""
    from app.models import Sticker, StickerPack

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "STICKER"},
        files={"file": ("chat.webp", b"octets-de-sticker", "image/webp")},
        headers=uploader_headers,
    ).json()

    db = TestingSessionLocal()
    pack = StickerPack(name="Officiel", slug="officiel", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    db.refresh(pack)
    sticker = Sticker(pack_id=pack.id, media_asset_id=uploaded["id"], emoji_tags="😂")
    db.add(sticker)
    db.commit()
    db.close()
    return uploaded["id"]


def test_on_envoie_un_sticker_qu_on_n_a_pas_televerse(client):
    # LE cas qui était cassé : l'image d'un pack appartient à son auteur,
    # jamais à celui qui l'envoie. Sans l'exception, `POST /messages`
    # répondait « Pièce jointe introuvable » à chaque sticker, et toute la
    # fonctionnalité mourait à l'envoi.
    headers_auteur, _, _ = _signup(client, "+22891000090")
    headers_a, _, _ = _signup(client, "+22891000091")
    _, user_id_b, _ = _signup(client, "+22891000092")
    client.post("/api/v1/contacts", json={"phone": "+22891000092", "display_name": "Bob"}, headers=headers_a)

    media_id = _pack_public_avec_sticker(headers_auteur, client)

    envoi = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "STICKER", "media_asset_id": media_id},
        headers=headers_a,
    )
    assert envoi.status_code == 200, envoi.text
    assert envoi.json()["message_type"] == "STICKER"


def test_l_exception_sticker_n_ouvre_pas_les_photos_des_autres(client):
    # Le garde-fou : la même image, envoyée sous un AUTRE type, doit rester
    # refusée. Sans cette borne, il aurait suffi d'annoncer « STICKER »
    # pour joindre n'importe quel média deviné.
    headers_b, _, _ = _signup(client, "+22891000093")
    headers_a, _, _ = _signup(client, "+22891000094")
    _, user_id_c, _ = _signup(client, "+22891000095")
    client.post("/api/v1/contacts", json={"phone": "+22891000095", "display_name": "Carl"}, headers=headers_a)

    photo_de_b = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"octets-de-bob", "image/jpeg")},
        headers=headers_b,
    ).json()

    refus = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_c, "message_type": "STICKER", "media_asset_id": photo_de_b["id"]},
        headers=headers_a,
    )
    assert refus.status_code == 404


def test_le_destinataire_voit_le_sticker_recu(client):
    # Sans la branche ajoutée à `_can_access`, le destinataire recevait un
    # message dont l'image rendait 404 : un cadre cassé dans la bulle.
    headers_auteur, _, _ = _signup(client, "+22891000096")
    headers_a, _, _ = _signup(client, "+22891000097")
    headers_b, user_id_b, _ = _signup(client, "+22891000098")
    client.post("/api/v1/contacts", json={"phone": "+22891000098", "display_name": "Bob"}, headers=headers_a)

    media_id = _pack_public_avec_sticker(headers_auteur, client)
    client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "STICKER", "media_asset_id": media_id},
        headers=headers_a,
    )

    assert client.get(f"/api/v1/media/{media_id}", headers=headers_b).status_code == 200


def test_media_message_requires_media_asset_id(client):
    headers_a, _, _ = _signup(client, "+22891000048")
    _, user_id_b, _ = _signup(client, "+22891000049")
    client.post("/api/v1/contacts", json={"phone": "+22891000049", "display_name": "Bob"}, headers=headers_a)

    response = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "VIDEO"},
        headers=headers_a,
    )
    assert response.status_code == 400


def test_text_message_still_requires_content(client):
    headers_a, _, _ = _signup(client, "+22891000050")
    _, user_id_b, _ = _signup(client, "+22891000051")
    client.post("/api/v1/contacts", json={"phone": "+22891000051", "display_name": "Bob"}, headers=headers_a)

    response = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "TEXT"},
        headers=headers_a,
    )
    assert response.status_code == 400


# ─── Profile ──────────────────────────────────────────────────────────────────

def test_update_and_read_own_profile(client):
    headers_a, _, _ = _signup(client, "+22891000017")
    updated = client.put(
        "/api/v1/users/me/profile", json={"full_name": "Alice A.", "about": "Toujours en ligne"}, headers=headers_a
    )
    assert updated.status_code == 200
    assert updated.json()["about"] == "Toujours en ligne"

    fetched = client.get("/api/v1/users/me/profile", headers=headers_a).json()
    assert fetched["full_name"] == "Alice A."


def test_profile_of_non_contact_is_forbidden(client):
    headers_a, _, _ = _signup(client, "+22891000018")
    _, user_id_b, _ = _signup(client, "+22891000019")
    response = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a)
    assert response.status_code == 403


def test_profile_of_contact_is_visible(client):
    headers_a, _, _ = _signup(client, "+22891000020")
    _, user_id_b, _ = _signup(client, "+22891000021")
    client.post("/api/v1/contacts", json={"phone": "+22891000021", "display_name": "Bob"}, headers=headers_a)

    response = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a)
    assert response.status_code == 200
    assert response.json()["phone"] == "+22891000021"


def test_set_avatar_updates_profile(client):
    headers_a, _, _ = _signup(client, "+22891000052")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("avatar.jpg", b"fake-avatar-bytes", "image/jpeg")},
        headers=headers_a,
    ).json()

    response = client.put("/api/v1/users/me/profile", json={"avatar_media_id": uploaded["id"]}, headers=headers_a)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["avatar_media_id"] == uploaded["id"]
    assert body["avatar"]["id"] == uploaded["id"]

    fetched = client.get("/api/v1/users/me/profile", headers=headers_a).json()
    assert fetched["avatar"]["original_filename"] == "avatar.jpg"


def test_cannot_set_someone_elses_upload_as_avatar(client):
    headers_a, _, _ = _signup(client, "+22891000053")
    headers_b, _, _ = _signup(client, "+22891000054")
    uploaded_by_b = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("avatar.jpg", b"bytes-de-bob", "image/jpeg")},
        headers=headers_b,
    ).json()

    response = client.put(
        "/api/v1/users/me/profile", json={"avatar_media_id": uploaded_by_b["id"]}, headers=headers_a
    )
    assert response.status_code == 404


def test_avatar_is_downloadable_by_contacts_not_strangers(client):
    headers_a, _, _ = _signup(client, "+22891000055")
    headers_b, _, _ = _signup(client, "+22891000056")
    headers_c, _, _ = _signup(client, "+22891000057")  # stranger, not a contact of A
    client.post("/api/v1/contacts", json={"phone": "+22891000055", "display_name": "Alice"}, headers=headers_b)

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("avatar.jpg", b"fake-avatar-bytes", "image/jpeg")},
        headers=headers_a,
    ).json()
    client.put("/api/v1/users/me/profile", json={"avatar_media_id": uploaded["id"]}, headers=headers_a)

    # B a A dans ses contacts (voit son statut/profil) — peut voir l'avatar.
    ok = client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b)
    assert ok.status_code == 200

    # C n'a pas A dans ses contacts — refusé.
    forbidden = client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_c)
    assert forbidden.status_code == 404


# ─── Transfert / suppression ──────────────────────────────────────────────────

def test_forward_message_to_another_contact(client):
    headers_a, _, _ = _signup(client, "+22891000060")
    headers_b, user_id_b, _ = _signup(client, "+22891000061")
    _, user_id_c, _ = _signup(client, "+22891000062")
    client.post("/api/v1/contacts", json={"phone": "+22891000061", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000062", "display_name": "Charlie"}, headers=headers_a)

    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "devis 250000 FCFA"}, headers=headers_a
    ).json()

    forwarded = client.post(
        f"/api/v1/messages/{sent['id']}/forward", json={"recipient_id": user_id_c}, headers=headers_a
    )
    assert forwarded.status_code == 200, forwarded.text
    body = forwarded.json()
    # Une COPIE : nouvel id, nouvelle conversation, contenu identique.
    assert body["id"] != sent["id"]
    assert body["recipient_id"] == user_id_c
    assert body["content"] == "devis 250000 FCFA"

    # L'original est intact dans la conversation d'origine.
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["total"] == 1
    assert client.get(f"/api/v1/messages/{user_id_c}", headers=headers_a).json()["total"] == 1


def test_can_forward_a_received_message(client):
    headers_a, _, _ = _signup(client, "+22891000063")
    headers_b, user_id_b, _ = _signup(client, "+22891000064")
    _, user_id_c, _ = _signup(client, "+22891000065")
    client.post("/api/v1/contacts", json={"phone": "+22891000064", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000065", "display_name": "Charlie"}, headers=headers_b)

    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "à faire suivre"}, headers=headers_a
    ).json()

    # B n'est pas l'expéditeur mais le destinataire : il peut retransmettre.
    forwarded = client.post(
        f"/api/v1/messages/{sent['id']}/forward", json={"recipient_id": user_id_c}, headers=headers_b
    )
    assert forwarded.status_code == 200
    assert forwarded.json()["sender_id"] == user_id_b


def test_cannot_forward_to_a_non_contact(client):
    headers_a, _, _ = _signup(client, "+22891000066")
    _, user_id_b, _ = _signup(client, "+22891000067")
    _, user_id_c, _ = _signup(client, "+22891000068")
    client.post("/api/v1/contacts", json={"phone": "+22891000067", "display_name": "Bob"}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut"}, headers=headers_a
    ).json()

    response = client.post(
        f"/api/v1/messages/{sent['id']}/forward", json={"recipient_id": user_id_c}, headers=headers_a
    )
    assert response.status_code == 403


def test_cannot_forward_a_message_from_someone_elses_conversation(client):
    headers_a, _, _ = _signup(client, "+22891000069")
    headers_b, user_id_b, _ = _signup(client, "+22891000070")
    headers_c, user_id_c, _ = _signup(client, "+22891000071")
    client.post("/api/v1/contacts", json={"phone": "+22891000070", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000070", "display_name": "Bob"}, headers=headers_c)

    private = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "confidentiel"}, headers=headers_a
    ).json()

    # C n'est ni expéditeur ni destinataire de ce message.
    response = client.post(
        f"/api/v1/messages/{private['id']}/forward", json={"recipient_id": user_id_b}, headers=headers_c
    )
    assert response.status_code == 404


def test_forwarded_media_stays_downloadable_by_the_new_recipient(client):
    headers_a, _, _ = _signup(client, "+22891000072")
    _, user_id_b, _ = _signup(client, "+22891000073")
    headers_c, user_id_c, _ = _signup(client, "+22891000074")
    client.post("/api/v1/contacts", json={"phone": "+22891000073", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000074", "display_name": "Charlie"}, headers=headers_a)

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("facture.jpg", b"fake-jpeg-bytes", "image/jpeg")},
        headers=headers_a,
    ).json()
    sent = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    ).json()

    forwarded = client.post(
        f"/api/v1/messages/{sent['id']}/forward", json={"recipient_id": user_id_c}, headers=headers_a
    ).json()
    assert forwarded["media_asset_id"] == uploaded["id"]
    # Sans ça le transfert d'une photo afficherait une pièce jointe cassée.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_c).status_code == 200


def test_forwarded_message_is_pushed_live_over_websocket(client):
    headers_a, _, _ = _signup(client, "+22891000075")
    _, user_id_b, _ = _signup(client, "+22891000076")
    _, user_id_c, token_c = _signup(client, "+22891000077")
    client.post("/api/v1/contacts", json={"phone": "+22891000076", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000077", "display_name": "Charlie"}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "à transférer"}, headers=headers_a
    ).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_c}") as ws:
        forwarded = client.post(
            f"/api/v1/messages/{sent['id']}/forward", json={"recipient_id": user_id_c}, headers=headers_a
        )
        assert forwarded.status_code == 200
        # Même bascule de statut que pour un envoi normal (voir _deliver).
        assert forwarded.json()["status"] == "DELIVERED"
        event = ws.receive_json()
        assert event["type"] == "message:new"
        assert event["message"]["content"] == "à transférer"


def test_sender_can_delete_own_message(client):
    headers_a, _, _ = _signup(client, "+22891000078")
    _, user_id_b, _ = _signup(client, "+22891000079")
    client.post("/api/v1/contacts", json={"phone": "+22891000079", "display_name": "Bob"}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "oups"}, headers=headers_a
    ).json()

    deleted = client.delete(f"/api/v1/messages/{sent['id']}", headers=headers_a)
    assert deleted.status_code == 200
    assert deleted.json()["deleted"] is True
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["total"] == 0


def test_recipient_cannot_delete_a_received_message(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000080")
    headers_b, user_id_b, _ = _signup(client, "+22891000081")
    client.post("/api/v1/contacts", json={"phone": "+22891000081", "display_name": "Bob"}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "tu ne peux pas l'effacer"}, headers=headers_a
    ).json()

    # Suppression = « supprimer pour tout le monde » : réservée à l'expéditeur.
    response = client.delete(f"/api/v1/messages/{sent['id']}", headers=headers_b)
    assert response.status_code == 404
    assert client.get(f"/api/v1/messages/{user_id_a}", headers=headers_b).json()["total"] == 1


def test_deletion_is_pushed_to_the_recipient_over_websocket(client):
    headers_a, _, _ = _signup(client, "+22891000082")
    _, user_id_b, token_b = _signup(client, "+22891000083")
    client.post("/api/v1/contacts", json={"phone": "+22891000083", "display_name": "Bob"}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "à retirer"}, headers=headers_a
    ).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        client.delete(f"/api/v1/messages/{sent['id']}", headers=headers_a)
        event = ws.receive_json()
        assert event["type"] == "message:deleted"
        # L'événement ne porte QUE l'id : le message n'existe plus côté
        # serveur (voir _onEvent dans messaging_controller.dart).
        assert event["message_id"] == sent["id"]


def test_deleting_an_unknown_message_is_404(client):
    headers_a, _, _ = _signup(client, "+22891000084")
    assert client.delete("/api/v1/messages/does-not-exist", headers=headers_a).status_code == 404


# ─── Réponses citées ──────────────────────────────────────────────────────────

def _linked_pair(client, phone_a, phone_b):
    """Deux comptes qui se sont mutuellement ajoutés — condition pour
    s'écrire dans les deux sens (voir _require_contact)."""
    headers_a, user_id_a, token_a = _signup(client, phone_a)
    headers_b, user_id_b, token_b = _signup(client, phone_b)
    client.post("/api/v1/contacts", json={"phone": phone_b, "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": phone_a, "display_name": "Alice"}, headers=headers_b)
    return (headers_a, user_id_a, token_a), (headers_b, user_id_b, token_b)


def _rewrite_message(message_id, **fields):
    """Écrit directement en base pour faire passer le temps : aucune route
    ne permet de vieillir un message, et attendre quinze minutes (ou
    vingt-quatre heures) dans un test n'est pas une option."""
    db = TestingSessionLocal()
    try:
        db.query(DirectMessage).filter(DirectMessage.id == message_id).update(fields)
        db.commit()
    finally:
        db.close()


def test_reply_carries_a_preview_of_the_quoted_message(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000101", "+228891000102")
    quoted = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "combien pour 50 sacs ?"},
        headers=headers_a,
    ).json()

    answer = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "250000 FCFA", "reply_to_id": quoted["id"]},
        headers=headers_a,
    )
    assert answer.status_code == 200, answer.text
    body = answer.json()
    assert body["reply_to_id"] == quoted["id"]
    # Le client dessine la citation sans second appel.
    assert body["reply_to"]["id"] == quoted["id"]
    assert body["reply_to"]["sender_id"] == quoted["sender_id"]
    assert body["reply_to"]["content"] == "combien pour 50 sacs ?"
    assert body["reply_to"]["message_type"] == "TEXT"


def test_message_without_a_quote_has_a_null_preview(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000103", "+228891000104")
    body = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "salut"}, headers=headers_a
    ).json()
    assert body["reply_to"] is None
    assert body["reply_to_id"] is None


def test_quoted_preview_content_is_truncated(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000105", "+228891000106")
    long_text = "a" * 400
    quoted = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": long_text}, headers=headers_a
    ).json()

    body = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "ok", "reply_to_id": quoted["id"]},
        headers=headers_a,
    ).json()
    preview = body["reply_to"]["content"]
    assert preview.endswith("…")
    assert len(preview) < len(long_text)


def test_reply_preview_never_nests_a_second_level(client):
    """Une chaîne de réponses ne doit pas faire grossir la réponse de proche
    en proche : l'aperçu du message cité ne porte pas sa propre citation."""
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000107", "+228891000108")
    first = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "un"}, headers=headers_a
    ).json()
    second = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "deux", "reply_to_id": first["id"]},
        headers=headers_a,
    ).json()
    third = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "trois", "reply_to_id": second["id"]},
        headers=headers_a,
    ).json()

    assert third["reply_to"]["id"] == second["id"]
    assert "reply_to" not in third["reply_to"]


def test_cannot_quote_a_message_from_another_conversation(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000109", "+228891000110")
    _, user_id_c, _ = _signup(client, "+228891000111")
    client.post("/api/v1/contacts", json={"phone": "+228891000111", "display_name": "Charlie"}, headers=headers_a)

    with_charlie = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_c, "content": "prix d'ami pour toi"},
        headers=headers_a,
    ).json()

    # Citer ce message chez Bob lui recopierait un extrait d'une
    # conversation à laquelle il n'a jamais eu accès.
    response = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "regarde", "reply_to_id": with_charlie["id"]},
        headers=headers_a,
    )
    assert response.status_code == 404, response.text
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["total"] == 0


def test_reply_preview_of_a_media_message_carries_its_metadata(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000112", "+228891000113")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("facture.jpg", b"\xff\xd8\xff-fake-jpeg", "image/jpeg")},
        headers=headers_a,
    ).json()
    photo = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    ).json()

    body = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "bien reçu", "reply_to_id": photo["id"]},
        headers=headers_a,
    ).json()
    assert body["reply_to"]["message_type"] == "IMAGE"
    assert body["reply_to"]["media"]["original_filename"] == "facture.jpg"


# ─── Réactions ────────────────────────────────────────────────────────────────

def test_reaction_replaces_the_previous_one_instead_of_stacking(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000114", "+228891000115")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "livré ce matin"}, headers=headers_a
    ).json()

    client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)
    second = client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "❤️"}, headers=headers_b)
    assert second.status_code == 200, second.text

    reactions = second.json()["reactions"]
    assert len(reactions) == 1
    assert reactions[0]["emoji"] == "❤️"
    assert reactions[0]["count"] == 1


def test_reactions_are_aggregated_by_emoji(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000116", "+228891000117")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "le marché est conclu"}, headers=headers_a
    ).json()

    client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_a)
    both = client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_b).json()

    grouped = {r["emoji"]: r for r in both["reactions"]}
    assert list(grouped) == ["👍"]
    assert grouped["👍"]["count"] == 2
    assert sorted(grouped["👍"]["user_ids"]) == sorted([user_id_a, user_id_b])
    # `mine` est calculé pour CELUI qui lit : c'est Bob qui vient de réagir.
    assert grouped["👍"]["mine"] is True

    apart = client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "🎉"}, headers=headers_b).json()
    grouped = {r["emoji"]: r["count"] for r in apart["reactions"]}
    assert grouped == {"👍": 1, "🎉": 1}


def test_mine_is_false_for_someone_elses_reaction(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000118", "+228891000119")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "d'accord"}, headers=headers_a
    ).json()
    client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)

    seen_by_alice = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"][0]
    assert seen_by_alice["reactions"][0]["mine"] is False


def test_removing_a_reaction_leaves_the_message_without_any(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000120", "+228891000121")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "bien noté"}, headers=headers_a
    ).json()
    client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)

    removed = client.delete(f"/api/v1/messages/{sent['id']}/reaction", headers=headers_b)
    assert removed.status_code == 200, removed.text
    assert removed.json()["reactions"] == []


def test_removing_an_absent_reaction_is_not_an_error(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000122", "+228891000123")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "rien à signaler"}, headers=headers_a
    ).json()
    response = client.delete(f"/api/v1/messages/{sent['id']}/reaction", headers=headers_b)
    assert response.status_code == 200
    assert response.json()["reactions"] == []


def test_a_stranger_cannot_react_to_a_conversation_he_is_not_part_of(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000124", "+228891000125")
    headers_c, _, _ = _signup(client, "+228891000126")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "confidentiel"}, headers=headers_a
    ).json()

    response = client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_c)
    assert response.status_code == 404


def test_reaction_is_pushed_to_the_other_party_over_websocket(client):
    (headers_a, _, token_a), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000127", "+228891000128")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "on se voit demain"}, headers=headers_a
    ).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws:
        reacted = client.put(f"/api/v1/messages/{sent['id']}/reaction", json={"emoji": "👍"}, headers=headers_b)
        assert reacted.status_code == 200

        event = ws.receive_json()
        assert event["type"] == "message:reaction"
        assert event["message"]["id"] == sent["id"]
        assert event["message"]["reactions"][0]["emoji"] == "👍"
        # L'événement est sérialisé du point de vue de celui qui le reçoit.
        assert event["message"]["reactions"][0]["mine"] is False


# ─── Modification ─────────────────────────────────────────────────────────────

def test_sender_can_edit_own_text_message_within_the_window(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000129", "+228891000130")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "250000 FCFA"}, headers=headers_a
    ).json()
    assert sent["edited_at"] is None

    edited = client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "260000 FCFA"}, headers=headers_a)
    assert edited.status_code == 200, edited.text
    assert edited.json()["content"] == "260000 FCFA"
    assert edited.json()["edited_at"] is not None

    history = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"]
    assert history[0]["content"] == "260000 FCFA"
    assert history[0]["edited_at"] is not None


def test_only_the_sender_can_edit_a_message(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000131", "+228891000132")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "prix ferme"}, headers=headers_a
    ).json()

    response = client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "gratuit"}, headers=headers_b)
    assert response.status_code == 404
    received = client.get(f"/api/v1/messages/{user_id_a}", headers=headers_b).json()["items"][0]
    assert received["content"] == "prix ferme"


def test_editing_after_the_fifteen_minute_window_is_refused(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000133", "+228891000134")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "je m'engage sur 500000 FCFA"},
        headers=headers_a,
    ).json()
    # Vieilli au-delà de la fenêtre, quelle qu'elle soit : on dérive le
    # décalage de la constante plutôt que de l'écrire à la main, sinon
    # changer la fenêtre casse le test pour une raison sans rapport.
    _rewrite_message(
        sent["id"],
        created_at=datetime.utcnow() - (MESSAGE_EDIT_WINDOW + timedelta(minutes=1)),
    )

    response = client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "50 FCFA"}, headers=headers_a)
    assert response.status_code == 409, response.text
    assert str(MESSAGE_EDIT_WINDOW_MINUTES) in response.json()["detail"]

    history = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"]
    assert history[0]["content"] == "je m'engage sur 500000 FCFA"
    assert history[0]["edited_at"] is None


def test_a_media_message_cannot_be_edited(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000135", "+228891000136")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"\xff\xd8\xff-fake-jpeg", "image/jpeg")},
        headers=headers_a,
    ).json()
    sent = client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    ).json()

    response = client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "autre légende"}, headers=headers_a)
    assert response.status_code == 403, response.text


def test_edit_is_pushed_to_the_recipient_over_websocket(client):
    (headers_a, _, _), (_, user_id_b, token_b) = _linked_pair(client, "+228891000137", "+228891000138")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "rendez-vous à 9h"}, headers=headers_a
    ).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        client.patch(f"/api/v1/messages/{sent['id']}", json={"content": "rendez-vous à 10h"}, headers=headers_a)
        event = ws.receive_json()
        assert event["type"] == "message:edited"
        assert event["message"]["content"] == "rendez-vous à 10h"
        assert event["message"]["edited_at"] is not None


# ─── Messages éphémères ───────────────────────────────────────────────────────

def test_disappearing_setting_is_read_back_and_can_be_disabled(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000139", "+228891000140")
    assert client.get(f"/api/v1/messages/{user_id_b}/disappearing", headers=headers_a).json()[
        "disappearing_seconds"
    ] is None

    updated = client.put(
        f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 604800}, headers=headers_a
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["disappearing_seconds"] == 604800
    assert client.get(f"/api/v1/messages/{user_id_b}/disappearing", headers=headers_a).json()[
        "disappearing_seconds"
    ] == 604800

    cleared = client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": None}, headers=headers_a)
    assert cleared.json()["disappearing_seconds"] is None


def test_disappearing_setting_rejects_an_arbitrary_duration(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000141", "+228891000142")
    response = client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 42}, headers=headers_a)
    assert response.status_code == 400
    assert client.get(f"/api/v1/messages/{user_id_b}/disappearing", headers=headers_a).json()[
        "disappearing_seconds"
    ] is None


def test_disappearing_setting_of_a_non_contact_is_forbidden(client):
    headers_a, _, _ = _signup(client, "+228891000143")
    _, user_id_b, _ = _signup(client, "+228891000144")
    assert client.get(f"/api/v1/messages/{user_id_b}/disappearing", headers=headers_a).status_code == 403


def test_message_sent_with_disappearing_enabled_gets_an_expiry(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000145", "+228891000146")
    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 86400}, headers=headers_a)

    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "à oublier demain"}, headers=headers_a
    ).json()
    assert sent["expires_at"] is not None


def test_expired_message_is_absent_from_the_history_of_both_parties(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000147", "+228891000148")
    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 86400}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "code du coffre 4821"}, headers=headers_a
    ).json()
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["total"] == 1

    _rewrite_message(sent["id"], expires_at=datetime.utcnow() - timedelta(seconds=1))

    for headers, other_id in ((headers_a, user_id_b), (headers_b, user_id_a)):
        history = client.get(f"/api/v1/messages/{other_id}", headers=headers).json()
        assert history["total"] == 0
        assert history["items"] == []


def test_expiry_is_frozen_at_send_time_and_survives_a_setting_change(client):
    """Changer le réglage ne doit pas réécrire le passé : les messages déjà
    envoyés gardent l'échéance qu'ils avaient au moment de l'envoi."""
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000149", "+228891000150")
    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 86400}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "figé"}, headers=headers_a
    ).json()
    frozen = sent["expires_at"]
    assert frozen is not None

    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 7776000}, headers=headers_a)
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"][0]["expires_at"] == frozen

    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": None}, headers=headers_a)
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"][0]["expires_at"] == frozen

    # Et le réglage ne s'applique qu'aux envois SUIVANTS.
    plain = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "sans échéance"}, headers=headers_a
    ).json()
    assert plain["expires_at"] is None


# ─── Média à vue unique ───────────────────────────────────────────────────────

def _send_view_once_photo(client, headers_sender, recipient_id):
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("secret.jpg", b"\xff\xd8\xff-vue-unique", "image/jpeg")},
        headers=headers_sender,
    ).json()
    sent = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": recipient_id,
            "message_type": "IMAGE",
            "media_asset_id": uploaded["id"],
            "view_once": True,
        },
        headers=headers_sender,
    )
    return uploaded, sent


def test_view_once_is_refused_on_a_document(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000151", "+228891000152")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "DOCUMENT"},
        files={"file": ("contrat.txt", b"contenu", "text/plain")},
        headers=headers_a,
    ).json()

    response = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": user_id_b,
            "message_type": "DOCUMENT",
            "media_asset_id": uploaded["id"],
            "view_once": True,
        },
        headers=headers_a,
    )
    assert response.status_code == 400, response.text


def test_view_once_media_is_unreachable_after_viewing_but_stays_open_to_the_sender(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000153", "+228891000154")
    uploaded, sent = _send_view_once_photo(client, headers_a, user_id_b)
    assert sent.status_code == 200, sent.text
    message = sent.json()
    assert message["view_once"] is True
    assert message["viewed_at"] is None

    # Avant consultation le destinataire télécharge la photo normalement.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200

    viewed = client.post(f"/api/v1/messages/{message['id']}/viewed", headers=headers_b)
    assert viewed.status_code == 200, viewed.text
    assert viewed.json()["viewed_at"] is not None

    # Sans le verrou côté média, il suffirait de rappeler GET /media/{id}
    # pour revoir le contenu.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 404
    # L'expéditeur garde son propre fichier.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_a).status_code == 200


def test_only_the_recipient_can_mark_a_view_once_message_viewed(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000155", "+228891000156")
    _, sent = _send_view_once_photo(client, headers_a, user_id_b)
    message = sent.json()

    # L'expéditeur ne consomme pas sa propre vue unique.
    assert client.post(f"/api/v1/messages/{message['id']}/viewed", headers=headers_a).status_code == 404
    assert client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()["items"][0]["viewed_at"] is None


def test_marking_viewed_twice_keeps_the_first_timestamp(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000157", "+228891000158")
    _, sent = _send_view_once_photo(client, headers_a, user_id_b)
    message = sent.json()

    first = client.post(f"/api/v1/messages/{message['id']}/viewed", headers=headers_b).json()["viewed_at"]
    second = client.post(f"/api/v1/messages/{message['id']}/viewed", headers=headers_b).json()["viewed_at"]
    assert first == second


def test_marking_an_ordinary_message_viewed_is_refused(client):
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000159", "+228891000160")
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "message normal"}, headers=headers_a
    ).json()
    assert client.post(f"/api/v1/messages/{sent['id']}/viewed", headers=headers_b).status_code == 400


def test_an_ordinary_photo_stays_downloadable_after_being_seen(client):
    """Le verrou de la vue unique ne doit pas se refermer sur les photos
    ordinaires, qu'on doit pouvoir rouvrir autant qu'on veut."""
    (headers_a, _, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000161", "+228891000162")
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"\xff\xd8\xff-fake-jpeg", "image/jpeg")},
        headers=headers_a,
    ).json()
    client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )

    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200


# ─── Recherche ────────────────────────────────────────────────────────────────

def test_search_is_case_insensitive_and_covers_both_directions(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(client, "+228891000163", "+228891000164")
    client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "Devis pour 50 sacs"}, headers=headers_a
    )
    client.post(
        "/api/v1/messages", json={"recipient_id": user_id_a, "content": "j'ai reçu le DEVIS"}, headers=headers_b
    )
    client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "bonne journée"}, headers=headers_a)

    found = client.get("/api/v1/messages/search", params={"q": "devis"}, headers=headers_a)
    assert found.status_code == 200, found.text
    items = found.json()["items"]
    assert len(items) == 2
    # L'autre partie est donnée pour que le client sache quelle conversation ouvrir.
    assert {item["contact_user_id"] for item in items} == {user_id_b}
    # Du plus récent au plus ancien.
    assert items[0]["content"] == "j'ai reçu le DEVIS"


def test_search_does_not_return_other_peoples_conversations(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000165", "+228891000166")
    headers_c, _, _ = _signup(client, "+228891000167")
    client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "code du coffre 4821"}, headers=headers_a
    )

    assert client.get("/api/v1/messages/search", params={"q": "coffre"}, headers=headers_c).json()["items"] == []
    assert len(client.get("/api/v1/messages/search", params={"q": "coffre"}, headers=headers_a).json()["items"]) == 1


def test_search_excludes_expired_messages(client):
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000168", "+228891000169")
    client.put(f"/api/v1/messages/{user_id_b}/disappearing", json={"seconds": 86400}, headers=headers_a)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "mot de passe temporaire"}, headers=headers_a
    ).json()
    assert len(client.get("/api/v1/messages/search", params={"q": "passe"}, headers=headers_a).json()["items"]) == 1

    _rewrite_message(sent["id"], expires_at=datetime.utcnow() - timedelta(seconds=1))
    assert client.get("/api/v1/messages/search", params={"q": "passe"}, headers=headers_a).json()["items"] == []


def test_search_treats_like_wildcards_as_plain_text(client):
    """Sans échappement, chercher « 50% » ferait de `%` un joker et
    ramènerait toute la conversation."""
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000170", "+228891000171")
    client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "remise de 50% ce mois"}, headers=headers_a)
    client.post("/api/v1/messages", json={"recipient_id": user_id_b, "content": "sans remise"}, headers=headers_a)

    items = client.get("/api/v1/messages/search", params={"q": "50%"}, headers=headers_a).json()["items"]
    assert len(items) == 1
    assert items[0]["content"] == "remise de 50% ce mois"


def test_search_requires_a_query(client):
    headers_a, _, _ = _signup(client, "+228891000172")
    assert client.get("/api/v1/messages/search", headers=headers_a).status_code == 422


def test_deleting_the_quoted_message_leaves_the_answer_readable(client):
    """Supprimer le message d'origine n'emporte pas les réponses qu'il a
    suscitées : elles perdent seulement leur citation."""
    (headers_a, _, _), (_, user_id_b, _) = _linked_pair(client, "+228891000173", "+228891000174")
    quoted = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "à supprimer"}, headers=headers_a
    ).json()
    client.post(
        "/api/v1/messages",
        json={"recipient_id": user_id_b, "content": "ma réponse", "reply_to_id": quoted["id"]},
        headers=headers_a,
    )

    client.delete(f"/api/v1/messages/{quoted['id']}", headers=headers_a)

    history = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()
    assert history["total"] == 1
    assert history["items"][0]["content"] == "ma réponse"
    assert history["items"][0]["reply_to"] is None


# ─── Contenus riches : payload/poll survivent au rechargement ────────────────
#
# app/routes/polls.py sérialise déjà `payload`/`poll` dans la réponse d'envoi
# et l'événement WebSocket `message:new`. Mais GET /messages/{contact_user_id}
# passait par _serialize() de CE module, qui ne les renvoyait pas : un sondage
# ou une position affichait ses détails juste après l'envoi puis les perdait
# au premier rechargement de la conversation.

def test_conversation_history_carries_poll_payload_after_reload(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(
        client, "+228891000175", "+228891000176"
    )
    created = client.post(
        "/api/v1/polls",
        json={
            "kind": "contact",
            "target_id": user_id_b,
            "question": "On part à quelle heure ?",
            "options": ["8h", "9h"],
        },
        headers=headers_a,
    )
    assert created.status_code == 200, created.text
    poll_id = created.json()["poll"]["id"]
    option_id = created.json()["poll"]["options"][0]["id"]
    client.post(f"/api/v1/polls/{poll_id}/vote", json={"option_ids": [option_id]}, headers=headers_b)

    history = client.get(f"/api/v1/messages/{user_id_a}", headers=headers_b).json()
    bubble = history["items"][-1]
    assert bubble["message_type"] == "POLL"
    assert bubble["poll"]["question"] == "On part à quelle heure ?"
    assert bubble["poll"]["options"][0]["vote_count"] == 1
    assert bubble["poll"]["options"][0]["mine"] is True


def test_conversation_history_carries_location_payload_after_reload(client):
    (headers_a, user_id_a, _), (headers_b, user_id_b, _) = _linked_pair(
        client, "+228891000177", "+228891000178"
    )
    client.post(
        "/api/v1/polls/location",
        json={
            "kind": "contact",
            "target_id": user_id_b,
            "latitude": 6.1319,
            "longitude": 1.2228,
            "label": "Marché",
        },
        headers=headers_a,
    )

    history = client.get(f"/api/v1/messages/{user_id_a}", headers=headers_b).json()
    bubble = history["items"][-1]
    assert bubble["message_type"] == "LOCATION"
    assert bubble["payload"]["latitude"] == 6.1319
    assert bubble["payload"]["label"] == "Marché"


# ─── Suivi de commande dans la conversation ─────────────────────────────────


def _publish_product(client, headers, name="Ciment", price=5500):
    response = client.post(
        "/api/v1/marketplace",
        json={"name": name, "price": price, "currency": "XOF"},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()["id"]


def test_seul_le_vendeur_fait_avancer_une_commande(client):
    (seller, seller_id, _), (buyer, buyer_id, _) = _linked_pair(
        client, "+228891000901", "+228891000902"
    )
    product_id = _publish_product(client, seller)

    # LA vérification qui manquait. L'ancienne version envoyait un message
    # texte portant « [POKOU_ORDER] » : l'acheteur pouvait le TAPER et
    # annoncer lui-même que sa commande était livrée. Un suivi falsifiable
    # en le tapant n'est pas un suivi.
    usurpation = client.post(
        "/api/v1/messages/order-update",
        json={"recipient_id": seller_id, "product_id": product_id, "status": "DELIVERED"},
        headers=buyer,
    )
    assert usurpation.status_code == 403

    legitimate = client.post(
        "/api/v1/messages/order-update",
        json={"recipient_id": buyer_id, "product_id": product_id, "status": "VALIDATED"},
        headers=seller,
    )
    assert legitimate.status_code == 200, legitimate.text


def test_l_etat_de_commande_voyage_hors_du_texte(client):
    (seller, _, _), (buyer, buyer_id, _) = _linked_pair(
        client, "+228891000903", "+228891000904"
    )
    product_id = _publish_product(client, seller)

    sent = client.post(
        "/api/v1/messages/order-update",
        json={"recipient_id": buyer_id, "product_id": product_id, "status": "SHIPPED"},
        headers=seller,
    ).json()

    # Dans `payload`, donc dans une colonne de MÉTADONNÉES que le
    # chiffrement ne touche pas : le destinataire classe le message sans
    # avoir rien à déchiffrer. C'est ce qui produisait une bulle vide quand
    # le marqueur voyageait dans le texte chiffré.
    order = sent["payload"]["pokou_order"]
    assert order["status"] == "SHIPPED"
    assert order["label"] == "Commande expédiée"
    assert order["product_id"] == product_id

    # Et `content` reste une phrase LISIBLE : c'est elle qui s'affiche dans
    # l'aperçu de la liste des discussions, et dans une version de
    # l'application qui ne connaîtrait pas encore ce format. L'ancienne
    # version y mettait un marqueur technique.
    assert sent["content"] == "Commande expédiée · Ciment"
    assert "[POKOU_ORDER]" not in sent["content"]


def test_un_etat_de_commande_inconnu_est_refuse(client):
    (seller, _, _), (_buyer, buyer_id, _) = _linked_pair(
        client, "+228891000905", "+228891000906"
    )
    product_id = _publish_product(client, seller)
    response = client.post(
        "/api/v1/messages/order-update",
        json={"recipient_id": buyer_id, "product_id": product_id, "status": "ANNULEE"},
        headers=seller,
    )
    assert response.status_code == 422


def test_le_destinataire_recoit_bien_l_etat(client):
    (seller, seller_id, _), (buyer, buyer_id, _) = _linked_pair(
        client, "+228891000907", "+228891000908"
    )
    product_id = _publish_product(client, seller)
    client.post(
        "/api/v1/messages/order-update",
        json={"recipient_id": buyer_id, "product_id": product_id, "status": "DELIVERED"},
        headers=seller,
    )

    received = client.get(f"/api/v1/messages/{seller_id}", headers=buyer).json()["items"]
    assert received[-1]["payload"]["pokou_order"]["status"] == "DELIVERED"


# ─── Le rafraîchissement de la liste d'accueil ────────────────────────────────


def test_l_expediteur_est_prevenu_que_sa_liste_a_change(client):
    """Écrire à quelqu'un puis revenir laissait la liste des discussions
    telle qu'elle était : il fallait tirer pour rafraîchir.

    Le serveur ne prévenait que le DESTINATAIRE. L'expéditeur — et ses
    autres appareils — n'apprenaient rien de leur propre envoi.
    """
    headers_a, sender_id, _ = _signup(client, "+22891700001")
    headers_b, recipient_id, _ = _signup(client, "+22891700002")

    with patch("app.api.v1.messaging.messages.manager.send_to_user") as pushed:
        pushed.return_value = False
        response = client.post(
            "/api/v1/messages",
            json={
                "recipient_id": recipient_id,
                "recipient_phone": "+22891700002",
                "content": "salut",
            },
            headers=headers_a,
        )
    assert response.status_code == 200

    events = {call.args[0]: call.args[1] for call in pushed.call_args_list}
    assert recipient_id in events, "le destinataire doit toujours recevoir son message"
    assert events[recipient_id]["type"] == "message:new"

    assert sender_id in events, "l'expéditeur n'était prévenu de rien"
    # Un type DISTINCT de `message:new` : la conversation ouverte chez
    # l'expéditeur a déjà ajouté ce message de façon optimiste, et lui
    # repousser `message:new` l'afficherait deux fois.
    assert events[sender_id]["type"] == "conversation:updated"
    assert events[sender_id]["contact_user_id"] == recipient_id


# ── Accusé de remise au retour du destinataire ───────────────────────────────

def test_un_message_envoye_a_un_absent_est_remis_a_sa_reconnexion(client):
    """Un message écrit à quelqu'un de hors ligne restait à une coche jusqu'à
    sa LECTURE. Il est remis dès que son téléphone se reconnecte, et
    l'expéditeur en est prévenu."""
    headers_a, user_id_a, token_a = _signup(client, "+22891000901")
    headers_b, user_id_b, token_b = _signup(client, "+22891000902")
    client.post("/api/v1/contacts", json={"phone": "+22891000902", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000901", "display_name": "Alice"}, headers=headers_b)

    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "tu es là ?"}, headers=headers_a
    ).json()
    assert sent["status"] == "SENT"

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws_a:
        with client.websocket_connect(f"/api/v1/ws?token={token_b}"):
            event = ws_a.receive_json()
            assert event["type"] == "message:status"
            assert event["message"]["id"] == sent["id"]
            assert event["message"]["status"] == "DELIVERED"

    conversation = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()
    assert conversation["items"][0]["status"] == "DELIVERED"


def test_la_reconnexion_ne_rétrograde_pas_un_message_lu(client):
    headers_a, user_id_a, _ = _signup(client, "+22891000903")
    headers_b, user_id_b, token_b = _signup(client, "+22891000904")
    client.post("/api/v1/contacts", json={"phone": "+22891000904", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22891000903", "display_name": "Alice"}, headers=headers_b)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_b, "content": "lu"}, headers=headers_a
    ).json()
    client.post(f"/api/v1/messages/{sent['id']}/read", headers=headers_b)

    with client.websocket_connect(f"/api/v1/ws?token={token_b}"):
        pass

    conversation = client.get(f"/api/v1/messages/{user_id_b}", headers=headers_a).json()
    assert conversation["items"][0]["status"] == "READ"
