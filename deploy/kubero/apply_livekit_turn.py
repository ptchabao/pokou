"""Active le relais TURN intégré de LiveKit sur l'app Kubero `livekit` déjà en
service, sans la recréer, puis la redémarre.

Usage : python3 apply_livekit_turn.py  (depuis deploy/kubero, avec secrets.env)

Reprend la configuration en service et n'y change que deux choses, celles de
build_livekit_json.py : le bloc `turn:` de LIVEKIT_CONFIG, et le port
3478/UDP du Service des ports média. Relancer le script ne change rien de
plus.
"""
import json
import ssl
import sys
import urllib.request

# L'IP du nœud et non rtc.cabinet-p-et-associes.com : ce nom passe par le
# proxy Cloudflare, qui ne relaie pas l'UDP — le relais y serait injoignable.
HOST = "169.58.195.18"
OLD_HOST = "rtc.cabinet-p-et-associes.com"
TURN_BLOCK = f"turn:\n  enabled: true\n  domain: {HOST}\n  udp_port: 3478\n"
TURN_PORT = {"name": "turn-udp", "port": 3478, "targetPort": 3478, "protocol": "UDP"}

env = {}
for line in open("secrets.env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

K = env.get("KUBERO_URL", "https://kubero.169.58.195.18.sslip.io")
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def call(path, data=None, token=None, method=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        K + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers=headers,
        method=method or ("POST" if data is not None else "GET"),
    )
    return urllib.request.urlopen(req, context=ctx, timeout=60).read()


token = json.loads(call("/api/auth/login", {
    "username": env.get("KUBERO_USER", "admin"),
    "password": env["KUBERO_PASSWORD"],
}))["access_token"]
app = json.loads(call("/api/apps/pokou/production/livekit", token=token))
spec = app.get("spec", app)

changed = []
for e in spec.get("envVars") or []:
    if e["name"] == "LIVEKIT_CONFIG" and "\nturn:" not in "\n" + e.get("value", ""):
        if "\nkeys:" not in e["value"]:
            sys.exit("LIVEKIT_CONFIG sans bloc « keys: » : configuration inattendue, rien n'est modifié.")
        e["value"] = e["value"].replace("\nkeys:", "\n" + TURN_BLOCK + "keys:", 1)
        changed.append("bloc turn de LIVEKIT_CONFIG")
    elif e["name"] == "LIVEKIT_CONFIG" and f"domain: {OLD_HOST}" in e.get("value", ""):
        e["value"] = e["value"].replace(f"domain: {OLD_HOST}", f"domain: {HOST}", 1)
        changed.append("domaine du relais TURN (IP directe)")

for addon in spec.get("addons") or []:
    svc = (addon.get("resourceDefinitions") or {}).get("Service")
    if svc and svc.get("metadata", {}).get("name") == "livekit-rtc":
        ports = svc["spec"]["ports"]
        if not any(p.get("port") == 3478 for p in ports):
            ports.append(TURN_PORT)
            changed.append("port 3478/UDP du Service livekit-rtc")

if not changed:
    sys.exit("Le relais TURN est déjà en place : rien à faire.")

rv = app.get("metadata", {}).get("resourceVersion", "")
body = dict(spec)
body.setdefault("pipeline", "pokou")
body.setdefault("phase", "production")
call(f"/api/apps/pokou/production/livekit/{rv}", body, token=token, method="PUT")
call("/api/apps/pokou/production/livekit/restart", token=token)
print("Appliqué :", ", ".join(changed))
print("Redémarrage de LiveKit lancé.")
