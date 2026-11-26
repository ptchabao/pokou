import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/widgets/pokou_sheet.dart';

// Rendu d'une longue feuille d'actions sur un écran à barre de navigation
// système : POKOU_PREVIEW=<dossier> flutter test test/preview/sheet_preview_test.dart
final _out = Platform.environment['POKOU_PREVIEW'];

/// Échelle des rendus (POKOU_PREVIEW_SCALE=2 pour le site) ; 1 par défaut.
final _scale =
    double.tryParse(Platform.environment['POKOU_PREVIEW_SCALE'] ?? '') ?? 1;
final _key = GlobalKey();

void main() {
  testWidgets('feuille longue au-dessus de la barre système', (tester) async {
    if (_out == null) return;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(top: 120, bottom: 144);
    late BuildContext ctx;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );
    showPokouSheet<void>(
      context: ctx,
      scrollable: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 12; i++)
              ListTile(
                leading: const Icon(Icons.circle_outlined),
                title: Text('Action $i'),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _scale);
      return (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    });
    Directory(_out!).createSync(recursive: true);
    File('$_out/sheet.png').writeAsBytesSync(bytes!);
    // La zone qui défile s'arrête au-dessus de la barre système : aucune
    // action ne peut passer dessous.
    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    expect(scroll.bottom, lessThanOrEqualTo(2000 / 3 - 144 / 3 + 0.01));
  });
}
