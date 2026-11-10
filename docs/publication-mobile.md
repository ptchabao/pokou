# Publier l'app mobile (Play Store, App Store, APK)

## 1. La clé de signature Android

Créée le 8 novembre 2026 pour le premier bundle Play Store.

| | |
|---|---|
| Keystore | `mobile/android/upload-keystore.jks` (alias `upload`, RSA 4096, valable jusqu'en 2056) |
| Mots de passe | `mobile/android/key.properties` (`storeFile` en chemin **absolu**) |
| Sauvegarde | `~/Documents/pokou-signing/` sur le Mac de build |
| SHA-1 | `FF:D8:31:C3:B1:05:2A:28:1A:F4:E1:DB:1D:B8:C0:D9:2F:2D:77:1D` |
| SHA-256 | `65:9E:06:2A:85:96:D8:8D:84:5B:7D:7D:0E:41:2F:B1:1E:51:5B:31:2E:E8:72:47:94:BA:1C:E3:17:D9:63:40` |

Les deux fichiers sont ignorés par git (`.gitignore` racine et
`mobile/android/.gitignore`). **Ils ne doivent exister nulle part ailleurs
qu'en lieu sûr** : copier `~/Documents/pokou-signing/` dans un gestionnaire
de mots de passe ou un coffre. Avec Play App Signing, une clé de
téléversement perdue se remplace auprès de Google, mais c'est long.

Sans `key.properties`, Gradle retombe sur la clé de debug de la machine, et
`build-production.sh` refuse alors de construire.

Les empreintes de cette clé sont déclarées :

- dans Firebase (app Android `com.pokou.pokou`) : SHA-1 et SHA-256 ;
- dans `backend/app/api/public/wellknown.py` : SHA-256, pour que les liens
  Pokou ouvrent l'app (`/.well-known/assetlinks.json`).

**Après la création de la fiche Play** : Google signe les installations
avec sa propre clé (Play App Signing). Son SHA-256 (Play Console → Intégrité
de l'application) doit être ajouté :

- à l'API : variable `ANDROID_PLAY_SIGNING_SHA256` de `pokou-api` ;
- à Firebase : empreinte de l'app Android ;
- au client OAuth Android de Google Cloud (sauvegarde Google Drive).

### Les APK déjà distribués

Jusqu'à la 1.28.0, les APK de test étaient signés avec la clé de debug du
Mac de build (SHA-1 `ad41268b…3f75`). Android refuse de remplacer une app
par une autre signée différemment : passer d'un de ces APK à la version
Play Store, ou à l'APK signé avec la clé de release, **oblige à
désinstaller**, donc à perdre les messages locaux sans sauvegarde.

Pour que les testeurs actuels se mettent à jour sans désinstaller, on
construit aussi un APK signé comme avant (`…-testeurs-mise-a-jour.apk`,
voir § 2).

## 2. Construire

Prérequis sur le Mac de build : voir `mobile/README.md` (JDK 17, Flutter,
CocoaPods), et **Android `cmdline-tools`**
(`~/Library/Android/sdk/cmdline-tools/latest`). Flutter vérifie avec
`apkanalyzer` que le bundle ne contient pas les symboles de débogage ;
sans cet outil, la vérification échoue toujours (« Release app bundle failed
to strip debug symbols »), même quand le bundle est correct.

La version vient de `mobile/pubspec.yaml` (`version: 1.28.0+49` : nom +
code). La monter avant chaque publication : le Play Store refuse un code
déjà envoyé.

```bash
cd mobile
export PATH="$HOME/development/bin:$PATH"

# Play Store : bundle + APK par architecture, obfusqués, + symboles
./build-production.sh --apk            # --skip-checks pour sauter analyse et tests

# APK universel, clé de release (nouvelles installations)
flutter build apk --release --dart-define=POKOU_VERSION=1.28.0 \
  --obfuscate --split-debug-info=build-production/symbols-v1.28.0

# APK testeurs (clé de debug, comme les APK déjà distribués)
mv android/key.properties android/key.properties.off
flutter build apk --release --dart-define=POKOU_VERSION=1.28.0
mv android/key.properties.off android/key.properties

# iOS : archive non signée
flutter build ipa --release --no-codesign --dart-define=POKOU_VERSION=1.28.0 \
  --obfuscate --split-debug-info=build-production/symbols-ios-v1.28.0
```

`POKOU_VERSION` est la version affichée dans « À propos »
(`build-production.sh` la passe tout seul).

Résultats dans `mobile/build-production/` :

| Fichier | Pour |
|---|---|
| `pokou-v<version>-release.aab` | Play Store |
| `pokou-v<version>-<abi>-release.apk` | distribution directe, par architecture |
| `symbols-v<version>/` | Play Console → plantages (désobfuscation) |
| `build/ios/archive/Runner.xcarchive` | App Store |

## 3. Play Store

1. Play Console → créer l'app `com.pokou.pokou`.
2. Accepter **Play App Signing** (Google garde la clé de signature, la
   nôtre ne sert qu'au téléversement).
3. Test interne → nouvelle version → déposer le `.aab`, puis les symboles
   (`symbols-v<version>/`).
4. Notes de version : `mobile/release-notes/<version>.txt` (fr, en, es, it, ru).
5. Reporter le SHA-256 de la clé de signature Google (§ 1).

## 4. App Store

Le Mac de build n'a ni certificat Apple ni équipe configurée : l'archive est
construite **sans signature**.

1. Xcode → Réglages → Comptes : ajouter le compte Apple Developer.
2. Ouvrir l'archive (`Runner.xcarchive`, double-clic) → Organizer.
3. **Distribute App** → App Store Connect → Upload : Xcode signe avec
   l'équipe choisie et envoie.
4. Dans App Store Connect : fiche, captures, puis TestFlight.

À régler une fois :

- l'app `com.pokou.pokou` dans le compte développeur, capacité *Associated
  Domains* ;
- `APPLE_TEAM_ID` côté API (`apple-app-site-association`) ;
- la **clé APNs** dans Firebase (Paramètres du projet → Cloud Messaging) :
  sans elle, aucune notification sur iPhone ;
- `ios/Runner/GoogleService-Info.plist` (présent sur le Mac de build,
  ignoré par git).

## 5. Appels : ce qu'il faut savoir avant de publier

- **Intégration Telecom d'Android coupée** (`PokouTelecom.ENABLED = false`,
  `android/.../call/PokouTelecom.kt`). Sur Android 15/16, déclarer l'appel
  à Android prenait le focus audio et le mode d'appel au moment où WebRTC
  configurait les siens : l'appel se connectait, mais personne n'entendait
  personne. Conséquence : un appel téléphonique ou WhatsApp en cours n'est
  plus mis en attente automatiquement quand un appel Pokou démarre.
- **Relais TURN** du serveur d'appels : voir
  [deploiement-kubero.md](deploiement-kubero.md) § 9. Il rattrape les
  réseaux mobiles qui bloquent le média direct.

Avant chaque publication, tester un appel 1-1 entre deux Android réels, dont
un en 4G.
