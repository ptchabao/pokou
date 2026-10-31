import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/push/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/devices_repository.dart';
import 'settings_widgets.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  return DevicesRepository(apiClient: ref.watch(apiClientProvider));
});

/// Jeton FCM de CET appareil.
///
/// Il sert à se reconnaître dans la liste, et surtout à répondre à la seule
/// question que cet écran doit trancher : est-ce que CE téléphone-ci peut
/// recevoir une notification ? `null` veut dire non — et c'était jusqu'ici
/// indiscernable d'une liste vide, qui se lit « aucun appareil enregistré »
/// alors que le vrai problème est local.
final _currentPushTokenProvider = FutureProvider<String?>((ref) async {
  try {
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
});

final devicesProvider = FutureProvider.autoDispose<List<PokouDevice>>((
  ref,
) async {
  final currentToken = await ref.watch(_currentPushTokenProvider.future);
  return ref.watch(devicesRepositoryProvider).list(currentToken: currentToken);
});

/// Profil > Appareils connectés.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    PokouDevice device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).devicesRemoveTitle),
        content: Text(
          device.isCurrent
              ? L.of(context).devicesRemoveCurrentBody
              : L.of(context).devicesRemoveOtherBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).devicesRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(devicesRepositoryProvider).revoke(device.id);
      ref.invalidate(devicesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).devicesRemoveFailed)),
        );
      }
    }
  }

  /// Relance l'enregistrement du jeton depuis l'écran.
  ///
  /// Sans ce bouton, un appareil qui a raté son enregistrement au démarrage
  /// le reste jusqu'à la réinstallation : rien, dans l'application, ne
  /// permettait de réessayer.
  Future<void> _retryRegistration(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = L.of(context).devicesRetryDone;
    final failed = L.of(context).devicesRetryFailed;

    await ref.read(pushServiceProvider).registerCurrentToken();
    ref.invalidate(_currentPushTokenProvider);
    ref.invalidate(devicesProvider);

    final ok = await ref.read(_currentPushTokenProvider.future) != null;
    messenger.showSnackBar(SnackBar(content: Text(ok ? done : failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return SettingsScaffold(
      title: L.of(context).devicesTitle,
      onRefresh: () async {
        ref.invalidate(devicesProvider);
        await ref.read(devicesProvider.future);
      },
      children: [
        // Ce que cet écran doit dire en premier : est-ce que CE téléphone
        // reçoit les notifications ? Le reste de la liste concerne les
        // autres appareils, et ne répond pas à cette question.
        if (ref.watch(_currentPushTokenProvider).valueOrNull == null)
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.notifications_off_outlined,
                label: L.of(context).devicesNoPushHere,
                subtitle: L.of(context).devicesNoPushHereBody,
                onTap: () => _retryRegistration(context, ref),
                trailing: Icon(
                  Icons.refresh,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        devicesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SettingsFootnote(L.of(context).devicesUnavailable),
          data: (devices) => devices.isEmpty
              ? SettingsFootnote(L.of(context).devicesEmpty)
              : SettingsCard(
                  children: [
                    for (final device in devices)
                      SettingsRow(
                        icon: _platformIcon(device.platform),
                        label:
                            _platformLabel(L.of(context), device.platform) +
                            (device.isCurrent
                                ? L.of(context).devicesThisDevice
                                : ''),
                        subtitle: L
                            .of(context)
                            .devicesLastSeen(
                              _formatDate(L.of(context), device.lastSeenAt),
                              device.tokenHint,
                            ),
                        onTap: () => _revoke(context, ref, device),
                        trailing: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
        ),
        SettingsFootnote(L.of(context).devicesFootnote),
      ],
    );
  }
}

IconData _platformIcon(String platform) => switch (platform) {
  'ios' => Icons.phone_iphone,
  'web' => Icons.language,
  _ => Icons.phone_android,
};

String _platformLabel(L l, String platform) => switch (platform) {
  'ios' => 'iPhone',
  'web' => l.devicesBrowser,
  'android' => 'Android',
  _ => platform,
};

/// Motifs numériques et `DateFormat.Hm()` uniquement : le reste de l'app ne
/// charge pas les données de locale (pas d'initializeDateFormatting), et un
/// motif à mois nommé lèverait une LocaleDataException à l'exécution.
String _formatDate(L l, DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return l.devicesTodayAt(DateFormat.Hm().format(local));
  }
  return DateFormat('d/M/y').format(local);
}
