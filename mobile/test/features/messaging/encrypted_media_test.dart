import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/crypto/media_cipher.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';

/// Une pièce jointe chiffrée de bout en bout : ce qui part au serveur, et ce
/// que le destinataire retrouve en ouvrant le message.

/// Un service de chiffrement qui « scelle » en gardant le clair de côté,
/// et « ouvre » en le rendant — assez pour suivre le trajet de la clé.
class _Echo extends E2EEService {
  _Echo({this.outcome}) : super(apiClient: ApiClient(baseUrl: 'https://x'));

  final SealOutcome? outcome;
  String? lastSealed;

  @override
  Future<SealOutcome> seal({required int peerUserId, required String plaintext}) async {
    lastSealed = plaintext;
    return outcome ??
        const SealEncrypted(encryption: 'v1', ciphertext: 'opaque', envelope: {'v': 1});
  }

  @override
  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async => ciphertext;
}

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://inutilise');

  final List<Map<String, dynamic>> posted = [];

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    posted.add(Map<String, dynamic>.from(body!));
    return {
      'id': 'srv-1',
      'sender_id': 1,
      'recipient_id': body['recipient_id'],
      'message_type': body['message_type'],
      'content': body['content'],
      'encryption': body['encryption'],
      'ciphertext': body['ciphertext'],
      'envelope': body['envelope'],
      'media_asset_id': body['media_asset_id'],
      'media': {
        'id': body['media_asset_id'],
        'mime_type': MediaCipher.uploadMimeType,
        'size_bytes': 116,
        'original_filename': MediaCipher.uploadFilename,
      },
      'status': 'SENT',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

void main() {
  late MediaKey key;

  setUp(() async {
    MediaKeyRing.clear();
    key = (await MediaCipher.encrypt(
      List.filled(100, 7),
      mimeType: 'image/jpeg',
      filename: 'boutique.jpg',
      caption: 'nouvel arrivage',
    )).key;
  });

  DirectMessage incoming({required MediaKey sealed, int assetId = 11, String type = 'IMAGE'}) =>
      DirectMessage.fromJson({
        'id': 'srv-$assetId-$type',
        'sender_id': 2,
        'recipient_id': 1,
        'message_type': type,
        'content': null,
        'encryption': 'v1',
        // _Echo.open rend le « chiffré » tel quel : on y met la clé scellée.
        'ciphertext': sealed.seal(),
        'envelope': {'v': 1},
        'media_asset_id': assetId,
        'media': {
          'id': assetId,
          'mime_type': MediaCipher.uploadMimeType,
          'size_bytes': 116,
          'original_filename': MediaCipher.uploadFilename,
        },
        'status': 'DELIVERED',
        'created_at': DateTime.now().toIso8601String(),
      });

  test('ni la légende, ni le nom, ni le type ne partent en clair', () async {
    final api = _Api();
    final e2ee = _Echo();
    final repository = MessagingRepository(apiClient: api, e2ee: e2ee);

    final sent = await repository.sendMedia(
      recipientId: 2,
      messageType: 'IMAGE',
      mediaAssetId: 9,
      caption: 'nouvel arrivage',
      mediaKey: key,
    );

    final body = api.posted.single;
    expect(body.containsKey('content'), isFalse);
    expect(body['encryption'], 'v1');
    expect(body['message_type'], 'IMAGE');
    expect(body.toString(), isNot(contains('nouvel arrivage')));
    expect(body.toString(), isNot(contains('boutique.jpg')));
    // C'est bien la clé du fichier qui a été scellée.
    expect(MediaKey.tryParse(e2ee.lastSealed!)!.filename, 'boutique.jpg');

    // L'expéditeur revoit sa propre photo, décrite par la clé.
    expect(sent.mediaKey, isNotNull);
    expect(sent.content, 'nouvel arrivage');
    expect(sent.media!.originalFilename, 'boutique.jpg');
    expect(sent.isEncrypted, isFalse);
  });

  test('sans session chiffrée possible, la clé ne part pas en clair', () async {
    final api = _Api();
    final repository = MessagingRepository(
      apiClient: api,
      e2ee: _Echo(outcome: const SealPeerHasNoKeys()),
    );

    await expectLater(
      repository.sendMedia(recipientId: 2, messageType: 'IMAGE', mediaAssetId: 9, mediaKey: key),
      throwsA(isA<EncryptionUnavailableException>()),
    );
    expect(api.posted, isEmpty);
  });

  test('le destinataire retrouve la clé, la légende et la vraie description', () async {
    final repository = MessagingRepository(apiClient: _Api(), e2ee: _Echo());

    final opened = await repository.decryptIncoming(
      incoming(sealed: key.withAssetId(11)),
      2,
    );

    expect(opened.isEncrypted, isFalse);
    expect(opened.content, 'nouvel arrivage');
    expect(opened.media!.mimeType, 'image/jpeg');
    expect(opened.media!.originalFilename, 'boutique.jpg');
    expect(MediaKeyRing.of(11), isNotNull, reason: 'le dépôt de médias doit la retrouver');

    // Elle survit au cache local de l'appareil…
    final reread = DirectMessage.fromJson(opened.toJson(), fromCache: true);
    expect(reread.mediaKey!.filename, 'boutique.jpg');
    // …mais n'est jamais acceptée d'une charge venue du réseau.
    expect(DirectMessage.fromJson(opened.toJson()).mediaKey, isNull);
  });

  test('une clé qui annonce un autre fichier est refusée', () async {
    final repository = MessagingRepository(apiClient: _Api(), e2ee: _Echo());
    // Le serveur a remplacé media_asset_id (12) : la clé, elle, dit 11.
    final opened = await repository.decryptIncoming(
      incoming(sealed: key.withAssetId(11), assetId: 12),
      2,
    );
    expect(opened.isEncrypted, isTrue);
    expect(opened.mediaKey, isNull);
    expect(MediaKeyRing.of(12), isNull);
  });

  test('un autocollant ne porte jamais de clé de fichier', () async {
    final repository = MessagingRepository(apiClient: _Api(), e2ee: _Echo());
    final opened = await repository.decryptIncoming(
      incoming(sealed: key.withAssetId(13), assetId: 13, type: 'STICKER'),
      2,
    );
    expect(opened.mediaKey, isNull);
    expect(MediaKeyRing.of(13), isNull);
  });

  test('le serveur ne peut pas rattacher une clé ouverte à un autre fichier', () async {
    final repository = MessagingRepository(apiClient: _Api(), e2ee: _Echo());
    final opened = await repository.decryptIncoming(
      incoming(sealed: key.withAssetId(21), assetId: 21),
      2,
    );
    // Une réaction renvoie le même message… avec un autre media_asset_id.
    final tampered = DirectMessage.fromJson({
      ...opened.toJson(),
      'encryption': 'v1',
      'ciphertext': 'x',
      'envelope': {'v': 1},
      'media_asset_id': 22,
      'media_key': null,
    });
    final merged = tampered.resolvedWith(opened);
    expect(merged.isEncrypted, isTrue, reason: 'fusion refusée');
    expect(merged.mediaKey, isNull);
    expect(MediaKeyRing.of(22), isNull);

    // Et une ligne de cache incohérente ne réinstalle pas la clé.
    final row = {...opened.toJson(), 'media_asset_id': 22};
    expect(DirectMessage.fromJson(row, fromCache: true).mediaKey, isNull);
  });
}
