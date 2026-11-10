# Déployer l'API Pokou avec Kubero

[Kubero](https://www.kubero.dev) est une plateforme « à la Heroku » installée
sur un cluster Kubernetes : on y décrit une application, Kubero en fait les
déploiements, le service, l'Ingress et l'autoscaling. Ce guide remplace, pour
qui choisit Kubero, le déploiement par manifestes de
[deploiement-kubernetes.md](deploiement-kubernetes.md). Les deux ne doivent
pas tourner en même temps sur les mêmes domaines.

Les fichiers sont dans [`deploy/kubero/`](../deploy/kubero) :

| Fichier | Rôle |
|---|---|
| `app.template.yaml` | L'application Kubero (`KuberoApp`), avec des `${…}` à remplir |
| `config.env` | Les réglages non secrets, versionnés |
| `secrets.example.env` | La liste des secrets ; la copie remplie `secrets.env` n'est jamais versionnée |
| `render.sh` | Assemble les trois, vérifie les secrets obligatoires, et applique avec `--apply` |

## 1. Comment Pokou tient dans Kubero

| Pokou | Sous Kubero |
|---|---|
| L'API (FastAPI, port 8000) | Le processus **web** : 2 pods au moins, jusqu'à 6 selon le CPU |
| Le relais des évènements vers Kafka | Le processus **worker** : 1 pod, ou 0 sans Kafka |
| Les migrations Alembic | Au démarrage de chaque pod web, sous verrou PostgreSQL : le premier migre, les autres attendent puis trouvent la base à jour |
| `api.pok.app` et les chemins publics de `pok.app` | L'Ingress de l'application, certificat par cert-manager |

Kubero lance web et worker avec **la même image et la même commande** ;
seule la variable `PROC_TYPE` (que Kubero pose) les distingue.
`backend/docker-entrypoint.sh` s'en sert pour démarrer l'API ou le relais.

Ce que Kubero ne fait pas et que les manifestes faisaient : le Job de
migration préalable, le `PodDisruptionBudget` et la `NetworkPolicy`. Voir la
section 7.

## 2. Ce qu'il faut avant

- Un cluster Kubernetes avec **Kubero** installé (CLI `kubero install`, ou
  l'opérateur et l'interface par leur chart). Kubero installe aussi
  ingress-nginx et cert-manager si on le lui demande.
- Un `ClusterIssuer` cert-manager nommé `letsencrypt-prod` (ou passez
  `CLUSTER_ISSUER=…` à `render.sh`).
- **metrics-server**, sans quoi l'autoscaling ne voit pas le CPU.
- **PostgreSQL** : une base gérée, ou l'addon PostgreSQL de Kubero. Notez
  l'URL, qui ira dans `DATABASE_URL`.
- **Redis** : idem, pour `REDIS_URL`.
- **Un bucket S3** (ou compatible : MinIO, Scaleway, R2…). Il est
  **obligatoire** ici : les pods ont un système de fichiers en lecture seule
  et éphémère, une pièce jointe écrite sur le disque serait perdue au
  redémarrage, quand l'écriture ne serait pas tout simplement refusée.
- **Kafka**, facultatif : celui de `deploy/k8s/kafka` (Strimzi). Sans Kafka,
  les évènements restent en base et le worker est mis à 0.
- Les comptes externes de [mise-en-service.md](mise-en-service.md) : Twilio,
  Firebase, LiveKit, CashPay.

## 3. Créer le pipeline dans Kubero

Dans l'interface de Kubero :

1. **Pipelines → New pipeline**, nom `pokou`.
2. Déploiement depuis une **image de conteneur** (pas de construction par
   Kubero : l'image est construite une fois par la CI, et c'est la même qui
   passe de la préproduction à la production).
3. Activer la phase **production** (et `stage` si vous voulez une
   préproduction).

Kubero crée un namespace par phase, `pokou-production` pour la production.
Vérifiez son nom exact dans l'interface : c'est là que `render.sh` applique
l'application (`NAMESPACE=…` pour en changer).

Si l'image est privée, créez dans ce namespace un secret de registre et
passez son nom à `render.sh` :

```bash
kubectl -n pokou-production create secret docker-registry ghcr-pokou \
  --docker-server=ghcr.io --docker-username=… --docker-password=…
export IMAGE_PULL_SECRET=ghcr-pokou
```

## 4. Construire et publier l'image

```bash
cd backend
docker build -t ghcr.io/pokou/pokou-api:1.20.0 .
docker push ghcr.io/pokou/pokou-api:1.20.0
```

Toujours une étiquette de version, jamais `latest` : `render.sh` refuse une
image sans étiquette, et c'est le changement d'étiquette qui déclenche le
déploiement.

## 5. Remplir les secrets et déployer

```bash
cd deploy/kubero
cp secrets.example.env secrets.env      # ignoré par git
$EDITOR secrets.env                     # DATABASE_URL, S3_*, TWILIO_*…
./render.sh ghcr.io/pokou/pokou-api:1.20.0            # relire le document
./render.sh ghcr.io/pokou/pokou-api:1.20.0 --apply    # appliquer
```

`render.sh` s'arrête si `SECRET_KEY`, `WEBHOOK_HMAC_SECRET`, `DATABASE_URL`
ou les accès S3 manquent. Sans Kafka :

```bash
WORKER_REPLICAS=0 ./render.sh ghcr.io/pokou/pokou-api:1.20.0 --apply
```

Autres domaines que `api.pok.app` / `pok.app` :

```bash
API_HOST=api.exemple.tg PUBLIC_HOST=exemple.tg ./render.sh … --apply
```

L'application apparaît ensuite dans l'interface de Kubero, dans le pipeline
`pokou`.

## 6. Vérifier

```bash
NS=pokou-production
kubectl -n $NS get pods                          # pokou-api-web-…, pokou-api-worker-…
kubectl -n $NS logs deploy/pokou-api-web | grep -i migration
curl -s https://api.pok.app/health               # le processus répond
curl -s https://api.pok.app/health/ready         # base et Redis joignables
curl -sI https://pok.app/.well-known/assetlinks.json
```

Dans les journaux du web, « Migrations applied. » doit apparaître une fois
par pod (le second pod n'a rien à faire). Le worker écrit « relais des
évènements vers Kafka », ou « relais en veille » sans Kafka.

Puis l'application mobile : inscription par SMS (Twilio), message entre deux
comptes, et l'espace officine sur `https://api.pok.app/officine/`.

## 7. Les différences à connaître

**Les secrets sont dans la ressource de l'application.** Kubero passe les
variables d'environnement en clair dans la `KuberoApp` : il n'y a pas de
référence à un Secret Kubernetes. Quiconque peut lire les `kuberoapps` du
namespace, ou ouvrir l'application dans l'interface de Kubero, lit les mots
de passe. Réservez l'accès à l'interface et ce droit Kubernetes aux
personnes qui ont déjà accès aux secrets.

**Le dépôt fait foi.** `render.sh --apply` réécrit l'application entière :
une variable ajoutée à la main dans l'interface disparaît au déploiement
suivant. Ajoutez-la à `config.env` ou `secrets.env`.

**Les migrations ont 90 secondes.** Kubero laisse 90 s à un pod pour
répondre sur `/health` au démarrage, migrations comprises. Celles de Pokou
prennent quelques secondes. Une migration qui durerait plus longtemps (un
index sur une grosse table) se joue AVANT le déploiement, par un pod
ponctuel de la nouvelle image :

```bash
kubectl -n $NS run pokou-migrate --rm -it --restart=Never \
  --image=ghcr.io/pokou/pokou-api:1.21.0 \
  --env="DATABASE_URL=$(grep '^DATABASE_URL=' secrets.env | cut -d= -f2-)" \
  -- true      # l'entrypoint migre, puis exécute « true » et s'arrête
```

Les pods web trouvent ensuite la base à jour. Dans tous les cas, une
migration doit rester compatible avec la version précédente de l'API :
pendant le déploiement progressif, l'ancienne et la nouvelle tournent
ensemble sur la même base.

**Pas de PodDisruptionBudget ni de NetworkPolicy.** Kubero ne les crée pas.
On peut les appliquer à part dans le namespace, en reprenant
`deploy/k8s/base/api-pdb.yaml` et `networkpolicy.yaml` et en remplaçant les
sélecteurs par les étiquettes des pods Kubero
(`kubectl -n $NS get pods --show-labels`).

**Kafka et son certificat.** Kubero ne monte pas de fichier depuis un
Secret : le certificat de l'autorité Kafka passe par la variable
`KAFKA_SSL_CA_PEM` (commande dans `secrets.example.env`), lue directement
par le relais.

## 8. Mettre à jour, revenir en arrière

```bash
./render.sh ghcr.io/pokou/pokou-api:1.21.0 --apply   # nouvelle version
./render.sh ghcr.io/pokou/pokou-api:1.20.0 --apply   # retour arrière
```

Le retour arrière ne défait pas les migrations : c'est pour cela qu'elles
restent compatibles avec la version précédente.

## 9. L'instance en service (3 novembre 2026)

| | |
|---|---|
| Kubero | `https://kubero.169.58.195.18.sslip.io` (v3.1.1, k3s, un nœud, Ingress Traefik) |
| Pipeline / phase / namespace | `pokou` / `production` / `pokou-production` |
| API | `https://apipokou.cabinet-p-et-associes.com` (Cloudflare devant, certificat Let's Encrypt à l'origine) |
| Addons | PostgreSQL 17 `pokou-postgres:5432` (base et utilisateur `pokou`), Redis 8 `pokou-redis:6379`, Kafka 3.4 `pokou-kafka:9092` (PLAINTEXT, interne au cluster) |
| Appels (LiveKit) | App `livekit` : signalisation `wss://rtc.cabinet-p-et-associes.com`, médias en direct sur `169.58.195.18` : 7881/TCP et 7882/UDP, relais TURN 3478/UDP |
| Console d'administration | `https://apipokou.cabinet-p-et-associes.com/console/` (servie par l'API, voir [administration.md](administration.md)) |
| Pièces jointes | Volume `pokou-media` (10 Gi, local-path) monté sur `/data`, pas de S3 sur ce cluster |
| Secrets | `deploy/kubero/secrets.env` sur le poste qui a déployé, jamais versionné |

**Mode « plain », pas d'image.** Cette instance ne construit pas d'images
(`buildPipeline: false`) et le compte GitHub ne peut pas lancer d'Actions
pour l'instant (facturation). Kubero clone donc le dépôt à chaque démarrage
de pod, `backend/kubero-build.sh` installe les dépendances dans une image
`python:3.12-slim`, puis `backend/kubero-run.sh` lance le point d'entrée
habituel. C'est plus lent à démarrer (une à deux minutes par pod) et chaque
redémarrage prend le dernier `main`. Dès que les Actions remarchent,
`.github/workflows/api-image.yml` publie une image : passer l'app en
déploiement par image (sections 4 et 5).

**Recréer ou modifier l'app** : `deploy/kubero/build_app_json.py` produit
le corps attendu par l'API de Kubero à partir de `secrets.env` :

```bash
cd deploy/kubero
python3 build_app_json.py > app.json        # app.json contient les secrets : ignoré par git
TOKEN=$(curl -s -X POST https://kubero.169.58.195.18.sslip.io/api/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"…"}' | jq -r .access_token)
curl -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  --data @app.json https://kubero.169.58.195.18.sslip.io/api/apps/pokou/production/new
```

Pour une modification (Twilio renseigné, par exemple), l'interface de Kubero
suffit : application `pokou-api` → Edit → variables d'environnement, puis
redémarrer.

**Kafka Bitnami et Zookeeper.** L'image d'origine
`docker.io/bitnami/zookeeper` n'existe plus (Bitnami a déplacé ses images
vers `bitnamilegacy`) : l'addon force `bitnamilegacy/zookeeper`. Sans ce
réglage, Zookeeper reste en `ImagePullBackOff` et Kafka redémarre en boucle.

**LiveKit et ses ports média.** Kubero n'expose qu'un port HTTP par
application ; les médias des appels ne passent pas par l'Ingress (ni par
Cloudflare) mais vont directement au serveur, sur 7881/TCP et 7882/UDP.
`deploy/kubero/build_livekit_json.py` les ouvre par un Service
`LoadBalancer` (`livekit-rtc`), que ServiceLB de k3s publie sur l'adresse du
nœud ; il passe par les « addons » de l'app, que le chart de Kubero rend
tels quels. Ces deux ports doivent rester ouverts dans le pare-feu de
l'hébergeur. Les clés LiveKit sont dans `secrets.env` (`LIVEKIT_API_KEY`,
`LIVEKIT_API_SECRET`) ; `build_app_json.py` les donne aussi à l'API.

**Relais TURN (10 novembre 2026).** Certains réseaux mobiles (NAT
symétrique) empêchent le média direct vers 7881/7882 : l'appel se connecte
mais le son ne passe pas. LiveKit embarque un relais TURN, activé sur
3478/UDP : bloc `turn:` de `LIVEKIT_CONFIG` et port `turn-udp` du Service
`livekit-rtc`. Le relais est annoncé aux téléphones **sous l'IP du nœud**
(`domain: 169.58.195.18`) et non sous `rtc.cabinet-p-et-associes.com` : ce
nom passe par le proxy Cloudflare, qui ne relaie pas l'UDP, et le relais y
serait injoignable. Le TURN sur TLS (réseaux qui ne laissent passer que du
HTTPS) demanderait un nom hors proxy et le certificat monté dans le pod.

Sur une app `livekit` déjà en service, sans la recréer :

```bash
cd deploy/kubero
python3 apply_livekit_turn.py     # ajoute ce qui manque, puis redémarre LiveKit
```

Le script ne touche que le relais, ne fait rien s'il est déjà en place et
redémarre LiveKit (les appels en cours sont coupés quelques secondes).
Vérifier ensuite que les journaux de LiveKit disent « Starting TURN server »,
et que le port répond depuis l'extérieur à une requête STUN sur
`169.58.195.18:3478` (https://icetest.info).

## 10. Redéployer l'API

Kubero clone `main` à chaque démarrage de pod : redéployer, c'est pousser
puis redémarrer l'app `pokou-api` (interface Kubero → `pokou-api` →
Restart, ou `POST /api/apps/pokou/production/pokou-api/restart`).

Au démarrage, `docker-entrypoint.sh` :

1. attend la base, puis `alembic upgrade head` ;
2. lance le seed (`python -m scripts.seed`) : catalogue des modules et
   super-administrateur de la console, idempotent (voir
   [administration.md](administration.md) § 2) ;
3. démarre uvicorn.

Pendant le remplacement du pod (une à deux minutes), l'ancien sert encore
les requêtes : une route toute neuve peut répondre 404 le temps de la
bascule. Vérifier ensuite :

```bash
curl -s https://apipokou.cabinet-p-et-associes.com/health                  # 200
curl -s -o /dev/null -w '%{http_code}' https://apipokou.cabinet-p-et-associes.com/console/login/   # 200
```

La console est un export statique committé dans `backend/app/console/` :
après une modification de `admin/`, lancer `npm run publish` et committer le
résultat **avant** de redéployer.
