#!/bin/sh
# Construction Kubero en mode « plain » (pas d'image Docker) : Kubero clone
# le dépôt dans /app, puis lance ce script dans une image Python. Les
# dépendances vont dans /app/.python, que le conteneur d'exécution lit
# ensuite en lecture seule. Voir docs/deploiement-kubero.md.
set -e
cd "$(dirname "$0")"
python3 -m pip install --no-cache-dir --disable-pip-version-check \
  --target /app/.python -r requirements.txt
chmod +x docker-entrypoint.sh kubero-run.sh
echo "Dépendances installées dans /app/.python"
