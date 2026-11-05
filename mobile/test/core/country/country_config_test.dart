import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/core/theme/app_colors.dart';

void main() {
  group('CountryConfig', () {
    test('Kory et Honam restent ouverts dans la réponse du serveur', () {
      final config = CountryConfig.fromJson({
        'country': 'CI',
        'modules': ['discussions'],
      });

      expect(config.has('kory'), isTrue);
      expect(config.has('honam'), isTrue);
    });

    test('le repli garde Kory et Honam pour tous les indicatifs', () {
      for (final config in [
        CountryConfig.guessFromPhone('+22890112233'),
        CountryConfig.guessFromPhone('+2250700112233'),
        CountryConfig.guessFromPhone('+221771234567'),
        CountryConfig.guessFromPhone(null),
      ]) {
        expect(config.has('kory'), isTrue);
        expect(config.has('honam'), isTrue);
      }
    });
  });

  test('la palette claire suit les jetons fournis', () {
    expect(AppColors.background, const Color(0xFFFFF7EC));
    expect(AppColors.surfaceElevated, const Color(0xFFF2E5D5));
    expect(AppColors.actionButtonBackground, const Color(0xFFA65527));
  });
}
