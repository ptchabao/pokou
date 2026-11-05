# Vault — état réel du dépôt

**Pour** : le fondateur, pour arbitrer la roadmap sur du vérifié plutôt que sur une impression.
**Méthode** : lecture du code, pas des intentions. Chaque case a été ouverte.
**Date** : 23/09/2026.

---

## 1. Matrice fonctionnelle

Barème : **COMPLET** (utilisable en production) · **PARTIEL** (existe, une couche manque) · **ABSENT** · **À TESTER** (écrit, jamais éprouvé en conditions réelles).

| Fonctionnalité | Backend | API | Flutter | DB | E2EE | Android | iOS | Tests | État |
|---|---|---|---|---|---|---|---|---|---|
| **Status** | COMPLET | COMPLET | COMPLET | COMPLET | ABSENT | COMPLET | COMPLET | COMPLET | **PARTIEL** |
| **Communities** | COMPLET | COMPLET | COMPLET | COMPLET | ABSENT | COMPLET | COMPLET | COMPLET | **PARTIEL** |
| **Messages éphémères** | COMPLET | COMPLET | ABSENT | COMPLET | COMPLET | — | — | ABSENT | **PARTIEL** |
| **View Once** | COMPLET | COMPLET | COMPLET | COMPLET | COMPLET | PARTIEL | ABSENT | PARTIEL | **PARTIEL** |
| **Live Location** | COMPLET | COMPLET | PARTIEL | COMPLET | COMPLET | COMPLET | COMPLET | ABSENT | **PARTIEL** |
| **Polls** | COMPLET | COMPLET | COMPLET | COMPLET | ABSENT | COMPLET | COMPLET | COMPLET | **COMPLET** |
| **Appels natifs** | COMPLET | COMPLET | COMPLET | COMPLET | — | COMPLET | ABSENT | PARTIEL | **À TESTER** |

### Ce que chaque « PARTIEL » veut dire précisément

**Status** — tout est là : texte, photo, vidéo, visionneuse, confidentialité par liste, compteur de vues, expiration à 24 h. Le seul manque est le chiffrement : un statut n'est pas chiffré de bout en bout. C'est un choix documenté dans `e2ee_service.dart` (« les groupes, les chaînes et les statuts ne sont PAS chiffrés »), pas un oubli — mais il doit être dit sur la page produit.

**Communities** — même situation. Modèle, routes, écrans, membres, appartenance. Non chiffrées.

**Messages éphémères** — `Contact.disappearing_seconds` existe, `messages.py` calcule `expires_at`, `_not_expired()` filtre à la lecture. **Mais aucun écran Flutter ne permet de régler la durée** : la fonctionnalité est complète côté serveur et invisible côté application. C'est l'écart le plus rentable de tout ce tableau — quelques heures d'interface libèrent un travail déjà payé. Et aucun test ne la couvre.

**View Once** — verrouillée côté SERVEUR, ce qui est le bon endroit : `_can_access` refuse le média au destinataire une fois consulté, donc rappeler `GET /media/{id}` ne le redonne pas. Android est en `PARTIEL` parce que `FLAG_SECURE` a été retiré à votre demande : une capture d'écran redevient possible. iOS n'a jamais eu d'équivalent.

**Live Location** — `live_until` est porté par le serveur et la bulle Flutter l'affiche, mais il n'y a **pas de carte ni de rafraîchissement en direct** : on voit une position et une durée, pas un point qui bouge. D'où `PARTIEL` côté Flutter.

**Polls** — la seule ligne complète. Même route de vote pour les conversations et les chaînes, barres de progression, rétractation. Non chiffrés, comme les groupes.

**Appels natifs** — `À TESTER`. Le Kotlin compile, 41 tests unitaires passent, et depuis le **23/09/2026 un appel entrant passe bien sur appareil réel** (cas 1 du §8, confirmé par le fondateur) : la chaîne push → interception → sonnerie → notification `CallStyle` tient de bout en bout, ce qu'aucun émulateur ne pouvait montrer.

Les **onze autres cas** restent à éprouver — notamment le refus sans lancer Flutter, l'arrêt sur raccrochage distant, le délai de 45 s, la réponse rapide, et le cas 12 sur les surcouches chinoises (Xiaomi, Oppo, Huawei), qui sont majoritaires sur ce marché et tuent agressivement les processus d'arrière-plan. Tant que les douze cas ne sont pas couverts sur les cinq modèles convenus, cette ligne n'est pas « COMPLET » quoi qu'en dise le code, et le repli Flutter reste en place.

---

## 2. Audit de montée en charge

**Objectif** : passer de `FastAPI × 1` à `FastAPI × N` sans changer le comportement fonctionnel.

**Verdict global : l'API n'est pas horizontalement extensible aujourd'hui.** Deux blocages durs, et ils sont nommés ci-dessous. Le reste est sain ou se corrige facilement.

| # | Point | État | Détail |
|---|---|---|---|
| 1 | FastAPI stateless | **PARTIEL** | Les routes le sont. Deux objets en mémoire ne le sont pas (voir 2 et 13). |
| 2 | Aucune donnée critique en RAM | **ABSENT** | 🔴 `ConnectionManager._connections` est un `Dict` en mémoire de processus. |
| 3 | Plusieurs instances simultanées | **ABSENT** | 🔴 Conséquence directe de 2 et 4. |
| 4 | WebSocket multi-instance via Redis | **ABSENT** | 🔴 Aucun pub/sub. Le fichier le dit lui-même : « registre en mémoire, valable pour un seul processus API ». |
| 5 | Présence/typing sur Redis | **PARTIEL** | `typing` est de la diffusion pure, sans écriture — parfait. `last_seen_at` va en **PostgreSQL** à chaque connexion/déconnexion WebSocket. |
| 6 | Tâches longues sorties vers des workers | **PARTIEL** | `notification_queue` est une vraie file en base. Mais `DataSourceScheduler` tourne **dans le processus API** : avec N instances, N schedulers exécutent le même travail. |
| 7 | FCM/APNs découplés du HTTP | **PARTIEL** | `notification_queue` existe et est utilisée par les signaux. `send_push` est appelé **en direct** depuis les routes de message et d'appel — un Firebase lent ralentit l'envoi d'un message. |
| 8 | Jobs idempotents et réessayables | **COMPLET** | `NotificationQueueItem.idempotency_key` unique + backoff. Bon modèle, à généraliser. |
| 9 | Pool PostgreSQL | **PARTIEL** | `pool_pre_ping` et `pool_recycle=3600` sont réglés ; `pool_size` et `max_overflow` restent aux défauts SQLAlchemy (5 + 10). À 10 instances, 150 connexions — au-delà du défaut Postgres (100). |
| 10 | Index sur les requêtes critiques | **COMPLET** | `direct_messages`, `group_messages`, `contacts`, `call_logs` sont indexés sur leurs colonnes de filtrage et de tri. |
| 11 | Upload direct vers MinIO | **ABSENT** | Aucune URL présignée : tout passe par l'API. |
| 12 | Gros fichiers hors RAM | **ABSENT** | 🔴 `content = await upload.read()` charge le fichier ENTIER en mémoire. Une vidéo de 100 Mo = 100 Mo de RAM par upload concurrent. |
| 13 | Rate limiting distribué | **ABSENT** | Compteur en mémoire, par processus — documenté comme tel dans `rate_limit.py`. À N instances, plafond × N. |
| 14 | Clé d'idempotence sur les opérations sensibles | **PARTIEL** | Présente sur la file de notifications et sur les jetons d'action (ceux-ci étant à usage unique). Absente sur l'envoi de message et le paiement. |
| 15 | `request_id` / `trace_id` dans les logs | **COMPLET** | Middleware `add_trace_id_and_metrics`, `X-Trace-ID` en en-tête de réponse. |
| 16 | Métriques exploitables | **PARTIEL** | `prometheus_client` et `/metrics` existent pour l'API. Rien sur PostgreSQL, Redis, MinIO ni LiveKit. |

### Les trois blocages, par ordre de gravité

**🔴 1. Le registre WebSocket est en mémoire.**
C'est LE blocage. Avec deux instances, un message envoyé par quelqu'un servi par l'instance A n'atteint pas un destinataire connecté à l'instance B : `manager.send_to_user` ne trouve pas sa socket et retombe sur le push. La messagerie temps réel cesse de fonctionner à moitié — et silencieusement, puisque le repli par notification masque le symptôme.

*Correction* : un pub/sub Redis. Chaque instance s'abonne à un canal par utilisateur connecté ; `send_to_user` publie au lieu d'écrire directement. Redis est déjà une dépendance configurée. C'est le seul changement structurel indispensable, et il est circonscrit à `ws.py`.

**🔴 2. Les fichiers transitent par la RAM de FastAPI.**
`await upload.read()` charge tout. Dix personnes qui envoient une vidéo de 50 Mo en même temps = 500 Mo de pic. Avec la vidéo et les fichiers qui arrivent en priorité 1, c'est le prochain incident de production.

*Correction* : URL présignée MinIO. Le client téléverse directement, l'API ne voit qu'une confirmation. Bénéfice double — la RAM, et la bande passante de l'API qui cesse d'être le goulot.

**🟠 3. Le scheduler tourne dans chaque instance.**
`DataSourceScheduler.start()` est appelé au démarrage de l'application. À N instances, le rapport quotidien part N fois, les sondages de sources de données sont faits N fois.

*Correction* : un verrou Redis, ou une variable d'environnement désignant l'instance ordonnanceur. Quelques lignes.

### Ce qui est déjà bon, et qu'il ne faut pas toucher

Les index, la traçabilité (`trace_id` de bout en bout), la file de notifications avec sa clé d'idempotence et son backoff, `pool_pre_ping`, et le fait que `typing` n'écrive rien du tout. Ce dernier point est plus important qu'il n'en a l'air : persister chaque frappe aurait donné un `UPDATE` par mot tapé.

### Ordre de correction recommandé

```
1. Pub/sub Redis pour le WebSocket      ← débloque tout le reste
2. URL présignées MinIO                 ← avant vidéo/fichiers, pas après
3. Verrou du scheduler                  ← quelques lignes
4. Rate limiting sur Redis              ← optionnel, voir la note ci-dessous
5. pool_size / max_overflow explicites  ← avant de dépasser 5 instances
6. Métriques PostgreSQL/Redis/MinIO     ← pour voir venir le prochain mur
```

Note sur le point 4 : vous aviez choisi de garder le plafond en mémoire pour qu'une panne de Redis ne puisse pas rendre l'API muette. Ce raisonnement tient toujours. Si le WebSocket dépend déjà de Redis (point 1), l'argument s'affaiblit — mais un plafond approximatif reste moins grave qu'un temps réel cassé, donc l'ordre proposé les traite séparément.

---

## 3. Ce qu'il ne faut PAS faire maintenant

Confirmé, et pour les mêmes raisons que vous : ni Kubernetes, ni Kafka, ni découpage en microservices, ni Redis Cluster, ni sharding PostgreSQL. Les trois blocages ci-dessus se corrigent **dans la stack actuelle**, et aucun ne demande une brique nouvelle — Redis et MinIO sont déjà là.
