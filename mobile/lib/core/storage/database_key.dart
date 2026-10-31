import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// La clé qui chiffre la base locale des messages.
///
/// Elle ne vit PAS dans le code, et c'est le seul point qui compte : une clé
/// écrite en dur serait la même sur tous les téléphones, donc lisible par
/// quiconque a ouvert l'APK une fois. Celle-ci est tirée au hasard à la
/// première ouverture, propre à l'appareil, et gardée dans le Keystore
/// Android / la Keychain iOS — le même magasin que les clés de chiffrement
/// de bout en bout, protégé par le matériel quand l'appareil le permet.
///
/// Ce que cela change : le cache contenait les messages DÉCHIFFRÉS en clair
/// sur le disque. `allowBackup="false"` empêchait qu'ils partent chez
/// Google, mais un téléphone rooté ou une extraction forensique livrait tout
/// l'historique — y compris celui des conversations chiffrées de bout en
/// bout, ce qui vidait la garantie de son sens là où elle compte le plus.
///
/// Ce que cela ne change pas, et qu'il faut dire : une fois l'application
/// déverrouillée et lancée, la clé est en mémoire. Le chiffrement au repos
/// protège un appareil ÉTEINT ou une copie du disque, pas un téléphone
/// déverrouillé entre les mains de quelqu'un d'autre. C'est le verrou
/// d'application qui couvre ce cas-là.
class DatabaseKey {
  const DatabaseKey({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const storageKey = 'pokou_db_key_v1';

  /// 32 octets — la taille de clé d'AES-256, ce que SQLCipher utilise.
  static const keyBytes = 32;

  /// La clé de cet appareil, créée au premier appel.
  ///
  /// `Random.secure()` et non `Random()` : le générateur ordinaire est
  /// prévisible à partir de sa graine, ce qui rendrait la clé devinable
  /// depuis l'heure de la première ouverture.
  Future<String> read() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final key = base64.encode(
      List<int>.generate(keyBytes, (_) => random.nextInt(256)),
    );
    await _storage.write(key: storageKey, value: key);
    return key;
  }

  /// Efface la clé — déconnexion, suppression de compte.
  ///
  /// Sans elle, la base chiffrée devient définitivement illisible : c'est
  /// une façon de détruire l'historique bien plus sûre que de supprimer des
  /// lignes, qui laissent des traces récupérables dans les pages libérées.
  Future<void> destroy() => _storage.delete(key: storageKey);

  /// Cette clé a-t-elle déjà été créée ?
  ///
  /// Sert à distinguer une première installation d'une application déjà
  /// posée avec sa base EN CLAIR, qu'il faut migrer (voir
  /// pokou_message_store.dart).
  Future<bool> exists() async {
    final value = await _storage.read(key: storageKey);
    return value != null && value.isNotEmpty;
  }
}
