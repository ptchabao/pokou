import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/sync/offline_list.dart';

/// Ce que `offlineList` promet aux écrans qui s'en servent : la liste reste
/// là quand le réseau part, et SEULEMENT dans ce cas.
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

  Stream<List<String>> run(
    Future<List<dynamic>> Function() fetch, {
    String scope = 'test',
  }) {
    return offlineList<String>(
      store: store,
      scope: scope,
      fetch: fetch,
      parse: (json) => json['name'] as String,
    );
  }

  test(
    'une réponse reçue est rendue, et gardée pour la prochaine coupure',
    () async {
      final fresh = await run(
        () async => [
          {'name': 'Kodjo'},
          {'name': 'Awa'},
        ],
      ).first;
      expect(fresh, ['Kodjo', 'Awa']);

      // L'écriture du cache n'est pas attendue par `offlineList` — elle a lieu
      // pendant que l'écran s'affiche. On laisse la boucle d'événements la
      // terminer avant de relire.
      await Future<void>.delayed(Duration.zero);

      final offline = await run(
        () async => throw NetworkException('coupure'),
      ).first;
      expect(
        offline,
        ['Kodjo', 'Awa'],
        reason: 'la dernière liste connue doit répondre à la place du réseau',
      );
    },
  );

  test('sans rien en cache, la coupure remonte telle quelle', () async {
    // « Je ne sais pas » et « vous n'avez rien » demandent deux écrans
    // différents : rendre une liste vide ici afficherait le second à la
    // place du premier.
    await expectLater(
      run(() async => throw NetworkException('coupure')).toList(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('une erreur du serveur ne sert jamais le cache', () async {
    await run(
      () async => [
        {'name': 'Kodjo'},
      ],
    ).first;
    await Future<void>.delayed(Duration.zero);

    // Un 403 est une RÉPONSE, pas une absence de réseau. Resservir du cache
    // dessus masquerait une vraie panne — un compte suspendu continuerait
    // d'afficher ses données comme si de rien n'était.
    await expectLater(
      run(() async => throw ApiException(403, 'interdit')).toList(),
      throwsA(isA<ApiException>()),
    );
  });

  test('a server outage keeps the local list visible', () async {
    await run(() async => [
      {'name': 'Kodjo'}
    ]).first;
    await Future<void>.delayed(Duration.zero);

    expect(
      await run(
        () async => throw ApiException(503, 'serveur indisponible'),
      ).last,
      ['Kodjo'],
    );
  });

  test('chaque écran a son propre cache', () async {
    await run(
      () async => [
        {'name': 'Kodjo'},
      ],
      scope: 'contacts',
    ).first;
    await run(
      () async => [
        {'name': 'Marché de Lomé'},
      ],
      scope: 'communities',
    ).first;
    await Future<void>.delayed(Duration.zero);

    expect(
      await run(
        () async => throw NetworkException('coupure'),
        scope: 'contacts',
      ).first,
      ['Kodjo'],
    );
    expect(
      await run(
        () async => throw NetworkException('coupure'),
        scope: 'communities',
      ).first,
      ['Marché de Lomé'],
    );
  });

  test('emits cached data before the online refresh completes', () async {
    await run(
      () async => [
        {'name': 'local'},
      ],
    ).first;
    await Future<void>.delayed(Duration.zero);

    final response = Completer<List<dynamic>>();
    final firstValue = Completer<List<String>>();
    final refreshedValue = Completer<List<String>>();
    var emissions = 0;
    final subscription = run(() => response.future).listen((value) {
      if (emissions++ == 0) {
        firstValue.complete(value);
      } else {
        refreshedValue.complete(value);
      }
    });

    expect(await firstValue.future, ['local']);
    response.complete([
      {'name': 'serveur'},
    ]);
    expect(await refreshedValue.future, ['serveur']);
    await subscription.cancel();
  });
}
