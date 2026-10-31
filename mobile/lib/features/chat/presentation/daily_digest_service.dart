import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../core/mahizu/mahizu_session.dart';
import '../../../l10n/app_localizations.dart';
import '../../shield/presentation/shield_controller.dart';
import '../data/chat_message_model.dart';
import '../data/daily_digest_repository.dart';
import 'chat_controller.dart';

final dailyDigestRepositoryProvider = Provider<DailyDigestRepository>((ref) {
  return DailyDigestRepository(apiClient: ref.watch(mahizuApiClientProvider));
});

/// Le repère qui dit « ce message est le récap d'aujourd'hui ».
///
/// Un emoji seul, et non le titre traduit : sinon, changer de langue en
/// milieu de journée ferait republier un récap déjà posté, puisque le
/// préfixe cherché ne correspondrait plus à celui écrit le matin.
const _digestMarker = '📋';

/// Récap de fin de journée livré dans le chat général Mahizu (monitorId 0)
/// — pas un vrai déclencheur serveur à heure fixe (l'app n'a pas de tâche
/// d'arrière-plan pour ça), mais une vérification faite à chaque ouverture
/// de l'app après une certaine heure : au plus une fois par jour, dès la
/// prochaine fois que l'utilisateur ouvre Pokou ce soir-là.
class DailyDigestService {
  DailyDigestService(this._ref);

  final Ref _ref;

  static const _cutoffHour = 18;

  Future<void> maybeShowDigest() async {
    if (DateTime.now().hour < _cutoffHour) return;
    // Le bilan vient de Mahizu : sans compte rattaché, il n'y a rien à demander.
    if (!_ref.read(mahizuSessionProvider).isConnected) return;

    final store = _ref.read(chatLocalStoreProvider);
    final today = DateTime.now();
    final history = await store.forMonitor(0);
    final alreadyShownToday = history.any(
      (m) =>
          m.role == ChatRole.assistant &&
          m.content.startsWith(_digestMarker) &&
          _isSameDay(m.createdAt, today),
    );
    if (alreadyShownToday) return;

    DailyDigest digest;
    try {
      digest = await _ref.read(dailyDigestRepositoryProvider).fetch();
    } catch (_) {
      // Best-effort — retente à la prochaine ouverture de l'app.
      return;
    }

    final deferredToday = _ref
        .read(shieldControllerProvider.notifier)
        .todayDeferredCount;
    if (digest.isEmpty && deferredToday == 0) return;

    await store.insert(
      ChatMessage(
        monitorId: 0,
        role: ChatRole.assistant,
        content: _formatDigest(
          _ref.read(appL10nProvider),
          digest,
          deferredToday,
        ),
        createdAt: today,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDigest(L l, DailyDigest digest, int deferredToday) {
    final lines = <String>['$_digestMarker ${l.digestTitle}'];

    if (digest.unreadMessages.isNotEmpty) {
      lines.add('');
      lines.add('💬 ${l.digestUnread}');
      for (final u in digest.unreadMessages) {
        lines.add('• ${u.contactName} (${u.count})');
      }
    }

    if (digest.missedCalls.isNotEmpty) {
      lines.add('');
      lines.add('📞 ${l.digestMissedCalls}');
      for (final c in digest.missedCalls) {
        lines.add('• ${c.contactName}${c.isVideo ? l.digestVideoSuffix : ''}');
      }
    }

    if (deferredToday > 0) {
      lines.add('');
      lines.add('🛡️ ${l.digestShieldDeferred(deferredToday)}');
    }

    if (digest.monitorSignalsCount > 0) {
      lines.add('');
      lines.add('📊 ${l.digestMonitorSignals(digest.monitorSignalsCount)}');
    }

    if (lines.length == 1) {
      lines.add('');
      lines.add(l.digestNothing);
    }

    return lines.join('\n');
  }
}

final dailyDigestServiceProvider = Provider<DailyDigestService>(
  (ref) => DailyDigestService(ref),
);
