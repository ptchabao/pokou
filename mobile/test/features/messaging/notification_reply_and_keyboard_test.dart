import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/widgets/keyboard_height.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Retours testeurs (26 novembre 2026) :
// - le panneau emoji était plus bas qu'un vrai clavier ;
// - une réponse écrite depuis une notification n'apparaissait pas dans la
//   discussion.

DirectMessage _reply() => DirectMessage(
  id: 'srv-42',
  senderId: 1,
  recipientId: 2,
  messageType: 'TEXT',
  content: 'Je réponds depuis la notification',
  mediaAssetId: null,
  media: null,
  status: DirectMessageStatus.sent,
  createdAt: DateTime.utc(2026, 11, 26, 21),
);

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'une réponse envoyée hors de l\'écran est annoncée aux conversations',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await PokouMessageStore.createSchema(db);
      final store = PokouMessageStore(database: db);
      final seen = <OutboxUpdate>[];
      final sub = store.updates.listen(seen.add);

      final reply = _reply();
      await store.saveDirect([reply]);
      store.announceSent(direct: reply);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1));
      expect(
        seen.single.localId,
        isEmpty,
        reason: 'rien à remplacer : on ajoute',
      );
      expect(seen.single.direct?.id, 'srv-42');
      expect(
        (await store.directById('srv-42'))?.content,
        'Je réponds depuis la notification',
      );
      await sub.cancel();
      store.dispose();
      await db.close();
    },
  );

  group('hauteur du panneau emoji', () {
    setUp(KeyboardHeight.reset);

    testWidgets('sans clavier vu : une estimation réaliste, pas 280', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      tester.view.padding = const FakeViewPadding(
        bottom: 132,
      ); // barre de 48 dp
      addTearDown(tester.view.reset);
      late double height;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              height = KeyboardHeight.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        height,
        greaterThan(320),
        reason: '≈ 38 % de l\'écran + la barre du bas',
      );
    });

    testWidgets(
      'le vrai clavier, une fois vu, vaut pour toute l\'application',
      (tester) async {
        KeyboardHeight.remember(366);
        KeyboardHeight.remember(40); // un encart minuscule n'est pas un clavier
        late double height;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                height = KeyboardHeight.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(height, 366);
      },
    );
  });
}
