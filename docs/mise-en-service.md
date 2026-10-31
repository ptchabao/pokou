# Mise en service de Pokou

Ce que le code ne peut pas faire seul. À cocher avant la première publication.

## Domaines

- [ ] `api.pok.app` → l'API (`PUBLIC_API_URL=https://api.pok.app`).
- [ ] `pok.app` → un reverse-proxy qui sert, **sans authentification ni
      préfixe `/api/v1`**, les chemins `/.well-known/*`, `/invite/*`, `/c/*`,
      `/channel/*` et `/bot/*` de l'API.
- [ ] Image de partage `https://pok.app/static/pokou-banner.png` (aperçu des
      liens d'invitation, voir `backend/app/api/public/deeplinks.py`).

## Android (`com.pokou.pokou`)

- [ ] Créer l'application dans Firebase et remplacer
      `mobile/android/app/google-services.json` : le fichier actuel est celui
      de Vault (`com.mahizu.vault`), et le plugin Google Services refusera de
      construire tant qu'il ne déclare pas `com.pokou.pokou`.
- [ ] Keystore de release dans `mobile/android/key.properties` (hors dépôt).
- [ ] Créer la fiche Play, puis publier l'empreinte SHA-256 de la clé de
      signature Google : `ANDROID_PLAY_SIGNING_SHA256` côté API. Sans elle,
      les liens s'ouvrent dans le navigateur.

## iOS

- [ ] Bundle `com.pokou.pokou` dans le compte développeur, capacité
      *Associated Domains* (`applinks:pok.app`).
- [ ] Ajouter `GoogleService-Info.plist` de l'app iOS Firebase.
- [ ] `APPLE_TEAM_ID` côté API (fichier `apple-app-site-association`).

## API

- [ ] `SECRET_KEY`, `WEBHOOK_HMAC_SECRET` (l'API refuse de démarrer sans).
- [ ] PostgreSQL (`DATABASE_URL`), Redis (`REDIS_URL`), bucket S3 (`S3_*`).
- [ ] SMS : identifiants NGH et identifiant d'expéditeur **POKOU déclaré chez
      l'opérateur** (`SMS_SENDER_ID`) — un expéditeur non déclaré fait
      refuser tous les codes de connexion.
- [ ] WhatsApp : passerelle ou Twilio.
- [ ] Firebase : compte de service (`FIREBASE_CREDENTIALS_JSON`), `FCM_ENABLED=true`.
- [ ] LiveKit Cloud (`LIVEKIT_*`).
- [ ] Semoa : réglages système `semoa_login`, `semoa_api_key`,
      `semoa_webhook_secret`… ; les rappels arrivent sur
      `/api/v1/webhooks/marketplace-payment/semoa`.
- [ ] Un premier administrateur : `python -m scripts.promote_admin +228…`.

## Assistant Mahizu

Les écrans de l'assistant appellent `https://api.mahizu.com/api/v1`
(`MAHIZU_API_BASE_URL`). L'API Mahizu doit accepter ces appels depuis l'app :
rien à configurer côté Pokou.

## Kubernetes et Kafka

- [ ] Suivre [deploiement-kubernetes.md](deploiement-kubernetes.md), et
      cocher sa section « Points ouverts avant la production ».
