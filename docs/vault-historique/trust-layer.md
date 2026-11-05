# Vault — couche de confiance unifiée

**Pour** : le fondateur, pour arbitrer ; et qui implémentera l'étape 1.
**Statut** : spécification. **Aucun code n'a été modifié.**
**Date** : 24/09/2026.
**Périmètre** : étape 1 du programme en dix points — unification du système
de certification existant. Les étapes 2 à 10 sont seulement *préparées* ici,
pas construites.

---

## 0. Le principe directeur

> **Simple pour l'utilisateur, rigoureux derrière.**

Une seule action visible : **« Certifier mon compte »**. Vault déduit le
parcours. L'utilisateur n'a jamais à savoir qu'il existe un
`SellerVerificationApplication` ou un `ChannelCertificationApplication`, ni
ce que veut dire KYB.

Tout ce document décrit ce qui se passe *derrière* cette phrase.

---

## 1. L'état actuel, vérifié

Vault possède **deux** systèmes de certification. Ils ne sont pas d'accord.

| | Vendeur marketplace | Chaîne |
|---|---|---|
| Table de demande | `seller_verification_applications` | `channel_certification_applications` |
| Prix | 5 000 FCFA, une fois | 3 000/30 j ou 30 000/365 j |
| Pièce d'identité | **obligatoire** (`identity_media_id` NOT NULL) | **aucune** |
| Où vit le badge | `User.is_certified_seller` (booléen) | `Channel.is_verified` + `verified_until` |
| Expiration | **aucune** | oui, évaluée à la lecture |
| Révocation | inexistante | inexistante |
| Motif de refus | `review_note`, texte libre 500 car. | idem |

### Cinq routes accordent ou retirent un badge — trois sans aucune trace

| Route | Fichier | Journal d'audit | Note de décision |
|---|---|---|---|
| `PUT /admin/marketplace/verifications/{id}` | `marketplace_admin.py:202` | ✅ | ✅ |
| `PUT /marketplace/verification/{id}` | `marketplace.py:538` | ❌ | ❌ |
| `PUT /marketplace/sellers/{id}/certification` | `marketplace.py:662` | ❌ | ❌ (aucun dossier) |
| `PUT /channels/certifications/{id}` | `channels.py:~480` | ❌ | ✅ |
| `PUT /channels/{id}/certification` | `channels.py:298` | ❌ | ❌ (aucun dossier, **sans échéance**) |

C'est le même motif qui a coûté un 403 en production : la règle « qui
puis-je joindre » était écrite à quatre endroits, trois avaient divergé.
Ici, c'est « qu'est-ce qu'un compte vérifié » qui est écrit cinq fois.

### Conséquence concrète

Un vendeur certifié en 2026 le reste en 2030 avec une pièce d'identité de
2026. Une chaîne, non. Et si un vendeur vérifié escroque quelqu'un, trois
des cinq chemins ne permettent pas de dire **qui** a décidé, **quand**, ni
**sur quelle pièce**.

---

## 2. Le modèle cible

Deux tables, et la séparation entre les deux porte tout le sens.

```
                     TrustApplication              TrustGrant
                     « le dossier »                « le badge en vigueur »
                            │                              │
                     workflow, documents,          sujet, type, validité,
                     décision, motif               révocation
                            │                              │
                            └──────── grant_id ────────────┘
                                   (nullable)
```

### Pourquoi deux tables, et pas une

Parce qu'il existe des badges **sans dossier** et des dossiers **sans
badge**, et que les confondre est exactement ce qui rend le système actuel
illisible :

- la porte de service de l'équipe accorde un badge sans le moindre dossier
  — elle doit être **enregistrée**, pas dissimulée ;
- un dossier `PENDING` ou `REJECTED` n'accorde rien ;
- un compte peut avoir plusieurs dossiers dans son historique et **un seul**
  badge actif.

Une table unique obligerait une même ligne à signifier tantôt « demande »,
tantôt « droit en cours ». C'est déjà le défaut d'aujourd'hui :
`SellerVerificationApplication` pilote `User.is_certified_seller` par effet
de bord.

### `TrustGrant` — la source de vérité

C'est **lui, et lui seul**, qui répond à « ce compte est-il certifié ? ».

| Colonne | Rôle |
|---|---|
| `subject_type` | `USER \| CHANNEL \| BUSINESS \| STORE` |
| `subject_id` | identifiant dans la table correspondante |
| `kind` | `IDENTITY \| SELLER \| CHANNEL \| BUSINESS \| STORE \| OFFICIAL` |
| `granted_at` | date de décision |
| `expires_at` | `NULL` = sans échéance |
| `revoked_at` | `NULL` = en vigueur |
| `revoked_reason` | vocabulaire contrôlé (§6) |
| `granted_by_admin_id` | qui a décidé — **jamais nullable** hors migration |
| `application_id` | le dossier d'origine, `NULL` pour une décision d'équipe |
| `created_at` |  |

`subject_type` + `subject_id` sans clé étrangère : les sujets vivent dans
des tables différentes (`users`, `channels`, plus tard `businesses`,
`stores`). C'est le prix du polymorphisme, et il est assumé — l'intégrité
est portée par le service, pas par le schéma.

**Un seul badge actif par `(subject_type, subject_id, kind)`** — index
unique partiel sur `revoked_at IS NULL`. Les badges révoqués ou expirés
restent en base : c'est l'historique.

**Un badge est actif si** `revoked_at IS NULL` **et**
(`expires_at IS NULL` **ou** `expires_at > now()`). Évalué à la lecture,
comme le fait déjà `_certification_active()` pour les chaînes — pas de tâche
de fond à surveiller.

### `TrustApplication` — le dossier

| Colonne | Rôle |
|---|---|
| `subject_type`, `subject_id` | le même couple |
| `kind` | ce qui est demandé |
| `requested_by_user_id` | qui a rempli |
| `status` | `PENDING \| APPROVED \| REJECTED \| CANCELLED` |
| `identity_media_id` | nullable — tous les parcours n'en exigent pas |
| `payload` | JSON : les informations légales déclarées (§ étape 7) |
| `payment_id` | nullable, FK `marketplace_payments` |
| `reviewer_id`, `reviewed_at` | la décision |
| `rejection_reason` | vocabulaire contrôlé (§6) |
| `reviewer_note` | texte libre, **interne**, jamais montré au demandeur |
| `document_purge_after` | § étape 2 — rétention des pièces |

`REVOKED` n'est **pas** un statut de dossier : on ne révoque pas une
demande, on révoque un **badge**. C'est `TrustGrant.revoked_at` qui le
porte. Confondre les deux ferait perdre la trace du dossier qui avait été
légitimement approuvé avant la révocation.

---

## 3. Source historique / source de vérité

La distinction que vous avez demandée, rendue explicite dans le schéma.

| | Tables | Statut après migration |
|---|---|---|
| **Source historique** | `seller_verification_applications`, `channel_certification_applications` | **conservées, figées en lecture seule.** Plus aucune écriture. Elles servent à prouver ce qui s'est passé avant la bascule. |
| **Source de vérité** | `trust_applications`, `trust_grants` | seules écrites, seules lues par la logique métier |
| **Miroirs de compatibilité** | `User.is_certified_seller`, `User.certified_seller_at`, `Channel.is_verified`, `Channel.verified_at`, `Channel.verified_until` | **maintenus en écriture par le service**, encore lus par le code existant. Retirés dans une migration ultérieure, quand plus rien ne les lit. |

### Le mécanisme de compatibilité

Pendant la transition, `trust_service.grant()` et `revoke()` écrivent
**toujours** les deux : la ligne `TrustGrant` *et* le miroir sur `User` ou
`Channel`.

Aucun badge ne s'éteint au moment de la bascule, et tout le code qui lit
`seller_is_certified` ou `_certification_active()` continue de fonctionner
sans être touché. On déplace la décision, pas l'affichage.

L'inverse est interdit : **rien ne doit plus écrire les miroirs
directement**. Un test le verrouille (§8).

---

## 4. Correspondance entre l'ancien et le nouveau

### Les dossiers

| Ancien | Nouveau |
|---|---|
| `SellerVerificationApplication` | `TrustApplication(subject_type=USER, kind=SELLER)` |
| `.seller_id` | `.subject_id` **et** `.requested_by_user_id` |
| `.identity_media_id` | `.identity_media_id` |
| `.payment_id` | `.payment_id` |
| `.status` | `.status`, à l'identique |
| `.review_note` | `.reviewer_note` + `.rejection_reason` déduit (§6) |
| `ChannelCertificationApplication` | `TrustApplication(subject_type=CHANNEL, kind=CHANNEL)` |
| `.channel_id` | `.subject_id` |
| `.requested_by` | `.requested_by_user_id` |
| `.plan` (`MONTHLY\|ANNUAL`) | `.payload = {"plan": "..."}` |

### Les badges

| Ancien | Nouveau |
|---|---|
| `User.is_certified_seller = true` | `TrustGrant(USER, SELLER, revoked_at=NULL)` |
| `User.certified_seller_at` | `.granted_at` |
| — (pas d'échéance vendeur) | `.expires_at = NULL` (voir §5, cas 1) |
| `Channel.is_verified = true` | `TrustGrant(CHANNEL, CHANNEL)` |
| `Channel.verified_at` | `.granted_at` |
| `Channel.verified_until` | `.expires_at` |

---

## 5. Migration des données — les huit cas

Règle qui prime sur toutes les autres :

> **Aucune certification actuellement valide ne doit être perdue.**

En cas de doute, la migration **accorde** plutôt que de retirer, et écrit
une ligne de journal. Un badge retiré à tort est visible par l'utilisateur
et coûte sa confiance ; un badge conservé à tort se corrige à la main.

| # | Cas | Ce que fait la migration |
|---|---|---|
| 1 | Vendeur approuvé, sans expiration | `TrustGrant(expires_at=NULL)`. **Les badges existants ne reçoivent pas d'échéance rétroactive** — voir la décision ci-dessous. |
| 2 | Vendeur approuvé, badge actif | `granted_at = certified_seller_at`, ou `reviewed_at` du dossier s'il est nul, ou `created_at` en dernier recours. Jamais `NULL`. |
| 3 | Chaîne approuvée, `verified_until` futur | `expires_at = verified_until`. Badge actif, échéance préservée à la seconde près. |
| 4 | Chaîne expirée | La ligne est créée avec son `expires_at` **passé**. Le badge n'est pas actif, et l'historique est conservé. Ne rien migrer perdrait la trace d'un paiement. |
| 5 | Demande `PENDING` | `TrustApplication(status=PENDING)`, **aucun** `TrustGrant`. La file d'attente de l'équipe est préservée telle quelle. |
| 6 | Demande `REJECTED` | `TrustApplication(status=REJECTED)`, `rejection_reason=UNSPECIFIED_LEGACY`, `reviewer_note` recopié. Aucun badge. |
| 7 | **Incohérence dossier / badge** | **Le badge gagne.** Un dossier `REJECTED` avec `is_certified_seller = true` produit quand même un `TrustGrant` actif, plus une ligne de journal `TRUST_MIGRATION_DISCREPANCY`. C'est ce que l'utilisateur voit aujourd'hui ; le lui retirer en silence serait pire que l'incohérence. |
| 8 | Plusieurs dossiers pour un même compte | Tous migrés comme `TrustApplication`. **Un seul** `TrustGrant`, rattaché au dossier `APPROVED` le plus récent — ou à aucun (`application_id = NULL`) si le badge vient d'une porte de service. |

### Deux décisions — **TRANCHÉES le 24/09/2026**

**(a) Échéance rétroactive pour les vendeurs — ✅ NON.**

Les badges vendeurs migrés conservent `expires_at = NULL`. L'échéance
devient obligatoire pour toute **nouvelle** certification vendeur après la
bascule. **Aucun badge existant ne change d'état du fait de la migration.**

La raison : les vendeurs ont payé 5 000 FCFA pour un badge sans échéance
annoncée. Leur en imposer une le jour de la bascule serait modifier
unilatéralement un contrat payé. L'harmonisation porte sur le MÉCANISME —
une colonne, un calcul, un écran de renouvellement — pas sur l'application
rétroactive d'une politique. **Une migration n'est pas le lieu où une
politique commerciale se décide.**

Contrepartie assumée et documentée : une pièce d'identité de 2026 continuera
d'adosser un badge en 2030 pour la population déjà certifiée. Elle s'éteint
d'elle-même à mesure que la politique s'applique aux nouveaux.

**(b) Incohérence dossier / badge — ✅ LE BADGE FAIT FOI, dans les deux sens.**

| Situation | Dossier | Badge | `TrustGrant` |
|---|---|---|---|
| Écart en faveur | `REJECTED` | actif | **oui**, actif + journal |
| Écart en défaveur | `APPROVED` | inactif | **non** + journal |

Les deux sens comptent. Ne **pas** supprimer un badge actif parce qu'un vieux
dossier dit `REJECTED` ; ne **pas** ressusciter un badge retiré parce qu'un
vieux dossier dit `APPROVED` — un retrait traduit presque toujours une
décision délibérée prise par la porte de service, et la migration ne doit
pas la défaire.

Chaque écart écrit `TRUST_MIGRATION_DISCREPANCY`. Les incohérences
historiques sont traitées **séparément, après** la migration.

**(c) `granted_by_admin_id` pour les lignes migrées — ✅ NULL + `origin`.**

`origin = MIGRATED` et `granted_by_admin_id = NULL` pour les seules lignes
issues de la migration : il est réellement inconnu, et trois des cinq routes
actuelles ne le tracent pas. **Toute décision postérieure à la bascule
l'exige**, ce qui la rend non répudiable sans prétendre reconstruire le
passé.

---

## 6. Motifs de refus et de révocation

Vocabulaire contrôlé, pas de texte libre. Deux raisons : ces motifs sont
**montrés au demandeur**, et ils alimentent les statistiques. « Document
illisible » et « doc pas lisible » ne doivent pas être deux motifs.

**Refus d'un dossier**

`DOCUMENT_UNREADABLE` · `DOCUMENT_EXPIRED` · `IDENTITY_MISMATCH` ·
`BUSINESS_NOT_FOUND` · `DUPLICATE_APPLICATION` · `INCOMPLETE_INFORMATION` ·
`SUSPECTED_FRAUD` · `POLICY_VIOLATION` · `OTHER` (exige `reviewer_note`) ·
`UNSPECIFIED_LEGACY` (**réservé à la migration**, jamais posé par un humain)

**Révocation d'un badge**

`FRAUD_CONFIRMED` · `USER_REQUEST` · `DOCUMENT_INVALIDATED` ·
`BUSINESS_CLOSED` · `POLICY_VIOLATION` · `EXPIRED_NOT_RENEWED` ·
`ADMINISTRATIVE_ERROR` · `OTHER` (exige une note)

`reviewer_note` reste libre, reste **interne**, et n'est jamais montré au
demandeur.

---

## 7. Audit des décisions

Trois niveaux, et ils ne se remplacent pas.

1. **Dans la ligne** — `granted_by_admin_id`, `granted_at`, `revoked_at`,
   `revoked_reason`, `application_id`. La décision se lit sans jointure.
2. **Dans `AuditLogger`** (existant) — une entrée par transition :
   `trust.application.decided`, `trust.grant.granted`, `trust.grant.revoked`.
   Avec l'IP et l'identifiant de l'administrateur.
3. **Par immuabilité** — une révocation **n'efface jamais** le `TrustGrant` :
   elle pose `revoked_at`. Une nouvelle certification crée une **nouvelle
   ligne**. L'historique d'un compte est la liste de ses `TrustGrant`, dans
   l'ordre.

### Une seule route de décision

Les cinq routes actuelles se réduisent à une :
`POST /admin/trust/applications/{id}/decide`, plus
`POST /admin/trust/grants` (décision d'équipe sans dossier, tracée) et
`POST /admin/trust/grants/{id}/revoke`.

Toutes journalisées. Les anciennes routes restent en place le temps de la
transition, mais **réimplémentées par-dessus le service**, pour qu'aucune
ne puisse plus décider dans son coin.

---

## 8. Relations avec `User`, `Channel`, et plus tard `Business` / `Store`

```
TrustGrant (subject_type, subject_id, kind)
    │
    ├── USER    + IDENTITY   → « Identité vérifiée »
    ├── USER    + SELLER     → badge vendeur actuel
    ├── CHANNEL + CHANNEL    → badge de chaîne actuel
    ├── CHANNEL + OFFICIAL   → étape 5 — POSÉ PAR VAULT SEUL
    ├── BUSINESS+ BUSINESS   → étape 7
    └── STORE   + STORE      → étape 8
```

Aucune de ces lignes n'exige de nouvelle table aujourd'hui : `subject_type`
est une chaîne bornée, on lui ajoute une valeur quand l'entité existe.
**C'est précisément ce qui évite de refaire l'architecture plus tard.**

Trois points à figer dès maintenant, même si le code vient plus tard :

- **`OFFICIAL` n'est jamais accessible par le parcours utilisateur.** Ce
  n'est pas un champ qu'on coche : c'est un `kind` que la route publique
  de demande refuse, et que seul `SUPER_ADMIN` peut poser depuis un écran
  distinct. Le §16 de la proposition initiale avait raison, et la
  conséquence est qu'**on ne fait pas passer les comptes officiels par le
  même formulaire ni le même écran d'admin**.
- **Une boutique est un sujet à part entière**, pas un attribut de `User`.
  `STORE` existe dans l'énumération dès l'étape 1, sans table derrière.
- **La chaîne de certification** (entreprise → ses boutiques) se lira par
  `TrustGrant(BUSINESS)` + `Store.business_id`. Rien à prévoir de plus ici.

---

## 9. Vérification

### Les tests de migration — obligatoires

Un test par cas du §5, sur une base réelle, vérifiant après migration :

- le badge est actif si et seulement s'il l'était avant ;
- `expires_at` est identique à `verified_until` à la seconde ;
- aucun `TrustGrant` actif en double pour un même `(sujet, kind)` ;
- les dossiers `PENDING` sont tous là, et en `PENDING` ;
- le cas 7 produit une ligne de journal **dans les deux sens** — badge
  conservé malgré un dossier rejeté, ET badge non ressuscité malgré un
  dossier approuvé.

Plus, par la règle du dépôt : **la migration est conditionnelle et testée
dans les deux ordres de déploiement** — application d'abord
(`create_all()`), puis Alembic d'abord.

### Les tests de non-régression

- `trust_service.grant()` écrit la ligne **et** le miroir ;
- **aucune route n'écrit `is_certified_seller` ni `is_verified`
  directement** — vérifié par un test qui lit le code source, comme celui
  qui garde le branchement du pont d'appel natif. C'est la seule façon
  d'attraper une régression qui compile ;
- un badge expiré n'est pas actif, sans tâche de fond ;
- une révocation prend effet immédiatement et n'efface rien.

---

## 10. Ce que cette étape ne fait PAS

Pour éviter tout malentendu sur le périmètre :

- ❌ aucune nouvelle table `Business` ou `Store` (étapes 7 et 8) ;
- ❌ aucun compte officiel Vault (étape 5) ;
- ❌ aucune messagerie officielle (étape 6) ;
- ❌ aucun changement du parcours utilisateur visible — l'écran unique
  « Certifier mon compte » vient après, une fois que la couche tient ;
- ❌ aucune suppression des anciennes tables ;
- ❌ **aucun journal des consultations de pièces d'identité ni rétention**
  — c'est l'étape 2, et c'est la plus urgente des deux après celle-ci.

---

## 11. Ordre d'exécution proposé

1. `trust_applications` + `trust_grants` + énumérations — migration
   conditionnelle, aucune écriture encore.
2. `trust_service.py` — la seule porte : `is_certified`, `active_grants`,
   `decide`, `grant`, `revoke`. Écrit les miroirs.
3. Migration des données, avec les huit cas testés.
4. Les cinq routes existantes réimplémentées **par-dessus** le service —
   même contrat HTTP, même réponse, décision centralisée.
5. La route `PUT /marketplace/verification/{id}`, qui ne journalise rien,
   est **supprimée** : elle fait doublon avec sa jumelle d'admin qui, elle,
   trace.
6. Écran d'admin unifié — une seule file, tous types confondus.
7. Anciennes tables passées en lecture seule.

Les étapes 1 à 3 ne changent aucun comportement visible : elles peuvent
partir en production sans risque pour les badges existants.
