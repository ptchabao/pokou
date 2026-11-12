# Pokou — documentation officielle de l'écosystème

État au 11 novembre 2026 — application mobile 1.28.1 (50), API en production,
migration de base `0020_token_client`.

Ce document est le point d'entrée d'une équipe qui reprend Pokou sans y avoir
jamais travaillé. Il décrit tout ce qui compose le produit, où chaque chose se
trouve, comment la faire tourner, la déployer et la publier, et ce qui reste à
faire. Les sujets qui ont déjà leur document détaillé y sont résumés, avec le
lien.

**Ce document ne contient aucun secret.** Il dit où ils sont rangés (§ 12).

## Sommaire

1. [Pokou en une page](#1-pokou-en-une-page)
2. [Environnements et adresses](#2-environnements-et-adresses)
3. [Le dépôt](#3-le-dépôt)
4. [L'API (backend)](#4-lapi-backend)
5. [L'application mobile](#5-lapplication-mobile)
6. [Le chiffrement de bout en bout](#6-le-chiffrement-de-bout-en-bout)
7. [Les appels](#7-les-appels)
8. [La console d'administration](#8-la-console-dadministration)
9. [L'espace officine et Pokou Business](#9-lespace-officine-et-pokou-business)
10. [Infrastructure et déploiement](#10-infrastructure-et-déploiement)
11. [Procédures courantes](#11-procédures-courantes)
12. [Secrets et sécurité](#12-secrets-et-sécurité)
13. [Tests et qualité](#13-tests-et-qualité)
14. [État du produit, limites connues et dette](#14-état-du-produit-limites-connues-et-dette)
15. [Décisions récentes à connaître](#15-décisions-récentes-à-connaître)
16. [Glossaire](#16-glossaire)
17. [Première semaine de reprise](#17-première-semaine-de-reprise)
18. [Carte des autres documents](#18-carte-des-autres-documents)

---

## 1. Pokou en une page

Pokou est une messagerie chiffrée de bout en bout pour l'Afrique de l'Ouest
(Togo et Côte d'Ivoire d'abord), autour de laquelle s'ouvrent des services du
quotidien. Identifiant de l'application : `com.pokou.pokou`.

| Service | Ce qu'il fait |
|---|---|
| Discussions | Messages à deux et en groupe, médias, notes vocales, stickers, statuts 24 h, appels audio et vidéo, communautés, chaînes publiques, listes de diffusion |
| Kory | Cagnottes, cotisations et tontines. Pokou tient le journal ; l'argent passe de wallet à wallet, jamais par Pokou |
| Honam | Pharmacie : envoi d'ordonnance, devis d'une officine, paiement, livraison par coursier |
| Assimé | Petites annonces : publier, chercher, contacter le vendeur, vendeur vérifié, mise en avant payante |
| Pokou certifié | Badge d'identité vérifiée et « mode preuve » (messages supprimés gardés barrés, export PDF) |
| Modules | Catalogue de fonctions sociales activables (Ligue des cœurs, Série de flammes, Marché de la vérité, Taxe sociale, Salon VIP, Hype Train, Spark, versets) |
| Baba | Assistant IA (traduire, résumer, répondre) |
| Pokou Business | API et portail pour les entreprises (robots, facturation) |

### Les composants

```
 Téléphones (Flutter, Android / iOS)          Navigateur
 ┌──────────────────────────────┐   ┌────────────────────────────┐
 │ App Pokou                    │   │ Console d'admin (/console) │
 │  chiffrement sur l'appareil  │   │ Espace officine (/officine)│
 └───────┬───────────┬──────────┘   └──────────────┬─────────────┘
   HTTPS + WebSocket │ médias WebRTC                │ HTTPS
         │           │                              │
 ┌───────▼───────────│──────────────────────────────▼─────────────┐
 │ API Pokou (FastAPI, Python 3.12)   apipokou.cabinet-p-et-…com  │
 │  /api/v1/*  ·  /console  ·  /officine  ·  /.well-known         │
 └───┬────────┬────────┬─────────────│────────────┬───────────────┘
     │        │        │             │            │
 PostgreSQL  Redis   Kafka     ┌─────▼─────┐   Services externes :
  (données) (débit, (événements│  LiveKit  │   Firebase (push), Twilio
            verrous) métier)   │ + relais  │   (SMS, WhatsApp), Semoa
                               │   TURN    │   (paiement), IA (Baba),
                               └───────────┘   Google Drive (sauvegarde)
```

### Les ordres de grandeur

| | |
|---|---|
| API | environ 490 routes, 116 tables, 20 migrations |
| App mobile | 326 fichiers Dart, 6 langues, environ 2 100 textes |
| Tests | 78 fichiers côté API, 94 fichiers (684 tests) côté app |
| Console | 12 pages (Next.js, export statique) |

### Le principe à retenir avant tout

**Le serveur ne lit pas les messages.** Texte, médias, statuts et appels sont
chiffrés sur le téléphone. Tout ce qui demande de lire un contenu (aperçu,
mentions, recherche, modération du contenu) se fait sur l'appareil ou pas du
tout. Beaucoup de choix du code en découlent (§ 6).

---

## 2. Environnements et adresses

Il n'y a **qu'un environnement en ligne : la production**. Le reste se fait en
local.

| Quoi | Adresse |
|---|---|
| API | `https://apipokou.cabinet-p-et-associes.com` (préfixe `/api/v1`) |
| État de l'API | `/health` (200 attendu) ; documentation interactive `/docs` |
| Console d'administration | `https://apipokou.cabinet-p-et-associes.com/console/` |
| Espace officine (pharmacies) | `https://apipokou.cabinet-p-et-associes.com/officine/` |
| Appels (signalisation LiveKit) | `wss://rtc.cabinet-p-et-associes.com` |
| Appels (médias) | `169.58.195.18` : 7881/TCP, 7882/UDP, relais TURN 3478/UDP |
| Plateforme d'hébergement | Kubero : `https://kubero.169.58.195.18.sslip.io` |
| Dépôt | GitHub, branche `main` |
| Firebase | projet `pokou-3b047` (apps Android et iOS `com.pokou.pokou`) |

Cloudflare est placé devant `apipokou.…` et `rtc.…` (proxy). Il ne relaie pas
l'UDP : c'est pourquoi les médias des appels vont à l'IP du serveur.

Les domaines définitifs prévus par le cahier des charges (`api.pok.app`,
`pok.app`) ne sont pas en service ; voir [mise-en-service.md](mise-en-service.md).

---

## 3. Le dépôt

```
pokou/
├── backend/                API FastAPI
│   ├── app/
│   │   ├── api/v1/<domaine>/   routes, un dossier par domaine
│   │   ├── api/public/         pages servies hors /api/v1 (console, officine, liens)
│   │   ├── core/               config, base, sécurité, droits, planificateur
│   │   ├── models/             tables SQLAlchemy
│   │   ├── schemas/            schémas Pydantic partagés
│   │   ├── services/<domaine>/ logique métier et clients externes
│   │   ├── middleware/         limite de débit
│   │   ├── workers/            relais des événements vers Kafka
│   │   ├── console/            export statique de la console (GÉNÉRÉ, committé)
│   │   ├── officine/           espace officine (HTML/JS/CSS)
│   │   ├── legal/, suppression/  pages légales et suppression de compte
│   ├── alembic/versions/       migrations 0001 → 0020
│   ├── scripts/                seed.py, promote_admin.py
│   ├── tests/                  78 fichiers
│   ├── docker-entrypoint.sh    attente de la base, migrations, seed, démarrage
│   ├── kubero-build.sh, kubero-run.sh   déploiement Kubero sans image
│   └── Dockerfile, requirements*.txt, alembic.ini, pytest.ini
├── mobile/                 application Flutter
│   ├── lib/core/               socle : api, crypto, sync, stockage, thème…
│   ├── lib/features/<domaine>/ écrans et données par fonctionnalité
│   ├── lib/l10n/               textes (fr, en, es, it, ru, ar)
│   ├── android/, ios/, web/    projets natifs
│   ├── assets/                 polices, illustrations, sons, papier peint
│   ├── test/                   94 fichiers ; test/preview = rendus d'écrans
│   ├── tool/design_tour.dart   parcours automatique pour captures
│   ├── build-production.sh, build-ios.sh
│   └── release-notes/          notes de version par numéro
├── admin/                  console d'administration (Next.js, shadcn/ui)
├── deploy/
│   ├── kubero/                 déploiement EN SERVICE (scripts, secrets hors git)
│   └── k8s/                    manifestes Kubernetes (cible, non utilisés aujourd'hui)
├── docs/                   documentation (ce fichier, guides, plan de test)
├── docker-compose.yml      PostgreSQL, Redis, MinIO, API pour le développement
├── Makefile                raccourcis (`make help`)
└── .github/workflows/api-image.yml   construction de l'image (inactif, voir § 10)
```

À la racine se trouvent aussi les **sources de référence, hors code** :

| Fichier ou dossier | Contenu |
|---|---|
| `POKOU_Cahier_des_charges_v3.4.pdf` (et v3.2) | le cahier des charges, référence fonctionnelle |
| `Pokou_vues_cahier_v3.4.md`, `Pokou_Maquettes_ecrans.pdf` | écrans attendus |
| `pokou-design-tokens.json` | jetons de design (couleurs, rayons, typographie) |
| `stitch_google_design_system_interface/`, `stitch_maquettes_compl_tes_d_interface/` | maquettes « Terre de Confiance » (non versionnées) |
| `IconKitchen/`, `Pokou-logos/` | icônes et logos sources |
| `pokou.db`, `media_storage/`, `backend/test_*.db` | fichiers locaux de développement et de test, à ne pas versionner |

---

## 4. L'API (backend)

### 4.1 Technique

Python 3.12, FastAPI, SQLAlchemy, Alembic, Pydantic. PostgreSQL en production
(SQLite par défaut en local et dans les tests). Redis pour la limite de débit,
les verrous et le registre temps réel. Kafka pour les événements métier.

Bibliothèques notables : `python-jose` et `bcrypt` (sessions, mots de passe),
`phonenumbers`, `Pillow` (miniatures), `boto3` (stockage S3), `livekit-api`,
`firebase-admin`, `reportlab` (PDF), `aiokafka`, `google-genai`.

### 4.2 Démarrer en local

```bash
make backend-setup     # virtualenv + dépendances
make backend-run       # http://localhost:8000/docs (SQLite)
make backend-test
make up                # tout sous Docker : PostgreSQL, Redis, MinIO, API
make migration m="message"   # nouvelle migration ; make migrate pour l'appliquer
```

En local, `Base.metadata.create_all` crée le schéma au démarrage. En
production, c'est Alembic qui le pose.

### 4.3 Où ranger quoi

| Besoin | Endroit |
|---|---|
| Une route | `app/api/v1/<domaine>/`, déclarée dans `app/api/router.py` |
| Une page servie hors `/api/v1` | `app/api/public/` |
| Une table | `app/models/<domaine>.py`, exportée dans `models/__init__.py`, plus une migration |
| De la logique partagée ou un client externe | `app/services/<domaine>/` |
| Un réglage | `app/core/config.py` (variable d'environnement du même nom, en majuscules) |
| Un réglage modifiable sans redéployer | table `system_settings` (`services/settings_service.py`) |

### 4.4 Carte des routes

Toutes sous `/api/v1`. Le nombre indique les routes du fichier.

| Préfixe | Fichier (`app/api/v1/…`) | Rôle |
|---|---|---|
| `/auth` (9) | `auth/auth.py` | code SMS, vérification en deux étapes, session, rafraîchissement, déconnexion, profil courant |
| `/devices` (3) | `auth/devices.py` | jetons de notification, sessions par appareil |
| `/e2ee` (4) | `auth/e2ee.py` | trousseau public de chiffrement, pré-clés |
| `/e2ee/retries` (4) | `e2ee_retry/e2ee_retry.py` | demandes de nouvel envoi d'un message illisible |
| `/account-privacy` (10), `/account/phone` (2), `/contacts` (6) | `account/` | confidentialité, code PIN, changement de numéro, carnet |
| `/messages` (16) | `messaging/messages.py` | messages à deux : envoi, édition, suppression, réactions, mode preuve |
| `/groups` (30) | `messaging/groups.py` | groupes, membres, invitations, messages, clés d'expéditeur |
| `/conversations` (7) | `messaging/conversations.py` | liste des discussions, archivage, signalement |
| `/sync` (1) | `messaging/sync.py` | rattrapage des événements manqués |
| `/presence` (5) | `messaging/presence.py` | en ligne, vu à, saisie en cours |
| `/polls` (7) | `messaging/polls.py` | sondages (fermés dans les groupes, voir § 14) |
| `/broadcasts` (6) | `messaging/broadcasts.py` | listes de diffusion |
| `/link-preview` (2) | `messaging/link_preview.py` | aperçu de liens |
| `/ws` | `messaging/ws.py` | WebSocket temps réel |
| `/communities` (12), `/channels` (22) | `communities/` | communautés et chaînes publiques |
| `/calls` (6) | `calls/calls.py` | jetons d'appel LiveKit, invitations, journal |
| `/media` (5), `/status` (8), `/stickers` (15) | `media/` | pièces jointes, statuts, stickers |
| `/backup` (3) | `backup/backup.py` | sauvegarde chiffrée (métadonnées et pointeur) |
| `/notifications` (3) | `notifications/notifications.py` | centre de notifications de service |
| `/kory` (14) | `kory/kory.py` | cagnottes, cotisations, tontines |
| `/honam`, `/admin/honam` (50) | `honam/honam.py` | patient, officine (`/honam/pharmacy`), coursier (`/honam/courier`), administration |
| `/marketplace`, `/admin/marketplace` (45) | `marketplace/` | Assimé : annonces, avis, ventes, publicités, vérification vendeur, configuration |
| `/certified`, `/admin/certified` (10) | `certified/certified.py` | badge, mode preuve, dossiers Pro |
| `/modules`, `/admin/modules` (5) | `modules/modules.py` | catalogue des modules |
| `/heart-league`, `/streaks`, `/truth`, `/ceremonies`, `/vip`, `/hype` | `modules/*.py` | les modules eux-mêmes |
| `/spark`, `/spark-admin` (49) | `spark/` | rencontres, rendez-vous, sécurité |
| `/baba` (3) | `baba/baba.py` | assistant IA |
| `/business`, `/admin/business`, `/bot/v1` (46) | `business/` | Pokou Business |
| `/admin` (19) | `admin/admin.py` | console : connexion, tableau de bord, utilisateurs, équipe, signalements, audit |
| `/config` (1) | `config/country.py` | modules ouverts dans le pays de l'utilisateur |
| `/webhooks` (1) | `payments/webhooks.py` | retour de paiement Semoa |
| `/shield` (2) | `safety/shield.py` | Mode Bouclier (retiré de l'app, voir § 14) |

Hors `/api/v1` (`app/api/public/`) : `/console/*`, `/officine/*`,
`/.well-known/assetlinks.json` et `apple-app-site-association` (liens qui
ouvrent l'app), liens d'invitation (`/invite/*`, `/c/*`, `/channel/*`,
`/bot/*`), pages légales, page de suppression de compte.

### 4.5 Connexion et sessions

| Mécanisme | Règle |
|---|---|
| Code de connexion | 6 chiffres, valable 50 secondes, envoyé par SMS et WhatsApp |
| Essais | 5 codes faux puis blocage de 15 minutes ; 3 demandes de code par 15 minutes |
| Jeton d'accès | 30 minutes |
| Jeton de rafraîchissement | 10 ans, changé à chaque usage, avec une minute de grâce si la réponse se perd |
| Révocation | chaque session est une ligne `tokens` ; la révoquer coupe l'accès tout de suite |
| Vérification en deux étapes | code PIN facultatif, demandé après le SMS ; « PIN oublié » ouvre un délai de 7 jours |
| **Un seul téléphone par compte** | une connexion depuis l'app ferme les sessions des autres téléphones et supprime leurs jetons de notification. Les sessions web (officine) et console ne sont pas touchées (`tokens.client` : `app`, `web`, `console`) |
| Console | e-mail et mot de passe, session de 8 heures marquée `scope = console`, exigée par toutes les routes d'administration (§ 8) |
| WebSocket | ouvert avec un ticket à usage unique, valable quelques secondes (`ws_tickets`) |
| Actions depuis une notification | jetons d'action à usage unique (`action_tokens`) |

L'app s'identifie par l'en-tête `X-Pokou-Crypto` (version du protocole de
chiffrement, aujourd'hui `2`). En dessous, l'envoi en groupe répond 426.

Deux garde-fous au démarrage (`core/startup_checks.py`) : l'API refuse de
démarrer en production avec les secrets par défaut, ou avec le code de
connexion fixe prévu pour la revue des stores (`REVIEW_PHONE_NUMBERS`,
`REVIEW_OTP_CODE`).

### 4.6 Rôles et droits

Rôles (`UserRole`) : `USER`, `VIEWER`, `SUPPORT`, `AI_OPERATOR`, `ADMIN`,
`SUPER_ADMIN`. La correspondance rôle → permissions est dans
`core/permissions.py`. Le rôle est relu en base à chaque requête. Détail et
tableau complet : [administration.md](administration.md).

### 4.7 Temps réel et rattrapage

- **WebSocket** (`messaging/ws.py`) : pousse les événements aux appareils
  connectés. Types principaux : `message:new`, `message:edited`,
  `message:deleted`, `message:reaction`, `message:status`, `typing`,
  `group:message:new` (et variantes), `group:invitation`,
  `group:member:added/removed/role`, `group:updated`, `status:new`,
  `status:deleted`, `call:invite`, `call_end`, `kory:updated`,
  `honam:order_updated`, `channel:post`, `user:profile_updated`,
  `conversation:updated`, `poll:vote`, `location:update`.
- **Registre partagé** (`services/messaging/ws_registry.py`) : avec plusieurs
  instances de l'API, Redis sait sur laquelle chaque utilisateur est connecté.
- **Rattrapage** (`/sync`, table `sync_events`) : un appareil qui était hors
  ligne redemande ce qu'il a manqué. Le WebSocket est un accélérateur, pas la
  source de vérité. Les numéros d'événement et les curseurs portent la
  « génération » de la base (`3f9a1c2e.93`, clé `sync_generation` de
  `system_settings`) : après une remise à zéro, un curseur de l'ancienne base
  repart de 0 au lieu de sauter des événements. Côté app, les données locales
  appartiennent à un compte (`PokouMessageStore.claimFor`) : se connecter avec
  un autre compte les efface.
- **Présence** : « vu à » n'est écrit qu'aux connexions et déconnexions ;
  « écrit… » n'est jamais enregistré.

### 4.8 Médias

`/media` reçoit les pièces jointes (25 Mo maximum). Stockage sur disque
(`MEDIA_STORAGE_DIR`) ou sur S3 si `S3_*` est renseigné. En production : disque,
sur un volume de 10 Go. Les médias de conversation sont chiffrés par l'app avant
l'envoi ; le serveur ne garde que des octets illisibles. Les droits d'accès à un
fichier suivent l'appartenance à la discussion ou au groupe.

### 4.9 Notifications, SMS et WhatsApp

| Canal | Service | Réglages |
|---|---|---|
| Notifications de l'app | Firebase Cloud Messaging (`services/notifications/push_service.py`) | `FCM_ENABLED`, `FIREBASE_CREDENTIALS_JSON` ou `_PATH` |
| Codes de connexion | Twilio Verify (`twilio_verify.py`) : Twilio génère, envoie et vérifie le code ; Pokou garde débit, délai de renvoi et verrouillage. Repli : code Pokou par SMS si Verify refuse | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` (facultatif : le service « Pokou » est retrouvé ou créé), `TWILIO_VERIFY_ENABLED` |
| SMS | Twilio, secours NGH (`sms_service.py`) | `TWILIO_*`, `NGH_*`, `SMS_SENDER_ID` |
| WhatsApp | Twilio ou passerelle interne (`whatsapp_service.py`) | `TWILIO_WHATSAPP_FROM`, `WHATSAPP_SERVICE_URL` |
| Centre de notifications | table `service_notifications` (`inbox.notify`) | — |

Le contenu d'une notification de message n'est pas lisible par le serveur :
l'app le déchiffre à la réception.

### 4.10 Paiements

Semoa (CashPay) est le prestataire (`services/payments/semoa_client.py`). Ses
identifiants sont dans la table `system_settings` (`semoa_login`,
`semoa_api_key`, `semoa_api_reference`, `semoa_gateway_id`,
`semoa_webhook_secret`), pas dans l'environnement. Le retour de paiement arrive
sur `/api/v1/webhooks/marketplace-payment/semoa` et reste fermé tant que
`semoa_webhook_secret` n'est pas renseigné.

Sont payants : badge vendeur vérifié (3 000 FCFA par mois, 30 000 FCFA par an,
réglable), mise en avant d'annonce et de statut, publicités, Pokou certifié,
certains modules. **Kory ne fait transiter aucun argent.** Taxe sociale encaisse
sur le compte marchand de Pokou et le reversement à l'organisateur est manuel.

### 4.11 Pays

`core/countries.py` décide des modules ouverts selon l'indicatif du numéro.

| Pays | Modules |
|---|---|
| Togo | discussions, Kory, Honam, Assimé, Pokou certifié |
| Côte d'Ivoire | discussions, Kory, Honam, Assimé |
| Autres | discussions, Kory, Honam |

Devise : XOF partout. L'app lit sa configuration sur `/config/country`.

### 4.12 Limite de débit

`middleware/rate_limit.py`, par minute et par client : 1 200 requêtes en
général, 240 sur les routes coûteuses et sur `/auth`. Le WebSocket, `/health`
et la documentation en sont exclus. Sans Redis, la limite est tenue par
processus.

### 4.13 Tâches planifiées

`core/scheduler.py`. Une seule instance les exécute à la fois (verrou Redis).

| Tâche | Fréquence |
|---|---|
| Nettoyage des appels restés ouverts | chaque minute |
| Facturation et webhooks Pokou Business | toutes les 20 secondes |
| Rappels d'abonnement des pharmacies | chaque minute |
| Purge des statuts expirés | toutes les 30 à 60 minutes |

### 4.14 Événements métier et Kafka

Les routes écrivent leurs événements dans la table `outbox_events`
(`services/events/outbox.py`) ; un relais (`workers/outbox_relay.py`, processus
`PROC_TYPE=worker`) les publie vers Kafka. Sans Kafka, le relais se met en
veille et les événements restent en base (7 jours).

### 4.15 Journal d'audit

`core/audit.py` et la table `audit_logs` : connexions, actions de l'équipe
(suspension, rôle, signalement, mot de passe de console). Visible dans la
console.

### 4.16 La base : tables par domaine

116 tables. Les principales :

| Domaine | Tables |
|---|---|
| Comptes et sessions | `users`, `tokens`, `phone_otps`, `ws_tickets`, `action_tokens`, `device_tokens`, `contacts` |
| Chiffrement | `device_key_bundles`, `one_time_prekeys`, `group_sender_key_distributions`, `e2ee_retries` |
| Messages | `direct_messages`, `message_reactions`, `direct_proof_modes`, `groups`, `group_members`, `group_invitations`, `group_join_requests`, `group_messages`, `group_message_reactions`, `group_message_mentions`, `sync_events` |
| Diffusion | `broadcast_lists`, `broadcast_list_members`, `broadcast_messages`, `communities`, `community_members`, `channels`, `channel_members`, `channel_posts` (et réactions, vues, certification) |
| Médias | `media_assets`, `statuses`, `status_recipients`, `status_privacy`, `status_privacy_entries`, `status_views`, `sticker_packs`, `stickers` (et favoris, récents) |
| Appels | `call_logs`, `call_participants` |
| Sondages | `polls`, `poll_options`, `poll_votes` |
| Kory | `kory_pots`, `kory_members`, `kory_entries`, `kory_rounds`, `kory_invites` |
| Honam | `honam_pharmacies`, `honam_pharmacy_staff`, `honam_orders`, `honam_order_events`, `honam_order_messages`, `honam_couriers`, `honam_pharmacy_couriers`, `honam_courier_ledger`, `honam_waitlist` |
| Assimé | `marketplace_products`, `marketplace_product_images`, `seller_reviews`, `marketplace_payments`, `marketplace_boosts`, `marketplace_favorites`, `marketplace_alerts`, `marketplace_ads`, `seller_verification_applications` |
| Pokou certifié | `certified_subscriptions`, `certified_pro_applications` |
| Modules | `app_modules`, `user_module_activations`, `heart_league_*`, `conversation_streaks`, `truth_questions`, `ceremony_*`, `vip_*`, `hype_*`, `spark_*` |
| Pokou Business | `business_organizations`, `business_organization_members`, `business_bots`, `business_api_keys`, `business_ledger`, `business_usage`, `business_invoices`, `business_webhook_deliveries`, `business_test_numbers` |
| Divers | `user_backups`, `baba_messages`, `service_notifications`, `abuse_reports`, `audit_logs`, `system_settings`, `outbox_events` |

### 4.17 Migrations

`backend/alembic/versions/`, appliquées dans l'ordre au démarrage.

| N° | Objet |
|---|---|
| 0001 | schéma initial |
| 0002 | Kory |
| 0003 | événements (outbox) |
| 0004 | consentements |
| 0005 | Pokou certifié, mode preuve |
| 0006 | Honam |
| 0007, 0008 | maquettes, finalisation |
| 0009, 0010 | rappels d'abonnement pharmacie, messages de commande |
| 0011 | statuts chiffrés |
| 0012 | clés d'expéditeur de groupe |
| 0013 | demande de réinitialisation du PIN |
| 0014 | messages de Baba |
| 0015 | réglages de groupe |
| 0016 | nouveaux essais de déchiffrement |
| 0017 | promesses Kory, invitations, notifications de service, sauvegardes |
| 0018 | signalements (espace d'administration) |
| 0019 | mot de passe de console |
| 0020 | type de client des sessions (un seul téléphone) |

### 4.18 Données de départ

`backend/scripts/seed.py`, joué à chaque démarrage après les migrations, sans
rien écraser : il crée le catalogue des modules et le super-administrateur de
la console (variables `POKOU_SUPERADMIN_*`). Détail :
[administration.md](administration.md) § 2. `scripts/promote_admin.py` donne
un rôle à un compte existant, en ligne de commande.

### 4.19 Variables d'environnement

Toutes définies dans `app/core/config.py`. Les principales :

| Groupe | Variables |
|---|---|
| Base | `DATABASE_URL`, `DB_POOL_SIZE`, `DB_MAX_OVERFLOW`, `REDIS_URL` |
| Sécurité | `SECRET_KEY`, `WEBHOOK_HMAC_SECRET`, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`, `ENVIRONMENT`, `DEBUG` |
| Démarrage | `RUN_MIGRATIONS`, `UVICORN_WORKERS`, `FORWARDED_ALLOW_IPS`, `PROC_TYPE` |
| Médias | `MEDIA_STORAGE_DIR`, `MEDIA_MAX_SIZE_MB`, `S3_ENDPOINT_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET` |
| Appels | `LIVEKIT_ENABLED`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` |
| Notifications | `FCM_ENABLED`, `FIREBASE_CREDENTIALS_JSON` |
| SMS, WhatsApp | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_SMS_FROM`, `TWILIO_MESSAGING_SERVICE_SID`, `TWILIO_WHATSAPP_FROM`, `NGH_API_KEY`, `NGH_API_SECRET`, `SMS_SENDER_ID`, `WHATSAPP_SERVICE_URL` |
| Liens | `PUBLIC_API_URL`, `PUBLIC_LINK_BASE_URL`, `ANDROID_PLAY_SIGNING_SHA256`, `APPLE_TEAM_ID` |
| Assistant | `GEMINI_*`, `GROQ_*`, `DEEPSEEK_*`, `GROK_*`, `OLLAMA_*` (chacun avec `_ENABLED`, `_API_KEY`, `_MODEL`) |
| Kafka | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_SECURITY_PROTOCOL`, `KAFKA_SASL_*`, `KAFKA_TOPIC_PREFIX` |
| Console | `POKOU_SUPERADMIN_EMAIL`, `POKOU_SUPERADMIN_PASSWORD`, `POKOU_SUPERADMIN_NAME`, `POKOU_SUPERADMIN_PHONE` |
| Revue des stores | `REVIEW_PHONE_NUMBERS`, `REVIEW_OTP_CODE` (interdits en production) |

---

## 5. L'application mobile

### 5.1 Technique

Flutter (Dart), Android et iOS ; une cible web existe aussi. État : Riverpod.
Stockage local chiffré : `sqflite_sqlcipher`. Secrets de l'appareil :
`flutter_secure_storage`. Chiffrement : `libsignal_protocol_dart`,
`cryptography`. Appels : `livekit_client`. Notifications : `firebase_messaging`,
`flutter_local_notifications`.

### 5.2 Démarrer

```bash
make mobile-setup
make mobile-run        # émulateur Android contre l'API locale
make mobile-test
make mobile-analyze
```

Réglages au moment du build (`--dart-define`) :

| Nom | Rôle | Défaut |
|---|---|---|
| `API_BASE_URL` | adresse de l'API | `https://apipokou.cabinet-p-et-associes.com/api/v1` |
| `POKOU_VERSION` | version affichée dans « À propos » | — |
| `POKOU_LINK_HOST` | domaine des liens d'invitation | celui de l'API |
| `MAHIZU_API_BASE_URL` | ancien service d'assistant (reliquat, § 14) | `https://api.mahizu.com/api/v1` |

L'outillage de build du Mac actuel (JDK 17, CocoaPods, outils Android) est
décrit dans `mobile/README.md` et [publication-mobile.md](publication-mobile.md).

### 5.3 Organisation du code

`lib/core/` — le socle :

| Dossier | Rôle |
|---|---|
| `api/` | client HTTP, rafraîchissement de session, erreurs |
| `ws/` | WebSocket, reconnexion |
| `sync/` | file d'envoi hors ligne, moteur de rattrapage, envoi des médias |
| `storage/` | base locale chiffrée, clé de la base, jetons |
| `crypto/` | sessions à deux, clés d'expéditeur de groupe, chiffrement des médias, clés d'appel, nouveaux essais |
| `backup/` | sauvegarde chiffrée, Google Drive |
| `push/`, `notifications/` | notifications |
| `calls/` | pont avec le code natif des appels |
| `router/` | routes d'entrée (`/welcome`, `/onboarding`, `/phone`, `/otp`, `/inbox`, `/chat/:id`) ; le reste se navigue par empilement d'écrans |
| `theme/`, `widgets/` | couleurs, rayons, typographie, composants partagés, illustrations |
| `country/`, `settings/`, `security/`, `deeplink/`, `sharing/`, `media/`, `identity/`, `time/`, `text/`, `l10n/` | configuration pays, réglages, verrouillage de l'app, liens, partage, etc. |
| `mahizu/` | reliquat de l'ancien assistant |

`lib/features/` — une fonctionnalité par dossier, chacun avec `data/`
(modèles, dépôt) et `presentation/` (écrans, contrôleurs) :

`auth`, `inbox` (coquille à onglets), `home` (accueil, Plus, recherche),
`contacts` (liste des discussions), `messaging` (discussion à deux, barre de
saisie, bulles), `groups`, `communities`, `channels`, `broadcasts`, `calls`,
`status`, `stickers`, `presence`, `profile`, `settings`, `notifications`,
`kory`, `honam`, `marketplace` (Assimé), `modules` (catalogue et modules),
`chat` (assistant Baba), `shield` (reliquat).

### 5.4 Fonctionnement hors ligne

- Les discussions et messages sont lus dans la base locale, puis mis à jour.
- Un envoi sans réseau entre dans une file (`sync/outbox_service.dart`) et part
  au retour du réseau.
- À la reconnexion, le moteur (`sync/pokou_sync_engine.dart`) rattrape les
  événements manqués par `/sync`.

### 5.5 Textes et langues

`lib/l10n/app_<langue>.arb` : français (référence), anglais, espagnol, italien,
russe, arabe (affichage de droite à gauche). Un texte absent d'une langue
retombe sur le français. Après modification : `flutter gen-l10n`. Un test
(`test/l10n/`) vérifie la cohérence des six langues ; il refuse notamment une
branche de pluriel faite d'un seul mot.

### 5.6 Apparence

- Palette « Terre de Confiance » : terre cuite, or, ébène, crème
  (`core/theme/app_colors.dart`). Les couleurs se lisent par `AppColors`, sans
  contexte ; au changement clair/sombre, tout l'écran est reconstruit.
- Polices : Inter (texte), Outfit (titres).
- Illustrations : `assets/illustrations/` (unDraw, recolorées), via
  `core/widgets/pokou_illustration.dart`.
- La taille de texte du téléphone est suivie jusqu'à +50 %.
- Description complète de l'interface : [design-ui-ux.md](design-ui-ux.md).

### 5.7 Code natif Android

`android/app/src/main/kotlin/com/pokou/pokou/` : service d'appel en cours,
sonnerie et vibration (`call/RingtoneService.kt`), réponses rapides depuis une
notification, image dans l'image. L'intégration au système d'appels d'Android
(`call/PokouTelecom.kt`) est **désactivée** (§ 7).

### 5.8 Outils de relecture visuelle

- `tool/design_tour.dart` : lance l'app réelle et navigue seule, pour prendre
  des captures (`flutter run -t tool/design_tour.dart`). Il ne publie rien,
  mais il ouvre des discussions : les accusés de lecture partent.
- `test/preview/` : rend des écrans en PNG sans simulateur
  (`POKOU_PREVIEW=/dossier flutter test test/preview`). Sans la variable, il ne
  fait rien.

---

## 6. Le chiffrement de bout en bout

Résumé ; le détail est dans les documents cités.

| Contenu | Méthode | Document |
|---|---|---|
| Messages à deux | session chiffrée entre les deux appareils (protocole Signal : identité, pré-clés, clé qui avance à chaque message) | `mobile/README.md` § Chiffrement |
| Messages de groupe | une « clé d'expéditeur » par membre et par époque du groupe, remise à chacun par sa session à deux | [e2ee-group-messages.md](e2ee-group-messages.md) |
| Médias | chaque fichier est chiffré avec sa propre clé, qui voyage dans le message | `core/crypto/media_cipher.dart` |
| Statuts | scellés pour chaque contact autorisé ; le fond et la police d'un statut en texte voyagent dans le chiffré | [e2ee-statuses.md](e2ee-statuses.md) |
| Appels | clé éphémère par appel, scellée pour chaque participant | [chiffrement-appels-groupe.md](chiffrement-appels-groupe.md) |
| Sauvegarde | chiffrée par un mot de passe que le serveur ne connaît pas (AES-256-GCM, PBKDF2) | `core/backup/` |

Ce qu'il faut savoir pour ne pas casser les choses :

1. **Une identité par compte, donc un téléphone par compte.** L'app publie son
   trousseau à chaque démarrage (`/e2ee/bundle`). Deux téléphones sur un compte
   se reprenaient l'identité : les messages n'étaient lisibles que sur le
   dernier démarré. D'où la règle du § 4.5.
2. **Un changement d'identité** (nouveau téléphone, réinstallation) purge les
   clés de groupe remises à l'ancien appareil et prévient les contacts.
3. **Message illisible** : l'app affiche « En attente de ce message… » et
   demande un nouvel envoi (`/e2ee/retries`). L'expéditeur le rescelle quand son
   app est ouverte. S'il n'a plus le texte, la demande est close.
4. **Jamais de repli en clair.** Un échec de chiffrement arrête l'envoi.
5. Le serveur refuse tout message de groupe en clair. Mentions, aperçu d'une
   citation, texte d'une correction : tout cela voyage dans le chiffré.
6. Les sondages, positions et fiches de contact de groupe ne sont pas encore
   chiffrés : ils sont fermés (§ 14).

---

## 7. Les appels

- **Serveur de médias** : LiveKit 1.13, auto-hébergé sur Kubero (app `livekit`).
  L'API délivre les jetons d'accès (`/calls`, valables 15 minutes).
- **Sonnerie** : invitation par WebSocket si l'app est ouverte, par
  notification sinon ; l'écran d'appel entrant affiche le nom et la photo de
  l'appelant ou du groupe. 32 membres au plus sont sonnés pour un appel de
  groupe.
- **Réseau** : les médias vont à l'IP du serveur (7881/TCP, 7882/UDP). Un
  **relais TURN** intégré (3478/UDP) sert les réseaux mobiles qui bloquent le
  média direct. Il est annoncé sous l'IP, pas sous le nom de domaine, parce que
  Cloudflare ne relaie pas l'UDP.
- **Coupure réseau en appel** : l'app attend 25 secondes le retour du
  correspondant avant de raccrocher.
- **Intégration au système d'appels d'Android : désactivée.** Sur Android 15 et
  16, elle rendait l'appel muet des deux côtés. Conséquence : un appel
  téléphonique en cours n'est plus mis en attente quand un appel Pokou démarre.
- Scripts : `deploy/kubero/build_livekit_json.py` (création) et
  `apply_livekit_turn.py` (activer le relais sur l'app en service). Détail :
  [deploiement-kubero.md](deploiement-kubero.md) § 9.

---

## 8. La console d'administration

Document complet : [administration.md](administration.md).

- Adresse : `/console/` sur l'API. Code : `admin/` (Next.js 15, shadcn/ui,
  Tailwind 4), exporté en fichiers statiques dans `backend/app/console/`.
- Connexion par e-mail et mot de passe uniquement. 5 échecs bloquent 15 minutes.
- Premier super-administrateur créé par le seed ; son mot de passe initial
  n'apparaît qu'une fois, dans les journaux du déploiement qui le crée.
- Pages : tableau de bord, utilisateurs, signalements, Kory, Honam, Assimé,
  Pokou certifié, modules, équipe et rôles, journal d'audit.
- La console ne montre jamais le contenu des messages ni le détail d'une
  ordonnance.

**Après toute modification de `admin/`** : `npm run publish` (construit et
copie dans `backend/app/console/`), committer le résultat, puis redéployer.
Le serveur de production n'a pas Node.

---

## 9. L'espace officine et Pokou Business

### Espace officine

Application web installable pour l'équipe d'une pharmacie, servie sous
`/officine/` (`backend/app/officine/`, HTML/JS/CSS sans framework, avec un
service worker). Connexion par numéro et code SMS. Elle utilise les routes
`/honam/pharmacy/*` : commandes reçues, devis, remise au coursier.

### Pokou Business

Portail et API pour les entreprises (`api/v1/business/`,
`services/business/`) : organisations et rôles (propriétaire, développeur,
facturation), robots, clés d'API, numéros de test, tarifs, grand livre,
factures PDF, webhooks sortants. L'API des robots est sous `/bot/v1`.
L'administration (`/admin/business`) règle la facturation et suspend. **Aucune
page de la console ne couvre encore ce domaine.**

---

## 10. Infrastructure et déploiement

Document complet : [deploiement-kubero.md](deploiement-kubero.md).

### Ce qui tourne

Un serveur (Contabo), un cluster k3s à un nœud, piloté par Kubero.

| Application Kubero | Rôle |
|---|---|
| `pokou-api` (pipeline `pokou`, phase `production`) | l'API |
| `livekit` | appels, avec le relais TURN |
| Addons | PostgreSQL 17, Redis 8, Kafka 3.4, volume médias de 10 Go |

### Comment l'API est déployée

**Kubero ne construit pas d'image.** À chaque démarrage d'un pod, il clone la
branche `main`, installe les dépendances (`kubero-build.sh`) puis lance
`kubero-run.sh` → `docker-entrypoint.sh` :

1. attendre la base ;
2. `alembic upgrade head` ;
3. `python -m scripts.seed` ;
4. démarrer uvicorn.

Conséquences à connaître :

- **Tout ce qui est sur `main` part en production au prochain redémarrage**,
  qu'il soit voulu ou non (panne, mise à jour du serveur).
- Un démarrage prend une à deux minutes.
- Le flux de construction d'image GitHub (`.github/workflows/api-image.yml`)
  existe mais est inactif : les Actions du compte sont bloquées.

### La cible Kubernetes

`deploy/k8s/` contient des manifestes complets (déploiement, autoscaling,
tâche de migration, politique réseau, Kafka Strimzi, PostgreSQL CloudNativePG).
Ils ne sont pas utilisés aujourd'hui. Guide :
[deploiement-kubernetes.md](deploiement-kubernetes.md).

---

## 11. Procédures courantes

### Déployer l'API

```bash
git push origin main
# puis redémarrer l'app pokou-api : interface Kubero → pokou-api → Restart
# ou POST /api/apps/pokou/production/pokou-api/restart (jeton Kubero)
curl -s https://apipokou.cabinet-p-et-associes.com/health        # 200
```

Vérifier dans les journaux Kubero : « Migrations applied. », la ligne du seed,
« Application startup complete. ». Pendant la bascule, une route nouvelle peut
répondre 404 une minute.

### Revenir en arrière

Remettre `main` sur le commit précédent (`git revert`), pousser, redémarrer.
Une migration déjà appliquée ne se défait pas toute seule : prévoir
`alembic downgrade` ou une migration corrective.

### Ajouter une migration

`make migration m="…"`, relire le fichier généré, nommer la révision à la suite
(`0021_…`), vérifier `alembic heads` (une seule tête), tester sur une base
vide et sur une copie.

### Modifier un réglage ou un secret de production

Interface Kubero → `pokou-api` → Edit → variables, puis redémarrer. Pour
Firebase et les clés de l'assistant : `deploy/kubero/apply_secrets.py`.

### Modifier la console

`cd admin && npm run publish`, committer `admin/` et `backend/app/console/`,
déployer l'API.

### Publier l'app

[publication-mobile.md](publication-mobile.md) : monter la version dans
`mobile/pubspec.yaml`, `./build-production.sh --apk` (Play Store),
`flutter build ipa` (App Store), notes de version dans `mobile/release-notes/`.

### Gérer l'équipe

Console → Équipe et rôles (super-administrateur). En secours, sur le serveur :
`python -m scripts.promote_admin <numéro> <RÔLE>`.

### Lire les journaux

Kubero → application → Logs. Les numéros de téléphone et jetons y sont masqués
(`core/log_redaction.py`).

### Remettre la production à zéro

**Irréversible, sans sauvegarde** : comptes, discussions, groupes, Kory,
Honam, Assimé, équipe de la console, et tous les médias (MinIO et disque).
Faite une fois, le 11 novembre 2026.

1. Dans Kubero, ajouter à `pokou-api` la variable
   `POKOU_RESET_DATABASE=EFFACER-TOUT-<AAAA-MM-JJ>`, avec la date du jour en
   UTC. Toute autre valeur est refusée.
2. Redémarrer. Au démarrage, `scripts/reset_database.py` efface tout, avant
   les migrations ; les migrations recréent le schéma, le seed recrée les
   modules et un super-administrateur avec un **nouveau** mot de passe
   (journaux).
3. **Retirer la variable** et redémarrer. Une marque sur le volume empêche
   de toute façon de rejouer la même phrase.
4. Prévenir les testeurs : effacer les données de l'app ou la réinstaller. Leur
   téléphone garde d'anciennes discussions rattachées à des identifiants de
   compte qui seront redonnés à d'autres personnes.

### Activer ou vérifier le relais d'appels

`cd deploy/kubero && python3 apply_livekit_turn.py` ; les journaux de LiveKit
doivent dire « Starting TURN server ».

---

## 12. Secrets et sécurité

### Où sont les secrets

Aucun n'est dans le dépôt. Ils existent sur le poste qui a déployé et dans
Kubero.

| Secret | Emplacement |
|---|---|
| Variables de production (base, clés, Twilio, LiveKit, accès Kubero) | `deploy/kubero/secrets.env` (ignoré par git) et la configuration de `pokou-api` dans Kubero |
| Compte de service Firebase | `deploy/kubero/firebase-service-account.json` (ignoré) |
| Configuration LiveKit générée | `deploy/kubero/livekit.json` (ignoré, contient la clé LiveKit) |
| Clé de signature Android | `mobile/android/upload-keystore.jks` et `key.properties` (ignorés) ; sauvegarde dans `~/Documents/pokou-signing/` du Mac de build |
| Fichiers Firebase de l'app | `mobile/android/app/google-services.json`, `mobile/ios/Runner/GoogleService-Info.plist` (ignorés) |
| Identifiants Semoa | table `system_settings` de la base de production |
| Mot de passe du super-administrateur | connu de son titulaire ; l'initial est passé par les journaux |

`deploy/kubero/secrets.example.env` liste les clés attendues, sans valeurs.

### À faire lors de la reprise

- **Changer tous les secrets** que l'équipe précédente a connus : accès Kubero,
  `SECRET_KEY` (déconnecte tout le monde), clés Twilio, LiveKit, IA, mot de
  passe du super-administrateur.
- **Renouveler la clé du compte de service Firebase.**
- Récupérer et mettre en lieu sûr la clé de signature Android. Sans elle, plus
  de mise à jour signée.

### Règles tenues par le code

- Le serveur ne stocke que l'empreinte des jetons de session et des tickets.
- Les mots de passe de console sont hachés (bcrypt).
- Aucune route d'administration n'accepte une session de l'app.
- Suspendre un compte révoque ses sessions tout de suite.
- Une pièce jointe n'est rendue qu'aux membres de sa discussion.
- La console et l'officine sont servies avec une politique de sécurité de
  contenu stricte.

---

## 13. Tests et qualité

| | Commande | État |
|---|---|---|
| API | `make backend-test` | 78 fichiers ; tout passe. 17 tests sont marqués « échec attendu » (§ 14) |
| App | `make mobile-test` | 684 tests, tous passent |
| Analyse de l'app | `make mobile-analyze` | aucune erreur ni avertissement ; une centaine de remarques de style |
| Style de l'API | `make backend-lint` | — |

Chaque fichier de test de l'API crée sa propre base SQLite
(`backend/test_*.db`). Une exécution interrompue peut laisser un fichier
périmé : le supprimer si un test échoue sur une colonne manquante.

Dans les tests de groupes, `tests/helpers.py::GroupCryptoClient` envoie les
messages sous forme chiffrée comme le fait l'app ; le « chiffré » y est le
texte du test.

**Plan de test manuel** : `docs/plan-de-test/Pokou-plan-de-test-1.28.1.xlsx`
(183 cas sur 17 modules, journal d'anomalies, grille d'appareils). Il se
régénère avec `docs/plan-de-test/generer_plan_de_test.py`.

Il n'y a pas d'intégration continue active. Les tests se lancent à la main
avant chaque déploiement.

---

## 14. État du produit, limites connues et dette

### Par rapport au cahier des charges

Le suivi exigence par exigence est dans
[etat-cahier-des-charges.md](etat-cahier-des-charges.md) et
[conformite-cahier-v3.4.md](conformite-cahier-v3.4.md). Ce qui reste à ouvrir
avant une publication est coché dans [mise-en-service.md](mise-en-service.md).

### Ce qui ne peut pas être fait sans action extérieure

| Sujet | Ce qui manque |
|---|---|
| Play Store | créer la fiche, déposer le bundle, puis déclarer l'empreinte de la clé de signature Google (`ANDROID_PLAY_SIGNING_SHA256`, Firebase, client OAuth) |
| App Store | compte Apple Developer dans Xcode pour signer ; l'archive actuelle est non signée |
| Notifications iPhone | clé APNs à déposer dans Firebase |
| Sauvegarde Google Drive | activer l'API Drive, écran de consentement, identifiants OAuth Android et iOS |
| Lien court | aucun domaine acheté ; les liens utilisent le domaine de l'API |
| Paiements | identifiants Semoa à renseigner et à vérifier en production |
| Pharmacies | aucune officine partenaire enregistrée |

### Fonctions fermées ou incomplètes

- **Sondages, positions et fiches de contact dans les groupes** : fermés depuis
  le chiffrement (le serveur répond 409, l'entrée est retirée du menu). À
  refaire sous forme chiffrée.
- **Anciens messages illisibles** : ils ne se réparent que si l'expéditeur
  rouvre son app.
- **Déconnexion par « un seul téléphone »** : l'ancien téléphone revient à
  l'écran de connexion sans message d'explication.
- **Pokou Business** : pas de page dans la console.
- **Mode Bouclier** : retiré de l'app ; il reste `api/v1/safety/shield.py`,
  `services/privacy/shield_service.py` et `mobile/lib/features/shield/`. À
  supprimer ou à reprendre.
- **Ancien assistant Mahizu** : l'assistant passe par `/baba` ; il reste
  `mobile/lib/core/mahizu/` et `MAHIZU_API_BASE_URL`.
- **Relais d'appels** : UDP seulement. Les réseaux qui ne laissent passer que
  le HTTPS ne sont pas servis.
- **Mise en attente d'un autre appel** : perdue avec la désactivation de
  l'intégration Android.

### Dette technique

- **17 tests de l'ancien fonctionnement en clair des groupes** (médias,
  mentions, aperçu de citation, stickers, sondages) sont marqués « échec
  attendu » avec leur raison (`tests/test_groups.py`, `tests/test_polls.py`).
  À réécrire pour le fonctionnement chiffré, ou à supprimer.
- **Hors ligne, l'app affiche 5 000 FCFA** pour le badge vendeur vérifié
  (`MarketplaceConfig.fallback`) alors que le serveur facture 3 000 ou
  30 000 FCFA.
- Les APK de test distribués avant la 1.28.0 sont signés avec une clé de
  debug : passer à la version du Play Store oblige ces testeurs à désinstaller.
- En mode debug, Flutter signale des `ListTile` posés sur un fond coloré sans
  `Material` (sans effet en production).
- La taille de texte est plafonnée à +50 % ; les très grandes tailles
  d'accessibilité ne sont pas servies.

### Risques d'exploitation

- **Un seul serveur, un seul nœud** : pas de redondance.
- **Aucune sauvegarde automatique de la base ni des médias n'est documentée.**
  À vérifier et à mettre en place en priorité.
- Le volume des médias fait 10 Go, sans stockage S3.
- `main` se déploie à chaque redémarrage (§ 10) : protéger la branche.
- Pas d'intégration continue ni d'alerte de supervision en place.
- Jamais vérifié sur le terrain : la fluidité sur un Android d'entrée de gamme,
  les lecteurs d'écran, l'arabe, les tablettes.

---

## 15. Décisions récentes à connaître

| Date | Décision | Raison |
|---|---|---|
| 7 nov. 2026 | Messages de groupe chiffrés obligatoires ; versions trop anciennes refusées (426) | elles ne savaient pas remettre leur clé à un nouvel appareil |
| 7 nov. 2026 | 25 secondes d'attente avant de raccrocher sur une coupure | un changement de réseau coupait l'appel |
| 8 nov. 2026 | Sauvegarde sur Google Drive en plus de Pokou | restaurer sur un nouveau téléphone |
| 8 nov. 2026 | Console d'administration, rôles et journal d'audit | donner à l'équipe un outil sans accès direct à la base |
| 8 nov. 2026 | Console par e-mail et mot de passe seulement ; super-administrateur créé au déploiement | l'administration ne doit pas dépendre d'un numéro de téléphone |
| 8 nov. 2026 | Intégration au système d'appels d'Android désactivée | appels muets sur Android 15 et 16 |
| 8 nov. 2026 | Clé de signature Android créée | premier bundle Play Store |
| 10 nov. 2026 | Relais TURN activé, annoncé sous l'IP | réseaux mobiles ; Cloudflare ne relaie pas l'UDP |
| 10 nov. 2026 | Texte suivi jusqu'à +50 %, écran reconstruit au changement de thème, contrastes relevés | revue de design |
| 11 nov. 2026 | Un seul téléphone par compte | deux téléphones rendaient les messages illisibles |
| 11 nov. 2026 | Le serveur accepte les libellés envoyés par les anciennes versions pour la devise et la catégorie d'une annonce | la publication Assimé échouait |
| 11 nov. 2026 | Entrée « Sondage » retirée des groupes | elle échouait toujours |

L'historique complet est dans `git log` ; les messages de commit décrivent le
pourquoi de chaque changement.

---

## 16. Glossaire

| Terme | Sens |
|---|---|
| Kory | cagnottes, cotisations et tontines |
| Honam | pharmacie et livraison ; « officine » = pharmacie partenaire |
| Assimé | marché de petites annonces |
| Baba | assistant IA de l'app |
| Pokou certifié | badge d'identité vérifiée ; « Pro » = variante pour les professionnels |
| Mode preuve | les messages supprimés restent visibles barrés, avec export PDF |
| Spark | module de rencontres, réservé aux adultes |
| Win Pokou | le mode coursier de Honam |
| Clé d'expéditeur | clé avec laquelle un membre chiffre ses messages de groupe |
| Époque (`crypto_epoch`) | numéro qui change quand la composition d'un groupe change ; les clés sont redistribuées |
| Trousseau | les clés publiques qu'un appareil publie pour qu'on puisse lui écrire |
| Outbox | table où les routes déposent leurs événements avant publication vers Kafka |
| Seed | données de départ créées au déploiement |
| Kubero | la plateforme qui héberge l'API et LiveKit |
| LiveKit | le serveur des appels audio et vidéo |
| TURN | relais qui fait passer un appel quand le réseau bloque la liaison directe |
| Semoa (CashPay) | prestataire de paiement mobile |
| Terre de Confiance | nom du système de design |

---

## 17. Première semaine de reprise

1. Obtenir les accès : dépôt GitHub, Kubero, Firebase (`pokou-3b047`), Google
   Cloud, Twilio, Cloudflare, Contabo, Semoa, comptes Play et Apple.
2. Récupérer `deploy/kubero/secrets.env`, le compte de service Firebase et la
   clé de signature Android.
3. Changer les secrets (§ 12) et le mot de passe du super-administrateur.
4. Vérifier qu'une sauvegarde de la base et des médias existe ; sinon la mettre
   en place.
5. Faire tourner l'API et l'app en local (`make backend-run`, `make mobile-run`)
   et lancer les deux suites de tests.
6. Lire, dans cet ordre : ce document, `mobile/README.md` (chiffrement),
   [e2ee-group-messages.md](e2ee-group-messages.md),
   [deploiement-kubero.md](deploiement-kubero.md),
   [administration.md](administration.md).
7. Dérouler les cas prioritaires du plan de test sur deux téléphones réels.
8. Protéger la branche `main` et décider d'une intégration continue.
9. Traiter d'abord : sauvegardes, publication sur les stores, notifications
   iPhone, sondages de groupe chiffrés, réécriture des 17 tests.

---

## 18. Carte des autres documents

| Document | Sujet |
|---|---|
| `README.md` | démarrage rapide |
| `backend/README.md` | développement de l'API, où ranger quoi, services externes |
| `mobile/README.md` | app : lancement, builds, architecture, chiffrement et ses limites |
| [administration.md](administration.md) | console : connexion, rôles, pages, modification |
| [publication-mobile.md](publication-mobile.md) | clé de signature, builds, Play Store, App Store |
| [deploiement-kubero.md](deploiement-kubero.md) | l'hébergement en service, LiveKit, relais, redéploiement |
| [deploiement-kubernetes.md](deploiement-kubernetes.md) | cible Kubernetes et Kafka |
| [mise-en-service.md](mise-en-service.md) | liste de ce qui reste à ouvrir avant publication |
| [e2ee-group-messages.md](e2ee-group-messages.md) | chiffrement des groupes |
| [e2ee-statuses.md](e2ee-statuses.md) | chiffrement des statuts |
| [chiffrement-appels-groupe.md](chiffrement-appels-groupe.md) | chiffrement des appels de groupe |
| [design-ui-ux.md](design-ui-ux.md) | description de l'interface |
| [etat-cahier-des-charges.md](etat-cahier-des-charges.md) | exigences : fait, pas fait |
| [conformite-cahier-v3.4.md](conformite-cahier-v3.4.md), [conformite-cahier-v3.2.md](conformite-cahier-v3.2.md) | vérification face au cahier des charges |
| `docs/plan-de-test/` | plan de test manuel (Excel) et son générateur |
| `docs/vault-historique/` | documents d'un projet antérieur, gardés pour mémoire |
| `mobile/release-notes/` | notes de version |
