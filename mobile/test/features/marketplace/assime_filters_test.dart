import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/data/marketplace_repository.dart';

/// La feuille « Filtres » (Assimé 2) : ce qu'elle compte sur la puce et ce
/// qu'elle envoie au serveur.
void main() {
  test('sans critère, rien ne part et la puce ne compte rien', () {
    const filters = MarketFilters();
    expect(filters.count, 0);
    expect(filters.isEmpty, isTrue);
    expect(filters.queryParams, isEmpty);
  });

  test('prix, état et date comptent chacun pour un', () {
    const filters = MarketFilters(
      minPrice: 1000,
      maxPrice: 15000,
      conditions: {'NEW', 'VERY_GOOD'},
      publishedDays: 7,
      sort: 'price_asc',
    );
    expect(filters.count, 3);
    expect(filters.queryParams, [
      'min_price=1000',
      'max_price=15000',
      'condition=NEW,VERY_GOOD',
      'published_days=7',
      'sort=price_asc',
    ]);
  });

  test('changer le tri garde les critères', () {
    const filters = MarketFilters(maxPrice: 5000);
    final sorted = filters.copyWith(sort: 'price_desc');
    expect(sorted.maxPrice, 5000);
    expect(sorted.isEmpty, isFalse);
  });
}
