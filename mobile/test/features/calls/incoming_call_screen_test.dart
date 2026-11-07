import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/call_keys.dart';
import 'package:pokou/core/providers.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/core/ws/ws_client.dart';
import 'package:pokou/features/calls/data/call_repository.dart';
import 'package:pokou/features/calls/presentation/call_controller.dart';
import 'package:pokou/features/calls/presentation/incoming_call_screen.dart';
import 'package:pokou/features/calls/presentation/ringtone_player.dart';
import 'package:pokou/features/contacts/data/contact_model.dart';
import 'package:pokou/features/contacts/presentation/contacts_controller.dart';

/// Faux RingtonePlayer — compte les appels sans jamais toucher à un vrai
/// AudioPlayer (`implements`, pas `extends` : aucun `AudioPlayer()` construit
/// en douce par le constructeur parent).
class _FakeRingtonePlayer implements RingtonePlayer {
  int ringtoneCalls = 0;
  int ringbackCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> playRingtone() async => ringtoneCalls++;

  @override
  Future<void> playRingback() async => ringbackCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _FakeCallRepository extends CallRepository {
  _FakeCallRepository({this.joinCallError})
    : super(apiClient: ApiClient(baseUrl: 'https://unused'));

  /// Si renseignée, `joinCall` échoue avec cette erreur — simule un accept
  /// qui ne peut pas aboutir, sans jamais pousser un vrai CallScreen (qui
  /// ouvrirait une connexion LiveKit réelle, hors de propos pour ce test).
  final Object? joinCallError;
  Completer<CallToken>? joinCallCompleter;
  String? signalledEvent;

  int? joinedWithInviter;

  @override
  Future<CallToken> joinCall(String room, {int? inviter}) async {
    joinedWithInviter = inviter;
    if (joinCallCompleter != null) return joinCallCompleter!.future;
    if (joinCallError != null) throw joinCallError!;
    return const CallToken(
      room: 'pokou-call-test',
      token: 'jwt',
      livekitUrl: 'wss://example.livekit.cloud',
    );
  }

  @override
  Future<void> signal({
    required String room,
    required int targetUserId,
    required String event,
  }) async {
    signalledEvent = event;
  }
}

Widget _buildApp({
  required _FakeRingtonePlayer ringtonePlayer,
  required _FakeCallRepository repository,
}) {
  return ProviderScope(
    overrides: [
      callRepositoryProvider.overrideWithValue(repository),
      // Jamais connecté (voir _listenForCancellation) : un WsClient réel mais
      // inerte évite de simuler le WebSocket pour ce test.
      wsClientProvider.overrideWithValue(
        WsClient(
          baseWsUrl: 'wss://unused',
          tokenStorage: SecureTokenStorage(),
          apiClient: ApiClient(baseUrl: 'https://unused'),
        ),
      ),
      contactsProvider.overrideWith((ref) => Stream.value(<PokouContact>[])),
    ],
    child: MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('fr'),
      home: IncomingCallScreen(
        room: 'pokou-call-test',
        fromUserId: 42,
        callType: '1:1',
        isVideo: false,
        ringtonePlayer: ringtonePlayer,
      ),
    ),
  );
}

void main() {
  setUp(() {
    IncomingCallScreen.debugCallScreenOverride = (pending) {
      pending.ignore();
      return const Scaffold(body: Text('ecran-appel'));
    };
  });
  tearDown(() => IncomingCallScreen.debugCallScreenOverride = null);

  group('IncomingCallScreen — RingtonePlayer', () {
    testWidgets('joue la sonnerie en boucle dès l’ouverture de l’écran', (
      tester,
    ) async {
      final player = _FakeRingtonePlayer();
      await tester.pumpWidget(
        _buildApp(ringtonePlayer: player, repository: _FakeCallRepository()),
      );

      expect(player.ringtoneCalls, 1);
      expect(player.stopCalls, 0);
    });

    testWidgets('refuser l’appel arrête la sonnerie', (tester) async {
      final player = _FakeRingtonePlayer();
      final repo = _FakeCallRepository();
      await tester.pumpWidget(
        _buildApp(ringtonePlayer: player, repository: repo),
      );

      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pump();

      expect(player.stopCalls, greaterThanOrEqualTo(1));
      expect(repo.signalledEvent, 'decline');
    });

    testWidgets(
      'accepter l’appel arrête la sonnerie immédiatement (avant même la navigation)',
      (tester) async {
        final player = _FakeRingtonePlayer();
        // joinCall échoue volontairement : on vérifie que le ringtone est déjà
        // coupé au moment où l'utilisateur répond, indépendamment de l'issue du
        // réseau — pas de vrai CallScreen/LiveKit engagé par ce test.
        final repo = _FakeCallRepository(joinCallError: Exception('boom'));
        await tester.pumpWidget(
          _buildApp(ringtonePlayer: player, repository: repo),
        );

        await tester.tap(find.byIcon(Icons.call));
        await tester.pump();

        expect(player.stopCalls, greaterThanOrEqualTo(1));
        // L'écran d'appel s'ouvre AUSSITÔT (« Connexion… »), sans attendre
        // la réponse du serveur : l'écran de sonnerie ne reste plus figé.
        expect(find.text('ecran-appel', skipOffstage: false), findsOneWidget);
      },
    );

    testWidgets('accepter affiche un indicateur pendant la requête réseau', (
      tester,
    ) async {
      final player = _FakeRingtonePlayer();
      final repo = _FakeCallRepository()
        ..joinCallCompleter = Completer<CallToken>();
      await tester.pumpWidget(
        _buildApp(ringtonePlayer: player, repository: repo),
      );

      await tester.tap(find.byIcon(Icons.call));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.call), findsNothing);

      repo.joinCallCompleter!.completeError(Exception('offline'));
      await tester.pump();
      await tester.pump();
    });

    testWidgets(
      'une clé d’appel illisible prévient l’appelant au lieu de le laisser sonner',
      (tester) async {
        final player = _FakeRingtonePlayer();
        final repo = _FakeCallRepository(
          joinCallError: const CallEncryptionException('clé illisible'),
        );
        await tester.pumpWidget(
          _buildApp(ringtonePlayer: player, repository: repo),
        );

        await tester.tap(find.byIcon(Icons.call));
        await tester.pump();
        await tester.pump();

        // La clé est ouverte avec la session de CELUI qui sonne, et de lui seul.
        expect(repo.joinedWithInviter, 42);
        expect(repo.signalledEvent, 'decline');
      },
    );

    testWidgets('fermer l’écran arrête la sonnerie et libère le lecteur', (
      tester,
    ) async {
      final player = _FakeRingtonePlayer();
      await tester.pumpWidget(
        _buildApp(ringtonePlayer: player, repository: _FakeCallRepository()),
      );
      expect(player.ringtoneCalls, 1);

      // Remplace tout l'arbre de widgets : force le dispose() de l'écran
      // d'appel entrant, comme le ferait une navigation qui le retire.
      await tester.pumpWidget(const SizedBox.shrink());

      expect(player.stopCalls, greaterThanOrEqualTo(1));
      // Un lecteur INJECTÉ (celui du test) n'appartient pas à l'écran : il ne
      // doit pas le libérer à notre place (voir dispose() dans
      // incoming_call_screen.dart).
      expect(player.disposeCalls, 0);
    });
  });
}
