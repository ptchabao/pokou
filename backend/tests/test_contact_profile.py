"""Pokou — fiche contact (GET /users/{id}/profile), façon WhatsApp Business :
médias échangés, documents, liens, groupes en commun, état de blocage.

Le point sensible reste l'ACCÈS : cette fiche agrège tout ce qui a été
échangé avec quelqu'un, donc elle ne doit jamais s'ouvrir sur simple
énumération d'identifiants, et ne jamais laisser fuir la conversation d'un
tiers dans ses sections.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_contact_profile.db"

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
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _add_contact(client, headers, phone, name):
    return client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers)


def _upload(client, headers, filename, mime, message_type):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": message_type},
        files={"file": (filename, b"des-octets", mime)},
        headers=headers,
    ).json()["id"]


def _send(client, headers, recipient_id, **body):
    payload = {"recipient_id": recipient_id}
    payload.update(body)
    return client.post("/api/v1/messages", json=payload, headers=headers)


# ─── Accès ────────────────────────────────────────────────────────────────────

def test_profile_is_refused_for_a_non_contact(client):
    """La fiche agrège tout l'échangé : elle ne doit pas s'ouvrir par simple
    énumération d'identifiants."""
    headers_a, _ = _signup(client, "+22897300001")
    _, user_id_b = _signup(client, "+22897300002")
    assert client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).status_code == 403


def test_la_fiche_s_ouvre_pour_quelqu_un_qui_m_a_ecrit_sans_etre_dans_mon_carnet(client):
    """B a A dans son répertoire et lui écrit ; A n'a pas le numéro de B.
    A doit pouvoir regarder qui lui écrit, et l'enregistrer depuis la fiche."""
    headers_a, user_id_a = _signup(client, "+22897300003")
    headers_b, user_id_b = _signup(client, "+22897300004")
    _add_contact(client, headers_b, "+22897300003", "Alice")
    assert _send(client, headers_b, user_id_a, content="Bonjour").status_code in (200, 201)

    response = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a)
    assert response.status_code == 200
    profile = response.json()
    assert profile["phone"] == "+22897300004"
    assert profile["is_contact"] is False
    assert profile["contact_display_name"] is None
    assert profile["is_blocked"] is False


def test_la_fiche_s_ouvre_pour_qui_m_a_dans_son_carnet(client):
    """La relation de carnet compte dans les deux sens, comme pour la
    confidentialité (privacy_service.est_dans_les_contacts)."""
    headers_a, _ = _signup(client, "+22897300005")
    headers_b, user_id_b = _signup(client, "+22897300006")
    _add_contact(client, headers_b, "+22897300005", "Alice")
    assert client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).status_code == 200


def test_la_fiche_s_ouvre_entre_membres_d_un_meme_groupe(client):
    headers_a, _ = _signup(client, "+22897300007")
    headers_b, user_id_b = _signup(client, "+22897300008")
    headers_c, user_id_c = _signup(client, "+22897300009")
    _add_contact(client, headers_a, "+22897300008", "Bob")
    _add_contact(client, headers_a, "+22897300009", "Charlie")
    client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [user_id_b, user_id_c]},
        headers=headers_a,
    )
    _rejoindre(client, headers_b)
    _rejoindre(client, headers_c)
    # B et C ne se connaissent que par le groupe.
    assert client.get(f"/api/v1/users/{user_id_c}/profile", headers=headers_b).status_code == 200


def test_la_fiche_dit_si_la_personne_est_dans_mon_carnet(client):
    headers_a, _ = _signup(client, "+22897300010")
    _, user_id_b = _signup(client, "+22897300011")
    _add_contact(client, headers_a, "+22897300011", "Bob")
    profile = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert profile["is_contact"] is True
    assert profile["contact_display_name"] == "Bob"


def test_le_badge_d_identite_suit_le_compte_sur_les_deux_profils(client):
    """Le ✓ accordé depuis l'admin doit se lire sur la fiche d'un contact et
    sur son propre profil, pas seulement dans la liste des discussions."""
    headers_a, _ = _signup(client, "+22897300003")
    headers_b, user_id_b = _signup(client, "+22897300004")
    _add_contact(client, headers_a, "+22897300004", "Bob")
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id_b).update({"is_verified": True})
        db.commit()
    finally:
        db.close()

    assert client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()["is_verified"] is True
    assert client.get("/api/v1/users/me/profile", headers=headers_b).json()["is_verified"] is True
    assert client.get("/api/v1/users/me/profile", headers=headers_a).json()["is_verified"] is False


# ─── Médias, documents, liens ─────────────────────────────────────────────────

def test_visuals_and_documents_are_separated(client):
    """Les visuels se regardent en grille, les documents se lisent en liste —
    un seul tableau mélangé obligerait le client à retrier."""
    headers_a, _ = _signup(client, "+22897300010")
    headers_b, user_id_b = _signup(client, "+22897300011")
    _add_contact(client, headers_a, "+22897300011", "Bob")

    image = _upload(client, headers_a, "photo.jpg", "image/jpeg", "IMAGE")
    _send(client, headers_a, user_id_b, message_type="IMAGE", media_asset_id=image)
    document = _upload(client, headers_a, "devis.pdf", "application/pdf", "DOCUMENT")
    _send(client, headers_a, user_id_b, message_type="DOCUMENT", media_asset_id=document)

    profile = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert [item["media"]["id"] for item in profile["shared_media"]] == [image]
    assert [item["media"]["id"] for item in profile["shared_documents"]] == [document]
    # Métadonnée complète : le client a besoin du MIME pour nommer son cache.
    assert profile["shared_media"][0]["media"]["mime_type"] == "image/jpeg"
    assert profile["shared_documents"][0]["media"]["original_filename"] == "devis.pdf"


def test_links_are_deduplicated_newest_first(client):
    headers_a, _ = _signup(client, "+22897300012")
    headers_b, user_id_b = _signup(client, "+22897300013")
    _add_contact(client, headers_a, "+22897300013", "Bob")

    _send(client, headers_a, user_id_b, content="vieux https://ancien.example")
    _send(client, headers_a, user_id_b, content="https://recent.example et encore https://recent.example")

    links = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()["shared_links"]
    urls = [item["url"] for item in links]
    # Dédoublonné, et le plus récent d'abord (un set seul les remonterait
    # dans un ordre arbitraire).
    assert urls == ["https://recent.example", "https://ancien.example"]


def test_the_profile_never_leaks_a_third_partys_conversation(client):
    headers_a, _ = _signup(client, "+22897300014")
    headers_b, user_id_b = _signup(client, "+22897300015")
    headers_c, user_id_c = _signup(client, "+22897300016")
    _add_contact(client, headers_a, "+22897300015", "Bob")
    _add_contact(client, headers_a, "+22897300016", "Charlie")
    _add_contact(client, headers_b, "+22897300016", "Charlie")

    # Échange entre B et C, dont A ne doit rien voir.
    _send(client, headers_b, user_id_c, content="secret https://prive.example")

    profile = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert profile["shared_links"] == []
    assert profile["shared_media"] == []


# ─── Groupes en commun ────────────────────────────────────────────────────────

def _rejoindre(client, headers):
    """Accepte les invitations en attente.

    Pokou INVITE au lieu d'ajouter depuis `20260928_group_invitations` : un
    groupe créé avec des membres ne les y met plus. Ces tests portent sur la
    FICHE DE CONTACT — groupes en commun, médias partagés — et le flux
    d'invitation a son propre fichier.
    """
    for invitation in client.get(
        "/api/v1/groups/invitations", headers=headers
    ).json()["items"]:
        client.post(
            f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers
        )


def test_common_groups_lists_only_groups_we_both_belong_to(client):
    headers_a, _ = _signup(client, "+22897300020")
    headers_b, user_id_b = _signup(client, "+22897300021")
    _, user_id_c = _signup(client, "+22897300022")
    _add_contact(client, headers_a, "+22897300021", "Bob")
    _add_contact(client, headers_a, "+22897300022", "Charlie")

    shared = client.post(
        "/api/v1/groups", json={"name": "Chantier", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)
    # Un groupe où B n'est PAS, et qui ne doit donc pas apparaître.
    client.post(
        "/api/v1/groups", json={"name": "Sans Bob", "member_user_ids": [user_id_c]}, headers=headers_a
    )

    profile = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert [group["name"] for group in profile["common_groups"]] == ["Chantier"]
    assert profile["common_groups"][0]["id"] == shared["id"]
    assert profile["common_groups"][0]["member_count"] == 2


def test_leaving_a_group_removes_it_from_the_common_list(client):
    headers_a, user_id_a = _signup(client, "+22897300023")
    headers_b, user_id_b = _signup(client, "+22897300024")
    _add_contact(client, headers_a, "+22897300024", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Éphémère", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_a)

    profile = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert profile["common_groups"] == []


# ─── Blocage et nom du carnet ─────────────────────────────────────────────────

def test_profile_carries_my_block_state_and_my_own_name_for_them(client):
    """La fiche doit pouvoir afficher « Bloquer » ou « Débloquer » sans un
    second appel, et montrer le nom que J'AI donné au contact."""
    headers_a, _ = _signup(client, "+22897300030")
    _, user_id_b = _signup(client, "+22897300031")
    _add_contact(client, headers_a, "+22897300031", "Bob du dépôt")

    before = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert before["is_blocked"] is False
    assert before["contact_display_name"] == "Bob du dépôt"

    client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": user_id_b, "blocked": True},
        headers=headers_a,
    )
    after = client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()
    assert after["is_blocked"] is True

    client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": user_id_b, "blocked": False},
        headers=headers_a,
    )
    assert client.get(f"/api/v1/users/{user_id_b}/profile", headers=headers_a).json()["is_blocked"] is False
