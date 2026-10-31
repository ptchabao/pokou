import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/notifications/message_notification_handler.dart';
import 'package:pokou/core/notifications/message_notifications.dart';
import 'package:pokou/core/notifications/notification_policy.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Les notifications de message construites par l'appareil : une par
/// conversation, déroulée sur ses derniers messages, avec réponse et
/// « Marquer comme lu ».

class _Shown {
  _Shown(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String? title;
  final String? body;
  final NotificationDetails? details;
  final String? payload;

  AndroidNotificationDetails get android => details!.android!;
  List<Message> get lines =>
      (android.styleInformation as MessagingStyleInformation).messages!;
}

class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final Map<int, _Shown> visible = {};

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    visible[id] = _Shown(id, title, body, notificationDetails, payload);
  }

  @override
  Future<void> cancel(int id, {String? tag}) async => visible.remove(id);
}

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);
}

Map<String, dynamic> _directPush({String id = 'm1', String type = 'TEXT'}) => {
  'rich': '1',
  'type': 'message',
  'message_id': id,
  'sender_id': '8',
  'sender_name': 'Kodjo',
  'contact_user_id': '8',
  'contact_name': 'Kodjo',
  'message_type': type,
  'sent_at': '2026-10-05T10:00:00Z',
  'is_encrypted': '0',
};

/// Ce que rend GET /messages/by-id/{id}.
String _directJson(String content, {String id = 'm1'}) => jsonEncode({
  'id': id,
  'sender_id': 8,
  'recipient_id': 1,
  'message_type': 'TEXT',
  'content': content,
  'status': 'DELIVERED',
  'created_at': '2026-10-05T10:00:00',
});

Map<String, dynamic> _groupPush({String id = 'g1'}) => {
  'rich': '1',
  'type': 'group_message',
  'message_id': id,
  'sender_id': '9',
  'sender_name': 'Ama',
  'group_id': '5',
  'group_name': 'Équipe',
  'message_type': 'TEXT',
  'sent_at': '2026-10-05T10:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();
  final l = lookupL(const Locale('fr'));

  late Directory dir;
  late _FakePlugin plugin;
  late MessageNotificationPresenter presenter;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pokou_notif_');
    plugin = _FakePlugin();
    presenter = MessageNotificationPresenter(
      plugin: plugin,
      l: l,
      threads: NotificationThreads(file: File('${dir.path}/threads.json')),
    );
  });

  tearDown(() => dir.delete(recursive: true));

  ({MessageNotificationHandler handler, List<http.Request> requests}) handlerWith(
    Future<http.Response> Function(http.Request) respond, {
    Future<bool> Function(int, String)? sendDirect,
  }) {
    final requests = <http.Request>[];
    final api = ApiClient(
      tokenStorage: SecureTokenStorage(),
      baseUrl: 'https://pokou.test/api/v1',
      httpClient: MockClient((request) {
        requests.add(request);
        return respond(request);
      }),
    );
    final handler = MessageNotificationHandler(
      presenter: presenter,
      api: api,
      messaging: MessagingRepository(apiClient: api),
      sendDirect: sendDirect ?? (_, _) async => true,
    );
    return (handler: handler, requests: requests);
  }

  group('le push', () {
    test('seul le format enrichi est pris en charge ici', () {
      expect(MessagePush.tryParse({'type': 'message'}), isNull);
      final push = MessagePush.tryParse({
        ..._directPush(),
        'is_encrypted': '1',
        'envelope': '{"sid":"abc"}',
      })!;
      expect(push.conversationKey, 'contact:8');
      expect(push.envelope, {'sid': 'abc'});
      expect(MessagePush.tryParse(_groupPush())!.conversationKey, 'group:5');
    });

    test('l\'identifiant d\'une conversation ne dépend pas du lancement', () {
      // Une valeur FIXE : publiée par l'isolat de Firebase, la notification
      // est effacée par l'application. Le même calcul doit donner le même
      // nombre partout, toujours.
      expect(conversationNotificationKeyId('contact:8'), 1928258009);
      expect(
        conversationNotificationId(contactUserId: 8),
        conversationNotificationKeyId('contact:8'),
      );
      for (final key in ['contact:1', 'group:1', 'contact:2147483647']) {
        final id = conversationNotificationKeyId(key);
        expect(id, inInclusiveRange(0, kMessagesSummaryId - 1));
      }
    });
  });

  group('la notification d\'une conversation', () {
    test('se déroule sur ses messages et se range sous un résumé', () async {
      final h = handlerWith(
        (request) async => http.Response(
          _directJson('Message ${request.url.pathSegments.last}'),
          200,
        ),
      );
      for (final id in ['m1', 'm2']) {
        await h.handler.handle(
          MessagePush.tryParse(_directPush(id: id))!,
          presentation: NotificationPresentation.standard,
          withSound: true,
        );
      }
      final shown = plugin.visible[conversationNotificationKeyId('contact:8')]!;
      expect(shown.title, 'Kodjo');
      expect(shown.lines.map((m) => m.text), ['Message m1', 'Message m2']);
      expect(shown.android.groupKey, kMessagesGroupKey);
      expect(jsonDecode(shown.payload!)['contact_user_id'], '8');

      final summary = plugin.visible[kMessagesSummaryId]!;
      expect(summary.android.setAsGroupSummary, isTrue);
      expect(summary.body, contains('2 messages'));
    });

    test('« Nouveau message » d\'abord, puis son texte — sans resonner', () async {
      final h = handlerWith(
        (_) async => http.Response(_directJson('Le colis part demain'), 200),
      );
      await h.handler.handle(
        MessagePush.tryParse(_directPush())!,
        presentation: NotificationPresentation.standard,
        withSound: true,
        fallbackFirst: true,
      );
      final shown = plugin.visible[conversationNotificationKeyId('contact:8')]!;
      // Remplacé, pas ajouté : un seul message, une seule ligne.
      expect(shown.lines.map((m) => m.text), ['Le colis part demain']);
      expect(shown.android.onlyAlertOnce, isTrue);
    });

    test('un contenu introuvable laisse « Nouveau message »', () async {
      final h = handlerWith((_) async => http.Response('{}', 503));
      await h.handler.handle(
        MessagePush.tryParse(_directPush(type: 'IMAGE'))!,
        presentation: NotificationPresentation.standard,
        withSound: true,
        fallbackFirst: true,
      );
      final shown = plugin.visible[conversationNotificationKeyId('contact:8')]!;
      expect(shown.lines.single.text, l.notifPhoto);
    });

    test('ne garde que les derniers messages', () async {
      final h = handlerWith((_) async => http.Response(_directJson('x'), 200));
      for (var i = 0; i < 10; i++) {
        await h.handler.handle(
          MessagePush.tryParse({
            ..._directPush(id: 'm$i'),
            'sent_at': '2026-10-05T10:0$i:00Z',
          })!,
          presentation: NotificationPresentation.standard,
          withSound: true,
        );
      }
      final thread = await presenter.thread('contact:8');
      expect(thread!.lines.map((line) => line.messageId).first, 'm3');
      expect(thread.lines, hasLength(7));
    });

    test('rien pour la conversation qu\'on lit', () async {
      final h = handlerWith((_) async => http.Response('{}', 200));
      await h.handler.handle(
        MessagePush.tryParse(_directPush())!,
        presentation: NotificationPresentation.suppressed,
        withSound: true,
      );
      expect(plugin.visible, isEmpty);
      expect(h.requests, isEmpty);
    });
  });

  group('les boutons', () {
    test('« Marquer comme lu » accuse la lecture et efface', () async {
      final h = handlerWith((_) async => http.Response(_directJson('Salut'), 200));
      final push = MessagePush.tryParse(_directPush())!;
      await h.handler.handle(push, presentation: NotificationPresentation.standard, withSound: true);
      final payload = jsonDecode(plugin.visible[push.notificationId]!.payload!) as Map<String, dynamic>;

      await h.handler.onAction(kMarkReadActionId, payload);

      expect(h.requests.map((r) => r.url.path), contains('/api/v1/messages/m1/read'));
      expect(plugin.visible, isEmpty, reason: 'ni la conversation, ni le résumé');
    });

    test('une réponse de groupe part tout de suite et rejoint le fil', () async {
      final h = handlerWith((_) async => http.Response(jsonEncode({'content': 'On commence ?'}), 200));
      final push = MessagePush.tryParse(_groupPush())!;
      await h.handler.handle(push, presentation: NotificationPresentation.standard, withSound: true);
      final payload = jsonDecode(plugin.visible[push.notificationId]!.payload!) as Map<String, dynamic>;

      await h.handler.onAction(kReplyActionId, payload, input: 'J\'arrive');

      final sent = h.requests.where((r) => r.method == 'POST').single;
      expect(sent.url.path, '/api/v1/groups/5/messages');
      expect(jsonDecode(sent.body), {'content': 'J\'arrive'});
      final shown = plugin.visible[push.notificationId]!;
      expect(shown.lines.map((m) => m.text), ['On commence ?', 'J\'arrive']);
      expect(shown.lines.last.person?.key, 'me');
      expect(shown.android.onlyAlertOnce, isTrue);
    });

    test('une réponse privée hors de Pokou attend son ouverture, et le dit', () async {
      final queued = <String>[];
      final h = handlerWith(
        (_) async => http.Response(_directJson('Tu passes ?'), 200),
        sendDirect: (recipientId, text) async {
          queued.add('$recipientId:$text');
          return false;
        },
      );
      final push = MessagePush.tryParse(_directPush())!;
      await h.handler.handle(push, presentation: NotificationPresentation.standard, withSound: true);
      final payload = jsonDecode(plugin.visible[push.notificationId]!.payload!) as Map<String, dynamic>;

      await h.handler.onAction(kReplyActionId, payload, input: 'Oui');

      expect(queued, ['8:Oui']);
      // Pas encore partie : pas d'accusé de lecture non plus.
      expect(h.requests.where((r) => r.url.path.endsWith('/read')), isEmpty);
      expect(
        plugin.visible[push.notificationId]!.lines.last.text,
        'Oui · ${l.notifReplyQueued}',
      );
    });
  });

  group('les réponses en attente', () {
    test('partent dans l\'ordre, et s\'arrêtent au premier échec', () async {
      final pending = PendingReplies(file: File('${dir.path}/pending.json'));
      await pending.add(8, 'un');
      await pending.add(8, 'deux');
      await pending.add(8, 'trois');

      final sent = <String>[];
      expect(
        await pending.drain((_, text) async {
          if (text == 'deux') throw const SocketException('hors ligne');
          sent.add(text);
        }),
        1,
      );
      expect(sent, ['un']);

      // « deux » n'a pas sauté son tour.
      expect(await pending.drain((_, text) async => sent.add(text)), 2);
      expect(sent, ['un', 'deux', 'trois']);
      expect(await pending.drain((_, _) async {}), 0);
    });
  });
}
