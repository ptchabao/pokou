# Pokou

Messagerie, communautés, appels et marché — application mobile
`com.pokou.pokou` et son API.

```
pokou/
├── backend/            API FastAPI (Python 3.12)
├── mobile/             Application Flutter (Android / iOS)
├── deploy/k8s/         Manifestes Kubernetes (Kustomize) et Kafka (Strimzi)
├── docs/               Documentation transverse
├── docker-compose.yml  PostgreSQL + Redis + MinIO + API, pour le développement
└── Makefile            Raccourcis (`make help`)
```

## Démarrage rapide

```bash
make backend-setup      # virtualenv + dépendances
make backend-run        # http://localhost:8000/docs (SQLite par défaut)
make backend-test

make mobile-setup
make mobile-run         # émulateur Android → API locale
```

Ou tout l'environnement sous Docker : `make up`.

## Backend

```
backend/
├── app/
│   ├── main.py             Application FastAPI, middlewares, cycle de vie
│   ├── api/
│   │   ├── router.py       Assemblage des routes
│   │   ├── public/         Sans préfixe : /.well-known/*, pages d'invitation
│   │   └── v1/             Sous /api/v1, une famille par dossier :
│   │       ├── auth/           connexion par téléphone, appareils, clés E2EE
│   │       ├── account/        profil, contacts, confidentialité
│   │       ├── messaging/      messages, conversations, groupes, sondages,
│   │       │                   diffusions, présence, synchro, WebSocket
│   │       ├── media/          pièces jointes, stickers, statuts
│   │       ├── communities/    communautés, chaînes
│   │       ├── calls/          appels LiveKit
│   │       ├── safety/         Mode Bouclier
│   │       ├── marketplace/    marché (+ administration)
│   │       ├── kory/           Kory : cagnottes et cotisations, en journal
│       ├── config/         configuration par pays (modules ouverts, TVA)
│       ├── certified/      Pokou certifié (badge, essai, mode preuve)
│       ├── honam/          HONAM : annuaire, commandes, officine, coursiers
│       ├── modules/        Heart League, séries, Truth, cérémonies, VIP, Hype
│   │       ├── spark/          rencontres
│   │       ├── business/       Pokou Business : portail et API des bots
│   │       └── payments/       rappels Mobile Money (Semoa)
│   ├── core/               config, base, sécurité, RBAC, audit, scheduler,
│   │                       verrou distribué, métriques, garde-fous de démarrage
│   ├── middleware/         limitation de débit
│   ├── models/             modèles SQLAlchemy, un fichier par domaine
│   ├── schemas/            schémas Pydantic partagés
│   ├── services/           logique métier, par domaine (auth, messaging,
│   │                       calls, media, privacy, marketplace, payments,
│   │                       notifications, modules, business, ai)
│   └── utils/              utilitaires sans état
├── alembic/                migrations
├── scripts/                outils d'exploitation (promote_admin)
└── tests/
```

Configuration : `backend/.env.example`. En production, l'API refuse de
démarrer avec un `SECRET_KEY` ou un `WEBHOOK_HMAC_SECRET` par défaut, ou avec
le compte de démonstration des stores encore ouvert.

Donner un rôle d'administration : la personne se connecte une fois à l'app,
puis `python -m scripts.promote_admin +228XXXXXXXX [ADMIN|SUPER_ADMIN]`.

## Cahier des charges

Ce qui est fait, ce qui ne l'est pas, et chaque hypothèse :
[docs/etat-cahier-des-charges.md](docs/etat-cahier-des-charges.md).
Espace officine HONAM : `https://api.pok.app/officine/`.

## Production

Kubernetes et Kafka : [docs/deploiement-kubernetes.md](docs/deploiement-kubernetes.md).
Instance en service (Kubero, LiveKit, relais TURN, redéployer) :
[docs/deploiement-kubero.md](docs/deploiement-kubero.md).
Comptes et services à ouvrir avant : [docs/mise-en-service.md](docs/mise-en-service.md).

## Administration

Console de l'équipe : `https://apipokou.cabinet-p-et-associes.com/console/`
(code dans `admin/`). Connexion par e-mail et mot de passe, rôles,
super-administrateur créé au déploiement :
[docs/administration.md](docs/administration.md).

## Mobile

Voir `mobile/README.md`. Clé de signature, builds Play Store, App Store et
APK : [docs/publication-mobile.md](docs/publication-mobile.md). L'API visée se règle au build :
`--dart-define=API_BASE_URL=…` (défaut
`https://apipokou.cabinet-p-et-associes.com/api/v1`).

## Pokou et Mahizu

Pokou est **indépendant** de Mahizu : base de données, comptes, backend et
déploiement séparés. Seuls les écrans de l'assistant (chat, Baba/Minou,
contacts intelligents, bilan du soir) parlent à l'API Mahizu, depuis
l'application, avec un compte Mahizu que l'utilisateur rattache lui-même
(`mobile/lib/core/mahizu/`). Le backend Pokou n'en contient rien.
