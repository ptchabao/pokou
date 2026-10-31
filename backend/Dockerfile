FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# postgresql-client : `pg_isready`, utilisé par docker-entrypoint.sh pour
# attendre la base avant de migrer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN chmod +x docker-entrypoint.sh

# Un utilisateur sans privilège, au numéro FIXE : la politique de sécurité des
# pods Kubernetes (`runAsNonRoot`) vérifie un UID, pas un nom.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin pokou \
    && mkdir -p /app/media_storage \
    && chown -R pokou:pokou /app/media_storage
USER 10001

EXPOSE 8000

# Applique les migrations Alembic en attente (sauf RUN_MIGRATIONS=0), puis
# démarre l'API. Le relais Kafka utilise la même image :
#   docker run … pokou-api python -m app.workers.outbox_relay
ENTRYPOINT ["./docker-entrypoint.sh"]
