#!/bin/bash
set -e

# ── Attendre une base qui répond, puis migrer ────────────────────────────────
#
# La boucle ci-dessous rejouait `alembic upgrade head` dix fois en traitant
# toutes les erreurs de la même façon. Elles ne se ressemblent pourtant pas :
#
#   - « la base n'est pas encore prête » est transitoire, il faut réessayer ;
#   - « personne ne répond au bout de DATABASE_URL » ne le sera jamais. Dix
#     tentatives et soixante lignes de traceback plus tard, le conteneur
#     s'arrêtait sur « server closed the connection unexpectedly » — un message
#     qui accuse le serveur alors que la faute est dans l'URL, et qui ne nomme
#     ni l'hôte ni le port utilisés.
#
# `pg_isready` (postgresql-client, installé par le Dockerfile) répond à la
# première question, sans authentification, et son message contient le
# « hôte:port » réellement contacté. Son code de sortie, en revanche, ne sert à
# rien ici : le 2 « no response » couvre aussi bien un nom introuvable qu'un
# port fermé, un port muet ou un mot de passe non encodé — tous vérifiés. Le
# tri fin est donc fait par `diagnose_address`, à l'endroit où le message est
# lu, et non par un aiguillage sur ce code.
if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL est vide : l'API ne sait pas à quelle base se connecter."
  exit 1
fi

# libpq (pg_isready) ne connaît pas le suffixe de pilote de SQLAlchemy, alors
# que DATABASE_URL en porte un en production (`postgresql+psycopg://…`).
LIBPQ_URL="${DATABASE_URL//+psycopg2/}"
LIBPQ_URL="${LIBPQ_URL//+psycopg/}"

# ── Nommer la panne quand l'adresse reste muette ─────────────────────────────
#
# « no response » couvre des pannes qu'on ne répare pas de la même façon, et le
# déployeur n'a aucun moyen de les distinguer sans entrer dans le conteneur :
#
#   1. le nom ne se résout pas         → nom de service faux, ou API et base
#                                        sur deux réseaux Docker différents ;
#   2. le nom se résout, rien n'écoute → base arrêtée, ou mauvais port ;
#   3. quelque chose écoute mais ne    → pas PostgreSQL derrière ce port (la
#      répond pas au protocole           panne d'origine : port 5428 recyclé).
#
# La sonde les sépare dans l'ordre où il faut les corriger : URL, puis DNS,
# puis TCP. Ce que `pg_isready` traverse aussi — mais sans le raconter.
diagnose_address() {
  python3 - <<'PY'
import os, socket, urllib.parse as u

url = os.environ["DATABASE_URL"]
parsed = u.urlparse(url)
host = parsed.hostname or "localhost"
port = parsed.port or 5432

# Piège vu en vrai : avec un « @ » non encodé dans le mot de passe, libpq
# coupe l'autorité au PREMIER @ alors que l'application la coupe au dernier.
# Les deux ne contactent donc pas le même hôte, et l'adresse affichée
# ci-dessous peut être celle que pg_isready utilise, pas celle de l'API.
if parsed.netloc.count("@") > 1:
    print("  attention  : plusieurs « @ » avant l'hôte — le mot de passe contient")
    print("               un @ non encodé (à écrire %40). pg_isready et l'API n'en")
    print("               déduisent pas le même hôte.")
    print("               Tout caractère réservé (%, @, /, :, #) doit être encodé.")

try:
    addresses = sorted({info[4][0] for info in socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP)})
except OSError as exc:
    print(f"  résolution : {host} introuvable ({exc.strerror or exc})")
    print("               → nom de service faux, ou API et base rattachées à deux")
    print("                 réseaux Docker différents : chaque service a le sien.")
    raise SystemExit(0)

print(f"  résolution : {host} -> {', '.join(addresses)}")

for address in addresses:
    try:
        with socket.create_connection((address, port), timeout=4):
            print(f"  TCP        : {address}:{port} accepte la connexion")
            print("               → quelqu'un écoute mais ne parle pas PostgreSQL :")
            print("                 autre service sur ce port, ou base en cours")
            print("                 d'initialisation (elle acceptera ensuite).")
    except OSError as exc:
        print(f"  TCP        : {address}:{port} injoignable ({exc.strerror or exc})")
        print("               → rien n'écoute à cette adresse : la base n'est pas")
        print("                 démarrée, ou pas exposée sur ce port.")
PY
}

attempt=0
max_attempts=10

while true; do
  # Le `if` sert à lire le message ET le code : set -e ne doit pas sortir avant
  # qu'on ait décidé quoi en faire.
  if is_ready="$(pg_isready -d "$LIBPQ_URL" -t 5 2>&1)"; then
    echo "PostgreSQL: ${is_ready}"
    break
  fi

  attempt=$((attempt + 1))
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Base injoignable après ${max_attempts} tentatives : ${is_ready}"
    echo "Adresse utilisée par l'API :"
    diagnose_address
    exit 1
  fi

  echo "Tentative ${attempt}/${max_attempts} : la base n'accepte pas encore les connexions (${is_ready}), nouvel essai dans 3s..."
  sleep 3
done

# La base répond : une erreur qui suit vient de la migration elle-même, et une
# migration à moitié appliquée qu'on rejoue est exactement ce qui produit les
# boucles « already exists ». Elle est donc jouée UNE fois.
#
# RUN_MIGRATIONS=0 sur Kubernetes : les migrations y sont jouées par un Job
# dédié avant le déploiement (deploy/k8s/base/migrate-job.yaml). Sans ce
# réglage, chaque réplica lancerait `alembic upgrade head` au même moment.
#
# PROC_TYPE (Kubero) : le processus web et le worker partagent la même image
# et la même commande, seule cette variable les distingue. Le worker est le
# relais Kafka ; il ne migre jamais — c'est le rôle des pods web.
if [ "${PROC_TYPE:-}" = "worker" ] && [ "$#" -eq 0 ]; then
  if [ -z "${KAFKA_BOOTSTRAP_SERVERS:-}" ]; then
    # Sans Kafka, le relais n'a rien à faire. Il attend plutôt que de
    # s'arrêter, ce qui ferait redémarrer le pod en boucle.
    echo "PROC_TYPE=worker sans KAFKA_BOOTSTRAP_SERVERS : relais en veille, les évènements restent en base."
    exec sleep infinity
  fi
  echo "PROC_TYPE=worker : relais des évènements vers Kafka."
  exec python -m app.workers.outbox_relay
fi

if [ "${RUN_MIGRATIONS:-1}" = "1" ]; then
  if ! alembic upgrade head; then
    echo "alembic upgrade head a échoué alors que la base répond : l'erreur est dans la migration, pas dans la connexion."
    exit 1
  fi
  echo "Migrations applied."
else
  echo "RUN_MIGRATIONS=0 : migrations laissées au Job de déploiement."
fi

echo "Starting application..."
if [ "$#" -gt 0 ]; then
  exec "$@"
else
  # --proxy-headers : derrière l'Ingress, l'adresse du client et le schéma
  # https viennent de X-Forwarded-*, sans quoi la limitation de débit
  # verrait toutes les requêtes venir du contrôleur d'Ingress.
  exec uvicorn app.main:app --host 0.0.0.0 --port 8000 \
    --workers "${UVICORN_WORKERS:-1}" \
    --proxy-headers --forwarded-allow-ips "${FORWARDED_ALLOW_IPS:-*}" \
    --timeout-graceful-shutdown 25
fi
