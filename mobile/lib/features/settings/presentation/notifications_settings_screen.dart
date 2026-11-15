import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/country/country_config.dart';
import '../../../core/providers.dart';
import '../../../core/push/push_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_widgets.dart';

/// Les services dont le push se coupe module par module. Réglage du COMPTE
/// et non de l'appareil : c'est le serveur qui n'envoie pas (inbox.py), ce
/// qui vaut aussi application fermée. La ligne reste dans le centre de
/// notifications.
final servicePushPreferencesProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
      final json =
          await ref.watch(apiClientProvider).get('/notifications/preferences')
              as Map<String, dynamic>;
      return {
        for (final entry in json.entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      };
    });

/// REG-8 · Notifications : Messages, Appels, puis les Modules ouverts.
///
/// Les interrupteurs Messages et Appels gouvernent les notifications que
/// POKOU construit lui-même (messages enrichis, appels) — y compris
/// application fermée, puisque ces push arrivent sans texte et sont mis en
/// forme par l'application. Le raccourci vers les réglages Android reste en
/// bas : c'est là que se règlent les canaux et l'autorisation elle-même.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final modules = ref.watch(currentCountryConfigProvider).modules;

    final l = L.of(context);
    // Section « Modules » : seulement les modules OUVERTS dans le pays —
    // absente au lot 1.
    final services = <(String, String, String)>[
      if (modules.contains('kory')) ('kory', 'Kory', l.notifModuleKorySub),
      if (modules.contains('honam')) ('honam', 'Honam', l.notifModuleHonamSub),
      if (modules.contains('assime'))
        ('assime', 'Assimé', l.notifModuleAssimeSub),
    ];
    final prefs = ref.watch(servicePushPreferencesProvider).valueOrNull;

    Future<void> setService(String service, bool enabled) async {
      try {
        await ref
            .read(apiClientProvider)
            .put('/notifications/preferences', body: {service: enabled});
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.privacySaveFailed)),
          );
        }
      }
      ref.invalidate(servicePushPreferencesProvider);
    }

    return SettingsScaffold(
      title: l.profileNotifications,
      children: [
        SettingsSectionTitle(l.notifMessages),
        SettingsCard(
          children: [
            SettingsRow(
              label: l.notifDirect,
              trailing: SettingsSwitch(
                value: settings.messageNotifications,
                semanticLabel: l.notifMessagesSemantic,
                onChanged: controller.setMessageNotifications,
              ),
            ),
            SettingsRow(
              label: l.notifGroups,
              trailing: SettingsSwitch(
                value: settings.groupNotifications,
                semanticLabel: l.notifGroupsSemantic,
                onChanged: controller.setGroupNotifications,
              ),
            ),
            SettingsRow(
              label: l.notifPreview,
              subtitle: l.notifPreviewSub,
              trailing: SettingsSwitch(
                value: settings.messagePreview,
                semanticLabel: l.notifPreview,
                onChanged: controller.setMessagePreview,
              ),
            ),
            SettingsRow(
              label: l.notifReactions,
              trailing: SettingsSwitch(
                value: settings.reactionNotifications,
                semanticLabel: l.notifReactions,
                onChanged: controller.setReactionNotifications,
              ),
            ),
          ],
        ),
        SettingsSectionTitle(l.navCalls),
        SettingsCard(
          children: [
            SettingsRow(
              label: l.notifRingtone,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pokou',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              onTap: () => _chooseRingtone(context),
            ),
            SettingsRow(
              label: l.notifVibrate,
              trailing: SettingsSwitch(
                value: settings.callVibrate,
                semanticLabel: l.notifVibrate,
                onChanged: controller.setCallVibrate,
              ),
            ),
          ],
        ),
        if (services.isNotEmpty) ...[
          SettingsSectionTitle(l.notifModules),
          SettingsCard(
            children: [
              for (final (key, name, sub) in services)
                SettingsRow(
                  label: name,
                  subtitle: sub,
                  trailing: prefs == null
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : SettingsSwitch(
                          value: prefs[key] ?? true,
                          semanticLabel: name,
                          onChanged: (v) => setService(key, v),
                        ),
                ),
            ],
          ),
        ],
        // Discret, en bas : l'autorisation elle-même et les canaux se
        // règlent dans le système, et nulle part ailleurs.
        const SizedBox(height: 8),
        if (kIsWeb)
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.notifications_active_outlined,
                label: l.notifWebEnable,
                subtitle: l.notifWebEnableSub,
                onTap: () async {
                  final enabled = await ref
                      .read(pushServiceProvider)
                      .enableWebPush();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          enabled ? l.notifWebEnabled : l.notifWebEnableFailed,
                        ),
                      ),
                    );
                },
              ),
            ],
          )
        else
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.settings_outlined,
                label: l.notifAndroidSettings,
                subtitle: l.notifAndroidSettingsSub,
                onTap: openAppSettings,
              ),
            ],
          ),
      ],
    );
  }

  /// Une seule sonnerie aujourd'hui, celle de Pokou : la feuille le dit
  /// plutôt que de proposer un choix qui n'existe pas.
  Future<void> _chooseRingtone(BuildContext context) {
    final l = L.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: 'pokou',
              onChanged: (_) => Navigator.pop(sheet),
              child: const RadioListTile<String>(
                value: 'pokou',
                title: Text('Pokou'),
              ),
            ),
            SettingsFootnote(l.notifRingtoneNote),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
