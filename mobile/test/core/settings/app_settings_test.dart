import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/settings/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('tout est activé par défaut, sauf l\'économie de données', () {
      const settings = AppSettings();
      expect(settings.messageNotifications, isTrue);
      expect(settings.groupNotifications, isTrue);
      expect(settings.callNotifications, isTrue);
      expect(settings.notificationSound, isTrue);
      // Un mode qui dégraderait les photos sans qu'on l'ait demandé serait
      // une mauvaise surprise, pas une économie.
      expect(settings.dataSaver, isFalse);
    });

    test('une clé absente retombe sur son défaut', () {
      // Réglages écrits par une version antérieure : les champs ajoutés
      // depuis ne doivent pas arriver à null ni tout réinitialiser.
      final settings = AppSettings.fromJson({'data_saver': true});
      expect(settings.dataSaver, isTrue);
      expect(settings.messageNotifications, isTrue);
      expect(settings.notificationSound, isTrue);
    });

    test('sérialise et relit à l\'identique', () {
      const original = AppSettings(
        messageNotifications: false,
        groupNotifications: true,
        callNotifications: false,
        notificationSound: false,
        dataSaver: true,
      );
      final round = AppSettings.fromJson(original.toJson());
      expect(round.messageNotifications, isFalse);
      expect(round.groupNotifications, isTrue);
      expect(round.callNotifications, isFalse);
      expect(round.notificationSound, isFalse);
      expect(round.dataSaver, isTrue);
    });

    test('copyWith ne touche que le champ demandé', () {
      const original = AppSettings();
      final next = original.copyWith(dataSaver: true);
      expect(next.dataSaver, isTrue);
      expect(next.messageNotifications, isTrue);
      expect(next.callNotifications, isTrue);
    });

    test("l'économie de données compresse davantage les photos envoyées", () {
      expect(const AppSettings().imageUploadQuality, 85);
      expect(const AppSettings(dataSaver: true).imageUploadQuality, 55);
    });
  });
}
