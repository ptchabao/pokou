import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../../../core/widgets/pokou_illustration.dart';

final backupInfoProvider = FutureProvider.autoDispose<BackupInfo?>(
  (ref) => ref.watch(backupServiceProvider).info(),
);

String _size(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Go';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
  return '${(bytes / 1024).ceil()} Ko';
}

String _when(BuildContext context, DateTime date) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).add_Hm().format(date.toLocal());

/// Demande un mot de passe (et sa confirmation à la création).
Future<String?> _askPassword(
  BuildContext context, {
  required bool confirm,
}) async {
  final l = L.of(context);
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(l.backupPasswordLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l.backupPasswordLabel),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                decoration: InputDecoration(labelText: l.backupPasswordConfirm),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.feedbackDanger),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              if (first.text.length < 8) {
                setState(() => error = l.backupPasswordTooShort);
              } else if (confirm && first.text != second.text) {
                setState(() => error = l.backupPasswordMismatch);
              } else {
                Navigator.pop(dialogContext, first.text);
              }
            },
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    ),
  );
  first.dispose();
  second.dispose();
  return result;
}

/// Restaure en arrière-plan : la main est rendue tout de suite (CNX-3), la
/// carte d'avancement s'affiche en tête des Discussions.
Future<bool> startRestore(
  BuildContext context,
  WidgetRef ref,
  String password, {
  BackupInfo? from,
}) async {
  final service = ref.read(backupServiceProvider);
  final progress = ref.read(restoreProgressProvider.notifier);
  progress.state = const RestoreProgress(done: 0, total: 1);
  try {
    await service.restore(
      password,
      from: from,
      onProgress: (p) => progress.state = p,
    );
    progress.state = null;
    return true;
  } on BackupWrongPasswordException {
    progress.state = null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).restoreWrongPassword)),
      );
    }
    return false;
  } catch (_) {
    progress.state = null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).modulesCheckNetwork)),
      );
    }
    return false;
  }
}

// ── Réglage de la sauvegarde (REG-3 → Sauvegarde) ──────────────────────

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _busy = false;
  bool? _hasPassword;
  BackupSource? _dest;
  String? _email;

  @override
  void initState() {
    super.initState();
    final service = ref.read(backupServiceProvider);
    service.hasPassword().then((v) {
      if (mounted) setState(() => _hasPassword = v);
    });
    service.destination().then((d) {
      if (mounted) setState(() => _dest = d);
    });
    service.driveAccountEmail().then((e) {
      if (mounted) setState(() => _email = e);
    });
  }

  Future<void> _setDest(BackupSource dest) async {
    final service = ref.read(backupServiceProvider);
    if (dest == BackupSource.googleDrive && _email == null) {
      final account = await service.drive.chooseAccount();
      if (account == null) return;
      _email = account.email;
    }
    await service.setDestination(dest);
    ref.invalidate(backupInfoProvider);
    if (mounted) setState(() => _dest = dest);
  }

  Future<void> _changeAccount() async {
    final service = ref.read(backupServiceProvider);
    await service.drive.signOut();
    final account = await service.drive.chooseAccount();
    ref.invalidate(backupInfoProvider);
    if (mounted) setState(() => _email = account?.email);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(backupInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).backupFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _password() async {
    final l = L.of(context);
    final password = await _askPassword(context, confirm: true);
    if (password == null || !mounted) return;
    final service = ref.read(backupServiceProvider);
    await _run(() async {
      await service.setPassword(password);
      await service.backupNow();
    }, l.backupDone);
    if (mounted) setState(() => _hasPassword = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final info = ref.watch(backupInfoProvider);
    final backup = info.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.backupTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Center(
              child: PokouIllustration(PokouIllustrations.backup, height: 140),
            ),
            const SizedBox(height: 16),
            // MSG-12 : Google Drive (comme WhatsApp) ou Pokou.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l.backupDestTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ModuleCard(
              child: RadioGroup<BackupSource>(
                groupValue: _dest,
                onChanged: (v) {
                  if (v != null) _setDest(v);
                },
                child: Column(
                  children: [
                    RadioListTile<BackupSource>(
                      contentPadding: EdgeInsets.zero,
                      value: BackupSource.googleDrive,
                      title: Text(l.backupDestDrive),
                      subtitle: Text(l.backupDestDriveSub),
                    ),
                    if (_dest == BackupSource.googleDrive)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _email ?? l.backupNoAccount,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _changeAccount,
                              child: Text(l.backupChangeAccount),
                            ),
                          ],
                        ),
                      ),
                    RadioListTile<BackupSource>(
                      contentPadding: EdgeInsets.zero,
                      value: BackupSource.pokou,
                      title: Text(l.backupDestPokou),
                      subtitle: Text(l.backupWhere),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              child: Column(
                children: [
                  _InfoRow(
                    l.backupTitle,
                    _dest == BackupSource.googleDrive && _email != null
                        ? l.backupWhereDrive(_email!)
                        : l.backupWhere,
                  ),
                  _InfoRow(
                    l.backupLast,
                    backup == null
                        ? l.backupNever
                        : _when(context, backup.createdAt),
                  ),
                  if (backup != null)
                    _InfoRow(
                      l.backupContent,
                      l.backupContentValue(
                        backup.discussions,
                        _size(backup.sizeBytes),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ModuleCallout(tone: CalloutTone.beige, text: l.backupExplain),
            const SizedBox(height: 16),
            if (_hasPassword == true) ...[
              ModuleActionButton(
                label: l.backupNow,
                icon: Icons.backup_outlined,
                busy: _busy,
                onPressed: () => _run(
                  () => ref.read(backupServiceProvider).backupNow(),
                  l.backupDone,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.backupDaily,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ModuleQuietButton(
                label: l.backupChangePassword,
                icon: Icons.password,
                onPressed: _password,
              ),
            ] else if (_hasPassword == false)
              ModuleActionButton(
                label: l.backupSetPassword,
                icon: Icons.lock_outline,
                busy: _busy,
                onPressed: _password,
              ),
            if (backup != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.feedbackDanger,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.backupDelete),
                onPressed: () => _run(() async {
                  await ref.read(backupServiceProvider).deleteBackup();
                  if (mounted) setState(() => _hasPassword = false);
                }, l.backupDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// ── CNX-2 · Bon retour et sauvegarde ────────────────────────────────────

class WelcomeBackScreen extends ConsumerStatefulWidget {
  const WelcomeBackScreen({super.key, this.backup});

  /// `null` : aucune sauvegarde chez Pokou ; on propose de la retrouver sur
  /// Google Drive (Android, comme WhatsApp).
  final BackupInfo? backup;

  @override
  ConsumerState<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends ConsumerState<WelcomeBackScreen> {
  late BackupInfo? backup = widget.backup;
  bool _searching = false;

  Future<void> _findDrive() async {
    setState(() => _searching = true);
    try {
      final found = await ref
          .read(backupServiceProvider)
          .driveInfo(interactive: true);
      if (!mounted) return;
      if (found == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).restoreNoDrive)));
      }
      setState(() => backup = found ?? backup);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).modulesCheckNetwork)),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = this.backup;
    final l = L.of(context);
    final user = ref.watch(authControllerProvider).user;
    final first = (user?.fullName ?? '').split(' ').first;
    final phone = user?.phone ?? '';
    final masked = phone.length > 6
        ? '${phone.substring(0, 4)} •• •• ${phone.substring(phone.length - 4, phone.length - 2)} ${phone.substring(phone.length - 2)}'
        : phone;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Center(
            child: PokouIllustration(PokouIllustrations.backup, height: 150),
          ),
          const SizedBox(height: 16),
          ModuleCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.brandOr),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    backup == null
                        ? l.restoreWelcomeNoBackup
                        : l.welcomeBackBaba(first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModuleCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.terracottaTint,
                  foregroundColor: AppColors.onTerracottaTint,
                  child: Text(first.isEmpty ? '?' : first[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        masked,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (backup != null)
            ModuleCard(
              child: Column(
                children: [
                  _InfoRow(
                    l.backupTitle,
                    backup.source == BackupSource.googleDrive
                        ? l.backupWhereDrive(backup.accountEmail ?? '')
                        : l.backupWhere,
                  ),
                  _InfoRow(l.backupLast, _when(context, backup.createdAt)),
                  _InfoRow(
                    l.backupContent,
                    l.backupContentValue(
                      backup.discussions,
                      _size(backup.sizeBytes),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ModuleCallout(tone: CalloutTone.beige, text: l.welcomeBackOrder),
          const SizedBox(height: 12),
          ModuleCallout(tone: CalloutTone.amber, text: l.welcomeBackOldPhone),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (backup == null)
                ModuleActionButton(
                  label: l.restoreFindDrive,
                  icon: Icons.cloud_download_outlined,
                  busy: _searching,
                  onPressed: _searching ? null : _findDrive,
                )
              else
                ModuleActionButton(
                  label: l.welcomeBackRestore,
                  onPressed: () async {
                    final password = await _askPassword(
                      context,
                      confirm: false,
                    );
                    if (password == null || !context.mounted) return;
                    // La main est rendue tout de suite (CNX-3) : la
                    // restauration continue, sa carte s'affiche dans
                    // Discussions.
                    Navigator.of(context).pop();
                    unawaited(
                      startRestore(context, ref, password, from: backup).then((
                        ok,
                      ) {
                        if (ok && context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(content: Text(l.restoreDone)),
                          );
                        }
                      }),
                    );
                  },
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.welcomeBackSkip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CNX-3 · Restauration en cours (carte des Discussions) ──────────────

class RestoreProgressCard extends ConsumerWidget {
  const RestoreProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(restoreProgressProvider);
    if (progress == null) return const SizedBox.shrink();
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.restoreCardTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${(progress.fraction * 100).round()} %'),
              ],
            ),
            const SizedBox(height: 8),
            ModuleProgressBar(
              value: progress.fraction,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              l.restoreCardBody('${progress.done}', '${progress.total}'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
