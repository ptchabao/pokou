"""Écrire à quelqu'un pour la PREMIÈRE fois.

Constaté en production : l'utilisateur touche un numéro, l'application le
cherche (`GET /contacts/lookup` → 200), ouvre la conversation, et chaque
envoi revient en 403. Il n'y avait ni fiche au carnet, ni conversation
existante, ni groupe commun — et le client, qui venait pourtant de chercher
CE numéro, ne le transmettait pas. Le serveur n'avait donc plus aucune façon
d'autoriser.

Ces tests figent les quatre chemins d'autorisation, celui du numéro en
particulier, et l'alignement de « en train d'écrire » sur la même règle.
"""
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_reachability.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# Le schéma est créé UNE fois pour le module, comme dans les autres fichiers
# de test. Supprimer le fichier entre deux tests laissait l'`engine` pointer
# sur un fichier disparu, et le suivant échouait sur « attempt to write a
# readonly database ».
Base.metadata.create_all(bind=engine)


@pytest.fixture
def client():
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    import re

    code = re.search(r"\b(\d{6})\b", mock.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def test_sans_rien_presenter_on_ne_peut_pas_ecrire(client):
    """Le garde-fou lui-même : les identifiants sont des entiers séquentiels,
    et sans règle on écrit à toute la base en incrémentant un compteur."""
    entetes, _ = _signup(client, "+22890100001")
    _, destinataire = _signup(client, "+22890100002")

    refus = client.post(
        "/api/v1/messages",
        json={"recipient_id": destinataire, "content": "bonjour"},
        headers=entetes,
    )

    assert refus.status_code == 403


def test_presenter_le_numero_autorise_le_premier_message(client):
    """Le chemin qui manquait côté client.

    Connaître un numéro est exactement ce qui autorise à joindre quelqu'un
    par SMS ou par téléphone : c'est la même clé, et elle ne s'énumère pas
    comme un entier séquentiel.
    """
    entetes, _ = _signup(client, "+22890100003")
    _, destinataire = _signup(client, "+22890100004")

    envoi = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": destinataire,
            "content": "bonjour",
            "recipient_phone": "+22890100004",
        },
        headers=entetes,
    )

    assert envoi.status_code == 200, envoi.text


def test_un_numero_avec_des_espaces_marche_aussi(client):
    """Le client transmet le numéro tel qu'il l'a lu — depuis le carnet du
    téléphone, il porte souvent des espaces (« +228 96 36 71 66 »)."""
    entetes, _ = _signup(client, "+22890100005")
    _, destinataire = _signup(client, "+22890100006")

    envoi = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": destinataire,
            "content": "bonjour",
            "recipient_phone": "+228 90 10 00 06",
        },
        headers=entetes,
    )

    assert envoi.status_code == 200, envoi.text


def test_le_numero_de_QUELQU_UN_D_AUTRE_n_autorise_rien(client):
    """Sinon le laissez-passer serait un passe-partout : il suffirait de
    présenter son propre numéro pour écrire à n'importe quel identifiant."""
    entetes, _ = _signup(client, "+22890100007")
    _, destinataire = _signup(client, "+22890100008")

    refus = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": destinataire,
            "content": "bonjour",
            "recipient_phone": "+22890100007",
        },
        headers=entetes,
    )

    assert refus.status_code == 403


def test_la_reponse_ne_demande_plus_rien(client):
    """Une messagerie où le premier message passe mais pas la réponse n'est
    pas une messagerie."""
    entetes_a, _ = _signup(client, "+22890100009")
    entetes_b, id_b = _signup(client, "+22890100010")

    client.post(
        "/api/v1/messages",
        json={
            "recipient_id": id_b,
            "content": "bonjour",
            "recipient_phone": "+22890100010",
        },
        headers=entetes_a,
    )
    me_a = client.get("/api/v1/auth/me", headers=entetes_a).json()

    reponse = client.post(
        "/api/v1/messages",
        json={"recipient_id": me_a["id"], "content": "salut"},
        headers=entetes_b,
    )

    assert reponse.status_code == 200, reponse.text


def test_ecrire_est_possible_mais_pas_signaler_sa_frappe(client):
    """Les deux règles doivent être la MÊME.

    /presence/typing gardait l'ancienne — « uniquement mon carnet » — alors
    que l'envoi avait été assoupli. On ouvrait la conversation, le message
    partait, et chaque frappe déclenchait un 403 silencieux : le
    correspondant ne voyait jamais « écrit… », sans que rien n'explique
    pourquoi.
    """
    entetes_a, _ = _signup(client, "+22890100011")
    entetes_b, id_b = _signup(client, "+22890100012")

    # Un premier message crée la conversation, donc la relation.
    envoi = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": id_b,
            "content": "bonjour",
            "recipient_phone": "+22890100012",
        },
        headers=entetes_a,
    )
    assert envoi.status_code == 200, envoi.text

    frappe = client.post(
        "/api/v1/presence/typing",
        json={"kind": "contact", "id": id_b, "typing": True},
        headers=entetes_a,
    )

    assert frappe.status_code == 200, frappe.text


def test_signaler_sa_frappe_a_un_inconnu_reste_refuse(client):
    """La présence de n'importe qui ne doit pas être consultable par
    énumération d'identifiants."""
    entetes, _ = _signup(client, "+22890100013")
    _, inconnu = _signup(client, "+22890100014")

    refus = client.post(
        "/api/v1/presence/typing",
        json={"kind": "contact", "id": inconnu, "typing": True},
        headers=entetes,
    )

    assert refus.status_code == 403


# ── La même règle partout : écrire, signaler sa frappe, APPELER ──────────


def test_appeler_quelqu_un_a_qui_on_peut_ecrire(client):
    """Trois routes, une seule règle.

    messages.py a été assoupli, presence.py était resté sur l'ancienne règle,
    et calls.py aussi. Le symptôme était le plus déroutant ici : depuis une
    conversation avec quelqu'un hors carnet, on pouvait écrire et le bouton
    d'appel renvoyait 403 — aucun appel n'était créé, donc rien n'apparaissait
    dans l'onglet Appels, et l'utilisateur ne voyait qu'un échec sans cause.
    """
    entetes_a, _ = _signup(client, "+22890100015")
    _, id_b = _signup(client, "+22890100016")

    # Une conversation existe : c'est ce qui autorise à écrire.
    envoi = client.post(
        "/api/v1/messages",
        json={
            "recipient_id": id_b,
            "content": "bonjour",
            "recipient_phone": "+22890100016",
        },
        headers=entetes_a,
    )
    assert envoi.status_code == 200, envoi.text

    appel = client.post(
        "/api/v1/calls/token",
        json={"contact_ids": [id_b], "is_video": False},
        headers=entetes_a,
    )

    # 200 si LiveKit est configuré, 503 sinon — mais JAMAIS 403 : ce qu'on
    # éprouve ici est l'autorisation, pas la disponibilité du média.
    assert appel.status_code != 403, appel.text


def test_appeler_un_inconnu_reste_refuse(client):
    """Le garde-fou garde sa raison d'être : les identifiants sont
    séquentiels, et sans règle on appellerait toute la base."""
    entetes, _ = _signup(client, "+22890100017")
    _, inconnu = _signup(client, "+22890100018")

    refus = client.post(
        "/api/v1/calls/token",
        json={"contact_ids": [inconnu], "is_video": False},
        headers=entetes,
    )

    assert refus.status_code == 403
