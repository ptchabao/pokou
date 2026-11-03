"""Construit le corps de création de l'app Kubero `livekit` (serveur d'appels
audio et vidéo de Pokou), à partir de secrets.env.
Usage : python3 build_livekit_json.py > livekit.json  (fichier ignoré par git)

Kubero n'expose qu'un port HTTP par application. LiveKit a besoin en plus
de ports MÉDIA joignables directement depuis les téléphones : 7881/TCP et
7882/UDP (un seul port UDP, multiplexé). Ils sont ouverts par un Service
LoadBalancer — sur k3s, ServiceLB les publie sur l'adresse du nœud. Ce
Service passe par les « addons » de l'application : le chart de Kubero
rend tels quels les objets de `resourceDefinitions`.
"""
import json, sys

env = {}
for line in open("secrets.env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

NODE_IP = "169.58.195.18"
HOST = f"livekit.{NODE_IP}.sslip.io"

config = f"""port: 7880
rtc:
  tcp_port: 7881
  udp_port: 7882
  use_external_ip: false
  node_ip: {NODE_IP}
keys:
  {env['LIVEKIT_API_KEY']}: {env['LIVEKIT_API_SECRET']}
logging:
  level: info
"""

resources = {"requests": {"cpu": "250m", "memory": "256Mi"}, "limits": {"memory": "1Gi"}}
sc = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "runAsNonRoot": True,
      "runAsUser": 1000, "runAsGroup": 1000, "capabilities": {"add": [], "drop": ["ALL"]}}

app = {
    "name": "livekit",
    "pipeline": "pokou",
    "phase": "production",
    "sleep": "disabled",
    "deploymentstrategy": "docker",
    "buildstrategy": "plain",
    "gitrepo": {"admin": False, "clone_url": "", "ssh_url": ""},
    "branch": "",
    "autodeploy": False,
    "podsize": {"name": "livekit", "description": "LiveKit (CPU 0.25, mémoire 1 Gi)", "resources": resources},
    "autoscale": False,
    "autoscaling": {"enabled": False},
    "basicAuth": {"enabled": False, "realm": "Authenticate", "accounts": []},
    "envVars": [{"name": "LIVEKIT_CONFIG", "value": config}],
    "extraVolumes": [],
    "cronjobs": [],
    # Un seul serveur : le port UDP unique est publié sur le nœud.
    "web": {"replicaCount": 1, "autoscaling": {"minReplicas": 1, "maxReplicas": 1,
            "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "worker": {"replicaCount": 0, "autoscaling": {"minReplicas": 0, "maxReplicas": 0,
               "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "image": {
        "containerPort": 7880,
        "pullPolicy": "IfNotPresent",
        "repository": "livekit/livekit-server",
        "tag": "v1.13.11",
        "fetch": {"repository": "ghcr.io/kubero-dev/buildpacks/fetch", "tag": "v1.2", "securityContext": sc},
        "build": {"repository": "livekit/livekit-server", "tag": "v1.13.11", "securityContext": sc},
        "run": {"repository": "livekit/livekit-server", "tag": "v1.13.11", "readOnlyAppStorage": True, "securityContext": sc},
    },
    "imagePullSecrets": [],
    "resources": resources,
    "service": {"port": 80, "type": "ClusterIP"},
    "serviceAccount": {"annotations": {}, "create": True, "name": ""},
    "healthcheck": {"enabled": True, "path": "/", "startupSeconds": 90, "timeoutSeconds": 3, "periodSeconds": 10},
    "vulnerabilityscan": {"enabled": False, "schedule": "0 0 * * *",
                          "image": {"repository": "aquasec/trivy", "tag": "latest"}},
    "ingress": {
        "enabled": True,
        "className": "traefik",
        "annotations": {"cert-manager.io/cluster-issuer": "letsencrypt-prod", "kubernetes.io/tls-acme": "true"},
        "hosts": [{"host": HOST, "paths": [{"path": "/", "pathType": "Prefix"}]}],
        "tls": [{"hosts": [HOST], "secretName": "livekit-tls"}],
    },
    "addons": [{
        "id": "pokou-livekit-rtc", "kind": "Service", "displayName": "LiveKit RTC (ports média)",
        "icon": "", "env": [], "version": {"latest": "1"},
        "resourceDefinitions": {"Service": {
            "apiVersion": "v1", "kind": "Service",
            "metadata": {"name": "livekit-rtc"},
            "spec": {
                "type": "LoadBalancer",
                "externalTrafficPolicy": "Local",
                # Les pods « web » du chart : instance = <app>-web.
                "selector": {"app.kubernetes.io/name": "kuberoapp", "app.kubernetes.io/instance": "livekit-web"},
                "ports": [
                    {"name": "rtc-tcp", "port": 7881, "targetPort": 7881, "protocol": "TCP"},
                    {"name": "rtc-udp", "port": 7882, "targetPort": 7882, "protocol": "UDP"},
                ],
            },
        }},
    }],
}
json.dump(app, sys.stdout)
