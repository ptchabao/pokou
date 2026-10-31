import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

/// GET /link-preview?url=… (api/app/routes/link_preview.py) — le serveur
/// récupère titre/description/image Open Graph pour éviter un fetch direct
/// depuis le téléphone (CORS, et surtout pour ne jamais exposer l'IP/les
/// habitudes de navigation de l'utilisateur au site tiers pointé par le
/// lien : c'est TOUJOURS l'API qui va chercher la page, jamais son app).
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.image,
  });

  final String url;
  final String? title;
  final String? description;
  final String? image;

  bool get hasContent => title != null || description != null || image != null;

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
    url: json['url'] as String,
    title: json['title'] as String?,
    description: json['description'] as String?,
    image: json['image'] as String?,
  );
}

final linkPreviewRepositoryProvider = Provider<LinkPreviewRepository>((ref) {
  return LinkPreviewRepository(
    apiClient: ref.watch(apiClientProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
  );
});

class LinkPreviewRepository {
  LinkPreviewRepository({
    required ApiClient apiClient,
    required MediaRepository mediaRepository,
  }) : _api = apiClient,
       _medias = mediaRepository;

  final ApiClient _api;
  final MediaRepository _medias;

  // ── Ce que la session retient ─────────────────────────────────────────
  //
  // La carte créait son `Future` dans `initState`. Une bulle recyclée par
  // `ListView.builder` — c'est-à-dire n'importe quelle bulle qu'on fait
  // sortir puis rentrer à l'écran — recréait son état, donc relançait la
  // requête. Remonter dans une conversation redemandait l'aperçu de chaque
  // lien, à chaque passage.
  //
  // Le serveur garde maintenant son propre cache, ce qui épargne le site
  // tiers ; celui-ci épargne le RÉSEAU du téléphone, qui est la ressource
  // rare ici.
  static final Map<String, LinkPreview> _resolus = {};
  static final Map<String, Future<LinkPreview>> _enCours = {};

  static const _maxResolus = 256;

  /// L'aperçu s'il est déjà connu — sans `Future`, donc utilisable pendant
  /// un `build` : la carte se dessine complète dès la première image de
  /// rendu au lieu d'apparaître après coup.
  LinkPreview? apercuConnu(String url) => _resolus[url];

  Future<LinkPreview> fetch(String url) {
    final deja = _resolus[url];
    if (deja != null) return SynchronousFuture<LinkPreview>(deja);
    return _enCours[url] ??= _recuperer(
      url,
    ).whenComplete(() => _enCours.remove(url));
  }

  Future<LinkPreview> _recuperer(String url) async {
    final response = await _api.get(
      '/link-preview?url=${Uri.encodeQueryComponent(url)}',
    );
    final apercu = LinkPreview.fromJson(response as Map<String, dynamic>);
    if (_resolus.length >= _maxResolus) {
      // Borne grossière mais suffisante : ces objets pèsent quelques
      // centaines d'octets, et une conversation n'a pas des milliers de
      // liens distincts.
      _resolus.remove(_resolus.keys.first);
    }
    _resolus[url] = apercu;
    return apercu;
  }

  /// L'illustration de l'aperçu, TÉLÉCHARGÉE PAR L'API et mise en cache sur
  /// l'appareil.
  ///
  /// La carte l'affichait avec `Image.network(preview.image!)`, c'est-à-dire
  /// que le téléphone allait la chercher lui-même chez le site tiers. Ce
  /// module promet pourtant l'inverse depuis le premier jour — « c'est
  /// TOUJOURS l'API qui va chercher la page, jamais son app » — précisément
  /// pour ne pas livrer au tiers l'adresse IP de l'utilisateur ni l'instant
  /// où il ouvre une conversation. La promesse tenait pour le HTML et
  /// tombait sur l'image.
  ///
  /// Elle passe maintenant par `/link-preview/image`, qui relaie. Et comme
  /// c'est un fichier, il vit dans le cache média : plus de retéléchargement
  /// au défilement, et « vider le cache » le vide aussi.
  Future<File> imageDeLApercu(String url) {
    // SHA-1 de l'URL : un nom de fichier court, sûr, et STABLE d'un
    // lancement à l'autre — contrairement à `hashCode`, que Dart ne
    // garantit pas entre deux exécutions.
    final cle = 'lp_${sha1.convert(utf8.encode(url))}';
    return _medias.fichierSousCle(
      cle,
      () => _api.getBytes(
        '/link-preview/image?url=${Uri.encodeQueryComponent(url)}',
      ),
    );
  }

  @visibleForTesting
  static void viderLeCacheMemoire() {
    _resolus.clear();
    _enCours.clear();
  }
}

/// Carte d'aperçu affichée sous le texte d'un message qui cite un lien —
/// façon WhatsApp/Telegram/iMessage. Se rend invisible d'elle-même (ni
/// espace, ni erreur) si le lien ne se laisse pas résumer : un aperçu
/// manquant ne doit jamais dégrader la lecture du message lui-même.
class LinkPreviewCard extends ConsumerStatefulWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  ConsumerState<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends ConsumerState<LinkPreviewCard> {
  late Future<LinkPreview> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(linkPreviewRepositoryProvider).fetch(widget.url);
  }

  @override
  void didUpdateWidget(covariant LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Une bulle réutilisée par ListView.builder pour un AUTRE message (même
    // position, lien différent) ne doit pas garder l'aperçu du précédent.
    if (oldWidget.url != widget.url) {
      _future = ref.read(linkPreviewRepositoryProvider).fetch(widget.url);
    }
  }

  Future<void> _open() =>
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview>(
      future: _future,
      builder: (context, snapshot) {
        // En cours de chargement ou échoué : rien plutôt qu'un espace vide
        // qui laisserait deviner qu'"il devrait y avoir quelque chose ici".
        if (snapshot.connectionState != ConnectionState.done)
          return const SizedBox.shrink();
        if (snapshot.hasError) return const SizedBox.shrink();
        final preview = snapshot.data;
        if (preview == null || !preview.hasContent)
          return const SizedBox.shrink();

        final onSurface = AppColors.chatTextReceived;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: InkWell(
            onTap: _open,
            borderRadius: AppRadius.card,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.chatBubbleReceived,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.chatBubbleReceivedBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.image != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: _ApercuImage(url: preview.image!),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (preview.title != null)
                          Text(
                            preview.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                              fontSize: 13,
                            ),
                          ),
                        if (preview.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            preview.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          Uri.tryParse(widget.url)?.host ?? widget.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// L'illustration d'un aperçu — relayée par l'API, puis lue depuis le cache
/// média comme n'importe quelle pièce jointe.
///
/// Une image qui échoue ne doit pas casser la carte : le titre et la
/// description restent lisibles, et la bande d'image disparaît simplement.
class _ApercuImage extends ConsumerStatefulWidget {
  const _ApercuImage({required this.url});

  final String url;

  @override
  ConsumerState<_ApercuImage> createState() => _ApercuImageState();
}

class _ApercuImageState extends ConsumerState<_ApercuImage> {
  File? _fichier;
  bool _echec = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(_ApercuImage ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.url != widget.url) {
      _fichier = null;
      _echec = false;
      _charger();
    }
  }

  void _charger() {
    ref
        .read(linkPreviewRepositoryProvider)
        .imageDeLApercu(widget.url)
        .then((f) {
          if (mounted) setState(() => _fichier = f);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _echec = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_echec) return const SizedBox.shrink();
    final fichier = _fichier;
    if (fichier == null) {
      return Container(height: 140, color: AppColors.surfaceElevated);
    }
    return Image.file(
      fichier,
      height: 140,
      width: double.infinity,
      fit: BoxFit.cover,
      // La bande fait 140 points de haut sur toute la largeur : inutile de
      // décoder une illustration de 1 200 points en pleine définition.
      cacheHeight: (140 * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (context, _, _) => const SizedBox.shrink(),
    );
  }
}
