import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/e2ee_service.dart';
import '../../auth/presentation/auth_controller.dart';

import '../../../core/providers.dart';
import '../../../core/sync/offline_list.dart';
import '../../../core/router/app_router.dart';
import '../data/call_repository.dart';
import 'incoming_call_screen.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(
    apiClient: ref.watch(apiClientProvider),
    e2ee: ref.watch(e2eeServiceProvider),
    myUserId: () => ref.read(authControllerProvider).user?.id,
  );
});

final callLogProvider = StreamProvider.autoDispose<List<CallLogEntry>>((ref) {
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'calls_log',
    fetch: ref.watch(callRepositoryProvider).getLogRaw,
    parse: CallLogEntry.fromJson,
  );
});

/// Appel de groupe en cours, pour le bandeau « Rejoindre » d'une conversation
/// de groupe. Renvoie null quand il n'y a pas d'appel. À invalider quand un
/// `call:invite` de ce groupe arrive (voir GroupConversationScreen).
final activeGroupCallProvider = FutureProvider.autoDispose
    .family<ActiveGroupCall?, int>((ref, groupId) {
      return ref.watch(callRepositoryProvider).activeGroupCall(groupId);
    });

/// Écoute globale des invitations d'appel (`call:invite` sur le WebSocket) —
/// active pour toute la durée de vie de l'app dès qu'on la regarde une fois
/// (voir main.dart), pas seulement pendant qu'un écran de messagerie précis
/// est affiché, pour ne rater aucun appel entrant pendant qu'on navigue.
final callSignalingProvider = Provider<void>((ref) {
  final ws = ref.watch(wsClientProvider);
  final subscription = ws.events.listen((event) async {
    if (event['type'] != 'call:invite') return;
    final room = event['room'] as String?;
    final fromUserId = event['from_user_id'] as int?;
    if (room == null || fromUserId == null) return;
    final callType = event['call_type'] as String? ?? '1:1';
    final isVideo = event['is_video'] as bool? ?? true;
    final groupId = event['group_id'] as int?;
    final groupName = event['group_name'] as String?;
    final callerIsVerified = event['caller_is_verified'] as bool? ?? false;
    final callerCertifiedName = event['caller_certified_name'] as String?;

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          room: room,
          fromUserId: fromUserId,
          callType: callType,
          isVideo: isVideo,
          groupId: groupId,
          groupName: groupName,
          callerName: callerCertifiedName,
          callerIsVerified: callerIsVerified,
        ),
      ),
    );
  });
  ref.onDispose(subscription.cancel);
});
