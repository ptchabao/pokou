import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/page_transitions.dart';
import 'package:pokou/core/widgets/image_viewer.dart';

/// La visionneuse plein écran : elle s'ouvre depuis la vignette, se ferme
/// d'un glissement, et zoome au double toucher.

const _thumbTag = 'photo-1';

Widget _app() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: GestureDetector(
          key: const Key('vignette'),
          onTap: () => ImageViewer.open(
            context,
            images: const [
              ViewerImage(
                full: ColoredBox(key: Key('photo'), color: Colors.red),
                heroTag: _thumbTag,
              ),
              ViewerImage(full: ColoredBox(key: Key('photo2'), color: Colors.blue)),
            ],
          ),
          child: const Hero(
            tag: _thumbTag,
            child: SizedBox(width: 80, height: 80, child: ColoredBox(color: Colors.red)),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.byKey(const Key('vignette')));
  await tester.pumpAndSettle();
  expect(find.byType(ImageViewer), findsOneWidget);
}

void main() {
  testWidgets('un long glissement vers le bas ferme', (tester) async {
    await _open(tester);
    await tester.drag(find.byKey(const Key('photo')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewer), findsNothing);
  });

  testWidgets('un glissement trop court ramène la photo', (tester) async {
    await _open(tester);
    // Lent, pour ne pas compter comme un geste vif.
    await tester.timedDrag(
      find.byKey(const Key('photo')),
      const Offset(0, 40),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewer), findsOneWidget);
    final moved = tester.widget<Transform>(
      find.ancestor(of: find.byType(PageView), matching: find.byType(Transform)).first,
    );
    expect(moved.transform.getTranslation().y, 0);
  });

  testWidgets('le double toucher zoome, puis revient', (tester) async {
    await _open(tester);
    final viewer = find.byType(InteractiveViewer).first;
    Matrix4 matrix() =>
        tester.widget<InteractiveViewer>(viewer).transformationController!.value;

    await tester.tap(find.byKey(const Key('photo')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('photo')));
    await tester.pumpAndSettle();
    expect(matrix().getMaxScaleOnAxis(), closeTo(2.5, 0.01));

    // Zoomé, un glissement déplace la photo : il ne ferme pas.
    await tester.drag(find.byKey(const Key('photo')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewer), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('photo')));
    await tester.pumpAndSettle();
    expect(matrix().getMaxScaleOnAxis(), closeTo(1, 0.01));
  });

  testWidgets('plusieurs photos se parcourent latéralement', (tester) async {
    await _open(tester);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.fling(find.byKey(const Key('photo')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byKey(const Key('photo2')), findsOneWidget);
  });

  testWidgets('le thème remplace le zoom par le glissement court', (tester) async {
    expect(
      pokouPageTransitionsTheme.builders[TargetPlatform.android],
      isA<PokouPageTransitionsBuilder>(),
    );
    // Et l'écran poussé arrive bien à sa place.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: pokouPageTransitionsTheme),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('suivant')),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('suivant')).dx, 0);
  });
}
