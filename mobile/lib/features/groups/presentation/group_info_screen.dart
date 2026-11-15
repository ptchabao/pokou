import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/group_model.dart';

/// Discussions · 8 — Infos du groupe.
///
/// Un ÉCRAN, et non plus la feuille du ⋮ : grand avatar, « Groupe · N
/// membres », la rangée Audio / Vidéo / Ajouter, le mode preuve et le lien
/// d'invitation, la liste des membres, puis les actions sur le groupe.
///
/// ── Ce que cet écran fait, et ce qu'il laisse faire ──────────────────
///
/// Il ne fait RIEN lui-même : chaque geste rend un code d'action à la
/// conversation qui l'a ouvert (« proof », « rename », « remove:12 »…), qui
/// l'exécute avec les méthodes qu'elle avait déjà pour la feuille. Le mode
/// preuve garde ainsi ses propres feuilles d'activation, et rien n'est
/// écrit deux fois.
///
/// Pas de « Rechercher » : la recherche dans une conversation n'existe que
/// pour les discussions à deux (les messages de groupe sont chiffrés par
/// clé d'expéditeur, la recherche serveur n'y a pas accès). Pas de bandeau
/// de cagnotte non plus : aucune donnée ne relie encore une cagnotte Kory
/// à son groupe côté application.
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.myUserId,
  });

  final Group group;
  final int myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];
    String stateOf(GroupMember member) {
      for (final c in contacts) {
        if (c.contactUserId == member.userId) {
          final about = c.about?.trim() ?? '';
          return about.isEmpty ? l.contactAvailable : about;
        }
      }
      return l.contactAvailable;
    }

    // Moi d'abord, puis les administrateurs, puis les autres — comme la
    // maquette.
    final members = [...group.members]
      ..sort((a, b) {
        int rank(GroupMember m) =>
            m.userId == myUserId ? 0 : (m.canManage ? 1 : 2);
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.displayName.compareTo(b.displayName);
      });

    void act(String action) => Navigator.of(context).pop(action);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(
          l.groupInfoTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(
              child: ContactAvatar(
                avatar: null,
                displayName: group.name,
                size: 88,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              group.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.groupInfoSubtitle(group.members.length),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.call_outlined,
                    label: l.groupInfoAudio,
                    onTap: () => act('call:audio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.videocam_outlined,
                    label: l.groupInfoVideo,
                    onTap: () => act('call:video'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.person_add_alt,
                    label: l.groupInfoAdd,
                    onTap: () => act('add'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              children: [
                // Le mode preuve : on mène à sa feuille, sans la refaire.
                ListTile(
                  leading: const Icon(Icons.history_toggle_off),
                  title: Text(
                    group.proofMode ? l.groupInfoProofOn : l.groupInfoProofOff,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l.groupInfoProofHint,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    group.proofMode
                        ? l.groupInfoProofDisable
                        : l.groupInfoProofEnable,
                    style: TextStyle(
                      color: AppColors.accentPrimaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => act('proof'),
                ),
                if (group.proofMode)
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(l.proofExport),
                    onTap: () => act('proof:export'),
                  ),
                if (group.canManage)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(
                      l.groupInviteLink,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      l.groupInfoInviteHint,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => act('invite'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(
                l.groupInvitationMembers(group.members.length),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _Card(
              children: [
                for (final member in members)
                  ListTile(
                    leading: IdentityAvatar(
                      userId: member.userId,
                      avatar: null,
                      displayName: member.displayName,
                      size: 38,
                      showStatusRing: false,
                    ),
                    title: Text(
                      member.userId == myUserId ? l.navYou : member.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      stateOf(member),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: member.canManage
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l.groupAdmin,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : null,
                    // Toucher un membre : écrire, ou (admin) gérer son rôle.
                    onTap: member.userId == myUserId
                        ? null
                        : () => _memberMenu(context, member),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              children: [
                if (group.canEditInfo) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l.groupEditName),
                    onTap: () => act('rename'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(
                      group.avatarMediaId == null
                          ? l.groupAddPhoto
                          : l.groupChangePhoto,
                    ),
                    onTap: () => act('photo'),
                  ),
                  if (group.avatarMediaId != null)
                    ListTile(
                      leading: const Icon(Icons.hide_image_outlined),
                      title: Text(l.groupRemovePhoto),
                      onTap: () => act('photo:clear'),
                    ),
                ],
                if (group.canManage)
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(l.groupManageTitle),
                    subtitle: Text(
                      l.groupManageSubtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => act('manage'),
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.semanticError,
                  ),
                  title: Text(
                    l.groupLeave,
                    style: const TextStyle(color: AppColors.semanticError),
                  ),
                  onTap: () => act('leave'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.semanticError,
                  ),
                  title: Text(
                    l.reportGroup,
                    style: const TextStyle(color: AppColors.semanticError),
                  ),
                  onTap: () => act('report'),
                ),
                if (group.isOwnedBy(myUserId))
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.semanticError,
                    ),
                    title: Text(
                      l.groupDelete,
                      style: const TextStyle(color: AppColors.semanticError),
                    ),
                    onTap: () => act('delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Écrire au membre ; pour qui gère le groupe, le nommer ou le retirer.
  /// Mêmes règles que la feuille d'avant : le créateur n'est ni
  /// rétrogradable ni évinçable.
  Future<void> _memberMenu(BuildContext context, GroupMember member) async {
    final l = L.of(context);
    final navigator = Navigator.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(l.groupInfoMessage(member.displayName)),
              onTap: () => Navigator.pop(sheetContext, 'dm:${member.userId}'),
            ),
            if (group.isOwner && !member.isOwner)
              ListTile(
                leading: Icon(
                  member.isAdmin
                      ? Icons.remove_moderator_outlined
                      : Icons.add_moderator_outlined,
                ),
                title: Text(
                  member.isAdmin ? l.groupDemoteAdmin : l.groupPromoteAdmin,
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  'role:${member.userId}:${member.isAdmin ? 'MEMBER' : 'ADMIN'}',
                ),
              ),
            if (group.canManage && !member.isOwner)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: Text(l.marketRemove),
                onTap: () =>
                    Navigator.pop(sheetContext, 'remove:${member.userId}'),
              ),
          ],
        ),
      ),
    );
    if (action != null) navigator.pop(action);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentPrimaryDark),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: children),
  );
}
