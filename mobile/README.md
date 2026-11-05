# Pokou

Application mobile Flutter de Pokou (`com.pokou.pokou`), adossée à l'API
Pokou (`../backend`). Inscription/connexion par numéro de téléphone façon
WhatsApp (OTP SMS, sans mot de passe) ; messagerie chiffrée, groupes,
communautés, chaînes, statuts, appels, marché et modules.

L'assistant (chat, Baba/Minou, contacts intelligents, bilan du soir) est un
service **Mahizu**, tiers : l'app l'appelle sur l'API Mahizu avec un compte
Mahizu rattaché séparément (voir `lib/core/mahizu/`). Le backend Pokou n'en
contient rien.

## Lancer en local

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1  # émulateur Android
```

| `--dart-define` | Défaut |
|---|---|
| `API_BASE_URL` | `https://apipokou.cabinet-p-et-associes.com/api/v1` |
| `MAHIZU_API_BASE_URL` | `https://api.mahizu.com/api/v1` |

`10.0.2.2` est l'alias de l'émulateur Android vers `localhost` de la machine
hôte. Sur un appareil physique ou iOS, pointez `API_BASE_URL` vers une
adresse joignable depuis le téléphone (IP locale, tunnel, ou déploiement).

## Builds de production

| Plateforme | Commande | Prérequis |
|---|---|---|
| Android | `./build-production.sh --apk` | `android/key.properties` + keystore ; `google-services.json` de l'app Firebase **`com.pokou.pokou`** ; JDK 17 ou 21 (`flutter config --jdk-dir …`), Gradle 8.14 ne prend pas Java 25 |
| iOS | `./build-ios.sh` | Xcode, CocoaPods sur le `PATH`, `ios/Runner/GoogleService-Info.plist`, équipe de signature dans Xcode |
| Web | `flutter build web --release` | Application Web Firebase configurée dans `lib/firebase_options.dart` ; notifications servies en HTTPS |

### Notifications Web

L'application Web utilise l'application Firebase `pokou-3b047` et son
service worker `web/firebase-messaging-sw.js`. Le worker doit rester accessible
à la racine du site, sur une origine HTTPS (ou `localhost` en développement).
La clé VAPID publique est configurée dans `lib/core/push/push_service.dart`;
l'autorisation se demande depuis Profil > Notifications > Activer les
notifications Web, car les navigateurs peuvent bloquer une demande au démarrage.

Le Ruby 2.6 de macOS ne compile plus les extensions natives de CocoaPods
avec le SDK de Xcode 26. Sur la machine de build, CocoaPods tourne sur un
Ruby portable (`~/development/bin/pod`) : ajouter `~/development/bin` au
`PATH`.

## Architecture

```
lib/
  core/           # api client, thème, routage, stockage sécurisé, crypto (X3DH),
                  # synchro hors ligne, WebSocket, push, appels, médias
  features/
    auth/ inbox/ chat/ messaging/ contacts/ presence/ status/ stickers/
    groups/ communities/ channels/ broadcasts/ calls/
    marketplace/ modules/ (spark, heart_league, vip_room, verses…)
    shield/ settings/ profile/
```

État : Riverpod. Routing : go_router. HTTP : `package:http`. Base locale :
SQLCipher (`sqflite_sqlcipher`), clé tirée au hasard et gardée dans le
Keystore/Keychain. Temps réel : WebSocket à ticket. Appels : LiveKit. Push :
Firebase Cloud Messaging. Modèles JSON : `fromJson`/`toJson` manuels.

La fiche technique complète (fonctionnalités, ce que Pokou fait et ne fait
pas, services à provisionner, points d'attention) est dans le document
« Pokou — fiche technique et fonctionnalités ».

## Ce qui n'est PAS fait

Ne pas le présenter comme acquis :

- Chiffrement de bout en bout des groupes, chaînes, statuts, listes de
  diffusion, appels de groupe et de l'assistant Baba
- Plusieurs appareils par compte, sauvegarde chiffrée, transfert d'historique
- Sécurité post-compromission (pas de cliquet Diffie-Hellman) et audit externe
- Vérification de clé par numéro de sécurité, QR code ou emoji
- Biométrie ; masquage des captures d'écran
- Virements sortants et remboursements automatiques pour les modules payants
  (ils calculent et inscrivent les montants, rien n'est versé)
- CallKit / PushKit sur iOS

## Chiffrement de bout en bout

⚠️ **À lire avant d'écrire « chiffré de bout en bout » sur une page produit,
dans une fiche de store, ou de le dire à un utilisateur.**

### Ce qui est chiffré

Les **messages privés 1:1** : texte, **pièces jointes** (image, vidéo, audio,
document — clé AES-256-GCM par fichier, scellée dans le message chiffré) et
**appels 1:1** (clé scellée, média chiffré par LiveKit). Un appel 1:1 n'est
chiffré que si une session existe déjà et que les deux côtés annoncent la
capacité `call-v1` ; sinon il est en clair et l'écran l'indique.

Ne le sont **pas** : les groupes, les chaînes, les statuts, les listes de
diffusion, les appels de groupe, et les conversations avec l'assistant Baba
— qui ne pourra jamais l'être, puisqu'il doit lire pour répondre.

Une conversation dont un seul côté a une version qui chiffre reste **en clair**
(le serveur répond 404 : pas de trousseau), délibérément : refuser d'écrire à
quelqu'un qui n'a pas mis à jour serait une bien pire régression. Toute autre
erreur, ou un changement de clé d'identité, **bloque** l'envoi.

### Ce que ça garantit

- Le serveur **ne peut pas** lire les messages privés en texte. La colonne
  `content` est NULL et le serveur n'a aucune clé privée.
- **Confidentialité persistante** : une clé de message est détruite après
  usage et la chaîne n'est pas réversible. Un téléphone volé aujourd'hui ne
  livre pas les messages d'hier.
- Un message **modifié ou rejoué** en route est rejeté, pas affiché.
- Un changement de clé d'identité (réinstallation, ou quelqu'un au milieu)
  est **détectable**.

### Ce que ça ne garantit pas

- **Pas de sécurité post-compromission.** Le vrai protocole Signal ajoute un
  second cliquet, à échange Diffie-Hellman, qui permet à une conversation de
  se « soigner » après un vol de clé. Ici, qui vole l'état d'une session lit
  tout ce qui suit jusqu'à la prochaine.
- **Pas de multi-appareil.** Un seul trousseau par compte ; une
  réinstallation rend l'historique chiffré précédent illisible.
- **Pas de déniabilité.**
- **La recherche serveur ne voit pas les messages chiffrés** et ne marche pas
  hors ligne : la recherche dans le contenu chiffré devrait se faire sur le
  cache local, ce qui n'est pas fait.
- **Notifications push** : le serveur ne peut pas lire un message chiffré. Un
  appareil standard reçoit « Nouveau message » ; un appareil équipé reçoit le
  chiffré (3 000 caractères au plus) et le déchiffre sur le téléphone.
- **Aperçu de lien** : l'adresse extraite du texte déchiffré est envoyée au
  serveur (`/link-preview`), sans option pour l'éviter.
- **`android:allowBackup="false"`** est une conséquence directe : le cache
  local contient les messages déchiffrés, et Android les sauvegarderait vers
  Google Drive. Prix à payer : l'historique ne suit pas un changement de
  téléphone. Même compromis que Signal ; une sauvegarde chiffrée séparée
  reste à faire.

### La limite la plus importante

**Les protocoles et leur intégration n'ont fait l'objet d'aucun audit externe.**

Le chiffrement individuel est assemblé à la main (`lib/core/crypto/`) sur des primitives éprouvées
— `package:cryptography`, Apache-2.0, X25519 / Ed25519 / AES-256-GCM /
HKDF / HMAC-SHA256. Aucune primitive n'est réimplémentée : ce qui est écrit
ici, c'est leur ASSEMBLAGE, et c'est déjà bien assez pour se tromper.

Les groupes utilisent Signal Sender Keys via `libsignal_protocol_dart`
(GPL-3.0). Le dépôt est placé sous GNU AGPL-3.0 ; voir le fichier `LICENSE`
à la racine. Toute distribution de l'application ou mise à disposition de
versions modifiées doit respecter les obligations de cette licence, notamment
la disponibilité du code source correspondant. Cette décision n'est pas un
avis juridique.

Conséquence pratique : présenter cette fonctionnalité aux utilisateurs comme
une garantie de sécurité demande d'abord un audit par un tiers compétent.
Tant qu'il n'a pas eu lieu, la formulation honnête est que les messages sont
chiffrés et que le serveur ne peut pas les lire — pas que la sécurité est
garantie.

### Architecture

| Fichier | Rôle |
|---|---|
| `lib/core/crypto/e2ee_primitives.dart` | Les briques, et rien d'autre |
| `lib/core/crypto/e2ee_session.dart` | Poignée de main X3DH, dérivation des chaînes |
| `lib/core/crypto/e2ee_envelope.dart` | Chiffrement d'un message, cliquet, désordre |
| `lib/core/crypto/e2ee_store.dart` | Clés privées — Keychain / Keystore matériel |
| `lib/core/crypto/e2ee_service.dart` | Façade ; le reste de l'app ne voit que ça |
| `lib/core/crypto/media_cipher.dart` | Chiffrement des pièces jointes |
| `lib/core/crypto/group_sender_keys.dart` | Signal Sender Keys et stockage sécurisé des états de groupe |
| `lib/core/crypto/call_keys.dart` | Clé d'appel 1:1 scellée |
| `backend/app/api/v1/auth/e2ee.py` | Annuaire de clés PUBLIQUES, côté serveur |

Le dépôt `messaging_repository.dart` est la **frontière** : en dessous c'est
chiffré, au-dessus c'est en clair. Aucun écran ne sait qu'un chiffrement
existe — c'est ce qui évite d'oublier de déchiffrer quelque part.

## Tests

```bash
flutter analyze
flutter test
```
