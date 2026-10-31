import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/features/chat/data/chat_local_store.dart';
import 'package:pokou/features/chat/data/chat_message_model.dart';

void main() {
  late ChatLocalStore store;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // Each test gets its own isolated in-memory database — sqflite treats
    // a bare `inMemoryDatabasePath` as a singleton connection by default,
    // so reusing that path across tests would leak the schema/rows from
    // one test into the next.
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monitor_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    store = ChatLocalStore(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'inserted messages are returned in insertion order, scoped to their monitor',
    () async {
      await store.insert(
        ChatMessage(
          monitorId: 1,
          role: ChatRole.user,
          content: 'a',
          createdAt: DateTime.now(),
        ),
      );
      await store.insert(
        ChatMessage(
          monitorId: 1,
          role: ChatRole.assistant,
          content: 'b',
          createdAt: DateTime.now(),
        ),
      );
      await store.insert(
        ChatMessage(
          monitorId: 2,
          role: ChatRole.user,
          content: 'other monitor',
          createdAt: DateTime.now(),
        ),
      );

      final history = await store.forMonitor(1);

      expect(history.map((m) => m.content), ['a', 'b']);
    },
  );

  test('insert assigns an auto-incrementing id', () async {
    final first = await store.insert(
      ChatMessage(
        monitorId: 1,
        role: ChatRole.user,
        content: 'a',
        createdAt: DateTime.now(),
      ),
    );
    final second = await store.insert(
      ChatMessage(
        monitorId: 1,
        role: ChatRole.user,
        content: 'b',
        createdAt: DateTime.now(),
      ),
    );

    expect(second.id, greaterThan(first.id!));
  });
}
