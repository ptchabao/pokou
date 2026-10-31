import 'marketplace_repository.dart';
import 'product_model.dart';

/// Une page d'articles pour la vitrine, et où reprendre ensuite.
typedef VitrinePage = ({List<MarketplaceProduct> items, int? nextOffset});

/// Les articles retenus pour la vitrine : ceux des autres, avec une photo,
/// les boostés d'abord (à boost égal, l'ordre du serveur).
List<MarketplaceProduct> pickDiscoveryProducts(
  List<MarketplaceProduct> items, {
  required int? myUserId,
}) {
  final kept = [
    for (final p in items)
      if (p.sellerId != myUserId && p.coverImage != null) p,
  ];
  return [
    ...kept.where((p) => p.isBoosted),
    ...kept.where((p) => !p.isBoosted),
  ];
}

/// Une page de la vitrine, à partir de [offset] dans le catalogue.
///
/// Une page sans article retenu (tous à soi, ou sans photo) ne doit pas
/// arrêter la vitrine : on passe à la suivante, quelques fois au plus.
Future<VitrinePage> loadVitrinePage(
  MarketplaceRepository repository, {
  required int? myUserId,
  int offset = 0,
}) async {
  int? next = offset;
  for (var attempt = 0; attempt < 3 && next != null; attempt++) {
    final page = await repository.list(limit: 16, offset: next);
    next = page.hasMore ? page.nextOffset : null;
    final kept = pickDiscoveryProducts(page.items, myUserId: myUserId);
    if (kept.isNotEmpty) return (items: kept, nextOffset: next);
  }
  return (items: const <MarketplaceProduct>[], nextOffset: null);
}
