import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/data/marketplace_repository.dart';
import 'package:pokou/features/marketplace/data/product_model.dart';
import 'package:pokou/features/marketplace/data/vitrine.dart';
import 'package:pokou/features/marketplace/presentation/vitrine_viewer.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// La vitrine : des articles du Marché qui défilent d'eux-mêmes, jusqu'à
/// ce qu'on touche celui qui intéresse.

MarketplaceProduct _product(
  int id, {
  int seller = 2,
  bool photo = true,
  bool boosted = false,
}) => MarketplaceProduct.fromJson({
  'id': id,
  'seller_id': seller,
  'name': 'Article $id',
  'price': 1000,
  'is_boosted': boosted,
  if (photo)
    'image': {
      'id': id,
      'mime_type': 'image/jpeg',
      'size_bytes': 10,
      'original_filename': 'p.jpg',
    },
});

class _Catalogue extends Fake implements MarketplaceRepository {
  _Catalogue(this.pages);

  /// Les pages, par décalage.
  final Map<int, PaginatedProducts> pages;
  final asked = <int>[];

  @override
  Future<PaginatedProducts> list({
    int? sellerId,
    String? query,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    int limit = 20,
    int offset = 0,
  }) async {
    asked.add(offset);
    return pages[offset] ?? const PaginatedProducts(items: [], hasMore: false);
  }
}

void main() {
  group('le choix des articles', () {
    test('pas les siens, pas sans photo, les boostés d\'abord', () {
      final picked = pickDiscoveryProducts([
        _product(1),
        _product(2, seller: 1),
        _product(3, photo: false),
        _product(4, boosted: true),
        _product(5),
      ], myUserId: 1);
      expect(picked.map((p) => p.id), [4, 1, 5]);
    });

    test('une page sans article retenu ne termine pas la vitrine', () async {
      final catalogue = _Catalogue({
        0: PaginatedProducts(
          items: [_product(1, seller: 1)],
          hasMore: true,
          nextOffset: 16,
        ),
        16: PaginatedProducts(
          items: [_product(2)],
          hasMore: true,
          nextOffset: 32,
        ),
      });
      final page = await loadVitrinePage(catalogue, myUserId: 1);
      expect(page.items.map((p) => p.id), [2]);
      expect(page.nextOffset, 32);
      expect(catalogue.asked, [0, 16]);
    });

    test('la fin du catalogue se dit', () async {
      final page = await loadVitrinePage(
        _Catalogue({
          0: PaginatedProducts(items: [_product(1)], hasMore: false),
        }),
        myUserId: 9,
      );
      expect(page.nextOffset, isNull);
    });
  });

  group('le défilement', () {
    Future<void> open(
      WidgetTester tester,
      List<MarketplaceProduct> products,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    VitrineViewer.open(context, products: products),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder card(int id) => find.byKey(ValueKey('vitrine-card-$id'));

    testWidgets('les cartes partent seules, puis la vitrine se ferme', (
      tester,
    ) async {
      await open(tester, [_product(1), _product(2)]);
      // Rien que les photos : ni nom, ni prix.
      expect(find.text('Article 1'), findsNothing);
      expect(card(1), findsOneWidget);

      // Un peu au-delà des cinq secondes de la carte, puis son envol.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(VitrineViewer.perProduct);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(card(1), findsNothing);
      expect(card(2), findsOneWidget);

      await tester.pump(VitrineViewer.perProduct);
      await tester.pumpAndSettle();
      expect(find.byType(VitrineViewer), findsNothing);
    });

    testWidgets('écarter vers la gauche passe à la suivante', (tester) async {
      await open(tester, [_product(1), _product(2), _product(3)]);
      await tester.fling(card(1), const Offset(-300, 0), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(card(1), findsNothing);
      expect(card(2), findsOneWidget);
    });

    testWidgets('un geste trop court ramène la carte', (tester) async {
      await open(tester, [_product(1), _product(2)]);
      await tester.timedDrag(
        card(1),
        const Offset(-40, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(card(1), findsOneWidget);
    });

    testWidgets('maintenir le doigt met en pause', (tester) async {
      await open(tester, [_product(1), _product(2)]);
      final gesture = await tester.startGesture(tester.getCenter(card(1)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(VitrineViewer.perProduct * 2);
      expect(card(1), findsOneWidget);
      await gesture.up();
    });

    testWidgets('glisser vers le bas ferme', (tester) async {
      await open(tester, [_product(1), _product(2)]);
      await tester.drag(card(1), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byType(VitrineViewer), findsNothing);
    });
  });
}
