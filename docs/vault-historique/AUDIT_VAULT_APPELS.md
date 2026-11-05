# Audit des appels de Vault : audio, vidéo, groupe

Date : 23 octobre 2026. Version auditée : Vault 1.18.0 (build 34), API au commit `4f17a68`.
Écrit pour le responsable de Vault. Chaque constat dit comment il a été établi : **prouvé** (exécuté, résultat observé), **relu** (lu dans le code, raisonnement vérifié mais non exécuté) ou **à vérifier sur appareil** (dépend du comportement d'Android ou d'iOS, que je n'ai pas pu tester ici).

## Verdict

Les appels 1 contre 1 sur Android sont solidement conçus (couche native, jetons d'action, chiffrement). Les appels de groupe et iOS ne sont pas prêts pour être présentés comme une fonction fiable : un bug de signalisation fait raccrocher l'appelant au premier refus, iOS ne sonne pas application fermée, et plusieurs contrôles d'accès manquent côté serveur. Trois défauts ont été **prouvés** par des sondes exécutées contre l'API ; sept autres sont probables et demandent un test sur téléphone.

| Domaine | État |
| --- | --- |
| Appel audio/vidéo 1 contre 1, Android | Bien conçu ; deux risques à vérifier sur appareil (réponse depuis la notification, micro en arrière-plan) |
| Appel de groupe | Fonctionne dans le cas nominal ; bug de signalisation au premier refus, sonnerie coupée trop tôt, aucune limite de taille |
| Appel vidéo | Même socle ; aucune adaptation au réseau mobile, grille de tous les participants |
| iOS | Appels entrants fiables seulement application ouverte |
| Sécurité du serveur | Trois contrôles d'accès manquants, prouvés |
| Chiffrement | 1 contre 1 seulement, bien fait ; groupes en clair pour le serveur de média |

## Ce qui a été fait pour cet audit

- Lecture complète de `api/app/routes/calls.py` (832 lignes), du service LiveKit, des jetons d'action, du journal d'appels dans la conversation, de la file d'événements ; côté application, de la session d'appel, du dépôt d'appels, de l'écran d'appel entrant, du pont natif, de la porte d'entrée native ; côté Android, des huit fichiers natifs et du manifeste ; côté iOS, du delegate, des autorisations et des modes d'arrière-plan.
- **Trois sondes exécutées** contre l'API (fichier jetable, supprimé après usage), dont les résultats sont cités plus bas.
- Tests existants : 63 tests serveur (39 appels, 10 journal, 14 jetons) passent ; les 609 tests Flutter passent. Aucun ne couvre les défauts ci-dessous, ce qui explique qu'ils soient passés inaperçus.
- **Non fait** : aucun test sur un vrai téléphone ni un émulateur, aucune vérification du serveur LiveKit réellement déployé, aucune mesure de consommation de données.

## Constats

### Gravité élevée

**A1. Aucun contrôle d'appartenance sur `/calls/signal` — prouvé.**
N'importe quel utilisateur connecté qui connaît le nom d'un salon peut envoyer `end`, `accept` ou `decline` pour l'appel d'un autre. Sonde : un compte étranger a envoyé `end` sur l'appel de deux autres ; réponse 200 et le journal de l'appelant est passé à « manqué ». Le serveur relaie aussi l'événement en WebSocket et par push (`call_end`) à n'importe quel identifiant d'utilisateur fourni. Le nom du salon est un identifiant aléatoire, mais `GET /calls/active` le donne à tout membre d'un groupe, y compris sans être dans l'appel.
Piste : n'accepter un signal que d'un participant (appelant ou invité) de l'appel, et n'envoyer qu'aux participants.

**A2. Un jeton LiveKit s'obtient pour n'importe quel nom de salle — prouvé.**
`POST /calls/token {"room": "ma-salle-privee-hors-vault"}` renvoie un jeton valide pour une salle qui n'existe dans aucun appel. Conséquences : n'importe quel compte peut utiliser le LiveKit payé de Vault comme service de visioconférence gratuit (coût), et rejoindre toute salle dont il connaît le nom. Le jeton est valable 6 heures (valeur par défaut de la bibliothèque, jamais réglée) et n'est pas lié à l'appel : on peut rejoindre une salle après la fin de l'appel. Le serveur n'a aucun moyen d'éjecter ni de couper un participant (aucun appel à l'API d'administration de LiveKit).
Piste : ne délivrer un jeton que pour un appel connu dont on est participant, invité ou membre du groupe ; durée d'une ou deux heures.

**A3. Un utilisateur bloqué fait sonner celui qui l'a bloqué, via un groupe — prouvé.**
Sonde : A bloque B ; B lance un appel dans un groupe qu'il partage avec A ; réponse 200, l'appel apparaît dans le journal de A et la sonnerie part. Les appels 1 contre 1 vérifient le blocage, pas les appels de groupe.
Piste : ne pas faire sonner (ni inscrire) les membres qui ont bloqué l'appelant.

**A4. Appel de groupe : le premier refus fait quitter l'appelant — relu.**
Dans `call_session.dart`, la réaction à `call:decline` quitte l'appel dès qu'il n'y a plus de participant dans le salon, sans vérifier que quelqu'un a déjà rejoint ni que d'autres invités sonnent encore. Scénario : A appelle B et C ; C refuse tout de suite ; A raccroche sans signaler `end` ; B continue de sonner puis rejoint une salle vide ; le journal reste « en sonnerie ». Aucun test ne couvre la session d'appel.
Piste : ne quitter que si quelqu'un a déjà rejoint et que plus personne n'est dans le salon ; sinon continuer à attendre les autres invités.

**A5. Android : rien ne maintient l'appel en cours en arrière-plan — relu, à vérifier sur appareil.**
Le seul service de premier plan (type appel) ne vit que pendant la sonnerie et s'arrête dès qu'on répond. Pendant la conversation, aucun service ne tient le micro ou la caméra, et le manifeste ne déclare ni micro ni caméra pour un service de premier plan. Depuis Android 9, une application en arrière-plan reçoit du silence du micro : appuyer sur Accueil ou verrouiller l'écran pendant un appel peut couper la voix de l'utilisateur. Aucun verrou d'écran n'est tenu non plus pendant une vidéo.
Piste : service de premier plan de type appel (ou micro et caméra) pendant toute la durée de l'appel, avec notification « Appel en cours ».

**A6. iOS : l'appel entrant ne sonne pas application fermée — relu.**
Le push d'appel part en donnée silencieuse (type « background »), les modes d'arrière-plan se limitent aux notifications distantes et à l'audio, et il n'y a ni CallKit ni PushKit. iOS ne réveille pas une application fermée ou en économie d'énergie pour un push silencieux, et ne sonne pas sans CallKit. Sur iPhone, un appel n'arrive de façon fiable que si l'application est ouverte. Les tests Flutter l'actent d'ailleurs (« iOS garde le repli Flutter »).
Piste : CallKit + PushKit (travail natif iOS conséquent), ou déclarer clairement que les appels sur iPhone exigent l'application ouverte.

**A7. Android 12 et plus : « Répondre » depuis la notification peut ne pas ouvrir l'application — relu, à vérifier sur appareil.**
Le bouton « Répondre » est un `PendingIntent.getBroadcast` qui appelle un récepteur, lequel démarre ensuite l'activité depuis un fil d'arrière-plan. Depuis Android 12 (l'application cible l'API 36), démarrer une activité depuis un récepteur lancé par une notification est interdit (« notification trampoline »). Risque : le serveur enregistre l'acceptation et l'appelant croit que l'autre a décroché, mais l'application de l'appelé ne s'ouvre pas et la conversation ne s'établit pas. L'écran plein (téléphone verrouillé) ouvre l'activité directement et n'est pas concerné.
Piste : faire de « Répondre » un `PendingIntent.getActivity` vers l'activité principale, qui répond depuis l'activité.

### Gravité moyenne

**M1. Aucune gestion d'un second appel — relu.** Côté application, accepter un deuxième appel raccroche silencieusement le premier (`existing.hangUp()`) et prévient tous ses participants ; côté natif, un push d'appel pendant un appel connecté remplace l'état. Il n'y a ni « occupé » renvoyé à l'appelant ni appel en attente.

**M2. La signalisation de groupe est trop grossière — relu.** Quand un participant raccroche, le client envoie `end` à tous les autres, y compris à ceux qui sonnent encore : leur sonnerie s'arrête (écran d'appel entrant, et couche native via `call_end`) alors que l'appel continue entre les autres. Un refus ne prévient que l'appelant.

**M3. La fin d'un appel ne dépend que des clients — relu.** Il n'y a ni webhook LiveKit ni balayage serveur. Un appel dont l'application plante ou perd le réseau reste « en sonnerie » ou « en cours » indéfiniment dans le journal. Raccrocher envoie une requête par participant, sans nouvelle tentative : hors ligne, le signal de fin est perdu. Le temps de vie (90 secondes, 4 heures) ne sert qu'à décider si le bandeau « Rejoindre » s'affiche, jamais à clore la ligne.

**M4. Faire sonner tout un groupe est coûteux et non borné — relu.** Les groupes n'ont aucune taille maximale ; un appel sonne tous les membres l'un après l'autre dans la requête HTTP (diffusion temps réel ou push, deux jetons d'action, une recherche de contact par membre), avec un envoi push synchrone qui bloque la boucle d'événements. Le client abandonne à 20 secondes. Un gros groupe donne un appel lent ou en échec, et tout membre peut faire sonner tout le monde, y compris en sourdine (les appels passent toujours). Seule la limite de débit globale par processus s'applique.

**M5. Chiffrement limité — relu.** Les appels de groupe ne sont jamais chiffrés de bout en bout (le serveur de média voit l'audio et la vidéo). En 1 contre 1, le chiffrement exige une session déjà établie et la capacité des deux côtés ; sinon l'appel passe en clair et l'écran l'indique. Une seule clé partagée sert tout l'appel, sans rotation : un participant qui part ou est ajouté garde la même clé. La rétrogradation vers le clair n'est détectée qu'à l'arrivée d'une piste non chiffrée.

**M6. Fuite de numéro de téléphone — relu.** Le nom envoyé à LiveKit est le nom complet ou, à défaut, le numéro de téléphone ; l'écran d'appel l'affiche tel quel aux participants qui n'ont pas la personne dans leur carnet.

**M7. Jetons d'action non liés à la session, jamais nettoyés — relu.** À l'émission, l'identifiant de session n'est pas transmis : révoquer une session n'invalide pas les jetons d'appel en attente (60 secondes). La fonction qui purge les jetons expirés n'est appelée nulle part : la table gagne deux lignes par appel entrant, sans fin.

**M8. Réseau mobile : aucun réglage — relu.** Aucun réglage LiveKit de bande passante (flux adaptatif, résolution) n'est présent dans le code, et l'option « économie de données » ne s'applique qu'à la qualité des images envoyées, pas aux appels. La vidéo de groupe affiche tous les participants en grille à deux colonnes, sans limite. La perte de connexion ne déclenche que la fin de l'appel : aucun état « reconnexion » n'est géré.

**M9. Une connexion temps réel périmée masque l'appel — relu.** Si le serveur croit l'appelé joignable en WebSocket (connexion ouverte mais application en arrière-plan), il n'envoie pas de push : l'appelé peut ne jamais être sonné. Aucun accusé de sonnerie n'existe.

**M10. Mode Bouclier incohérent — relu.** Côté Flutter, le mode Bouclier peut différer un appel entrant sans le faire sonner ; côté Android, la couche native sonne indépendamment. Le comportement dépend donc de l'état de l'application.

### Gravité faible

- Le journal d'appels fait environ deux à trois requêtes par ligne, pour 100 lignes, sans pagination ; il n'est jamais purgé.
- La bulle d'appel déposée dans la conversation est écrite en base sans événement temps réel : l'affichage immédiat n'est pas vérifié.
- Un refus de permission micro ou caméra produit l'échec générique « connexion impossible » : non vérifié.
- Aucun garde-fou contre les appels répétés vers une même personne.
- La documentation interne `docs/native-call-layer.md` décrit encore la couche native comme « à implémenter », alors qu'elle existe.

## Conformité à vérifier avant publication

- **Google Play, Android 14 et plus** : l'autorisation d'écran plein (`USE_FULL_SCREEN_INTENT`) n'est accordée qu'aux applications déclarées comme appel ou alarme ; le code le dit lui-même. La déclaration doit figurer dans la Play Console, faute de quoi l'écran plein est retiré.
- **Type de service de premier plan « appel »** : exige une utilisation conforme de l'API de téléphonie ou le droit de l'usage déclaré ; non vérifié.
- **Apple** : les consignes de l'App Store sur les appels sans CallKit n'ont pas été vérifiées dans cet audit.

## Ce qui est bien fait

- **Jetons d'action** : usage unique par écriture atomique, empreinte stockée, portée étroite, durée de 60 secondes, journaux sans jeton ; 14 tests, dont la concurrence.
- **Couche native Android** : état unique, silence avant tout appel réseau, respect du mode silencieux, refus sans démarrer Flutter, sonnerie sur le bon flux audio, délais documentés et cohérents entre les quatre couches.
- **Chiffrement 1 contre 1** : clé liée à l'expéditeur et au destinataire, refus de toute enveloppe qui ouvre une session, session déjà établie exigée, tout-ou-rien pour les invités, détection de rétrogradation ; testé côté serveur et côté application.
- **Appel de groupe** : un seul appel actif par groupe (deux appuis simultanés rejoignent le même salon), bandeau « Appel en cours », le départ d'un participant ne ferme pas l'appel des autres côté serveur.
- **Journal** : idempotent (une seule bulle par appel, même par plusieurs chemins), durée comptée depuis le premier décroché.

## Couverture de tests

| Zone | Tests | Ce qui manque |
| --- | --- | --- |
| Serveur, appels | 39 | Autorisation de `/calls/signal`, de la salle fournie à `/calls/token`, du blocage en groupe, appel de très gros groupe |
| Serveur, journal dans la conversation | 10 | Diffusion temps réel de la bulle |
| Serveur, jetons d'action | 14 | Lien avec la session à l'émission, purge appelée |
| Application | 39 sur les appels (lecture de réponses, porte native, pont natif, écran entrant, notification) | Session d'appel (signalisation de groupe, raccrochage, reconnexion), écran d'appel, sonnerie, journal d'appels |
| Natif Android | 0 | Machine à états, récepteur, service de sonnerie |
| iOS | 0 | Tout |

## Plan proposé

1. **Avant d'annoncer les appels de groupe** : A1, A2, A3 (contrôles d'accès, quelques heures de travail et tests), A4 (correction de la session, un test à écrire d'abord), A5 (service de premier plan).
2. **À valider sur téléphone avant tout nouveau binaire** : A5, A7, et le comportement de M9. Cela demande un appareil Android récent (13 ou 14) et deux comptes.
3. **Décision produit pour iOS** : construire CallKit et PushKit, ou limiter les appels iPhone à l'application ouverte et le dire dans l'interface et la fiche du store.
4. **Ensuite** : M1 à M4 (occupé, signalisation de groupe, balayage des appels orphelins, borne de taille et de débit), puis M5 à M10.

## Questions ouvertes

- Un serveur LiveKit de production est-il provisionné (le code cite `livekit.mahizu.com` dans un commentaire), avec quel forfait, quelle région, quel plafond de minutes ?
- Combien coûte aujourd'hui une minute d'appel de groupe vidéo pour dix participants, et qui peut en déclencher ?
- La déclaration de l'écran plein est-elle faite dans la Play Console ?
- Quelle taille de groupe vise-t-on pour les appels (le code n'en fixe aucune) ?
