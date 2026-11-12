import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/crypto/group_sender_keys.dart';
import 'package:pokou/core/crypto/undecryptable.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/groups/data/group_model.dart';
import 'package:pokou/features/groups/data/group_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Un message de groupe ne s'ouvre qu'UNE fois, et il arrive par plusieurs
// chemins (temps réel, notification, chargement de la conversation).
//
// En production (11 novembre 2026), dès que les notifications ont
// fonctionné, CHAQUE message de groupe partait en re-livraison : la
// notification rouvrait un chiffré que le temps réel venait d'ouvrir,
// échouait, et demandait à l'expéditeur de le renvoyer.

void main() {
  const groupId = 1, epoch = 4, sender = 2, me = 5;
  late Database db;
  late PokouMessageStore store;
  late GroupSenderKeys receiverKeys;
  late GroupRepository receiver;
  late GroupSenderKeys senderKeys;
  late List<String> reports;
  late StreamSubscription<({String kind, String messageId})> subscription;

  final group = Group.fromJson({
    'id': groupId,
    'name': 'Famille',
    'created_by': sender,
    'crypto_epoch': epoch,
  });

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    GroupRepository.openedElsewhereWait = const Duration(milliseconds: 150);
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
    final api = ApiClient(baseUrl: 'https://unused');
    receiverKeys = GroupSenderKeys(store: InMemorySenderKeyStore());
    receiver = GroupRepository(
      apiClient: api,
      e2ee: E2EEService(apiClient: api),
      senderKeys: receiverKeys,
      store: store,
    );
    senderKeys = GroupSenderKeys(store: InMemorySenderKeyStore());
    await receiverKeys.acceptDistribution(
      groupId: groupId,
      epoch: epoch,
      senderId: sender,
      distribution: await senderKeys.createDistribution(
        groupId: groupId,
        epoch: epoch,
        senderId: sender,
      ),
    );
    reports = [];
    subscription = undecryptableReports.listen(
      (report) => reports.add(report.messageId),
    );
  });

  tearDown(() async {
    await subscription.cancel();
    store.dispose();
    await db.close();
  });

  Future<GroupMessage> incoming(String id, String text) async =>
      GroupMessage.fromJson({
        'id': id,
        'group_id': groupId,
        'sender_id': sender,
        'sender_name': 'Awa',
        'message_type': 'TEXT',
        'encryption': 'sender-key-v1',
        'crypto_epoch': epoch,
        'ciphertext': await senderKeys.encrypt(
          groupId: groupId,
          epoch: epoch,
          senderId: sender,
          plaintext: '{"content":"$text"}',
        ),
        'created_at': '2026-11-11T16:45:18',
      });

  test('the notification reopening a message the live feed just opened '
      'gets its text, and asks for no redelivery', () async {
    final message = await incoming('m1', 'On se voit à 18 h');

    // Le temps réel l'ouvre et a fini…
    final first = await receiver.decryptIncoming(group, message);
    expect(first.content, 'On se voit à 18 h');

    // …puis la notification, qui avait regardé le cache AVANT, arrive.
    final second = await receiver.decryptMessages(group, [message], me);
    expect(second.single.isEncrypted, isFalse);
    expect(second.single.content, 'On se voit à 18 h');

    await Future<void>.delayed(Duration.zero);
    expect(reports, isEmpty);
  });

  test('a message opened by the notification isolate a moment ago is read '
      'from the cache instead of being declared unreadable', () async {
    final message = await incoming('m2', 'Bien reçu');

    // L'autre isolat consomme la clé…
    final clear = await receiverKeys.decrypt(
      groupId: groupId,
      epoch: epoch,
      senderId: sender,
      ciphertext: message.ciphertext!,
    );
    // …et range le clair pendant que nous échouons à rouvrir le chiffré.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 60), () async {
        await store.saveGroup([receiver.resolveGroupBody(message, clear)]);
      }),
    );

    final opened = await receiver.decryptIncoming(group, message);
    expect(opened.content, 'Bien reçu');
    await Future<void>.delayed(Duration.zero);
    expect(reports, isEmpty);
  });

  test(
    'a message that truly cannot be opened still asks for redelivery',
    () async {
      final message = await incoming('m3', 'Perdu');
      await receiverKeys.decrypt(
        groupId: groupId,
        epoch: epoch,
        senderId: sender,
        ciphertext: message.ciphertext!,
      );

      final opened = await receiver.decryptIncoming(group, message);
      expect(opened.isEncrypted, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(reports, ['m3']);
    },
  );
}
