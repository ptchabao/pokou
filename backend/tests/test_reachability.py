"""Pokou — à qui ai-je le droit d'écrire, et qui peut m'écrire.

Quatre choses se jouent ici, et trois d'entre elles étaient cassées :

- **répondre à un inconnu.** Quelqu'un qui vous a dans son carnet vous
  écrit ; vous n'avez pas le sien ; votre réponse partait en 403. Une
  messagerie où le premier message passe mais pas la réponse n'en est pas
  une.
- **écrire à un numéro qu'on vient de lire**, sans créer de fiche.
- **le blocage.** `is_blocked_between` existait, était testé, et n'était
  appelé par AUCUNE route : bloquer quelqu'un ne l'empêchait pas d'écrire.
  C'est le carnet obligatoire qui servait de barrière de fait, ce qui rend
  ce test indissociable des deux précédents — relâcher le carnet sans
  réparer le blocage aurait ouvert la porte en grand.
- **l'énumération.** Les `user_id` sont des entiers séquentiels. Ce qui doit
  rester impossible, c'est d'écrire à un compte qu'on n'a fait que deviner.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Contact
from app.services.auth import contact_linking, otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_reachability.db"

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


ALICE = "+22890000001"
BOB = "+22890000002"
CAROL = "+22890000003"


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()  # Le bocal à cookies de TestClient authentifierait la requête suivante.
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _send(client, headers, recipient_id, content="Bonjour", phone=None):
    payload = {"recipient_id": recipient_id, "content": content}
    if phone:
        payload["recipient_phone"] = phone
    return client.post("/api/v1/messages", json=payload, headers=headers)


# ── Répondre à quelqu'un qu'on n'a pas dans son carnet ─────────────────────

def test_on_peut_repondre_a_quelqu_un_absent_de_son_carnet(client):
    alice, alice_id = _signup(client, ALICE)
    bob, bob_id = _signup(client, BOB)

    # Alice a Bob dans son carnet, Bob n'a pas Alice.
    client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=alice)
    assert _send(client, alice, bob_id).status_code == 200

    # La réponse de Bob doit passer : c'est Alice qui a ouvert la porte.
    assert _send(client, bob, alice_id, "Et voilà").status_code == 200


def test_ecrire_a_un_inconnu_sans_rien_prouver_reste_refuse(client):
    alice, alice_id = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)

    # Aucune fiche, aucune conversation, aucun numéro fourni : c'est
    # exactement le scénario de l'énumération par identifiant.
    response = _send(client, alice, bob_id)
    assert response.status_code == 403


# ── Le numéro comme clé ───────────────────────────────────────────────────

def test_connaitre_le_numero_suffit_a_ecrire(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)

    assert _send(client, alice, bob_id, phone=BOB).status_code == 200

    # Et le carnet d'Alice n'a pas été modifié au passage : écrire à
    # quelqu'un ne l'enregistre pas chez soi.
    listing = client.get("/api/v1/contacts", headers=alice).json()
    assert listing["items"] == []


def test_un_numero_qui_n_est_pas_le_sien_ne_donne_aucun_droit(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)
    _signup(client, CAROL)

    # Numéro valide, mais celui de quelqu'un d'autre : sans cette
    # vérification, n'importe quel numéro connu ouvrirait n'importe quel
    # identifiant.
    assert _send(client, alice, bob_id, phone=CAROL).status_code == 403


def test_une_fois_la_conversation_ouverte_le_numero_n_est_plus_necessaire(client):
    alice, _ = _signup(client, ALICE)
    _bob, bob_id = _signup(client, BOB)

    assert _send(client, alice, bob_id, "Premier", phone=BOB).status_code == 200
    # Le client n'a pas à retenir le numéro pour la suite : l'historique
    # prouve désormais la relation.
    assert _send(client, alice, bob_id, "Deuxième").status_code == 200


# ── Blocage ───────────────────────────────────────────────────────────────

def test_bloquer_quelqu_un_l_empeche_vraiment_d_ecrire(client):
    alice, alice_id = _signup(client, ALICE)
    bob, bob_id = _signup(client, BOB)

    client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=alice)
    client.post("/api/v1/contacts", json={"phone": ALICE, "display_name": "Alice"}, headers=bob)
    assert _send(client, bob, alice_id).status_code == 200

    # Alice bloque Bob.
    blocked = client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": bob_id, "blocked": True},
        headers=alice,
    )
    assert blocked.status_code == 200, blocked.text

    # Bob ne peut plus écrire à Alice — c'est le sens évident.
    assert _send(client, bob, alice_id, "Toujours là ?").status_code == 403
    # Et Alice non plus : sinon celle qui bloque impose une conversation à
    # sens unique à quelqu'un qui ne peut plus répondre.
    assert _send(client, alice, bob_id, "Coucou").status_code == 403


def test_le_blocage_prime_sur_le_numero_connu(client):
    alice, alice_id = _signup(client, ALICE)
    bob, bob_id = _signup(client, BOB)

    client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=alice)
    client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": bob_id, "blocked": True},
        headers=alice,
    )

    # Le numéro d'Alice ne doit pas servir de contournement : le blocage est
    # vérifié AVANT toute autre voie d'accès.
    assert _send(client, bob, alice_id, phone=ALICE).status_code == 403


# ── Rattachement des fiches en attente ────────────────────────────────────

def test_une_fiche_ajoutee_avant_l_inscription_se_rattache_a_l_arrivee(client):
    alice, alice_id = _signup(client, ALICE)

    # Bob n'est pas encore sur Pokou : la fiche existe, sans compte associé.
    created = client.post(
        "/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=alice
    ).json()
    assert created["contact_user_id"] is None

    # Bob s'inscrit.
    _bob, bob_id = _signup(client, BOB)

    listing = client.get("/api/v1/contacts", headers=alice).json()["items"]
    assert [c["contact_user_id"] for c in listing] == [bob_id]


def test_le_rattachement_designe_ceux_qu_il_faut_prevenir(client):
    alice, alice_id = _signup(client, ALICE)
    carol, carol_id = _signup(client, CAROL)
    for headers in (alice, carol):
        client.post("/api/v1/contacts", json={"phone": BOB, "display_name": "Bob"}, headers=headers)

    _bob, bob_id = _signup(client, BOB)

    with TestingSessionLocal() as session:
        bob_user = session.query(Contact).filter(Contact.phone == BOB).first()
        assert bob_user.contact_user_id == bob_id
        # Rappelé une seconde fois, il ne trouve plus rien à rattacher : la
        # fonction tourne à CHAQUE connexion, pas seulement à la création.
        from app.models import User
        assert contact_linking.link_pending_contacts(session, session.get(User, bob_id)) == []
