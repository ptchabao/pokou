import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
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
                  const SizedBox(height: 16),
                  Text(
                    l.groupLeaveKoryNote,
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
