import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/push/push_service.dart';
import '../../../core/settings/app_settings.dart';
import 'settings_widgets.dart';

/// Profil > Notifications. Ces interrupteurs gouvernent les notifications que
/// POKOU construit lui-même, c'est-à-dire celles qui arrivent app ouverte
/// (voir PushService._showForegroundNotification). App fermée, c'est Android
/// qui affiche la notification FCM sans exécuter le moindre code de l'app :
/// seuls les réglages système peuvent l'en empêcher, d'où le raccourci vers
/// eux en bas d'écran — et la note qui le dit, plutôt qu'un interrupteur qui
/// mentirait sur sa portée.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    final l = L.of(context);
    return SettingsScaffold(
      title: l.profileNotifications,
      children: [
        SettingsSectionTitle(l.notifInApp),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.chat_bubble_outline,
              label: l.notifMessages,
              subtitle: l.notifMessagesSub,
              trailing: SettingsSwitch(
                value: settings.messageNotifications,
                semanticLabel: l.notifMessagesSemantic,
                onChanged: controller.setMessageNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.groups_outlined,
              label: l.notifGroups,
              subtitle: l.notifGroupsSub,
              trailing: SettingsSwitch(
                value: settings.groupNotifications,
                semanticLabel: l.notifGroupsSemantic,
                onChanged: controller.setGroupNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.call_outlined,
              label: l.navCalls,
              subtitle: l.notifCallsSub,
              trailing: SettingsSwitch(
                value: settings.callNotifications,
                semanticLabel: l.notifCallsSemantic,
                onChanged: controller.setCallNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.volume_up_outlined,
              label: l.notifSound,
              trailing: SettingsSwitch(
                value: settings.notificationSound,
                semanticLabel: l.notifSoundSemantic,
                onChanged: controller.setNotificationSound,
              ),
            ),
          ],
        ),
        SettingsFootnote(l.notifCallsFootnote),
        SettingsSectionTitle(l.notifSystem),
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
                icon: Icons.android,
                label: l.notifAndroidSettings,
                subtitle: l.notifAndroidSettingsSub,
                onTap: openAppSettings,
              ),
            ],
          ),
        if (!kIsWeb) SettingsFootnote(l.notifSystemFootnote),
      ],
    );
  }
}
