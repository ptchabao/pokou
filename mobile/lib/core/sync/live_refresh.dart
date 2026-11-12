import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/calls/presentation/call_controller.dart';
import '../../features/calls/presentation/call_session.dart';
import '../../features/communities/presentation/community_controller.dart';
import '../../features/contacts/presentation/discussions_controller.dart';
import '../../features/notifications/presentation/notifications_center_screen.dart';
import '../../features/status/presentation/status_controller.dart';
import '../providers.dart';
import 'pokou_sync_engine.dart';

/// Ce qui tient les écrans à jour sans qu'on y touche — là où aucun
/// contrôleur d'écran ne le fait déjà.
///
/// Audit du 11 novembre 2026 : plusieurs écrans ne se rechargeaient qu'à
/// leur ouverture ou en tirant vers le bas.
///
/// - **Le socket lui-même.** Au retour au premier plan après une vraie
///   absence, il est rouvert ([WsClient.resume]) : le système suspend les
///   sockets en arrière-plan sans le dire, et un socket mort ne livrait
///   plus rien. La réouverture déclenche le rattrapage de PokouSyncEngine,
///   donc la relecture de toutes les listes branchées sur les événements.
/// - **Le journal d'appels** : relu à chaque signal d'appel, à la fin de
///   l'appel local, à la reconnexion et au retour au premier plan — un appel
///   manqué pendant qu'on était ailleurs y apparaît sans rien faire.
/// - **Le bandeau « Appel en cours »** des groupes : relu aux mêmes moments.
/// - **La cloche** : relue quand une cagnotte ou une commande bouge, à la
///   reconnexion et au retour.
/// - **Les identités** : un contact qui change de nom ou de photo met aussi
///   à jour les statuts, le journal d'appels et les communautés.
/// - **Mon propre profil**, au retour d'une longue absence.
final liveRefreshProvider = Provider<void>((ref) {
  final ws = ref.watch(wsClientProvider);

  void refreshCalls() {
    ref.invalidate(callLogProvider);
    ref.invalidate(activeGroupCallProvider);
  }

  void refreshBell() => ref.invalidate(serviceNotificationsProvider);

  listenDurableEventTypes(ref, (type) {
    switch (type) {
      case 'call:invite' || 'call:accept' || 'call:decline' || 'call:end':
        refreshCalls();
      case 'kory:updated' ||
          'honam:order_updated' ||
          'group:invitation' ||
          'contact:registered':
        refreshBell();
      case 'user:profile_updated':
        ref.invalidate(statusFeedProvider);
        ref.invalidate(callLogProvider);
        ref.invalidate(myCommunitiesProvider);
    }
  });

  // L'appel local vient de se terminer : il est dans le journal.
  void onActiveCall() {
    if (activeCall.value == null) refreshCalls();
  }

  activeCall.addListener(onActiveCall);

  var everConnected = false;
  final connection = ws.connectionChanges.listen((connected) {
    if (!connected) return;
    // La toute première connexion suit le chargement initial des écrans :
    // rien à relire. Les suivantes sont des RETOURS.
    if (everConnected) {
      refreshCalls();
      refreshBell();
    }
    everConnected = true;
  });

  DateTime? leftAt;
  final lifecycle = AppLifecycleListener(
    onHide: () => leftAt ??= DateTime.now(),
    onPause: () => leftAt ??= DateTime.now(),
    onResume: () {
      final away = leftAt == null
          ? Duration.zero
          : DateTime.now().difference(leftAt!);
      leftAt = null;
      if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return;
      }
      unawaited(ws.resume(away));
      refreshCalls();
      refreshBell();
      if (away >= const Duration(minutes: 1)) {
        // Le socket rouvert rattrape les événements ; ces deux-là n'en ont
        // pas (mon profil, les compteurs de non-lus).
        ref.invalidate(discussionsProvider);
        unawaited(ref.read(authControllerProvider.notifier).reloadProfile());
      }
    },
  );

  ref.onDispose(() {
    activeCall.removeListener(onActiveCall);
    connection.cancel();
    lifecycle.dispose();
  });
});
