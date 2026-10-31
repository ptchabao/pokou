"""On INVITE dans un groupe, on n'y met plus d'office.

Ajouter quelqu'un le rendait membre sur-le-champ : on se retrouvait dans une
conversation sans l'avoir demandé, avec ses notifications et son historique,
et la seule sortie était de partir — c'est-à-dire d'annoncer publiquement
qu'on était parti.

Ce fichier verrouille quatre propriétés, dans cet ordre d'importance :

1. **tant qu'on n'a pas accepté, on n'est PAS membre.** Ni dans la liste des
   membres, ni dans la diffusion des messages, ni dans ses propres groupes ;
2. **« qui peut m'inviter » décide de l'ENVOI, jamais de l'adhésion.** Même
   quelqu'un qui autorise tout le monde garde le dernier mot ;
3. **l'expiration se calcule.** Pas de tâche de fond, donc pas de fenêtre
   pendant laquelle une invitation périmée resterait acceptable ;
4. **une nouvelle invitation reste possible** après un refus ou une
   expiration — sans quoi une hésitation vaudrait bannissement.
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
from app.models import GroupInvitation, GroupInvitationStatus, GroupMember, PrivacyAudience, User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_group_invitations.db"

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
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as envoi:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", envoi.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _contact(client, entetes, phone):
    client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": "X"}, headers=entetes
    )


def _duo(client, a, b):
    entetes_a, id_a = _signup(client, a)
    entetes_b, id_b = _signup(client, b)
    _contact(client, entetes_a, b)
    _contact(client, entetes_b, a)
    return (entetes_a, id_a), (entetes_b, id_b)


def _creer_groupe(client, entetes, membres):
    return client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": membres},
        headers=entetes,
    )


def _membres(group_id: int) -> set:
    with TestingSessionLocal() as db:
        return {
            row[0]
            for row in db.query(GroupMember.user_id)
            .filter(GroupMember.group_id == group_id)
            .all()
        }


# ── Tant qu'on n'a pas accepté, on n'est pas membre ───────────────────────


def test_creer_un_groupe_invite_au_lieu_d_ajouter(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400001", "+22893400002"
    )
    reponse = _creer_groupe(client, entetes_a, [id_b])
    assert reponse.status_code in (200, 201), reponse.text
    group_id = reponse.json()["id"]

    # Le créateur, et lui seul.
    assert _membres(group_id) == {id_a}
    assert len(reponse.json()["invitations"]) == 1

    # B ne voit pas ce groupe dans les siens tant qu'il n'a rien accepté.
    # `["items"]` directement : `or siens` retombait sur le dictionnaire
    # quand la liste est VIDE — c'est-à-dire exactement le cas qu'on veut
    # vérifier ici.
    siens = client.get("/api/v1/groups", headers=entetes_b).json()
    assert {g["id"] for g in siens["items"]} == set()


def test_un_invite_ne_recoit_pas_les_messages_du_groupe(client):
    """La propriété qui justifie une table séparée.

    Un membre « en attente » aurait été un membre pour toute requête qui
    liste ou diffuse, et la première oubliée aurait envoyé les messages du
    groupe à quelqu'un qui n'a rien accepté.
    """
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400003", "+22893400004"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]

    client.post(
        f"/api/v1/groups/{group_id}/messages",
        json={"content": "Rendez-vous à 8 h"},
        headers=entetes_a,
    )
    lu = client.get(f"/api/v1/groups/{group_id}/messages", headers=entetes_b)
    assert lu.status_code in (403, 404), lu.text


def test_accepter_rend_membre(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400005", "+22893400006"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]

    invitations = client.get("/api/v1/groups/invitations", headers=entetes_b).json()
    assert len(invitations["items"]) == 1
    charge = invitations["items"][0]
    # Ce que l'invité voit AVANT de décider : de quoi trancher, et pas les
    # messages — on ne lit pas une conversation qu'on n'a pas rejointe.
    assert charge["group"]["name"] == "Chantier"
    assert charge["invited_by"]["id"] == id_a
    assert charge["group"]["member_count"] == 1

    accepte = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/accept", headers=entetes_b
    )
    assert accepte.status_code == 200, accepte.text
    assert _membres(group_id) == {id_a, id_b}


def test_refuser_ne_rend_pas_membre(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400007", "+22893400008"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]

    refuse = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/reject", headers=entetes_b
    )
    assert refuse.status_code == 200, refuse.text
    assert _membres(group_id) == {id_a}
    # Et la liste est vide : il n'y a plus rien à décider.
    assert client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"] == []


# ── L'expiration ──────────────────────────────────────────────────────────


def test_une_invitation_de_plus_de_72h_ne_s_accepte_plus(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400009", "+22893400010"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]

    with TestingSessionLocal() as db:
        invitation = db.query(GroupInvitation).filter(
            GroupInvitation.id == charge["id"]
        ).one()
        invitation.expires_at = datetime.utcnow() - timedelta(minutes=1)
        db.commit()

    tardif = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/accept", headers=entetes_b
    )
    # 409 et non 400 : l'invitation a existé, elle n'est simplement plus
    # valable. Le client distingue « jamais reçue » de « trop tard ».
    assert tardif.status_code == 409, tardif.text
    assert _membres(group_id) == {id_a}


def test_une_invitation_perimee_disparait_de_la_liste_et_s_ecrit(client):
    """L'expiration se CALCULE, et s'écrit quand on la constate.

    Sans l'écriture, la base garderait des `PENDING` éternels et l'index
    unique partiel empêcherait de réinviter — alors que l'ancienne
    invitation ne vaut plus rien.
    """
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400011", "+22893400012"
    )
    _creer_groupe(client, entetes_a, [id_b])
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]

    with TestingSessionLocal() as db:
        db.query(GroupInvitation).filter(GroupInvitation.id == charge["id"]).update(
            {"expires_at": datetime.utcnow() - timedelta(seconds=1)}
        )
        db.commit()

    assert client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"] == []
    with TestingSessionLocal() as db:
        relue = db.query(GroupInvitation).filter(
            GroupInvitation.id == charge["id"]
        ).one()
        assert relue.status == GroupInvitationStatus.EXPIRED


def test_on_peut_reinviter_apres_un_refus(client):
    """Une hésitation ne doit pas valoir bannissement.

    C'est pour ça que l'index unique est PARTIEL : une contrainte sur
    (groupe, personne) aurait interdit toute nouvelle invitation, pour
    toujours.
    """
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400013", "+22893400014"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]
    client.post(f"/api/v1/groups/invitations/{charge['id']}/reject", headers=entetes_b)

    encore = client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_ids": [id_b]},
        headers=entetes_a,
    )
    assert encore.status_code == 200, encore.text
    assert len(encore.json()["invitations"]) == 1
    assert len(client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"]) == 1


# ── Idempotence ───────────────────────────────────────────────────────────


def test_inviter_deux_fois_ne_cree_qu_une_invitation(client):
    """Un double appui sur « Ajouter » ne doit pas produire deux lignes, ni
    échouer sur une violation de contrainte que personne ne peut interpréter."""
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400015", "+22893400016"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]

    encore = client.post(
        f"/api/v1/groups/{group_id}/members",
        json={"user_ids": [id_b]},
        headers=entetes_a,
    )
    assert encore.status_code == 200, encore.text
    assert len(client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"]) == 1


def test_accepter_deux_fois_ne_duplique_pas_l_appartenance(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400017", "+22893400018"
    )
    group_id = _creer_groupe(client, entetes_a, [id_b]).json()["id"]
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]

    premier = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/accept", headers=entetes_b
    )
    assert premier.status_code == 200
    second = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/accept", headers=entetes_b
    )
    assert second.status_code == 409, second.text

    with TestingSessionLocal() as db:
        lignes = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_id == id_b)
            .count()
        )
    assert lignes == 1


# ── La règle de confidentialité décide de l'ENVOI, pas de l'adhésion ──────


def test_qui_peut_m_inviter_bloque_l_envoi(client):
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400019", "+22893400020"
    )
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == id_b).update(
            {"privacy_group_invites": PrivacyAudience.NOBODY}
        )
        db.commit()

    reponse = _creer_groupe(client, entetes_a, [id_b])
    assert reponse.status_code == 403, reponse.text


def test_autoriser_tout_le_monde_n_ajoute_toujours_pas_d_office(client):
    """Le point le plus important de toute la tranche.

    Si autoriser valait accepter, on aurait remis le comportement d'avant
    avec un réglage devant — et personne ne le verrait, puisque le réglage
    dirait « tout le monde peut m'inviter ».
    """
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400021", "+22893400022"
    )
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == id_b).update(
            {"privacy_group_invites": PrivacyAudience.EVERYONE}
        )
        db.commit()

    reponse = _creer_groupe(client, entetes_a, [id_b])
    assert reponse.status_code in (200, 201), reponse.text
    group_id = reponse.json()["id"]
    assert _membres(group_id) == {id_a}  # invité, pas membre


# ── L'invitation d'autrui ─────────────────────────────────────────────────


def test_l_invitation_de_quelqu_un_d_autre_est_introuvable(client):
    """404 et non 403 : un refus explicite confirmerait qu'elle existe, donc
    que cette personne a été invitée quelque part."""
    (entetes_a, id_a), (entetes_b, id_b) = _duo(
        client, "+22893400023", "+22893400024"
    )
    entetes_c, id_c = _signup(client, "+22893400025")
    _creer_groupe(client, entetes_a, [id_b])
    charge = client.get("/api/v1/groups/invitations", headers=entetes_b).json()["items"][0]

    vole = client.post(
        f"/api/v1/groups/invitations/{charge['id']}/accept", headers=entetes_c
    )
    assert vole.status_code == 404, vole.text
