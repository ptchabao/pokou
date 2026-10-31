import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/data/ad_model.dart';

void main() {
  test('une publicité du fil porte son annonceur', () {
    final ad = MarketplaceAdItem.fromJson({
      'id': 3,
      'title': 'Promo',
      'body': 'Offre',
      'placement': 'MARKET',
      'advertiser_id': 42,
      'advertiser_name': 'Kodjo',
      'media': null,
      'expires_at': '2026-10-08T10:00:00',
    });
    expect(ad.advertiserId, 42);
    expect(ad.advertiserName, 'Kodjo');
    expect(ad.media, isNull);
    expect(ad.isVideo, isFalse);
  });

  test('une vidéo se reconnaît à son type', () {
    final ad = MarketplaceAdItem.fromJson({
      'id': 4,
      'title': 'Clip',
      'body': '',
      'placement': 'STATUS',
      'advertiser_id': 1,
      'advertiser_name': 'A',
      'media': {
        'id': 9,
        'mime_type': 'video/mp4',
        'size_bytes': 1000,
        'original_filename': 'clip.mp4',
      },
    });
    expect(ad.isVideo, isTrue);
    expect(ad.placement, 'STATUS');
  });
}
