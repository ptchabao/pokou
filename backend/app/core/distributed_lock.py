"""Un verrou partagé, pour qu'une tâche planifiée ne s'exécute qu'une fois.

── Le problème ───────────────────────────────────────────────────────────

`Scheduler.start()` est appelé au démarrage de l'application. À une
instance, c'est correct. À dix, dix schedulers exécutent le même travail en
même temps : les webhooks des bots partent dix fois, la facturation tourne
dix fois.

Le symptôme est trompeur, parce qu'il ressemble à un bogue de la tâche
elle-même plutôt qu'à un défaut de déploiement.

── La correction ─────────────────────────────────────────────────────────

`SET clé valeur NX EX durée` : Redis pose la clé seulement si elle n'existe
pas, et l'opération est atomique. La première instance qui demande le verrou
l'obtient, les autres se taisent. Le verrou EXPIRE de lui-même, ce qui
règle le cas de l'instance qui meurt en le tenant — sans expiration, une
tâche planifiée cesserait définitivement de s'exécuter après un seul
plantage.

── Le repli ──────────────────────────────────────────────────────────────

Redis absent : le verrou est accordé. C'est le comportement d'aujourd'hui —
une seule instance qui exécute tout — et il est correct tant qu'il n'y en a
qu'une. Refuser la tâche serait pire : elle ne s'exécuterait plus du tout.
"""
import logging

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_redis = None
_unavailable = False


def _client():
    """Le client Redis, ouvert au premier besoin.

    Un échec est mémorisé : sans ça, chaque tentative de verrou paierait un
    aller-retour vers un Redis qu'on sait absent.
    """
    global _redis, _unavailable
    if _unavailable:
        return None
    if _redis is not None:
        return _redis
    try:
        import redis

        client = redis.from_url(get_settings().redis_url, decode_responses=True)
        client.ping()
        _redis = client
        return _redis
    except Exception as exc:
        _unavailable = True
        logger.warning(
            "[Verrou] Redis indisponible (%s) — les tâches planifiées "
            "s'exécutent sans coordination, ce qui reste correct à UNE instance",
            exc.__class__.__name__,
        )
        return None


def reset() -> None:
    """Oublie l'état du client — pour les tests."""
    global _redis, _unavailable
    _redis = None
    _unavailable = False


def acquire(name: str, ttl_seconds: int, owner: str) -> bool:
    """Tente de prendre le verrou `name`. Renvoie `True` si on l'a.

    `ttl_seconds` doit couvrir la durée de la tâche AVEC une marge : un
    verrou qui expire pendant l'exécution laisserait une seconde instance
    démarrer la même tâche. Mais pas trop long non plus — c'est aussi le
    temps pendant lequel la tâche ne repartira pas si l'instance meurt.
    """
    client = _client()
    if client is None:
        return True
    try:
        return bool(client.set(f"pokou:lock:{name}", owner, nx=True, ex=ttl_seconds))
    except Exception as exc:
        logger.warning("[Verrou] %s non vérifié : %s", name, exc)
        # En cas de doute on EXÉCUTE : une tâche jouée deux fois est
        # généralement moins grave qu'une tâche jamais jouée — et les nôtres
        # sont idempotentes (voir notification_queue).
        return True


def release(name: str, owner: str) -> None:
    """Rend le verrou, si on en est bien le propriétaire.

    La vérification du propriétaire compte : sans elle, une instance lente
    dont le verrou a expiré libérerait celui d'une AUTRE instance en train
    de travailler.
    """
    client = _client()
    if client is None:
        return
    try:
        key = f"pokou:lock:{name}"
        # Lu puis supprimé plutôt qu'un script Lua : la fenêtre entre les
        # deux est étroite, et le pire qu'elle produise est un verrou libéré
        # une fraction de seconde trop tôt — pas une double exécution, le
        # `nx` de `acquire` restant la vraie barrière.
        if client.get(key) == owner:
            client.delete(key)
    except Exception:
        pass
