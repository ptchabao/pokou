"""La session survit aux années, et meurt quand on le lui demande.

Deux exigences opposées, et tout l'intérêt est qu'elles tiennent ensemble :

- **rester connecté.** Une semaine sans ouvrir Pokou déconnectait. Un
  voyage, un second téléphone, une hospitalisation suffisaient à imposer un
  SMS au retour. La session ne périme plus d'elle-même ;
- **pouvoir fermer.** Une session qui ne périme plus n'a QUE la révocation
  pour la fermer. Il faut donc que la révocation ferme la bonne — ce qui
  n'était pas le cas, et ne se voyait pas tant que sept jours finissaient
  par tout nettoyer.

Le défaut central que ce fichier verrouille : `DeviceToken.session_jti`
était posé à l'enregistrement et jamais reporté à la rotation. Au bout de
trente minutes il désignait un jeton déjà révoqué, pendant que la vraie
session continuait ailleurs. « Révoquer cet appareil » révoquait alors
quelque chose de mort, et quelqu'un qui croyait fermer la porte d'un
téléphone perdu ne fermait rien.
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings
from app.core.database import Base, get_db
from app.main import app
from app.models import DeviceToken, Token
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_session_survie.db"

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
    return body


def _rafraichir(client, refresh_token):
    return client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )


# ── Rester connecté ───────────────────────────────────────────────────────


def test_la_session_ne_perime_plus_avant_des_annees(client):
    """Sept jours sans ouvrir Pokou déconnectaient. Plus maintenant."""
    body = _signup(client, "+22893200001")

    with TestingSessionLocal() as db:
        ligne = db.query(Token).filter(Token.user_id == body["user"]["id"]).one()
        restant = ligne.expires_at - datetime.utcnow()

    # La borne est basse à dessein : on vérifie l'ORDRE DE GRANDEUR, pas une
    # valeur exacte que le réglage doit rester libre d'ajuster.
    assert restant > timedelta(days=365), restant
    assert get_settings().refresh_token_expire_days >= 365


# ── Pouvoir fermer ────────────────────────────────────────────────────────


def test_revoquer_un_appareil_coupe_la_session_APRES_rotation(client):
    """Le défaut central, et la raison pour laquelle le reste est acceptable.

    `session_jti` était posé à l'enregistrement et jamais reporté. Au premier
    rafraîchissement il désignait un jeton déjà révoqué : révoquer le
    téléphone ne fermait plus rien, et la session continuait sous un autre
    `jti`.
    """
    body = _signup(client, "+22893200002")
    entetes = {"Authorization": f"Bearer {body['access_token']}"}

    enregistre = client.post(
        "/api/v1/devices/register",
        json={"token": "jeton-fcm-abc", "platform": "android"},
        headers=entetes,
    )
    assert enregistre.status_code in (200, 201), enregistre.text

    # La session tourne : le jeton de rafraîchissement est échangé.
    rafraichi = _rafraichir(client, body["refresh_token"])
    assert rafraichi.status_code == 200, rafraichi.text
    nouveau_refresh = rafraichi.json()["refresh_token"]
    nouveaux_entetes = {
        "Authorization": f"Bearer {rafraichi.json()['access_token']}"
    }

    # L'appareil suit sa session.
    with TestingSessionLocal() as db:
        appareil = db.query(DeviceToken).filter(
            DeviceToken.user_id == body["user"]["id"]
        ).one()
        vivant = db.query(Token).filter(
            Token.user_id == body["user"]["id"], Token.revoked_at.is_(None)
        ).one()
        assert appareil.session_jti == vivant.jti, (
            "le lien appareil→session n'a pas suivi la rotation"
        )
        appareil_id = appareil.id

    supprime = client.delete(f"/api/v1/devices/{appareil_id}", headers=nouveaux_entetes)
    assert supprime.status_code == 200, supprime.text

    # Et la session est VRAIMENT fermée : le jeton de rafraîchissement ne
    # vaut plus rien.
    apres = _rafraichir(client, nouveau_refresh)
    assert apres.status_code == 403, apres.text


def test_la_deconnexion_ferme_toutes_les_sessions(client):
    body = _signup(client, "+22893200003")
    entetes = {"Authorization": f"Bearer {body['access_token']}"}

    assert client.post("/api/v1/auth/logout", headers=entetes).status_code == 200
    assert _rafraichir(client, body["refresh_token"]).status_code == 403


def test_un_jeton_echange_ne_ressert_pas_hors_fenetre_de_grace(client):
    """La rotation est ce qui rend une session sans échéance acceptable.

    Un jeton volé cesse de servir dès que le vrai client se rafraîchit. Sans
    cette propriété, dix ans de validité seraient dix ans de porte ouverte.
    """
    body = _signup(client, "+22893200004")
    premier = body["refresh_token"]

    assert _rafraichir(client, premier).status_code == 200

    # Hors de la fenêtre de grâce : on la consomme d'abord (un rejeu passe
    # UNE fois), le suivant doit être refusé.
    _rafraichir(client, premier)
    assert _rafraichir(client, premier).status_code == 403


# ── Ce qu'une évolution technique ne doit PAS faire ───────────────────────


def test_un_jeton_sans_champ_de_version_reste_accepte(client):
    """`verify_token` ne lit ni version ni schéma, et ça doit durer.

    Les cas « nouvelle version d'application », « migration backend » et
    « changement de schéma de session » sont sains PAR OMISSION : personne
    n'a ajouté de vérification de version. Le jour où quelqu'un l'ajoutera,
    l'effet ne se verrait qu'au déploiement, sur tout le parc à la fois.

    Ce test échoue alors, et c'est tout son objet.
    """
    body = _signup(client, "+22893200005")
    from app.core.security import verify_token

    charge = verify_token(body["refresh_token"], "refresh")
    # Les seules clés dont dépend la validation.
    assert charge.get("type") == "refresh"
    assert charge.get("user_id")
    # Aucune version n'est exigée : le jeton n'en porte pas, et il passe.
    assert "v" not in charge and "version" not in charge
    assert _rafraichir(client, body["refresh_token"]).status_code == 200


def test_une_ligne_de_session_sans_les_colonnes_recentes_reste_valable(client):
    """Les colonnes du 25/09 sont nullables, et doivent le rester.

    Une session créée avant leur ajout — donc avec `rotated_at`,
    `replaced_by_jti` et `grace_used_at` à `NULL` — doit continuer de
    fonctionner. Sinon un simple déploiement déconnecterait tout le monde.
    """
    body = _signup(client, "+22893200006")
    with TestingSessionLocal() as db:
        ligne = db.query(Token).filter(Token.user_id == body["user"]["id"]).one()
        ligne.rotated_at = None
        ligne.replaced_by_jti = None
        ligne.grace_used_at = None
        db.commit()

    assert _rafraichir(client, body["refresh_token"]).status_code == 200
