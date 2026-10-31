"""Le verrou qui garantit qu'UNE instance ordonnance.

`Scheduler.start()` tourne au démarrage de l'application. À dix
instances, dix schedulers exécutent le même travail : le rapport quotidien
part dix fois, les sources de données sont interrogées dix fois, les quotas
d'API tiers fondent d'autant. Le symptôme trompe — il ressemble à un bogue
de la tâche plutôt qu'à un défaut de déploiement.
"""
import pytest

from app.core import distributed_lock


class FakeRedis:
    """`SET NX EX` et rien d'autre — c'est tout ce dont le verrou dépend."""

    def __init__(self):
        self.store: dict[str, str] = {}

    def ping(self):
        return True

    def set(self, key, value, nx=False, ex=None):
        if nx and key in self.store:
            return None
        self.store[key] = value
        return True

    def get(self, key):
        return self.store.get(key)

    def delete(self, key):
        self.store.pop(key, None)


@pytest.fixture
def redis(monkeypatch):
    fake = FakeRedis()
    distributed_lock.reset()
    monkeypatch.setattr(distributed_lock, "_client", lambda: fake)
    yield fake
    distributed_lock.reset()


def test_une_seule_instance_obtient_le_verrou(redis):
    # Le cœur du sujet.
    assert distributed_lock.acquire("scheduler", 60, "inst-1") is True
    assert distributed_lock.acquire("scheduler", 60, "inst-2") is False
    assert distributed_lock.acquire("scheduler", 60, "inst-3") is False


def test_le_rendre_le_libere_pour_les_autres(redis):
    distributed_lock.acquire("scheduler", 60, "inst-1")
    distributed_lock.release("scheduler", "inst-1")

    assert distributed_lock.acquire("scheduler", 60, "inst-2") is True


def test_on_ne_libere_PAS_le_verrou_d_un_autre(redis):
    """Sans la vérification du propriétaire, une instance lente dont le
    verrou a expiré libérerait celui d'une autre, en train de travailler."""
    distributed_lock.acquire("scheduler", 60, "inst-1")

    distributed_lock.release("scheduler", "inst-2")

    assert distributed_lock.acquire("scheduler", 60, "inst-2") is False


def test_deux_verrous_differents_ne_se_genent_pas(redis):
    assert distributed_lock.acquire("scheduler", 60, "inst-1") is True
    assert distributed_lock.acquire("purge", 60, "inst-1") is True


def test_sans_redis_le_verrou_est_ACCORDE(monkeypatch):
    """Redis absent ne doit pas arrêter les tâches planifiées.

    C'est le comportement d'aujourd'hui — une instance qui exécute tout — et
    il est correct tant qu'il n'y en a qu'une. Refuser serait pire : la
    tâche ne s'exécuterait plus du tout.
    """
    distributed_lock.reset()
    monkeypatch.setattr(distributed_lock, "_client", lambda: None)

    assert distributed_lock.acquire("scheduler", 60, "inst-1") is True
    # Et rendre un verrou qui n'existe pas ne lève pas.
    distributed_lock.release("scheduler", "inst-1")


def test_un_redis_qui_tombe_en_route_laisse_EXECUTER(monkeypatch):
    """En cas de doute on exécute : une tâche jouée deux fois est moins
    grave qu'une tâche jamais jouée — et les nôtres sont idempotentes."""

    class Cassé:
        def set(self, *a, **k):
            raise RuntimeError("Redis coupé")

    distributed_lock.reset()
    monkeypatch.setattr(distributed_lock, "_client", lambda: Cassé())

    assert distributed_lock.acquire("scheduler", 60, "inst-1") is True


def test_le_scheduler_declare_une_duree_de_verrou_plus_longue_que_son_renouvellement():
    """Sinon le verrou expirerait entre deux renouvellements, et une seconde
    instance démarrerait ses propres boucles — deux ordonnanceurs."""
    from app.core.scheduler import Scheduler

    assert Scheduler.LOCK_RENEW_SECONDS < Scheduler.LOCK_TTL_SECONDS
    # Avec une marge : un pic de charge ne doit pas suffire à perdre le
    # verrou.
    assert Scheduler.LOCK_RENEW_SECONDS * 2 <= Scheduler.LOCK_TTL_SECONDS
