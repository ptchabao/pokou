import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/report_sheet.dart';
import '../data/group_model.dart';
import 'group_controller.dart';

/// DIS-26 · Gérer le groupe — réservé aux administrateurs.
///
/// Les réglages valent pour tout le groupe et sont appliqués par le
/// serveur : un membre ne peut pas les contourner en modifiant son
/// application.
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  Group? _group;
  List<Map<String, dynamic>> _requests = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(groupRepositoryProvider);
    try {
      final group = await repo.getGroup(widget.groupId);
      final requests = await repo.joinRequests(widget.groupId);
      if (mounted) {
        setState(() {
          _group = group;
          _requests = requests;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _group ??= null);
    }
  }

  Future<void> _save({
    bool? adminsOnlyMessages,
    bool? membersCanEditInfo,
    bool? joinApproval,
    bool setDisappearing = false,
    int? disappearingSeconds,
  }) async {
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(groupRepositoryProvider)
          .updateSettings(
            groupId: widget.groupId,
            adminsOnlyMessages: adminsOnlyMessages,
            membersCanEditInfo: membersCanEditInfo,
            joinApproval: joinApproval,
            setDisappearing: setDisappearing,
            disappearingSeconds: disappearingSeconds,
          );
      if (mounted) setState(() => _group = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : L.of(context).groupSettingsSaveFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// « Quitter le groupe » — même confirmation que depuis le ⋮ de la
  /// conversation (voir group_conversation_screen.dart::_leave), rejointe
  /// ici parce que cet écran n'a pas le contrôleur de la conversation.
  Future<void> _confirmLeave(Group group) async {
    final l = L.of(context);
    final myUserId = ref.read(authControllerProvider).user?.id;
    if (myUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.groupLeaveTitle),
        content: Text(l.groupLeaveBody(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l.groupLeaveAction,
              style: const TextStyle(color: AppColors.semanticError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(groupId: widget.groupId, userId: myUserId);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.groupLeaveFailed)));
      }
    }
  }

  /// Discussions · 26 — « Signaler le groupe », avec les 5 derniers
  /// messages déchiffrés par CET appareil, réservé aux membres (le serveur
  /// vérifie l'appartenance).
  Future<void> _reportGroup(Group group) async {
    final myUserId = ref.read(authControllerProvider).user?.id;
    if (myUserId == null) return;
    final recent = await recentGroupForReport(
      ref,
      groupId: widget.groupId,
      myUserId: myUserId,
    );
    if (!mounted) return;
    await showReportSheet(
      context,
      ref,
      title: L.of(context).reportGroupNamed(group.name),
      groupId: widget.groupId,
      recentMessages: recent,
    );
  }

  /// « Edem K., toi » : les administrateurs, moi compris.
  String _adminNames(Group group, L l) {
    final myUserId = ref.read(authControllerProvider).user?.id;
    return group.members
        .where((m) => m.canManage)
        .map((m) => m.userId == myUserId ? l.groupSettingsMe : m.displayName)
        .join(', ');
  }

  Future<void> _showAdmins(Group group) async {
    final l = L.of(context);
    final myUserId = ref.read(authControllerProvider).user?.id;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.groupSettingsAdmins,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final m in group.members.where((m) => m.canManage))
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(m.userId == myUserId ? l.navYou : m.displayName),
                subtitle: Text(m.isOwner ? l.groupCreator : l.groupAdmin),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(String requestId, bool approve) async {
    try {
      await ref
          .read(groupRepositoryProvider)
          .decideJoinRequest(
            groupId: widget.groupId,
            requestId: requestId,
            approve: approve,
          );
    } catch (_) {}
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final group = _group;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.groupManageTitle),
            if (group != null)
              Text(
                '${group.name} · ${group.memberCount}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: group == null
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(l.groupPermissions),
                  _Card(
                    children: [
                      SwitchListTile(
                        title: Text(l.groupEditInfoSetting),
                        subtitle: Text(
                          group.membersCanEditInfo
                              ? l.groupAllMembers
                              : l.groupAdminsOnly,
                        ),
                        value: group.membersCanEditInfo,
                        onChanged: (v) => _save(membersCanEditInfo: v),
                      ),
                      SwitchListTile(
                        title: Text(l.groupSendSetting),
                        subtitle: Text(
                          group.adminsOnlyMessages
                              ? l.groupAdminsOnly
                              : l.groupAllMembers,
                        ),
                        value: !group.adminsOnlyMessages,
                        onChanged: (v) => _save(adminsOnlyMessages: !v),
                      ),
                      SwitchListTile(
                        title: Text(l.groupApproveSetting),
                        subtitle: Text(l.groupApproveSettingSub),
                        value: group.joinApproval,
                        onChanged: (v) => _save(joinApproval: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Discussions · 26 — « Membres » : administrateurs, lien
                  // d'invitation, mode preuve. Le lien et le mode preuve
                  // s'ouvrent depuis la conversation, qui a déjà leurs
                  // feuilles : cet écran lui rend la main avec le geste.
                  _Section(l.groupSettingsMembers),
                  _Card(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: Text(l.groupSettingsAdmins),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                _adminNames(group, l),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _showAdmins(group),
                      ),
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(l.groupInviteLink),
                        subtitle: Text(
                          group.inviteCode == null
                              ? l.groupNoLink
                              : l.groupInfoInviteHint,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop('invite'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.history_toggle_off),
                        title: Text(l.groupSettingsProof),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              group.proofMode
                                  ? l.groupSettingsProofOn
                                  : l.groupSettingsProofOff,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => Navigator.of(context).pop('proof'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(l.groupDisappearing),
                  _Card(
                    children: [
                      RadioGroup<int>(
                        groupValue: group.disappearingSeconds ?? 0,
                        onChanged: (v) => _save(
                          setDisappearing: true,
                          disappearingSeconds: v == 0 ? null : v,
                        ),
                        child: Column(
                          children: [
                            for (final (seconds, label) in [
                              (0, l.groupDisappearingOff),
                              (86400, l.groupDisappearing24h),
                              (604800, l.groupDisappearing7d),
                              (7776000, l.groupDisappearing90d),
                            ])
                              RadioListTile<int>(
                                value: seconds,
                                title: Text(label),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(l.groupJoinRequests),
                  _Card(
                    children: [
                      if (_requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l.groupNoJoinRequest,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        for (final r in _requests)
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1),
                            title: Text(r['display_name'] as String? ?? ''),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _decide(r['id'] as String, false),
                                  child: Text(l.groupReject),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      _decide(r['id'] as String, true),
                                  child: Text(l.groupApprove),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(l.groupLeave),
                        onTap: () => _confirmLeave(group),
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
                        onTap: () => _reportGroup(group),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // La cagnotte n'existe que là où Kory est ouvert : en Lot
                  // 1, la note ne mentionne jamais Kory (aucune mention de
                  // Kory n'est montrée dans ce pays).
                  Text(
                    ref.watch(currentCountryConfigProvider).has('kory')
                        ? l.groupLeaveKoryNote
                        : l.groupLeaveLot1Note,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}
