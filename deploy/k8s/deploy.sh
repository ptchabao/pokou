#!/usr/bin/env bash
# Déploie une version de l'API Pokou sur Kubernetes, dans le bon ordre :
#   1. migrations (Job, attendu) ;  2. API et relais (déploiement progressif).
#
# Usage : deploy/k8s/deploy.sh <image:tag>   (ex. ghcr.io/pokou/pokou-api:1.19.0)
set -euo pipefail

IMAGE="${1:?Usage : $0 <image:tag>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$HERE/overlays/prod"
NS=pokou

if [ ! -f "$OVERLAY/secrets.env" ]; then
  echo "❌ $OVERLAY/secrets.env absent (voir secrets.example.env)."
  exit 1
fi

echo "→ Image : $IMAGE"

echo "→ Namespace, configuration et secrets"
# Ils doivent exister AVANT le Job de migration, qui les lit. On n'applique
# donc d'abord que ces trois types, extraits du rendu de l'overlay.
RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT
# L'image est posée sur le rendu : `kubectl kustomize` suffit, sans
# dépendre du binaire `kustomize` ni modifier les fichiers du dépôt.
kubectl kustomize "$OVERLAY" | sed -E "s#image: [^ ]*pokou-api[^ ]*#image: $IMAGE#" > "$RENDERED"
python3 - "$RENDERED" <<'PY' | kubectl apply -f -
import re, sys
docs = open(sys.argv[1]).read().split("\n---\n")
keep = ("Namespace", "ConfigMap", "Secret", "ServiceAccount")
print("\n---\n".join(d for d in docs if re.search(r"^kind: (%s)$" % "|".join(keep), d, re.M)))
PY

echo "→ Migrations"
kubectl -n "$NS" delete job pokou-migrate --ignore-not-found --wait=true
sed "s#image: pokou-api#image: $IMAGE#" "$HERE/base/migrate-job.yaml" | kubectl -n "$NS" apply -f -
if ! kubectl -n "$NS" wait --for=condition=complete job/pokou-migrate --timeout=900s; then
  echo "❌ Migration en échec — rien d'autre n'est déployé. Journal :"
  kubectl -n "$NS" logs job/pokou-migrate --tail=100 || true
  exit 1
fi

echo "→ API et relais"
kubectl apply -f "$RENDERED"
kubectl -n "$NS" rollout status deployment/pokou-api --timeout=600s
kubectl -n "$NS" rollout status deployment/pokou-outbox-relay --timeout=300s
echo "✅ Déployé : $IMAGE"
