import '../../../core/media/media_repository.dart' show MediaMeta;

/// Une publicité EN DIFFUSION, telle que `/marketplace/ads/feed` la renvoie :
/// payée, approuvée par l'équipe, dans sa période.
class MarketplaceAdItem {
  const MarketplaceAdItem({
    required this.id,
    required this.title,
    required this.body,
    required this.placement,
    required this.advertiserId,
    required this.advertiserName,
    this.media,
  });

  final int id;
  final String title;
  final String body;

  /// MARKET (dans le Marché) ou STATUS (dans les Actualités).
  final String placement;
  final int advertiserId;
  final String advertiserName;
  final MediaMeta? media;

  bool get isVideo => media?.mimeType.startsWith('video/') ?? false;

  factory MarketplaceAdItem.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as Map<String, dynamic>?;
    return MarketplaceAdItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      placement: json['placement'] as String? ?? 'MARKET',
      advertiserId: json['advertiser_id'] as int? ?? 0,
      advertiserName: json['advertiser_name'] as String? ?? '',
      media: mediaJson == null ? null : MediaMeta.fromJson(mediaJson),
    );
  }
}
