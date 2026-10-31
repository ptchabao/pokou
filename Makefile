# Raccourcis de développement. `make help` pour la liste.
BACKEND := backend
MOBILE  := mobile
PY      := $(BACKEND)/.venv/bin/python

.PHONY: help setup backend-setup backend-run backend-test backend-lint migrate migration up down mobile-setup mobile-run mobile-test mobile-analyze

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

setup: backend-setup mobile-setup ## Installe backend et mobile

backend-setup: ## Crée le virtualenv et installe les dépendances
	cd $(BACKEND) && python3.12 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt

backend-run: ## Lance l'API en local (http://localhost:8000/docs)
	cd $(BACKEND) && .venv/bin/uvicorn app.main:app --reload --port 8000

backend-test: ## Lance la suite de tests du backend
	cd $(BACKEND) && .venv/bin/python -m pytest

backend-lint: ## Vérifie le style du backend
	cd $(BACKEND) && .venv/bin/ruff check app tests

migrate: ## Applique les migrations Alembic
	cd $(BACKEND) && .venv/bin/alembic upgrade head

migration: ## Génère une migration : make migration m="message"
	cd $(BACKEND) && .venv/bin/alembic revision --autogenerate -m "$(m)"

up: ## Démarre PostgreSQL, Redis, MinIO et l'API (Docker)
	docker compose up --build

down: ## Arrête l'environnement Docker
	docker compose down

mobile-setup: ## Récupère les dépendances Flutter
	cd $(MOBILE) && flutter pub get

mobile-run: ## Lance l'app contre l'API locale (émulateur Android)
	cd $(MOBILE) && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

mobile-test: ## Lance les tests Flutter
	cd $(MOBILE) && flutter test

mobile-analyze: ## Analyse statique Flutter
	cd $(MOBILE) && flutter analyze
