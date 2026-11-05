# Remédiation des appels de Vault

Date : 23 octobre 2026. Suite de l'audit [AUDIT_VAULT_APPELS.md](AUDIT_VAULT_APPELS.md).
Écrit pour le responsable de Vault et l'équipe qui déploie.

**Résumé.** Les trois failles serveur prouvées (A1, A2, A3) sont corrigées et couvertes par des tests négatifs qui échouaient sur l'ancien code. Le bug du premier refus dans les appels de groupe (A4) et la sonnerie coupée trop tôt (M2) sont corrigés et testés. Les appels abandonnés sont désormais clos par le serveur et les jetons d'action purgés (M3, M7). Deux correctifs Android (A5, A7) sont écrits et compilent, mais **ne sont pas validés sur téléphone** : ils ne doivent pas être considérés comme terminés avant le protocole de la section 4. iOS (A6) n'est pas traité.

## 1. Vérification des constats dans le code actuel

| Constat | Revérifié | Traitement |
| --- | --- | --- |
| A1 `/calls/signal` sans contrôle | Oui, sonde : 200 et journal modifié | Corrigé, testé |
| A2 jeton pour salle quelconque, 6 h | Oui, sonde : 200 et jeton délivré ; durée par défaut de la bibliothèque confirmée (6 h) | Corrigé, testé |
| A3 blocage ignoré en groupe | Oui, sonde : 200 et appel dans le journal de la personne qui bloque | Corrigé, testé |
| A4 premier refus en groupe | Oui, lecture de `call_session.dart` | Corrigé, testé (logique isolée) |
| A5 micro en arrière-plan (Android) | Oui, lecture : aucun service pendant l'appel | Écrit, compile, **non validé sur appareil** |
| A6 iOS sans CallKit/PushKit | Oui, lecture : push en arrière-plan silencieux, aucun CallKit | **Non traité** |
| A7 « Répondre » via récepteur (Android 12+) | Oui, lecture : `PendingIntent.getBroadcast` puis `startActivity` | Écrit, compile, **non validé sur appareil** |
| M1 second appel | Oui | Non traité |
| M2 `end` envoyé à ceux qui sonnent | Oui | Corrigé, testé |
| M3 appels abandonnés jamais clos | Oui | Corrigé (balayage), testé |
| M4 groupe non borné | Oui | Limite configurable ajoutée ; envoi encore synchrone |
| M5 chiffrement de groupe | Oui | Non traité (chantier à part) |
| M6 numéro dans LiveKit | Oui | Corrigé, testé |
| M7 jetons d'action jamais purgés ; non liés à la session | Oui | Purge corrigée et testée ; lien à la session non traité |
| M8 à M10 | Oui | Non traités |

Le contrôle `est-ce que l'appelant a bloqué ce membre ?` est symétrique, comme partout ailleurs dans Vault (`is_blocked_between`). Les paramètres de confidentialité ne prévoient pas de réglage « qui peut m'appeler » : rien à appliquer de ce côté.

## 2. Modifications

### Serveur (`api/`)

- `app/routes/calls.py`
  - **A1** : `/calls/signal` retrouve l'appel, exige que l'auteur en soit participant (sinon 404, sans confirmer son existence), que le destinataire en soit participant (sinon 400), que l'appelant ne réponde pas à son propre appel (400). Accepter un appel fini répond 409 ; refuser ou raccrocher un appel fini répond 200 sans effet. Aucun journal, WebSocket ni push n'est produit avant ces contrôles.
  - **A2** : `/calls/token` avec un salon n'accepte que le salon d'un appel connu, ouvert, dont on est participant ou, pour un appel de groupe, membre du groupe (sinon 404 ; 409 si l'appel est fini).
  - **A3** : un appel de groupe ne fait sonner ni n'inscrit les membres bloqués dans un sens ou dans l'autre ; l'ajout en cours d'appel d'un membre bloqué est refusé.
  - **M4** : au-delà de `CALL_MAX_GROUP_RING` membres à faire sonner (32 par défaut, prudent, à relever après mesure), l'appel de groupe est refusé avec un message clair ; même borne pour les ajouts en cours d'appel.
- `app/services/livekit_service.py` : jeton de **15 minutes** (`LIVEKIT_TOKEN_TTL_MINUTES`) au lieu de 6 heures. Le serveur LiveKit pousse des jetons renouvelés aux participants connectés et le SDK de l'application (livekit_client 2.11) les reprend (`SignalTokenUpdatedEvent`), donc un appel long n'est pas coupé. Le nom affiché n'est plus jamais le numéro de téléphone (**M6**).
- `app/services/call_housekeeping.py` (nouveau) et `app/utils/scheduler.py` : chaque minute, clôt les appels en sonnerie depuis plus de 90 s (« manqué ») et en cours depuis plus de 4 h (« terminé »), dépose leur bulle dans la conversation, purge les jetons d'action périmés (**M3**, **M7**). Idempotent.
- `app/config.py` : deux réglages, `LIVEKIT_TOKEN_TTL_MINUTES` (15) et `CALL_MAX_GROUP_RING` (32).
- Aucune migration de schéma.

### Application (`vault/`)

- `lib/features/calls/presentation/call_session.dart`
  - **A4** : nouvelle fonction `shouldLeaveOnRemoteSignal`. Tant que personne n'a rejoint, on ne quitte l'appel que si **tous** les invités ont refusé ou raccroché ; une fois l'appel établi, on reste tant que quelqu'un est dans le salon.
  - **M2** : nouvelle fonction `endSignalTargets`. Dans un appel de groupe qui continue sans nous, `end` ne part qu'aux personnes présentes dans le salon : ceux qui sonnent encore peuvent décrocher. Si l'appel se termine avec nous, tout le monde est prévenu.
  - Démarre et arrête le service natif d'appel en cours (A5).
- `lib/core/calls/native_call_bridge.dart` : `startOngoingCall` / `stopOngoingCall` (sans effet sur iOS, canal absent).
- `lib/features/calls/presentation/call_screen.dart` : transmet le pont natif à la session.
- Android :
  - **A7** : le bouton « Répondre » de la notification ouvre directement l'activité (`PendingIntent.getActivity`), qui répond elle-même ; « Refuser » reste un récepteur sans interface.
  - **A5** : `OngoingCallService` (nouveau), service de premier plan de types appel, micro et caméra, démarré une fois le média établi, arrêté au raccroché, avec une notification « Appel en cours ». Permissions `FOREGROUND_SERVICE_MICROPHONE` et `FOREGROUND_SERVICE_CAMERA` ajoutées au manifeste.

### Compatibilité avec l'application déjà publiée (1.18.0)

Le serveur corrigé peut être déployé **avant** une nouvelle version de l'application :

- l'application publiée n'envoie des signaux qu'aux participants de l'appel et ne rejoint que des salons auxquels elle est invitée : les nouveaux contrôles ne la bloquent pas ;
- un raccroché tardif reçoit 200 sans effet, comme avant ;
- le jeton plus court est renouvelé par LiveKit ;
- seul changement visible : rejoindre un appel déjà fini répond 409 au lieu d'ouvrir une salle vide.

## 3. Tests ajoutés et résultats réels

- `api/tests/test_vault_calls_security.py` (nouveau, 13 tests) : étranger qui termine, accepte ou refuse (404, aucun relais, journal inchangé), destinataire hors appel, appelant qui répond à son propre appel, appel fini, salle inventée, appel d'autrui, jeton après la fin, membre et étranger d'un groupe, durée du jeton et absence du numéro, blocage en groupe (deux cas), borne de taille, balayage des appels abandonnés (y compris idempotence et bulles déposées).
- Trois tests existants encodaient le comportement vulnérable (signal sur un salon inventé, jeton pour un salon inventé, salon inconnu accepté) ; ils ont été réécrits pour vérifier le comportement attendu.
- `vault/test/features/calls/call_signalling_test.dart` (nouveau, 10 tests), dont le scénario de l'audit : A appelle B et C, C refuse, A reste.

Résultats réels (23 octobre 2026) :

- **Les nouveaux tests détectent les failles** : relancés sur l'ancien `calls.py` et l'ancien `livekit_service.py`, 12 des 13 tests serveur échouent. Le treizième (balayage) passe aussi parce que son service est un fichier nouveau, absent de l'ancien code.
- **API, suite complète** : 1 397 réussis, 6 échecs. Ce sont les 6 mêmes qu'avant ce travail, sans lien avec les appels : un test du récap quotidien, deux de tarif marketplace, trois règles de migrations.
- **Application** : analyse sans erreur ni avertissement (les 99 remarques mineures habituelles) ; **619 tests Flutter réussis**, dont les 10 nouveaux.
- **Android** : bundle de release compilé avec le nouveau code Kotlin ; le manifeste final contient `OngoingCallService` et les deux permissions, cible API 36. Même avertissement qu'avant sur les symboles natifs non retirés. Compiler ne prouve pas que le comportement est le bon : voir la section 4.

## 4. Protocole de test sur appareil (obligatoire avant de publier un binaire)

Matériel : deux téléphones Android (dont un en Android 13 et un en Android 14 ou plus), deux comptes, réseau mobile et Wi-Fi.

| N° | Scénario | Attendu |
| --- | --- | --- |
| 1 | A appelle B, B verrouillé : écran plein, répondre | L'appel s'établit, voix dans les deux sens |
| 2 | A appelle B, B déverrouillé sur une autre application : répondre depuis la notification | L'application s'ouvre et l'appel s'établit (A7) |
| 3 | Pendant un appel, B appuie sur Accueil 2 minutes, puis verrouille l'écran 2 minutes | A entend B tout du long ; notification « Appel en cours » visible (A5) |
| 4 | Idem en vidéo | La caméra de B reprend au retour ; A continue d'entendre B |
| 5 | Refuser la permission micro, puis appeler | Message compréhensible, pas de blocage de l'application |
| 6 | Appel de groupe A → B, C, D ; C refuse tout de suite ; B répond 20 s plus tard | A et B se parlent ; D sonne toujours jusqu'à son délai (A4) |
| 7 | Appel de groupe établi A, B ; D sonne encore ; B raccroche | A et le salon restent ; D peut encore répondre et rejoindre A (M2) |
| 8 | Couper le réseau de B pendant 10 s puis le rétablir | Reprise ou fin propre ; le journal finit clos (au plus 4 h, ou 90 s si l'appel sonnait) |
| 9 | Appel de plus de 20 minutes | Aucune coupure à 15 minutes (renouvellement du jeton) |
| 10 | Casque Bluetooth branché puis retiré pendant l'appel | Le son suit le périphérique |

iOS : à faire après la décision sur CallKit/PushKit ; aujourd'hui, seul le cas « application ouverte » est pris en charge.

## 5. Non résolu, et risques résiduels

- **iOS (A6)** : aucun appel entrant fiable application fermée. Demande CallKit, PushKit, un certificat VoIP Apple, et des tests sur iPhone. Décision produit nécessaire.
- **A5 et A7** : écrits mais non validés sur appareil. Risque propre à A5 : Android peut refuser de démarrer un service micro/caméra si l'application n'est déjà plus au premier plan au moment de la connexion ; le code se replie alors sur le type « appel » seul, sans planter. La déclaration Play Console des services de premier plan (types appel, micro, caméra) et de l'écran plein doit être à jour.
- **Second appel (M1)** : accepter un deuxième appel raccroche toujours le premier, sans « occupé ».
- **Sonnerie des groupes (M4)** : la borne évite les très gros groupes, mais la sonnerie reste faite dans la requête HTTP avec un envoi push synchrone. À passer en tâche de fond.
- **Pas de webhook LiveKit ni d'éjection** : un participant ne peut pas être retiré d'un appel en cours ; le jeton court limite seulement la durée pendant laquelle on peut ENTRER.
- **Jetons d'action non liés à la session** (M7, seconde moitié) : demanderait d'émettre un jeton par appareil.
- **Chiffrement de groupe (M5)**, **réseau mobile (M8)**, **WebSocket périmé (M9)**, **Bouclier (M10)** : non traités. L'interface ne présente pas les appels de groupe comme chiffrés, ce qui est exact.
- **Machine à états** : la séparation état global / état par participant existe déjà en base (`call_logs` et `call_participants`). Le plan recommandait une refonte plus complète (états `CREATED`, `UNREACHABLE`, raisons de fin) ; elle n'a pas été faite, les correctifs ci-dessus traitant les défauts constatés sans changer le schéma.

## 6. Déploiement et retour arrière

1. **API d'abord.** Aucune migration, deux réglages facultatifs. Déployer, puis surveiller pendant 24 h dans les journaux : réponses 404/409 sur `/calls/token` et `/calls/signal` (une hausse anormale indiquerait un client légitime bloqué), et la ligne `[Appels] N appel(s) abandonné(s) clos`.
2. **Retour arrière de l'API** : revenir au commit précédent. Rien à défaire en base : le balayage n'a fait que clore des appels déjà morts et purger des jetons périmés.
3. **Application ensuite**, après le protocole de la section 4, sous un numéro de version supérieur au dernier publié, d'abord en test interne puis en déploiement progressif (10 %, puis 50 %, puis 100 %) en surveillant le taux de plantage et les retours sur les appels.
4. **Retour arrière de l'application** : arrêter le déploiement progressif dans la Play Console ; les deux versions fonctionnent avec la nouvelle API.
