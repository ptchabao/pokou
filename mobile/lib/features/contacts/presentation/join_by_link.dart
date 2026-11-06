import 'package:flutter/material.dart';

import '../../groups/data/group_repository.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../communities/data/community_model.dart';
import '../../communities/presentation/community_controller.dart';
import '../../communities/presentation/community_detail_screen.dart';
import '../../groups/data/group_model.dart';
import '../../groups/presentation/group_controller.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import 'discussions_controller.dart';

/// Rejoindre un groupe ou une communauté par lien — **une seule porte**.
///
/// Les deux flux existaient séparément, chacun dans sa section de l'onglet
/// Contacts : « Rejoindre » sous Groupes, « Rejoindre » sous Communautés. Ces
/// sections ont disparu quand groupes et communautés sont entrés dans la
/// liste des discussions, et avec elles les deux seules entrées vers ce
/// geste.
///
/// Les réunir n'est pas qu'un rangement : **personne ne sait, en collant un
/// lien, s'il mène à un groupe ou à une communauté**. Demander de choisir
/// avant de coller revenait à poser une question dont on n'a pas la réponse.
/// Le lien, lui, la porte — c'est lui qu'on lit.
Future<void> showJoinByLinkSheet(
  BuildContext context,
  WidgetRef ref, {
  required int myUserId,
}) async {
  final controller = TextEditingController();
  final input = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).joinLinkTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            L.of(context).joinLinkBody,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://apipokou.cabinet-p-et-associes.com/invite/…',
            ),
            onSubmitted: (value) => Navigator.pop(sheetContext, value),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(sheetContext, controller.text),
            child: Text(L.of(context).joinLinkContinue),
          ),
        ],
      ),
    ),
  );
  final raw = input?.trim() ?? '';
  controller.dispose();
  if (raw.isEmpty || !context.mounted) return;

  // `/c/…` désigne une communauté, `/invite/…` un groupe. Un code seul, dicté
  // à l'oral, est traité comme un groupe : c'est le format historique, et le
  // seul que les gens recopient à la main.
  if (raw.contains('/c/')) {
    await _joinCommunity(context, ref, communityInviteCodeFrom(raw), myUserId);
  } else {
    await _joinGroup(context, ref, inviteCodeFrom(raw), myUserId);
  }
}

Future<void> _joinGroup(
  BuildContext context,
  WidgetRef ref,
  String code,
  int myUserId,
) async {
  final repository = ref.read(groupRepositoryProvider);
  GroupInvitePreview preview;
  try {
    preview = await repository.previewInvite(code);
  } catch (exc) {
    _say(
      context,
      exc is ApiException ? exc.message : L.of(context).joinLinkUnreadable,
    );
    return;
  }
  if (!context.mounted) return;

  if (preview.alreadyMember) {
    _say(context, L.of(context).joinAlreadyMember(preview.name));
    return;
  }

  // On montre CE QU'ON REJOINT avant de rejoindre : un collage ne doit pas
  // suffire à faire entrer quelqu'un quelque part.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(preview.name),
      content: Text(L.of(context).joinGroupQuestion(preview.memberCount)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(L.of(context).actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(L.of(context).joinAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final group = await repository.joinByInvite(code);
    ref.invalidate(myGroupsProvider);
    ref.invalidate(discussionsProvider);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupConversationScreen(
          myUserId: myUserId,
          groupId: group.id,
          groupName: group.name,
        ),
      ),
    );
  } on GroupJoinPending {
    if (context.mounted) _say(context, L.of(context).groupJoinPending);
  } catch (_) {
    _say(context, L.of(context).joinGroupFailed);
  }
}

Future<void> _joinCommunity(
  BuildContext context,
  WidgetRef ref,
  String code,
  int myUserId,
) async {
  final repository = ref.read(communityRepositoryProvider);
  CommunityInvitePreview preview;
  try {
    preview = await repository.previewInvite(code);
  } catch (exc) {
    _say(
      context,
      exc is ApiException ? exc.message : L.of(context).joinLinkUnreadable,
    );
    return;
  }
  if (!context.mounted) return;

  if (preview.alreadyMember) {
    _say(context, L.of(context).joinAlreadyMember(preview.name));
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(preview.name),
      content: Text(
        '${L.of(context).joinCommunityCounts(preview.memberCount, preview.groupCount)}'
        '\n\n${L.of(context).joinCommunityBody}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(L.of(context).actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(L.of(context).joinAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final community = await repository.joinByInvite(code);
    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(myGroupsProvider);
    ref.invalidate(discussionsProvider);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: community.id,
          myUserId: myUserId,
        ),
      ),
    );
  } catch (_) {
    _say(context, L.of(context).joinCommunityFailed);
  }
}

void _say(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
