"""Pokou — chiffrement de bout en bout, côté serveur.

Ce qui est testé ici n'est pas le chiffrement lui-même (il a lieu sur
l'appareil), mais la seule chose que le serveur puisse garantir : qu'il ne
détient rien qui permette de lire. Deux propriétés d'ABSENCE, donc, et elles
ne se verraient pas casser :

- un message chiffré ne laisse AUCUNE copie en clair en base ;
- le serveur ne stocke que des clés publiques.

La troisième famille de tests porte sur les pré-clés à usage unique, dont
tout l'intérêt est de n'être distribuées qu'une fois — une régression les
rendrait réutilisables, ce qui ne se remarquerait par aucun symptôme.
"""
import base64
import os
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DirectMessage
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_e2ee.db"

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


ALICE = "+22892000001"
BOB = "+22892000002"


def _key(size=32):
    return base64.b64encode(os.urandom(size)).decode()


def _bundle(prekey_count=3, **overrides):
    payload = {
        "device_id": "device-" + base64.b16encode(os.urandom(4)).decode(),
        "identity_key": _key(),
        "signing_key": _key(),
        "signed_prekey": _key(),
        "signed_prekey_signature": _key(64),
        "one_time_prekeys": [
            {"key_id": i, "public_key": _key()} for i in range(prekey_count)
        ],
    }
    payload.update(overrides)
    return payload


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


# ── Ce que le serveur ne doit PAS détenir ─────────────────────────────────

def test_un_message_chiffre_ne_laisse_aucune_copie_en_clair(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    client.put("/api/v1/e2ee/bundle", json=_bundle(), headers=alice)

    sent = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id,
            "recipient_phone": BOB,
            # Un client malveillant — ou simplement mal écrit — pourrait
            # envoyer les deux. Le serveur doit jeter le clair : le garder
            # « au cas où » viderait le chiffrement de tout son sens, et
            # c'est exactement ainsi que ce genre de fonctionnalité se défait
            # sans que personne ne le remarque.
            "content": "le prix est de 500000 FCFA",
            "encryption": "v1",
            "ciphertext": "Y2hpZmZyZQ==",
            "envelope": {"v": 1, "n": 0, "iv": "aXZpdml2aXZpdg=="},
        },
        headers=alice,
    )
    assert sent.status_code == 200, sent.text
    assert sent.json()["content"] is None
    assert sent.json()["ciphertext"] == "Y2hpZmZyZQ=="

    with TestingSessionLocal() as session:
        row = session.query(DirectMessage).filter(DirectMessage.id == sent.json()["id"]).one()
        assert row.content is None
        assert row.encryption == "v1"
        assert "500000" not in (row.ciphertext or "")


def test_la_recherche_serveur_ne_trouve_pas_un_message_chiffre(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id, "recipient_phone": BOB,
            "encryption": "v1", "ciphertext": "Y2hpZmZyZQ==",
            "envelope": {"v": 1, "n": 0, "iv": "aXZpdml2aXZpdg=="},
        },
        headers=alice,
    )
    # Ce n'est pas une lacune, c'est la preuve que ça marche : le serveur ne
    # peut pas chercher dans ce qu'il ne peut pas lire. La recherche du
    # contenu chiffré appartient au client, sur son cache déchiffré.
    found = client.get("/api/v1/messages/search?q=chiffre", headers=alice).json()
    assert found["items"] == []


def test_un_message_chiffre_sans_enveloppe_est_refuse(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    response = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id, "recipient_phone": BOB,
            "encryption": "v1", "ciphertext": "Y2hpZmZyZQ==",
        },
        headers=alice,
    )
    # Sans enveloppe, le destinataire ne peut RIEN faire du ciphertext.
    # Accepter serait écrire un message perdu, illisible pour toujours et
    # sans erreur visible au moment où il part.
    assert response.status_code == 400


def test_une_version_de_chiffrement_inconnue_est_refusee(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    response = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id, "recipient_phone": BOB,
            "encryption": "v99", "ciphertext": "Y2hpZmZyZQ==",
            "envelope": {"v": 99},
        },
        headers=alice,
    )
    assert response.status_code == 400


# ── L'annuaire ────────────────────────────────────────────────────────────

def test_on_recupere_le_trousseau_de_quelqu_un_pour_lui_ouvrir_une_session(client):
    alice, _ = _signup(client, ALICE)
    bob, bob_id = _signup(client, BOB)
    published = _bundle(prekey_count=2)
    assert client.put("/api/v1/e2ee/bundle", json=published, headers=bob).status_code == 200

    fetched = client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice).json()
    assert fetched["identity_key"] == published["identity_key"]
    assert fetched["signed_prekey_signature"] == published["signed_prekey_signature"]
    assert fetched["one_time_prekey"]["public_key"] in {
        p["public_key"] for p in published["one_time_prekeys"]
    }


def test_une_pre_cle_a_usage_unique_n_est_distribuee_qu_une_fois(client):
    alice, _ = _signup(client, ALICE)
    bob, bob_id = _signup(client, BOB)
    client.put("/api/v1/e2ee/bundle", json=_bundle(prekey_count=2), headers=bob)

    first = client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice).json()["one_time_prekey"]
    second = client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice).json()["one_time_prekey"]
    # Tout l'intérêt de ces clés tient à ce « une fois ». Une régression ici
    # ne produirait aucun symptôme : les messages partiraient et arriveraient,
    # simplement une session rejouée resterait déchiffrable.
    assert first["key_id"] != second["key_id"]

    # Réserve épuisée : on n'échoue pas, on renvoie null. La session s'ouvre
    # alors sur la pré-clé signée seule — moins fort, mais pas cassé.
    third = client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice).json()
    assert third["one_time_prekey"] is None
    assert third["identity_key"] is not None


def test_le_compteur_de_pre_cles_signale_quand_il_faut_reapprovisionner(client):
    bob, bob_id = _signup(client, BOB)
    alice, _ = _signup(client, ALICE)

    assert client.get("/api/v1/e2ee/prekeys/count", headers=bob).json()["published"] is False

    client.put("/api/v1/e2ee/bundle", json=_bundle(prekey_count=2), headers=bob)
    count = client.get("/api/v1/e2ee/prekeys/count", headers=bob).json()
    assert count == {"published": True, "available": 2, "low": True}

    client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice)
    assert client.get("/api/v1/e2ee/prekeys/count", headers=bob).json()["available"] == 1


def test_changer_d_identite_jette_les_anciennes_pre_cles(client):
    bob, _ = _signup(client, BOB)
    client.put("/api/v1/e2ee/bundle", json=_bundle(prekey_count=5), headers=bob)

    # Réinstallation : nouvelle identité. Garder les anciennes pré-clés
    # ferait dériver des sessions vers une clé privée que plus personne ne
    # détient — des messages illisibles, sans erreur nulle part.
    response = client.put(
        "/api/v1/e2ee/bundle", json=_bundle(prekey_count=2), headers=bob
    ).json()
    assert response["identity_changed"] is True
    assert client.get("/api/v1/e2ee/prekeys/count", headers=bob).json()["available"] == 2


def test_une_cle_de_mauvaise_taille_est_refusee_a_la_publication(client):
    bob, _ = _signup(client, BOB)
    response = client.put(
        "/api/v1/e2ee/bundle",
        json=_bundle(identity_key=base64.b64encode(os.urandom(16)).decode()),
        headers=bob,
    )
    # Une clé tronquée ne se signale nulle part : elle produit des messages
    # illisibles chez le correspondant, très loin d'ici. Refuser à la
    # publication transforme une panne muette en erreur nommée.
    assert response.status_code == 400
    assert "16 octets" in response.json()["detail"]


def test_sans_trousseau_publie_on_repond_404_et_pas_une_erreur(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    response = client.get(f"/api/v1/e2ee/bundle/{bob_id}", headers=alice)
    # Cas NORMAL : la personne n'a pas encore de version qui chiffre.
    # L'appelant doit retomber sur un envoi en clair, pas planter.
    assert response.status_code == 404


# ── Capacités : ce qu'un appareil sait chiffrer au-delà du texte ──────────


def test_les_capacites_publiees_avec_le_trousseau_sont_lisibles_sans_consommer_de_pre_cle(client):
    headers_a, _ = _signup(client, ALICE)
    headers_b, bob_id = _signup(client, BOB)
    client.put(
        "/api/v1/e2ee/bundle",
        json=_bundle(prekey_count=1, capabilities=["media-v1", "call-v1"]),
        headers=headers_b,
    )

    first = client.get(f"/api/v1/e2ee/capabilities/{bob_id}", headers=headers_a).json()
    client.get(f"/api/v1/e2ee/capabilities/{bob_id}", headers=headers_a)
    assert first["capabilities"] == ["call-v1", "media-v1"]
    assert first["identity_key"] is not None

    # La pré-clé unique est toujours là : lire les capacités n'en consomme pas.
    count = client.get("/api/v1/e2ee/prekeys/count", headers=headers_b).json()
    assert count["available"] == 1


def test_une_version_qui_ne_declare_rien_n_a_aucune_capacite(client):
    headers_a, _ = _signup(client, ALICE)
    headers_b, bob_id = _signup(client, BOB)
    client.put("/api/v1/e2ee/bundle", json=_bundle(capabilities=["media-v1"]), headers=headers_b)
    # Réinstallation d'une version plus ancienne : elle ne déclare rien, et
    # ce qu'avait déclaré la précédente ne doit pas lui survivre.
    client.put("/api/v1/e2ee/bundle", json=_bundle(), headers=headers_b)

    response = client.get(f"/api/v1/e2ee/capabilities/{bob_id}", headers=headers_a).json()
    assert response["capabilities"] == []


def test_sans_trousseau_aucune_capacite(client):
    headers_a, _ = _signup(client, ALICE)
    _, bob_id = _signup(client, BOB)
    response = client.get(f"/api/v1/e2ee/capabilities/{bob_id}", headers=headers_a)
    assert response.status_code == 200
    assert response.json()["capabilities"] == []


def test_une_piece_jointe_chiffree_ne_laisse_ni_legende_ni_nom_en_clair(client):
    headers_a, _ = _signup(client, ALICE)
    _, bob_id = _signup(client, BOB)
    client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=headers_a)

    # Le client téléverse un bloc opaque, comme document, sous un nom neutre.
    upload = client.post(
        "/api/v1/media/upload",
        data={"message_type": "DOCUMENT"},
        files={"file": ("pokou.bin", os.urandom(64), "application/octet-stream")},
        headers=headers_a,
    )
    assert upload.status_code == 200, upload.text
    media_id = upload.json()["id"]

    sent = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id,
            "message_type": "IMAGE",
            "media_asset_id": media_id,
            "encryption": "v1",
            "ciphertext": "Y2xlLWR1LWZpY2hpZXI=",
            "envelope": {"v": 1, "n": 0},
        },
        headers=headers_a,
    )
    assert sent.status_code == 200, sent.text
    body = sent.json()
    assert body["message_type"] == "IMAGE"
    assert body["content"] is None
    assert body["media"]["mime_type"] == "application/octet-stream"
    assert body["media"]["original_filename"] == "pokou.bin"


def test_le_serveur_refuse_de_transferer_un_message_chiffre(client):
    headers_a, _ = _signup(client, ALICE)
    _, bob_id = _signup(client, BOB)
    _, charlie_id = _signup(client, "+22892000003")
    client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=headers_a)
    client.post("/api/v1/contacts", json={"phone": "+22892000003", "display_name": "Charlie"}, headers=headers_a)

    sent = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": bob_id,
            "encryption": "v1",
            "ciphertext": "b3BhcXVl",
            "envelope": {"v": 1, "n": 0},
        },
        headers=headers_a,
    ).json()

    response = client.post(
        f"/api/v1/messages/{sent['id']}/forward",
        json={"recipient_id": charlie_id},
        headers=headers_a,
    )
    assert response.status_code == 409
