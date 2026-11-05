from datetime import datetime, timedelta
import base64
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import Status
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_status.db"

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


def _upload(client, headers, message_type="IMAGE", content=b"fake-bytes", mime="image/jpeg", name="photo.jpg"):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": message_type},
        files={"file": (name, content, mime)},
        headers=headers,
    ).json()


def _upload_opaque(client, headers):
    return _upload(
        client,
        headers,
        message_type="DOCUMENT",
        content=b"\x00" * 32,
        mime="application/octet-stream",
        name="pokou.bin",
    )


def _recipient_payload(client, headers):
    audience = client.get("/api/v1/status/audience", headers=headers).json()["recipient_ids"]
    return [
        {
            "user_id": user_id,
            "encryption": "v1",
            "ciphertext": base64.b64encode(b"\x00" * 32).decode(),
            "envelope": {
                "v": 1,
                "sid": f"test-{user_id}",
                "n": 0,
                "iv": base64.b64encode(b"\x00" * 12).decode(),
            },
        }
        for user_id in audience
    ]


def _post_text_status(client, headers, text="bonjour"):
    response = client.post(
        "/api/v1/status",
        json={"content_type": "TEXT", "recipients": _recipient_payload(client, headers)},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


def _post_media_status(client, headers, media_asset_id, content_type="IMAGE"):
    response = client.post(
        "/api/v1/status",
        json={
            "content_type": content_type,
            "media_asset_id": media_asset_id,
            "recipients": _recipient_payload(client, headers),
        },
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


def _expire(status_id: str) -> None:
    # Passe par app.dependency_overrides[get_db] plutôt que par
    # TestingSessionLocal directement : quand ce fichier tourne aux côtés
    # d'autres modules de test Pokou qui font la même surcharge au niveau
    # module (test_pokou_messaging.py, test_pokou_calls.py...), c'est la
    # dernière assignation importée qui gagne pour toute la session pytest —
    # un statut créé via le TestClient peut donc atterrir dans une autre
    # base que TestingSessionLocal. Repasser par la surcharge active
    # garantit qu'on modifie la même ligne que celle que l'API vient de créer.
    db = next(app.dependency_overrides[get_db]())
    try:
        row = db.query(Status).filter(Status.id == status_id).first()
        row.expires_at = datetime.utcnow() - timedelta(hours=1)
        db.commit()
    finally:
        db.close()


# ─── Création ─────────────────────────────────────────────────────────────────

def test_create_text_status(client):
    headers, _, _ = _signup(client, "+22892000001")
    body = _post_text_status(client, headers, "Bonne journée !")
    assert body["content_type"] == "TEXT"
    assert body["text_content"] is None
    assert body["encrypted_content"] is None
    assert body["media"] is None
    assert body["view_count"] == 0


def test_plaintext_status_content_is_rejected(client):
    headers, _, _ = _signup(client, "+22892000002")
    plaintext = client.post(
        "/api/v1/status",
        json={"content_type": "TEXT", "text_content": "must not reach server"},
        headers=headers,
    )
    assert plaintext.status_code == 422


def test_create_media_status(client):
    headers, _, _ = _signup(client, "+22892000003")
    uploaded = _upload_opaque(client, headers)
    body = _post_media_status(client, headers, uploaded["id"])
    assert body["media"]["id"] == uploaded["id"]
    assert body["text_content"] is None


def test_status_audience_is_authoritative_and_cannot_fall_back_to_plaintext(client):
    headers_a, _, _ = _signup(client, "+22892000030")
    headers_b, user_id_b, _ = _signup(client, "+22892000031")
    client.post(
        "/api/v1/contacts",
        json={"phone": "+22892000031", "display_name": "Bob"},
        headers=headers_a,
    )
    client.post(
        "/api/v1/contacts",
        json={"phone": "+22892000030", "display_name": "Alice"},
        headers=headers_b,
    )
    audience = client.get("/api/v1/status/audience", headers=headers_a).json()
    assert audience["recipient_ids"] == [user_id_b]

    stale = {
        "content_type": "TEXT",
        "recipients": [],
    }
    response = client.post("/api/v1/status", json=stale, headers=headers_a)
    assert response.status_code == 409

    created = _post_text_status(client, headers_a, "secret text")
    feed = client.get("/api/v1/status/feed", headers=headers_b).json()["items"]
    status = feed[0]["statuses"][0]
    assert status["text_content"] is None
    assert status["encrypted_content"]["ciphertext"]
    assert status["encrypted_content"]["envelope"]

    owner_feed = client.get("/api/v1/status/feed", headers=headers_a).json()["items"]
    own = next(item for item in owner_feed if item["user_id"] == created["user_id"])
    assert own["statuses"][0]["text_content"] is None
    assert own["statuses"][0]["encrypted_content"] is None


def test_plaintext_media_markers_are_rejected(client):
    headers, _, _ = _signup(client, "+22892000032")
    uploaded = _upload(client, headers)
    response = client.post(
        "/api/v1/status",
        json={
            "content_type": "IMAGE",
            "media_asset_id": uploaded["id"],
            "recipients": _recipient_payload(client, headers),
        },
        headers=headers,
    )
    assert response.status_code == 400


def test_media_status_requires_media_asset_id(client):
    headers, _, _ = _signup(client, "+22892000004")
    response = client.post("/api/v1/status", json={"content_type": "IMAGE"}, headers=headers)
    assert response.status_code == 400


def test_status_media_downloadable_by_contact_viewing_the_feed(client):
    headers_a, _, _ = _signup(client, "+22892000008")
    headers_b, _, _ = _signup(client, "+22892000009")
    # A a B dans son carnet : c'est l'auteur du statut qui décide de son
    # public (voir services/status_privacy_service.py).
    client.post("/api/v1/contacts", json={"phone": "+22892000009", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22892000008", "display_name": "Alice"}, headers=headers_b)

    uploaded = _upload_opaque(client, headers_a)
    created = _post_media_status(client, headers_a, uploaded["id"])

    # B fait partie du public de A — il peut télécharger le média du statut.
    response = client.get(f"/api/v1/media/{created['media']['id']}", headers=headers_b)
    assert response.status_code == 200


def test_status_media_not_downloadable_by_non_contact(client):
    headers_a, _, _ = _signup(client, "+22892000010")
    headers_c, _, _ = _signup(client, "+22892000011")  # pas dans les contacts de A

    uploaded = _upload_opaque(client, headers_a)
    created = _post_media_status(client, headers_a, uploaded["id"])

    response = client.get(f"/api/v1/media/{created['media']['id']}", headers=headers_c)
    assert response.status_code == 404


def test_cannot_create_status_with_someone_elses_asset(client):
    headers_a, _, _ = _signup(client, "+22892000005")
    headers_b, _, _ = _signup(client, "+22892000006")
    uploaded_by_b = _upload_opaque(client, headers_b)

    response = client.post(
        "/api/v1/status",
        json={
            "content_type": "IMAGE",
            "media_asset_id": uploaded_by_b["id"],
            "recipients": _recipient_payload(client, headers_a),
        },
        headers=headers_a,
    )
    assert response.status_code == 404


def test_invalid_content_type_rejected(client):
    headers, _, _ = _signup(client, "+22892000007")
    response = client.post("/api/v1/status", json={"content_type": "GIF"}, headers=headers)
    assert response.status_code == 400


# ─── Feed ─────────────────────────────────────────────────────────────────────

def test_feed_includes_own_and_contacts_statuses_not_strangers(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000010")
    headers_b, user_id_b, _ = _signup(client, "+22892000011")
    headers_c, user_id_c, _ = _signup(client, "+22892000012")  # stranger, not a contact of A

    client.post("/api/v1/contacts", json={"phone": "+22892000011", "display_name": "Bob"}, headers=headers_a)
    # B doit avoir A dans SON carnet : c'est l'auteur qui choisit son public
    # (voir services/status_privacy_service.py). Avoir ajouté quelqu'un ne
    # donne pas accès à ses statuts.
    client.post("/api/v1/contacts", json={"phone": "+22892000010", "display_name": "Alice"}, headers=headers_b)

    _post_text_status(client, headers_a, "moi")
    _post_text_status(client, headers_b, "bob")
    _post_text_status(client, headers_c, "charlie")

    feed = client.get("/api/v1/status/feed", headers=headers_a).json()["items"]
    author_ids = {item["user_id"] for item in feed}
    assert author_ids == {user_id_a, user_id_b}
    assert user_id_c not in author_ids


def test_feed_excludes_expired_statuses(client):
    headers, _, _ = _signup(client, "+22892000013")
    created = _post_text_status(client, headers, "va expirer")
    _expire(created["id"])

    feed = client.get("/api/v1/status/feed", headers=headers).json()["items"]
    assert feed == []


# ─── Vues ─────────────────────────────────────────────────────────────────────

def test_view_status_records_view_and_increments_count(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000020")
    headers_b, user_id_b, _ = _signup(client, "+22892000021")
    client.post("/api/v1/contacts", json={"phone": "+22892000021", "display_name": "Bob"}, headers=headers_a)
    # B doit aussi avoir A dans ses propres contacts pour pouvoir voir/vue son
    # statut — la visibilité d'un statut est déterminée par le carnet
    # d'adresses du *spectateur*, comme pour le feed (voir _require_contact).
    client.post("/api/v1/contacts", json={"phone": "+22892000020", "display_name": "Alice"}, headers=headers_b)

    created = _post_text_status(client, headers_a, "salut")

    viewed = client.post(f"/api/v1/status/{created['id']}/view", headers=headers_b)
    assert viewed.status_code == 200

    feed = client.get("/api/v1/status/feed", headers=headers_a).json()["items"]
    mine = next(item for item in feed if item["user_id"] == user_id_a)
    assert mine["statuses"][0]["view_count"] == 1
    assert mine["statuses"][0]["viewed_by_me"] is False  # A didn't view their own status


def test_viewing_own_status_does_not_count(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000022")
    created = _post_text_status(client, headers_a, "salut")

    response = client.post(f"/api/v1/status/{created['id']}/view", headers=headers_a)
    assert response.status_code == 200

    feed = client.get("/api/v1/status/feed", headers=headers_a).json()["items"]
    mine = next(item for item in feed if item["user_id"] == user_id_a)
    assert mine["statuses"][0]["view_count"] == 0


def test_cannot_view_status_of_non_contact(client):
    headers_a, _, _ = _signup(client, "+22892000023")
    headers_b, _, _ = _signup(client, "+22892000024")  # not a contact of A

    created = _post_text_status(client, headers_a, "salut")

    response = client.post(f"/api/v1/status/{created['id']}/view", headers=headers_b)
    assert response.status_code == 404


def test_view_expired_status_returns_404(client):
    headers_a, _, _ = _signup(client, "+22892000025")
    headers_b, _, _ = _signup(client, "+22892000026")
    client.post("/api/v1/contacts", json={"phone": "+22892000026", "display_name": "Bob"}, headers=headers_a)

    created = _post_text_status(client, headers_a, "salut")
    _expire(created["id"])

    response = client.post(f"/api/v1/status/{created['id']}/view", headers=headers_b)
    assert response.status_code == 404


# ─── Visibilité choisie par l'auteur ─────────────────────────────────────────

def _feed_author_ids(client, headers):
    feed = client.get("/api/v1/status/feed", headers=headers).json()
    return {item["user_id"] for item in feed["items"]}


def test_default_visibility_is_the_authors_contacts(client):
    """Sans réglage, le comportement d'avant : visible par les contacts de
    l'auteur. La MIGRATION ne doit changer la visibilité de personne."""
    headers_a, user_id_a, _ = _signup(client, "+22893300001")
    headers_b, user_id_b, _ = _signup(client, "+22893300002")

    # A a B dans son carnet — c'est A qui décide de son public.
    client.post("/api/v1/contacts", json={"phone": "+22893300002", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893300001", "display_name": "Alice"}, headers=headers_b)

    _post_text_status(client, headers_a)

    assert user_id_a in _feed_author_ids(client, headers_b)
    assert client.get("/api/v1/status/privacy", headers=headers_a).json() == {
        "mode": "CONTACTS",
        "user_ids": [],
    }


def test_a_stranger_who_added_me_does_not_see_my_status(client):
    """C'est l'auteur qui choisit son public : ajouter quelqu'un à SON carnet
    ne doit pas donner accès à SES statuts."""
    headers_a, user_id_a, _ = _signup(client, "+22893300003")
    headers_b, _, _ = _signup(client, "+22893300004")

    # B ajoute A, mais A n'a pas B.
    client.post("/api/v1/contacts", json={"phone": "+22893300003", "display_name": "Alice"}, headers=headers_b)
    _post_text_status(client, headers_a)

    assert user_id_a not in _feed_author_ids(client, headers_b)


def test_nobody_mode_hides_the_status_from_everyone(client):
    headers_a, user_id_a, _ = _signup(client, "+22893300005")
    headers_b, _, _ = _signup(client, "+22893300006")
    client.post("/api/v1/contacts", json={"phone": "+22893300006", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893300005", "display_name": "Alice"}, headers=headers_b)

    assert client.put(
        "/api/v1/status/privacy", json={"mode": "NOBODY"}, headers=headers_a
    ).status_code == 200
    _post_text_status(client, headers_a)

    assert user_id_a not in _feed_author_ids(client, headers_b)
    # L'auteur voit toujours ses propres statuts.
    assert user_id_a in _feed_author_ids(client, headers_a)


def test_except_mode_hides_from_the_listed_people_only(client):
    headers_a, user_id_a, _ = _signup(client, "+22893300007")
    headers_b, user_id_b, _ = _signup(client, "+22893300008")
    headers_c, user_id_c, _ = _signup(client, "+22893300009")
    for phone, headers in (("+22893300008", headers_b), ("+22893300009", headers_c)):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers_a)
        client.post("/api/v1/contacts", json={"phone": "+22893300007", "display_name": "Alice"}, headers=headers)

    client.put(
        "/api/v1/status/privacy",
        json={"mode": "EXCEPT", "user_ids": [user_id_b]},
        headers=headers_a,
    )
    _post_text_status(client, headers_a)

    assert user_id_a not in _feed_author_ids(client, headers_b)
    assert user_id_a in _feed_author_ids(client, headers_c)


def test_only_mode_shows_to_the_listed_people_even_without_contact(client):
    """En mode ONLY l'auteur désigne nommément son public : la relation de
    contact n'est plus la condition."""
    headers_a, user_id_a, _ = _signup(client, "+22893300010")
    headers_b, user_id_b, _ = _signup(client, "+22893300011")
    headers_c, user_id_c, _ = _signup(client, "+22893300012")
    for phone, headers in (("+22893300011", headers_b), ("+22893300012", headers_c)):
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers_a)
        client.post("/api/v1/contacts", json={"phone": "+22893300010", "display_name": "Alice"}, headers=headers)

    client.put(
        "/api/v1/status/privacy",
        json={"mode": "ONLY", "user_ids": [user_id_c]},
        headers=headers_a,
    )
    _post_text_status(client, headers_a)

    assert user_id_a not in _feed_author_ids(client, headers_b)
    assert user_id_a in _feed_author_ids(client, headers_c)


def test_the_list_is_replaced_not_merged(client):
    headers_a, _, _ = _signup(client, "+22893300013")
    _, user_id_b, _ = _signup(client, "+22893300014")
    _, user_id_c, _ = _signup(client, "+22893300015")

    client.put(
        "/api/v1/status/privacy", json={"mode": "EXCEPT", "user_ids": [user_id_b]}, headers=headers_a
    )
    updated = client.put(
        "/api/v1/status/privacy", json={"mode": "EXCEPT", "user_ids": [user_id_c]}, headers=headers_a
    ).json()

    # C'est un réglage, pas un journal d'ajouts.
    assert updated["user_ids"] == [user_id_c]


def test_switching_back_to_contacts_forgets_the_list(client):
    headers_a, _, _ = _signup(client, "+22893300016")
    _, user_id_b, _ = _signup(client, "+22893300017")

    client.put(
        "/api/v1/status/privacy", json={"mode": "EXCEPT", "user_ids": [user_id_b]}, headers=headers_a
    )
    back = client.put("/api/v1/status/privacy", json={"mode": "CONTACTS"}, headers=headers_a).json()

    assert back == {"mode": "CONTACTS", "user_ids": []}


def test_an_invalid_mode_is_rejected(client):
    headers_a, _, _ = _signup(client, "+22893300018")
    response = client.put("/api/v1/status/privacy", json={"mode": "PEUT-ETRE"}, headers=headers_a)
    assert response.status_code == 400


def test_status_media_cannot_be_fetched_by_someone_who_cannot_see_the_status(client):
    """Le fil filtre, mais /media/{id} doit filtrer aussi — sinon il suffit
    d'appeler l'un pour contourner l'autre."""
    headers_a, _, _ = _signup(client, "+22893300019")
    headers_b, _, _ = _signup(client, "+22893300020")
    client.post("/api/v1/contacts", json={"phone": "+22893300020", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22893300019", "display_name": "Alice"}, headers=headers_b)

    uploaded = _upload_opaque(client, headers_a)
    _post_media_status(client, headers_a, uploaded["id"])

    # Visible tant que le mode est CONTACTS…
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200

    client.put("/api/v1/status/privacy", json={"mode": "NOBODY"}, headers=headers_a)
    # …et plus après.
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 404


def test_privacy_endpoints_require_authentication(client):
    assert client.get("/api/v1/status/privacy").status_code in (401, 403)
    assert client.put("/api/v1/status/privacy", json={"mode": "NOBODY"}).status_code in (401, 403)


# ─── Qui a vu mon statut, et quand ────────────────────────────────────────────

def test_the_author_sees_who_viewed_and_when(client):
    headers_a, user_id_a, _ = _signup(client, "+22894500001")
    headers_b, user_id_b, _ = _signup(client, "+22894500002")
    headers_c, user_id_c, _ = _signup(client, "+22894500003")
    # Le statut n'est visible que des contacts — la relation doit exister
    # dans les deux sens pour que B et C voient celui de A.
    client.post("/api/v1/contacts", json={"phone": "+22894500002", "display_name": "Bob du dépôt"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22894500003", "display_name": "Charlie"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22894500001", "display_name": "Ama"}, headers=headers_b)
    client.post("/api/v1/contacts", json={"phone": "+22894500001", "display_name": "Ama"}, headers=headers_c)

    status_id = _post_text_status(client, headers_a, "Dépôt ouvert")["id"]

    client.post(f"/api/v1/status/{status_id}/view", headers=headers_b)
    client.post(f"/api/v1/status/{status_id}/view", headers=headers_c)

    views = client.get(f"/api/v1/status/{status_id}/views", headers=headers_a).json()
    assert views["view_count"] == 2
    assert {item["viewer_id"] for item in views["items"]} == {user_id_b, user_id_c}
    # Le nom du carnet de l'AUTEUR l'emporte sur celui du spectateur.
    names = {item["viewer_id"]: item["display_name"] for item in views["items"]}
    assert names[user_id_b] == "Bob du dépôt"
    # Chaque vue porte son heure.
    assert all(item["viewed_at"] for item in views["items"])


def test_viewing_twice_counts_once(client):
    headers_a, _, _ = _signup(client, "+22894500004")
    headers_b, user_id_b, _ = _signup(client, "+22894500005")
    client.post("/api/v1/contacts", json={"phone": "+22894500005", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22894500004", "display_name": "Ama"}, headers=headers_b)
    status_id = _post_text_status(client, headers_a, "Coucou")["id"]

    for _ in range(3):
        client.post(f"/api/v1/status/{status_id}/view", headers=headers_b)

    views = client.get(f"/api/v1/status/{status_id}/views", headers=headers_a).json()
    assert views["view_count"] == 1
    assert len(views["items"]) == 1


def test_nobody_else_can_see_who_viewed_a_status(client):
    """Savoir qui regarde le statut de quelqu'un d'autre n'est le droit de
    personne — 404 plutôt que 403, pour ne pas confirmer l'existence du
    statut derrière cet identifiant."""
    headers_a, _, _ = _signup(client, "+22894500006")
    headers_b, user_id_b, _ = _signup(client, "+22894500007")
    client.post("/api/v1/contacts", json={"phone": "+22894500007", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22894500006", "display_name": "Ama"}, headers=headers_b)
    status_id = _post_text_status(client, headers_a, "Privé")["id"]
    client.post(f"/api/v1/status/{status_id}/view", headers=headers_b)

    # B a VU le statut, mais ne doit pas savoir qui d'autre l'a vu.
    assert client.get(f"/api/v1/status/{status_id}/views", headers=headers_b).status_code == 404


def test_a_status_nobody_watched_reports_zero_views(client):
    headers_a, _, _ = _signup(client, "+22894500008")
    status_id = _post_text_status(client, headers_a, "Personne")["id"]

    views = client.get(f"/api/v1/status/{status_id}/views", headers=headers_a).json()
    assert views["view_count"] == 0
    assert views["items"] == []


# ─── Suppression ──────────────────────────────────────────────────────────────

def test_l_auteur_retire_son_statut_avant_les_24h(client):
    """Une photo publiée avec le mauvais prix restait visible une journée
    entière : il n'existait aucun moyen de la retirer."""
    headers_a, user_id_a, _ = _signup(client, "+22892000090")
    headers_b, _, _ = _signup(client, "+22892000091")
    client.post("/api/v1/contacts", json={"phone": "+22892000091", "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22892000090", "display_name": "Alice"}, headers=headers_b)
    created = _post_text_status(client, headers_a, "mauvais prix")
    client.post(f"/api/v1/status/{created['id']}/view", headers=headers_b)

    response = client.delete(f"/api/v1/status/{created['id']}", headers=headers_a)
    assert response.status_code == 200, response.text

    feed_b = client.get("/api/v1/status/feed", headers=headers_b).json()["items"]
    assert all(item["user_id"] != user_id_a for item in feed_b)
    db = TestingSessionLocal()
    try:
        assert db.query(Status).filter(Status.id == created["id"]).first() is None
    finally:
        db.close()


def test_on_ne_retire_pas_le_statut_d_un_autre(client):
    headers_a, _, _ = _signup(client, "+22892000092")
    headers_b, _, _ = _signup(client, "+22892000093")
    created = _post_text_status(client, headers_a, "à moi")

    # 404 et non 403 : « interdit » confirmerait l'existence du statut.
    assert client.delete(f"/api/v1/status/{created['id']}", headers=headers_b).status_code == 404
    feed_a = client.get("/api/v1/status/feed", headers=headers_a).json()["items"]
    assert len(feed_a) == 1
