"""Stockage objet S3 de Pokou : SeaweedFS dans l'app Kubero « pokou-minio ».

MinIO a cessé de publier ses images Docker gratuites (fin 2025) : le pod
restait en ImagePullBackOff. SeaweedFS est compatible S3 (signature v4),
toujours publié, et l'API Pokou lui parle avec le même code boto3.

L'app garde son nom et son volume de 20 Gi ; seuls l'image, la commande et
le port changent. Les identifiants viennent de secrets.env (S3_ACCESS_KEY,
S3_SECRET_KEY), jamais du dépôt.

Usage : python3 build_seaweed_json.py current.json > seaweed.json
  (current.json = la ressource actuelle lue sur l'API Kubero)
"""
import json
import sys

SEAWEED_TAG = "4.50"

env = {}
for line in open("secrets.env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

s3_config = json.dumps({
    "identities": [{
        "name": "pokou-api",
        "credentials": [{"accessKey": env["S3_ACCESS_KEY"], "secretKey": env["S3_SECRET_KEY"]}],
        "actions": ["Admin", "Read", "Write", "List", "Tagging"],
    }]
})

current = json.load(open(sys.argv[1], encoding="utf-8"))
spec = current["spec"]
# Pas « S3_CONFIG » : SeaweedFS lie automatiquement les variables
# d'environnement à ses options, et celle-ci écrasait -s3.config.
spec["envVars"] = [{"name": "POKOU_S3_IDENTITIES", "value": s3_config}]
spec["podsize"]["description"] = "SeaweedFS S3 (CPU 0.1, mémoire 0.75 Gi)"
spec["podsize"]["resources"] = {"requests": {"cpu": "100m", "memory": "256Mi"}, "limits": {"memory": "768Mi"}}
spec["resources"] = spec["podsize"]["resources"]
img = spec["image"]
img["containerPort"] = 8333
for part in ("build", "run"):
    img[part]["repository"] = "chrislusf/seaweedfs"
    img[part]["tag"] = SEAWEED_TAG
img["repository"] = "chrislusf/seaweedfs"
img["tag"] = SEAWEED_TAG
img["build"]["command"] = "echo 'no build step'"
img["run"]["command"] = (
    "printf '%s' \"$POKOU_S3_IDENTITIES\" > /tmp/s3.json && "
    "exec weed server -dir=/data -ip.bind=0.0.0.0 -master.volumeSizeLimitMB=1024 "
    "-volume.max=0 -s3 -s3.port=8333 -s3.config=/tmp/s3.json"
)
# Sonde de santé : celle de MinIO (/minio/health/live) répond 404 ici, et
# Kubernetes redémarrait le pod en boucle. SeaweedFS S3 expose /healthz.
spec["healthcheck"] = {
    "enabled": True,
    "path": "/healthz",
    "periodSeconds": 15,
    "startupSeconds": 90,
    "timeoutSeconds": 5,
}
json.dump(spec, sys.stdout)
