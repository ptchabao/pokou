import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/features/messaging/pins/message_pins.dart';
import 'package:pokou/features/messaging/pins/pinned_banner.dart';
import 'package:pokou/l10n/app_localizations.dart';

import '../../helpers/localized_harness.dart';

class _FakeApi implements PinsApi {
  List<MessagePin> server = [];
  Object? failure;
  final calls = <String>[];

  @override
  Future<List<MessagePin>> list(PinScope scope) async => server;

  @override
  Future<List<MessagePin>> pin(
    PinScope scope,
    String messageId,
    int seconds,
  ) async {
    calls.add('pin:$messageId:$seconds');
    if (failure != null) throw failure!;
    server = [_pin(messageId), ...server].take(maxPins).toList();
    return server;
  }

  @override
  Future<List<MessagePin>> unpin(PinScope scope, String messageId) async {
    calls.add('unpin:$messageId');
    if (failure != null) throw failure!;
    server = server.where((p) => p.messageId != messageId).toList();
    return server;
  }
}

MessagePin _pin(String id, {Duration ttl = const Duration(days: 7)}) =>
    MessagePin(messageId: id, expiresAt: DateTime.now().toUtc().add(ttl));

Map<String, dynamic> _pinJson(String id) => {
  'message_id': id,
  'pinned_by': 1,
  'pinned_at': '2026-11-18T10:00:00',
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(days: 1))
      .toIso8601String()
      .replaceAll('Z', ''),
};

void main() {
  group('MessagePin', () {
    test('lit une date serveur sans fuseau comme UTC', () {
      final pin = MessagePin.fromJson({
        'message_id': 'm1',
        'expires_at': '2026-11-19T10:00:00',
      });
      expect(pin.expiresAt.isUtc, isTrue);
      expect(pin.expiresAt.hour, 10);
    });
  });

  group('PinsController', () {
    late _FakeApi api;
    late StreamController<Map<String, dynamic>> events;

    setUp(() {
      api = _FakeApi();
      events = StreamController<Map<String, dynamic>>.broadcast();
    });

    tearDown(() => events.close());

    PinsController make(PinScope scope) =>
        PinsController(scope: scope, api: api, events: events.stream);

    test('charge les épingles à l\'ouverture', () async {
      api.server = [_pin('a')];
      final controller = make(const PinScope.direct(2));
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPinned('a'), isTrue);
      controller.dispose();
    });

    test(
      'remplace la liste à l\'événement de SA discussion seulement',
      () async {
        final controller = make(const PinScope.direct(2));
        await Future<void>.delayed(Duration.zero);

        events.add({
          'type': 'message:pinned',
          'peer_id': 3,
          'pins': [_pinJson('autre')],
        });
        await Future<void>.delayed(Duration.zero);
        expect(controller.active, isEmpty);

        events.add({
          'type': 'message:pinned',
          'peer_id': 2,
          'pins': [_pinJson('x'), _pinJson('y')],
        });
        await Future<void>.delayed(Duration.zero);
        expect(controller.active.map((p) => p.messageId), ['x', 'y']);

        // Supprimé pour tous : l'épingle part avec le message.
        events.add({'type': 'message:deleted', 'message_id': 'x'});
        await Future<void>.delayed(Duration.zero);
        expect(controller.active.map((p) => p.messageId), ['y']);
        controller.dispose();
      },
    );

    test(
      'groupe : événement, suppression et suppression en mode preuve',
      () async {
        final controller = make(const PinScope.group(7));
        await Future<void>.delayed(Duration.zero);
        events.add({
          'type': 'group:message:pinned',
          'group_id': 7,
          'pins': [_pinJson('a'), _pinJson('b'), _pinJson('c')],
        });
        await Future<void>.delayed(Duration.zero);
        expect(controller.active, hasLength(3));

        events.add({
          'type': 'group:message:deleted',
          'group_id': 7,
          'message_id': 'a',
        });
        events.add({
          'type': 'group:message:edited',
          'group_id': 7,
          'message': {'id': 'b', 'deleted_at': '2026-11-18T10:00:00'},
        });
        events.add({
          'type': 'group:message:deleted',
          'group_id': 8,
          'message_id': 'c',
        });
        await Future<void>.delayed(Duration.zero);
        expect(controller.active.map((p) => p.messageId), ['c']);
        controller.dispose();
      },
    );

    test('une épingle échue n\'est plus active', () async {
      api.server = [
        _pin('vieux', ttl: const Duration(seconds: -1)),
        _pin('neuf'),
      ];
      final controller = make(const PinScope.direct(2));
      await Future<void>.delayed(Duration.zero);
      expect(controller.active.map((p) => p.messageId), ['neuf']);
      expect(controller.isPinned('vieux'), isFalse);
      controller.dispose();
    });

    test('épingler, désépingler, et refus 403 d\'un membre', () async {
      final controller = make(const PinScope.group(7));
      await Future<void>.delayed(Duration.zero);

      expect(await controller.pin('m1', 86400), PinOutcome.done);
      expect(controller.isPinned('m1'), isTrue);
      expect(api.calls, ['pin:m1:86400']);

      expect(await controller.unpin('m1'), PinOutcome.done);
      expect(controller.isPinned('m1'), isFalse);

      api.failure = ApiException(403, 'admins');
      expect(await controller.pin('m2', 86400), PinOutcome.forbidden);
      api.failure = NetworkException('hors ligne');
      expect(await controller.pin('m2', 86400), PinOutcome.failed);
      controller.dispose();
    });
  });

  group('messageExcerpt', () {
    test('le texte déchiffré, sinon la nature du message', () async {
      final l = await L.delegate.load(const Locale('fr'));
      expect(
        messageExcerpt(l, content: '  rdv\n18h ', messageType: 'TEXT'),
        'rdv 18h',
      );
      expect(messageExcerpt(l, content: null, messageType: 'IMAGE'), 'Photo');
      // Encore chiffré : jamais le chiffré, seulement « Message ».
      expect(
        messageExcerpt(l, content: 'b64==', messageType: 'TEXT', locked: true),
        'Message',
      );
    });
  });

  group('PinnedMessagesBanner', () {
    testWidgets('rien sans épingle', (tester) async {
      await tester.pumpWidget(
        localizedHarness(
          PinnedMessagesBanner(
            pins: const [],
            excerptFor: (_) => 'x',
            onOpen: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('toucher ouvre le message puis passe au suivant', (
      tester,
    ) async {
      final opened = <String>[];
      final texts = {'a': 'Réunion samedi', 'b': 'Photo'};
      await tester.pumpWidget(
        localizedHarness(
          PinnedMessagesBanner(
            pins: [_pin('a'), _pin('b')],
            excerptFor: (id) => texts[id]!,
            onOpen: opened.add,
          ),
        ),
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.text('Message épinglé'), findsOneWidget);
      expect(find.text('Réunion samedi'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.text('Réunion samedi'));
      await tester.pump();
      expect(opened, ['a']);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);

      await tester.tap(find.text('Photo'));
      await tester.pump();
      expect(opened, ['a', 'b']);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('une seule épingle : pas de compteur', (tester) async {
      await tester.pumpWidget(
        localizedHarness(
          PinnedMessagesBanner(
            pins: [_pin('a')],
            excerptFor: (_) => 'Seul',
            onOpen: (_) {},
          ),
        ),
      );
      expect(find.text('Seul'), findsOneWidget);
      expect(find.text('1/1'), findsNothing);
    });
  });
}
