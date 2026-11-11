import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../groups/presentation/group_controller.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../data/community_model.dart';
import 'community_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Détail d'une communauté : son groupe d'annonces en tête, puis ses autres
/// groupes. Les actions d'administration n'apparaissent que si le serveur
/// nous en donne le droit (`can_manage`).
class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.myUserId,
  });

  final int communityId;
  final int myUserId;

  void _openGroup(BuildContext context, CommunityGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupConversationScreen(
          myUserId: myUserId,
          groupId: group.id,
          groupName: group.name,
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(communityDetailProvider(communityId));
    await ref.read(communityDetailProvider(communityId).future);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Community community,
  ) async {
    final nameController = TextEditingController(text: community.name);
    final descriptionController = TextEditingController(
      text: community.description ?? '',
    );
    final saved = await showModalBottomSheet<bool>(
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
              L.of(context).communityEdit,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: nameController,
              autofocus: true,
              maxLength: 255,
              decoration: InputDecoration(
                hintText: L.of(context).commonName,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: descriptionController,
              maxLength: 2000,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: L.of(context).marketDescription,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: Text(L.of(context).actionSave),
            ),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();
    if (saved != true || name.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(communityRepositoryProvider)
          .update(
            communityId: communityId,
            name: name,
            description: description,
          );
      ref.invalidate(communityDetailProvider(communityId));
      ref.invalidate(myCommunitiesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).communityEditFailed)),
        );
      }
    }
  }

  /// Rattacher un groupe existant que j'administre, ou en créer un dans la
  /// communauté.
  Future<void> _addGroup(
    BuildContext context,
    WidgetRef ref,
    Community community,
  ) async {
    final attachedIds = community.groups.map((group) => group.id).toSet();
    final mine = ref
        .read(myGroupsProvider)
        .maybeWhen(
          data: (groups) =>
              groups.where((g) => !attachedIds.contains(g.id)).toList(),
          orElse: () => const [],
        );

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                L.of(context).communityAddGroup,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.group_add_outlined,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).communityNewGroup),
              onTap: () => Navigator.pop(sheetContext, 'new'),
            ),
            if (mine.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  L.of(context).communityAttachGroup,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              for (final group in mine)
                ListTile(
                  leading: Icon(
                    Icons.groups_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    '${group.memberCount} participant${group.memberCount > 1 ? 's' : ''}',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, 'attach:${group.id}'),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  L.of(context).communityNoGroupToAttach,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'new') {
      final controller = TextEditingController();
      final name = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheet,
        ),
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
                L.of(context).groupName,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                controller: controller,
                autofocus: true,
                maxLength: 255,
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (value) => Navigator.pop(sheetContext, value),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, controller.text),
                child: Text(L.of(context).actionCreate),
              ),
            ],
          ),
        ),
      );
      final trimmed = name?.trim() ?? '';
      controller.dispose();
      if (trimmed.isEmpty || !context.mounted) return;
      await _submitAddGroup(context, ref, name: trimmed);
      return;
    }

    final groupId = int.tryParse(choice.substring('attach:'.length));
    if (groupId != null) await _submitAddGroup(context, ref, groupId: groupId);
  }

  Future<void> _submitAddGroup(
    BuildContext context,
    WidgetRef ref, {
    int? groupId,
    String? name,
  }) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .addGroup(communityId: communityId, groupId: groupId, name: name);
      ref.invalidate(communityDetailProvider(communityId));
      ref.invalidate(myGroupsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).communityAddGroupFailed)),
        );
      }
    }
  }

  Future<void> _detachGroup(
    BuildContext context,
    WidgetRef ref,
    CommunityGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).communityDetachTitle(group.name)),
        content: Text(L.of(context).communityDetachBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).communityDetach),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(communityRepositoryProvider)
          .removeGroup(communityId: communityId, groupId: group.id);
      ref.invalidate(communityDetailProvider(communityId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).communityDetachFailed)),
        );
      }
    }
  }

  Future<void> _manageInviteLink(
    BuildContext context,
    WidgetRef ref,
    Community community,
  ) async {
    final repository = ref.read(communityRepositoryProvider);
    var code = community.inviteCode;
    if (code == null) {
      try {
        code = await repository.createInviteLink(communityId);
        ref.invalidate(communityDetailProvider(communityId));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.of(context).communityLinkFailed)),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;

    final link = communityInviteLinkFor(code);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                L.of(context).groupInviteLink,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                link,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                L.of(context).communityLinkNote,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.share_outlined, color: AppColors.accentPrimaryDark),
              title: Text(L.of(context).actionShare),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
            ListTile(
              leading: Icon(Icons.copy, color: AppColors.accentPrimaryDark),
              title: Text(L.of(context).groupCopyLink),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: Icon(
                Icons.autorenew,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).groupRegenLink),
              onTap: () => Navigator.pop(sheetContext, 'rotate'),
            ),
            ListTile(
              leading: const Icon(
                Icons.link_off,
                color: AppColors.semanticError,
              ),
              title: Text(
                L.of(context).groupDisableLink,
                style: TextStyle(color: AppColors.semanticError),
              ),
              onTap: () => Navigator.pop(sheetContext, 'revoke'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'share') {
      await Share.share(
        '${community.name} — Rejoignez notre communauté sur Pokou Messenger : $link',
        subject: community.name,
      );
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).groupLinkCopied)));
      }
      return;
    }
    try {
      if (action == 'rotate') {
        await repository.createInviteLink(communityId);
      } else {
        await repository.revokeInviteLink(communityId);
      }
      ref.invalidate(communityDetailProvider(communityId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).communityActionFailed)),
        );
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).communityLeaveTitle),
        content: Text(L.of(context).communityLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).groupLeaveAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(communityRepositoryProvider)
          .removeMember(communityId: communityId, userId: myUserId);
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(myGroupsProvider);
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).communityLeaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(communityDetailProvider(communityId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          async.maybeWhen(
            data: (community) => community.name,
            orElse: () => L.of(context).communityOne,
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                L.of(context).communityUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          data: (community) => RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _Header(community: community),
                if (community.canManage)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Action(
                          icon: Icons.edit_outlined,
                          label: L.of(context).conversationEdit,
                          onTap: () => _rename(context, ref, community),
                        ),
                        _Action(
                          icon: Icons.group_add_outlined,
                          label: L.of(context).communityAddGroup,
                          onTap: () => _addGroup(context, ref, community),
                        ),
                        _Action(
                          icon: Icons.link,
                          label: community.inviteCode == null
                              ? L.of(context).communityCreateLink
                              : L.of(context).groupInviteLink,
                          onTap: () =>
                              _manageInviteLink(context, ref, community),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    L.of(context).communityGroups,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                for (final group in community.groups)
                  _GroupRow(
                    group: group,
                    canManage: community.canManage,
                    onTap: () => _openGroup(context, group),
                    onDetach: () => _detachGroup(context, ref, group),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => _leave(context, ref),
                    child: Text(
                      L.of(context).communityLeave,
                      style: TextStyle(
                        color: AppColors.semanticError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          if (community.avatar != null)
            ContactAvatar(
              avatar: community.avatar,
              displayName: community.name,
              size: 72,
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
              ),
              child: Icon(
                Icons.workspaces_outline,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            community.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${community.memberCount} membre${community.memberCount > 1 ? 's' : ''} · '
            '${community.groupCount} groupe${community.groupCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (community.description != null &&
              community.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              community.description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accentPrimaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.canManage,
    required this.onTap,
    required this.onDetach,
  });

  final CommunityGroup group;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (group.avatar != null)
              ContactAvatar(
                avatar: group.avatar,
                displayName: group.name,
                size: 40,
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceElevated,
                ),
                child: Icon(
                  group.isAnnouncement ? Icons.campaign_outlined : Icons.groups,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.isAnnouncement
                        ? L.of(context).communityAnnouncements
                        : '${group.memberCount} participant${group.memberCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Le groupe d'annonces ne se détache pas : il n'existe que par la
            // communauté.
            if (canManage && !group.isAnnouncement)
              IconButton(
                icon: Icon(
                  Icons.link_off,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: L.of(context).communityDetach,
                onPressed: onDetach,
              ),
          ],
        ),
      ),
    );
  }
}
