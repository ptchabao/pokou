import 'assime_extras.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Fiche détaillée d'un produit — la tuile de la liste ne menait nulle part.
///
/// La marketplace ne fait que METTRE EN RELATION : aucun paiement n'est
/// encaissé, il n'y a donc pas de panier ni de commande. Les deux actions qui
/// comptent sont « écrire au vendeur » (qui épingle la fiche dans la
/// discussion, pour que l'acheteur n'ait pas à décrire l'article) et
/// « appeler ».
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  final MarketplaceProduct product;

  /// Le `Hero` de la vignette touchée dans la liste : sa photo s'agrandit
  /// jusqu'à la photo principale de la fiche au lieu de disparaître pour
  /// réapparaître. Propre à la liste d'origine (`market-grid-12`…) — un
  /// même produit peut figurer dans deux listes du même écran.
  final Object? heroTag;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  SellerProfile? _seller;
  List<SellerReview>? _reviews;
  bool _contacting = false;
  bool _favorite = false;

  /// Mettre de côté (Assimé 12) : optimiste, puis confirmé.
  Future<void> _toggleFavorite() async {
    final next = !_favorite;
    setState(() => _favorite = next);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .setFavorite(_product.id, next);
      ref.invalidate(favoritesProvider);
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    }
  }

  /// Photo affichée en grand : la principale d'abord, puis celle qu'on
  /// choisit dans la bande de vignettes.
  int _selectedImage = 0;

  /// Le `Hero` de la photo principale quand elle ne vient pas de la liste
  /// (une photo de la galerie choisie dans la bande de vignettes) : c'est
  /// d'elle que part la visionneuse, et vers elle qu'elle revient.
  final Object _ownHeroTag = Object();

  Object _mainHeroTag(int index) =>
      index == 0 && widget.heroTag != null ? widget.heroTag! : _ownHeroTag;

  void _openViewer(List<MediaMeta> images, int index) {
    ImageViewer.open(
      context,
      initialIndex: index,
      images: [
        for (var i = 0; i < images.length; i++)
          ViewerImage(
            // Pleine définition : dans la visionneuse, elle est le sujet.
            full: MediaImage.meta(images[i], fit: BoxFit.contain),
            // La version déjà décodée pour la fiche, le temps du décodage.
            preview: MediaImage.meta(
              images[i],
              fit: BoxFit.contain,
              decodeWidth: _ProductImage.decodeWidth,
            ),
            heroTag: i == index ? _mainHeroTag(index) : null,
          ),
      ],
    );
  }

  MarketplaceProduct get _product => widget.product;

  /// Principale + galerie, dans cet ordre — la principale est celle des
  /// vignettes de liste, elle ouvre donc naturellement la fiche.
  List<MediaMeta> get _images => [
    if (_product.image != null) _product.image!,
    ..._product.gallery,
  ];

  bool get _isMine =>
      _product.sellerId == ref.read(authControllerProvider).user?.id;

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    if (_isMine) return;
    try {
      final favorites = await ref.read(favoritesProvider.future);
      if (mounted)
        setState(() => _favorite = favorites.any((f) => f.id == _product.id));
    } catch (_) {
      // Hors ligne : le cœur reste vide, le geste reste possible.
    }
  }

  Future<void> _loadSeller() async {
    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      final seller = await repository.sellerProfile(_product.sellerId);
      final reviews = await repository.sellerReviews(_product.sellerId);
      if (mounted) {
        setState(() {
          _seller = seller;
          _reviews = reviews;
        });
      }
    } catch (_) {
      // Best-effort : la fiche produit reste lisible sans la réputation du
      // vendeur, ce serait dommage de tout masquer pour ça.
    }
  }

  /// Épingle la fiche dans la conversation avec le vendeur, puis l'ouvre —
  /// c'est le geste central de la mise en relation.
  Future<void> _writeToSeller() async {
    setState(() => _contacting = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .shareProduct(
            productId: _product.id,
            message: L
                .of(context)
                .productInterestedMessage(
                  _product.name,
                  _product.price,
                  _product.currency,
                ),
          );
      final myUserId = ref.read(authControllerProvider).user?.id;
      if (!mounted || myUserId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            myUserId: myUserId,
            contactUserId: _product.sellerId,
            contactName: _seller?.sellerName ?? _product.sellerName,
            product: _product,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).productWriteFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  Future<void> _callSeller({required bool video}) async {
    try {
      final token = await ref.read(callRepositoryProvider).startCall([
        _product.sellerId,
      ], isVideo: video);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: [_product.sellerId],
            startWithVideo: video,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // L'API refuse d'appeler quelqu'un hors du carnet d'adresses —
          // contrairement à l'écriture, qui est ouverte pour permettre la
          // mise en relation.
          SnackBar(content: Text(L.of(context).productCallFirstWrite)),
        );
      }
    }
  }

  Future<void> _rateSeller() async {
    final mine = _reviews?.where((review) => review.isMine).firstOrNull;
    var rating = mine?.rating ?? 5;
    final commentController = TextEditingController(text: mine?.comment ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(builderContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                mine == null
                    ? L.of(context).productRateSeller
                    : L.of(context).productEditReview,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                L.of(context).productReviewScope,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      onPressed: () => setSheetState(() => rating = star),
                      icon: Icon(
                        star <= rating ? Icons.star : Icons.star_border,
                        color: AppColors.accentPrimary,
                      ),

                      tooltip: L.of(context).a11yRate,
                    ),
                ],
              ),
              TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                controller: commentController,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: L.of(context).productReviewHint,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(L.of(context).actionSave),
              ),
              if (mine != null)
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    L.of(context).productDeleteReview,
                    style: const TextStyle(color: AppColors.semanticError),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final comment = commentController.text.trim();
    commentController.dispose();
    if (confirmed == null) return;

    try {
      final repository = ref.read(marketplaceRepositoryProvider);
      if (confirmed) {
        await repository.reviewSeller(
          sellerId: _product.sellerId,
          rating: rating,
          comment: comment.isEmpty ? null : comment,
        );
      } else {
        await repository.deleteMyReview(_product.sellerId);
      }
      await _loadSeller();
      ref.invalidate(marketplaceProductsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // 403 côté API si on tente de se noter soi-même.
          SnackBar(content: Text(L.of(context).productReviewFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final seller = _seller;
    final reviews = _reviews ?? const <SellerReview>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          L.of(context).productTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isMine)
            IconButton(
              tooltip: L.of(context).assimeReportTitle,
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BoostReportScreen(
                    productId: _product.id,
                    productName: _product.name,
                  ),
                ),
              ),
            )
          else ...[
            if (_product.isBoosted)
              IconButton(
                tooltip: L.of(context).assimeWhyTitle,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showWhySponsored(context, ref, _product.id),
              ),
            IconButton(
              tooltip: _favorite
                  ? L.of(context).assimeRemoveFavorite
                  : L.of(context).assimeAddFavorite,
              icon: Icon(
                _favorite ? Icons.favorite : Icons.favorite_border,
                color: _favorite ? AppColors.feedbackDanger : null,
              ),
              onPressed: _toggleFavorite,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isMine
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _contacting ? null : _writeToSeller,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(
                          _contacting
                              ? L.of(context).productOpening
                              : L.of(context).productDiscuss,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _callSeller(video: false),
                      icon: const Icon(Icons.call_outlined),
                      tooltip: L.of(context).productCallAction,
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (images.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final index = _selectedImage.clamp(0, images.length - 1);
                return GestureDetector(
                  onTap: () => _openViewer(images, index),
                  child: Hero(
                    tag: _mainHeroTag(index),
                    child: ClipRRect(
                      borderRadius: AppRadius.card,
                      child: _ProductImage(media: images[index], height: 240),
                    ),
                  ),
                );
              },
            ),
            if (images.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) => InkWell(
                    onTap: () => setState(() => _selectedImage = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == _selectedImage
                              ? AppColors.accentPrimary
                              : AppColors.border,
                          width: index == _selectedImage ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _ProductImage(media: images[index]),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          Text(
            _product.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${_product.price} ${_product.currency}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.accentPrimaryDark,
            ),
          ),
          if (_product.description != null &&
              _product.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _product.description!,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
          const SizedBox(height: 20),
          _SellerCard(
            name: seller?.sellerName ?? _product.sellerName,
            isCertified: seller?.isCertified ?? _product.sellerIsCertified,
            isPro: seller?.isPro ?? _product.sellerIsPro,
            rating: seller?.rating ?? _product.sellerRating,
            reviewCount: seller?.reviewCount ?? _product.sellerReviewCount,
            productCount: seller?.productCount,
            onRate: _isMine ? null : _rateSeller,
          ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              L.of(context).productReviews,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final review in reviews) _ReviewTile(review: review),
          ],
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.name,
    required this.isCertified,
    required this.isPro,
    required this.rating,
    required this.reviewCount,
    required this.productCount,
    required this.onRate,
  });

  final String name;
  final bool isCertified;
  final bool isPro;
  final double? rating;
  final int reviewCount;
  final int? productCount;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accentPrimaryLight,
                child: PokouIcon(
                  PokouModuleIcon.assime,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isCertified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 15),
                        ],
                        if (isPro) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimaryLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      rating == null
                          // Un vendeur sans avis n'est pas un mauvais vendeur :
                          // le dire explicitement vaut mieux qu'un « 0 étoile ».
                          ? L.of(context).productNoReviewYet
                          : L
                                    .of(context)
                                    .productRatingSummary(
                                      rating!.toStringAsFixed(1),
                                      reviewCount,
                                    ) +
                                (productCount == null
                                    ? ''
                                    : L
                                          .of(context)
                                          .productCountSuffix(productCount!)),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCertified) ...[
            const SizedBox(height: 8),
            Text(
              // La certification dit « ce compte est vérifié », pas « ce
              // vendeur est bon » : la note, elle, reste indépendante.
              L.of(context).productCertified,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          if (onRate != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_border, size: 16),
                label: Text(L.of(context).productRateSeller),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final SellerReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.isMine
                      ? L.of(context).productReviewMine
                      : review.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              for (var star = 1; star <= 5; star++)
                Icon(
                  star <= review.rating ? Icons.star : Icons.star_border,
                  size: 13,
                  color: AppColors.accentPrimary,
                ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Photo de produit servie par l'API authentifiée (pas d'URL publique), donc
/// résolue en fichier local comme les autres médias.
class _ProductImage extends ConsumerWidget {
  const _ProductImage({required this.media, this.height});

  final MediaMeta media;
  final double? height;

  /// Pleine largeur : le palier 1080 suffit, l'original pèse dix fois plus.
  static const decodeWidth = 420.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: MediaImage.meta(media, decodeWidth: decodeWidth),
    );
  }
}
