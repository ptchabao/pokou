import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:pokou/features/modules/verses/verse_data.dart';
import 'package:pokou/features/modules/verses/verse_scheduler.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Les modules de versets : 6 h et 18 h, dans la langue de l'application.

class _Scheduled {
  _Scheduled(this.id, this.title, this.body, this.at, this.payload);
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime at;
  final String? payload;
}

class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final Map<int, _Scheduled> pending = {};

  // Aucune implémentation Android en test : le planificateur saute la
  // création du canal, comme sur iOS.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #resolvePlatformSpecificImplementation
      ? null
      : super.noSuchMethod(invocation);

  @override
  Future<void> cancel(int id, {String? tag}) async => pending.remove(id);

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    pending[id] = _Scheduled(id, title, body, scheduledDate, payload);
  }
}

class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async => value == null ? values.remove(key) : values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => values.remove(key);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _MemoryStorage();

  group('les versets embarqués', () {
    for (final kind in VerseKind.values) {
      test(
        '${kind.name} : toutes les langues, le même nombre de versets',
        () async {
          final counts = <String, int>{};
          for (final language in verseLanguages) {
            final verses = await loadVerses(kind, language);
            counts[language] = verses.length;
            for (final verse in verses) {
              expect(
                verse.text.trim(),
                isNotEmpty,
                reason: '$language ${verse.reference}',
              );
              expect(verse.reference.trim(), isNotEmpty);
            }
            if (kind == VerseKind.quran) {
              // L'arabe accompagne toujours la traduction.
              expect(
                verses.every((v) => (v.arabic != null) == (language != 'ar')),
                isTrue,
                reason: language,
              );
            }
          }
          expect(counts.values.toSet(), hasLength(1), reason: '$counts');
        },
      );
    }

    test('une langue inconnue retombe sur le français', () async {
      final verses = await loadVerses(VerseKind.bible, 'de');
      expect(verses.first.reference, startsWith('Psaumes'));
    });
  });

  test('deux versets par jour, sans répétition avant le tour complet', () {
    final seen = <int>{};
    final start = DateTime(2026, 10, 8);
    for (var day = 0; day < 31; day++) {
      for (final slot in [0, 1]) {
        seen.add(verseIndexFor(start.add(Duration(days: day)), slot, 62));
      }
    }
    expect(seen, hasLength(62));
    expect(
      verseIndexFor(DateTime(2026, 10, 8, 6), 0, 62),
      verseIndexFor(DateTime(2026, 10, 8, 23), 0, 62),
      reason: 'le même jour donne le même verset',
    );
  });

  group('la planification', () {
    late _FakePlugin plugin;
    late VerseScheduler scheduler;
    final l = lookupL(const Locale('fr'));

    setUp(() {
      (FlutterSecureStoragePlatform.instance as _MemoryStorage).values.clear();
      plugin = _FakePlugin();
      scheduler = VerseScheduler(
        plugin: plugin,
        ensurePluginReady: () async {},
      );
    });

    test(
      'activer pose les versets de 6 h et 18 h des semaines à venir',
      () async {
        await scheduler.reconcile({'bible_verses', 'heart_league'}, l);

        expect(await scheduler.enabledKinds(), {VerseKind.bible});
        final all = plugin.pending.values.toList();
        expect(all.length, greaterThanOrEqualTo(VerseScheduler.daysAhead * 2));
        for (final n in all) {
          expect([6, 18], contains(n.at.hour));
          expect(n.at.minute, 0);
          expect(n.at.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
          expect(
            n.id - VerseKind.bible.notificationIdBase,
            inInclusiveRange(0, 61),
          );
          expect(n.title, n.at.hour == 6 ? l.versesMorning : l.versesEvening);
          final payload = jsonDecode(n.payload!) as Map<String, dynamic>;
          expect(payload['type'], 'verse');
          expect(payload['kind'], 'bible');
        }
      },
    );

    test(
      'désactiver retire les notifications du module, pas celles de l\'autre',
      () async {
        await scheduler.reconcile({'bible_verses', 'quran_verses'}, l);
        final quranCount = plugin.pending.keys
            .where((id) => id >= VerseKind.quran.notificationIdBase)
            .length;

        await scheduler.reconcile({'quran_verses'}, l);

        expect(
          plugin.pending.keys.where(
            (id) => id < VerseKind.quran.notificationIdBase,
          ),
          isEmpty,
        );
        expect(plugin.pending, hasLength(quranCount));
      },
    );

    test('la langue de l\'application choisit les versets', () async {
      await scheduler.reconcile({'quran_verses'}, lookupL(const Locale('en')));
      expect(
        plugin.pending.values.every((n) => n.body!.contains('— Quran —')),
        isTrue,
      );
    });
  });
}
