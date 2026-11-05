# Vault — préparation de la version iOS

**Pour** : le fondateur, et qui fera la première compilation sur Mac.
**Date** : 24/09/2026.

---

## 0. Ce qu'il faut savoir d'abord

**Le projet iOS n'avait jamais été construit.** Ce n'est pas une opinion :
il n'y avait ni `Podfile`, ni `GoogleService-Info.plist`, ni fichier
d'entitlements. `pod install` n'a donc jamais tourné, et aucune bibliothèque
native — Firebase, LiveKit, SQLCipher, le trousseau — n'était liée au
projet.

**Et une compilation iOS ne peut pas se faire depuis cette machine.** Xcode
n'existe que sur macOS ; il n'y a aucun contournement, ni conteneur, ni
service tiers qui change cela. Ce document sépare donc franchement ce qui a
été fait ici de ce qui vous attend sur un Mac.

---

## 1. Ce qui a été fait, et qui est dans le dépôt

### `ios/Podfile` — créé

Il manquait entièrement. Deux choses y méritent attention :

**La cible est 13.0**, alignée sur celle du projet Xcode et sur le plancher
de `firebase_messaging` 15.x. Le `post_install` la réimpose à tous les pods,
parce que certains — ceux tirés par `permission_handler` — en déclarent une
plus basse, ce qui produit des centaines d'avertissements et, sur les Xcode
récents, des erreurs de liaison.

**Les permissions sont restreintes au strict nécessaire.**
`permission_handler` compile par défaut le code de TOUTES les permissions
iOS : santé, calendrier, rappels, suivi publicitaire. Apple rejette une
application dont le binaire interroge des permissions qu'aucune chaîne de
l'`Info.plist` ne justifie, et c'est un motif de refus fréquent. Seules
caméra, micro, photos, position, contacts et notifications sont activées ;
les autres sont explicitement mises à `0`.

### `ios/Runner/Info.plist` — quatre clés ajoutées

| Clé | Pourquoi, et ce qui se passait sans |
|---|---|
| `UIBackgroundModes` = `remote-notification`, `audio` | **Le plus grave.** APNs ne remet pas un message *data-only* à une application en arrière-plan ou fermée sans ce mode. Or les appels partent justement en data-only. **Aucun appel entrant ne serait jamais arrivé sur iPhone**, sans la moindre erreur nulle part. `audio` permet à un appel LiveKit de continuer quand l'écran s'éteint. |
| `NSPhotoLibraryAddUsageDescription` | « Enregistrer sur le téléphone » écrit dans la photothèque via `gal`. Sans cette chaîne, iOS ne refuse pas : il **termine le processus**. |
| `ITSAppUsesNonExemptEncryption` = `true` | Sans elle, chaque envoi à App Store Connect repose la question de conformité à l'exportation et bloque la distribution. **À confirmer — voir §3.** |
| `LSApplicationQueriesSchemes` | Un numéro touché dans une carte de visite ouvre le téléphone, un partage ouvre les applications installées. iOS exige que les schémas interrogés soient déclarés. |

Les cinq chaînes de permission déjà présentes (caméra, micro, photos,
contacts, position *when-in-use*) sont correctes et suffisent :
`Geolocator.requestPermission()` ne demande jamais l'autorisation *always*,
elle se contente de la comparer — donc pas besoin de
`NSLocationAlwaysAndWhenInUseUsageDescription`.

### `ios/Runner/Runner.entitlements` — créé et déclaré

`aps-environment` (notifications push) et `com.apple.developer.associated-domains`
pour `vault.mahizu.com`, l'équivalent iOS des App Links Android déjà en
place. `CODE_SIGN_ENTITLEMENTS` est posé dans **les trois** configurations
du projet — Debug, Release, Profile : en oublier une la ferait construire
sans droit d'accès aux notifications, ce qui ne se voit qu'à l'exécution.

### Le serveur — un défaut corrigé

`send_push` n'envoyait **aucune configuration APNs**. Android livre un
message data-only du moment que la priorité est haute ; APNs, non. Sans
`content-available`, un message sans bloc `notification` n'est pas remis.
Ajouté, avec `apns-priority: 10` — un message silencieux part sinon en
priorité 5, c'est-à-dire « quand ça arrange le système », ce qui ne convient
pas à une sonnerie.

### L'application — un défaut corrigé

`flutter_local_notifications` était initialisé **sans aucun volet iOS**.
Conséquence silencieuse : sur iPhone, le greffon n'était jamais configuré
pour Darwin, donc **aucune notification locale ne s'affichait** — ni l'appel
entrant, ni le repli hors ligne. Rien dans les journaux ne le disait.

Les trois demandes d'autorisation y sont volontairement à `false` :
`firebase_messaging` les demande déjà, et les laisser à `true` ferait
apparaître deux fenêtres système à la première ouverture.

---

## 2. Ce qui vous attend sur un Mac — dans l'ordre

1. **Créer l'application dans le portail Apple Developer**, identifiant
   `com.mahizu.vault` (le même qu'Android), et y activer **Push
   Notifications** et **Associated Domains**. Sans ces deux capacités dans
   le profil de provisionnement, la compilation échoue sur les entitlements.
2. **Générer une clé APNs** (.p8) et la **déposer dans la console Firebase**,
   projet Vault, onglet Cloud Messaging. Sans elle, FCM ne peut rien
   remettre à un iPhone, même parfaitement configuré côté application.
3. **Télécharger `GoogleService-Info.plist`** depuis Firebase et le placer
   dans `ios/Runner/`, **puis l'ajouter à la cible Runner dans Xcode** — le
   déposer dans le dossier ne suffit pas, il doit être dans « Copy Bundle
   Resources ».
4. `flutter pub get` puis `cd ios && pod install`.
5. Ouvrir **`Runner.xcworkspace`** — jamais `Runner.xcodeproj` — régler
   l'équipe de signature, et vérifier que les deux capacités apparaissent.
6. **Servir `apple-app-site-association`** sur
   `https://vault.mahizu.com/.well-known/`, avec `TEAMID.com.mahizu.vault`.
   `api/app/routes/wellknown.py` sert déjà l'équivalent Android
   (`assetlinks.json`) : c'est le même endroit.
7. `flutter build ipa --release`.

---

## 3. Deux points qui demandent votre décision

**`ITSAppUsesNonExemptEncryption` — POINT OUVERT, à valider avant
soumission.** Posée à `true`, qui est la lecture honnête pour une messagerie
chiffrée de bout en bout. Mais ce n'est pas un réglage technique, c'est une
**déclaration légale** : elle engage à fournir une documentation de
conformité à l'exportation, et la déclaration annuelle auprès du BIS.
Beaucoup d'applications grand public relèvent d'une exemption qui
permettrait `false`.

**Cette valeur ne doit pas être changée sur la base d'une hypothèse** —
dans un sens elle bloque la distribution, dans l'autre c'est une fausse
déclaration. Elle se tranche avec un conseil, avant le premier envoi, et
pas autrement.

**`aps-environment` est à `development`.** Xcode le bascule en `production`
à l'archivage pour une distribution App Store. Si vous distribuez autrement
— TestFlight passe bien, une distribution ad hoc non —, il faudra le
vérifier.

---

## 4. Ce qui ne marchera PAS sur iOS, et qu'il faut savoir avant de publier

Ce ne sont pas des oublis de préparation, ce sont des fonctionnalités qui
n'existent pas côté iOS.

**Les appels entrants n'ont pas d'interface native.** Toute la couche
d'appel — `CallManager`, `RingtoneService`, la notification `CallStyle` avec
Répondre et Refuser, l'écran plein écran sur téléphone verrouillé — est
écrite en Kotlin et n'a **aucun équivalent iOS**. Sur iPhone, un appel
entrant arrivera comme une bannière ordinaire : pas de sonnerie, pas de
boutons, pas d'écran d'appel sur verrouillage.

Le faire correctement demande **PushKit + CallKit**, qui est un chantier à
part entière — et Apple l'impose : une application qui déclare le mode
`voip` sans utiliser PushKit est rejetée. C'est pourquoi `voip` n'est
**pas** dans les `UIBackgroundModes` ajoutés.

**Les notifications n'ont pas d'actions.** Le code ne construit que des
`AndroidNotificationDetails` ; iOS exige des `DarwinNotificationDetails` et
des catégories déclarées pour afficher des boutons. Une notification de
message s'affichera, mais sans « Répondre ».

**La vue unique est une promesse de convenance.** `FLAG_SECURE` n'a aucun
équivalent iOS — c'était déjà noté dans `audit-etat-reel.md`.

**Le multi-appareil n'existe pas.** `DeviceKeyBundle` porte une contrainte
d'unicité par compte : installer Vault sur un iPhone **remplacerait** le
trousseau d'un Android existant, et l'historique chiffré d'avant
deviendrait illisible. Ce n'est pas propre à iOS, mais c'est la première
fois que ça devient une situation courante.

---

## 5. Décision — TRANCHÉE le 24/09/2026

Compiler et faire tourner la version iOS est à portée : ce qui manquait
était structurel, et c'est en place.

**La publication, elle, attend la chaîne d'appel complète.** Décision du
fondateur, et elle ferme l'alternative qui était ouverte ici :

```
APNs → PushKit → CallKit → couche d'appel native iOS → Flutter/LiveKit
```

Pas de première publication App Store avec une messagerie qui fonctionne et
des appels entrants qui n'arrivent pas correctement. Le raisonnement est
juste : une note d'App Store se répare beaucoup plus lentement qu'un bug, et
la première impression d'une messagerie se joue sur l'appel qu'on rate.

### Ce que ça implique, concrètement

**`voip` reste hors des `UIBackgroundModes`** tant que PushKit n'est pas
réellement implémenté. Ce n'est pas une précaution de style : Apple rejette
une application qui déclare ce mode sans utiliser PushKit. Le mode se pose
**avec** le code, jamais avant.

**Le chantier à mener**, dans l'ordre des dépendances :

1. **PushKit** — un second jeton, distinct de celui d'APNs classique, et un
   type de push à part. Le serveur devra donc tenir DEUX jetons par appareil
   iOS : celui des messages et celui des appels. `DeviceToken` n'a
   aujourd'hui qu'une colonne `token`.
2. **CallKit** — l'écran d'appel du système, celui qui s'affiche sur
   téléphone verrouillé. Apple impose une contrainte que rien ne contourne :
   **tout push PushKit reçu DOIT aboutir à un appel CallKit signalé**, sinon
   iOS coupe la remise des pushs VoIP à l'application. Un appel déjà
   raccroché doit donc quand même être signalé, puis terminé aussitôt.
3. **La couche native iOS** — l'équivalent Swift de `CallManager`, avec la
   même règle qui a structuré la version Android : le natif est la source de
   vérité, Flutter observe. Et la même ligne rouge, qui vaut identiquement
   ici : **les clés E2EE ne quittent jamais Flutter**, le natif ne chiffre
   rien, et il n'existe aucun chemin qui puisse envoyer un message en clair.
4. **Le pont vers Flutter/LiveKit** — le pendant de `NativeCallBridge` et de
   `nativeCallGateProvider`. Rappel de ce qui a coûté un appel perdu sur
   Android : le pont était écrit, testé, complet, et **rien ne l'appelait**.
   Un test qui vérifie le branchement depuis `main.dart` existe désormais ;
   il faudra son équivalent iOS.

**Ce qui est déjà bon** et n'est pas à refaire : `content-available` et
`apns-priority: 10` côté serveur valent pour les pushs de message ; la
configuration APNs de PushKit s'ajoutera à côté, elle ne la remplace pas.
