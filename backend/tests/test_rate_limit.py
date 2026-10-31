"""Le plafond de débit global.

Les portes sensibles étaient protégées une par une — codes OTP, clés d'API,
code de compte — et tout le reste ne l'était pas. Une boucle sur la liste des
conversations, la recherche de chaînes ou l'envoi de médias pouvait épuiser
la base, la passerelle SMS ou le stockage sans jamais toucher à une route
« sensible ».

Ces tests éprouvent le comportement, pas les constantes : les chiffres
peuvent changer, la règle non.
"""
import random
import time

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.middleware import rate_limit
from app.middleware.rate_limit import RateLimitMiddleware


@pytest.fixture
def client():
    app = FastAPI()
    app.add_middleware(RateLimitMiddleware)

    @app.get("/api/v1/auth/ping")
    async def auth_ping():
        return {"ok": True}

    @app.get("/api/v1/media/ping")
    async def media_ping():
        return {"ok": True}

    @app.get("/api/v1/conversations")
    async def ordinary():
        return {"ok": True}

    @app.get("/health")
    async def health():
        return {"ok": True}

    @app.get("/api/v1/ws")
    async def websocket_handshake():
        return {"ok": True}

    return TestClient(app)


#: Un compteur par adresse et par catégorie — et il vit maintenant dans
#: Redis, donc il SURVIT d'un test à l'autre dans la même fenêtre d'une
#: minute. Chaque test prend donc une adresse distincte, sinon le second
#: hériterait du quota déjà consommé par le premier.
#:
#: Le préfixe tiré au sort vaut pour le PROCESSUS entier : sans lui, deux
#: exécutions de la suite à moins d'une minute d'intervalle retombaient sur
#: les mêmes adresses ET la même fenêtre, donc la seconde héritait des
#: compteurs de la première.
_PREFIXE = f"10.{random.randint(1, 254)}"
_prochaine_ip = iter(f"{_PREFIXE}.{n // 256}.{n % 256}" for n in range(1, 500))


def _ip():
    return next(_prochaine_ip)


@pytest.fixture(autouse=True)
def fenetre_figee(monkeypatch):
    """Fige la fenêtre de comptage pendant chaque test.

    Le middleware range les compteurs dans un seau horodaté
    (`int(time.time()) // WINDOW_SECONDS`) — une approximation assumée, qui
    laisse passer jusqu'à deux fois le plafond à cheval sur deux fenêtres.
    C'est correct en production, et ingérable pour un test : marteler 241
    requêtes prend d'ordinaire moins d'une seconde, mais sur une machine
    chargée — une compilation Gradle en parallèle, par exemple — la minute
    tourne au milieu, le compteur repart de zéro, et la 241ᵉ requête passe.

    C'est exactement ce qui s'est produit le 23/09/2026 : rouge dans la
    suite complète, vert en isolé. Figer l'horloge rend le test
    déterministe SANS affaiblir ce qu'il vérifie — c'est le comportement à
    l'intérieur d'une fenêtre qui nous intéresse, pas la bordure.
    """
    instant = time.time()
    monkeypatch.setattr(rate_limit.time, "time", lambda: instant)


def _hammer(client, path, times, ip="10.0.0.1"):
    """Renvoie le dernier code de statut obtenu."""
    status = None
    for _ in range(times):
        status = client.get(path, headers={"X-Forwarded-For": ip}).status_code
    return status


def test_une_avalanche_finit_par_etre_refusee(client):
    ip = _ip()
    assert _hammer(client, "/api/v1/auth/ping", rate_limit.AUTH_LIMIT, ip) == 200
    assert _hammer(client, "/api/v1/auth/ping", 1, ip) == 429


def test_le_refus_dit_quand_revenir(client):
    ip = _ip()
    _hammer(client, "/api/v1/auth/ping", rate_limit.AUTH_LIMIT + 1, ip)
    response = client.get("/api/v1/auth/ping", headers={"X-Forwarded-For": ip})

    assert response.status_code == 429
    assert response.headers["Retry-After"] == str(rate_limit.WINDOW_SECONDS)


def test_les_portes_couteuses_sont_plus_serrees_que_la_navigation():
    # Un SMS facturé, un média stocké : le plafond protège la dépense.
    assert rate_limit.AUTH_LIMIT < rate_limit.DEFAULT_LIMIT
    assert rate_limit.COSTLY_LIMIT < rate_limit.DEFAULT_LIMIT


def test_les_plafonds_survivent_a_un_NAT_d_operateur():
    """Une adresse IP ne désigne pas une personne.

    Les opérateurs mobiles d'Afrique de l'Ouest — le marché de Pokou —
    partagent une poignée d'adresses publiques entre des milliers d'abonnés.
    La première version de ce plafond autorisait 30 connexions par minute :
    un opérateur entier aurait eu 30 connexions par minute pour tous ses
    abonnés, qui se seraient mutuellement empêchés d'entrer.

    Ce test fige l'ordre de grandeur. Le chiffre exact peut bouger ; ce qui
    ne doit pas bouger, c'est qu'il reste très au-dessus de ce qu'une foule
    légitime produit.
    """
    assert rate_limit.AUTH_LIMIT >= 120, (
        "trop serré pour une population derrière un NAT d'opérateur"
    )
    assert rate_limit.DEFAULT_LIMIT >= 600


def test_chaque_categorie_a_son_propre_compteur(client):
    # Sinon, une navigation intense fermerait la porte d'authentification —
    # et quelqu'un qui scrolle sa liste se retrouverait incapable de se
    # reconnecter.
    ip = _ip()
    _hammer(client, "/api/v1/auth/ping", rate_limit.AUTH_LIMIT + 1, ip)

    assert _hammer(client, "/api/v1/conversations", 1, ip) == 200


def test_deux_appelants_ne_se_genent_pas(client):
    # Le piège du reverse proxy : sans lecture de X-Forwarded-For, toutes les
    # requêtes arrivent de l'adresse du proxy et la première personne
    # connectée ferait taire tout le monde.
    _hammer(client, "/api/v1/auth/ping", rate_limit.AUTH_LIMIT + 1, ip=_ip())

    assert _hammer(client, "/api/v1/auth/ping", 1, ip=_ip()) == 200


def test_la_sonde_de_sante_n_est_jamais_plafonnee(client):
    # Une limite qui fait croire l'API morte à l'orchestrateur provoquerait
    # le redémarrage qu'elle devait prévenir.
    assert _hammer(client, "/health", rate_limit.DEFAULT_LIMIT + 50, _ip()) == 200


def test_le_websocket_n_est_jamais_plafonne(client):
    # Refuser une poignée de main couperait le temps réel pour toute la
    # durée de la fenêtre.
    assert _hammer(client, "/api/v1/ws", rate_limit.DEFAULT_LIMIT + 50, _ip()) == 200


def test_les_routes_couteuses_ont_leur_propre_plafond(client):
    ip = _ip()
    assert _hammer(client, "/api/v1/media/ping", rate_limit.COSTLY_LIMIT, ip) == 200
    assert _hammer(client, "/api/v1/media/ping", 1, ip) == 429


def test_le_classement_des_routes():
    assert rate_limit.limit_for("/api/v1/auth/phone/request-otp") == rate_limit.AUTH_LIMIT
    assert rate_limit.limit_for("/api/v1/sms/send") == rate_limit.COSTLY_LIMIT
    assert rate_limit.limit_for("/api/v1/media/42") == rate_limit.COSTLY_LIMIT
    assert rate_limit.limit_for("/api/v1/conversations") == rate_limit.DEFAULT_LIMIT


def test_auth_et_routes_couteuses_ne_partagent_PAS_leur_compteur(client):
    """Deux catégories qui ont le même chiffre restent deux catégories.

    Les compteurs étaient classés par VALEUR de plafond. `AUTH_LIMIT` et
    `COSTLY_LIMIT` valant tous deux 240, l'authentification et l'envoi de
    médias partageaient le même seau : un envoi intensif pouvait empêcher de
    se reconnecter.
    """
    ip = _ip()
    assert _hammer(client, "/api/v1/media/ping", rate_limit.COSTLY_LIMIT + 1, ip) == 429

    assert _hammer(client, "/api/v1/auth/ping", 1, ip) == 200


def test_le_classement_par_categorie():
    assert rate_limit.category_for("/api/v1/auth/phone/request-otp")[0] == "auth"
    assert rate_limit.category_for("/api/v1/media/42")[0] == "costly"
    assert rate_limit.category_for("/api/v1/conversations")[0] == "default"
