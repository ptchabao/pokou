"""Construit le corps de création de l'app Kubero `mailu` : le serveur de
messagerie de pokou.app (webmail et administration sur hermes.pokou.app).
Usage : python3 build_mailu_json.py > mailu.json   (fichier ignoré par git)

Mailu, ce sont plusieurs conteneurs : front (nginx, ports mail), admin,
imap (dovecot), smtp (postfix), antispam (rspamd), webmail (roundcube),
redis et un résolveur DNS qui valide DNSSEC (unbound), exigé par Mailu.
Kubero ne gère qu'un conteneur par application : l'app elle-même porte
redis, et les autres sont des objets Kubernetes passés tels quels par les
« addons » (comme le Service des ports média de LiveKit).

Adresses fixes : chaque composant a un Service à IP fixe (10.43.200.x), et
les pods n'utilisent QUE le résolveur unbound (DNSSEC) : ils se joignent
par ces IP, sans dépendre du DNS du cluster.

Prérequis hors du cluster (voir docs/deploiement-kubero.md, « Messagerie ») :
enregistrement A hermes.pokou.app NON proxifié, MX, SPF, DKIM, DMARC,
reverse DNS chez l'hébergeur, ports 25/465/587/993 ouverts.
"""
import json
import sys

env = {}
for line in open("secrets.env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

HOST = "hermes.pokou.app"
DOMAIN = "pokou.app"
VERSION = "2024.06"
PODS = "10.42.0.0/16"  # réseau des pods k3s
IP = {
    "front": "10.43.200.10", "admin": "10.43.200.11", "imap": "10.43.200.12",
    "smtp": "10.43.200.13", "antispam": "10.43.200.14", "webmail": "10.43.200.15",
    "redis": "10.43.200.16", "resolver": "10.43.200.53",
}

common = {
    "DOMAIN": DOMAIN,
    "HOSTNAMES": HOST,
    "POSTMASTER": "admin",
    "SECRET_KEY": env["MAILU_SECRET_KEY"],
    "SUBNET": PODS,
    # Traefik termine le HTTPS du webmail ; les ports mail utilisent le
    # certificat de cert-manager, monté dans front.
    "TLS_FLAVOR": "mail",
    "REAL_IP_HEADER": "X-Forwarded-For",
    "REAL_IP_FROM": PODS,
    "MESSAGE_SIZE_LIMIT": "50000000",
    "ANTIVIRUS": "none",
    "WEBMAIL": "roundcube",
    "ADMIN": "true",
    "API": "true",
    "WEB_API": "/api",
    "API_TOKEN": env["MAILU_API_TOKEN"],
    "WEB_ADMIN": "/admin",
    "WEB_WEBMAIL": "/webmail",
    "WEBROOT_REDIRECT": "/webmail",
    "SITENAME": "Pokou Mail",
    "WEBSITE": "https://pokou.app",
    "LOG_LEVEL": "WARNING",
    # Hors de Docker, l'admin de Mailu refuse de démarrer (« Your system is
    # not supported ») sauf sous son chart Helm officiel, qui pose cette
    # variable : c'est le même déploiement Kubernetes.
    "MAILU_HELM_CHART": "true",
    "LD_PRELOAD": "/usr/lib/libhardened_malloc.so",
    "INITIAL_ADMIN_ACCOUNT": "admin",
    "INITIAL_ADMIN_DOMAIN": DOMAIN,
    "INITIAL_ADMIN_PW": env["MAILU_ADMIN_PASSWORD"],
    "INITIAL_ADMIN_MODE": "ifmissing",
    "FRONT_ADDRESS": IP["front"],
    "ADMIN_ADDRESS": IP["admin"],
    "IMAP_ADDRESS": IP["imap"],
    "SMTP_ADDRESS": IP["smtp"],
    "ANTISPAM_ADDRESS": IP["antispam"],
    "WEBMAIL_ADDRESS": IP["webmail"],
    "REDIS_ADDRESS": IP["redis"],
}
if env.get("MAILU_RELAYHOST"):
    # Si l'hébergeur bloque le port 25 sortant : relais SMTP authentifié.
    common["RELAYHOST"] = env["MAILU_RELAYHOST"]
    common["RELAYUSER"] = env.get("MAILU_RELAYUSER", "")
    common["RELAYPASSWORD"] = env.get("MAILU_RELAYPASSWORD", "")

DNS = {"dnsPolicy": "None", "dnsConfig": {"nameservers": [IP["resolver"]], "options": [{"name": "ndots", "value": "1"}]}}
STORAGE = {"name": "data", "persistentVolumeClaim": {"claimName": "mailu-storage"}}


def env_list(extra=None):
    values = dict(common)
    values.update(extra or {})
    return [{"name": k, "value": v} for k, v in values.items()]


def deployment(name, image, ports, mounts, volumes, use_resolver=True, extra_env=None, memory="256Mi"):
    pod = {
        "containers": [{
            # Nom et préfixe de pod de Kubero : ses journaux (onglet Logs,
            # /api/logs/…/mailu/web/history) montrent alors aussi Mailu.
            "name": "kuberoapp-web",
            "image": image,
            "imagePullPolicy": "IfNotPresent",
            "env": env_list(extra_env),
            "ports": [{"containerPort": p, "protocol": proto} for p, proto in ports],
            "volumeMounts": mounts,
            "resources": {"requests": {"cpu": "50m", "memory": "64Mi"}, "limits": {"memory": memory}},
        }],
        "volumes": volumes,
    }
    if use_resolver:
        pod.update(DNS)
    return {
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": f"mailu-kuberoapp-web-{name}", "labels": {"app": f"mailu-{name}"}},
        "spec": {
            "replicas": 1,
            "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": f"mailu-{name}"}},
            "template": {"metadata": {"labels": {"app": f"mailu-{name}"}}, "spec": pod},
        },
    }


def service(name, ports, selector=None, cluster_ip=None, kind="ClusterIP", svc_name=None):
    spec = {
        "type": kind,
        "selector": selector or {"app": f"mailu-{name}"},
        "ports": [{"name": f"p{p}-{proto.lower()}", "port": p, "targetPort": p, "protocol": proto} for p, proto in ports],
    }
    if cluster_ip:
        spec["clusterIP"] = cluster_ip
    if kind == "LoadBalancer":
        spec["externalTrafficPolicy"] = "Local"  # garde l'IP réelle de l'expéditeur
    return {"apiVersion": "v1", "kind": "Service", "metadata": {"name": svc_name or f"mailu-{name}"}, "spec": spec}


def mount(sub, path):
    return {"name": "data", "mountPath": path, "subPath": sub}


resources = []
resources.append({
    "apiVersion": "v1", "kind": "PersistentVolumeClaim",
    "metadata": {"name": "mailu-storage"},
    "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": "local-path",
             "resources": {"requests": {"storage": "20Gi"}}},
})

# Résolveur DNSSEC : il utilise, lui, le DNS du nœud pour démarrer.
resources.append(deployment("resolver", f"ghcr.io/mailu/unbound:{VERSION}",
                            [(53, "UDP"), (53, "TCP")], [], [], use_resolver=False, memory="128Mi"))
resources.append(service("resolver", [(53, "UDP"), (53, "TCP")], cluster_ip=IP["resolver"]))

front_ports = [(80, "TCP"), (25, "TCP"), (465, "TCP"), (587, "TCP"), (993, "TCP"), (143, "TCP"), (4190, "TCP"), (10025, "TCP"), (10143, "TCP"), (8008, "TCP")]
resources.append(deployment(
    "front", f"ghcr.io/mailu/nginx:{VERSION}", front_ports,
    [{"name": "certs", "mountPath": "/certs", "readOnly": True}],
    [{"name": "certs", "secret": {"secretName": "mailu-certs", "optional": False,
                                  "items": [{"key": "tls.crt", "path": "cert.pem"}, {"key": "tls.key", "path": "key.pem"}]}}],
    memory="256Mi"))
resources.append(service("front", front_ports, cluster_ip=IP["front"]))
# Les ports mail publiés sur l'adresse du nœud (ServiceLB de k3s).
resources.append(service("front", [(25, "TCP"), (465, "TCP"), (587, "TCP"), (993, "TCP")],
                         kind="LoadBalancer", svc_name="mailu-mail"))

resources.append(deployment("admin", f"ghcr.io/mailu/admin:{VERSION}", [(8080, "TCP")],
                            [mount("admin", "/data"), mount("dkim", "/dkim")], [STORAGE], memory="512Mi"))
resources.append(service("admin", [(8080, "TCP")], cluster_ip=IP["admin"]))

resources.append(deployment("imap", f"ghcr.io/mailu/dovecot:{VERSION}",
                            [(143, "TCP"), (110, "TCP"), (4190, "TCP"), (2525, "TCP"), (993, "TCP")],
                            [mount("mail", "/mail")], [STORAGE], memory="512Mi"))
resources.append(service("imap", [(143, "TCP"), (110, "TCP"), (4190, "TCP"), (2525, "TCP")], cluster_ip=IP["imap"]))

resources.append(deployment("smtp", f"ghcr.io/mailu/postfix:{VERSION}", [(25, "TCP"), (10025, "TCP")],
                            [mount("mailqueue", "/queue")], [STORAGE], memory="384Mi"))
resources.append(service("smtp", [(25, "TCP"), (10025, "TCP")], cluster_ip=IP["smtp"]))

resources.append(deployment("antispam", f"ghcr.io/mailu/rspamd:{VERSION}", [(11332, "TCP"), (11334, "TCP")],
                            [mount("rspamd", "/var/lib/rspamd"), mount("dkim", "/dkim")], [STORAGE], memory="512Mi"))
resources.append(service("antispam", [(11332, "TCP"), (11334, "TCP")], cluster_ip=IP["antispam"]))

resources.append(deployment("webmail", f"ghcr.io/mailu/webmail:{VERSION}", [(80, "TCP")],
                            [mount("webmail", "/data")], [STORAGE], memory="384Mi"))
resources.append(service("webmail", [(80, "TCP")], cluster_ip=IP["webmail"]))

# Redis : le conteneur de l'app Kubero elle-même (pods « mailu-web »).
resources.append(service("redis", [(6379, "TCP")], cluster_ip=IP["redis"],
                         selector={"app.kubernetes.io/name": "kuberoapp", "app.kubernetes.io/instance": "mailu-web"}))

resources.append({
    "apiVersion": "networking.k8s.io/v1", "kind": "Ingress",
    "metadata": {"name": "mailu-web", "annotations": {
        "cert-manager.io/cluster-issuer": "letsencrypt-prod", "kubernetes.io/tls-acme": "true"}},
    "spec": {
        "ingressClassName": "traefik",
        "tls": [{"hosts": [HOST], "secretName": "mailu-certs"}],
        "rules": [{"host": HOST, "http": {"paths": [{"path": "/", "pathType": "Prefix", "backend": {
            "service": {"name": "mailu-front", "port": {"number": 80}}}}]}}],
    },
})

addons = []
for i, res in enumerate(resources):
    addons.append({
        "id": f"mailu-{i:02d}-{res['metadata']['name']}", "kind": res["kind"],
        "displayName": f"Mailu {res['kind']} {res['metadata']['name']}", "icon": "", "env": [],
        "version": {"latest": "1"}, "resourceDefinitions": {res["kind"]: res},
    })

resources_app = {"requests": {"cpu": "50m", "memory": "64Mi"}, "limits": {"memory": "256Mi"}}
sc = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": False, "runAsNonRoot": True,
      "runAsUser": 999, "runAsGroup": 999, "capabilities": {"add": [], "drop": ["ALL"]}}
app = {
    "name": "mailu",
    "pipeline": "pokou",
    "phase": "production",
    "sleep": "disabled",
    "deploymentstrategy": "docker",
    "buildstrategy": "plain",
    "gitrepo": {"admin": False, "clone_url": "", "ssh_url": ""},
    "branch": "",
    "autodeploy": False,
    "podsize": {"name": "mailu", "description": "Mailu redis", "resources": resources_app},
    "autoscale": False,
    "autoscaling": {"enabled": False},
    "basicAuth": {"enabled": False, "realm": "Authenticate", "accounts": []},
    "envVars": [],
    "extraVolumes": [],
    "cronjobs": [],
    "web": {"replicaCount": 1, "autoscaling": {"minReplicas": 1, "maxReplicas": 1,
            "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "worker": {"replicaCount": 0, "autoscaling": {"minReplicas": 0, "maxReplicas": 0,
               "targetCPUUtilizationPercentage": 80, "targetMemoryUtilizationPercentage": 80}},
    "image": {
        "containerPort": 6379,
        "pullPolicy": "IfNotPresent",
        "repository": "redis",
        "tag": "7.4-alpine",
        "fetch": {"repository": "ghcr.io/kubero-dev/buildpacks/fetch", "tag": "v1.2", "securityContext": sc},
        "build": {"repository": "redis", "tag": "7.4-alpine", "securityContext": sc},
        "run": {"repository": "redis", "tag": "7.4-alpine", "readOnlyAppStorage": False, "securityContext": sc},
    },
    "imagePullSecrets": [],
    "resources": resources_app,
    "service": {"port": 6379, "type": "ClusterIP"},
    "serviceAccount": {"annotations": {}, "create": True, "name": ""},
    "healthcheck": {"enabled": False, "path": "/", "startupSeconds": 90, "timeoutSeconds": 3, "periodSeconds": 10},
    "vulnerabilityscan": {"enabled": False, "schedule": "0 0 * * *",
                          "image": {"repository": "aquasec/trivy", "tag": "latest"}},
    "ingress": {"enabled": False, "className": "traefik", "annotations": {}, "hosts": [], "tls": []},
    "addons": addons,
}
json.dump(app, sys.stdout)
