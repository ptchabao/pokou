"""Construit le corps de création de l'app Kubero « pokou-minio » (MinIO
standalone) dans le pipeline pokou, phase production.

MinIO en mode standalone est un seul processus — parfait pour un cluster
mono-nœud. L'image officielle `quay.io/minio/minio` sert à la fois de
serveur de stockage (port 9000) et de console web (port 9001).

Usage :
    python3 build_minio_json.py > minio.json
    TOKEN=$(curl -s -X POST https://kubero.169.58.195.18.sslip.io/api/auth/login \
      -H 'Content-Type: application/json' \
      -d '{"username":"admin","password":"…"}' | jq -r .access_token)
    curl -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
      --data @minio.json https://kubero.169.58.195.18.sslip.io/api/apps/pokou/production/new
"""
import json
import os
import sys

# ── Identifiants MinIO ──────────────────────────────────────────────────────
# Générés ici une seule fois. Les réutiliser dans build_app_json.py pour
# l'API Pokou.
MINIO_ROOT_USER = os.environ.get("MINIO_ROOT_USER", "pokou-minio-admin")
MINIO_ROOT_PASSWORD = os.environ.get("MINIO_ROOT_PASSWORD", "pKm8wR4yLq2sNx6vDfJe")

sc_root = {
    "allowPrivilegeEscalation": False,
    "readOnlyRootFilesystem": False,
    "runAsNonRoot": False,
    "runAsUser": 0,
    "runAsGroup": 0,
    "capabilities": {"add": [], "drop": []},
}

resources = {
    "requests": {"cpu": "100m", "memory": "256Mi"},
    "limits": {"memory": "512Mi"},
}

app = {
    "name": "pokou-minio",
    "pipeline": "pokou",
    "phase": "production",
    "sleep": "disabled",
    "deploymentstrategy": "docker",
    "buildstrategy": "plain",
    "gitrepo": {
        "admin": False,
        "clone_url": "",
        "ssh_url": "",
    },
    "branch": "",
    "autodeploy": False,
    "podsize": {
        "name": "minio",
        "description": "MinIO standalone (CPU 0.1, mémoire 0.5 Gi)",
        "resources": resources,
    },
    "autoscale": False,
    "autoscaling": {"enabled": False},
    "basicAuth": {"enabled": False, "realm": "Authenticate", "accounts": []},
    "envVars": [
        {"name": "MINIO_ROOT_USER", "value": MINIO_ROOT_USER},
        {"name": "MINIO_ROOT_PASSWORD", "value": MINIO_ROOT_PASSWORD},
        # Créer le bucket « pokou-media » au démarrage (la commande ci-dessous
        # le fait aussi, mais c'est une sécurité).
    ],
    "extraVolumes": [
        {
            "name": "minio-data",
            "emptyDir": False,
            "storageClass": "local-path",
            "size": "20Gi",
            "accessModes": ["ReadWriteOnce"],
            "mountPath": "/data",
        }
    ],
    "cronjobs": [],
    "web": {
        "replicaCount": 1,
        "autoscaling": {
            "minReplicas": 1,
            "maxReplicas": 1,
            "targetCPUUtilizationPercentage": 80,
            "targetMemoryUtilizationPercentage": 80,
        },
    },
    "worker": {
        "replicaCount": 0,
        "autoscaling": {
            "minReplicas": 0,
            "maxReplicas": 0,
            "targetCPUUtilizationPercentage": 80,
            "targetMemoryUtilizationPercentage": 80,
        },
    },
    "image": {
        "containerPort": 9000,
        "pullPolicy": "IfNotPresent",
        "repository": "quay.io/minio/minio",
        "tag": "latest",
        "fetch": {
            "repository": "ghcr.io/kubero-dev/buildpacks/fetch",
            "tag": "v1.2",
            "securityContext": sc_root,
        },
        "build": {
            "repository": "quay.io/minio/minio",
            "tag": "latest",
            "command": "echo 'no build step'",
            "securityContext": sc_root,
        },
        "run": {
            "repository": "quay.io/minio/minio",
            "tag": "latest",
            "command": "minio server /data --console-address :9001",
            "readOnlyAppStorage": False,
            "securityContext": sc_root,
        },
    },
    "imagePullSecrets": [],
    "resources": resources,
    "service": {"port": 80, "type": "ClusterIP"},
    "serviceAccount": {"annotations": {}, "create": True, "name": ""},
    "healthcheck": {
        "enabled": True,
        "path": "/minio/health/live",
        "startupSeconds": 60,
        "timeoutSeconds": 5,
        "periodSeconds": 15,
    },
    "vulnerabilityscan": {
        "enabled": False,
        "schedule": "0 0 * * *",
        "image": {"repository": "aquasec/trivy", "tag": "latest"},
    },
    "ingress": {
        "enabled": False,
        "className": "traefik",
        "annotations": {},
        "hosts": [],
        "tls": [],
    },
    "addons": [],
}

json.dump(app, sys.stdout)
