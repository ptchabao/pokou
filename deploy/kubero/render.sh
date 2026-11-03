#!/usr/bin/env bash
# Produit la ressource KuberoApp de l'API Pokou, et l'applique avec --apply.
#
# Usage : deploy/kubero/render.sh <image:tag> [--apply]
#   ex.  deploy/kubero/render.sh ghcr.io/pokou/pokou-api:1.20.0 --apply
#
# Réglages (variables d'environnement, valeurs par défaut entre crochets) :
#   PIPELINE [pokou]  PHASE [production]  APP_NAME [pokou-api]
#   NAMESPACE [$PIPELINE-$PHASE]  API_HOST [api.pok.app]  PUBLIC_HOST [pok.app]
#   CLUSTER_ISSUER [letsencrypt-prod]  WORKER_REPLICAS [1, 0 sans Kafka]
#   IMAGE_PULL_SECRET [vide : image publique]
#
# Les secrets ne sont jamais écrits dans le dépôt : ils sont lus dans
# secrets.env (copie remplie de secrets.example.env, ignorée par git).
set -euo pipefail

IMAGE="${1:?Usage : $0 <image:tag> [--apply]}"
APPLY="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$HERE/secrets.env" ]; then
  echo "❌ $HERE/secrets.env absent (voir secrets.example.env)." >&2
  exit 1
fi

export PIPELINE="${PIPELINE:-pokou}"
export PHASE="${PHASE:-production}"
export APP_NAME="${APP_NAME:-pokou-api}"
export NAMESPACE="${NAMESPACE:-$PIPELINE-$PHASE}"
export API_HOST="${API_HOST:-api.pok.app}"
export PUBLIC_HOST="${PUBLIC_HOST:-pok.app}"
export CLUSTER_ISSUER="${CLUSTER_ISSUER:-letsencrypt-prod}"
export WORKER_REPLICAS="${WORKER_REPLICAS:-1}"
export IMAGE_PULL_SECRET="${IMAGE_PULL_SECRET:-}"
export IMAGE_REPOSITORY="${IMAGE%:*}"
export IMAGE_TAG="${IMAGE##*:}"
if [ "$IMAGE_REPOSITORY" = "$IMAGE" ] || [ -z "$IMAGE_TAG" ]; then
  echo "❌ Donnez une image avec son étiquette, jamais « latest » implicite : <dépôt>:<version>." >&2
  exit 1
fi

RENDERED="$(python3 - "$HERE/app.template.yaml" "$HERE/config.env" "$HERE/secrets.env" <<'PY'
import json, os, re, sys

template, config_path, secrets_path = sys.argv[1:4]

def read_env(path):
    values = {}
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "=" not in line:
            sys.exit(f"❌ {path}:{number} : ligne sans « = »")
        key, value = line.split("=", 1)
        values[key.strip()] = value
    return values

env = {**read_env(config_path), **read_env(secrets_path)}
# Un certificat tient sur plusieurs lignes : écrit « \n » dans le fichier,
# il est rendu ici avec de vrais sauts de ligne.
if env.get("KAFKA_SSL_CA_PEM"):
    env["KAFKA_SSL_CA_PEM"] = env["KAFKA_SSL_CA_PEM"].replace("\\n", "\n")
if os.environ["WORKER_REPLICAS"] == "0":
    env["KAFKA_BOOTSTRAP_SERVERS"] = ""

missing = [k for k in ("SECRET_KEY", "WEBHOOK_HMAC_SECRET", "DATABASE_URL", "S3_ENDPOINT_URL", "S3_ACCESS_KEY", "S3_SECRET_KEY")
           if not env.get(k)]
if missing:
    sys.exit("❌ Obligatoires et vides dans secrets.env : " + ", ".join(missing))

pull = os.environ["IMAGE_PULL_SECRET"]
os.environ["IMAGE_PULL_SECRETS"] = json.dumps([{"name": pull}] if pull else [])

text = open(template, encoding="utf-8").read()
text = re.sub(r"\$\{(\w+)\}", lambda m: os.environ[m.group(1)], text)
# JSON est du YAML valide : chaque valeur est citée telle quelle, sans
# risque qu'un « : » ou un « # » d'un mot de passe ne casse le document.
env_vars = [{"name": k, "value": v} for k, v in env.items() if v != ""]
print(text.rstrip("\n") + "\n  envVars: " + json.dumps(env_vars, ensure_ascii=False))
PY
)"

if [ "$APPLY" != "--apply" ]; then
  # Sans --apply : le document sur la sortie, secrets compris — à ne pas
  # coller dans un ticket.
  printf '%s\n' "$RENDERED"
  exit 0
fi

echo "→ $APP_NAME ($IMAGE) dans $NAMESPACE"
printf '%s\n' "$RENDERED" | kubectl -n "$NAMESPACE" apply -f -
echo "→ Attente du déploiement web (migrations comprises)"
kubectl -n "$NAMESPACE" rollout status "deployment/$APP_NAME-web" --timeout=900s \
  || kubectl -n "$NAMESPACE" get deployments
echo "✅ Appliqué : $IMAGE"
