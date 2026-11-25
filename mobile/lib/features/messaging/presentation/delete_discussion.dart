import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';

/// « Supprimer la discussion » avec [name] — pour moi seulement.
///
/// Confirmé d'abord : le geste efface la copie locale, et le texte des
/// messages chiffrés n'existe nulle part ailleurs pour moi. Le serveur
/// retient la date (l'historique ne revient pas au prochain chargement) ;
/// chez l'autre, rien ne bouge.
///
/// Hors ligne, rien n'est effacé : sans la date côté serveur, l'historique
/// reviendrait à la prochaine ouverture et le geste paraîtrait sans effet.
///
/// `true` si la discussion a été supprimée.
Future<bool> confirmAndDeleteDirectDiscussion(
  BuildContext context,
  WidgetRef ref, {
  required int myUserId,
  required int contactUserId,
  required String name,
}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.chatXDeleteDiscussionTitle(name)),
      content: Text(l.chatXDeleteDiscussionBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.semanticError),
          child: Text(l.chatXDeleteDiscussionAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await ref
        .read(conversationsRepositoryProvider)
        .clearDirectHistory(contactUserId);
    await ref
        .read(pokouMessageStoreProvider)
        .clearDirectConversation(
          myUserId: myUserId,
          contactUserId: contactUserId,
        );
    ref.invalidate(discussionsProvider);
    messenger?.showSnackBar(
      SnackBar(content: Text(l.chatXDeleteDiscussionDone)),
    );
    return true;
  } on NetworkException {
    messenger?.showSnackBar(
      SnackBar(content: Text(l.chatXDeleteDiscussionOffline)),
    );
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l.chatXDeleteDiscussionFailed)),
    );
  }
  return false;
}
