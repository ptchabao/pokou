# Pokou API

FastAPI · SQLAlchemy 2 · Alembic · PostgreSQL (SQLite en local) · Redis.

## Développement

```bash
python3.12 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env            # facultatif en local
.venv/bin/uvicorn app.main:app --reload --port 8000
```

Documentation interactive : http://localhost:8000/docs

## Tests

```bash
.venv/bin/python -m pytest
```

Chaque suite crée sa propre base SQLite jetable. `tests/conftest.py` neutralise
le stockage objet et les passerelles WhatsApp avant tout import : un `pytest`
lancé avec un vrai `.env` n'écrit ni dans le bucket de production ni vers de
vrais numéros.

## Migrations

```bash
.venv/bin/alembic upgrade head                          # appliquer
.venv/bin/alembic revision --autogenerate -m "message"  # après un changement de modèle
```

L'image Docker applique `alembic upgrade head` au démarrage (voir
`docker-entrypoint.sh`).

## Où ranger quoi

| Dossier | Contenu |
|---|---|
| `app/api/v1/<domaine>/` | Routes HTTP : validation, autorisation, appel des services. |
| `app/services/<domaine>/` | Logique métier, sans dépendance à FastAPI. |
| `app/models/<domaine>.py` | Tables. Toutes réexportées par `app.models`. |
| `app/core/` | Transverse : config, base, sécurité, RBAC, scheduler, métriques. |
| `app/utils/` | Fonctions pures, sans état. |

Une nouvelle famille de routes s'enregistre dans `app/api/router.py`.

## Tâches planifiées

Une seule instance à la fois les exécute (verrou distribué Redis ; sans
Redis, l'instance unique les exécute toutes) — voir `app/core/scheduler.py` : ménage des appels, webhooks et
facturation de Pokou Business, purge des statuts expirés.

## Services externes

| Service | Réglages | Rôle |
|---|---|---|
| NGH | `NGH_API_KEY`, `NGH_API_SECRET`, `SMS_SENDER_ID` | SMS des codes de connexion |
| Passerelle WhatsApp / Twilio | `WHATSAPP_SERVICE_URL`, `TWILIO_*` | second canal des codes |
| Firebase | `FCM_ENABLED`, `FIREBASE_CREDENTIALS_*` | notifications push |
| LiveKit Cloud | `LIVEKIT_*` | appels audio/vidéo |
| S3 / MinIO | `S3_*` | pièces jointes |
| Semoa | réglages système `semoa_*`, `PUBLIC_API_URL` | Mobile Money |
| Ollama / Gemini / Groq… | `OLLAMA_*`, `GEMINI_*`… | Mode Bouclier |
