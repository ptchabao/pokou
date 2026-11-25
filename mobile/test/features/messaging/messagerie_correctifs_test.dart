// Correctifs de la messagerie signalés par l'équipe de test : chaque test
// reproduit le défaut tel qu'il se produisait, puis vérifie le correctif.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/media_cipher.dart';
import 'package:pokou/core/media/media_repository.dart';
import 'package:pokou/core/platform/secure_screen.dart';
import 'package:pokou/core/providers.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/text/emoji_only.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';
import 'package:pokou/features/messaging/presentation/message_links.dart';
import 'package:pokou/features/messaging/presentation/messaging_controller.dart';
import 'package:pokou/features/messaging/presentation/poll_bubble.dart';
import 'package:pokou/features/messaging/presentation/view_once.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';

import '../../helpers/localized_harness.dart';

final _key = MediaKey(
  key: Uint8List(32),
  nonce: Uint8List(12),
  digest: Uint8List(32),
  mimeType: 'image/jpeg',
  filename: 'photo.jpg',
  size: 10,
  assetId: 42,
);

DirectMessage _photo({
  String id = 'srv-1',
  bool encrypted = false,
  MediaKey? mediaKey,
  bool viewOnce = false,
  DateTime? viewedAt,
  DateTime? createdAt,
  List<MessageReactionSummary> reactions = const [],
}) => DirectMessage(
  id: id,
  senderId: 1,
  recipientId: 2,
  messageType: 'IMAGE',
  content: encrypted ? null : 'légende',
  encryption: encrypted ? 'v1' : null,
  ciphertext: encrypted ? 'chiffre' : null,
  envelope: encrypted ? const {'sid': 's'} : null,
  mediaAssetId: 42,
  media: const MediaMeta(
    id: 42,
    mimeType: 'image/jpeg',
    sizeBytes: 10,
    originalFilename: 'photo.jpg',
  ),
  mediaKey: mediaKey,
  status: DirectMessageStatus.sent,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 20, 10),
  viewOnce: viewOnce,
  viewedAt: viewedAt,
  reactions: reactions,
);

DirectMessage _text(String id, DateTime at) => DirectMessage(
  id: id,
  senderId: 1,
  recipientId: 2,
  messageType: 'TEXT',
  content: 'message $id',
  mediaAssetId: null,
  media: null,
  status: DirectMessageStatus.sent,
  createdAt: at,
);

class _FakeMedia extends MediaRepository {
  _FakeMedia(this.file)
    : super(apiClient: ApiClient(baseUrl: 'https://unused'));
  final File file;
  int resolved = 0;
  int forgotten = 0;

  @override
  Future<File> resolveLocalFile(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
    MediaKey? mediaKey,
  }) async {
    resolved++;
    return file;
  }

  @override
  Future<void> oublier(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
  }) async => forgotten++;
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late PokouMessageStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
  });
  tearDown(() async {
    store.dispose();
    await db.close();
  });

  group('photos : la copie ouverte de l\'expéditeur survit', () {
    test(
      'un historique rechargé pendant l\'envoi n\'écrase plus la copie ouverte',
      () async {
        // L'expéditeur : la ligne provisoire, puis la confirmation ouverte,
        // pendant qu'un rechargement range la copie CHIFFRÉE du serveur.
        final opened = _photo(mediaKey: _key);
        final serverCopy = _photo(encrypted: true);
        await Future.wait([
          store.saveDirect([serverCopy]),
          store.confirmDirect('local-1', opened),
        ]);
        final kept = await store.directById('srv-1');
        expect(kept!.isEncrypted, isFalse);
        expect(kept.mediaKey, isNotNull);
      },
    );

    test('une copie en clair sans clé ne fait pas perdre la clé', () async {
      await store.saveDirect([_photo(mediaKey: _key)]);
      await store.saveDirect([_photo()]);
      expect((await store.directById('srv-1'))!.mediaKey, isNotNull);
    });

    test('la bulle confirmée remplace la provisoire sans doublon', () {
      final provisional = _photo(id: 'local-1');
      final stale = _photo(encrypted: true);
      final confirmed = _photo(mediaKey: _key);
      final result = replaceConfirmed(
        [provisional, stale],
        'local-1',
        confirmed,
      );
      expect(result, hasLength(1));
      expect(result.single.mediaKey, isNotNull);
    });
  });

  group('historique : plus de messages qui disparaissent', () {
    test('un message de la même seconde que le bord de page reste', () async {
      final at = DateTime.utc(2026, 11, 20, 10);
      await store.saveDirect([_text('a', at), _text('b', at)]);
      // La page du serveur s'arrête au milieu de la rafale : `b` n'y est
      // pas, mais il n'a pas été supprimé pour autant.
      await store.reconcileDirect(
        myUserId: 1,
        contactUserId: 2,
        serverMessages: [_text('a', at)],
      );
      final ids = (await store.directConversation(
        myUserId: 1,
        contactUserId: 2,
      )).messages.map((m) => m.id);
      expect(ids, containsAll(['a', 'b']));
    });

    test('les dates comparées en valeur, pas en texte', () {
      // « …00.123Z » < « …00.123400Z » en valeur, mais pas en texte.
      final ids = PokouMessageStore.staleIds(
        [
          {
            'id': 'old',
            'created_at': '2026-11-20T10:00:00.123Z',
            'payload': '{}',
          },
          {
            'id': 'gone',
            'created_at': '2026-11-20T11:00:00.000Z',
            'payload': '{}',
          },
        ],
        keptIds: const {},
        oldest: DateTime.parse('2026-11-20T10:00:00.123400Z'),
      );
      expect(ids, ['gone']);
    });

    test('un message illisible ne fait plus échouer la page', () {
      final parsed = parseHistoryItems([
        _text('ok', DateTime.utc(2026)).toJson(),
        {'id': 'cassé'},
      ]);
      expect(parsed.map((m) => m.id), ['ok']);
    });

    test('la réaction rattrapée hors ligne est écrite dans le cache', () async {
      await store.saveDirect([_text('m', DateTime.utc(2026))]);
      final reacted = DirectMessage.fromJson({
        ..._text('m', DateTime.utc(2026)).toJson(),
        'reactions': [
          {
            'emoji': '❤️',
            'count': 1,
            'user_ids': [2],
            'mine': false,
          },
        ],
      });
      await store.saveSyncBatch(
        events: [
          SyncInboxEvent(
            id: 'e1',
            type: 'message:reaction',
            payload: {'message': reacted.toJson()},
          ),
        ],
        cursor: 'c1',
        scope: 'direct',
      );
      final event = (await store.pendingSyncEvents(limit: 10)).single;
      expect(
        await store.applySyncEvent(event: event, directMessage: reacted),
        isTrue,
      );
      final kept = await store.directById('m');
      expect(kept!.reactions.single.emoji, '❤️');
      expect(kept.content, 'message m');
    });
  });

  group('vue unique', () {
    test(
      'ouverte une fois, l\'état survit à un historique plus ancien',
      () async {
        await store.saveDirect([_photo(viewOnce: true)]);
        await store.markDirectViewed('srv-1', DateTime.utc(2026, 11, 20, 11));
        // Le serveur ne l'a pas encore appris (hors ligne) : sa copie dit
        // « jamais vue ». Elle ne doit pas la rendre à nouveau ouvrable.
        await store.saveDirect([_photo(viewOnce: true)]);
        expect((await store.directById('srv-1'))!.isViewed, isTrue);
      },
    );

    Future<_FakeMedia> pump(
      WidgetTester tester, {
      required bool isMine,
      required bool opened,
      required Future<bool> Function() onOpen,
    }) async {
      final file = File('${Directory.systemTemp.path}/vue-unique-test.jpg')
        ..writeAsBytesSync(const [0xff, 0xd8, 0xff]);
      final media = _FakeMedia(file);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaRepositoryProvider.overrideWithValue(media)],
          child: localizedHarness(
            ViewOnceBubble(
              media: _photo().media!,
              isVideo: false,
              isMine: isMine,
              opened: opened,
              onOpen: onOpen,
            ),
          ),
        ),
      );
      return media;
    }

    testWidgets('discrète : une pastille « 1 · Photo », jamais l\'image', (
      tester,
    ) async {
      await pump(tester, isMine: true, opened: false, onOpen: () async => true);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      // Chez l'expéditeur, toucher ne fait rien.
      await tester.tap(find.byKey(const ValueKey('view-once-bubble')));
      await tester.pumpAndSettle();
      expect(find.byType(ViewOnceViewer), findsNothing);
    });

    testWidgets('deux appuis : une seule ouverture, puis « Ouvert »', (
      tester,
    ) async {
      final calls = <String>[];
      SecureScreen.debugReset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.pokou.pokou/secure'),
            (call) async {
              calls.add('${call.method}:${call.arguments}');
              return null;
            },
          );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var opens = 0;
      final media = await pump(
        tester,
        isMine: false,
        opened: false,
        onOpen: () async => ++opens == 1,
      );
      await tester.tap(find.byKey(const ValueKey('view-once-bubble')));
      await tester.pumpAndSettle();
      expect(find.byType(ViewOnceViewer), findsOneWidget);
      // Capture d'écran interdite pendant l'affichage.
      expect(calls, contains('setSecure:true'));
      // Aucune action : ni transférer, ni enregistrer, ni partager.
      expect(find.byIcon(Icons.forward), findsNothing);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsNothing);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(calls.last, 'setSecure:false');
      expect(find.text('Ouvert'), findsOneWidget);
      // La copie en clair est effacée de l'appareil.
      expect(media.forgotten, 1);

      await tester.tap(find.byKey(const ValueKey('view-once-bubble')));
      await tester.pumpAndSettle();
      expect(find.byType(ViewOnceViewer), findsNothing);
      expect(opens, 1);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('sondages', () {
    PollData poll({DateTime? locksAt, bool mine = true}) => PollData(
      id: 'p',
      question: 'On mange où ?',
      allowsMultiple: false,
      totalVoters: 1,
      myLocksAt: locksAt,
      options: [
        PollOptionData(
          id: 1,
          text: 'Ici',
          position: 0,
          voteCount: 1,
          voterIds: const [2],
          mine: mine,
        ),
        const PollOptionData(
          id: 2,
          text: 'Là',
          position: 1,
          voteCount: 0,
          voterIds: [],
          mine: false,
        ),
      ],
    );

    test('« Modifiable encore 12 min » puis « Réponse définitive »', () {
      final l = LFr();
      final now = DateTime.utc(2026, 11, 20, 10);
      expect(
        pollAnswerStatus(
          l,
          poll(locksAt: now.add(const Duration(minutes: 11, seconds: 30))),
          now,
        ),
        'Modifiable encore 12 min',
      );
      expect(
        pollAnswerStatus(
          l,
          poll(locksAt: now.subtract(const Duration(seconds: 1))),
          now,
        ),
        'Réponse définitive',
      );
      expect(pollAnswerStatus(l, poll(mine: false), now), isNull);
    });

    test('la fenêtre voyage avec le sondage, cache compris', () {
      final at = DateTime.utc(2026, 11, 20, 10, 15);
      final json = poll(locksAt: at).toJson();
      expect(PollData.fromJson(json).myLocksAt!.isAtSameMomentAs(at), isTrue);
    });

    testWidgets('une réponse définitive ne se change plus', (tester) async {
      var votes = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: localizedHarness(
            PollBubble(
              poll: poll(
                locksAt: DateTime.now().subtract(const Duration(minutes: 1)),
              ),
              onVoted: (_) {},
              castVote: (_) async {
                votes++;
                return poll();
              },
            ),
          ),
        ),
      );
      expect(find.text('Réponse définitive'), findsOneWidget);
      await tester.tap(find.text('Là'));
      await tester.pump();
      expect(votes, 0);
    });
  });

  group('emoji', () {
    test('une touche « 1️⃣ » seule s\'affiche en grand', () {
      expect(emojiOnlyCount('1️⃣'), 1);
      expect(emojiOnlyCount('12'), isNull);
    });

    test('« ❤ » sans sélecteur reçoit la présentation emoji', () {
      expect(withEmojiPresentation('je t\'❤'), 'je t\'❤️');
      expect(withEmojiPresentation('❤️ 😀 abc'), '❤️ 😀 abc');
    });

    test('un long message d\'emoji ne se replie plus sur un carré', () {
      final text = '😀' * 400;
      final collapsed = collapsedMessageText(text)!;
      // Aucune moitié d'emoji orpheline.
      final last = collapsed.codeUnitAt(collapsed.length - 1);
      expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
      expect(collapsed.runes.every((r) => r == 0x1F600), isTrue);
    });
  });
}
