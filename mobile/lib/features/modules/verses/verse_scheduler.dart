import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/theme/app_colors.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import 'verse_data.dart';

/// Les heures des versets : 6 h et 18 h, à l'heure du téléphone.
const verseHours = [6, 18];

/// Planifie les notifications des modules de versets, SUR L'APPAREIL.
///
/// ── Pourquoi local ─────────────────────────────────────────────────────
///
/// Le verset de 6 h arrive quand le téléphone se réveille, souvent sans
/// réseau. Un push serveur à heure fixe dépendrait de la connexion, et de
/// l'heure du téléphone que le serveur ne connaît pas. Ici, les versets
/// sont embarqués et les alarmes posées d'avance : rien ne passe par le
/// réseau.
///
/// ── Pourquoi d'avance, et pas une alarme quotidienne ──────────────────
///
/// Une alarme qui se répète montre chaque jour le MÊME texte — celui
/// figé au moment de la planification. Pour un verset différent chaque
/// matin, on pose une notification par moment, sur les semaines qui
/// viennent, et on recharge la réserve à chaque ouverture de l'application.
///
/// Mode inexact : Android peut décaler de quelques minutes pour regrouper
/// les réveils, et n'exige alors aucune permission spéciale. Un verset à
/// 6 h 04 vaut mieux qu'une permission « alarmes exactes » à demander.
class VerseScheduler {
  VerseScheduler({
    required FlutterLocalNotificationsPlugin plugin,
    required Future<void> Function() ensurePluginReady,
    FlutterSecureStorage? storage,
  }) : _plugin = plugin,
       _ensurePluginReady = ensurePluginReady,
       _storage = storage ?? const FlutterSecureStorage();

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<void> Function() _ensurePluginReady;
  final FlutterSecureStorage _storage;

  static const _storageKey = 'pokou_verse_modules';
  static const channelId = 'pokou_verses';

  /// Combien de jours planifier d'avance. iOS plafonne à 64 notifications
  /// en attente pour toute l'application : deux modules × deux moments ×
  /// quinze jours y tiennent.
  static int get daysAhead => Platform.isIOS ? 15 : 30;

  /// La plus grande plage d'identifiants qu'un module puisse occuper.
  static const _maxSlots = 31 * 2;

  bool _timezoneReady = false;

  /// Les modules allumés SUR CET APPAREIL — l'activation vit sur le
  /// serveur, mais les alarmes, elles, sont ici, et doivent pouvoir être
  /// rechargées sans réseau.
  Future<Set<VerseKind>> enabledKinds() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return {};
      final names = (jsonDecode(raw) as List).cast<String>();
      return {
        for (final name in names)
          if (VerseKind.fromName(name) case final kind?) kind,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveEnabled(Set<VerseKind> kinds) => _storage.write(
    key: _storageKey,
    value: jsonEncode([for (final kind in kinds) kind.name]),
  );

  /// Aligne l'appareil sur le catalogue : [activated] contient les slugs
  /// activés côté serveur. Un module éteint ailleurs (un autre téléphone,
  /// l'interrupteur) cesse d'envoyer ici aussi.
  Future<void> reconcile(Set<String> activated, L l) async {
    final wanted = {
      for (final slug in activated)
        if (VerseKind.fromSlug(slug) case final kind?) kind,
    };
    final current = await enabledKinds();
    if (setEquals(wanted, current)) return;
    await _saveEnabled(wanted);
    for (final kind in VerseKind.values) {
      if (wanted.contains(kind)) {
        await schedule(kind, l);
      } else if (current.contains(kind)) {
        await cancel(kind);
      }
    }
  }

  /// Recharge la réserve de tous les modules allumés — à l'ouverture de
  /// l'application, et quand la langue change (le texte d'une notification
  /// est figé au moment où on la planifie).
  Future<void> rescheduleAll(L l) async {
    for (final kind in await enabledKinds()) {
      await schedule(kind, l);
    }
  }

  Future<void> cancel(VerseKind kind) async {
    for (var i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(kind.notificationIdBase + i);
    }
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (exc) {
      // Fuseau inconnu de la base : on retombe sur l'UTC, qui est l'heure
      // de Lomé, d'Abidjan, de Dakar — et un verset décalé vaut mieux
      // qu'aucun.
      debugPrint('[Versets] Fuseau introuvable, UTC: $exc');
    }
    _timezoneReady = true;
  }

  /// Pose les notifications de [kind] sur les jours qui viennent.
  Future<void> schedule(VerseKind kind, L l) async {
    try {
      await _ensurePluginReady();
      await _ensureTimezone();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          l.versesChannel,
          description: l.versesChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );
      await cancel(kind);

      final verses = await loadVerses(kind, l.localeName.split('_').first);
      final now = tz.TZDateTime.now(tz.local);
      var slotNumber = 0;
      for (var day = 0; day <= daysAhead && slotNumber < _maxSlots; day++) {
        for (var slot = 0; slot < verseHours.length; slot++) {
          final at = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + day,
            verseHours[slot],
          );
          if (!at.isAfter(now) || slotNumber >= _maxSlots) continue;
          final verse = verses[verseIndexFor(at, slot, verses.length)];
          final title = slot == 0 ? l.versesMorning : l.versesEvening;
          final body = '${verse.text}\n— ${verse.reference}';
          await _plugin.zonedSchedule(
            kind.notificationIdBase + slotNumber,
            title,
            body,
            at,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channelId,
                l.versesChannel,
                // Sans teinte, Android retombe sur son vert par défaut.
                color: AppColors.accentPrimary,
                channelDescription: l.versesChannelDesc,
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                category: AndroidNotificationCategory.reminder,
                styleInformation: BigTextStyleInformation(
                  body,
                  contentTitle: title,
                ),
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: jsonEncode({
              'type': 'verse',
              'kind': kind.name,
              'slot': slot,
              'day': '${at.year}-${at.month}-${at.day}',
            }),
          );
          slotNumber++;
        }
      }
    } catch (exc) {
      // Un échec ne doit jamais empêcher l'application de démarrer : le
      // module se replanifiera à la prochaine ouverture.
      debugPrint('[Versets] Planification impossible: $exc');
    }
  }
}
