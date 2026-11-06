import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/groups/data/group_model.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/presentation/group_controller.dart';
import '../../features/messaging/data/direct_message_model.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/messaging/presentation/messaging_controller.dart';
import '../providers.dart';
import '../sync/pokou_sync_engine.dart';
import 'e2ee_outcome.dart';
import 'e2ee_service.dart';
import 'undecryptable.dart';

/// Reçus de nouvel essai : aucun message ne reste illisible pour de bon.
///
/// Une clé de message ne sert qu'une fois (chiffrement de bout en bout).
/// Réinstallation, cache effacé, deux traitements concurrents : le
/// destinataire peut se retrouver avec un chiffré qu'il ne peut plus ouvrir
/// — une bulle vide.
///
/// - Côté DESTINATAIRE : chaque échec de déchiffrement est signalé
///   ([reportUndecryptable]) et devient une demande au serveur.
/// - Côté EXPÉDITEUR : son téléphone a le clair de ce qu'il a envoyé. Il le
///   rescelle POUR CE SEUL destinataire, par une session à deux NEUVE
///   ([E2EEService.sealFresh]) — si l'ancienne était perdue, la continuer
///   échouerait encore.
/// - Le destinataire l'ouvre, le range ouvert, et la bulle se remplit.
///
/// Le serveur ne voit que du chiffré. Rien ne part si l'expéditeur n'a plus
/// le clair : la demande est close comme « indisponible ».
class E2EERetryService {
  E2EERetryService(this._ref) {
    _reports = undecryptableReports.listen(
      (r) => unawaited(_request(r.kind, r.messageId)),
    );
    listenDurableEventTypes(_ref, (type) {
      if (type.startsWith('e2ee:retry')) unawaited(process());
    });
    unawaited(process());
  }

  final Ref _ref;
  StreamSubscription<({String kind, String messageId})>? _reports;
  final Set<String> _asked = {};
  bool _running = false;
  bool _again = false;

  int? get _me => _ref.read(authControllerProvider).user?.id;

  Future<void> _request(String kind, String messageId) async {
    if (_me == null || !_asked.add('$kind:$messageId')) return;
    try {
      await _ref.read(apiClientProvider).post(
        '/e2ee/retries',
        body: {'kind': kind, 'message_id': messageId},
      );
    } catch (_) {
      // Hors ligne : on redemandera à la prochaine lecture du message.
      _asked.remove('$kind:$messageId');
    }
  }

  /// Traite ce qui attend : re-livrer (expéditeur), ouvrir (destinataire).
  Future<void> process() async {
    if (_me == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final response =
            await _ref.read(apiClientProvider).get('/e2ee/retries')
                as Map<String, dynamic>;
        // Un élément qui échoue ne bloque pas les autres : il sera repris
        // au prochain passage.
        for (final item in (response['to_fulfill'] as List? ?? const [])) {
          try {
            await _fulfill(item as Map<String, dynamic>);
          } catch (_) {}
        }
        for (final item in (response['to_open'] as List? ?? const [])) {
          try {
            await _open(item as Map<String, dynamic>);
          } catch (_) {}
        }
      } while (_again);
    } catch (_) {
      // Réseau : réessayé au prochain événement ou à la reconnexion.
    } finally {
      _running = false;
    }
  }

  Future<void> _fulfill(Map<String, dynamic> item) async {
    final me = _me;
    final api = _ref.read(apiClientProvider);
    final store = _ref.read(pokouMessageStoreProvider);
    final kind = item['kind'] as String;
    final messageId = item['message_id'] as String;
    final retryId = item['id'] as String;

    String? body;
    if (kind == 'direct') {
      final m = await store.directById(messageId);
      if (m != null && !m.isEncrypted && m.senderId == me) {
        body = MessagingRepository.directPlaintextOf(m);
      }
    } else {
      final m = await store.groupById(messageId);
      if (m != null && !m.isEncrypted && m.senderId == me) {
        body = GroupRepository.groupBodyOf(m);
      }
    }
    if (body == null) {
      await api.post(
        '/e2ee/retries/$retryId/fulfill',
        body: const {'unavailable': true},
      );
      return;
    }
    final sealed = await _ref
        .read(e2eeServiceProvider)
        .sealFresh(
          peerUserId: item['requester_id'] as int,
          plaintext: jsonEncode({
            'v': 1,
            'kind': kind,
            'message_id': messageId,
            'body': body,
          }),
        );
    if (sealed is! SealEncrypted) return; // réessayé plus tard
    await api.post(
      '/e2ee/retries/$retryId/fulfill',
      body: {
        'encryption': sealed.encryption,
        'ciphertext': sealed.ciphertext,
        'envelope': sealed.envelope,
      },
    );
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final api = _ref.read(apiClientProvider);
    final store = _ref.read(pokouMessageStoreProvider);
    final retryId = item['id'] as String;
    final kind = item['kind'] as String;
    final messageId = item['message_id'] as String;
    final raw = item['message'] as Map<String, dynamic>?;

    if (item['status'] == 'DELIVERED' && raw != null) {
      final clear = await _ref
          .read(e2eeServiceProvider)
          .open(
            peerUserId: item['sender_id'] as int,
            envelope: item['envelope'] as Map<String, dynamic>,
            ciphertext: item['ciphertext'] as String,
          );
      final wrapper = jsonDecode(clear) as Map<String, dynamic>;
      if (wrapper['kind'] != kind || wrapper['message_id'] != messageId) {
        throw const FormatException('Re-livraison hors contexte');
      }
      final body = wrapper['body'] as String;
      if (kind == 'direct') {
        final message = DirectMessage.fromJson(raw);
        final opened = _ref
            .read(messagingRepositoryProvider)
            .resolveDirectPlaintext(message, body);
        if (!opened.isEncrypted) {
          await store.saveDirect([opened]);
          store.announceRecovered(group: false, message: opened.toJson());
        }
      } else {
        final message = GroupMessage.fromJson(raw);
        final opened = _ref
            .read(groupRepositoryProvider)
            .resolveGroupBody(message, body);
        await store.saveGroup([opened]);
        store.announceRecovered(group: true, message: opened.toJson());
      }
    }
    await api.post('/e2ee/retries/$retryId/ack', body: const {});
  }

  void dispose() => _reports?.cancel();
}

final e2eeRetryServiceProvider = Provider<E2EERetryService>((ref) {
  final service = E2EERetryService(ref);
  ref.onDispose(service.dispose);
  return service;
});
