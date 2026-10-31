"""Tâches planifiées de Pokou.

Trois boucles, sur UNE seule instance à la fois (verrou distribué, voir
core/distributed_lock.py) :

- ménage des appels : clôt les appels abandonnés, purge les jetons d'action ;
- Pokou Business : remise des webhooks des bots, facturation mensuelle ;
- purge des statuts expirés (24 h) et de leurs médias orphelins.
"""
import asyncio
import logging
import os
import uuid
from datetime import datetime

from app.core import distributed_lock
from app.core.database import SessionLocal

logger = logging.getLogger(__name__)


class Scheduler:
    def __init__(self):
        # Qui tient le verrou : un identifiant par PROCESSUS. Deux workers
        # uvicorn sur la même machine sont deux candidats distincts.
        self._owner = os.environ.get("POKOU_INSTANCE_ID", f"{os.getpid()}-{uuid.uuid4().hex[:8]}")
        self.stop_event = asyncio.Event()
        self.tasks: list[asyncio.Task] = []

    #: Le verrou qui garantit qu'UNE seule instance ordonnance.
    #:
    #: Sa durée dépasse largement l'intervalle de renouvellement : le tenir
    #: doit être le cas normal pour l'instance ordonnanceur, et sa perte
    #: doit être détectée vite par les autres si elle meurt.
    LOCK_NAME = "scheduler"
    LOCK_TTL_SECONDS = 120
    LOCK_RENEW_SECONDS = 45

    async def start(self):
        """Démarre les boucles planifiées — sur UNE seule instance.

        L'instance qui n'obtient pas le verrou ne démarre RIEN et le guette :
        si l'ordonnanceur meurt, son verrou expire et une autre prend le
        relais en moins de deux minutes.
        """
        if self.tasks:
            return

        if not distributed_lock.acquire(self.LOCK_NAME, self.LOCK_TTL_SECONDS, self._owner):
            logger.info("[Scheduler] Une autre instance ordonnance — surveillance du verrou")
            self.stop_event.clear()
            self.tasks = [asyncio.create_task(self._wait_for_lock_loop())]
            return

        logger.info("[Scheduler] Verrou obtenu — cette instance ordonnance")
        self.stop_event.clear()
        self.tasks = [
            asyncio.create_task(self._renew_lock_loop()),
            asyncio.create_task(self._calls_housekeeping_loop()),
            asyncio.create_task(self._business_loop()),
            asyncio.create_task(self._status_purge_loop()),
        ]

    async def stop(self):
        if not self.tasks:
            return

        self.stop_event.set()
        for task in self.tasks:
            task.cancel()

        await asyncio.gather(*self.tasks, return_exceptions=True)
        self.tasks = []
        logger.info("[Scheduler] Arrêté")

    async def _renew_lock_loop(self):
        """Garde le verrou tant que cette instance vit.

        Sans renouvellement, le verrou expirerait au bout de deux minutes et
        une seconde instance démarrerait ses propres boucles — on aurait
        alors DEUX ordonnanceurs, exactement ce qu'on voulait éviter.
        """
        while not self.stop_event.is_set():
            await asyncio.sleep(self.LOCK_RENEW_SECONDS)
            # `acquire` échoue si le verrou est tenu par quelqu'un d'autre ;
            # on le repose pour prolonger le nôtre.
            distributed_lock.release(self.LOCK_NAME, self._owner)
            distributed_lock.acquire(
                self.LOCK_NAME, self.LOCK_TTL_SECONDS, self._owner
            )

    async def _wait_for_lock_loop(self):
        """Guette la mort de l'ordonnanceur.

        Sans cette veille, une instance qui démarre en second ne reprendrait
        jamais le relais : les tâches planifiées s'arrêteraient avec
        l'instance qui les tenait.
        """
        while not self.stop_event.is_set():
            await asyncio.sleep(self.LOCK_TTL_SECONDS // 2)
            if distributed_lock.acquire(
                self.LOCK_NAME, self.LOCK_TTL_SECONDS, self._owner
            ):
                logger.info("[Scheduler] Verrou repris — cette instance ordonnance")
                self.tasks = []
                await self.start()
                return

    async def _calls_housekeeping_loop(self):
        """Clôt les appels abandonnés et purge les jetons d'action périmés."""
        from app.services.calls import call_housekeeping

        while not self.stop_event.is_set():
            db = SessionLocal()
            try:
                call_housekeeping.run(db)
            except Exception as exc:
                logger.error("Calls housekeeping error: %s", str(exc), exc_info=True)
            finally:
                db.close()
            await self._sleep_interval(60)

    async def _business_loop(self):
        """Pokou Business : remet les webhooks des bots, et une fois l'heure
        émet les relevés postpayés et suspend les impayés.

        Toutes les 20 s pour les webhooks : un message reçu par un bot doit
        arriver chez le développeur en quelques secondes, pas à la prochaine
        heure. Le cycle de facturation, lui, n'a rien à faire plus souvent."""
        await self._sleep_interval(20)
        tours = 0
        while not self.stop_event.is_set():
            try:
                from app.services.business import billing, webhooks

                db = SessionLocal()
                try:
                    bilan = await asyncio.to_thread(webhooks.remettre_en_attente, db)
                    if any(bilan.values()):
                        logger.info("[BUSINESS] webhooks %s", bilan)
                    if tours % 180 == 0:
                        cycle = billing.cycle_mensuel(db)
                        db.commit()
                        if any(cycle.values()):
                            logger.info("[BUSINESS] facturation %s", cycle)
                finally:
                    db.close()
            except Exception as exc:
                logger.error("Business loop error: %s", str(exc), exc_info=True)
            tours += 1
            await self._sleep_interval(20)

    async def _status_purge_loop(self):
        """Purge les statuts expirés (TTL 24 h), toutes les heures — premier
        passage 30 min après le démarrage."""
        await self._sleep_interval(1800)

        while not self.stop_event.is_set():
            try:
                from app.models import DirectMessage, Group, GroupMessage, Status, User
                from app.services.media.media_storage import delete_content

                db = SessionLocal()
                try:
                    expired = db.query(Status).filter(Status.expires_at < datetime.utcnow()).all()
                    purged = 0
                    for status_row in expired:
                        media_asset = status_row.media_asset
                        db.delete(status_row)
                        db.commit()
                        purged += 1

                        if media_asset is None:
                            continue

                        # Le même média peut avoir été partagé ailleurs : on
                        # vérifie TOUTES les tables qui peuvent le référencer
                        # avant de le supprimer. Oublier les messages de
                        # groupe ou les avatars casserait une pièce jointe
                        # encore affichée.
                        referenced = (
                            db.query(DirectMessage)
                            .filter(DirectMessage.media_asset_id == media_asset.id)
                            .first()
                            or db.query(GroupMessage)
                            .filter(GroupMessage.media_asset_id == media_asset.id)
                            .first()
                            or db.query(Status)
                            .filter(Status.media_asset_id == media_asset.id)
                            .first()
                            or db.query(User)
                            .filter(User.avatar_media_id == media_asset.id)
                            .first()
                            or db.query(Group)
                            .filter(Group.avatar_media_id == media_asset.id)
                            .first()
                        )
                        if referenced:
                            continue

                        # delete_content et non un unlink() : le contenu vit
                        # peut-être dans le stockage objet, où un unlink de
                        # chemin local ne supprimerait rien du tout.
                        delete_content(media_asset)
                        db.delete(media_asset)
                        db.commit()

                    if purged > 0:
                        logger.info("[STATUS_PURGE] %d statut(s) expiré(s) supprimé(s)", purged)
                finally:
                    db.close()
            except Exception as exc:
                logger.error("Status purge error: %s", str(exc), exc_info=True)

            await self._sleep_interval(3600)

    # ── Helpers ───────────────────────────────────────────────────────────────

    async def _sleep_interval(self, seconds: float):
        try:
            await asyncio.wait_for(self.stop_event.wait(), timeout=seconds)
        except asyncio.TimeoutError:
            pass


scheduler = Scheduler()
