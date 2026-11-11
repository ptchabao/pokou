"""Pokou — conversations de groupe (api/app/routes/groups.py).

Fichier séparé de test_pokou_messaging.py sur le même modèle : base SQLite
dédiée, inscription par OTP mockée. Ne teste PAS les accusés de lecture — le
modèle GroupMessage n'en a délibérément pas (voir sa docstring dans orm.py).
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import GroupInvitation, GroupInvitationStatus, GroupMessage, User
from app.services.messaging import group_invitation_service
from app.services.auth import otp_service
from app.utils.editing import MESSAGE_EDIT_WINDOW
from tests.helpers import GroupCryptoClient

TEST_DATABASE_URL = "sqlite:///./test_pokou_groups.db"

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
    # Les messages de groupe partent chiffrés, comme depuis l'app.
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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"], body["access_token"]


def _add_contact(client, headers, phone, name):
    return client.post("/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers)


# ─── Création ─────────────────────────────────────────────────────────────────

def _rejoindre(client, headers):
    """Accepte toutes les invitations en attente de cet utilisateur.

    Depuis que Pokou INVITE au lieu d'ajouter, créer un groupe avec des
    membres ne les y met plus : ils reçoivent une invitation. Or ces tests
    portent sur le comportement des GROUPES — envoyer, lire, quitter,
    administrer — et non sur le flux d'invitation, qui a son propre fichier
    (`test_group_invitations.py`).

    Ce helper leur rend donc leur point de départ : un groupe dont les
    membres sont bien membres. Sans lui, chaque test revérifierait
    l'invitation, et on ne saurait plus lequel couvre quoi.
    """
    invitations = client.get("/api/v1/groups/invitations", headers=headers).json()
    for invitation in invitations["items"]:
        client.post(
            f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=headers
        )


def test_create_group_makes_the_creator_owner(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000001")
    headers_b, user_id_b, _ = _signup(client, "+22892000002")
    _add_contact(client, headers_a, "+22892000002", "Bob")

    response = client.post(
        "/api/v1/groups", json={"name": "Dépôt Adidogomé", "member_user_ids": [user_id_b]}, headers=headers_a
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["name"] == "Dépôt Adidogomé"
    # Le créateur est SEUL membre : Bob est invité, pas embarqué. C'est tout
    # l'objet du changement — on ne se retrouve plus dans une conversation
    # sans l'avoir demandé.
    assert body["member_count"] == 1
    assert len(body["invitations"]) == 1

    _rejoindre(client, headers_b)
    body = client.get(f"/api/v1/groups/{body['id']}", headers=headers_a).json()
    assert body["member_count"] == 2
    roles = {member["user_id"]: member["role"] for member in body["members"]}
    assert roles[user_id_a] == "OWNER"
    assert roles[user_id_b] == "MEMBER"


def test_cannot_add_a_non_contact_at_creation(client):
    headers_a, _, _ = _signup(client, "+22892000003")
    headers_b, user_id_b, _ = _signup(client, "+22892000004")

    response = client.post(
        "/api/v1/groups", json={"name": "Inconnus", "member_user_ids": [user_id_b]}, headers=headers_a
    )
    _rejoindre(client, headers_b)
    assert response.status_code == 403


def test_creator_listed_once_even_if_passed_as_member(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000005")
    response = client.post(
        "/api/v1/groups", json={"name": "Solo", "member_user_ids": [user_id_a]}, headers=headers_a
    )
    _rejoindre(client, headers_a)
    assert response.status_code == 200
    assert response.json()["member_count"] == 1


def test_group_name_is_required(client):
    headers_a, _, _ = _signup(client, "+22892000006")
    response = client.post("/api/v1/groups", json={"name": "", "member_user_ids": []}, headers=headers_a)
    assert response.status_code == 422


# ─── Lecture / appartenance ───────────────────────────────────────────────────

def test_list_only_returns_my_groups(client):
    headers_a, _, _ = _signup(client, "+22892000007")
    headers_b, _, _ = _signup(client, "+22892000008")
    client.post("/api/v1/groups", json={"name": "Groupe de A", "member_user_ids": []}, headers=headers_a)

    assert len(client.get("/api/v1/groups", headers=headers_a).json()["items"]) == 1
    assert client.get("/api/v1/groups", headers=headers_b).json()["items"] == []


def test_non_member_cannot_read_a_group_or_its_messages(client):
    headers_a, _, _ = _signup(client, "+22892000009")
    headers_b, _, _ = _signup(client, "+22892000010")
    group = client.post("/api/v1/groups", json={"name": "Privé", "member_user_ids": []}, headers=headers_a).json()

    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers_b).status_code == 403
    assert client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_b).status_code == 403
    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "coucou"}, headers=headers_b
    )
    assert sent.status_code == 403


# ─── Messages ─────────────────────────────────────────────────────────────────

def test_send_and_fetch_group_messages_in_chronological_order(client):
    headers_a, _, _ = _signup(client, "+22892000011")
    headers_b, user_id_b, _ = _signup(client, "+22892000012")
    _add_contact(client, headers_a, "+22892000012", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Chantier", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    assert client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "premier"}, headers=headers_a
    ).status_code == 200
    assert client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "deuxième"}, headers=headers_b
    ).status_code == 200

    listed = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_b).json()
    assert [item["content"] for item in listed["items"]] == ["premier", "deuxième"]
    # `sender_name` est résolu côté serveur pour éviter un appel par auteur.
    assert all(item["sender_name"] for item in listed["items"])


def test_l_historique_d_un_groupe_se_remonte_page_par_page(client):
    """Seule la dernière page était servie : au-delà de 100 messages, le
    début d'un groupe actif devenait inaccessible."""
    headers_a, _, _ = _signup(client, "+22892000091")
    _, user_id_b, _ = _signup(client, "+22892000092")
    _add_contact(client, headers_a, "+22892000092", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Marché", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    for i in range(5):
        assert client.post(
            f"/api/v1/groups/{group['id']}/messages", json={"content": f"m{i}"}, headers=headers_a
        ).status_code == 200

    url = f"/api/v1/groups/{group['id']}/messages"
    page = client.get(url, params={"limit": 2}, headers=headers_a).json()
    assert [m["content"] for m in page["items"]] == ["m3", "m4"]
    assert page["has_more"] is True

    page = client.get(
        url, params={"limit": 2, "before": page["items"][0]["created_at"]}, headers=headers_a
    ).json()
    assert [m["content"] for m in page["items"]] == ["m1", "m2"]
    assert page["has_more"] is True

    page = client.get(
        url, params={"limit": 2, "before": page["items"][0]["created_at"]}, headers=headers_a
    ).json()
    assert [m["content"] for m in page["items"]] == ["m0"]
    assert page["has_more"] is False


def test_un_message_de_groupe_porte_le_nom_d_un_auteur_certifie(client):
    """Le même message part à tous : seul le nom d'un compte CERTIFIÉ, qui
    l'emporte sur tous les carnets, vient du serveur."""
    headers_a, user_id_a, _ = _signup(client, "+22892000095")
    _, user_id_b, _ = _signup(client, "+22892000096")
    _add_contact(client, headers_a, "+22892000096", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Quartier", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    client.post(f"/api/v1/groups/{group['id']}/messages", json={"content": "avant"}, headers=headers_a)
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id_a).update({"full_name": "Mairie de Lomé", "is_verified": True})
        db.commit()
    finally:
        db.close()
    client.post(f"/api/v1/groups/{group['id']}/messages", json={"content": "après"}, headers=headers_a)

    items = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_a).json()["items"]
    assert [m["sender_certified_name"] for m in items] == ["Mairie de Lomé", "Mairie de Lomé"]
    assert all(m["sender_is_verified"] for m in items)


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : l'évènement temps réel ne porte plus de texte en clair, seulement le chiffré")
def test_group_message_is_delivered_live_over_websocket(client):
    headers_a, _, _ = _signup(client, "+22892000013")
    headers_b, user_id_b, token_b = _signup(client, "+22892000014")
    _add_contact(client, headers_a, "+22892000014", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Livraisons", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        sent = client.post(
            f"/api/v1/groups/{group['id']}/messages", json={"content": "le camion arrive"}, headers=headers_a
        )
        assert sent.status_code == 200
        event = ws.receive_json()
        assert event["type"] == "group:message:new"
        assert event["message"]["content"] == "le camion arrive"
        assert event["message"]["group_id"] == group["id"]


def test_text_group_message_requires_content(client):
    headers_a, _, _ = _signup(client, "+22892000015")
    group = client.post("/api/v1/groups", json={"name": "Vide", "member_user_ids": []}, headers=headers_a).json()
    response = client.post(f"/api/v1/groups/{group['id']}/messages", json={"content": "   "}, headers=headers_a)
    assert response.status_code == 400


def test_media_group_message_requires_an_attachment(client):
    headers_a, _, _ = _signup(client, "+22892000016")
    group = client.post("/api/v1/groups", json={"name": "Photos", "member_user_ids": []}, headers=headers_a).json()
    response = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"message_type": "IMAGE"}, headers=headers_a
    )
    assert response.status_code == 400


def test_invalid_message_type_is_rejected(client):
    headers_a, _, _ = _signup(client, "+22892000017")
    group = client.post("/api/v1/groups", json={"name": "Types", "member_user_ids": []}, headers=headers_a).json()
    response = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "HOLOGRAMME", "content": "x"},
        headers=headers_a,
    )
    assert response.status_code == 400


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : un média de groupe part chiffré, avec sa clé dans le message : contrat à réécrire")
def test_cannot_attach_someone_elses_upload_to_a_group_message(client):
    headers_a, _, _ = _signup(client, "+22892000018")
    headers_b, user_id_b, _ = _signup(client, "+22892000019")
    _add_contact(client, headers_a, "+22892000019", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Factures", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    uploaded_by_b = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"bytes-de-bob", "image/jpeg")},
        headers=headers_b,
    ).json()

    response = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "IMAGE", "media_asset_id": uploaded_by_b["id"]},
        headers=headers_a,
    )
    assert response.status_code == 404


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : un média de groupe part chiffré, avec sa clé dans le message : contrat à réécrire")
def test_group_message_carries_its_media_metadata(client):
    headers_a, _, _ = _signup(client, "+22892000020")
    group = client.post("/api/v1/groups", json={"name": "Docs", "member_user_ids": []}, headers=headers_a).json()
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "AUDIO"},
        files={"file": ("note.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=headers_a,
    ).json()

    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "AUDIO", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )
    assert sent.status_code == 200, sent.text
    body = sent.json()
    assert body["message_type"] == "AUDIO"
    assert body["media"]["id"] == uploaded["id"]


# ─── Membres ──────────────────────────────────────────────────────────────────

def test_any_member_can_add_one_of_their_own_contacts(client):
    headers_a, _, _ = _signup(client, "+22892000021")
    headers_b, user_id_b, _ = _signup(client, "+22892000022")
    _, user_id_c, _ = _signup(client, "+22892000023")
    _add_contact(client, headers_a, "+22892000022", "Bob")
    _add_contact(client, headers_b, "+22892000023", "Charlie")
    group = client.post(
        "/api/v1/groups", json={"name": "Extensible", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    # B n'est pas OWNER mais peut inviter Charlie, qui est dans SON carnet.
    response = client.post(
        f"/api/v1/groups/{group['id']}/members", json={"user_ids": [user_id_c]}, headers=headers_b
    )
    assert response.status_code == 200, response.text
    # INVITÉ, pas ajouté : le groupe en compte toujours deux tant que
    # Charlie n'a rien accepté. C'est le cœur du changement, et ce test le
    # constate au lieu de l'ignorer.
    assert len(response.json()["invitations"]) == 1
    assert response.json()["group"]["member_count"] == 2


def test_cannot_add_someone_absent_from_my_own_contacts(client):
    headers_a, _, _ = _signup(client, "+22892000024")
    _, user_id_b, _ = _signup(client, "+22892000025")
    group = client.post("/api/v1/groups", json={"name": "Fermé", "member_user_ids": []}, headers=headers_a).json()

    response = client.post(
        f"/api/v1/groups/{group['id']}/members", json={"user_ids": [user_id_b]}, headers=headers_a
    )
    assert response.status_code == 403


def test_adding_an_existing_member_is_idempotent(client):
    """Un double appui ne doit pas produire deux invitations, ni échouer sur
    une violation de contrainte que personne ne peut interpréter."""
    headers_a, _, _ = _signup(client, "+22892000026")
    headers_b, user_id_b, _ = _signup(client, "+22892000027")
    _add_contact(client, headers_a, "+22892000027", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Doublons", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()

    response = client.post(
        f"/api/v1/groups/{group['id']}/members", json={"user_ids": [user_id_b]}, headers=headers_a
    )
    assert response.status_code == 200
    assert len(client.get("/api/v1/groups/invitations", headers=headers_b).json()["items"]) == 1

    # Et une fois accepté, réinviter ne fait rien non plus.
    _rejoindre(client, headers_b)
    encore = client.post(
        f"/api/v1/groups/{group['id']}/members", json={"user_ids": [user_id_b]}, headers=headers_a
    )
    assert encore.status_code == 200
    assert encore.json()["group"]["member_count"] == 2


def test_owner_can_remove_a_member_and_the_member_loses_access(client):
    headers_a, _, _ = _signup(client, "+22892000028")
    headers_b, user_id_b, _ = _signup(client, "+22892000029")
    _add_contact(client, headers_a, "+22892000029", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Ménage", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    removed = client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_a)
    assert removed.status_code == 200
    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers_b).status_code == 403


def test_a_plain_member_cannot_remove_someone_else(client):
    headers_a, user_id_a, _ = _signup(client, "+22892000030")
    headers_b, user_id_b, _ = _signup(client, "+22892000031")
    _add_contact(client, headers_a, "+22892000031", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Anti-sabotage", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    response = client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_a}", headers=headers_b)
    assert response.status_code == 403


def test_a_plain_member_can_leave_the_group(client):
    headers_a, _, _ = _signup(client, "+22892000032")
    headers_b, user_id_b, _ = _signup(client, "+22892000033")
    _add_contact(client, headers_a, "+22892000033", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Sortie libre", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    left = client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_b)
    assert left.status_code == 200
    assert client.get("/api/v1/groups", headers=headers_b).json()["items"] == []


def test_removed_member_is_notified_over_websocket(client):
    headers_a, _, _ = _signup(client, "+22892000034")
    headers_b, user_id_b, token_b = _signup(client, "+22892000035")
    _add_contact(client, headers_a, "+22892000035", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Notification", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    # Sans cette acceptation, B n'est pas membre : le retrait répond 404,
    # aucun événement ne part, et `receive_json()` attend indéfiniment — le
    # test ne tombe pas, il fige toute la suite.
    _rejoindre(client, headers_b)

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_a)
        event = ws.receive_json()
        assert event["type"] == "group:member:removed"
        assert event["user_id"] == user_id_b
        assert event["group_id"] == group["id"]


def test_removing_someone_who_is_not_a_member_is_404(client):
    headers_a, _, _ = _signup(client, "+22892000036")
    _, user_id_b, _ = _signup(client, "+22892000037")
    group = client.post("/api/v1/groups", json={"name": "Vide", "member_user_ids": []}, headers=headers_a).json()

    response = client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_a)
    assert response.status_code == 404


# ─── Administration du groupe (nom, photo, admins, lien) ─────────────────────

def _make_group(client, headers, name, members):
    """Groupe prêt à l'emploi : contacts ajoutés, groupe créé, invitations
    ACCEPTÉES. `members` est une liste de (téléphone, user_id).

    L'acceptation se fait directement en base, et c'est délibéré. Depuis que
    Pokou invite au lieu d'ajouter, un groupe naît avec son seul créateur ;
    or ces tests portent sur le comportement des groupes — renommer,
    diffuser, administrer, quitter — et non sur le flux d'invitation, qui a
    son propre fichier (`test_group_invitations.py`).

    Passer par les routes demanderait ici les en-têtes de chaque invité, que
    ce helper n'a pas : il ne connaît que des numéros et des identifiants.
    Le raccourci par le service garde les tests lisibles et concentre le flux
    d'invitation là où il est vraiment vérifié.
    """
    for phone, _ in members:
        _add_contact(client, headers, phone, phone)
    created = client.post(
        "/api/v1/groups",
        json={"name": name, "member_user_ids": [user_id for _, user_id in members]},
        headers=headers,
    )
    assert created.status_code == 200, created.text
    groupe = created.json()

    with TestingSessionLocal() as db:
        for _, user_id in members:
            invitation = (
                db.query(GroupInvitation)
                .filter(
                    GroupInvitation.group_id == groupe["id"],
                    GroupInvitation.user_id == user_id,
                    GroupInvitation.status == GroupInvitationStatus.PENDING,
                )
                .first()
            )
            if invitation is not None:
                group_invitation_service.accepter(db, invitation)
        db.commit()

    # `member_count` est calculé à la création : il dirait encore 1.
    return client.get(f"/api/v1/groups/{groupe['id']}", headers=headers).json()


def test_owner_can_rename_the_group(client):
    headers_a, _, _ = _signup(client, "+22892200001")
    _, user_id_b, token_b = _signup(client, "+22892200002")
    group = _make_group(client, headers_a, "Nom initial", [("+22892200002", user_id_b)])

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        renamed = client.patch(
            f"/api/v1/groups/{group['id']}", json={"name": "Dépôt Adidogomé"}, headers=headers_a
        )
        assert renamed.status_code == 200, renamed.text
        assert renamed.json()["name"] == "Dépôt Adidogomé"

        # Diffusé : le nom s'affiche dans la liste de chaque membre, il ne
        # peut pas rester périmé jusqu'au prochain rechargement.
        event = ws.receive_json()
        assert event["type"] == "group:updated"
        assert event["group"]["name"] == "Dépôt Adidogomé"


def test_a_plain_member_cannot_rename_the_group(client):
    headers_a, _, _ = _signup(client, "+22892200003")
    headers_b, user_id_b, _ = _signup(client, "+22892200004")
    group = _make_group(client, headers_a, "Chantier", [("+22892200004", user_id_b)])

    response = client.patch(f"/api/v1/groups/{group['id']}", json={"name": "Détourné"}, headers=headers_b)
    assert response.status_code == 403
    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers_b).json()["name"] == "Chantier"


def test_an_empty_name_is_rejected(client):
    headers_a, _, _ = _signup(client, "+22892200005")
    _, user_id_b, _ = _signup(client, "+22892200006")
    group = _make_group(client, headers_a, "Chantier", [("+22892200006", user_id_b)])

    response = client.patch(f"/api/v1/groups/{group['id']}", json={"name": "   "}, headers=headers_a)
    assert response.status_code == 400


def test_group_photo_can_be_set_and_removed(client):
    headers_a, _, _ = _signup(client, "+22892200007")
    _, user_id_b, _ = _signup(client, "+22892200008")
    group = _make_group(client, headers_a, "Avec photo", [("+22892200008", user_id_b)])

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("logo.jpg", b"fake-jpeg", "image/jpeg")},
        headers=headers_a,
    ).json()

    with_photo = client.patch(
        f"/api/v1/groups/{group['id']}", json={"avatar_media_id": uploaded["id"]}, headers=headers_a
    )
    assert with_photo.status_code == 200
    assert with_photo.json()["avatar_media_id"] == uploaded["id"]

    cleared = client.patch(f"/api/v1/groups/{group['id']}", json={"clear_avatar": True}, headers=headers_a)
    assert cleared.json()["avatar_media_id"] is None


def test_cannot_attach_someone_elses_image_to_a_group(client):
    """La photo devient visible par tout le groupe : on ne doit pas pouvoir y
    rattacher la pièce jointe d'un autre en devinant son identifiant."""
    headers_a, _, _ = _signup(client, "+22892200009")
    headers_b, user_id_b, _ = _signup(client, "+22892200010")
    group = _make_group(client, headers_a, "Chantier", [("+22892200010", user_id_b)])

    someone_elses = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("prive.jpg", b"fake-jpeg", "image/jpeg")},
        headers=headers_b,
    ).json()

    response = client.patch(
        f"/api/v1/groups/{group['id']}", json={"avatar_media_id": someone_elses["id"]}, headers=headers_a
    )
    assert response.status_code == 403


def test_owner_promotes_a_member_to_admin_who_can_then_rename(client):
    headers_a, _, _ = _signup(client, "+22892200011")
    headers_b, user_id_b, _ = _signup(client, "+22892200012")
    group = _make_group(client, headers_a, "Chantier", [("+22892200012", user_id_b)])

    promoted = client.put(
        f"/api/v1/groups/{group['id']}/members/{user_id_b}/role",
        json={"role": "ADMIN"},
        headers=headers_a,
    )
    assert promoted.status_code == 200, promoted.text
    assert promoted.json()["role"] == "ADMIN"

    # Le rôle sert vraiment à quelque chose.
    renamed = client.patch(f"/api/v1/groups/{group['id']}", json={"name": "Renommé par admin"}, headers=headers_b)
    assert renamed.status_code == 200

    mine = client.get(f"/api/v1/groups/{group['id']}", headers=headers_b).json()
    assert mine["my_role"] == "ADMIN"
    assert mine["can_manage"] is True


def test_an_admin_cannot_appoint_other_admins(client):
    """Sinon un admin pourrait s'entourer d'admins et déposséder le groupe."""
    headers_a, _, _ = _signup(client, "+22892200013")
    headers_b, user_id_b, _ = _signup(client, "+22892200014")
    _, user_id_c, _ = _signup(client, "+22892200015")
    group = _make_group(
        client, headers_a, "Chantier", [("+22892200014", user_id_b), ("+22892200015", user_id_c)]
    )
    client.put(
        f"/api/v1/groups/{group['id']}/members/{user_id_b}/role", json={"role": "ADMIN"}, headers=headers_a
    )

    response = client.put(
        f"/api/v1/groups/{group['id']}/members/{user_id_c}/role", json={"role": "ADMIN"}, headers=headers_b
    )
    assert response.status_code == 403


def test_owner_cannot_change_their_own_role(client):
    headers_a, user_id_a, _ = _signup(client, "+22892200016")
    _, user_id_b, _ = _signup(client, "+22892200017")
    group = _make_group(client, headers_a, "Chantier", [("+22892200017", user_id_b)])

    # Se rétrograder laisserait le groupe sans personne pour nommer des admins.
    response = client.put(
        f"/api/v1/groups/{group['id']}/members/{user_id_a}/role", json={"role": "MEMBER"}, headers=headers_a
    )
    assert response.status_code == 400


def test_admin_can_remove_a_member_but_not_the_owner(client):
    headers_a, user_id_a, _ = _signup(client, "+22892200018")
    headers_b, user_id_b, _ = _signup(client, "+22892200019")
    _, user_id_c, _ = _signup(client, "+22892200020")
    group = _make_group(
        client, headers_a, "Chantier", [("+22892200019", user_id_b), ("+22892200020", user_id_c)]
    )
    client.put(
        f"/api/v1/groups/{group['id']}/members/{user_id_b}/role", json={"role": "ADMIN"}, headers=headers_a
    )

    assert client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_c}", headers=headers_b).status_code == 200
    # Mais pas le créateur : il ne resterait personne pour nommer des admins.
    assert client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_a}", headers=headers_b).status_code == 403


def test_invite_link_lets_a_stranger_join_without_being_a_contact(client):
    headers_a, _, _ = _signup(client, "+22892200021")
    _, user_id_b, _ = _signup(client, "+22892200022")
    headers_c, user_id_c, _ = _signup(client, "+22892200023")
    group = _make_group(client, headers_a, "Ouvert", [("+22892200022", user_id_b)])

    created = client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a)
    assert created.status_code == 200, created.text
    code = created.json()["invite_code"]
    assert code

    # C ne connaît personne du groupe — c'est tout l'intérêt du lien.
    preview = client.get(f"/api/v1/groups/invite/{code}", headers=headers_c).json()
    assert preview["name"] == "Ouvert"
    assert preview["member_count"] == 2
    assert preview["already_member"] is False
    # On ne révèle pas QUI est dans le groupe à quelqu'un qui n'y est pas.
    assert "members" not in preview

    joined = client.post(f"/api/v1/groups/invite/{code}/join", headers=headers_c)
    assert joined.status_code == 200
    assert joined.json()["member_count"] == 3
    assert joined.json()["my_role"] == "MEMBER"
    assert any(g["id"] == group["id"] for g in client.get("/api/v1/groups", headers=headers_c).json()["items"])


def test_joining_twice_is_not_an_error(client):
    headers_a, _, _ = _signup(client, "+22892200024")
    _, user_id_b, _ = _signup(client, "+22892200025")
    headers_c, _, _ = _signup(client, "+22892200026")
    group = _make_group(client, headers_a, "Ouvert", [("+22892200025", user_id_b)])
    code = client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a).json()["invite_code"]

    client.post(f"/api/v1/groups/invite/{code}/join", headers=headers_c)
    second = client.post(f"/api/v1/groups/invite/{code}/join", headers=headers_c)

    assert second.status_code == 200
    assert second.json()["member_count"] == 3  # pas de doublon
    assert client.get(f"/api/v1/groups/invite/{code}", headers=headers_c).json()["already_member"] is True


def test_regenerating_the_link_invalidates_the_previous_one(client):
    """C'est le seul moyen de révoquer un lien déjà diffusé."""
    headers_a, _, _ = _signup(client, "+22892200027")
    _, user_id_b, _ = _signup(client, "+22892200028")
    headers_c, _, _ = _signup(client, "+22892200029")
    group = _make_group(client, headers_a, "Ouvert", [("+22892200028", user_id_b)])

    old_code = client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a).json()["invite_code"]
    new_code = client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a).json()["invite_code"]
    assert new_code != old_code

    assert client.post(f"/api/v1/groups/invite/{old_code}/join", headers=headers_c).status_code == 404
    assert client.post(f"/api/v1/groups/invite/{new_code}/join", headers=headers_c).status_code == 200


def test_revoked_link_no_longer_works(client):
    headers_a, _, _ = _signup(client, "+22892200030")
    _, user_id_b, _ = _signup(client, "+22892200031")
    headers_c, _, _ = _signup(client, "+22892200032")
    group = _make_group(client, headers_a, "Ouvert", [("+22892200031", user_id_b)])
    code = client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a).json()["invite_code"]

    assert client.delete(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a).status_code == 200
    assert client.post(f"/api/v1/groups/invite/{code}/join", headers=headers_c).status_code == 404


def test_a_plain_member_cannot_create_or_see_the_invite_link(client):
    """Un membre simple ne doit pas pouvoir faire entrer qui il veut."""
    headers_a, _, _ = _signup(client, "+22892200033")
    headers_b, user_id_b, _ = _signup(client, "+22892200034")
    group = _make_group(client, headers_a, "Fermé", [("+22892200034", user_id_b)])

    assert client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_b).status_code == 403

    client.post(f"/api/v1/groups/{group['id']}/invite-link", headers=headers_a)
    # Le lien existe, mais reste caché du membre simple.
    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers_b).json()["invite_code"] is None
    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers_a).json()["invite_code"] is not None


def test_unknown_invite_code_is_404(client):
    headers, _, _ = _signup(client, "+22892200035")
    assert client.get("/api/v1/groups/invite/nexistepas", headers=headers).status_code == 404
    assert client.post("/api/v1/groups/invite/nexistepas/join", headers=headers).status_code == 404


# ─── Réponses citées ──────────────────────────────────────────────────────────

@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : l'aperçu du message cité voyage dans le chiffré, le serveur ne le compose plus")
def test_a_reply_carries_a_compact_preview_of_the_quoted_message(client):
    headers_a, user_id_a, _ = _signup(client, "+228892200101")
    headers_b, user_id_b, _ = _signup(client, "+228892200102")
    group = _make_group(client, headers_a, "Citations", [("+228892200102", user_id_b)])
    messages = f"/api/v1/groups/{group['id']}/messages"

    long_text = "La livraison de ciment " * 20
    quoted = client.post(messages, json={"content": long_text}, headers=headers_a).json()

    reply = client.post(
        messages, json={"content": "d'accord", "reply_to_id": quoted["id"]}, headers=headers_b
    )
    assert reply.status_code == 200, reply.text
    preview = reply.json()["reply_to"]
    assert preview["id"] == quoted["id"]
    assert preview["sender_id"] == user_id_a
    assert preview["sender_name"]
    assert preview["message_type"] == "TEXT"
    # Tronqué : reconnaître la bulle d'origine, pas retransporter le message.
    assert len(preview["content"]) < len(long_text)

    # L'aperçu suit dans l'historique, pas seulement dans la réponse à l'envoi :
    # la bulle citée est souvent hors de la page chargée par le client.
    listed = client.get(messages, headers=headers_a).json()["items"]
    assert listed[-1]["reply_to"]["id"] == quoted["id"]
    assert listed[0]["reply_to"] is None


def test_cannot_quote_a_message_from_another_group(client):
    """Sinon l'aperçu (auteur + début du texte) d'une conversation ferait
    surface dans une autre."""
    headers_a, _, _ = _signup(client, "+228892200103")
    _, user_id_b, _ = _signup(client, "+228892200104")
    here = _make_group(client, headers_a, "Ici", [("+228892200104", user_id_b)])
    elsewhere = _make_group(client, headers_a, "Ailleurs", [])

    other_message = client.post(
        f"/api/v1/groups/{elsewhere['id']}/messages", json={"content": "affaire privée"}, headers=headers_a
    ).json()

    response = client.post(
        f"/api/v1/groups/{here['id']}/messages",
        json={"content": "regardez ça", "reply_to_id": other_message["id"]},
        headers=headers_a,
    )
    assert response.status_code == 404


# ─── Réactions ────────────────────────────────────────────────────────────────

def test_reacting_again_replaces_the_reaction_instead_of_adding_one(client):
    headers_a, _, _ = _signup(client, "+228892200105")
    headers_b, user_id_b, _ = _signup(client, "+228892200106")
    group = _make_group(client, headers_a, "Réactions", [("+228892200106", user_id_b)])
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "le camion est arrivé"}, headers=headers_a
    ).json()
    reaction_url = f"/api/v1/groups/{group['id']}/messages/{message['id']}/reaction"

    first = client.put(reaction_url, json={"emoji": "👍"}, headers=headers_b)
    assert first.status_code == 200, first.text
    assert first.json()["reactions"] == [
        {"emoji": "👍", "count": 1, "user_ids": [user_id_b], "mine": True}
    ]

    second = client.put(reaction_url, json={"emoji": "❤️"}, headers=headers_b)
    assert second.status_code == 200
    # Une seule réaction par personne : la seconde remplace, elle ne cumule pas.
    assert second.json()["reactions"] == [
        {"emoji": "❤️", "count": 1, "user_ids": [user_id_b], "mine": True}
    ]

    # `mine` est relatif à celui qui lit, pas à celui qui a réagi.
    listed = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_a).json()["items"]
    assert listed[0]["reactions"][0]["mine"] is False
    assert listed[0]["reactions"][0]["user_ids"] == [user_id_b]

    removed = client.delete(reaction_url, headers=headers_b)
    assert removed.status_code == 200
    assert removed.json()["reactions"] == []
    # Idempotent : le geste est un basculement, deux appuis ne font pas d'erreur.
    assert client.delete(reaction_url, headers=headers_b).status_code == 200


def test_a_reaction_is_broadcast_to_the_other_members(client):
    headers_a, _, token_a = _signup(client, "+228892200107")
    headers_b, user_id_b, _ = _signup(client, "+228892200108")
    group = _make_group(client, headers_a, "Live", [("+228892200108", user_id_b)])
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "ping"}, headers=headers_a
    ).json()

    with client.websocket_connect(f"/api/v1/ws?token={token_a}") as ws:
        client.put(
            f"/api/v1/groups/{group['id']}/messages/{message['id']}/reaction",
            json={"emoji": "👍"},
            headers=headers_b,
        )
        event = ws.receive_json()

    assert event["type"] == "group:message:reaction"
    assert event["message_id"] == message["id"]
    assert event["reactions"][0]["user_ids"] == [user_id_b]
    # Le même objet part vers N membres : il ne peut pas porter un booléen
    # propre à chacun, le client déduit « la mienne » de `user_ids`.
    assert "mine" not in event["reactions"][0]


# ─── Modification ─────────────────────────────────────────────────────────────

@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : une correction part chiffrée : le serveur ne renvoie plus de texte")
def test_only_the_author_can_edit_a_group_message(client):
    headers_a, _, _ = _signup(client, "+228892200109")
    headers_b, user_id_b, token_b = _signup(client, "+228892200110")
    group = _make_group(client, headers_a, "Corrections", [("+228892200110", user_id_b)])
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "rendez-vous à 14h"}, headers=headers_a
    ).json()
    message_url = f"/api/v1/groups/{group['id']}/messages/{message['id']}"

    # 403 et non 404 : le message est visible de tout le groupe, en cacher
    # l'existence à un membre n'aurait aucun sens.
    assert client.patch(message_url, json={"content": "rendez-vous à 6h"}, headers=headers_b).status_code == 403

    with client.websocket_connect(f"/api/v1/ws?token={token_b}") as ws:
        edited = client.patch(message_url, json={"content": "rendez-vous à 15h"}, headers=headers_a)
        assert edited.status_code == 200, edited.text
        assert edited.json()["content"] == "rendez-vous à 15h"
        assert edited.json()["edited_at"] is not None

        event = ws.receive_json()
        assert event["type"] == "group:message:edited"
        assert event["message"]["content"] == "rendez-vous à 15h"

    listed = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_b).json()["items"]
    assert listed[0]["content"] == "rendez-vous à 15h"


def test_a_group_message_can_no_longer_be_edited_after_the_window(client):
    """Passé le délai, le message a été lu par les autres : le réécrire
    réécrirait leur conversation."""
    headers_a, _, _ = _signup(client, "+228892200111")
    group = _make_group(client, headers_a, "Trop tard", [])
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "faute de frappe"}, headers=headers_a
    ).json()

    with TestingSessionLocal() as session:
        row = session.query(GroupMessage).filter(GroupMessage.id == message["id"]).first()
        row.created_at = datetime.utcnow() - (MESSAGE_EDIT_WINDOW + timedelta(minutes=1))
        session.commit()

    response = client.patch(
        f"/api/v1/groups/{group['id']}/messages/{message['id']}",
        json={"content": "corrigé"},
        headers=headers_a,
    )
    assert response.status_code == 409


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : un média de groupe part chiffré : contrat à réécrire")
def test_a_media_group_message_cannot_be_edited(client):
    headers_a, _, _ = _signup(client, "+228892200112")
    group = _make_group(client, headers_a, "Pièces jointes", [])
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "AUDIO"},
        files={"file": ("note.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=headers_a,
    ).json()
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "AUDIO", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    ).json()

    # Remplacer une pièce jointe déjà téléchargée chez les autres n'est pas
    # une modification, c'est un autre message.
    response = client.patch(
        f"/api/v1/groups/{group['id']}/messages/{message['id']}",
        json={"content": "légende"},
        headers=headers_a,
    )
    assert response.status_code == 400


def test_a_non_member_can_neither_react_nor_edit(client):
    headers_a, _, _ = _signup(client, "+228892200113")
    headers_b, _, _ = _signup(client, "+228892200114")
    group = _make_group(client, headers_a, "Privé", [])
    message = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "entre nous"}, headers=headers_a
    ).json()

    assert client.put(
        f"/api/v1/groups/{group['id']}/messages/{message['id']}/reaction",
        json={"emoji": "👍"},
        headers=headers_b,
    ).status_code == 403
    assert client.patch(
        f"/api/v1/groups/{group['id']}/messages/{message['id']}",
        json={"content": "détourné"},
        headers=headers_b,
    ).status_code == 403


# ─── Mentions ─────────────────────────────────────────────────────────────────

@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les mentions voyagent dans le chiffré, le serveur ne les connaît plus")
def test_mentioning_a_non_member_is_ignored_without_failing_the_send(client):
    """Le texte est déjà écrit et « @Charlie » y reste lisible : refuser tout
    le message parce que Charlie n'est pas dans le groupe ferait perdre le
    message pour un détail d'affichage."""
    headers_a, _, _ = _signup(client, "+228892200115")
    _, user_id_b, _ = _signup(client, "+228892200116")
    _, user_id_c, _ = _signup(client, "+228892200117")
    group = _make_group(client, headers_a, "Mentions", [("+228892200116", user_id_b)])

    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"content": "@Bob @Charlie qui livre ?", "mention_user_ids": [user_id_b, user_id_c]},
        headers=headers_a,
    )
    assert sent.status_code == 200, sent.text
    assert [mention["user_id"] for mention in sent.json()["mentions"]] == [user_id_b]
    assert sent.json()["mentions"][0]["display_name"]


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les mentions voyagent dans le chiffré, le serveur ne les connaît plus")
def test_the_mentions_feed_only_returns_my_own_mentions(client):
    headers_a, _, _ = _signup(client, "+228892200118")
    headers_b, user_id_b, _ = _signup(client, "+228892200119")
    headers_c, user_id_c, _ = _signup(client, "+228892200120")
    group = _make_group(
        client, headers_a, "Chantier", [("+228892200119", user_id_b), ("+228892200120", user_id_c)]
    )
    messages = f"/api/v1/groups/{group['id']}/messages"

    client.post(messages, json={"content": "@B tu passes ?", "mention_user_ids": [user_id_b]}, headers=headers_a)
    client.post(messages, json={"content": "@C et toi ?", "mention_user_ids": [user_id_c]}, headers=headers_a)
    client.post(messages, json={"content": "@B rappel", "mention_user_ids": [user_id_b]}, headers=headers_a)
    client.post(messages, json={"content": "sans personne"}, headers=headers_a)

    mine = client.get("/api/v1/groups/mentions", headers=headers_b)
    assert mine.status_code == 200, mine.text
    # Du plus récent au plus ancien, et uniquement les miennes.
    assert [item["content"] for item in mine.json()["items"]] == ["@B rappel", "@B tu passes ?"]
    assert all(item["group_name"] == "Chantier" for item in mine.json()["items"])

    assert [item["content"] for item in client.get("/api/v1/groups/mentions", headers=headers_c).json()["items"]] == [
        "@C et toi ?"
    ]
    # On ne se mentionne pas soi-même : l'auteur n'a rien qui l'attende.
    assert client.get("/api/v1/groups/mentions", headers=headers_a).json()["items"] == []


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les mentions voyagent dans le chiffré, le serveur ne les connaît plus")
def test_leaving_a_group_takes_its_mentions_out_of_my_feed(client):
    headers_a, _, _ = _signup(client, "+228892200121")
    headers_b, user_id_b, _ = _signup(client, "+228892200122")
    group = _make_group(client, headers_a, "Départ", [("+228892200122", user_id_b)])
    client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"content": "@B tu réponds ?", "mention_user_ids": [user_id_b]},
        headers=headers_a,
    )
    assert client.get("/api/v1/groups/mentions", headers=headers_b).json()["total"] == 1

    client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_b)

    # La ligne de mention survit au départ (elle est liée au message) — son
    # contenu, non.
    assert client.get("/api/v1/groups/mentions", headers=headers_b).json()["items"] == []


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les mentions voyagent dans le chiffré, le serveur ne les connaît plus")
def test_a_mentioned_member_gets_a_push_with_its_own_wording(client):
    """Être cité, c'est l'événement pour lequel on accepte d'être dérangé
    alors qu'on ne suivait pas la discussion : le push doit le dire, pas
    servir un extrait du fil comme un message ordinaire."""
    headers_a, _, _ = _signup(client, "+228892200123")
    _, user_id_b, _ = _signup(client, "+228892200124")
    _, user_id_c, _ = _signup(client, "+228892200125")
    group = _make_group(
        client, headers_a, "Livraisons", [("+228892200124", user_id_b), ("+228892200125", user_id_c)]
    )

    # Personne n'a le WebSocket ouvert : c'est exactement le cas où une
    # mention doit quand même arriver.
    with patch("app.api.v1.messaging.groups.send_push") as mock_push:
        sent = client.post(
            f"/api/v1/groups/{group['id']}/messages",
            json={"content": "@B le camion part", "mention_user_ids": [user_id_b]},
            headers=headers_a,
        )
    assert sent.status_code == 200, sent.text

    bodies = {call.args[1]: call.kwargs["body"] for call in mock_push.call_args_list}
    assert set(bodies) == {user_id_b, user_id_c}
    assert "vous a mentionné" in bodies[user_id_b]
    assert "vous a mentionné" not in bodies[user_id_c]


# ─── Réglages du groupe ───────────────────────────────────────────────────────

def test_admins_only_messages_blocks_a_plain_member(client):
    headers_a, _, _ = _signup(client, "+228892200126")
    headers_b, user_id_b, _ = _signup(client, "+228892200127")
    group = _make_group(client, headers_a, "Verrouillable", [("+228892200127", user_id_b)])
    messages = f"/api/v1/groups/{group['id']}/messages"
    settings_url = f"/api/v1/groups/{group['id']}"

    assert client.post(messages, json={"content": "avant"}, headers=headers_b).status_code == 200

    locked = client.patch(settings_url, json={"admins_only_messages": True}, headers=headers_a)
    assert locked.status_code == 200, locked.text
    assert locked.json()["admins_only_messages"] is True

    refused = client.post(messages, json={"content": "après"}, headers=headers_b)
    assert refused.status_code == 403
    # Le libellé parle du groupe, pas d'annonces : ce verrou-ci n'a rien à
    # voir avec une communauté.
    assert "annonces" not in refused.json()["detail"]
    assert client.post(messages, json={"content": "moi je peux"}, headers=headers_a).status_code == 200
    # Il lit toujours, il n'écrit plus.
    assert client.get(messages, headers=headers_b).status_code == 200

    # Réglage collectif : un membre simple ne peut pas se déverrouiller seul.
    assert client.patch(settings_url, json={"admins_only_messages": False}, headers=headers_b).status_code == 403
    assert client.patch(settings_url, json={"admins_only_messages": False}, headers=headers_a).status_code == 200
    assert client.post(messages, json={"content": "de nouveau"}, headers=headers_b).status_code == 200


def test_the_disappearing_delay_is_frozen_at_send_time(client):
    headers_a, _, _ = _signup(client, "+228892200128")
    group = _make_group(client, headers_a, "Éphémère", [])
    messages = f"/api/v1/groups/{group['id']}/messages"
    settings_url = f"/api/v1/groups/{group['id']}"

    without = client.post(messages, json={"content": "sans échéance"}, headers=headers_a).json()
    assert without["expires_at"] is None

    enabled = client.patch(settings_url, json={"disappearing_seconds": 86400}, headers=headers_a)
    assert enabled.status_code == 200, enabled.text
    assert enabled.json()["disappearing_seconds"] == 86400

    ephemeral = client.post(messages, json={"content": "24 heures"}, headers=headers_a).json()
    lifetime = datetime.fromisoformat(ephemeral["expires_at"]) - datetime.fromisoformat(
        ephemeral["created_at"]
    )
    assert 86390 <= lifetime.total_seconds() <= 86410

    # Couper le réglage ne réécrit pas le passé : le message déjà envoyé garde
    # son échéance, celui d'avant n'en gagne pas une.
    disabled = client.patch(settings_url, json={"disappearing_seconds": None}, headers=headers_a)
    assert disabled.status_code == 200
    assert disabled.json()["disappearing_seconds"] is None
    listed = {item["content"]: item["expires_at"] for item in client.get(messages, headers=headers_a).json()["items"]}
    assert listed["sans échéance"] is None
    assert listed["24 heures"] == ephemeral["expires_at"]

    # Durée hors des choix proposés : le client n'a pas à inventer une durée.
    assert client.patch(settings_url, json={"disappearing_seconds": 42}, headers=headers_a).status_code == 400


def test_an_expired_group_message_disappears_from_the_history(client):
    headers_a, _, _ = _signup(client, "+228892200129")
    headers_b, user_id_b, _ = _signup(client, "+228892200130")
    group = _make_group(client, headers_a, "Éphémère", [("+228892200130", user_id_b)])
    messages = f"/api/v1/groups/{group['id']}/messages"
    client.patch(f"/api/v1/groups/{group['id']}", json={"disappearing_seconds": 86400}, headers=headers_a)

    doomed = client.post(messages, json={"content": "à effacer"}, headers=headers_a).json()
    client.post(
        messages, json={"content": "je réponds", "reply_to_id": doomed["id"]}, headers=headers_b
    )

    with TestingSessionLocal() as session:
        row = session.query(GroupMessage).filter(GroupMessage.id == doomed["id"]).first()
        row.expires_at = datetime.utcnow() - timedelta(seconds=1)
        session.commit()

    items = client.get(messages, headers=headers_b).json()["items"]
    assert [item["content"] for item in items] == ["je réponds"]
    # L'aperçu cité s'efface avec le message : sinon une réponse rendrait un
    # message éphémère lisible pour toujours.
    assert items[0]["reply_to_id"] == doomed["id"]
    assert items[0]["reply_to"] is None


def test_the_announcement_group_stays_admin_only(client):
    """Non-régression : `admins_only_messages` s'AJOUTE au verrou des
    annonces, il ne le remplace pas — un groupe d'annonces reste réservé aux
    administrateurs alors que le réglage y est à faux."""
    headers_a, _, _ = _signup(client, "+228892200131")
    headers_b, _, _ = _signup(client, "+228892200132")
    community = client.post("/api/v1/communities", json={"name": "Marché"}, headers=headers_a).json()
    announcements = next(group for group in community["groups"] if group["is_announcement"])
    seen = client.get(f"/api/v1/groups/{announcements['id']}", headers=headers_a).json()
    assert seen["is_announcement"] is True
    assert seen["admins_only_messages"] is False

    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)

    messages = f"/api/v1/groups/{announcements['id']}/messages"
    posted = client.post(messages, json={"content": "ouverture à 6h demain"}, headers=headers_a)
    assert posted.status_code == 200, posted.text

    refused = client.post(messages, json={"content": "moi aussi je parle"}, headers=headers_b)
    assert refused.status_code == 403
    assert "annonces" in refused.json()["detail"]
    assert client.get(messages, headers=headers_b).status_code == 200

    # Mais réagir reste ouvert au membre simple : une réaction n'occupe pas le
    # fil, c'est le seul retour possible dans des annonces.
    reacted = client.put(
        f"{messages}/{posted.json()['id']}/reaction", json={"emoji": "👍"}, headers=headers_b
    )
    assert reacted.status_code == 200, reacted.text


# ─── Contenus riches : payload/poll survivent au rechargement ────────────────
#
# Même non-régression que test_pokou_messaging.py : app/routes/polls.py sait
# déjà renvoyer `payload`/`poll` dans la réponse d'envoi, mais
# GET /groups/{id}/messages passait par _serialize_message() de CE module, qui
# ne les renvoyait pas — un sondage de groupe perdait ses barres de vote au
# premier rechargement de la conversation.

@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les sondages de groupe sont fermés tant qu'ils ne sont pas chiffrés (409)")
def test_group_message_history_carries_poll_payload_after_reload(client):
    headers_a, user_id_a, _ = _signup(client, "+22892200200")
    _, user_id_b, _ = _signup(client, "+22892200201")
    group = _make_group(client, headers_a, "Sondage", [("+22892200201", user_id_b)])

    created = client.post(
        "/api/v1/polls",
        json={
            "kind": "group",
            "target_id": group["id"],
            "question": "On mange où ?",
            "options": ["Chez Fatou", "À la maison"],
        },
        headers=headers_a,
    )
    assert created.status_code == 200, created.text
    poll_id = created.json()["poll"]["id"]
    option_id = created.json()["poll"]["options"][0]["id"]
    client.post(f"/api/v1/polls/{poll_id}/vote", json={"option_ids": [option_id]}, headers=headers_a)

    items = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_a).json()["items"]
    bubble = items[-1]
    assert bubble["message_type"] == "POLL"
    assert bubble["poll"]["question"] == "On mange où ?"
    assert bubble["poll"]["options"][0]["vote_count"] == 1
    assert bubble["poll"]["options"][0]["mine"] is True


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les positions de groupe sont fermées tant qu'elles ne sont pas chiffrées (409)")
def test_group_message_history_carries_location_payload_after_reload(client):
    headers_a, user_id_a, _ = _signup(client, "+22892200202")
    _, user_id_b, _ = _signup(client, "+22892200203")
    group = _make_group(client, headers_a, "Position", [("+22892200203", user_id_b)])

    client.post(
        "/api/v1/polls/location",
        json={
            "kind": "group",
            "target_id": group["id"],
            "latitude": 6.1319,
            "longitude": 1.2228,
            "label": "Marché",
        },
        headers=headers_a,
    )

    items = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers_a).json()["items"]
    bubble = items[-1]
    assert bubble["message_type"] == "LOCATION"
    assert bubble["payload"]["latitude"] == 6.1319
    assert bubble["payload"]["label"] == "Marché"


# ─── Accès média envoyé dans un groupe (api/app/routes/media.py) ─────────────

@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : un média de groupe part chiffré : contrat à réécrire")
def test_other_group_members_can_download_an_image_sent_in_the_group(client):
    """Le bug signalé : sans le rattachement GroupMessage dans
    media.py::_can_access, seul l'auteur de l'envoi pouvait revoir le
    fichier — pour tout autre membre, GET /media/{id} rendait 404 et
    l'image s'affichait cassée dans l'app."""
    headers_a, user_id_a, _ = _signup(client, "+22892200210")
    headers_b, user_id_b, _ = _signup(client, "+22892200211")
    _add_contact(client, headers_a, "+22892200211", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Photos", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)

    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"bytes-de-la-photo-du-groupe", "image/jpeg")},
        headers=headers_a,
    ).json()
    client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )

    # B n'a rien uploadé, n'est ni le premier ni le seul membre — c'est
    # exactement le cas qui échouait avant le correctif.
    response = client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b)
    assert response.status_code == 200
    assert response.content == b"bytes-de-la-photo-du-groupe"


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : un média de groupe part chiffré : contrat à réécrire")
def test_someone_who_left_the_group_loses_access_to_its_media(client):
    headers_a, user_id_a, _ = _signup(client, "+22892200212")
    headers_b, user_id_b, _ = _signup(client, "+22892200213")
    _add_contact(client, headers_a, "+22892200213", "Bob")
    group = client.post(
        "/api/v1/groups", json={"name": "Chantier", "member_user_ids": [user_id_b]}, headers=headers_a
    ).json()
    _rejoindre(client, headers_b)
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("plan.jpg", b"plan-du-chantier", "image/jpeg")},
        headers=headers_a,
    ).json()
    client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 200

    client.delete(f"/api/v1/groups/{group['id']}/members/{user_id_b}", headers=headers_a)
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_b).status_code == 404


def test_a_stranger_to_the_group_still_cannot_download_its_media(client):
    headers_a, _, _ = _signup(client, "+22892200214")
    headers_c, _, _ = _signup(client, "+22892200215")
    group = client.post("/api/v1/groups", json={"name": "Privé", "member_user_ids": []}, headers=headers_a).json()
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("secret.jpg", b"contenu-prive", "image/jpeg")},
        headers=headers_a,
    ).json()
    client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "IMAGE", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )
    assert client.get(f"/api/v1/media/{uploaded['id']}", headers=headers_c).status_code == 404


def test_the_group_photo_loads_for_its_members_and_for_nobody_else(client):
    """Même trou que les images envoyées dans un groupe, à l'étage au-dessus :
    sans branche dédiée dans media.py::_can_access, la photo du groupe ne se
    chargeait que pour l'admin qui l'avait téléversée. Les autres membres
    voyaient un cadre cassé — et l'API répondait 404 sur son propre avatar."""
    headers_admin, _, _ = _signup(client, "+22892000090")
    headers_member, member_id, _ = _signup(client, "+22892000091")
    headers_stranger, _, _ = _signup(client, "+22892000092")
    _add_contact(client, headers_admin, "+22892000091", "Membre")
    group = client.post(
        "/api/v1/groups",
        json={"name": "Dépôt Agoè", "member_user_ids": [member_id]},
        headers=headers_admin,
    ).json()
    # Membre pour de bon : ce test porte sur l'accès à la photo D'UN MEMBRE,
    # et un invité qui n'a pas accepté n'en est pas un.
    _rejoindre(client, headers_member)

    media_id = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("logo.jpg", b"des-octets", "image/jpeg")},
        headers=headers_admin,
    ).json()["id"]
    updated = client.patch(
        f"/api/v1/groups/{group['id']}",
        json={"avatar_media_id": media_id},
        headers=headers_admin,
    )
    assert updated.status_code == 200, updated.text

    # Un membre la voit.
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_member).status_code == 200
    # Un tiers, non : un groupe n'est pas public, contrairement à une chaîne.
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_stranger).status_code == 404


# ─── Stickers dans un groupe ──────────────────────────────────────────────────
#
# Même exception qu'en tête-à-tête, et pour la même raison : l'image d'un
# sticker appartient au pack, pas à celui qui l'envoie. Testée ICI AUSSI
# parce que `groups.py` porte sa propre copie du garde-fou : c'est
# exactement le genre d'endroit où une règle diverge en silence.


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les stickers de groupe partent chiffrés comme le reste")
def test_on_envoie_un_sticker_dans_un_groupe(client):
    from app.models import Sticker, StickerPack

    headers_auteur, _, _ = _signup(client, "+22892000190")
    headers_a, _, _ = _signup(client, "+22892000191")
    headers_b, user_id_b, _ = _signup(client, "+22892000192")
    _add_contact(client, headers_a, "+22892000192", "Bob")
    group = client.post(
        "/api/v1/groups",
        json={"name": "Dépôt", "member_user_ids": [user_id_b]},
        headers=headers_a,
    ).json()
    _rejoindre(client, headers_b)

    # L'image est téléversée par QUELQU'UN D'AUTRE — l'auteur du pack.
    uploaded = client.post(
        "/api/v1/media/upload",
        data={"message_type": "STICKER"},
        files={"file": ("chat.webp", b"octets-de-sticker", "image/webp")},
        headers=headers_auteur,
    ).json()
    db = TestingSessionLocal()
    pack = StickerPack(name="Officiel", slug="officiel", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    db.refresh(pack)
    db.add(Sticker(pack_id=pack.id, media_asset_id=uploaded["id"]))
    db.commit()
    db.close()

    envoi = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "STICKER", "media_asset_id": uploaded["id"]},
        headers=headers_a,
    )
    assert envoi.status_code == 200, envoi.text
    assert envoi.json()["message_type"] == "STICKER"


@pytest.mark.xfail(strict=True, reason="Contrat d'avant le chiffrement des groupes : les stickers de groupe partent chiffrés comme le reste")
def test_l_exception_sticker_ne_s_etend_pas_aux_autres_medias_en_groupe(client):
    # Le garde-fou : annoncer « STICKER » ne doit pas suffire à joindre
    # n'importe quel média deviné.
    headers_b, _, _ = _signup(client, "+22892000193")
    headers_a, _, _ = _signup(client, "+22892000194")
    headers_c, user_id_c, _ = _signup(client, "+22892000195")
    _add_contact(client, headers_a, "+22892000195", "Carl")
    group = client.post(
        "/api/v1/groups",
        json={"name": "Dépôt", "member_user_ids": [user_id_c]},
        headers=headers_a,
    ).json()
    _rejoindre(client, headers_c)

    photo_de_b = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"octets-de-bob", "image/jpeg")},
        headers=headers_b,
    ).json()

    refus = client.post(
        f"/api/v1/groups/{group['id']}/messages",
        json={"message_type": "STICKER", "media_asset_id": photo_de_b["id"]},
        headers=headers_a,
    )
    assert refus.status_code == 404
