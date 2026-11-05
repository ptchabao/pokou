# Native Call & Notification Layer — spécification d'implémentation

**Pour** : la personne qui écrira le Kotlin et le Swift.
**Statut** : à implémenter. Aucune ligne de code natif n'existe encore au-delà de `MainActivity.kt`.

---

## 0. La règle, en une phrase

> **Un appel entrant doit sonner, s'afficher et se répondre sans que le moteur Flutter existe.**

Tout ce qui suit découle de là. Chaque fois qu'une décision est ambiguë, c'est cette phrase qui tranche.

Corollaire, qui est la raison d'être de ce document : **ces mécanismes forment UNE couche, pas quatre.** Sonnerie, notification d'appel, actions Répondre/Refuser et réponse rapide aux messages partagent le même état, la même authentification et la même garantie d'idempotence. Les implémenter séparément produirait quatre sources de vérité qui se contrediraient au premier cas limite — un appel raccroché pendant que la notification est encore affichée, par exemple.

---

## 1. Ce qui existe déjà — à NE PAS réécrire

Vérifié dans le code au 23/09/2026. Cette section existe pour éviter de refinancer du travail fait.

| Élément | Où | État |
|---|---|---|
| Appels de groupe réintégrables | `api/app/models/orm.py` (`CallLog`, `CallParticipant`) | ✅ `left_at` est distinct de `status` : quitter ne termine pas l'appel |
| Détection d'appel actif | `GET /calls/active?group_id=` | ✅ |
| Bandeau « Appel en cours — Rejoindre » | `group_conversation_screen.dart` (`_ActiveCallBanner`) | ✅ |
| Canaux de notification séparés | `push_service.dart` | ✅ `vault_messages`, `vault_calls_v2` |
| `fullScreenIntent` + `category: call` | `push_service.dart` | ✅ |
| Actions Répondre/Refuser | `push_service.dart` | ⚠️ existent, mais exigent le lancement de Flutter |
| Push sans contenu sensible | `messages.py::_push_preview` | ✅ « Nouveau message » + identifiants seulement |
| Sonnerie à l'arrivée du push | canal `vault_calls_v2` | ⚠️ jouée UNE fois par le système, ne boucle pas |
| Gestes de conversation | `conversation_screen.dart` | ✅ groupes, séparateurs de date, glisser-pour-répondre, réactions |

**Les deux ⚠️ sont l'objet de ce chantier.** Le reste ne doit pas être touché.

---

## 2. Ce que le serveur envoie aujourd'hui

À connaître avant d'écrire quoi que ce soit — le natif consomme exactement ceci.

### Appel entrant — `api/app/routes/calls.py`

Message FCM **data-only** (`silent=True`), donc Android n'affiche rien de lui-même : c'est le client qui construit la notification.

```json
{
  "type": "call",
  "room": "c8f2a91e-...",
  "from_user_id": "43",
  "is_video": "1",
  "caller_name": "Pondikpa",
  "group_id": "12",
  "group_name": "Entrepreneurs",
  "priority": "urgent",
  "muted": "0"
}
```

> ⚠️ **L'identifiant de l'appel est `room`, pas `call_id`.** `CallLog.id` existe mais la signalisation n'en fait rien : `POST /calls/signal` retrouve l'appel par `CallLog.room == room`. Le natif doit donc porter `room` partout où la spécification générique parlerait de `call_id`.

### Message — `api/app/routes/messages.py`

```json
{
  "type": "message",
  "contact_user_id": "43",
  "contact_name": "Pondikpa",
  "message_id": "m_...",
  "priority": "normal",
  "muted": "0"
}
```

Le corps de la notification est **toujours** « Nouveau message ». Le texte ne transite jamais par Firebase — c'est une garantie acquise, à ne pas défaire pour afficher un aperçu dans la notification native.

### Routes concernées

| Route | Usage |
|---|---|
| `POST /calls/signal` | `{room, target_user_id, event}` où `event ∈ {accept, decline, end}` |
| `POST /calls/token` | obtenir un jeton LiveKit pour rejoindre |
| `GET /calls/active?group_id=` | appel de groupe en cours |
| `POST /messages` | envoi d'un message |

---

## 3. Le problème d'authentification — à régler EN PREMIER

C'est le point que la spécification générique laisse de côté et qui décide de tout le reste.

`POST /calls/signal` et `POST /messages` exigent un `Authorization: Bearer`. Le jeton vit dans `FlutterSecureStorage`, côté Flutter. **Le natif ne peut pas y accéder proprement** : lire les `EncryptedSharedPreferences` du greffon depuis Kotlin revient à dépendre de son implémentation interne, qui change sans préavis.

Trois options, et une seule est saine.

| Option | Verdict |
|---|---|
| Lire le stockage du greffon depuis Kotlin | ❌ dépend d'un détail d'implémentation d'un paquet tiers |
| Flutter recopie le jeton dans un stockage natif | ⚠️ marche, mais duplique un secret de session longue durée dans un second endroit |
| **Le serveur met un jeton d'action dans le push** | ✅ **à retenir** |

### Le jeton d'action

Le push provient du serveur : il peut donc porter un laissez-passer que le natif présentera sans rien savoir de la session de l'utilisateur.

```json
{
  "type": "call",
  "room": "c8f2a91e-...",
  "action_token": "at_9f2b...",
  "action_expires_in": "60"
}
```

Propriétés exigées — **ce sont les mêmes que celles du ticket WebSocket déjà en place** (`api/app/services/ws_ticket_service.py`), et il faut réutiliser ce modèle plutôt qu'en inventer un second :

1. tiré par `secrets.token_urlsafe(32)` ;
2. **portée étroite** : il n'autorise que `accept` / `decline` / `reply`, sur CE `room` ou CETTE conversation, pour CE destinataire. Il n'ouvre rien d'autre de l'API ;
3. durée courte — 60 s pour un appel (la durée de sonnerie), 24 h pour une réponse à un message (une notification peut rester affichée longtemps) ;
4. **stocké en empreinte**, jamais en clair ;
5. **usage unique**, consommé par une écriture conditionnelle en un seul ordre SQL — voir `ws_ticket_service.consume` ;
6. lié à la session émettrice (`jti`), pour que révoquer un appareil invalide ses jetons d'action en attente.

Le natif n'a alors **aucun secret à stocker**. C'est ce qui rend le reste simple.

---

## 4. Idempotence — le contrat backend

Demande explicite du fondateur, et elle a une raison concrète : Android peut délivrer deux fois la même action (réseau lent, l'utilisateur appuie deux fois, le système rejoue l'intent après un redémarrage du processus).

### Ce qu'il ne doit JAMAIS arriver

```
2 réponses envoyées pour un même appui
2 messages identiques envoyés
un appel accepté puis re-accepté, écrasant un état plus récent
```

### La règle

Toute action native porte un identifiant unique, généré **par le serveur** au moment du push (pas par le client — un client qui génère l'identifiant peut le regénérer au réessai, ce qui annule la garantie).

```
answer_action_id   = aa_<uuid>
decline_action_id  = ad_<uuid>
reply_action_id    = ar_<uuid>
```

Le backend applique :

```
action reçue
      ↓
déjà consommée ?
      ↓ oui                    ↓ non
200 + état actuel        appliquer + marquer consommée
(aucun second effet)              ↓
                            200 + nouvel état
```

**Répondre 200 et non 409 sur une action déjà consommée.** Un 4xx pousserait le natif à réessayer ou à afficher une erreur, alors que du point de vue de l'utilisateur l'action a réussi. Le corps porte l'état réel, que le natif utilise pour se synchroniser.

### Transitions à refuser

Le serveur reste l'autorité :

| Tentative | Réponse |
|---|---|
| `accept` sur un appel `ended` | refusé — le natif ferme la notification |
| `accept` sur un appel `declined` par un autre appareil du même compte | refusé |
| `decline` sur un appel déjà `accepted` | refusé |
| `reply` sur une conversation où l'on a été bloqué | refusé, silencieusement côté utilisateur |

---

## 5. Android — la couche à écrire

### 5.1 Composants

```
app/src/main/kotlin/com/mahizu/vault/
├── MainActivity.kt                    (existant)
└── call/
    ├── VaultFirebaseMessagingService.kt   reçoit le push AVANT Flutter
    ├── CallManager.kt                     source de vérité de l'état d'appel
    ├── CallNotification.kt                Notification.CallStyle
    ├── RingtoneService.kt                 service de premier plan : sonnerie + vibration
    ├── CallActionReceiver.kt              Répondre / Refuser
    └── VaultApi.kt                        client HTTP minimal (jeton d'action)
└── messaging/
    └── ReplyActionReceiver.kt             RemoteInput
```

**`VaultFirebaseMessagingService` doit être déclaré dans le manifeste avec une priorité supérieure à celle du greffon Flutter**, sinon `firebase_messaging` capte le message et le chemin natif ne s'exécute jamais. C'est l'erreur la plus fréquente sur ce type d'intégration.

### 5.2 La machine à états

`CallManager` est **la seule source de vérité**. Ni la notification, ni le service de sonnerie, ni Flutter ne détiennent d'état propre — ils observent celui-ci.

```
                    push reçu
                        ↓
                    RINGING ──────────────┐
                   ↙   ↓   ↘              │
            ANSWER  DECLINE  TIMEOUT      │ caller_hangup
              ↓       ↓        ↓          │ (via FCM ou WebSocket)
          ANSWERING  ENDED   MISSED       ↓
              ↓                         ENDED
          CONNECTING
              ↓
          CONNECTED
              ↓
            ENDED
```

Chaque transition **arrête immédiatement** sonnerie, vibration et notification, dans cet ordre, avant tout appel réseau. Le fondateur l'a demandé explicitement : l'utilisateur ne doit pas entendre la sonnerie continuer pendant que le réseau réfléchit.

### 5.3 La sonnerie

`RingtoneService`, service de premier plan de type `phoneCall` :

- `AudioManager.STREAM_RING`, `AudioAttributes.USAGE_NOTIFICATION_RINGTONE` ;
- `MediaPlayer.isLooping = true` sur `res/raw/vault_ringtone.wav` (1,5 s, un cycle — déjà en place) ;
- vibration : motif répété, `VibrationEffect.createWaveform(..., repeat = 0)` ;
- respecte `AudioManager.ringerMode` : `SILENT` → aucune sonnerie, `VIBRATE` → vibration seule ;
- respecte `NotificationManager.currentInterruptionFilter` pour « Ne pas déranger », **sauf** si l'appelant est prioritaire au sens du système ;
- **s'arrête de lui-même après 45 s** sans réponse, en passant l'état à `MISSED`. Une sonnerie qui ne s'arrête jamais est un défaut, pas une fonctionnalité.

Le canal `vault_calls_v2` porte déjà la sonnerie pour le premier signal. **Quand le service de premier plan prend le relais, la notification d'appel doit être posée sur un canal SILENCIEUX**, sinon le système et le service jouent le son en même temps. Prévoir `vault_calls_silent_v1` à cet usage.

### 5.4 La notification d'appel

`Notification.CallStyle.forIncomingCall(person, declineIntent, answerIntent)` :

- `setFullScreenIntent(..., highPriority = true)` ;
- `setOngoing(true)` — non balayable tant que l'appel sonne ;
- `setCategory(CATEGORY_CALL)` ;
- `Person` avec le nom de l'appelant et son avatar si disponible localement.

`USE_FULL_SCREEN_INTENT` doit être déclaré au manifeste. **Sur Android 14+, cette permission n'est accordée d'office qu'aux applications de type appel ou alarme** ; Vault entre dans cette catégorie, mais la déclaration Play Store doit le refléter, sinon l'autorisation est révoquée et l'écran plein ne s'affiche plus. À vérifier lors de la publication.

### 5.5 Répondre sans lancer Flutter

C'est le cœur du chantier. Le chemin interdit :

```
❌  notification → MainActivity → Flutter démarre → cherche l'appel → répond
```

Le chemin exigé :

```
✅  notification
        ↓
    CallActionReceiver (BroadcastReceiver)
        ↓
    CallManager.answer(room, answer_action_id)
        ↓
    arrêt sonnerie + vibration + notification      ← IMMÉDIAT, avant le réseau
        ↓
    VaultApi.signal(room, "accept", action_token)  ← en tâche de fond
        ↓
    puis seulement : lancer Flutter si nécessaire
        ↓
    Flutter lit CallManager.state, obtient son jeton LiveKit, rejoint la room
```

Le `BroadcastReceiver` doit terminer son travail en moins de 10 s. Déléguer l'appel réseau à un `goAsync()` ou à un service court — pas à un `WorkManager` différé, l'appel n'attend pas.

### 5.6 Le pont vers Flutter

Un `EventChannel` unique, `com.mahizu.vault/call_events`, qui émet :

```
CALL_INCOMING   { room, from_user_id, is_video, caller_name, group_id? }
CALL_ANSWERED   { room }
CALL_DECLINED   { room }
CALL_ENDED      { room, reason }
CALL_FAILED     { room, reason }
```

Et un `MethodChannel` `com.mahizu.vault/call` pour l'interrogation au démarrage :

```
getCurrentCall() → { room, state, ... } | null
```

**Flutter ne doit jamais supposer qu'ouvrir `CallScreen` signifie que l'appel est connecté.** Il observe `CallManager.state`. C'est exactement le point que le fondateur a souligné.

### 5.7 RemoteInput — répondre à un message

```
Notification
  └── action "reply"
        └── RemoteInput(key = "vault_reply_text")
```

Au déclenchement, `ReplyActionReceiver` :

1. lit le texte via `RemoteInput.getResultsFromIntent(intent)` ;
2. appelle `POST /messages` avec le jeton d'action et `reply_action_id` ;
3. met à jour la notification : `setRemoteInputHistory(arrayOf(texte))` — l'utilisateur voit sa réponse, comme dans WhatsApp ;
4. en cas d'échec réseau, **conserve le texte** et réaffiche l'action plutôt que de perdre ce qui a été écrit.

> ⚠️ **Le chiffrement de bout en bout.** `POST /messages` attend soit du clair, soit un chiffré accompagné de son enveloppe. Le natif **ne peut pas chiffrer** : les clés de session vivent dans `E2EEStore`, côté Dart, et les exposer au natif reviendrait à élargir la surface du chiffrement.
>
> Deux voies, à trancher avec le fondateur :
>
> - **(a)** la réponse rapide part en clair, et l'interface le DIT — une mention « réponse non chiffrée » dans la notification. Honnête, mais contredit la garantie que nous venons de poser ;
> - **(b)** la réponse rapide est mise en FILE côté natif, et Flutter la chiffre et l'envoie à son prochain démarrage. L'utilisateur voit « en attente d'envoi ». Cohérent avec le chiffrement, au prix d'un délai.
>
> **Recommandation : (b).** Nous venons de rendre le chiffrement infalsifiable (`SealRefused` arrête l'envoi plutôt que de dégrader) ; introduire ici une porte qui envoie du clair sans que l'utilisateur l'ait choisi défait ce travail. Et une réponse différée de quelques secondes est un moindre mal comparé à un message que l'utilisateur croyait chiffré et qui ne l'était pas.

---

## 6. iOS — PushKit + CallKit

À faire **après** la validation d'Android sur appareil, pas en parallèle : les deux plateformes partagent la machine à états, et la stabiliser une fois vaut mieux que deux fois.

- `PKPushRegistry` pour les pushs VoIP ;
- **obligation Apple** : tout push VoIP reçu DOIT donner lieu à un `CXProvider.reportNewIncomingCall` — sinon iOS cesse purement et simplement de livrer les pushs VoIP à l'application. Il n'y a pas de tolérance sur ce point ;
- `CXAnswerCallAction` / `CXEndCallAction` → mêmes appels que le `CallManager` Android, même contrat d'idempotence ;
- la sonnerie est jouée par le système : aucun `AudioPlayer` côté application ;
- `CXProvider.reportCall(with:endedAt:reason:)` quand l'appelant raccroche.

Le backend devra distinguer les jetons APNs VoIP des jetons APNs ordinaires : ce sont deux jetons différents pour un même appareil. `DeviceToken.platform` devra donc admettre `ios_voip`.

---

## 7. Le repli, et sa date de péremption

Le chemin Flutter actuel reste **pendant l'implémentation**, et pas au-delà.

```
push d'appel
      ↓
couche native disponible ?
   ↓ oui              ↓ non
chemin natif      chemin Flutter actuel
```

**Critère de sortie, à écrire dans le suivi du chantier :** le repli est supprimé quand le chemin natif a été validé sur au moins **5 modèles Android différents** couvrant Android 10 à 15, dans les quatre situations du §8, sans échec.

La raison de fixer ce critère maintenant : un repli sans date devient une seconde architecture permanente. Les bugs deviennent alors irreproductibles — « ça marche chez moi » signifie simplement qu'on n'a pas emprunté le même chemin.

---

## 8. Tests sur appareil réel

Aucun de ces cas ne se vérifie en émulateur ni en test unitaire. **Ils font partie de la livraison**, pas d'une vérification facultative.

| # | Situation | Attendu |
|---|---|---|
| 1 | Application **tuée**, téléphone **verrouillé** | sonnerie + écran d'appel plein écran en moins de 3 s |
| 2 | Application tuée, **Répondre** depuis l'écran verrouillé | sonnerie arrêtée immédiatement, appel connecté, `CallScreen` ouvert |
| 3 | Application tuée, **Refuser** | sonnerie arrêtée, notification fermée, **Flutter n'est jamais lancé** |
| 4 | Appelant raccroche **pendant** la sonnerie | sonnerie et notification disparaissent en moins de 2 s |
| 5 | Aucune réponse pendant 45 s | appel manqué, notification remplacée, sonnerie arrêtée |
| 6 | Mode silencieux | vibration seule |
| 7 | « Ne pas déranger » | comportement conforme au réglage système |
| 8 | Casque Bluetooth connecté | sonnerie sur le bon flux |
| 9 | Appel entrant **pendant** un appel GSM | l'appel Vault ne prend pas le dessus |
| 10 | Double appui sur Répondre | **une seule** acceptation côté serveur |
| 11 | Réponse rapide, application tuée | message envoyé une seule fois |
| 12 | Batterie faible / optimisation agressive (Xiaomi, Oppo, Huawei) | le push arrive encore |

### Ce qui a été éprouvé à ce jour

**23/09/2026 — un appel entrant passe bien sur appareil réel** (confirmé par
le fondateur). C'est le cas 1, et c'est le plus structurant : il prouve que
la chaîne complète tient — le push arrive, `VaultFirebaseMessagingService`
l'intercepte, `CallManager` prend la main, `RingtoneService` sonne et la
notification `CallStyle` s'affiche. Rien de tout cela ne se vérifie en
émulateur.

Ce que ça ne prouve **pas**, et qu'il ne faut pas confondre : les onze
autres cas, en particulier le refus sans lancer Flutter (3), l'arrêt sur
raccrochage distant (4), le délai de 45 s (5), la réponse rapide (11) et
surtout le cas 12 sur les surcouches chinoises. Le repli Flutter reste donc
en place, et la ligne « Appels natifs » de `audit-etat-reel.md` reste
**À TESTER** tant que les douze cas ne sont pas couverts sur les cinq
modèles convenus (Android 10 à 15, dont un Xiaomi, un Oppo et un Huawei).

Le cas 12 mérite une mention à part : les surcouches chinoises sont majoritaires sur le marché de Vault et tuent agressivement les processus d'arrière-plan. Si le push n'arrive pas sur ces modèles, l'architecture est correcte et le produit ne marche quand même pas. À tester tôt, pas à la fin.

---

## 9. Ordre de travail

Celui fixé par le fondateur, avec les dépendances explicitées.

```
1. Jeton d'action côté backend        ← bloque tout le reste (§3, §4)
2. CallManager + machine à états      ← source de vérité
3. RingtoneService                    ← dépend de 2
4. CallStyle + full-screen intent     ← dépend de 2
5. Répondre / Refuser sans Flutter    ← dépend de 1, 2, 3, 4
6. Pont EventChannel vers Flutter     ← dépend de 2
7. RemoteInput messages               ← dépend de 1 ; trancher (a)/(b) au §5.7 d'abord
8. Tests appareil réel (§8)           ← bloque la suppression du repli
9. PushKit + CallKit iOS              ← après validation d'Android
```

Les étapes 1 et 2 ne sont pas négociables en premier : tout le reste s'y branche, et les écrire après conduirait à recâbler chaque composant.

---

## 10. Ce qui reste hors de ce chantier

Pour éviter que le périmètre ne glisse :

- la sélection multiple de messages (manquante, mais purement Flutter) ;
- `textScaler` et les débordements aux grandes tailles de texte ;
- la migration SQLCipher, qui attend une validation sur appareil ;
- les appels de groupe, qui fonctionnent.
