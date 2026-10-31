import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/l10n/app_locales.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// La traduction de l'application.
///
/// Trois choses s'y cassent sans bruit : une clé oubliée dans une langue
/// (qui retombe alors sur le français sans prévenir), une locale déclarée
/// mais non fournie, et l'arabe qui reste aligné à gauche — traduit mais
/// illisible.
void main() {
  test('les six langues annoncées sont réellement fournies', () {
    final codes = L.supportedLocales.map((locale) => locale.languageCode).toSet();
    expect(codes, {'fr', 'en', 'es', 'it', 'ru', 'ar'});
  });

  testWidgets('chaque langue rend un texte dans SA langue', (tester) async {
    // Le même écran, six fois. Une clé non traduite retomberait sur le
    // français, et ce test le verrait : on compare à une valeur attendue par
    // langue, pas seulement à « non vide ».
    const expected = {
      'fr': 'Annuler',
      'en': 'Cancel',
      'es': 'Cancelar',
      'it': 'Annulla',
      'ru': 'Отмена',
      'ar': 'إلغاء',
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: L.localizationsDelegates,
          home: Builder(
            builder: (context) => Text(L.of(context).actionCancel),
          ),
        ),
      );
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: '« ${entry.key} » ne rend pas sa propre traduction',
      );
    }
  });

  testWidgets("l'arabe passe toute l'interface en droite-à-gauche", (tester) async {
    // Sans `GlobalWidgetsLocalizations`, l'arabe serait traduit mais aligné
    // à gauche — pire que pas d'arabe du tout.
    late TextDirection direction;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('les autres langues restent en gauche-à-droite', (tester) async {
    late TextDirection direction;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(direction, TextDirection.ltr);
  });

  testWidgets('une langue non gérée retombe sur le français', (tester) async {
    // Le japonais n'est pas fourni. Sans repli explicite, Flutter prend la
    // PREMIÈRE locale déclarée — et le générateur les range par ordre
    // alphabétique, donc l'arabe. Un téléphone en japonais aurait ouvert
    // Pokou en arabe, aligné à droite. C'est ce test qui l'a trouvé.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        localeResolutionCallback: appLocaleResolution,
        home: Builder(builder: (context) => Text(L.of(context).actionCancel)),
      ),
    );
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('les pluriels russes suivent leurs trois formes', (tester) async {
    // Le russe distingue 1 / 2-4 / 5+. Une traduction qui les confond se lit
    // comme une faute, pas comme un logiciel.
    late String one;
    late String few;
    late String many;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: Builder(
          builder: (context) {
            final l = L.of(context);
            one = l.chatsGroupCount(1);
            few = l.chatsGroupCount(3);
            many = l.chatsGroupCount(7);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(one, isNot(equals(few)));
    expect(few, isNot(equals(many)));
  });

  test('aucune traduction ne mélange des alphabets étrangers', () {
    // Je m'étais trompé une fois : des idéogrammes chinois s'étaient glissés
    // au milieu d'une phrase russe. Ça ne casse rien — donc rien ne le
    // signale — et ça reste illisible pour celui qui la lit.
    //
    // La vérification lit les .arb DIRECTEMENT plutôt que les getters
    // générés : ceux-ci ne s'énumèrent pas, et c'est la source qu'on veut
    // vérifier, pas sa traduction en Dart.
    const forbidden = {
      'han': r'[\u4e00-\u9fff]',
      'kana': r'[\u3040-\u30ff]',
      'hangul': r'[\uac00-\ud7af]',
    };

    for (final code in ['fr', 'en', 'es', 'it', 'ru', 'ar']) {
      final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      for (final entry in arb.entries) {
        // Les clés `@…` portent des métadonnées, pas du texte affiché.
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        for (final script in forbidden.entries) {
          expect(
            RegExp(script.value).hasMatch(entry.value as String),
            isFalse,
            reason: '$code › ${entry.key} contient des caractères ${script.key}',
          );
        }
      }
    }
  });

  test('les six fichiers portent exactement les mêmes clés', () {
    // Une clé ajoutée dans une seule langue retombe silencieusement sur le
    // français : l'écran reste lisible, et personne ne voit qu'il n'a pas été
    // traduit. C'est la panne la plus discrète de tout ce dispositif.
    Set<String> keysOf(String code) {
      final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      return arb.keys.where((key) => !key.startsWith('@')).toSet();
    }

    final reference = keysOf('fr');
    for (final code in ['en', 'es', 'it', 'ru', 'ar']) {
      final missing = reference.difference(keysOf(code));
      final extra = keysOf(code).difference(reference);
      expect(missing, isEmpty, reason: '$code : clés manquantes $missing');
      expect(extra, isEmpty, reason: '$code : clés en trop $extra');
    }
  });

  test('un paramètre du français se retrouve dans les six langues', () {
    // Un `{count}` oublié dans une seule traduction ne se voit pas à la
    // relecture, et ne casse rien tant que personne n'ouvre l'app dans cette
    // langue : la phrase s'affiche simplement amputée du nombre dont elle
    // parle. C'est le pendant du test de clés identiques, un cran plus bas.
    final placeholder = RegExp(r'\{(\w+)[,}]');

    Map<String, Set<String>> paramsOf(String code) {
      final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      return {
        for (final entry in arb.entries)
          if (!entry.key.startsWith('@') && entry.value is String)
            entry.key: placeholder
                .allMatches(entry.value as String)
                .map((match) => match.group(1)!)
                // `plural` et `other` sont la grammaire d'ICU, pas des
                // paramètres : les langues n'ont pas les mêmes catégories.
                .where((name) => !const {
                      'plural',
                      'select',
                      'other',
                      'zero',
                      'one',
                      'two',
                      'few',
                      'many',
                    }.contains(name))
                .toSet(),
      };
    }

    final reference = paramsOf('fr');
    for (final code in ['en', 'es', 'it', 'ru', 'ar']) {
      final translated = paramsOf(code);
      for (final entry in reference.entries) {
        expect(
          translated[entry.key],
          entry.value,
          reason: '$code › ${entry.key} : paramètres différents du français',
        );
      }
    }
  });
}
