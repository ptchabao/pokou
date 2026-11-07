"""Construit le corps de création de l'app Kubero `pokou-api` (mode plain),
à partir de secrets.env. Usage : python3 build_app_json.py > app.json"""
import json, sys

env = {}
for line in open("secrets.env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

HOST = "apipokou.cabinet-p-et-associes.com"
sc_root = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": False,
           "runAsNonRoot": False, "runAsUser": 0, "runAsGroup": 0, "capabilities": {"add": [], "drop": []}}
sc_run = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
          "runAsNonRoot": True, "runAsUser": 10001, "runAsGroup": 10001, "capabilities": {"add": [], "drop": ["ALL"]}}

app_env = {
    "ENVIRONMENT": "production",
    "RUN_MIGRATIONS": "1",
    "UVICORN_WORKERS": "2",
    "FORWARDED_ALLOW_IPS": "*",
    "DB_POOL_SIZE": "5",
    "DB_MAX_OVERFLOW": "5",
    "PUBLIC_API_URL": f"https://{HOST}",
    # Pas de stockage objet sur ce cluster : les pièces jointes vont sur un
    # volume persistant (local-path).
    "MEDIA_STORAGE_DIR": "/data/media",
    "KAFKA_BOOTSTRAP_SERVERS": "pokou-kafka:9092",
    "KAFKA_SECURITY_PROTOCOL": "PLAINTEXT",
    "KAFKA_TOPIC_PREFIX": "pokou",
    "SECRET_KEY": env["SECRET_KEY"],
    "WEBHOOK_HMAC_SECRET": env["WEBHOOK_HMAC_SECRET"],
    "DATABASE_URL": env["DATABASE_URL"],
    "REDIS_URL": env["REDIS_URL"],
}
# Appels audio et vidéo : l'app Kubero « livekit » (build_livekit_json.py).
# L'API ne fait que signer les jetons ; le téléphone se connecte lui-même à
# cette adresse publique.
if env.get("LIVEKIT_API_KEY") and env.get("LIVEKIT_API_SECRET"):
    app_env.update({
        "LIVEKIT_ENABLED": "true",
        "LIVEKIT_URL": "wss://rtc.cabinet-p-et-associes.com",
        "LIVEKIT_API_KEY": env["LIVEKIT_API_KEY"],
        "LIVEKIT_API_SECRET": env["LIVEKIT_API_SECRET"],
    })
else:
    app_env["LIVEKIT_ENABLED"] = "false"
for k in ("TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_SMS_FROM", "TWILIO_MESSAGING_SERVICE_SID"):
    if env.get(k):
        app_env[k] = env[k]

# Notifications push (FCM) : allumées dès qu'une clé de compte de service
# Firebase est fournie — soit en JSON sur une ligne dans secrets.env
# (FIREBASE_CREDENTIALS_JSON=…), soit par un fichier firebase-service-account.json
# posé à côté de ce script (gitignoré). Sans clé, aucune notification ni
# sonnerie n'arrive quand l'application est fermée.
import os
_fb = env.get("FIREBASE_CREDENTIALS_JSON", "").strip()
if not _fb and os.path.exists("firebase-service-account.json"):
    _fb = json.dumps(json.load(open("firebase-service-account.json", encoding="utf-8")))
if _fb:
    app_env["FCM_ENABLED"] = "true"
    app_env["FIREBASE_CREDENTIALS_JSON"] = _fb
else:
    app_env["FCM_ENABLED"] = "false"
# Baba : un ou plusieurs modèles de langage, essayés dans l'ordre
# (voir app/services/baba). Sans clé, Baba répond par la FAQ.
for k in ("GEMINI_API_KEY", "GROQ_API_KEY", "DEEPSEEK_API_KEY", "GROK_API_KEY"):
    if env.get(k):
        app_env[k] = env[k]
        app_env[k.replace("_API_KEY", "_ENABLED")] = "true"

# Stockage objet : SeaweedFS (S3) dans l'app « pokou-minio », joignable
# par son service interne. Les pièces jointes y sont écrites dès que les
# clés sont présentes (voir app/services/media/object_storage.py).
if env.get("S3_ACCESS_KEY") and env.get("S3_SECRET_KEY"):
    app_env.update({
        "S3_ENDPOINT_URL": "http://pokou-minio-kuberoapp:80",
        "S3_ACCESS_KEY": env["S3_ACCESS_KEY"],
        "S3_SECRET_KEY": env["S3_SECRET_KEY"],
        "S3_BUCKET": env.get("S3_BUCKET", "pokou-media"),
    })

resources = {"requests": {"cpu": "250m", "memory": "384Mi"}, "limits": {"memory": "768Mi"}}

app = {
    "name": "pokou-api",
    "pipeline": "pokou",
    "phase": "production",
    "sleep": "disabled",
    "deploymentstrategy": "git",
    "buildstrategy": "plain",
    "gitrepo": {"admin": False, "clone_url": "https://github.com/ptchabao/pokou.git",
                "ssh_url": "git@github.com:ptchabao/pokou.git"},
    "branch": "main",
    "autodeploy": False,
    "podsize": {"name": "pokou", "description": "Pokou (CPU 0.25, mémoire 0.75 Gi)", "resources": resources},
    "autoscale": False,
    "autoscaling": {"enabled": False},
    "basicAuth": {"enabled": False, "realm": "Authenticate", "accounts": []},
    "envVars": [{"name": k, "value": v} for k, v in app_env.items()],
    "extraVolumes": [{"name": "pokou-media", "emptyDir": False, "storageClass": "local-path",
                      "size": "10Gi", "accessModes": ["ReadWriteOnce"], "mountPath": "/data"}],
    "cronjobs": [],
    "web": {"replicaCount": 1, "autoscaling": {"minReplicas": 1, "maxReplicas": 3,
            "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "worker": {"replicaCount": 1, "autoscaling": {"minReplicas": 1, "maxReplicas": 1,
               "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "image": {
        "containerPort": 8000,
        "pullPolicy": "IfNotPresent",
        "repository": "python",
        "tag": "3.12-slim",
        "fetch": {"repository": "ghcr.io/kubero-dev/buildpacks/fetch", "tag": "v1.2", "securityContext": sc_root},
        "build": {"repository": "python", "tag": "3.12-slim", "command": "./backend/kubero-build.sh",
                  "securityContext": sc_root},
        "run": {"repository": "python", "tag": "3.12-slim", "command": "./backend/kubero-run.sh",
                "readOnlyAppStorage": True, "securityContext": sc_run},
    },
    "imagePullSecrets": [],
    "resources": resources,
    "service": {"port": 80, "type": "ClusterIP"},
    "serviceAccount": {"annotations": {}, "create": True, "name": ""},
    "healthcheck": {"enabled": True, "path": "/health", "startupSeconds": 90, "timeoutSeconds": 3, "periodSeconds": 10},
    "vulnerabilityscan": {"enabled": False, "schedule": "0 0 * * *",
                          "image": {"repository": "aquasec/trivy", "tag": "latest"}},
    "ingress": {
        "enabled": True,
        "className": "traefik",
        "annotations": {"cert-manager.io/cluster-issuer": "letsencrypt-prod", "kubernetes.io/tls-acme": "true"},
        "hosts": [{"host": HOST, "paths": [{"path": "/", "pathType": "Prefix"}]}],
        "tls": [{"hosts": [HOST], "secretName": "pokou-api-tls"}],
    },
    "addons": [
        {"id": "kubero-operator", "kind": "KuberoAddonPostgres", "displayName": "PostgreSQL",
         "icon": "/img/addons/pgsql.svg", "env": [], "version": {"latest": "0.2.2"},
         "resourceDefinitions": {"KuberoAddonPostgres": {
             "apiVersion": "application.kubero.dev/v1alpha1", "kind": "KuberoAddonPostgres",
             "metadata": {"name": "pokou-postgres"},
             "spec": {"postgres": {
                 "image": {"tag": "17.6"}, "replicaCount": 1, "resources": {},
                 "auth": {"enablePostgresUser": True, "postgresPassword": env["POSTGRES_ADMIN_PASSWORD"],
                          "username": "pokou", "password": env["POSTGRES_PASSWORD"], "database": "pokou"},
                 "persistence": {"enabled": True, "size": "10Gi", "storageClass": "local-path",
                                 "accessModes": ["ReadWriteOnce"]}}}}}},
        {"id": "kubero-operator", "kind": "KuberoAddonRedis", "displayName": "Redis",
         "icon": "/img/addons/redis.svg", "env": [], "version": {"latest": "0.2.2"},
         "resourceDefinitions": {"KuberoAddonRedis": {
             "apiVersion": "application.kubero.dev/v1alpha1", "kind": "KuberoAddonRedis",
             "metadata": {"name": "pokou-redis"},
             "spec": {"redis": {
                 "image": {"tag": "8"}, "metrics": {"enabled": False}, "resources": {},
                 "useDeploymentWhenNonHA": True,
                 "haMode": {"enabled": False, "masterGroupName": "redisha", "quorum": "2", "replicas": "3", "useDnsNames": False},
                 "storage": {"accessModes": ["ReadWriteOnce"], "className": "local-path", "keepPvc": False,
                             "requestedSize": "2Gi", "volumeName": "redis-data"}}}}}},
        {"id": "kubero-operator", "kind": "KuberoKafka", "displayName": "Kafka (Bitnami)",
         "icon": "/img/addons/kafka.svg", "env": [], "version": {"latest": "0.2.2"},
         "resourceDefinitions": {"KuberoKafka": {
             "apiVersion": "application.kubero.dev/v1alpha1", "kind": "KuberoKafka",
             "metadata": {"name": "pokou-kafka"},
             "spec": {"kafka": {
                 "global": {"storageClass": "local-path"},
                 "persistence": {"size": "8Gi"},
                 # L'image d'origine (docker.io/bitnami/zookeeper) n'existe
                 # plus : Bitnami a déplacé ses images vers bitnamilegacy.
                 "zookeeper": {"image": {"repository": "bitnamilegacy/zookeeper"}, "persistence": {"size": "2Gi"}},
                 "auth": {"clientProtocol": "plaintext", "interBrokerProtocol": "plaintext"}}}}}},
    ],
}
json.dump(app, sys.stdout)
