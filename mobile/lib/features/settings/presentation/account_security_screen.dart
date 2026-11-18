import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/forgot_pin_screen.dart';
import '../data/account_security_repository.dart';
import 'account_pin_screen.dart';
import 'backup_screens.dart';
import 'change_number_screen.dart';
import 'delete_account_screen.dart';
import 'devices_screen.dart';
import 'settings_widgets.dart';
import '../../../core/widgets/pokou_sheet.dart';

/// REG-3 · Compte et sécurité : le code PIN du compte, la sauvegarde, le
/// changement de numéro, les appareils, l'export des données et la
/// suppression du compte — tout ce qui protège ou fait sortir le COMPTE.
///
/// Le Profil (nom, photo, À propos) reste un écran à part : c'est ce que
/// les autres voient, pas ce qui garde la porte.
class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  bool _exporting = false;

  Future<T?> _push<T>(Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  Future<void> _openPin(bool enabled) async {
    if (!enabled) {
      await _push<bool>(const AccountPinScreen());
      return;
    }
    final l = L.of(context);
    final choice = await showPokouSheet<String>(
      scrollable: true,
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.accountPinChange),
              onTap: () => Navigator.pop(sheet, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l.pinForgot),
              onTap: () => Navigator.pop(sheet, 'forgot'),
            ),
            ListTile(
              leading: const Icon(
                Icons.lock_open_outlined,
                color: AppColors.semanticError,
              ),
              title: Text(
                l.accountPinDisable,
                style: const TextStyle(color: AppColors.semanticError),
              ),
              onTap: () => Navigator.pop(sheet, 'disable'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'change':
        await _push<bool>(const AccountPinScreen(change: true));
      case 'forgot':
        await _push<void>(const ForgotPinScreen());
      case 'disable':
        await _disablePin();
    }
  }

  /// Désactiver retire la protection : le serveur exige le code actuel.
  Future<void> _disablePin() async {
    final l = L.of(context);
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.accountPinDisable),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(kAccountPinLength),
          ],
          decoration: InputDecoration(labelText: l.accountPinCurrent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l.actionCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.semanticError,
            ),
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: Text(l.accountPinDisableConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.length != kAccountPinLength || !mounted) return;
    try {
      await ref.read(accountSecurityRepositoryProvider).disablePin(pin);
      ref.invalidate(accountPinEnabledProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.accountPinDisabled)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorNetwork)));
      }
    }
  }

  /// Le fichier est produit sur le téléphone puis confié à la feuille de
  /// partage : on l'enregistre dans ses fichiers, on se l'envoie, au choix.
  Future<void> _export() async {
    if (_exporting) return;
    final l = L.of(context);
    setState(() => _exporting = true);
    try {
      final data = await ref
          .read(accountSecurityRepositoryProvider)
          .exportData();
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      final file = File('${dir.path}/pokou-mes-donnees-$stamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json'),
      ], subject: l.accountExport);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.accountExportFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _backupLine(L l, BackupInfo? info) {
    if (info == null) return l.backupNever;
    final where = info.source == BackupSource.googleDrive
        ? l.backupDestDrive
        : l.backupDestPokou;
    final when = DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm().format(info.createdAt.toLocal());
    return '$where · $when';
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pin = ref.watch(accountPinEnabledProvider);
    final backup = ref.watch(backupInfoProvider);
    final devices = ref.watch(devicesProvider).valueOrNull;

    return SettingsScaffold(
      title: l.accountSecurityTitle,
      onRefresh: () async {
        ref.invalidate(accountPinEnabledProvider);
        ref.invalidate(backupInfoProvider);
        ref.invalidate(devicesProvider);
      },
      children: [
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.key_outlined,
              label: l.accountPinTitle,
              subtitle: l.accountPinRowSub,
              trailing: pin.when(
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => SettingsValue(l.accountPinUnknown),
                data: (on) =>
                    SettingsValue(on ? l.accountPinOn : l.accountPinOff),
              ),
              onTap: pin.hasValue ? () => _openPin(pin.value!) : null,
            ),
            SettingsRow(
              icon: Icons.cloud_outlined,
              label: l.backupTitle,
              subtitle: backup.hasValue ? _backupLine(l, backup.value) : null,
              onTap: () async {
                await _push<void>(const BackupSettingsScreen());
                ref.invalidate(backupInfoProvider);
              },
            ),
            SettingsRow(
              icon: Icons.phone_outlined,
              label: l.changeNumberTitle,
              onTap: () => _push<void>(const ChangeNumberScreen()),
            ),
            SettingsRow(
              icon: Icons.smartphone_outlined,
              label: l.devicesTitle,
              trailing: devices == null
                  ? null
                  : SettingsValue('${devices.length}'),
              onTap: () => _push<void>(const DevicesScreen()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.download_outlined,
              label: l.accountExport,
              subtitle: l.accountExportSub,
              trailing: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _exporting ? null : _export,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.delete_outline,
              label: l.deleteAccountTitle,
              destructive: true,
              onTap: () => _push<void>(const DeleteAccountScreen()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsNote(text: l.accountSecurityWarning, warning: true),
      ],
    );
  }
}
