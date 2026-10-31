import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/data/product_model.dart';

void main() {
  group('MarketplaceProduct.fromJson', () {
    test('lit image principale, galerie ordonnée, note et certification', () {
      final product = MarketplaceProduct.fromJson({
        'id': 7,
        'seller_id': 3,
        'seller_name': 'Fatou',
        'seller_is_certified': true,
        'seller_rating': 4.5,
        'seller_review_count': 12,
        'name': 'Sac de ciment',
        'description': '50 kg',
        'price': '4500',
        'currency': 'XOF',
        'image': {'id': 1, 'mime_type': 'image/jpeg', 'size_bytes': 100},
        'gallery': [
          {'id': 2, 'mime_type': 'image/jpeg', 'size_bytes': 200},
          {'id': 3, 'mime_type': 'image/jpeg', 'size_bytes': 300},
        ],
        'is_active': true,
      });

      expect(product.image!.id, 1);
      expect(product.gallery.map((m) => m.id), [2, 3]);
      expect(product.sellerIsCertified, isTrue);
      expect(product.sellerRating, 4.5);
      expect(product.sellerReviewCount, 12);
    });

    test('allImages met la principale en tête, puis la galerie', () {
      final product = MarketplaceProduct.fromJson({
        'id': 1,
        'seller_id': 1,
        'name': 'X',
        'price': '1',
        'image': {'id': 10, 'mime_type': 'image/jpeg', 'size_bytes': 1},
        'gallery': [
          {'id': 11, 'mime_type': 'image/jpeg', 'size_bytes': 1},
        ],
      });
      expect(product.allImages.map((m) => m.id), [10, 11]);
    });

    test('une note ronde renvoyée en entier ne casse pas le parsing', () {
      // Le serveur renvoie la moyenne comme nombre JSON : 4 (int) pour une
      // note ronde, 4.5 (double) sinon — `as double?` planterait sur le
      // premier cas.
      final product = MarketplaceProduct.fromJson({
        'id': 1,
        'seller_id': 1,
        'name': 'X',
        'price': '1',
        'seller_rating': 4,
      });
      expect(product.sellerRating, 4.0);
    });

    test("aucun avis laisse la note à null, jamais à 0", () {
      // 0 serait la pire note possible ; l'absence d'avis doit rester
      // distinguable pour que l'écran écrive « pas encore d'avis ».
      final product = MarketplaceProduct.fromJson({
        'id': 1,
        'seller_id': 1,
        'name': 'X',
        'price': '1',
      });
      expect(product.sellerRating, isNull);
      expect(product.sellerReviewCount, 0);
      expect(product.sellerIsCertified, isFalse);
      expect(product.gallery, isEmpty);
      expect(product.allImages, isEmpty);
    });
  });

  group('SellerProfile / SellerReview', () {
    test('fiche vendeur complète', () {
      final profile = SellerProfile.fromJson({
        'seller_id': 5,
        'seller_name': 'Koffi',
        'is_certified': true,
        'certified_at': '2026-09-07T10:00:00',
        'rating': 3,
        'review_count': 2,
        'product_count': 8,
      });
      expect(profile.isCertified, isTrue);
      expect(profile.rating, 3.0);
      expect(profile.productCount, 8);
    });

    test('avis avec is_mine résolu côté serveur', () {
      final review = SellerReview.fromJson({
        'id': 1,
        'seller_id': 5,
        'author_id': 9,
        'author_name': 'Ama',
        'rating': 5,
        'comment': 'Très bien',
        'created_at': '2026-09-07T10:00:00',
        'is_mine': true,
      });
      expect(review.rating, 5);
      expect(review.isMine, isTrue);
      expect(review.comment, 'Très bien');
    });
  });
}
