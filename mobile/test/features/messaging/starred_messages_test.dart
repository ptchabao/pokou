import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/providers.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/groups/data/group_model.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/starred/starred_messages.dart';
import 'package:pokou/l10n/app_localizations.dart';

DirectMessage _direct(String id, {int senderId = 2, String? content}) =>
    DirectMessage(
      id: id,
      senderId: senderId,
      recipientId: senderId == 1 ? 2 : 1,
      messageType: 'TEXT',
      content: content,
      mediaAssetId: null,
      media: null,
      status: DirectMessageStatus.sent,
      createdAt: DateTime.utc(2026, 11, 18, 10),
    );

GroupMessage _group(String id, {String content = 'réunion samedi'}) =>
    GroupMessage(
      id: id,
      groupId: 7,
      senderId: 3,
      senderName: 'Kodjo',
      messageType: 'TEXT',
      content: content,
      mediaAssetId: null,
      media: null,
      createdAt: DateTime.utc(2026, 11, 18, 11),
    );

void main() {
  late PokouMessageStore store;
  late Database db;

  setUpAll(sqfliteFfiInit);

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

  group('stockage local des importants', () {
    test('marquer, relire, retirer', () async {
      await store.saveDirect([_direct('d1', content: 'devis 250000 FCFA')]);
      await store.saveGroup([_group('g1')]);
      await store.setStarred(
        messageId: 'd1',
        scope: StarScope.direct,
        conversationId: 2,
        conversationName: 'Ama',
        starred: true,
      );
      await store.setStarred(
        messageId: 'g1',
        scope: StarScope.group,
        conversationId: 7,
        conversationName: 'Marché',
        starred: true,
      );

      expect(await store.starredIds(StarScope.direct, 2), {'d1'});
      expect(await store.starredIds(StarScope.group, 7), {'g1'});
      expect(await store.starredIds(StarScope.group, 8), isEmpty);

      final all = await store.starredMessages();
      expect(all.map((e) => e.messageId).toSet(), {'d1', 'g1'});
      final direct = all.firstWhere((e) => e.messageId == 'd1');
      expect(direct.direct?.content, 'devis 250000 FCFA');
      expect(direct.conversationName, 'Ama');

      final onlyGroup = await store.starredMessages(
        scope: StarScope.group,
        conversationId: 7,
      );
      expect(onlyGroup.single.group?.senderName, 'Kodjo');

      await store.setStarred(
        messageId: 'd1',
        scope: StarScope.direct,
        conversationId: 2,
        conversationName: 'Ama',
        starred: false,
      );
      expect(await store.starredIds(StarScope.direct, 2), isEmpty);
    });

    test('un message supprimé ne figure plus parmi les importants', () async {
      await store.saveDirect([_direct('d1', content: 'à garder')]);
      await store.setStarred(
        messageId: 'd1',
        scope: StarScope.direct,
        conversationId: 2,
        conversationName: 'Ama',
        starred: true,
      );
      await store.deleteDirect('d1');
      expect(await store.starredMessages(), isEmpty);
    });

    test('la déconnexion efface les importants', () async {
      await store.setStarred(
        messageId: 'd1',
        scope: StarScope.direct,
        conversationId: 2,
        conversationName: 'Ama',
        starred: true,
      );
      await store.clear();
      expect(await store.starredIds(StarScope.direct, 2), isEmpty);
    });
  });

  testWidgets('StarredMark porte son libellé d\'accessibilité', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const Scaffold(body: StarredMark(color: Colors.grey)),
      ),
    );
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Important'), findsOneWidget);
  });

  testWidgets('l\'écran liste les messages marqués, et en retire', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.saveDirect([
        _direct('d1', senderId: 1, content: 'rdv au marché'),
      ]);
      await store.saveGroup([_group('g1')]);
      await store.setStarred(
        messageId: 'd1',
        scope: StarScope.direct,
        conversationId: 2,
        conversationName: 'Ama',
        starred: true,
      );
      await store.setStarred(
        messageId: 'g1',
        scope: StarScope.group,
        conversationId: 7,
        conversationName: 'Marché',
        starred: true,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pokouMessageStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const StarredMessagesScreen(myUserId: 1),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages importants'), findsOneWidget);
    expect(find.text('rdv au marché'), findsOneWidget);
    expect(find.text('Toi · Ama'), findsOneWidget);
    expect(find.text('réunion samedi'), findsOneWidget);
    expect(find.text('Kodjo · Marché'), findsOneWidget);
    expect(find.text('Visible uniquement sur ce téléphone.'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer des importants').first);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.byTooltip('Retirer des importants'), findsOneWidget);
  });

  testWidgets('écran vide : il explique le geste', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pokouMessageStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const StarredMessagesScreen(
            myUserId: 1,
            scope: StarScope.direct,
            conversationId: 2,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun message important'), findsOneWidget);
  });
}
