import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/sync/offline_list.dart';

/// Une bannière du carrousel de l'accueil — une publicité ou une annonce,
/// choisie par le serveur pour la zone de la personne (pays de son numéro,
/// région si on la connaît). Gérée depuis la console : rien n'est codé ici.
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    this.label,
    this.body,
    this.image,
    this.ctaLabel,
    this.ctaUrl,
  });

  final int id;
  final String title;

  /// La petite ligne au-dessus du titre : l'annonceur, ou « Sponsorisé ».
  final String? label;
  final String? body;
  final MediaMeta? image;
  final String? ctaLabel;

  /// `https://…` ou `app:kory`, `app:honam`, `app:assime`.
  final String? ctaUrl;

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    return HomeBanner(
      id: json['id'] as int,
      title: json['title'] as String,
      label: json['label'] as String?,
      body: json['body'] as String?,
      image: image is Map<String, dynamic> ? MediaMeta.fromJson(image) : null,
      ctaLabel: json['cta_label'] as String?,
      ctaUrl: json['cta_url'] as String?,
    );
  }
}

/// Les bannières de ma zone. Le cache d'abord : l'accueil s'ouvre avec le
/// carrousel de la dernière fois, puis le serveur le met à jour.
final homeBannersProvider = StreamProvider.autoDispose<List<HomeBanner>>((ref) {
  final api = ref.watch(apiClientProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'home_banners',
    fetch: () async {
      final response = await api.get('/home/banners');
      return (response as Map<String, dynamic>)['items'] as List;
    },
    parse: HomeBanner.fromJson,
  );
});
