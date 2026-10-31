"""Pokou — listes de diffusion.

Ce qui est vérifié ici tient à la seule chose qui distingue une liste de
diffusion d'un groupe, et c'est une PROPRIÉTÉ D'ABSENCE : le destinataire ne
doit rien savoir des autres. Une régression ne se verrait pas — les messages
partiraient toujours — elle divulguerait seulement, en silence, la liste des
clients de quelqu'un à ses clients.

Les deux garde-fous testés ensuite sont ceux qui empêchent d'en faire un
outil de publipostage : on ne diffuse qu'à son carnet, et le blocage est
respecté destinataire par destinataire.
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

TEST_DATABASE_URL = "sqlite:///./test_pokou_broadcasts.db"

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


SELLER = "+22891000001"
CLIENT_A = "+22891000002"
CLIENT_B = "+22891000003"
STRANGER = "+22891000004"


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _add_contact(client, headers, phone, name):
    response = client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def _setup_seller_with_two_clients(client):
    seller, seller_id = _signup(client, SELLER)
    client_a, a_id = _signup(client, CLIENT_A)
    client_b, b_id = _signup(client, CLIENT_B)
    _add_contact(client, seller, CLIENT_A, "Client A")
    _add_contact(client, seller, CLIENT_B, "Client B")
    return {
        "seller": seller, "seller_id": seller_id,
        "a": client_a, "a_id": a_id,
        "b": client_b, "b_id": b_id,
    }


def test_chaque_destinataire_recoit_un_message_prive_ordinaire(client):
    people = _setup_seller_with_two_clients(client)

    created = client.post(
        "/api/v1/broadcasts",
        json={"name": "Clients fidèles", "member_user_ids": [people["a_id"], people["b_id"]]},
        headers=people["seller"],
    )
    assert created.status_code == 200, created.text
    list_id = created.json()["id"]
    assert created.json()["member_count"] == 2

    sent = client.post(
        f"/api/v1/broadcasts/{list_id}/messages",
        json={"content": "Arrivage de ciment demain"},
        headers=people["seller"],
    )
    assert sent.status_code == 200, sent.text
    assert sent.json()["recipient_count"] == 2

    # Chez CHAQUE client : un message ordinaire, dans la conversation avec le
    # vendeur. Rien qui indique une diffusion.
    for viewer, viewer_id, other_id in (
        (people["a"], people["a_id"], people["b_id"]),
        (people["b"], people["b_id"], people["a_id"]),
    ):
        inbox = client.get(f"/api/v1/messages/{people['seller_id']}", headers=viewer).json()
        assert len(inbox["items"]) == 1
        message = inbox["items"][0]
        assert message["content"] == "Arrivage de ciment demain"

        # La propriété qui compte, et qui ne se verrait pas casser : le
        # message ne désigne QUE la paire vendeur→lecteur. Aucun champ ne
        # nomme l'autre destinataire, et aucun ne dit qu'il y en a eu un.
        assert message["sender_id"] == people["seller_id"]
        assert message["recipient_id"] == viewer_id
        assert other_id not in [v for v in message.values() if isinstance(v, int)]
        assert not [k for k in message if "broadcast" in k.lower()]


def test_la_reponse_revient_en_prive_au_seul_expediteur(client):
    people = _setup_seller_with_two_clients(client)
    list_id = client.post(
        "/api/v1/broadcasts",
        json={"name": "Clients", "member_user_ids": [people["a_id"], people["b_id"]]},
        headers=people["seller"],
    ).json()["id"]
    client.post(
        f"/api/v1/broadcasts/{list_id}/messages",
        json={"content": "Arrivage demain"},
        headers=people["seller"],
    )

    # Le client A répond. Il n'a pas le vendeur dans son carnet : c'est
    # précisément le cas que la règle d'accessibilité doit laisser passer.
    reply = client.post(
        "/api/v1/messages",
        json={"recipient_id": people["seller_id"], "content": "J'en prends 10 sacs"},
        headers=people["a"],
    )
    assert reply.status_code == 200, reply.text

    # Le client B ne voit rien de cette réponse.
    b_inbox = client.get(f"/api/v1/messages/{people['seller_id']}", headers=people["b"]).json()
    assert [m["content"] for m in b_inbox["items"]] == ["Arrivage demain"]


def test_on_ne_diffuse_qu_a_son_carnet(client):
    people = _setup_seller_with_two_clients(client)
    _stranger, stranger_id = _signup(client, STRANGER)

    created = client.post(
        "/api/v1/broadcasts",
        json={"name": "Tout le monde", "member_user_ids": [people["a_id"], stranger_id]},
        headers=people["seller"],
    ).json()

    # L'inconnu est écarté en silence : sans ce filtre, une liste de
    # diffusion permettrait d'écrire à 256 identifiants d'un seul appel, ce
    # que le reste de la messagerie interdit précisément.
    assert created["member_count"] == 1
    assert [m["user_id"] for m in created["members"]] == [people["a_id"]]


def test_un_destinataire_bloque_est_saute_sans_faire_echouer_l_envoi(client):
    people = _setup_seller_with_two_clients(client)
    list_id = client.post(
        "/api/v1/broadcasts",
        json={"name": "Clients", "member_user_ids": [people["a_id"], people["b_id"]]},
        headers=people["seller"],
    ).json()["id"]

    # Le client B bloque le vendeur.
    client.post("/api/v1/contacts", json={"phone": SELLER, "display_name": "Vendeur"}, headers=people["b"])
    blocked = client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": people["seller_id"], "blocked": True},
        headers=people["b"],
    )
    assert blocked.status_code == 200, blocked.text

    sent = client.post(
        f"/api/v1/broadcasts/{list_id}/messages",
        json={"content": "Arrivage demain"},
        headers=people["seller"],
    ).json()

    # Une brouille avec une personne ne doit pas bloquer les trente-neuf
    # autres — mais elle doit tenir pour celle-là.
    assert sent["recipient_count"] == 1
    assert sent["skipped_blocked"] == 1
    assert client.get(f"/api/v1/messages/{people['seller_id']}", headers=people["b"]).json()["items"] == []


def test_la_liste_n_est_visible_que_de_son_auteur(client):
    people = _setup_seller_with_two_clients(client)
    list_id = client.post(
        "/api/v1/broadcasts",
        json={"name": "Clients fidèles", "member_user_ids": [people["a_id"]]},
        headers=people["seller"],
    ).json()["id"]

    # Un destinataire ne sait pas qu'il est sur une liste — et ne peut donc
    # pas la lire, la modifier, ni même en constater l'existence.
    assert client.get("/api/v1/broadcasts", headers=people["a"]).json()["items"] == []
    assert client.get(f"/api/v1/broadcasts/{list_id}/messages", headers=people["a"]).status_code == 404
    assert client.delete(f"/api/v1/broadcasts/{list_id}", headers=people["a"]).status_code == 404


def test_supprimer_la_liste_ne_supprime_pas_les_messages_deja_partis(client):
    people = _setup_seller_with_two_clients(client)
    list_id = client.post(
        "/api/v1/broadcasts",
        json={"name": "Clients", "member_user_ids": [people["a_id"]]},
        headers=people["seller"],
    ).json()["id"]
    client.post(
        f"/api/v1/broadcasts/{list_id}/messages",
        json={"content": "Arrivage demain"},
        headers=people["seller"],
    )

    assert client.delete(f"/api/v1/broadcasts/{list_id}", headers=people["seller"]).status_code == 200

    # Le message est chez son destinataire, dans sa conversation. Il n'a
    # jamais porté la marque de cette liste : rien ne justifierait qu'il
    # disparaisse parce que l'expéditeur a rangé son carnet de copie.
    inbox = client.get(f"/api/v1/messages/{people['seller_id']}", headers=people["a"]).json()
    assert [m["content"] for m in inbox["items"]] == ["Arrivage demain"]
