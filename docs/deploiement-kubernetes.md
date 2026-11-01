# Déployer Pokou sur Kubernetes (production)

Ce guide met l'API Pokou en production sur un cluster Kubernetes, avec
Kafka pour les évènements métier. Les manifestes sont dans
[`deploy/k8s/`](../deploy/k8s/). La liste des comptes et services à ouvrir
(Firebase, stores, SMS, domaines) est dans
[`mise-en-service.md`](mise-en-service.md) : elle reste un préalable.

## 1. Ce qui tourne, et où

```
                      Internet
                         │  HTTPS / WSS
                 ┌───────▼────────┐
                 │ ingress-nginx  │  api.pok.app   (toute l'API + espace officine /officine/)
                 │ + cert-manager │  pok.app       (/.well-known, /invite, /c, /channel, /bot, /legal)
                 └───────┬────────┘
   namespace pokou       │
   ┌─────────────────────▼──────────────┐   ┌──────────────────────┐
   │ Deployment pokou-api (2 à 10 pods) │──▶│ PostgreSQL (managé)  │
   │  HPA, PDB, sondes, non root        │──▶│ Redis (managé)       │
   │                                    │──▶│ Stockage S3          │
   │ Deployment pokou-outbox-relay (1)  │   └──────────────────────┘
   │ Job pokou-migrate (à chaque version)│
   └─────────────────────┬──────────────┘
                         │ SASL_SSL (SCRAM-SHA-512), port 9093
   namespace kafka       ▼
   ┌────────────────────────────────────┐
   │ Strimzi : Kafka KRaft, 3 nœuds     │
   │ topics pokou.kory / honam / analytics │
   └────────────────────────────────────┘
```

Hors du cluster : FCM (push), LiveKit Cloud (appels), Twilio (SMS des codes, NGH en secours),
Semoa / CashPay (paiements).

| Composant | Choix | Pourquoi |
|---|---|---|
| PostgreSQL | **Base managée** (option : CloudNativePG, `deploy/k8s/optional/postgres-cnpg.yaml`) | Sauvegardes, bascule et montées de version gérées par le fournisseur. |
| Redis | **Managé** | Présence et diffusion WebSocket entre pods, verrou de l'ordonnanceur. |
| Médias | **S3 obligatoire** | Le disque local des pods n'est pas partagé. Sans S3, une pièce jointe déposée sur un pod est introuvable depuis un autre. |
| Kafka | **Strimzi dans le cluster** | Opérateur mûr, KRaft (sans ZooKeeper), topics et comptes déclarés en YAML. Une offre managée (Confluent Cloud, Aiven, MSK) convient aussi : il suffit de changer `KAFKA_*`. |

## 2. Ce que Kafka apporte à Pokou, et ce qu'il n'apporte pas

**Il sert à** publier, de façon fiable et ordonnée, ce qui se passe dans
le métier, pour que d'autres services s'en servent sans alourdir l'API :

- **Indicateurs (section 17 du cahier des charges)** : inscriptions,
  cagnottes créées, contributions confirmées, coût SMS par inscription.
  L'entrepôt de données consomme `pokou.analytics.events` et
  `pokou.kory.events`, au lieu d'interroger la base de production.
- **HONAM (lot 2)** : une commande passe par plusieurs états (devis, payée,
  coursier, livrée). Chaque transition est un évènement de
  `pokou.honam.events`. Le décompte du pack coursier (BM-04) et du crédit
  officine (BM-11), les notifications et le relevé mensuel en dépendent, et
  ils ne doivent ni se perdre ni compter deux fois.
- **Notifications et relances** (renouvellement à J-7 et J-1, BM-06) :
  un consommateur dédié les envoie, et l'API ne les porte plus dans ses
  requêtes.
- **Audit et rejeu** : 30 jours de rétention permettent de reconstruire un
  consommateur après une panne.

**Il ne remplace pas Redis pour le temps réel.** La remise des messages
aux WebSocket connectés reste sur Redis Pub/Sub
(`services/messaging/ws_registry.py`). C'est un problème de latence et de
diffusion à des connexions vivantes, pas de journal durable.

**Il n'est pas indispensable au lancement.** Sans `KAFKA_BOOTSTRAP_SERVERS`,
l'API fonctionne normalement : les évènements s'accumulent dans la table
`outbox_events` et partent dès que Kafka est branché. On peut donc lancer le
lot 1 sans Kafka et l'ajouter avant le pilote HONAM du mois 4.

### Comment c'est branché : le *transactional outbox*

```
route Kory ── même transaction ──▶ kory_pots / kory_entries
                                └─▶ outbox_events (évènement)
                                         │
              pokou-outbox-relay ────────┘ lit, publie (acks=all, idempotent),
                                           marque publié, purge après 7 jours
                                         ▼
                                   Kafka pokou.kory.events
```

- Un évènement est écrit dans **la même transaction** que la donnée : pas
  d'évènement perdu si Kafka est injoignable, pas d'évènement fantôme si la
  transaction échoue.
- Le relais publie **au moins une fois**, dans l'ordre. Deux relais en
  parallèle ne publient pas deux fois la même ligne
  (`FOR UPDATE SKIP LOCKED`). Les consommateurs doivent quand même
  dédoublonner sur `id` (UUID de l'enveloppe).
- **Clé de partition** = l'objet métier (`pot-12`) : ses évènements restent
  ordonnés.
- **Aucune donnée personnelle sensible** dans les évènements : ni numéro de
  téléphone ni référence de transaction mobile money (vérifié par
  `tests/test_outbox.py`).

Format d'un évènement :

```json
{
  "id": "6f1c…",
  "type": "kory.entry.confirmed",
  "version": 1,
  "occurred_at": "2026-10-31T10:12:03.511Z",
  "data": { "pot_id": 12, "group_id": 4, "kind": "CAGNOTTE",
            "entry_id": 87, "contributor_id": 31, "amount": 5000 }
}
```

Types émis aujourd'hui :

| Topic | Types |
|---|---|
| `pokou.kory.events` | `kory.pot.created`, `kory.pot.closed`, `kory.entry.declared`, `kory.entry.confirmed`, `kory.entry.rejected` |
| `pokou.honam.events` | `honam.order.submitted`, `.quoted`, `.accepted`, `.paid`, `.ready`, `.in_delivery`, `.delivered`, `.rejected`, `.expired`, `.cancelled` ; `honam.pharmacy.suspended`, `honam.pharmacy.credit_low`, `honam.courier.suspended` |
| `pokou.analytics.events` | `certified.subscription.paid` |

Aucun évènement HONAM ne contient d'ordonnance, de nom de médicament ni de
numéro de téléphone. Pour
en ajouter un : appeler `record_event(db, topic, type, data, key=…)` avant
le `commit` de la route, sans le committer à part.

## 3. Prérequis

Sur le poste qui déploie : `kubectl` ≥ 1.29, `python3`, l'accès au cluster
et au registre d'images.

Dans le cluster :

| Élément | Installation |
|---|---|
| ingress-nginx | `helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace` |
| cert-manager + `ClusterIssuer` `letsencrypt-prod` | `helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true`, puis créer l'émetteur ACME |
| metrics-server | requis par l'HPA (souvent déjà présent) |
| Opérateur Strimzi ≥ 0.45 | `helm upgrade --install strimzi strimzi/strimzi-kafka-operator -n kafka --create-namespace` |
| Une `StorageClass` par défaut | pour les volumes Kafka (3 × 50 Gi) |

Hors cluster : PostgreSQL 16 et Redis 7 managés, joignables depuis les
nœuds ; un bucket S3 ; les DNS `api.pok.app` et `pok.app` pointés sur l'IP
de l'ingress.

## 4. Construire et publier l'image

```bash
cd backend
docker build -t ghcr.io/pokou/pokou-api:1.19.0 .
docker push ghcr.io/pokou/pokou-api:1.19.0
```

L'image tourne sans privilège (UID 10001) et lit un système de fichiers en
lecture seule. Elle sert à la fois l'API, le relais et les migrations.
**Toujours un tag de version, jamais `latest`** : un rollback doit savoir
vers quoi revenir.

## 5. Kafka

```bash
kubectl apply -k deploy/k8s/kafka
kubectl -n kafka wait kafka/pokou-kafka --for=condition=Ready --timeout=15m
```

Puis recopier dans le namespace `pokou` les deux éléments générés par
Strimzi :

```bash
# Certificat de l'autorité du cluster, monté dans /etc/kafka-ca
kubectl create namespace pokou --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kafka get secret pokou-kafka-cluster-ca-cert -o json \
  | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps({"apiVersion":"v1","kind":"Secret","metadata":{"name":s["metadata"]["name"],"namespace":"pokou"},"data":{"ca.crt":s["data"]["ca.crt"]}}))' \
  | kubectl apply -f -

# Mot de passe du compte pokou-api → KAFKA_SASL_PASSWORD dans secrets.env
kubectl -n kafka get secret pokou-api -o jsonpath='{.data.password}' | base64 -d; echo
```

**À refaire à chaque renouvellement du certificat de l'autorité Strimzi**
(un an par défaut), ou à confier à un outil de réplication de secrets
(Reflector, External Secrets).

Pour **lancer sans Kafka** : vider `KAFKA_BOOTSTRAP_SERVERS` dans
`deploy/k8s/base/configmap.yaml` (ou dans un patch de l'overlay). Le relais
journalise « relais inactif » et s'arrête ; Kubernetes le redémarre en
boucle (CrashLoopBackOff, sans conséquence). Le plus propre est alors de le
mettre à `replicas: 0`.

## 6. Secrets

```bash
cp deploy/k8s/overlays/prod/secrets.example.env deploy/k8s/overlays/prod/secrets.env
$EDITOR deploy/k8s/overlays/prod/secrets.env      # ignoré par git
```

- `SECRET_KEY` et `WEBHOOK_HMAC_SECRET` : 64 caractères aléatoires
  (`python3 -c 'import secrets; print(secrets.token_urlsafe(48))'`). L'API
  **refuse de démarrer** en production avec les valeurs par défaut.
- `DATABASE_URL` avec `sslmode=require`, `REDIS_URL` en `rediss://`.
- `FIREBASE_CREDENTIALS_JSON` : le JSON du compte de service sur une seule
  ligne.

Avec un gestionnaire de secrets (External Secrets Operator, Sealed
Secrets, Vault) : créer le Secret `pokou-api-secrets` par ce moyen et
retirer le `secretGenerator` de `overlays/prod/kustomization.yaml`.

## 7. Déployer

```bash
deploy/k8s/deploy.sh ghcr.io/pokou/pokou-api:1.19.0
```

Le script fait, dans l'ordre :

1. applique le namespace, la ConfigMap, le Secret et le ServiceAccount ;
2. joue le **Job de migration** et attend sa fin. En cas d'échec, il
   affiche le journal et **ne déploie rien d'autre** : l'ancienne version
   continue de servir ;
3. applique l'API, le relais, l'Ingress, l'HPA, la PDB et les
   NetworkPolicy, puis attend la fin du déploiement progressif
   (`maxUnavailable: 0`).

Les pods de l'API ont `RUN_MIGRATIONS=0` : sans ce réglage, chaque réplica
lancerait `alembic upgrade head` au même moment.

**Contrainte sur les migrations** : pendant le déploiement progressif,
l'ancienne et la nouvelle version tournent ensemble sur le schéma migré.
Une migration doit donc rester compatible avec la version précédente
(ajouter une colonne nullable, puis s'en servir ; supprimer une colonne
seulement à la version suivante).

## 8. Vérifier

```bash
kubectl -n pokou get pods
kubectl -n pokou logs deploy/pokou-api --tail=50
kubectl -n pokou logs deploy/pokou-outbox-relay --tail=20   # « Relais démarré vers … »
curl -s https://api.pok.app/health
curl -s https://api.pok.app/health/ready                     # 503 si la base est injoignable
curl -sI https://pok.app/.well-known/assetlinks.json
```

Côté Kafka, lire les évènements Kory :

```bash
kubectl -n kafka run kcat --rm -it --image=edenhill/kcat:1.7.1 --restart=Never -- \
  -b pokou-kafka-kafka-bootstrap:9093 -X security.protocol=SASL_SSL \
  -X sasl.mechanisms=SCRAM-SHA-512 -X sasl.username=pokou-consumers \
  -X sasl.password=<mot de passe du Secret pokou-consumers> \
  -X ssl.ca.location=/dev/null -X enable.ssl.certificate.verification=false \
  -C -t pokou.kory.events -o beginning -e
```

(Désactiver la vérification TLS n'est acceptable que pour ce test ponctuel
depuis l'intérieur du cluster.)

Si des évènements ne partent pas, regarder la file d'attente :

```sql
SELECT event_type, count(*), max(attempts), max(last_error)
FROM outbox_events WHERE published_at IS NULL GROUP BY 1;
```

## 9. Revenir en arrière

```bash
kubectl -n pokou rollout undo deployment/pokou-api
kubectl -n pokou rollout undo deployment/pokou-outbox-relay
```

Les migrations ne sont **pas** annulées automatiquement. Elles sont
compatibles avec la version précédente (section 7), donc l'ancienne image
fonctionne sur le nouveau schéma. N'exécuter `alembic downgrade` qu'en
connaissance de cause, après une sauvegarde.

## 10. Dimensionnement de départ

| Élément | Départ | Règle |
|---|---|---|
| API | 2 pods × 2 workers, 250m / 384 Mi | L'HPA monte à 10 pods à 65 % de CPU. |
| Connexions PostgreSQL | `pods × workers × (DB_POOL_SIZE + DB_MAX_OVERFLOW)` = 10 × 2 × 10 = **200 au maximum** | À garder sous `max_connections` de la base, avec une marge pour le Job et le relais. Au-delà, ajouter PgBouncer. |
| Relais | 1 pod, 50m / 128 Mi | Suffit pour des centaines d'évènements par seconde. |
| Kafka | 3 nœuds, 2 Gi, 50 Gi chacun | Réplication 3, `min.insync.replicas` 2. |

Une pod qui part coupe ses WebSocket : les clients se reconnectent sur une
autre. C'est pourquoi l'HPA descend d'une pod toutes les deux minutes au
plus, après dix minutes de stabilité.

## 11. Points ouverts avant la production

- [ ] **`/api/v1/metrics` est joignable depuis Internet** via l'Ingress.
      Le bloquer (règle du contrôleur d'Ingress, ou chemin servi sur un port
      interne) et le faire lire par Prometheus à l'intérieur du cluster.
- [ ] Sauvegardes PostgreSQL vérifiées par une **restauration** réelle.
- [ ] Rotation du certificat de l'autorité Strimzi (section 5) automatisée.
- [ ] Alertes : pods non prêts, file `outbox_events` non publiée depuis
      plus de 5 minutes, *consumer lag* Kafka, erreurs 5xx de l'Ingress.
- [ ] Audit de sécurité externe (prévu en phase 0 par le cahier des
      charges), qui doit couvrir aussi ce déploiement.
- [ ] Ces manifestes ont été rendus avec `kubectl kustomize`, mais **pas
      encore appliqués sur un cluster réel** : le premier déploiement doit
      se faire sur un environnement de préproduction.
