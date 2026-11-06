"""Applique à l'app Kubero `pokou-api` les clés facultatives — Firebase (push)
et modèles de langage (Baba) — sans toucher au reste de sa configuration,
puis redémarre l'API.

Usage : python3 apply_secrets.py
  - Firebase : poser firebase-service-account.json à côté de ce script
    (console Firebase → Paramètres du projet → Comptes de service →
    Générer une nouvelle clé privée), ou FIREBASE_CREDENTIALS_JSON dans
    secrets.env.
  - Baba : GEMINI_API_KEY / GROQ_API_KEY / DEEPSEEK_API_KEY / GROK_API_KEY
    dans secrets.env.
Les identifiants Kubero sont lus dans secrets.env (KUBERO_URL, KUBERO_USER,
KUBERO_PASSWORD).
"""
import json
import os
import ssl
import sys
import urllib.request

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


wanted = {}
fb = env.get("FIREBASE_CREDENTIALS_JSON", "").strip()
if not fb and os.path.exists("firebase-service-account.json"):
    fb = json.dumps(json.load(open("firebase-service-account.json", encoding="utf-8")))
if fb:
    if json.loads(fb).get("project_id") != "pokou-3b047":
        sys.exit("La clé Firebase n'est pas celle du projet pokou-3b047.")
    wanted["FCM_ENABLED"] = "true"
    wanted["FIREBASE_CREDENTIALS_JSON"] = fb
for k in ("GEMINI_API_KEY", "GROQ_API_KEY", "DEEPSEEK_API_KEY", "GROK_API_KEY"):
    if env.get(k):
        wanted[k] = env[k]
        wanted[k.replace("_API_KEY", "_ENABLED")] = "true"
if not wanted:
    sys.exit("Aucune clé à appliquer.")

token = json.loads(call("/api/auth/login", {
    "username": env.get("KUBERO_USER", "admin"),
    "password": env["KUBERO_PASSWORD"],
}))["access_token"]
app = json.loads(call("/api/apps/pokou/production/pokou-api", token=token))
spec = app.get("spec", app)
envvars = {e["name"]: e.get("value", "") for e in spec.get("envVars") or []}
envvars.update(wanted)
spec["envVars"] = [{"name": k, "value": v} for k, v in envvars.items()]
rv = app.get("metadata", {}).get("resourceVersion", "")
body = dict(spec)
body.setdefault("pipeline", "pokou")
body.setdefault("phase", "production")
call(f"/api/apps/pokou/production/pokou-api/{rv}", body, token=token, method="PUT")
call("/api/apps/pokou/production/pokou-api/restart", token=token)
print("Appliqué :", ", ".join(k for k in wanted if not k.endswith("_JSON") and "KEY" not in k) or "clés")
print("Redémarrage de l'API lancé.")
