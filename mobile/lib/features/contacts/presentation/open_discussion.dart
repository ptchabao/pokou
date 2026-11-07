import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../communities/presentation/community_detail_screen.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../data/conversation_summary.dart';

/// Ouvre une discussion — à deux, de groupe, ou une communauté.
///
/// UN seul chemin, partagé par la liste des Discussions et les bulles de
/// l'Accueil : toucher une discussion où qu'elle soit mène DIRECTEMENT à
/// elle, sans détour par la liste.
Future<void> openDiscussion(
  BuildContext context,
  WidgetRef ref,
  ConversationSummary discussion,
) async {
  var myUserId = ref.read(authControllerProvider).user?.id;
  if (myUserId == null) {
    final messenger = ScaffoldMessenger.of(context);
    final failed = L.of(context).chatsProfileMissing;
    myUserId =
        (await ref.read(authControllerProvider.notifier).ensureProfile())?.id;
    if (myUserId == null) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (!context.mounted) return;
  }
  final me = myUserId;
  // Une communauté s'OUVRE sur ses groupes : elle n'a pas de fil à elle.
  if (discussion.isCommunity) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CommunityDetailScreen(communityId: discussion.id!, myUserId: me),
      ),
    );
    return;
  }
  if (discussion.kind == 'group') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupConversationScreen(
          myUserId: me,
          groupId: discussion.id!,
          groupName: discussion.name,
        ),
      ),
    );
    return;
  }
  final contactUserId = discussion.contactUserId;
  if (contactUserId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context).chatsProfileMissing)),
    );
    return;
  }
  // Fonctionne aussi pour un inconnu : GET /messages/{id} n'exige que
  // d'être authentifié.
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ConversationScreen(
        myUserId: me,
        contactUserId: contactUserId,
        contactName: discussion.name,
      ),
    ),
  );
}
