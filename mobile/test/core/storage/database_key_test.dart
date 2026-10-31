import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/storage/database_key.dart';

/// La clé qui chiffre la base locale.
///
/// Le cache contenait les messages DÉCHIFFRÉS en clair sur le disque, y
/// compris ceux des conversations chiffrées de bout en bout : un téléphone
/// rooté ou une extraction forensique livrait tout l'historique, ce qui
/// vidait la garantie de son sens là où elle compte le plus.
///
/// Trois propriétés à tenir, et chacune correspond à une façon connue de
/// rater un chiffrement au repos : une clé écrite en dur, une clé
/// prévisible, une clé qui change à chaque lancement (donc une base qu'on ne
/// sait plus rouvrir).

class _MemoryStorage extends FlutterSecureStorage {
  const _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  late Map<String, String> keystore;
  late DatabaseKey key;

  setUp(() {
    keystore = {};
    key = DatabaseKey(storage: _MemoryStorage(keystore));
  });

  test('la clé n\'est pas écrite en dur : elle est TIRÉE au hasard', () async {
    // Une clé en dur serait la même sur tous les téléphones, donc lisible
    // par quiconque a ouvert l'APK une fois. C'est la façon la plus
    // fréquente de chiffrer une base pour rien.
    final premier = await DatabaseKey(storage: _MemoryStorage({})).read();
    final second = await DatabaseKey(storage: _MemoryStorage({})).read();

    expect(premier, isNot(second));
  });

  test('elle fait 32 octets — la taille d\'AES-256', () async {
    expect(base64.decode(await key.read()).length, DatabaseKey.keyBytes);
    expect(DatabaseKey.keyBytes, 32);
  });

  test('elle est STABLE : la même à chaque lancement', () async {
    // Une clé régénérée à chaque ouverture rendrait la base illisible dès le
    // second lancement — l'historique entier disparaîtrait à chaque
    // démarrage, sans erreur visible.
    final premier = await key.read();

    expect(await key.read(), premier);
    expect(await DatabaseKey(storage: _MemoryStorage(keystore)).read(), premier);
  });

  test('elle vit dans le Keystore, pas dans SQLite', () async {
    await key.read();

    expect(keystore.keys, contains(DatabaseKey.storageKey));
  });

  test('l\'effacer rend la base définitivement illisible', () async {
    // C'est la façon la plus sûre de détruire un historique : supprimer des
    // lignes laisse des traces récupérables dans les pages libérées, alors
    // qu'une clé perdue rend le fichier entier inexploitable.
    await key.read();
    await key.destroy();

    expect(keystore, isEmpty);
    expect(await key.exists(), isFalse);
  });

  test('`exists` distingue une première installation d\'une migration',
      () async {
    // Ce que regarde le magasin pour savoir s'il doit reprendre une base en
    // clair laissée par une version précédente.
    expect(await key.exists(), isFalse);
    await key.read();
    expect(await key.exists(), isTrue);
  });
}
