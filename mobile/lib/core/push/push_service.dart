import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications_web.dart'
    as web_notifications;

import '../../features/calls/presentation/call_controller.dart';
import '../../features/calls/presentation/call_screen.dart';
import '../../features/calls/presentation/incoming_call_screen.dart';
import '../../features/groups/presentation/group_conversation_screen.dart';
import '../../features/messaging/presentation/conversation_screen.dart';
import '../../features/messaging/presentation/messaging_controller.dart';
import '../../features/modules/verses/verse_data.dart';
import '../../features/modules/verses/verse_screen.dart';
import '../../l10n/app_localizations.dart';
import '../crypto/call_keys.dart';
import '../l10n/l10n_provider.dart';
import '../notifications/active_conversation.dart';
import '../notifications/background_notifications.dart';
import '../notifications/message_notification_handler.dart';
import '../notifications/message_notifications.dart';
import '../notifications/notification_policy.dart';
import '../l10n/l10n_standalone.dart';
import '../providers.dart';
import '../router/app_router.dart';
import '../settings/app_settings.dart';
import 'push_repository.dart';

/// Doit être une fonction top-level (ou statique) — FCM l'exécute dans un
/// isolate séparé quand un message arrive app fermée/en arrière-plan, isolé
/// de PushService (aucun état partagé possible), d'où l'instance de plugin
/// et la logique entièrement autonomes ci-dessous.
///
/// Les messages "normaux" (type != call) restent en payload FCM
/// "notification" — Android les affiche déjà tout seul même app fermée,
/// sans code à exécuter ici. Les appels, eux, arrivent en data-only (voir
/// silent=True dans app/services/push_service.py côté API) : sans ça,
/// Android afficherait EN PLUS sa propre notification par défaut à côté de
/// la nôtre. C'est donc à ce handler de construire la vraie UI d'appel
/// entrant (plein écran, actions Répondre/Refuser) quand l'app est fermée
/// ou en arrière-plan — en foreground c'est _showForegroundNotification qui
/// s'en charge (l'app tourne déjà, pas besoin de cet isolate séparé).
///
/// ── Sur ANDROID, ce chemin ne sert plus ─────────────────────────────
///
/// La couche native (PokouFirebaseMessagingService → CallManager →
/// RingtoneService) traite les pushs d'appel AVANT Flutter et pose sa
/// propre notification, avec `CallStyle`, la sonnerie et le plein écran.
/// Elle le fait sans réveiller le moteur Dart, ce qui est tout l'intérêt :
/// plusieurs secondes de moins sur un téléphone en veille.
///
/// Laisser ce gestionnaire s'exécuter en plus produisait DEUX notifications
/// d'appel pour un seul appel — constaté sur appareil réel le 23/09/2026,
/// application complètement fermée. Et deux, pas une de trop au hasard :
/// l'identifiant utilisé ici était `message.hashCode`, donc CHAQUE push
/// reçu empilait une notification de plus au lieu de remplacer la
/// précédente. Un appareil qui a laissé derrière lui d'anciens jetons FCM
/// en reçoit autant de copies.
///
/// Les deux défauts sont corrigés : Android sort tout de suite, et
/// l'identifiant est désormais CONSTANT — sur iOS, où la couche native
/// n'existe pas encore, un second push remplace le premier au lieu de
/// s'ajouter.
/// L'initialisation iOS du greffon de notifications locales.
///
/// Elle MANQUAIT, et son absence est silencieuse : sur iPhone, le greffon
/// n'était jamais configuré pour Darwin, donc aucune notification locale ne
/// s'affichait — ni l'appel entrant, ni le repli hors ligne. Rien dans les
/// journaux ne le disait.
///
/// Les trois demandes d'autorisation sont à `false` DÉLIBÉRÉMENT :
/// `firebase_messaging` les demande déjà (voir `messaging.requestPermission`
/// plus bas). Les laisser à `true` ferait apparaître DEUX fenêtres système
/// à la première ouverture, et la seconde passerait pour un bug.
const DarwinInitializationSettings _darwinInit = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

/// L'identifiant de LA notification d'appel entrant.
///
/// Un appel, une notification. Le natif fait déjà ce choix de son côté
/// (`CallNotification.NOTIFICATION_ID`) ; ce nombre-ci n'a pas à lui
/// correspondre, les deux ne coexistent jamais sur la même plateforme.
const int kIncomingCallNotificationId = 424243;
const String kWebPushVapidKey =
    'BH-gXJw22FwfaCTW-SPbHph6hKmObX658YXLP2Mj9Apwc89nxGhyUo3gh25IYERcpdzZVg3_kMCLWjfduBoIfsg';

/// Ce gestionnaire doit-il construire la notification d'appel ?
///
/// Non sur Android : la couche native l'a déjà fait, avant même que cet
/// isolate ne se réveille. Deux notifications pour un appel, c'est ce qu'on
/// a observé sur appareil réel le 23/09/2026.
///
/// Oui partout ailleurs — iOS n'a pas encore de couche native, et le
/// repli Flutter y reste le seul chemin.
///
/// Une fonction plutôt qu'une condition en ligne : c'est une RÈGLE, elle
/// mérite d'être nommée et vérifiée par un test. Elle prend la plateforme
/// en paramètre pour cette raison — un test ne peut pas changer
/// `defaultTargetPlatform` de l'isolate FCM.
bool shouldBuildCallNotificationInBackground(TargetPlatform platform) =>
    platform != TargetPlatform.android;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Un message, dans le format que cette version sait mettre en forme —
  // voir core/notifications/background_notifications.dart.
  if (MessagePush.tryParse(message.data) != null) {
    await handleRichPushInBackground(message.data);
    return;
  }
  if (message.data['type'] != 'call') return;
  // La couche native d'Android est la source de vérité pour les appels
  // entrants. Elle a déjà sonné et affiché la notification quand cet
  // isolate se réveille — s'il se réveille.
  if (!shouldBuildCallNotificationInBackground(defaultTargetPlatform)) return;

  // Cet isolate n'a ni contexte ni conteneur Riverpod : la langue se relit
  // depuis le coffre des réglages, comme le fait l'application au démarrage.
  final l = await loadStandaloneL();
  final isVideo = message.data['is_video'] == '1';
  final callerName = message.data['caller_name'] as String? ?? l.callIncoming;
  final callsChannel = _callsChannelOf(l);

  final notifications = FlutterLocalNotificationsPlugin();
  await initializeMessageNotificationsPlugin(
    notifications,
    darwin: _darwinInit,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(callsChannel);

  await notifications.show(
    // CONSTANT, et non `message.hashCode` : un identifiant différent par
    // push empile les notifications au lieu de les remplacer. Un appel,
    // une notification, quel que soit le nombre de pushs reçus.
    kIncomingCallNotificationId,
    callerName,
    isVideo ? l.pushIncomingVideoCall : l.pushIncomingAudioCall,
    NotificationDetails(
      android: AndroidNotificationDetails(
        callsChannel.id,
        callsChannel.name,
        // Sans teinte, Android retombe sur son vert par défaut.
        color: AppColors.accentPrimary,
        category: AndroidNotificationCategory.call,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        actions: [
          AndroidNotificationAction(
            'accept',
            l.pushAnswer,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'decline',
            l.pushDecline,
            showsUserInterface: true,
          ),
        ],
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

/// Les deux canaux Android. Leur nom et leur description s'affichent dans
/// les réglages système du téléphone, donc ils suivent la langue de l'app —
/// d'où des fonctions plutôt que des constantes.
AndroidNotificationChannel _messagesChannelOf(L l) =>
    AndroidNotificationChannel(
      'pokou_messages',
      l.pushMessagesChannel,
      description: l.pushMessagesChannelDesc,
      importance: Importance.high,
    );

/// Le canal des appels.
///
/// ── Pourquoi l'identifiant porte un « _v2 » ────────────────────────────
///
/// Android FIGE les réglages d'un canal à sa création. Rappeler
/// `createNotificationChannel` avec le même identifiant et un son différent
/// ne change RIEN sur un téléphone où l'application est déjà installée : le
/// système considère que l'utilisateur peut avoir personnalisé ce canal et
/// refuse de le réécrire. Le seul moyen de livrer un nouveau son est donc un
/// NOUVEL identifiant — et de supprimer l'ancien, sinon il reste visible et
/// vide dans les réglages du téléphone.
///
/// ── Pourquoi un son porté par le canal ─────────────────────────────────
///
/// La sonnerie était jouée par Flutter, depuis `CallScreen`. Elle ne se
/// déclenchait donc qu'une fois l'application lancée et l'écran d'appel
/// construit — c'est-à-dire après le réveil du moteur Dart, l'ouverture de
/// l'activité et la navigation. Sur un téléphone en veille, ce délai est
/// long, et il est entièrement à la charge de l'application.
///
/// Un son posé sur le canal est joué par le SYSTÈME, à l'instant où la
/// notification est publiée, sans que Flutter existe. Le téléphone sonne
/// donc dès l'arrivée du push.
///
/// Ce que ça ne fait PAS, et il faut le dire : Android joue ce son UNE fois,
/// il ne le boucle pas. Une vraie sonnerie qui dure jusqu'à la réponse
/// suppose `Notification.CallStyle` et un service de premier plan en Kotlin
/// — voir le relevé d'architecture. Cette étape-ci donne le premier signal,
/// immédiat ; elle ne remplace pas la couche native.
AndroidNotificationChannel _callsChannelOf(L l) => AndroidNotificationChannel(
  callsChannelId,
  l.pushCallsChannel,
  description: l.pushCallsChannelDesc,
  importance: Importance.max,
  sound: const RawResourceAndroidNotificationSound('pokou_ringtone'),
  // Le flux SONNERIE et non le flux notification : c'est lui que porte
  // le volume de sonnerie du téléphone, et lui que le mode silencieux et
  // « Ne pas déranger » traitent comme un appel.
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  enableVibration: true,
);

/// L'identifiant du canal d'appel EN VIGUEUR.
///
/// Incrémenté à chaque changement de ses réglages — voir la docstring
/// ci-dessus : Android ne relit pas un canal déjà créé.
const callsChannelId = 'pokou_calls_v2';

/// Les identifiants abandonnés, à supprimer des réglages du téléphone.
///
/// Sans ce ménage, chaque version laisse derrière elle un canal orphelin :
/// l'écran « Notifications » de Pokou finirait par lister « Appels »,
/// « Appels », « Appels »… sans qu'aucun ne dise lequel est actif.
const _retiredCallChannelIds = ['pokou_calls'];

/// Notifications push (Firebase Cloud Messaging) — messages/appels reçus
/// app fermée/en arrière-plan, en complément du WebSocket (qui ne
/// fonctionne que tant que l'app est ouverte, voir ws_client.dart).
///
/// Limite connue : les actions "Répondre"/"Refuser" sur la notification
/// d'appel exigent que l'app soit relancée (showsUserInterface: true) pour
/// s'exécuter — un vrai refus silencieux depuis une notification sans
/// jamais rouvrir l'app (comme WhatsApp) demanderait un message FCM
/// data-only + un traitement réseau depuis l'isolate d'arrière-plan, pas
/// encore fait ici.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  Future<void>? _initialization;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _pendingToken;

  /// Y a-t-il une session ouverte ?
  ///
  /// Une valeur POUSSÉE par AuthController, et non lue depuis
  /// `authControllerProvider` : ce provider observe déjà `pushServiceProvider`
  /// (il appelle `registerCurrentToken` à la connexion), donc lire l'un
  /// depuis l'autre forme un cycle. Riverpod le refuse — et l'exception
  /// tombait dans un `catch` qui n'écrivait qu'un `debugPrint`. Résultat :
  /// le jeton FCM n'était JAMAIS enregistré, et le serveur journalisait
  /// « Aucun jeton FCM » sans que rien n'explique pourquoi.
  bool _authenticated = false;

  /// L'identifiant de la session ouverte — nécessaire pour ouvrir l'écran
  /// visé par une notification. Poussé pour la même raison que ci-dessus.
  int? _myUserId;

  /// Appelé par AuthController à chaque changement de session.
  void setSession({required bool authenticated, int? userId}) {
    _authenticated = authenticated;
    _myUserId = userId;
    if (authenticated) unawaited(_drainPendingReplies());
  }

  /// Pourquoi cet appareil ne peut pas recevoir de notification, ou `null`
  /// si tout va bien.
  ///
  /// Toute cette chaîne est best-effort et n'écrivait que des `debugPrint`,
  /// invisibles dans un binaire de release : un appareil sans push le
  /// restait indéfiniment, sans que rien nulle part ne le dise. L'écran
  /// « Appareils connectés » lit ce champ.
  String? pushFailureReason;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Le chapeau commun sous lequel Android range les notifications de
  /// conversation — voir `groupKey` dans _showForegroundNotification.
  static const _messagesGroupKey = kMessagesGroupKey;

  /// Où l'isolat de Firebase confie les messages quand l'application
  /// tourne — voir background_notifications.dart.
  ReceivePort? _mainPort;
  AppLifecycleListener? _lifecycle;
  bool _drainingReplies = false;
  Map<String, dynamic>? _pendingAcceptedCall;
  bool _acceptingCall = false;

  /// Best-effort de bout en bout — un plugin manquant (tests widget, un
  /// appareil sans Google Play Services) ou Firebase non configuré ne
  /// doivent jamais faire planter le démarrage/la connexion ; ils dégradent
  /// juste vers "pas de push, WebSocket seul" (voir docstring de classe).
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    // Le jeton D'ABORD, et séparément.
    //
    // Il était lu en DERNIER, après la création des canaux, l'initialisation
    // du greffon de notifications locales et deux dialogues de permission
    // système. Tout cela au premier plan et dans un seul try : un échec —
    // ou simplement un dialogue que l'utilisateur n'a pas encore touché —
    // empêchait la lecture du jeton, donc son enregistrement, donc toute
    // notification. Le serveur journalisait « Aucun jeton FCM » et l'appareil
    // ne disait rien.
    //
    // Sur mobile, le jeton ne dépend ni du greffon local ni de la permission
    // d'affichage. Sur Web, FCM exige la permission avant getToken().
    if (!kIsWeb) await _acquireAndRegisterToken();

    try {
      final messaging = FirebaseMessaging.instance;

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin;
      if (kIsWeb) {
        if (web_notifications.notificationPermission == 'granted') {
          await _acquireAndRegisterToken();
        }
        androidPlugin = null;
      } else {
        androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final l = _ref.read(appL10nProvider);
        await androidPlugin?.createNotificationChannel(_messagesChannelOf(l));
        await androidPlugin?.createNotificationChannel(_callsChannelOf(l));
        for (final retired in _retiredCallChannelIds) {
          await androidPlugin?.deleteNotificationChannel(retired);
        }

        await initializeMessageNotificationsPlugin(
          _localNotifications,
          darwin: _darwinInit,
          onResponse: (response) {
            final payload = response.payload;
            if (payload == null) return;
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final actionId = response.actionId;
            if (actionId == kReplyActionId || actionId == kMarkReadActionId) {
              unawaited(
                _messageHandler().onAction(
                  actionId!,
                  data,
                  input: response.input,
                ),
              );
              return;
            }
            _handleResponse(actionId, data);
          },
        );
        _listenForHandOffs();
        _clearNotificationsOfOpenConversation();
        // Notification touchée alors que l'app était complètement fermée
        // (cold start) — `onDidReceiveNotificationResponse` ne se déclenche
        // pas pour celle-ci, contrairement à un simple arrière-plan.
        final launchDetails = await _localNotifications
            .getNotificationAppLaunchDetails();
        final launchPayload = launchDetails?.notificationResponse?.payload;
        if (launchDetails?.didNotificationLaunchApp == true &&
            launchPayload != null) {
          _handleResponse(
            launchDetails!.notificationResponse!.actionId,
            jsonDecode(launchPayload) as Map<String, dynamic>,
          );
        }

        await messaging.requestPermission();
      }

      // Android 14+ (API 34) ne concède plus USE_FULL_SCREEN_INTENT à
      // l'installation, même déclarée au manifeste : sans cet accord, un
      // appel entrant app fermée arrive comme une notification ordinaire au
      // lieu de prendre l'écran. C'est très exactement le symptôme observé.
      // Best-effort et non bloquant : refusée, l'app reste utilisable, la
      // notification d'appel est juste moins visible.
      if (!kIsWeb) {
        try {
          await androidPlugin?.requestFullScreenIntentPermission();
        } catch (exc) {
          debugPrint('[Push] Autorisation plein écran indisponible: $exc');
        }
      }

      FirebaseMessaging.onMessage.listen(
        kIsWeb ? _showWebForegroundNotification : _showForegroundNotification,
      );

      if (!kIsWeb) {
        // Notification système (payload "notification") touchée alors que
        // l'app tournait déjà en arrière-plan / cold start via Firebase.
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => _handleResponse(null, message.data),
        );
        final initial = await messaging.getInitialMessage();
        if (initial != null) _handleResponse(null, initial.data);
      }
    } catch (exc) {
      // L'affichage des notifications est cassé sur cet appareil, mais le
      // jeton, lui, est peut-être déjà enregistré : les deux échecs sont
      // distincts et se disent séparément.
      debugPrint('[Push] Affichage des notifications indisponible: $exc');
      pushFailureReason ??= '$exc';
    }
  }

  Future<bool> enableWebPush() async {
    if (!kIsWeb) return false;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        pushFailureReason = 'Browser notification permission was not granted.';
        return false;
      }

      _pendingToken = null;
      pushFailureReason = null;
      await _acquireAndRegisterToken();
      return _pendingToken != null && pushFailureReason == null;
    } catch (exc) {
      debugPrint('[Push] Autorisation Web refusée: $exc');
      pushFailureReason = '$exc';
      return false;
    }
  }

  /// Lit le jeton FCM de cet appareil et l'envoie au serveur.
  ///
  /// C'est la seule étape indispensable pour RECEVOIR une notification : le
  /// reste (canaux, permission d'affichage, plein écran) décide de ce qui est
  /// MONTRÉ une fois le message arrivé.
  Future<void> _acquireAndRegisterToken() async {
    if (kIsWeb && web_notifications.notificationPermission != 'granted') {
      return;
    }

    try {
      // `FirebaseMessaging.instance` lève de façon SYNCHRONE si
      // `Firebase.initializeApp()` n'a jamais tourné (tests widget, appareil
      // sans Google Play Services) — d'où sa lecture à l'intérieur du try.
      final messaging = FirebaseMessaging.instance;
      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((
        token,
      ) async {
        _pendingToken = token;
        await _registerToken(token);
      });
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? kWebPushVapidKey : null,
      );
      if (token == null) {
        pushFailureReason =
            'Firebase n\'a pas fourni de jeton pour cet appareil.';
        return;
      }
      _pendingToken = token;
      await _registerToken(token);
    } catch (exc) {
      // Firebase non configuré, appareil sans Google Play Services, greffon
      // absent (tests widget) : pas de push, mais l'app reste utilisable.
      debugPrint('[Push] Lecture du token FCM impossible: $exc');
      pushFailureReason = '$exc';
    }
  }

  void _showWebForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final isCall = data['type'] == 'call';
    final title =
        notification?.title ??
        (isCall ? data['caller_name'] as String? ?? 'Appel entrant' : null);
    if (title == null || title.isEmpty) return;

    final body =
        notification?.body ??
        (isCall
            ? data['is_video'] == '1'
                  ? 'Appel vidéo entrant'
                  : 'Appel audio entrant'
            : '');
    web_notifications.showNotification(title, body);
  }

  bool _isVideo(Map<String, dynamic> data) {
    final value = data['is_video'];
    return value == true || value == '1' || value == 'true';
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (MessagePush.tryParse(message.data) != null) {
      unawaited(_showMessage(message.data));
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final contactUserId = int.tryParse(
      data['contact_user_id']?.toString() ?? '',
    );
    final groupId = int.tryParse(data['group_id']?.toString() ?? '');

    // La décision de PRÉSENTATION, séparée de la décision d'envoyer (prise
    // par le serveur) et de l'événement lui-même. C'est cette séparation qui
    // permet de se taire quand la conversation est déjà ouverte : le serveur
    // ne peut pas le savoir, lui.
    final presentation = decidePresentation(
      type: data['type'] as String?,
      priority: parsePriority(data['priority'] as String?),
      muted: data['muted'] == '1',
      contactUserId: contactUserId,
      groupId: groupId,
      active: _ref.read(activeConversationProvider),
      settings: _ref.read(appSettingsProvider),
    );
    if (presentation == NotificationPresentation.suppressed) return;

    final isCall = presentation == NotificationPresentation.fullScreen;
    final l = _ref.read(appL10nProvider);
    // Le son suit la présentation ET le réglage global : une notification
    // silencieuse le reste même si l'utilisateur a laissé le son activé.
    final withSound =
        presentation != NotificationPresentation.silent &&
        _ref.read(appSettingsProvider).notificationSound;

    // Un identifiant STABLE par conversation : trois messages de la même
    // personne remplacent la même notification au lieu d'en empiler trois.
    //
    // Et STABLE aussi pour un appel : il valait `message.hashCode`, donc un
    // identifiant différent par push. Un appareil qui reçoit deux fois le
    // même appel — deux jetons FCM laissés derrière lui par une
    // réinstallation, par exemple — voyait deux notifications d'appel
    // s'empiler. Le même défaut existait dans le gestionnaire
    // d'arrière-plan, et c'est ce que le fondateur a constaté sur un vrai
    // téléphone le 23/09/2026.
    final notificationId = isCall
        ? kIncomingCallNotificationId
        : conversationNotificationId(
            contactUserId: contactUserId,
            groupId: groupId,
          );

    _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isCall ? _callsChannelOf(l).id : _messagesChannelOf(l).id,
          isCall ? _callsChannelOf(l).name : _messagesChannelOf(l).name,
          // Sans teinte, Android retombe sur son vert par défaut.
          color: AppColors.accentPrimary,
          category: isCall ? AndroidNotificationCategory.call : null,
          fullScreenIntent: isCall,
          // Un bandeau qui s'impose pour une mention ou une réponse, une
          // ligne discrète pour le reste. C'est la traduction du niveau
          // d'interruption décidé côté serveur.
          importance: switch (presentation) {
            NotificationPresentation.fullScreen => Importance.max,
            NotificationPresentation.heads_up => Importance.high,
            NotificationPresentation.silent => Importance.low,
            _ => Importance.defaultImportance,
          },
          priority:
              presentation == NotificationPresentation.heads_up ||
                  presentation == NotificationPresentation.fullScreen
              ? Priority.high
              : Priority.defaultPriority,
          // Toutes les conversations sous un même chapeau : Android replie
          // alors « Pokou — 4 messages » au lieu d'une pile de lignes.
          groupKey: isCall ? null : _messagesGroupKey,
          actions: isCall
              ? [
                  AndroidNotificationAction(
                    'accept',
                    l.pushAnswer,
                    showsUserInterface: true,
                  ),
                  AndroidNotificationAction(
                    'decline',
                    l.pushDecline,
                    showsUserInterface: true,
                  ),
                ]
              : null,
          playSound: withSound,
          enableVibration: withSound,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// La notification d'un message enrichi, construite dans l'application —
  /// qu'elle soit au premier plan, ou en arrière-plan et sollicitée par
  /// l'isolat de Firebase.
  Future<void> _showMessage(Map<String, dynamic> data) async {
    final push = MessagePush.tryParse(data);
    if (push == null) return;
    final settings = _ref.read(appSettingsProvider);
    // La conversation « ouverte » ne l'est que si on la regarde : écran
    // éteint ou application en arrière-plan, elle reste montée mais
    // personne ne la lit.
    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final presentation = decidePresentation(
      type: push.type,
      priority: parsePriority(push.priority),
      muted: push.muted,
      contactUserId: push.contactUserId,
      groupId: push.groupId,
      active: resumed ? _ref.read(activeConversationProvider) : null,
      settings: settings,
    );
    try {
      await _messageHandler().handle(
        push,
        presentation: presentation,
        withSound: settings.notificationSound,
      );
    } catch (exc) {
      debugPrint('[Push] Notification de message impossible: $exc');
    }
  }

  MessageNotificationHandler _messageHandler() {
    final api = _ref.read(apiClientProvider);
    final messaging = _ref.read(messagingRepositoryProvider);
    return MessageNotificationHandler(
      presenter: MessageNotificationPresenter(
        plugin: _localNotifications,
        l: _ref.read(appL10nProvider),
      ),
      api: api,
      messaging: messaging,
      myUserId: _myUserId,
      sendDirect: (recipientId, text) async {
        await _sendDirectReply(recipientId, text);
        return true;
      },
    );
  }

  /// Une réponse privée, scellée et envoyée par l'application. Son clair
  /// est rangé dans le cache : le serveur ne l'a jamais eu, et c'est la
  /// seule copie que l'expéditeur pourra relire.
  Future<void> _sendDirectReply(int recipientId, String text) async {
    final saved = await _ref
        .read(messagingRepositoryProvider)
        .send(recipientId: recipientId, content: text);
    await _ref.read(pokouMessageStoreProvider).saveDirect([saved]);
  }

  /// Les réponses écrites depuis une notification pendant que Pokou était
  /// fermé partent maintenant — voir PendingReplies.
  Future<void> _drainPendingReplies() async {
    if (_drainingReplies) return;
    _drainingReplies = true;
    try {
      await PendingReplies().drain(_sendDirectReply);
    } finally {
      _drainingReplies = false;
    }
  }

  void _listenForHandOffs() {
    if (_mainPort != null) return;
    final port = ReceivePort();
    // Un nom resté enregistré par une instance précédente de l'application
    // pointe vers un port mort : on le remplace.
    IsolateNameServer.removePortNameMapping(kMainNotificationsPortName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      kMainNotificationsPortName,
    );
    _mainPort = port;
    port.listen((event) {
      if (event is! Map) return;
      (event['ack'] as SendPort?)?.send(true);
      switch (event['kind']) {
        case 'push':
          unawaited(
            _showMessage(Map<String, dynamic>.from(event['data'] as Map)),
          );
        case 'action':
          final payload = event['payload'] as String?;
          if (payload == null) return;
          unawaited(
            _messageHandler().onAction(
              event['action'] as String,
              jsonDecode(payload) as Map<String, dynamic>,
              input: event['input'] as String?,
            ),
          );
      }
    });
  }

  /// Ouvrir une conversation efface sa notification, comme revenir sur
  /// l'application quand elle est déjà à l'écran.
  void _clearNotificationsOfOpenConversation() {
    void clear(ActiveConversation? active) {
      if (active == null) return;
      final key = active.groupId != null
          ? 'group:${active.groupId}'
          : 'contact:${active.contactUserId}';
      unawaited(
        MessageNotificationPresenter(
          plugin: _localNotifications,
          l: _ref.read(appL10nProvider),
        ).clear(key),
      );
    }

    _ref.listen<ActiveConversation?>(
      activeConversationProvider,
      (_, next) => clear(next),
    );
    _lifecycle ??= AppLifecycleListener(
      onResume: () => clear(_ref.read(activeConversationProvider)),
    );
  }

  /// Appelé depuis AuthController après connexion/restauration de session
  /// réussie — au premier lancement de l'app (avant toute connexion),
  /// `initialize()` s'exécute déjà mais n'a pas encore d'utilisateur
  /// authentifié pour associer le jeton, d'où ce second point d'appel.
  Future<void> registerCurrentToken() async {
    await initialize();
    // Une nouvelle tentative complète, et non un abandon si `_messaging` est
    // nul : c'est précisément le cas où la première a échoué qu'il faut
    // réessayer. L'ancienne version sortait en silence, et l'appareil restait
    // sans push jusqu'à la réinstallation.
    if (_pendingToken == null) {
      await _acquireAndRegisterToken();
      return;
    }
    await _registerToken(_pendingToken);
  }

  Future<void> _registerToken(String? token) async {
    if (token == null) return;
    _pendingToken = token;
    if (!_authenticated) {
      // Pas encore connecté : le jeton reste sous le coude et partira à la
      // connexion, quand AuthController appellera `registerCurrentToken`.
      return;
    }
    try {
      await _ref.read(pushRepositoryProvider).registerToken(token);
      pushFailureReason = null;
      debugPrint('[Push] Token FCM enregistré pour l’utilisateur connecté');
    } catch (exc) {
      // Le serveur a refusé le jeton : l'appareil a bien le sien, mais le
      // serveur ne saura pas où pousser. C'est un échec distinct de
      // « pas de jeton », et il se dit aussi.
      debugPrint('[Push] Enregistrement du token refusé: $exc');
      pushFailureReason = '$exc';
    }
  }

  void _handleResponse(String? actionId, Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'message') {
      _openConversation(data);
    } else if (type == 'group_message' || type == 'group_mention') {
      _openGroupConversation(data);
    } else if (type == 'call') {
      _handleCallResponse(actionId, data);
    } else if (type == 'verse') {
      _openVerse(data);
    }
  }

  /// Un verset de 6 h ou 18 h touché : l'écran du module, ce verset en tête.
  void _openVerse(Map<String, dynamic> data) {
    final kind = VerseKind.fromName(data['kind']?.toString());
    if (kind == null) return;
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => VerseScreen(
          kind: kind,
          focusSlot: int.tryParse(data['slot']?.toString() ?? ''),
        ),
      ),
    );
  }

  void _openConversation(Map<String, dynamic> data) {
    final contactUserId = int.tryParse(
      data['contact_user_id'] as String? ?? '',
    );
    final myUserId = _myUserId;
    if (contactUserId == null || myUserId == null) return;

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: myUserId,
          contactUserId: contactUserId,
          contactName:
              data['contact_name'] as String? ??
              _ref.read(appL10nProvider).mediaContact,
        ),
      ),
    );
  }

  /// Pendant de _openConversation pour les groupes — la charge utile push
  /// est construite dans api/app/routes/groups.py::send_group_message.
  void _openGroupConversation(Map<String, dynamic> data) {
    final groupId = int.tryParse(data['group_id'] as String? ?? '');
    final myUserId = _myUserId;
    if (groupId == null || myUserId == null) return;

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => GroupConversationScreen(
          myUserId: myUserId,
          groupId: groupId,
          groupName:
              data['group_name'] as String? ??
              _ref.read(appL10nProvider).pushGroupFallback,
        ),
      ),
    );
  }

  void _handleCallResponse(String? actionId, Map<String, dynamic> data) {
    final room = data['room'] as String?;
    final fromUserId = int.tryParse(data['from_user_id'] as String? ?? '');
    final isVideo = _isVideo(data);
    if (room == null || fromUserId == null) return;

    if (actionId == 'decline') {
      unawaited(
        _ref
            .read(callRepositoryProvider)
            .signal(room: room, targetUserId: fromUserId, event: 'decline'),
      );
      return;
    }
    if (actionId == 'accept') {
      if (!_authenticated) {
        // Cold start : l'action Android arrive avant la restauration du
        // token. La conserver évite que le catch silencieux fasse perdre
        // l'appel pendant le démarrage de Flutter.
        _pendingAcceptedCall = Map<String, dynamic>.from(data);
      } else {
        unawaited(
          _acceptCall(room: room, fromUserId: fromUserId, isVideo: isVideo),
        );
      }
      return;
    }
    // Notification touchée sans action précise (corps du message) — même
    // écran de décision que pour une invitation reçue via le WebSocket.
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          room: room,
          fromUserId: fromUserId,
          // Les données FCM ne sont que des chaînes — d'où le parse ici.
          callType: data['group_id'] != null ? 'group' : '1:1',
          isVideo: isVideo,
          groupId: int.tryParse(data['group_id'] as String? ?? ''),
          groupName: data['group_name'] as String?,
          // Déjà résolu par le serveur pour CE destinataire (carnet, ou
          // nom d'un compte certifié) — voir calls.py::_ring.
          callerName: data['caller_name'] as String?,
          callerIsVerified: data['caller_is_verified'] == '1',
        ),
      ),
    );
  }

  Future<void> _acceptCall({
    required String room,
    required int fromUserId,
    required bool isVideo,
  }) async {
    if (_acceptingCall) return;
    _acceptingCall = true;
    try {
      final repository = _ref.read(callRepositoryProvider);
      final token = await repository.joinCall(room, inviter: fromUserId);
      await repository.signal(
        room: room,
        targetUserId: fromUserId,
        event: 'accept',
      );
      rootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: [fromUserId],
            startWithVideo: isVideo,
            joiningExistingCall: true,
          ),
        ),
      );
    } on CallEncryptionException {
      // Voir IncomingCallScreen._accept : l'appelant doit l'apprendre.
      unawaited(
        _ref
            .read(callRepositoryProvider)
            .signal(room: room, targetUserId: fromUserId, event: 'decline')
            .catchError((_) {}),
      );
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(L.of(context).callEncryptedJoinFailed)),
        );
      }
    } catch (_) {
      debugPrint(
        '[Push] Réponse à l’appel impossible; il a peut-être déjà pris fin.',
      );
    } finally {
      _acceptingCall = false;
    }
  }

  void drainPendingAcceptedCall() {
    final data = _pendingAcceptedCall;
    if (data == null || !_authenticated) return;
    _pendingAcceptedCall = null;
    final room = data['room'] as String?;
    final fromUserId = int.tryParse(data['from_user_id']?.toString() ?? '');
    if (room == null || fromUserId == null) return;
    unawaited(
      _acceptCall(room: room, fromUserId: fromUserId, isVideo: _isVideo(data)),
    );
  }
}

/// Watché une fois depuis PokouApp (voir main.dart), même schéma que
/// callSignalingProvider/shieldControllerProvider — le `create` lance
/// l'initialisation (fire-and-forget) plutôt que d'exposer un Future.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  service.initialize();
  return service;
});
