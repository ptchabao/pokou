// Outil de revue de design : lance l'app réelle et NAVIGUE seulement (aucun
// envoi), en annonçant chaque écran dans les journaux (« TOUR:nom ») pour
// qu'un script prenne les captures.  flutter run -t tool/design_tour.dart
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/widgets/pokou_bottom_nav.dart';
import 'package:pokou/main.dart' as app;

late LiveWidgetController c;

Future<void> shot(String name) async {
  await Future<void>.delayed(const Duration(milliseconds: 2500));
  print('TOUR:$name');
  await Future<void>.delayed(const Duration(milliseconds: 3500));
}

Future<void> tab(String label) async {
  final target = find.descendant(
    of: find.byType(PokouBottomNav),
    matching: find.text(label),
  );
  if (target.evaluate().isEmpty) {
    print('TOURMISS:tab $label');
    return;
  }
  await c.tap(target.first);
}

Future<void> scrollDown([double by = 700]) async {
  final s = find.byType(Scrollable);
  if (s.evaluate().isEmpty) return;
  await c.drag(s.first, Offset(0, -by));
}

Future<void> back() async {
  final nav = find.byType(Navigator);
  if (nav.evaluate().isEmpty) return;
  c.state<NavigatorState>(nav.first).maybePop();
}

Future<bool> open(String text, {bool last = false}) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    print('TOURMISS:$text');
    return false;
  }
  await c.tap(last ? f.last : f.first);
  return true;
}

Future<void> tour(String p) async {
  await tab('Discussions');
  await Future<void>.delayed(const Duration(seconds: 1));
  if (await open('Kanle', last: true)) {
    await shot('${p}conversation');
    await back();
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (await open('POKOU 2', last: true)) {
    await shot('${p}group');
    await back();
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await tab('Honam');
  await shot('${p}honam');
  await tab('Plus');
  await shot('${p}plus');
  await scrollDown(500);
  await shot('${p}plus2');
  if (await open('Assimé')) {
    await shot('${p}assime');
    await back();
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await scrollDown(600);
  await shot('${p}plus3');
}

Future<void> statusComposer(String p) async {
  await tab('Discussions');
  await Future<void>.delayed(const Duration(seconds: 1));
  if (!await open('Mon statut')) return;
  await shot('${p}status_empty');
  final field = find.byType(TextField);
  if (field.evaluate().isNotEmpty) {
    c.widget<TextField>(field.first).controller?.text =
        'Bonne fête de Tabaski à toute la famille';
  }
  final palette = find.byIcon(Icons.palette_outlined);
  if (palette.evaluate().isNotEmpty) {
    await c.tap(palette.first);
    await c.tap(palette.first);
    await c.tap(palette.first);
  }
  await shot('${p}status_text');
  final font = find.text('Aa');
  if (font.evaluate().isNotEmpty) await c.tap(font.first);
  if (palette.evaluate().isNotEmpty) {
    await c.tap(palette.first);
    await c.tap(palette.first);
    await c.tap(palette.first);
    await c.tap(palette.first);
  }
  await shot('${p}status_text2');
  await back();
  await Future<void>.delayed(const Duration(seconds: 1));
}

void main() async {
  app.main();
  c = LiveWidgetController(WidgetsBinding.instance);
  await Future<void>.delayed(const Duration(seconds: 14));
  await tab('Accueil');
  await shot('h_home');
  await scrollDown(520);
  await shot('h_home2');
  await statusComposer('h_');
  await tab('Plus');
  await Future<void>.delayed(const Duration(seconds: 1));
  if (await open('Assimé')) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (await open('Publier une annonce')) {
      await shot('h_editor');
      await back();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await back();
  }
  print('TOURCMD:dark');
  await Future<void>.delayed(const Duration(seconds: 4));
  await tab('Accueil');
  await shot('h_dark_home');
  await tab('Honam');
  await shot('h_dark_honam');
  print('TOURCMD:light');
  await Future<void>.delayed(const Duration(seconds: 3));
  print('TOUR:END');
}
