import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/messaging/data/messaging_repository.dart';
import '../api/api_client.dart';
import '../crypto/e2ee_service.dart';
import '../l10n/l10n_standalone.dart';
import '../settings/app_settings.dart';
import '../storage/secure_token_storage.dart';
import '../storage/pokou_message_store.dart';
import 'message_notification_handler.dart';
import 'message_notifications.dart';
import 'notification_policy.dart';

/// Les notifications de message HORS de l'application : l'isolat que
/// Firebase réveille pour un push, et celui que le greffon de notifications
/// démarre pour un bouton (« Répondre », « Marquer comme lu »).
///
/// ── D'abord, confier à l'application si elle tourne ─────────────────────
///
/// Application en arrière-plan, Android livre quand même le push à un
/// isolat À PART. Deux isolats qui ouvrent la même conversation chiffrée en
/// même temps consomment la même clé, ou font diverger l'état du cliquet :
/// c'est l'application qui traite, et cet isolat-ci s'efface.
///
/// L'application répond qu'elle a pris le relais. Sans réponse, elle n'est
/// plus là — un nom resté enregistré après sa fermeture, alors que le
/// processus, lui, survit — et cet isolat traite lui-même.

const _handoffTimeout = Duration(seconds: 2);

/// Confie un événement à l'application. `true` si elle l'a pris.
Future<bool> handOffToMainIsolate(Map<String, Object?> event) async {
  final main = IsolateNameServer.lookupPortByName(kMainNotificationsPortName);
  if (main == null) return false;
  final reply = ReceivePort();
  try {
    main.send({...event, 'ack': reply.sendPort});
    return await reply.first.timeout(_handoffTimeout, onTimeout: () => false)
        as bool;
  } catch (_) {
    return false;
  } finally {
    reply.close();
  }
}

/// Un push de message enrichi, reçu par l'isolat de Firebase.
Future<void> handleRichPushInBackground(Map<String, dynamic> data) async {
  final push = MessagePush.tryParse(data);
  if (push == null) return;
  final taken = await handOffToMainIsolate({
    'kind': 'push',
    'data': {for (final e in data.entries) e.key: e.value?.toString()},
  });
  if (taken) return;

  final standalone = await _StandaloneNotifications.open();
  final settings = standalone.settings;
  final presentation = decidePresentation(
    type: push.type,
    priority: parsePriority(push.priority),
    muted: push.muted,
    contactUserId: push.contactUserId,
    groupId: push.groupId,
    // Aucun écran ouvert : l'application ne tourne pas.
    active: null,
    settings: settings,
  );
  await standalone.handler.handle(
    push,
    presentation: presentation,
    withSound: settings.notificationSound,
    fallbackFirst: true,
  );
}

/// Un bouton touché sur une notification de message, application fermée ou
/// en arrière-plan. Enregistré auprès du greffon dans les deux isolats —
/// voir [initializeMessageNotificationsPlugin].
@pragma('vm:entry-point')
Future<void> notificationResponseInBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final payload = response.payload;
  if (actionId == null || payload == null) return;
  if (actionId != kReplyActionId && actionId != kMarkReadActionId) return;

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final taken = await handOffToMainIsolate({
    'kind': 'action',
    'action': actionId,
    'payload': payload,
    'input': response.input,
  });
  if (taken) return;

  final standalone = await _StandaloneNotifications.open();
  await standalone.handler.onAction(
    actionId,
    jsonDecode(payload) as Map<String, dynamic>,
    input: response.input,
  );
}

/// Initialise le greffon pour les notifications de message. Le gestionnaire
/// des boutons est TOUJOURS passé : le greffon garde le dernier enregistré,
/// et l'oublier dans un isolat suffirait à rendre les boutons muets.
Future<void> initializeMessageNotificationsPlugin(
  FlutterLocalNotificationsPlugin plugin, {
  DarwinInitializationSettings? darwin,
  DidReceiveNotificationResponseCallback? onResponse,
}) {
  return plugin.initialize(
    InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: darwin ??
          const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
    ),
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse: notificationResponseInBackground,
  ).then((_) {});
}

/// Ce que l'application fournit d'ordinaire par Riverpod, reconstruit à la
/// main : cet isolat n'a ni conteneur ni contexte.
class _StandaloneNotifications {
  _StandaloneNotifications(this.handler, this.settings);

  final MessageNotificationHandler handler;
  final AppSettings settings;

  static Future<_StandaloneNotifications> open() async {
    final l = await loadStandaloneL();
    final plugin = FlutterLocalNotificationsPlugin();
    await initializeMessageNotificationsPlugin(plugin);
    final presenter = MessageNotificationPresenter(plugin: plugin, l: l);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(presenter.channel);

    final tokens = SecureTokenStorage();
    final api = ApiClient(tokenStorage: tokens, l: l);
    final messaging = MessagingRepository(
      apiClient: api,
      e2ee: E2EEService(apiClient: api),
      store: PokouMessageStore(),
    );
    final pending = PendingReplies();
    final handler = MessageNotificationHandler(
      presenter: presenter,
      api: api,
      messaging: messaging,
      myUserId: await _myUserId(tokens),
      // Une réponse privée attend l'application — voir
      // MessageNotificationHandler.
      sendDirect: (recipientId, text) async {
        await pending.add(recipientId, text);
        return false;
      },
    );
    return _StandaloneNotifications(handler, await _settings());
  }

  static Future<int?> _myUserId(SecureTokenStorage tokens) async {
    try {
      final raw = await tokens.readProfile();
      if (raw == null) return null;
      return (jsonDecode(raw) as Map<String, dynamic>)['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<AppSettings> _settings() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: 'pokou_app_settings');
      if (raw == null) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }
}
