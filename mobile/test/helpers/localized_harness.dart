import 'package:flutter/material.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Un `MaterialApp` de test qui porte les traductions.
///
/// Depuis que les widgets lisent leurs libellés dans `L.of(context)`, un
/// `MaterialApp` nu les fait planter : `L.of` renvoie `null`, et le `!`
/// généré lève. Le harnais doit donc ressembler à l'application, pas à la
/// version minimale qui suffisait quand tout était écrit en dur.
///
/// La langue par défaut est le français : c'est celle dans laquelle les
/// assertions de ces tests sont écrites. Sans elle, le harnais prendrait la
/// locale de la machine de test et les libellés attendus changeraient d'une
/// machine à l'autre.
Widget localizedHarness(Widget child, {Locale locale = const Locale('fr')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: child),
    );
