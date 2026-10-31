import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../core/push/push_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/module_model.dart';
import '../presentation/module_controller.dart';
import 'verse_scheduler.dart';

final verseSchedulerProvider = Provider<VerseScheduler>((ref) {
  return VerseScheduler(
    // Le greffon est un singleton : c'est la même instance que celle des
    // messages, initialisée une fois par PushService (qui y branche le
    // toucher d'une notification — voir son _handleResponse).
    plugin: FlutterLocalNotificationsPlugin(),
    ensurePluginReady: () => ref.read(pushServiceProvider).initialize(),
  );
});

/// Les slugs activés dans un catalogue.
Set<String> activatedModuleSlugs(ModuleCatalogue catalogue) => {
  for (final module in [
    ...catalogue.mine,
    ...catalogue.recommended,
    ...catalogue.popular,
  ])
    if (module.isActivated) module.slug,
};

/// Garde les versets planifiés, quoi qu'il arrive à l'application.
///
/// Observé depuis `PokouApp` (main.dart), comme les autres synchronisations :
///
/// - **à l'ouverture**, il recharge la réserve de notifications — elle
///   couvre quelques semaines, et chaque ouverture la repousse ;
/// - **quand la langue change**, il replanifie : le texte d'une
///   notification est figé au moment où on la pose ;
/// - **à la connexion**, il relit le catalogue : un module activé sur un
///   autre téléphone, ou avant une réinstallation, se remet à sonner ici.
final verseSyncProvider = Provider<void>((ref) {
  final l = ref.watch(appL10nProvider);
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  final scheduler = ref.read(verseSchedulerProvider);
  unawaited(() async {
    await scheduler.rescheduleAll(l);
    if (userId == null) return;
    try {
      final catalogue = await ref.read(moduleRepositoryProvider).catalogue();
      await scheduler.reconcile(activatedModuleSlugs(catalogue), l);
    } catch (_) {
      // Hors ligne : la réserve locale suffit, on réessaiera.
    }
  }());
});
