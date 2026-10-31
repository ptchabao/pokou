import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';

/// La preuve de bout en bout : un chiffrement impossible ARRÊTE l'envoi.
///
/// Les tests de `e2ee_fail_closed_test.dart` montrent que `seal` refuse.
/// Ceux-ci montrent que le refus se propage — c'est-à-dire qu'aucune requête
/// ne part. C'est la distinction qui compte : le défaut d'origine n'était pas
/// dans le chiffrement, il était dans l'appelant qui traduisait « je n'ai pas
/// pu » en « alors envoie en clair ».

/// Un service de chiffrement dont on choisit l'issue.
class _Sealer extends E2EEService {
  _Sealer(this.outcome) : super(apiClient: ApiClient(baseUrl: 'https://x'));

  final SealOutcome outcome;

  @override
  Future<SealOutcome> seal({required int peerUserId, required String plaintext}) async =>
      outcome;
}

/// Un ApiClient qui COMPTE ce qui part. S'il est appelé, le message a fui.
class _CountingApi extends ApiClient {
  _CountingApi() : super(baseUrl: 'https://inutilise');

  final List<Map<String, dynamic>> posted = [];
  final List<Map<String, dynamic>> patched = [];

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    posted.add(Map<String, dynamic>.from(body!));
    return _messageJson(body);
  }

  @override
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    patched.add(Map<String, dynamic>.from(body!));
    return _messageJson(body);
  }

  static Map<String, dynamic> _messageJson(Map<String, dynamic>? body) {
    final map = body!;
    return {
      'id': 'srv-1',
      'sender_id': 1,
      'recipient_id': map['recipient_id'] ?? 2,
      'message_type': 'TEXT',
      'content': map['content'],
      'status': 'SENT',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

void main() {
  late _CountingApi api;

  setUp(() => api = _CountingApi());

  MessagingRepository repositoryWith(SealOutcome outcome) => MessagingRepository(
        apiClient: api,
        store: PokouMessageStore(),
        e2ee: _Sealer(outcome),
      );

  group('un refus empêche la requête de partir', () {
    for (final reason in SealFailure.values) {
      test('$reason → rien ne part', () async {
        final repository = repositoryWith(SealRefused(reason));

        await expectLater(
          repository.send(recipientId: 2, content: 'code de la caisse : 4412'),
          throwsA(isA<EncryptionUnavailableException>()),
        );
        expect(api.posted, isEmpty,
            reason: 'aucun appel réseau — donc aucune fuite');
      });
    }

    test('le motif du refus est transmis tel quel', () async {
      // L'écran affiche une phrase différente selon le motif : « réessayez »
      // et « vérifiez l'identité de ce contact » n'appellent pas la même
      // conduite.
      final repository = repositoryWith(
        const SealRefused(SealFailure.identityChanged),
      );

      try {
        await repository.send(recipientId: 2, content: 'x');
        fail('aurait dû refuser');
      } on EncryptionUnavailableException catch (exc) {
        expect(exc.reason, SealFailure.identityChanged);
      }
    });

    test('une CORRECTION refusée ne part pas non plus', () async {
      // Sans ça, une correction partirait en clair par-dessus un message
      // chiffré : le pire des deux mondes, puisque le message d'origine
      // avait été protégé.
      final repository = repositoryWith(
        const SealRefused(SealFailure.keyLookupFailed),
      );

      await expectLater(
        repository.edit(messageId: 'srv-1', recipientId: 2, content: 'corrigé'),
        throwsA(isA<EncryptionUnavailableException>()),
      );
      expect(api.patched, isEmpty);
    });
  });

  group('ce qui part quand le chiffrement a réussi', () {
    test('le clair n\'accompagne JAMAIS le chiffré', () async {
      // Envoyer aussi le texte « au cas où » annulerait tout le dispositif.
      final repository = repositoryWith(const SealEncrypted(
        encryption: 'v1',
        ciphertext: 'AAAA',
        envelope: {'sid': 's'},
      ));

      await repository.send(recipientId: 2, content: 'secret');

      expect(api.posted.single['content'], isNull);
      expect(api.posted.single['ciphertext'], 'AAAA');
    });

    test('un correspondant sans trousseau reçoit du clair — et LUI SEUL',
        () async {
      // Le seul chemin qui autorise encore le clair. Il tient à une réponse
      // 404, pas à une panne (voir e2ee_fail_closed_test.dart).
      final repository = repositoryWith(const SealPeerHasNoKeys());

      await repository.send(recipientId: 2, content: 'bonjour');

      expect(api.posted.single['content'], 'bonjour');
      expect(api.posted.single.containsKey('ciphertext'), isFalse);
    });
  });
}
