"""Point d'entrée de l'API Pokou."""
import logging
import time
import uuid
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

from app import models  # noqa: F401 — enregistre toutes les tables sur Base.metadata
from app.services.events import live_updates
from app.api.router import api_router, public_router
from app.core.config import get_settings
from app.core.database import Base, engine
from app.core.log_redaction import install_secret_redaction
from app.core.metrics import api_request_duration, api_requests_total
from app.core.scheduler import scheduler
from app.core.startup_checks import ensure_no_review_backdoor, ensure_no_weak_secrets
from app.middleware.rate_limit import RateLimitMiddleware

__all__ = ["app", "ensure_no_review_backdoor", "ensure_no_weak_secrets"]

APP_VERSION = "1.0.0"

settings = get_settings()

if settings.environment == "production":
    logging.basicConfig(level=settings.log_level.upper())
else:
    logging.basicConfig(
        level=settings.log_level.upper(),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

# Le jeton d'accès voyage dans l'URL du WebSocket (voir api/v1/messaging/ws.py) :
# sans ce filtre, un JWT valable s'écrit en clair dans le journal d'accès, et
# de là dans la supervision, le reverse proxy et les exports de débogage.
install_secret_redaction()

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Pokou API...")
    ensure_no_weak_secrets(settings)
    ensure_no_review_backdoor(settings)

    # Filet pour le développement et les tests ; en production, le schéma
    # est posé par `alembic upgrade head` (voir docker-entrypoint.sh).
    Base.metadata.create_all(bind=engine)

    # Le registre temps réel partagé — voir services/messaging/ws_registry.py.
    # Démarré AVANT le scheduler : une tâche planifiée peut vouloir pousser un
    # évènement dès son premier tour.
    from app.api.v1.messaging.ws import manager as ws_manager
    from app.services.messaging.ws_registry import registry as ws_registry

    await ws_registry.start(ws_manager.deliver_local)
    await scheduler.start()

    from app.services.notifications.push_service import push_status_message

    logger.info("[Push] FCM: %s", push_status_message())

    yield

    logger.info("Shutting down Pokou API...")
    await scheduler.stop()
    # Retrait PROPRE des présences détenues ici : sans lui, les gens
    # connectés à cette instance restent « en ligne » jusqu'à l'expiration,
    # et les messages qui leur sont destinés partent dans le vide.
    await ws_registry.stop()


app = FastAPI(
    title="Pokou API",
    description="Messagerie, communautés, appels et marché de Pokou.",
    version=APP_VERSION,
    lifespan=lifespan,
)

# Avant CORS : une requête refusée pour excès de débit n'a pas besoin qu'on
# calcule ses en-têtes d'origine, et la refuser au plus tôt est tout
# l'intérêt d'un plafond.
app.add_middleware(RateLimitMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["X-Trace-ID"],
    max_age=600,
)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)


@app.middleware("http")
async def add_trace_id_and_metrics(request: Request, call_next):
    """Ajoute un X-Trace-ID à chaque réponse et alimente les métriques."""
    # Les routes synchrones (pool de threads) poussent le temps réel dans
    # CETTE boucle — voir live_updates.py.
    live_updates.bind_loop()
    if request.method == "OPTIONS":
        return await call_next(request)

    start_time = time.time()
    trace_id = str(uuid.uuid4())
    request.state.trace_id = trace_id

    # Le gabarit de la route plutôt que le chemin brut : sans lui, chaque
    # identifiant crée sa propre série dans Prometheus.
    endpoint = request.url.path
    if hasattr(request.scope.get("route"), "path"):
        endpoint = request.scope["route"].path

    status_code = "500"
    try:
        response = await call_next(request)
        status_code = str(response.status_code)
        response.headers["X-Trace-ID"] = trace_id
        return response
    finally:
        api_requests_total.labels(endpoint=endpoint, method=request.method, status_code=status_code).inc()
        api_request_duration.labels(endpoint=endpoint, method=request.method).observe(time.time() - start_time)


@app.exception_handler(status.HTTP_404_NOT_FOUND)
async def not_found_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={
            "error_code": "not_found",
            "message": "Resource not found",
            "trace_id": getattr(request.state, "trace_id", "unknown"),
        },
    )


@app.exception_handler(status.HTTP_500_INTERNAL_SERVER_ERROR)
async def internal_error_handler(request: Request, exc: Exception):
    logger.error("Internal server error: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error_code": "internal_error",
            "message": "Internal server error",
            "trace_id": getattr(request.state, "trace_id", "unknown"),
        },
    )


# Temps réel Kory / Honam : écoute des commits (voir live_updates.py).
live_updates.install()

app.include_router(api_router)
app.include_router(public_router)


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "healthy", "version": APP_VERSION, "environment": settings.environment}


@app.get("/health/ready", tags=["health"])
def readiness_check():
    """Sonde de disponibilité (Kubernetes `readinessProbe`).

    `/health` dit que le processus vit ; celle-ci dit qu'il peut SERVIR :
    sans base, la pod est retirée du Service au lieu de répondre 500, et
    remise dès que la base revient — sans redémarrage, contrairement à une
    sonde de vie qui échouerait pour la même raison.
    """
    from sqlalchemy import text

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception:
        return JSONResponse(status_code=503, content={"status": "unavailable", "database": "down"})
    return {"status": "ready"}


@app.get("/", tags=["root"])
async def root():
    return {"name": "Pokou API", "version": APP_VERSION, "docs": "/docs", "openapi": "/openapi.json"}
