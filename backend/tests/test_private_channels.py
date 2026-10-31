"""Une chaîne privée est introuvable, illisible et fermée.

Trois portes, et il faut les trois : sans l'une, les deux autres ne servent
à rien. Fermer la lecture en laissant la recherche révéler le nom, ou fermer
la recherche en laissant s'abonner par identifiant — les identifiants étant
des entiers consécutifs — ne protège personne.

Le quatrième test de ce fichier est le plus important : **le défaut ne
change rien**. Des chaînes publiques existent et des gens les suivent ; une
migration qui les rendrait privées ferait disparaître des fils que personne
n'a demandé à fermer.
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

TEST_DATABASE_URL = "sqlite:///./test_private_channels.db"

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


def _creer(client, entetes, nom, privee):
    reponse = client.post(
        "/api/v1/channels",
        json={"name": nom, "description": "Prix du ciment", "is_private": privee},
        headers=entetes,
    )
    assert reponse.status_code in (200, 201), reponse.text
    return reponse.json()


def _publier(client, entetes, channel_id, texte):
    return client.post(
        f"/api/v1/channels/{channel_id}/posts",
        json={"text_content": texte},
        headers=entetes,
    )


# ── Le défaut ne change rien ──────────────────────────────────────────────


def test_une_chaine_reste_publique_par_defaut(client):
    """Sans rien demander, une chaîne se comporte exactement comme avant."""
    entetes_a, _ = _signup(client, "+22893500001")
    reponse = client.post(
        "/api/v1/channels", json={"name": "Annonces Lomé"}, headers=entetes_a
    )
    assert reponse.status_code in (200, 201), reponse.text
    assert reponse.json()["is_private"] is False


def test_une_chaine_publique_se_lit_sans_abonnement(client):
    """On juge une chaîne sur son contenu avant de la suivre."""
    entetes_a, _ = _signup(client, "+22893500002")
    entetes_b, _ = _signup(client, "+22893500003")
    chaine = _creer(client, entetes_a, "Annonces Lomé", False)
    _publier(client, entetes_a, chaine["id"], "Ciment à 4 500")

    fil = client.get(f"/api/v1/channels/{chaine['id']}/posts", headers=entetes_b)
    assert fil.status_code == 200, fil.text
    assert len(fil.json()["items"]) == 1


# ── Les trois portes ──────────────────────────────────────────────────────


def test_une_chaine_privee_ne_sort_pas_de_la_recherche(client):
    entetes_a, _ = _signup(client, "+22893500004")
    entetes_b, _ = _signup(client, "+22893500005")
    _creer(client, entetes_a, "Grossistes Adidogomé", True)
    _creer(client, entetes_a, "Annonces publiques", False)

    trouve = client.get("/api/v1/channels/search?q=o", headers=entetes_b)
    assert trouve.status_code == 200, trouve.text
    noms = {c["name"] for c in trouve.json()["items"]}
    assert "Annonces publiques" in noms
    # Le NOM d'une chaîne en dit déjà beaucoup : « Grossistes Adidogomé » se
    # devine mal, mais se confirme vite.
    assert "Grossistes Adidogomé" not in noms


def test_une_chaine_privee_ne_se_suggere_pas(client):
    entetes_a, _ = _signup(client, "+22893500006")
    entetes_b, _ = _signup(client, "+22893500007")
    _creer(client, entetes_a, "Grossistes Adidogomé", True)

    suggerees = client.get("/api/v1/channels/suggested", headers=entetes_b)
    assert suggerees.status_code == 200, suggerees.text
    assert all(not c["is_private"] for c in suggerees.json()["items"])
    assert "Grossistes Adidogomé" not in {
        c["name"] for c in suggerees.json()["items"]
    }


def test_le_fil_d_une_chaine_privee_ne_se_lit_pas_de_l_exterieur(client):
    entetes_a, _ = _signup(client, "+22893500008")
    entetes_b, _ = _signup(client, "+22893500009")
    chaine = _creer(client, entetes_a, "Grossistes Adidogomé", True)
    _publier(client, entetes_a, chaine["id"], "Sac à 3 900 pour vous")

    fil = client.get(f"/api/v1/channels/{chaine['id']}/posts", headers=entetes_b)
    # 404 et non 403 : un refus explicite confirmerait l'existence de la
    # chaîne à qui essaie des identifiants — qui sont des entiers
    # consécutifs.
    assert fil.status_code == 404, fil.text


def test_on_ne_s_abonne_pas_seul_a_une_chaine_privee(client):
    """Sans ce contrôle, `is_private` n'aurait fermé que la vitrine."""
    entetes_a, _ = _signup(client, "+22893500010")
    entetes_b, _ = _signup(client, "+22893500011")
    chaine = _creer(client, entetes_a, "Grossistes Adidogomé", True)

    abonnement = client.post(
        f"/api/v1/channels/{chaine['id']}/follow", headers=entetes_b
    )
    assert abonnement.status_code == 404, abonnement.text


# ── Le lien est la seule porte ────────────────────────────────────────────


def test_le_lien_prive_ouvre_bien_la_chaine(client):
    entetes_a, _ = _signup(client, "+22893500012")
    entetes_b, _ = _signup(client, "+22893500013")
    chaine = _creer(client, entetes_a, "Grossistes Adidogomé", True)
    _publier(client, entetes_a, chaine["id"], "Sac à 3 900 pour vous")

    # Le lien existe DÈS la création : devoir le générer après coup ferait
    # une chaîne privée que personne ne peut rejoindre, y compris ceux qu'on
    # venait d'inviter de vive voix.
    code = chaine["invite_code"]
    assert code, "une chaîne privée doit naître avec son lien"

    rejoint = client.post(f"/api/v1/channels/invite/{code}/join", headers=entetes_b)
    assert rejoint.status_code == 200, rejoint.text

    # Et à partir de là, le fil se lit.
    fil = client.get(f"/api/v1/channels/{chaine['id']}/posts", headers=entetes_b)
    assert fil.status_code == 200, fil.text
    assert len(fil.json()["items"]) == 1


def test_le_proprietaire_lit_toujours_sa_chaine(client):
    entetes_a, _ = _signup(client, "+22893500014")
    chaine = _creer(client, entetes_a, "Grossistes Adidogomé", True)
    _publier(client, entetes_a, chaine["id"], "Sac à 3 900")

    fil = client.get(f"/api/v1/channels/{chaine['id']}/posts", headers=entetes_a)
    assert fil.status_code == 200, fil.text
    assert len(fil.json()["items"]) == 1


def test_la_chaine_privee_figure_dans_MES_chaines(client):
    """Elle est introuvable pour les autres, pas pour ses abonnés."""
    entetes_a, _ = _signup(client, "+22893500015")
    chaine = _creer(client, entetes_a, "Grossistes Adidogomé", True)

    miennes = client.get("/api/v1/channels", headers=entetes_a).json()["items"]
    assert chaine["id"] in {c["id"] for c in miennes}
    assert next(c for c in miennes if c["id"] == chaine["id"])["is_private"] is True
