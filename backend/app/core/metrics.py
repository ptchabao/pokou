"""Métriques Prometheus de l'API, exposées sur GET /api/v1/metrics."""
from fastapi import APIRouter, Response
from prometheus_client import CollectorRegistry, Counter, Histogram, generate_latest

registry = CollectorRegistry()

api_requests_total = Counter(
    "pokou_api_requests_total",
    "Total number of API requests",
    ["endpoint", "method", "status_code"],
    registry=registry,
)

api_request_duration = Histogram(
    "pokou_api_request_duration_seconds",
    "API request duration in seconds",
    ["endpoint", "method"],
    registry=registry,
)

router = APIRouter(tags=["monitoring"])


@router.get("/metrics", response_class=Response, include_in_schema=False)
async def metrics():
    return Response(content=generate_latest(registry), media_type="text/plain; version=0.0.4")
