import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/settings/app_settings.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_theme.dart';

/// Le mode sombre.
///
/// Il n'existait pas : `themeMode: ThemeMode.light` et — plus révélateur —
/// `darkTheme: AppTheme.light`, c'est-à-dire le thème clair servi comme
/// thème sombre. Pour une messagerie, dont l'usage est largement nocturne,
/// c'était le manque le plus visible de l'application.
///
/// Ces tests portent sur les PROPRIÉTÉS d'une palette sombre, pas sur des
/// valeurs précises : les teintes peuvent être retouchées, mais un fond
/// sombre doit rester sombre et le texte doit rester lisible dessus.

/// Le contraste relatif entre deux couleurs, formule WCAG.
double _contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) {
      v = v / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055 ) * 0 + _pow((v + 0.055) / 1.055, 2.4);
    }

    return 0.2126 * channel((c.r * 255)) +
        0.7152 * channel((c.g * 255)) +
        0.0722 * channel((c.b * 255));
  }

  final la = luminance(a);
  final lb = luminance(b);
  final clair = la > lb ? la : lb;
  final sombre = la > lb ? lb : la;
  return (clair + 0.05) / (sombre + 0.05);
}

double _pow(double x, double e) {
  var result = 1.0;
  // Approximation suffisante pour un seuil de contraste : exp(e * ln(x)).
  if (x <= 0) return 0;
  final lnX = _ln(x);
  var term = 1.0;
  final z = e * lnX;
  for (var n = 1; n <= 30; n++) {
    term *= z / n;
    result += term;
  }
  return result;
}

double _ln(double x) {
  // ln(x) par série, x > 0.
  var y = (x - 1) / (x + 1);
  var y2 = y * y;
  var sum = 0.0;
  var term = y;
  for (var n = 0; n < 40; n++) {
    sum += term / (2 * n + 1);
    term *= y2;
  }
  return 2 * sum;
}

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.light));

  group('la palette bascule vraiment', () {
    test('le fond devient sombre', () {
      AppColors.applyBrightness(Brightness.light);
      final clair = AppColors.background;
      AppColors.applyBrightness(Brightness.dark);
      final sombre = AppColors.background;

      expect(clair, isNot(sombre));
      expect(sombre.computeLuminance(), lessThan(0.15));
      expect(clair.computeLuminance(), greaterThan(0.85));
    });

    test('le texte principal s\'inverse avec lui', () {
      AppColors.applyBrightness(Brightness.dark);

      expect(AppColors.textPrimary.computeLuminance(), greaterThan(0.6));
    });

    test('`isDark` dit la vérité', () {
      AppColors.applyBrightness(Brightness.dark);
      expect(AppColors.isDark, isTrue);
      AppColors.applyBrightness(Brightness.light);
      expect(AppColors.isDark, isFalse);
    });
  });

  group('la lisibilité tient dans les deux modes', () {
    /// Les paires qui se superposent réellement à l'écran.
    List<(String, Color Function(), Color Function())> paires() => [
          ('texte principal / fond', () => AppColors.textPrimary, () => AppColors.background),
          ('texte secondaire / fond', () => AppColors.textSecondary, () => AppColors.background),
          ('texte de bulle reçue', () => AppColors.chatTextReceived, () => AppColors.chatBubbleReceived),
          ('texte de bulle envoyée', () => AppColors.chatTextReceived, () => AppColors.chatBubbleSent),
          ('horodatage sur bulle envoyée', () => AppColors.chatTimestamp, () => AppColors.chatBubbleSent),
          ('encre de marque / fond', () => AppColors.accentPrimaryDark, () => AppColors.background),
        ];

    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final (nom, encre, fond) in paires()) {
        test('$nom — $brightness', () {
          AppColors.applyBrightness(brightness);
          final ratio = _contrast(encre(), fond());

          // 4,5:1 est le seuil AA pour du texte courant. Ces écrans se
          // lisent dehors, en plein soleil, sur des dalles bon marché : ce
          // n'est pas un seuil théorique.
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '$nom : contraste $ratio en $brightness');
        });
      }
    }
  });

  group('les signaux ne changent PAS', () {
    test('le bleu des accusés de lecture est le même partout', () {
      // Le signal le plus universellement compris de l'application. Le
      // teinter différemment selon le thème lui ferait perdre ce qui fait
      // sa valeur : être reconnu sans être appris.
      AppColors.applyBrightness(Brightness.light);
      final clair = AppColors.readReceiptBlue;
      AppColors.applyBrightness(Brightness.dark);

      expect(AppColors.readReceiptBlue, clair);
    });

    test('le vert d\'action est le même partout', () {
      AppColors.applyBrightness(Brightness.light);
      final clair = AppColors.accentPrimary;
      AppColors.applyBrightness(Brightness.dark);

      expect(AppColors.accentPrimary, clair);
    });
  });

  group('les deux thèmes viennent de la même palette', () {
    test('le thème sombre n\'est plus le thème clair', () {
      // Le défaut exact : `darkTheme: AppTheme.light`.
      AppColors.applyBrightness(Brightness.dark);
      final sombre = AppTheme.dark;
      AppColors.applyBrightness(Brightness.light);
      final clair = AppTheme.light;

      expect(sombre.scaffoldBackgroundColor,
          isNot(clair.scaffoldBackgroundColor));
    });

    test('chacun prend le fond de son mode', () {
      AppColors.applyBrightness(Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.background);
    });
  });

  group('le réglage survit à un redémarrage', () {
    test('il se relit tel qu\'il a été écrit', () {
      for (final mode in ThemeMode.values) {
        final relu = AppSettings.fromJson(
          const AppSettings().copyWith(themeMode: mode).toJson(),
        );
        expect(relu.themeMode, mode);
      }
    });

    test('un réglage inconnu retombe sur « comme le téléphone »', () {
      // Écrit par une version future, ou fichier abîmé : une apparence ne
      // doit jamais empêcher l'application de démarrer.
      expect(
        AppSettings.fromJson({'theme_mode': 'nuit-etoilee'}).themeMode,
        ThemeMode.system,
      );
      expect(AppSettings.fromJson({}).themeMode, ThemeMode.system);
    });

    test('le défaut est « comme le téléphone »', () {
      // Quelqu'un qui a réglé son appareil en sombre l'a fait pour toutes
      // ses applications : lui redemander serait lui faire refaire un choix
      // déjà exprimé.
      expect(const AppSettings().themeMode, ThemeMode.system);
    });
  });
}
