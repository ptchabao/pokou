"""Pokou — communautés : contenant de groupes, avec un groupe d'annonces.

Ce qui est vérifié ici tient surtout à ce qui DISTINGUE une communauté d'un
dossier de groupes : le groupe d'annonces créé avec elle, réservé aux
administrateurs à l'écriture et ouvert à tous ses membres à la lecture.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_communities.db"

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


def _create_community(client, headers, name="Marché de Lomé", **extra):
    response = client.post("/api/v1/communities", json={"name": name, **extra}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _announcement_group(community):
    return next(group for group in community["groups"] if group["is_announcement"])


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


def _create_group(client, headers, name, member_phones_and_ids=()):
    for phone, _ in member_phones_and_ids:
        client.post("/api/v1/contacts", json={"phone": phone, "display_name": phone}, headers=headers)
    response = client.post(
        "/api/v1/groups",
        json={"name": name, "member_user_ids": [uid for _, uid in member_phones_and_ids]},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    _accepter_invitations(client, [uid for _, uid in member_phones_and_ids])
    return response.json()


# ─── Création ─────────────────────────────────────────────────────────────────

def test_creating_a_community_creates_its_announcement_group(client):
    """Les deux vont ensemble : sans annonces, une communauté n'aurait aucun
    moyen de s'adresser à tous ses membres — son seul intérêt propre."""
    headers, user_id = _signup(client, "+22898000001")

    community = _create_community(client, headers, "Marché de Lomé")

    assert community["name"] == "Marché de Lomé"
    assert community["my_role"] == "OWNER"
    assert community["can_manage"] is True
    assert community["member_count"] == 1
    announcements = _announcement_group(community)
    assert announcements["name"] == "Annonces"
    assert community["group_count"] == 1


def test_the_announcement_group_comes_first(client):
    headers, _ = _signup(client, "+22898000002")
    group = _create_group(client, headers, "Vendeurs")
    community = _create_community(client, headers, "Marché", group_ids=[group["id"]])

    # C'est le cœur de la communauté : il ne doit pas se perdre dans la liste.
    assert community["groups"][0]["is_announcement"] is True
    assert community["group_count"] == 2


def test_existing_group_can_be_attached_at_creation(client):
    headers, _ = _signup(client, "+22898000003")
    group = _create_group(client, headers, "Vendeurs")

    community = _create_community(client, headers, "Marché", group_ids=[group["id"]])

    names = {g["name"] for g in community["groups"]}
    assert names == {"Annonces", "Vendeurs"}


# ─── Annonces ─────────────────────────────────────────────────────────────────

def test_only_admins_can_post_in_the_announcement_group(client):
    headers_a, _ = _signup(client, "+22898000004")
    headers_b, _ = _signup(client, "+22898000005")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)

    announcements = _announcement_group(community)

    # Le créateur publie.
    posted = client.post(
        f"/api/v1/groups/{announcements['id']}/messages",
        json={"content": "Ouverture à 6h demain"},
        headers=headers_a,
    )
    assert posted.status_code == 200, posted.text

    # Un membre simple ne publie pas — c'est ce qui fait des « annonces ».
    refused = client.post(
        f"/api/v1/groups/{announcements['id']}/messages",
        json={"content": "moi aussi je parle"},
        headers=headers_b,
    )
    assert refused.status_code == 403

    # Mais il lit.
    read = client.get(f"/api/v1/groups/{announcements['id']}/messages", headers=headers_b)
    assert read.status_code == 200
    assert [m["content"] for m in read.json()["items"]] == ["Ouverture à 6h demain"]


def test_a_promoted_admin_can_post_announcements(client):
    """Un rôle qui ne donnerait pas la parole là où elle compte serait
    purement décoratif."""
    headers_a, _ = _signup(client, "+22898000006")
    headers_b, user_id_b = _signup(client, "+22898000007")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)
    announcements = _announcement_group(community)

    assert client.post(
        f"/api/v1/groups/{announcements['id']}/messages",
        json={"content": "avant"},
        headers=headers_b,
    ).status_code == 403

    promoted = client.put(
        f"/api/v1/communities/{community['id']}/members/{user_id_b}/role",
        json={"role": "ADMIN"},
        headers=headers_a,
    )
    assert promoted.status_code == 200

    assert client.post(
        f"/api/v1/groups/{announcements['id']}/messages",
        json={"content": "après"},
        headers=headers_b,
    ).status_code == 200


def test_ordinary_groups_stay_open_to_every_member(client):
    """La règle des annonces ne doit pas fuiter sur les groupes normaux."""
    headers_a, _ = _signup(client, "+22898000008")
    headers_b, user_id_b = _signup(client, "+22898000009")
    group = _create_group(client, headers_a, "Vendeurs", [("+22898000009", user_id_b)])
    _create_community(client, headers_a, "Marché", group_ids=[group["id"]])

    sent = client.post(
        f"/api/v1/groups/{group['id']}/messages", json={"content": "bonjour"}, headers=headers_b
    )
    assert sent.status_code == 200


# ─── Adhésion ─────────────────────────────────────────────────────────────────

def test_joining_a_community_adds_to_announcements_only(client):
    """Rejoindre la communauté ne fait pas entrer dans TOUS ses groupes : les
    rejoindre reste un choix, un par un."""
    headers_a, _ = _signup(client, "+22898000010")
    headers_b, _ = _signup(client, "+22898000011")
    group = _create_group(client, headers_a, "Vendeurs")
    community = _create_community(client, headers_a, "Marché", group_ids=[group["id"]])
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]

    joined = client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)
    assert joined.status_code == 200
    assert joined.json()["member_count"] == 2
    assert joined.json()["my_role"] == "MEMBER"

    my_groups = {g["name"] for g in client.get("/api/v1/groups", headers=headers_b).json()["items"]}
    assert my_groups == {"Annonces"}


def test_joining_twice_is_idempotent(client):
    headers_a, _ = _signup(client, "+22898000012")
    headers_b, _ = _signup(client, "+22898000013")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]

    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)
    second = client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)

    assert second.status_code == 200
    assert second.json()["member_count"] == 2


def test_invite_preview_hides_the_composition(client):
    headers_a, _ = _signup(client, "+22898000014")
    headers_b, _ = _signup(client, "+22898000015")
    group = _create_group(client, headers_a, "Vendeurs")
    community = _create_community(client, headers_a, "Marché", group_ids=[group["id"]])
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]

    preview = client.get(f"/api/v1/communities/invite/{code}", headers=headers_b).json()

    assert preview["name"] == "Marché"
    assert preview["group_count"] == 2
    assert preview["already_member"] is False
    # On ne révèle pas la composition à quelqu'un qui n'y est pas encore.
    assert "groups" not in preview
    assert "members" not in preview


def test_regenerating_the_link_invalidates_the_previous_one(client):
    headers_a, _ = _signup(client, "+22898000016")
    headers_b, _ = _signup(client, "+22898000017")
    community = _create_community(client, headers_a, "Marché")

    old_code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    new_code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]

    assert new_code != old_code
    assert client.post(f"/api/v1/communities/invite/{old_code}/join", headers=headers_b).status_code == 404
    assert client.post(f"/api/v1/communities/invite/{new_code}/join", headers=headers_b).status_code == 200


def test_a_plain_member_cannot_see_or_create_the_invite_link(client):
    headers_a, _ = _signup(client, "+22898000018")
    headers_b, _ = _signup(client, "+22898000019")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)

    assert client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_b
    ).status_code == 403
    seen = client.get(f"/api/v1/communities/{community['id']}", headers=headers_b).json()
    assert seen["invite_code"] is None
    assert seen["can_manage"] is False


# ─── Groupes rattachés ────────────────────────────────────────────────────────

def test_cannot_attach_a_group_you_do_not_administer(client):
    """Sinon n'importe qui absorberait le groupe d'autrui dans sa communauté,
    et en exposerait le nom à tous ses membres."""
    headers_a, _ = _signup(client, "+22898000020")
    headers_b, _ = _signup(client, "+22898000021")
    someone_elses = _create_group(client, headers_b, "Groupe privé de B")
    community = _create_community(client, headers_a, "Marché")

    response = client.post(
        f"/api/v1/communities/{community['id']}/groups",
        json={"group_id": someone_elses["id"]},
        headers=headers_a,
    )
    assert response.status_code == 403


def test_a_group_cannot_belong_to_two_communities(client):
    headers, _ = _signup(client, "+22898000022")
    group = _create_group(client, headers, "Vendeurs")
    _create_community(client, headers, "Marché", group_ids=[group["id"]])
    other = _create_community(client, headers, "Autre communauté")

    response = client.post(
        f"/api/v1/communities/{other['id']}/groups", json={"group_id": group["id"]}, headers=headers
    )
    assert response.status_code == 409


def test_a_group_can_be_created_directly_inside_the_community(client):
    headers, _ = _signup(client, "+22898000023")
    community = _create_community(client, headers, "Marché")

    created = client.post(
        f"/api/v1/communities/{community['id']}/groups", json={"name": "Livreurs"}, headers=headers
    )
    assert created.status_code == 200
    assert created.json()["name"] == "Livreurs"
    assert created.json()["is_announcement"] is False

    detail = client.get(f"/api/v1/communities/{community['id']}", headers=headers).json()
    assert {g["name"] for g in detail["groups"]} == {"Annonces", "Livreurs"}


def test_detaching_a_group_keeps_its_conversation(client):
    headers, _ = _signup(client, "+22898000024")
    group = _create_group(client, headers, "Vendeurs")
    community = _create_community(client, headers, "Marché", group_ids=[group["id"]])
    client.post(f"/api/v1/groups/{group['id']}/messages", json={"content": "avant"}, headers=headers)

    detached = client.delete(
        f"/api/v1/communities/{community['id']}/groups/{group['id']}", headers=headers
    )
    assert detached.status_code == 200

    # Le groupe existe toujours, avec son historique.
    still = client.get(f"/api/v1/groups/{group['id']}/messages", headers=headers)
    assert [m["content"] for m in still.json()["items"]] == ["avant"]
    assert client.get(f"/api/v1/groups/{group['id']}", headers=headers).json()["community_id"] is None


def test_the_announcement_group_cannot_be_detached(client):
    headers, _ = _signup(client, "+22898000025")
    community = _create_community(client, headers, "Marché")
    announcements = _announcement_group(community)

    response = client.delete(
        f"/api/v1/communities/{community['id']}/groups/{announcements['id']}", headers=headers
    )
    assert response.status_code == 400


# ─── Membres et rôles ─────────────────────────────────────────────────────────

def test_an_admin_cannot_appoint_other_admins(client):
    headers_a, _ = _signup(client, "+22898000026")
    headers_b, user_id_b = _signup(client, "+22898000027")
    headers_c, user_id_c = _signup(client, "+22898000028")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_c)
    client.put(
        f"/api/v1/communities/{community['id']}/members/{user_id_b}/role",
        json={"role": "ADMIN"},
        headers=headers_a,
    )

    response = client.put(
        f"/api/v1/communities/{community['id']}/members/{user_id_c}/role",
        json={"role": "ADMIN"},
        headers=headers_b,
    )
    assert response.status_code == 403


def test_leaving_a_community_leaves_announcements_but_not_other_groups(client):
    """On n'expulse pas quelqu'un de conversations où il a été invité
    personnellement."""
    headers_a, _ = _signup(client, "+22898000029")
    headers_b, user_id_b = _signup(client, "+22898000030")
    group = _create_group(client, headers_a, "Vendeurs", [("+22898000030", user_id_b)])
    community = _create_community(client, headers_a, "Marché", group_ids=[group["id"]])
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)

    left = client.delete(
        f"/api/v1/communities/{community['id']}/members/{user_id_b}", headers=headers_b
    )
    assert left.status_code == 200

    my_groups = {g["name"] for g in client.get("/api/v1/groups", headers=headers_b).json()["items"]}
    assert my_groups == {"Vendeurs"}
    assert client.get("/api/v1/communities", headers=headers_b).json()["items"] == []


def test_the_owner_cannot_be_removed_by_an_admin(client):
    headers_a, user_id_a = _signup(client, "+22898000031")
    headers_b, user_id_b = _signup(client, "+22898000032")
    community = _create_community(client, headers_a, "Marché")
    code = client.post(
        f"/api/v1/communities/{community['id']}/invite-link", headers=headers_a
    ).json()["invite_code"]
    client.post(f"/api/v1/communities/invite/{code}/join", headers=headers_b)
    client.put(
        f"/api/v1/communities/{community['id']}/members/{user_id_b}/role",
        json={"role": "ADMIN"},
        headers=headers_a,
    )

    response = client.delete(
        f"/api/v1/communities/{community['id']}/members/{user_id_a}", headers=headers_b
    )
    assert response.status_code == 403


# ─── Modification et cloisonnement ────────────────────────────────────────────

def test_admins_can_rename_and_describe_the_community(client):
    headers, _ = _signup(client, "+22898000033")
    community = _create_community(client, headers, "Marché")

    updated = client.patch(
        f"/api/v1/communities/{community['id']}",
        json={"name": "Grand marché", "description": "Vendeurs et livreurs du centre"},
        headers=headers,
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Grand marché"
    assert updated.json()["description"] == "Vendeurs et livreurs du centre"


def test_a_non_member_sees_nothing_of_a_community(client):
    headers_a, _ = _signup(client, "+22898000034")
    headers_b, _ = _signup(client, "+22898000035")
    community = _create_community(client, headers_a, "Marché")

    assert client.get(f"/api/v1/communities/{community['id']}", headers=headers_b).status_code == 403
    assert client.patch(
        f"/api/v1/communities/{community['id']}", json={"name": "Détourné"}, headers=headers_b
    ).status_code == 403
    assert client.get("/api/v1/communities", headers=headers_b).json()["items"] == []


def test_an_empty_name_is_rejected(client):
    headers, _ = _signup(client, "+22898000036")
    community = _create_community(client, headers, "Marché")
    assert client.patch(
        f"/api/v1/communities/{community['id']}", json={"name": "   "}, headers=headers
    ).status_code == 400


def test_community_endpoints_require_authentication(client):
    assert client.get("/api/v1/communities").status_code in (401, 403)
    assert client.post("/api/v1/communities", json={"name": "x"}).status_code in (401, 403)


def test_the_community_photo_loads_for_its_members_and_for_nobody_else(client):
    """Même règle que la photo d'un groupe (voir test_pokou_groups) : réservée
    aux membres. Sans branche dédiée dans media.py::_can_access, elle ne se
    chargeait que pour son auteur."""
    headers_owner, _ = _signup(client, "+22893000090")
    headers_stranger, _ = _signup(client, "+22893000091")
    community = _create_community(client, headers_owner, name="Marché de Tokoin")

    media_id = client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("logo.jpg", b"des-octets", "image/jpeg")},
        headers=headers_owner,
    ).json()["id"]
    updated = client.patch(
        f"/api/v1/communities/{community['id']}",
        json={"avatar_media_id": media_id},
        headers=headers_owner,
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["avatar"]["id"] == media_id

    assert client.get(f"/api/v1/media/{media_id}", headers=headers_owner).status_code == 200
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_stranger).status_code == 404
