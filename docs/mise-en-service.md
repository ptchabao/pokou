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

- [x] Application Firebase `com.pokou.pokou` et `google-services.json`.
- [x] Clé de téléversement Play : `mobile/android/upload-keystore.jks` et
      `key.properties`, hors dépôt (voir [publication-mobile.md](publication-mobile.md)).
- [ ] Créer la fiche Play, puis publier l'empreinte SHA-256 de la clé de
      signature Google : `ANDROID_PLAY_SIGNING_SHA256` côté API. Sans elle,
      les liens s'ouvrent dans le navigateur.

## iOS

- [ ] Bundle `com.pokou.pokou` dans le compte développeur, capacité
      *Associated Domains* (`applinks:pok.app`).
- [x] Ajouter `GoogleService-Info.plist` de l'app iOS Firebase.
- [ ] Compte Apple Developer dans Xcode pour signer l'archive, clé APNs
      dans Firebase (notifications iPhone).
- [ ] `APPLE_TEAM_ID` côté API (fichier `apple-app-site-association`).

## API

- [ ] `SECRET_KEY`, `WEBHOOK_HMAC_SECRET` (l'API refuse de démarrer sans).
- [ ] PostgreSQL (`DATABASE_URL`), Redis (`REDIS_URL`), bucket S3 (`S3_*`).
- [ ] SMS par Twilio : `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, et
      `TWILIO_SMS_FROM` (numéro Twilio ou identifiant alphanumérique POKOU,
      à faire enregistrer chez Twilio pour le Togo et la Côte d'Ivoire) ou
      `TWILIO_MESSAGING_SERVICE_SID`. En local dans `backend/.env`, en
      production dans le Secret. Le code est valable 50 secondes.
- [ ] Secours facultatif : identifiants NGH et `SMS_SENDER_ID` déclaré chez
      l'opérateur.
- [ ] WhatsApp : passerelle ou Twilio.
- [ ] Firebase : compte de service (`FIREBASE_CREDENTIALS_JSON`), `FCM_ENABLED=true`.
- [x] LiveKit auto-hébergé sur Kubero, avec relais TURN (voir
      [deploiement-kubero.md](deploiement-kubero.md) § 9).
- [ ] Semoa : réglages système `semoa_login`, `semoa_api_key`,
      `semoa_webhook_secret`… ; les rappels arrivent sur
      `/api/v1/webhooks/marketplace-payment/semoa`.
- [x] Premier administrateur : créé au déploiement par le seed
      (`admin@pokou.app`, mot de passe dans les journaux du premier
      déploiement, à changer). Voir [administration.md](administration.md).

## Assistant Mahizu

Les écrans de l'assistant appellent `https://api.mahizu.com/api/v1`
(`MAHIZU_API_BASE_URL`). L'API Mahizu doit accepter ces appels depuis l'app :
rien à configurer côté Pokou.

## Kubernetes et Kafka

- [ ] Suivre [deploiement-kubernetes.md](deploiement-kubernetes.md), et
      cocher sa section « Points ouverts avant la production ».
