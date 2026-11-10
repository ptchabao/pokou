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

void main() async {
  app.main();
  c = LiveWidgetController(WidgetsBinding.instance);
  await Future<void>.delayed(const Duration(seconds: 14));
  await tab('Honam');
  await shot('v_honam');
  await tab('Plus');
  await shot('v_plus');
  await tab('Discussions');
  await shot('v_chats');
  print('TOURCMD:dark');
  await Future<void>.delayed(const Duration(seconds: 4));
  await tab('Plus');
  await shot('v_dark_plus');
  await tab('Honam');
  await shot('v_dark_honam');
  print('TOURCMD:light');
  await Future<void>.delayed(const Duration(seconds: 3));
  print('TOURCMD:bigtext');
  await Future<void>.delayed(const Duration(seconds: 4));
  await tab('Accueil');
  await shot('v_big_home');
  await tab('Discussions');
  await shot('v_big_chats');
  print('TOURCMD:normaltext');
  await Future<void>.delayed(const Duration(seconds: 3));
  print('TOUR:END');
}
