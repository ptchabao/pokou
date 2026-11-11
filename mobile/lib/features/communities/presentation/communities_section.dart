import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../groups/presentation/group_controller.dart';
import 'community_controller.dart';
import 'community_detail_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Créer une communauté.
///
/// Ce fichier portait la section « Communautés » de l'onglet Contacts. Elle
/// a disparu le jour où les communautés sont devenues des LIGNES de la
/// liste des discussions : les garder au-dessus faisait figurer les mêmes
/// conversations deux fois, et poussait la liste sous la ligne de
/// flottaison.
///
/// Ne reste que ce qu'elle portait d'irremplaçable — la création, appelée
/// désormais depuis « Nouvelle discussion ». Rejoindre par lien a été
/// réuni avec celui des groupes dans `contacts/presentation/join_by_link.dart` :
/// personne ne sait, en collant un lien, s'il mène à l'un ou à l'autre.

/// La feuille « Nouvelle communauté ».
///
/// Fonction de haut niveau plutôt que méthode d'un widget : deux écrans
/// peuvent l'ouvrir, et recopier un formulaire de création est le meilleur
/// moyen d'avoir deux textes d'explication qui divergent sans que personne
/// ne les compare.
Future<void> showCreateCommunitySheet(
  BuildContext context,
  WidgetRef ref, {
  required int myUserId,
}) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).communityNewTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            L.of(context).communityNewBody,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: nameController,
            autofocus: true,
            maxLength: 255,
            decoration: InputDecoration(
              hintText: L.of(context).communityNameHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: descriptionController,
            maxLength: 2000,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: L.of(context).communityDescriptionHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: Text(L.of(context).communityCreateAction),
          ),
        ],
      ),
    ),
  );
  final name = nameController.text.trim();
  final description = descriptionController.text.trim();
  nameController.dispose();
  descriptionController.dispose();
  if (confirmed != true || name.isEmpty || !context.mounted) return;

  try {
    final community = await ref
        .read(communityRepositoryProvider)
        .create(
          name: name,
          description: description.isEmpty ? null : description,
        );
    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(myGroupsProvider);
    // La liste d'accueil porte désormais les communautés : sans cette
    // invalidation, la nouvelle n'y apparaîtrait qu'au prochain tirer-pour-
    // rafraîchir.
    ref.invalidate(discussionsProvider);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: community.id,
            myUserId: myUserId,
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).communityCreateFailed)),
      );
    }
  }
}
