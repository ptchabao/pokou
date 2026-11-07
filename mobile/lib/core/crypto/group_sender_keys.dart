import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class SecureSenderKeyStore implements SenderKeyStore {
  SecureSenderKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _storageKey(SenderKeyName name) =>
      'signal_sender_key_v1_${base64Url.encode(utf8.encode(name.serialize()))}';

  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    final stored = await _storage.read(key: _storageKey(senderKeyName));
    if (stored == null) return SenderKeyRecord();
    return SenderKeyRecord.fromSerialized(base64.decode(stored));
  }

  @override
  Future<void> storeSenderKey(
    SenderKeyName senderKeyName,
    SenderKeyRecord record,
  ) => _storage.write(
    key: _storageKey(senderKeyName),
    value: base64.encode(record.serialize()),
  );
}

class GroupSenderKeys {
  GroupSenderKeys({SenderKeyStore? store, FlutterSecureStorage? storage})
    : _storage =
          storage ?? (store == null ? const FlutterSecureStorage() : null),
      _store = store ?? SecureSenderKeyStore(storage: storage);

  final SenderKeyStore _store;
  final FlutterSecureStorage? _storage;
  final Map<String, String> _memoryCache = {};
  final Map<String, Future<void>> _queues = {};

  SenderKeyName _name({
    required int groupId,
    required int epoch,
    required int senderId,
  }) => SenderKeyName(
    'pokou-group-$groupId-epoch-$epoch',
    // Pokou currently publishes one cryptographic device per account.
    SignalProtocolAddress('$senderId', 1),
  );

  Future<String> createDistribution({
    required int groupId,
    required int epoch,
    required int senderId,
  }) {
    final name = _name(groupId: groupId, epoch: epoch, senderId: senderId);
    return _exclusive(name, () async {
      final cacheKey = _distributionKey(groupId, epoch, senderId);
      final cached = await _read(cacheKey);
      if (cached != null) return cached;
      final distribution = await GroupSessionBuilder(_store).create(name);
      final encoded = jsonEncode({
        'format': 'pokou-group-sender-key-v1',
        'group_id': groupId,
        'epoch': epoch,
        'sender_id': senderId,
        'distribution': base64.encode(distribution.serialize()),
      });
      await _write(cacheKey, encoded);
      return encoded;
    });
  }

  String _distributionKey(int groupId, int epoch, int senderId) =>
      'signal_group_distribution_v1_${groupId}_${epoch}_$senderId';

  Future<String?> _read(String key) async {
    final storage = _storage;
    return storage == null ? _memoryCache[key] : storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    final storage = _storage;
    if (storage == null) {
      _memoryCache[key] = value;
    } else {
      await storage.write(key: key, value: value);
    }
  }

  /// La clé de cet expéditeur pour ce groupe et cette époque est-elle déjà
  /// installée ? Son enveloppe à deux ne s'ouvre qu'UNE fois : la rouvrir à
  /// chaque chargement échouait (« message déjà reçu ») et bloquait le
  /// déchiffrement de tout le groupe.
  Future<bool> hasDistribution({
    required int groupId,
    required int epoch,
    required int senderId,
  }) async =>
      await _read(
        'signal_group_distribution_accepted_v1_${groupId}_${epoch}_$senderId',
      ) ==
      '1';

  /// The distribution must be sealed to each member with a pairwise E2EE
  /// session before being sent to the server.
  Future<void> acceptDistribution({
    required int groupId,
    required int epoch,
    required int senderId,
    required String distribution,
  }) {
    final name = _name(groupId: groupId, epoch: epoch, senderId: senderId);
    return _exclusive(name, () async {
      final acceptedKey =
          'signal_group_distribution_accepted_v1_${groupId}_${epoch}_$senderId';
      if (await _read(acceptedKey) == '1') return;
      final payload = jsonDecode(distribution);
      if (payload is! Map<String, dynamic> ||
          payload['format'] != 'pokou-group-sender-key-v1' ||
          payload['group_id'] != groupId ||
          payload['epoch'] != epoch ||
          payload['sender_id'] != senderId ||
          payload['distribution'] is! String) {
        throw const FormatException('Sender-key distribution context mismatch');
      }
      final decoded = SenderKeyDistributionMessageWrapper.fromSerialized(
        base64.decode(payload['distribution'] as String),
      );
      await GroupSessionBuilder(_store).process(name, decoded);
      await _write(acceptedKey, '1');
    });
  }

  Future<String> encrypt({
    required int groupId,
    required int epoch,
    required int senderId,
    required String plaintext,
  }) {
    final name = _name(groupId: groupId, epoch: epoch, senderId: senderId);
    return _exclusive(name, () async {
      final authenticatedPayload = jsonEncode({
        'format': 'pokou-group-message-v1',
        'group_id': groupId,
        'epoch': epoch,
        'sender_id': senderId,
        'body': plaintext,
      });
      final ciphertext = await GroupCipher(
        _store,
        name,
      ).encrypt(Uint8List.fromList(utf8.encode(authenticatedPayload)));
      return base64.encode(ciphertext);
    });
  }

  Future<String> decrypt({
    required int groupId,
    required int epoch,
    required int senderId,
    required String ciphertext,
  }) {
    final name = _name(groupId: groupId, epoch: epoch, senderId: senderId);
    return _exclusive(name, () async {
      final plaintext = await GroupCipher(
        _store,
        name,
      ).decrypt(base64.decode(ciphertext));
      final payload = jsonDecode(utf8.decode(plaintext));
      if (payload is! Map<String, dynamic> ||
          payload['format'] != 'pokou-group-message-v1' ||
          payload['group_id'] != groupId ||
          payload['epoch'] != epoch ||
          payload['sender_id'] != senderId ||
          payload['body'] is! String) {
        throw const FormatException('Group-message context mismatch');
      }
      return payload['body'] as String;
    });
  }

  Future<T> _exclusive<T>(
    SenderKeyName name,
    Future<T> Function() action,
  ) async {
    final key = name.serialize();
    final previous = _queues[key] ?? Future<void>.value();
    final finished = Completer<void>();
    final queued = previous.then((_) => finished.future);
    _queues[key] = queued;

    await previous;
    try {
      return await action();
    } finally {
      finished.complete();
      if (identical(_queues[key], queued)) _queues.remove(key);
    }
  }
}
