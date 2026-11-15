import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'call_controller.dart';

/// Le moment où le journal d'appels a été regardé pour la dernière fois sur
/// cet appareil. Les appels manqués reçus depuis font la pastille de
/// l'onglet Appels au Lot 1 (maquette p.52).
///
/// Local, comme les réglages de l'appareil (core/settings/app_settings.dart) :
/// avoir vu ses appels manqués sur un téléphone ne les a pas montrés sur
/// l'autre. Rangé dans le même coffre, pour une seule date.
class CallsSeenController extends StateNotifier<DateTime?> {
  CallsSeenController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(null) {
    _load();
  }

  final FlutterSecureStorage _storage;

  static const _key = 'pokou_calls_seen_at';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      final seen = raw == null ? null : DateTime.tryParse(raw);
      if (seen != null) {
        state = seen;
      } else {
        // Première ouverture : l'historique déjà présent sur le compte ne
        // compte pas comme « nouveau ». Seuls les appels manqués à partir
        // de maintenant allument la pastille.
        await markSeen();
      }
    } catch (_) {
      // Coffre illisible : pas de pastille plutôt qu'un démarrage bloqué.
    }
  }

  /// L'onglet Appels vient d'être ouvert : la pastille s'éteint.
  Future<void> markSeen() async {
    final now = DateTime.now();
    state = now;
    try {
      await _storage.write(key: _key, value: now.toIso8601String());
    } catch (_) {}
  }
}

final callsSeenAtProvider =
    StateNotifierProvider<CallsSeenController, DateTime?>(
      (ref) => CallsSeenController(),
    );

/// Le nombre d'appels manqués (entrants, sans réponse) depuis la dernière
/// visite du journal. 0 tant que la date n'est pas chargée.
final unseenMissedCallsProvider = Provider.autoDispose<int>((ref) {
  final seenAt = ref.watch(callsSeenAtProvider);
  if (seenAt == null) return 0;
  final log = ref.watch(callLogProvider).valueOrNull ?? const [];
  return log
      .where(
        (call) =>
            call.direction == 'incoming' &&
            call.status == 'missed' &&
            call.createdAt.isAfter(seenAt),
      )
      .length;
});
