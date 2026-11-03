#!/bin/sh
# Démarrage Kubero en mode « plain » : le même point d'entrée que l'image
# Docker (attente de la base, migrations, puis API — ou relais Kafka si
# PROC_TYPE=worker). Le code est en lecture seule : pas de .pyc.
set -e
cd "$(dirname "$0")"
export PYTHONPATH="/app/.python${PYTHONPATH:+:$PYTHONPATH}"
export PATH="/app/.python/bin:$PATH"
export PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
exec ./docker-entrypoint.sh "$@"
