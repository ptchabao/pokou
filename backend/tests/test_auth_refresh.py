"""POST /auth/refresh — couvre le bug où le lookup se faisait sur
User.email alors que `sub` peut être un téléphone ou un id pour les
comptes Pokou (téléphone+OTP), ce qui faisait échouer le refresh pour
absolument tous les utilisateurs Pokou (voir app/routes/auth.py)."""
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_auth_refresh.db"

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
    return body["access_token"], body["refresh_token"], body["user"]["id"]


def test_refresh_works_for_phone_only_account(client):
    _, refresh_token, user_id = _signup(client, "+22895000001")

    response = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["refresh_token"] != refresh_token

    # Le nouveau jeton d'accès fonctionne réellement.
    me = client.get(
        "/api/v1/users/me/profile", headers={"Authorization": f"Bearer {body['access_token']}"}
    )
    assert me.status_code == 200
    assert me.json()["id"] == user_id


def test_refresh_rotates_and_invalidates_old_refresh_token(client):
    """La rotation reste la règle — avec UNE tolérance, et une seule.

    Ce test affirmait qu'un jeton échangé devient immédiatement inutilisable.
    C'était trop strict, et ça coûtait des sessions : si la RÉPONSE se perd
    (coupure au mauvais instant, courant sur un réseau mobile), l'ancien
    jeton est mort et le client n'a jamais reçu le nouveau — session perdue
    sans que personne n'ait rien fait de mal.

    La règle est donc : rejouable UNE fois dans la minute qui suit, puis
    plus jamais. Les deux moitiés sont vérifiées ici et dans les tests
    suivants — relâcher la première sans verrouiller la seconde reviendrait
    à supprimer la rotation.
    """
    _, refresh_token, _ = _signup(client, "+22895000002")

    first = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"})
    assert first.status_code == 200

    # Rejeu immédiat : accepté, c'est la fenêtre de grâce.
    replay = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"})
    assert replay.status_code == 200, replay.text

    # Deuxième rejeu : refusé. La grâce ne se consomme qu'une fois.
    encore = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"})
    assert encore.status_code == 403, encore.text


def test_refresh_rejects_access_token(client):
    access_token, _, _ = _signup(client, "+22895000003")
    response = client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {access_token}"})
    assert response.status_code == 403


def test_refresh_rejects_garbage_token(client):
    response = client.post("/api/v1/auth/refresh", headers={"Authorization": "Bearer not-a-real-token"})
    assert response.status_code == 403


def test_refresh_requires_authorization_header(client):
    response = client.post("/api/v1/auth/refresh")
    assert response.status_code == 401


# ─── La fenêtre de grâce à la rotation ────────────────────────────────────────
#
# Ces tests gardent un compromis, et c'est pour ça qu'ils vont par paires :
# chacun qui ASSOUPLIT est suivi d'un qui VERROUILLE. Pris séparément, le
# premier de chaque paire décrirait une rotation supprimée.


def _ligne_de_session(refresh_token):
    """La ligne `Token` derrière un jeton, pour manipuler le temps."""
    from jose import jwt

    from app.core.config import get_settings
    from app.models import Token

    settings = get_settings()
    jti = jwt.decode(
        refresh_token, settings.secret_key, algorithms=[settings.algorithm]
    )["jti"]
    db = TestingSessionLocal()
    try:
        return db.query(Token).filter(Token.jti == jti).first(), db
    except Exception:
        db.close()
        raise


def test_une_rotation_interrompue_se_rattrape(client):
    # LE cas pour lequel la fenêtre existe : le serveur a bien tourné les
    # jetons, mais la réponse s'est perdue. Le client n'a que l'ancien, et
    # redemande. Sans grâce, sa session est morte alors qu'il n'a rien fait
    # de mal.
    _, refresh_token, _ = _signup(client, "+22895000010")

    perdue = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )
    assert perdue.status_code == 200

    rattrapage = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )

    assert rattrapage.status_code == 200, rattrapage.text
    # Et les jetons rendus fonctionnent vraiment.
    nouveaux = rattrapage.json()
    verif = client.get(
        "/api/v1/users/me/profile",
        headers={"Authorization": f"Bearer {nouveaux['access_token']}"},
    )
    assert verif.status_code == 200


def test_le_rattrapage_rend_la_meme_session_sans_en_ouvrir_une_autre(client):
    # Le verrou de la paire précédente : une seule session par appareil.
    # Le rattrapage révoquait le successeur et en ouvrait un troisième ; il
    # rend désormais le MÊME successeur — si bien qu'il n'y a jamais deux
    # sessions vivantes, et que celle que le client a peut-être déjà reçue
    # reste bonne.
    from jose import jwt

    from app.core.config import get_settings
    from app.models import Token

    _, refresh_token, _ = _signup(client, "+22895000011")
    settings = get_settings()

    premiere = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    ).json()
    rattrapage = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    ).json()

    jti = lambda t: jwt.decode(t, settings.secret_key, algorithms=[settings.algorithm])["jti"]
    assert jti(premiere["refresh_token"]) == jti(rattrapage["refresh_token"])

    db = TestingSessionLocal()
    try:
        vivantes = db.query(Token).filter(Token.revoked_at.is_(None)).count()
    finally:
        db.close()
    assert vivantes == 1

    # Et la session continue normalement depuis l'un ou l'autre jeton.
    suite = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {premiere['refresh_token']}"}
    )
    assert suite.status_code == 200, suite.text


def test_la_grace_expire_au_bout_d_une_minute(client):
    # L'autre moitié de la règle. Sans échéance, un jeton intercepté
    # resterait utilisable indéfiniment : ce ne serait plus une rotation.
    from datetime import datetime, timedelta

    _, refresh_token, _ = _signup(client, "+22895000012")
    client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )

    # On recule la rotation au-delà de la fenêtre, plutôt que d'attendre une
    # minute pour chaque exécution de la suite.
    ligne, db = _ligne_de_session(refresh_token)
    try:
        ligne.rotated_at = datetime.utcnow() - timedelta(seconds=120)
        db.commit()
    finally:
        db.close()

    tardif = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )
    assert tardif.status_code == 403, tardif.text


def test_la_deconnexion_ne_beneficie_d_aucune_grace(client):
    # Une déconnexion volontaire doit fermer la porte IMMÉDIATEMENT. La
    # grâce ne s'applique qu'à une rotation, jamais à une révocation : sans
    # ce test, se déconnecter aurait laissé une minute d'accès.
    access_token, refresh_token, _ = _signup(client, "+22895000013")

    client.post(
        "/api/v1/auth/logout", headers={"Authorization": f"Bearer {access_token}"}
    )

    apres = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )
    assert apres.status_code == 403, apres.text


def test_deux_rafraichissements_simultanes_restent_coherents(client):
    # Deux requêtes avec le même jeton, l'une derrière l'autre sans délai :
    # le second passe par la grâce, et les deux jeux rendus doivent être
    # utilisables ou refusés — jamais un état où le compte se retrouve sans
    # session valable.
    _, refresh_token, _ = _signup(client, "+22895000014")

    premiere = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )
    seconde = client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {refresh_token}"}
    )

    assert premiere.status_code == 200
    assert seconde.status_code == 200
    # LES DEUX jeux marchent, quel que soit celui que le client garde. Le
    # premier était révoqué par le second : un appareil qui recevait les
    # réponses dans le désordre gardait le jeu mort, tombait en 401 sur
    # tout, puis en 403 au rafraîchissement suivant — déconnecté sans rien
    # avoir fait (journal de prod du 2026-10-02).
    for jeu in (premiere.json(), seconde.json()):
        assert client.get(
            "/api/v1/users/me/profile", headers={"Authorization": f"Bearer {jeu['access_token']}"}
        ).status_code == 200
