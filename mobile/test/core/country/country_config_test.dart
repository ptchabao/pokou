import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/widgets/pokou_bottom_nav.dart';

void main() {
  group('CountryConfig', () {
    test('la réponse du serveur fait foi : aucun module ajouté', () {
      final config = CountryConfig.fromJson({
        'country': 'SN',
        'modules': ['discussions'],
      });

      expect(config.modules, {'discussions'});
      expect(isLot1(config.modules), isTrue);
    });

    test('le repli garde les modules du Togo et de la Côte d\'Ivoire', () {
      for (final config in [
        CountryConfig.guessFromPhone('+22890112233'),
        CountryConfig.guessFromPhone('+2250700112233'),
      ]) {
        expect(config.has('kory'), isTrue);
        expect(config.has('honam'), isTrue);
        expect(isLot1(config.modules), isFalse);
      }
    });

    test('un indicatif inconnu se présente en Lot 1', () {
      for (final config in [
        CountryConfig.guessFromPhone('+221771234567'),
        CountryConfig.guessFromPhone(null),
      ]) {
        expect(config.modules, {'discussions'});
        expect(isLot1(config.modules), isTrue);
      }
    });
  });

  test('la palette claire suit les jetons fournis', () {
    expect(AppColors.background, const Color(0xFFFBF7F2));
    expect(AppColors.surfaceElevated, const Color(0xFFF3EAE1));
    expect(AppColors.actionButtonBackground, const Color(0xFFA4512A));
  });
}
