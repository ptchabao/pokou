import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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

    return SettingsScaffold(
      title: L.of(context).profileNotifications,
      children: [
        SettingsSectionTitle(L.of(context).notifInApp),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.chat_bubble_outline,
              label: L.of(context).notifMessages,
              subtitle: L.of(context).notifMessagesSub,
              trailing: SettingsSwitch(
                value: settings.messageNotifications,
                semanticLabel: L.of(context).notifMessagesSemantic,
                onChanged: controller.setMessageNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.groups_outlined,
              label: L.of(context).notifGroups,
              subtitle: L.of(context).notifGroupsSub,
              trailing: SettingsSwitch(
                value: settings.groupNotifications,
                semanticLabel: L.of(context).notifGroupsSemantic,
                onChanged: controller.setGroupNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.call_outlined,
              label: L.of(context).navCalls,
              subtitle: L.of(context).notifCallsSub,
              trailing: SettingsSwitch(
                value: settings.callNotifications,
                semanticLabel: L.of(context).notifCallsSemantic,
                onChanged: controller.setCallNotifications,
              ),
            ),
            SettingsRow(
              icon: Icons.volume_up_outlined,
              label: L.of(context).notifSound,
              trailing: SettingsSwitch(
                value: settings.notificationSound,
                semanticLabel: L.of(context).notifSoundSemantic,
                onChanged: controller.setNotificationSound,
              ),
            ),
          ],
        ),
        SettingsFootnote(L.of(context).notifCallsFootnote),
        SettingsSectionTitle(L.of(context).notifSystem),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.android,
              label: L.of(context).notifAndroidSettings,
              subtitle: L.of(context).notifAndroidSettingsSub,
              onTap: openAppSettings,
            ),
          ],
        ),
        SettingsFootnote(L.of(context).notifSystemFootnote),
      ],
    );
  }
}
