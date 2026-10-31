"""Une limite de débit sur TOUTE l'API, pas seulement sur les portes connues.

Les portes sensibles étaient protégées une par une — les codes OTP (3 par
quart d'heure et par numéro), les clés d'API (60 par minute), la
vérification du code de compte. C'est le bon réflexe, mais ça laisse tout le
reste sans plafond : la liste des conversations, la recherche de chaînes, la
publication d'un message, l'envoi d'un média. De quoi épuiser la base, la
passerelle SMS ou le stockage sans jamais toucher à une route « sensible ».

À ne pas confondre avec `app/utils/rate_limiter.py`, qui existe déjà et
répond à une autre question : celui-là compte les appels d'un UTILISATEUR
selon son forfait, pour facturer un quota, et suppose donc une session
ouverte. Celui-ci compte par SOURCE, avant toute authentification — c'est ce
qui manquait, puisqu'une attaque ne se connecte pas d'abord.

Fenêtre glissante approchée, en mémoire du processus. Trois plafonds, parce
qu'un seul chiffre serait soit trop lâche pour les portes coûteuses, soit
trop serré pour la navigation ordinaire.

╔══════════════════════════════════════════════════════════════════════════╗
║  CE QUE CETTE LIMITE N'EST PAS — À LIRE AVANT DE S'EN REMETTRE À ELLE    ║
╚══════════════════════════════════════════════════════════════════════════╝

**Le compteur est PAR PROCESSUS.** Chaque worker uvicorn tient le sien, en
mémoire, sans rien partager. Avec N workers, le plafond réellement appliqué
est donc N fois celui écrit ici, et un même appelant peut être compté
séparément par chacun selon l'ordre de répartition.

**Ce n'est donc PAS une protection contre un déni de service.** Ni simple ni
distribué. Une attaque volumétrique sature la bande passante, les connexions
et le CPU bien avant d'atteindre ces compteurs, et un botnet présente autant
d'adresses différentes qu'il a de machines — chacune sous le plafond. Cette
protection-là se traite en amont : chez l'hébergeur, au reverse proxy, ou
devant un service spécialisé.

**Ce que ça couvre réellement**, et c'est déjà utile : un client qui boucle
par erreur, un script de balayage naïf, quelqu'un qui tente des codes à la
chaîne depuis une adresse, une facture SMS qui s'emballe. C'est-à-dire
l'immense majorité de ce qui arrive en pratique.

Choix ASSUMÉ contre un compteur partagé par Redis : faire dépendre CHAQUE
requête d'un service externe échange une approximation contre un point de
panne. Un Redis indisponible rendrait l'API muette, là où la version en
mémoire se contente d'être imprécise. Un garde-fou approximatif qui ne peut
pas tomber vaut mieux qu'un garde-fou exact qui emporte l'API avec lui.
"""
import logging
import time
from collections import defaultdict, deque

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import get_settings

logger = logging.getLogger(__name__)

#: Fenêtre d'observation, en secondes.
WINDOW_SECONDS = 60

#: ╔════════════════════════════════════════════════════════════════════╗
#: ║  POURQUOI CES PLAFONDS SONT SI HAUTS                               ║
#: ╚════════════════════════════════════════════════════════════════════╝
#:
#: Parce qu'une adresse IP ne désigne pas une personne.
#:
#: Les opérateurs mobiles d'Afrique de l'Ouest — le marché de Pokou —
#: pratiquent massivement le NAT d'opérateur : des milliers d'abonnés
#: partagent une poignée d'adresses publiques. Idem derrière le wifi d'un
#: bureau, d'un cybercafé ou d'un campus. Du point de vue de cette classe,
#: tous ces gens sont UN SEUL appelant.
#:
#: La première version plafonnait l'authentification à 30 requêtes par
#: minute. Un opérateur entier aurait donc disposé de 30 connexions par
#: minute pour tous ses abonnés : ses utilisateurs se seraient mutuellement
#: empêchés d'entrer, sans que rien ne l'explique. La suite de tests l'a
#: montré avant la production — soixante-dix tests sont tombés d'un coup,
#: tous sur des 429, simplement parce qu'ils partagent une adresse.
#:
#: Ces plafonds arrêtent donc ce qu'ils peuvent réellement arrêter : un
#: client qui boucle, un script de balayage, une facture SMS qui s'emballe.
#: Ils ne prétendent pas distinguer un abus d'une foule.
#:
#: La vraie protection de l'authentification est ailleurs, et elle est plus
#: fine : 3 codes par quart d'heure PAR NUMÉRO, 5 essais par code (voir
#: services/otp_service.py). Un compteur par numéro n'est ni trompé ni gêné
#: par le NAT.

#: Navigation ordinaire : lire des listes, ouvrir une conversation.
DEFAULT_LIMIT = 1200

#: Les routes qui COÛTENT — un SMS facturé, un média stocké, un message
#: poussé à des centaines d'abonnés. Le plafond protège la dépense autant
#: que le service.
COSTLY_LIMIT = 240
COSTLY_PREFIXES = (
    "/api/v1/sms/",
    "/api/v1/media",
    "/api/v1/channels",
    "/api/v1/broadcasts",
)

#: Les portes d'authentification. Volontairement GÉNÉREUX, et non serré :
#: voir l'encadré ci-dessus. La protection fine vit dans otp_service, par
#: numéro. Ce plafond-ci n'arrête qu'un script qui martèle depuis une seule
#: machine.
AUTH_LIMIT = 240
AUTH_PREFIXES = ("/api/v1/auth/",)

#: Ce qui ne doit jamais être plafonné.
#:
#: Le WebSocket : une socket ouverte n'est qu'une requête, mais la refuser
#: couperait le temps réel pour toute la durée de la fenêtre. Les sondes de
#: santé : les plafonner ferait croire l'API morte à l'orchestrateur, qui la
#: redémarrerait — une limite de débit qui provoque la panne qu'elle devait
#: prévenir.
EXEMPT_PREFIXES = ("/api/v1/ws", "/health", "/docs", "/openapi.json", "/redoc")


def category_for(path: str) -> tuple[str, int]:
    """La catégorie d'une route, et son plafond.

    La CATÉGORIE et non le plafond seul : les compteurs étaient classés par
    valeur numérique, et comme `AUTH_LIMIT` et `COSTLY_LIMIT` valent tous
    deux 240, l'authentification et les routes coûteuses partageaient le
    même compteur. Épuiser l'un fermait l'autre — un envoi de médias
    intensif pouvait empêcher de se reconnecter.

    Deux catégories qui se trouvent avoir le même chiffre restent deux
    catégories.
    """
    if any(path.startswith(prefix) for prefix in AUTH_PREFIXES):
        return ("auth", AUTH_LIMIT)
    if any(path.startswith(prefix) for prefix in COSTLY_PREFIXES):
        return ("costly", COSTLY_LIMIT)
    return ("default", DEFAULT_LIMIT)


def limit_for(path: str) -> int:
    """Le plafond seul — conservé pour les appelants qui n'ont besoin que
    de ça."""
    return category_for(path)[1]


def client_key(request: Request) -> str:
    """Qui compte comme « un appelant ».

    L'en-tête `X-Forwarded-For` en priorité : derrière un reverse proxy,
    `request.client.host` est l'adresse du PROXY, donc la même pour tout le
    monde — le plafond deviendrait global et la première personne connectée
    ferait taire les autres. On prend la première adresse de la chaîne, celle
    du client d'origine.

    À ne faire QUE derrière un proxy de confiance qui réécrit cet en-tête :
    exposée directement, cette valeur est choisie par l'appelant, qui
    contournerait la limite en la changeant à chaque requête. C'est le cas
    ici — l'API n'est jamais jointe sans son proxy — et ça doit le rester.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "inconnu"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Le plafond, distribué quand Redis est là, local sinon.

    ── Pourquoi les deux ────────────────────────────────────────────────

    Le compteur en mémoire était correct à une instance et faux à N : le
    plafond réel se multipliait par le nombre de processus. Redis le rend
    exact.

    Mais la raison de garder le repli n'a pas disparu : un Redis en panne ne
    doit pas rendre l'API muette. On bascule donc, sans jamais refuser une
    requête parce que le compteur est injoignable — la protection se dégrade,
    elle ne devient pas une panne.

    C'est le compromis que vous aviez explicitement retenu, et il tient
    encore : un garde-fou approximatif qui ne peut pas tomber vaut mieux
    qu'un garde-fou exact qui emporte l'API avec lui.
    """

    def __init__(self, app):
        super().__init__(app)
        # Une file d'horodatages par appelant et par catégorie de plafond.
        # Sert de repli, et de compteur unique quand Redis est absent.
        self._hits: dict[tuple[str, str], deque] = defaultdict(deque)
        self._redis = None
        self._redis_checked = False

    def _client(self):
        """Le client Redis, ouvert au premier besoin et jamais réessayé s'il
        échoue : payer un aller-retour par requête vers un Redis qu'on sait
        absent coûterait plus cher que le plafond ne rapporte."""
        if self._redis_checked:
            return self._redis
        self._redis_checked = True
        try:
            import redis

            client = redis.from_url(get_settings().redis_url, decode_responses=True)
            client.ping()
            self._redis = client
            logger.info("[Débit] Plafond distribué actif")
        except Exception as exc:
            logger.warning(
                "[Débit] Redis indisponible (%s) — plafond PAR PROCESSUS, "
                "donc multiplié par le nombre d'instances",
                exc.__class__.__name__,
            )
            self._redis = None
        return self._redis

    def _over_limit_redis(self, key: tuple[str, str], limit: int) -> bool | None:
        """Compte dans Redis. Renvoie `None` si Redis n'a pas répondu.

        Fenêtre par intervalle plutôt que glissante : `INCR` sur une clé
        horodatée, avec expiration. C'est une approximation — un appelant
        peut émettre jusqu'à deux fois le plafond à cheval sur deux fenêtres
        — mais elle coûte UNE commande là où une fenêtre glissante exacte en
        coûterait trois et un tri. Pour un garde-fou contre l'emballement,
        l'approximation suffit largement.
        """
        client = self._client()
        if client is None:
            return None
        bucket = int(time.time()) // WINDOW_SECONDS
        redis_key = f"pokou:rate:{key[0]}:{key[1]}:{bucket}"
        try:
            count = client.incr(redis_key)
            if count == 1:
                # Expire un peu après la fenêtre : la clé disparaît d'elle-
                # même, il n'y a aucun ménage à faire.
                client.expire(redis_key, WINDOW_SECONDS * 2)
            return count > limit
        except Exception:
            # Redis est tombé en cours de route : on retombe sur le compteur
            # local plutôt que de laisser passer ou de tout refuser.
            self._redis = None
            return None

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if any(path.startswith(prefix) for prefix in EXEMPT_PREFIXES):
            return await call_next(request)

        categorie, limit = category_for(path)
        key = (client_key(request), categorie)

        depasse = self._over_limit_redis(key, limit)
        if depasse is not None:
            if depasse:
                return self._refus(key[0], limit, path)
            return await call_next(request)

        # Repli local — voir la docstring de la classe.
        now = time.monotonic()
        hits = self._hits[key]
        # On purge AVANT de compter : sans ça la file grandirait
        # indéfiniment pour un appelant régulier, et la mémoire du processus
        # avec elle.
        threshold = now - WINDOW_SECONDS
        while hits and hits[0] < threshold:
            hits.popleft()

        if len(hits) >= limit:
            return self._refus(key[0], limit, path)

        hits.append(now)
        return await call_next(request)

    @staticmethod
    def _refus(appelant: str, limit: int, path: str) -> JSONResponse:
        logger.warning(
            "[Débit] %s dépasse %s requêtes/%ss sur %s",
            appelant,
            limit,
            WINDOW_SECONDS,
            path,
        )
        return JSONResponse(
            status_code=429,
            content={"detail": "Trop de requêtes — réessayez dans un instant."},
            headers={"Retry-After": str(WINDOW_SECONDS)},
        )
