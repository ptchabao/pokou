import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'assime_reviews.dart';
import 'marketplace_controller.dart';
import 'product_detail_screen.dart';

final _sellerProvider = FutureProvider.autoDispose
    .family<(SellerProfile, List<MarketplaceProduct>), int>((
      ref,
      sellerId,
    ) async {
      final repository = ref.watch(marketplaceRepositoryProvider);
      final results = await Future.wait([
        repository.sellerProfile(sellerId),
        repository.sellerProducts(sellerId),
      ]);
      return (
        results[0] as SellerProfile,
        results[1] as List<MarketplaceProduct>,
      );
    });

/// Assimé 22 · le profil d'un vendeur, ouvert depuis son annonce : note et
/// ventes notées, ancienneté, « Message » et « Signaler », ses annonces —
/// vendues comprises, avec « Vendu ».
///
/// Un écran à part de la fiche contact de la messagerie : on y arrive sans
/// avoir le vendeur dans son carnet, et on n'y voit jamais son numéro.
class AssimeSellerProfileScreen extends ConsumerWidget {
  const AssimeSellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  final int sellerId;
  final String sellerName;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketplaceRepositoryProvider).reportSeller(sellerId);
      messenger.showSnackBar(SnackBar(content: Text(l.assimeReportSent)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final data = ref.watch(_sellerProvider(sellerId));
    return ModuleScaffold(
      title: l.assimeProfileTitle,
      child: data.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.marketUnavailable,
          message: l.modulesCheckNetwork,
        ),
        data: (value) {
          final (profile, products) = value;
          final initials = profile.sellerName
              .split(' ')
              .where((p) => p.isNotEmpty)
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();
          final since = profile.memberSince == null
              ? null
              : DateFormat.yMMMM(locale).format(profile.memberSince!.toLocal());
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.terracottaTint,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      profile.sellerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (profile.isCertified) ...[
                    const SizedBox(width: 5),
                    const VerifiedBadge(size: 16),
                  ],
                ],
              ),
              if (since != null)
                Text(
                  profile.isPro
                      ? l.assimeProSince(since)
                      : l.assimePrivateSince(since),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 2),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SellerReviewsScreen(
                      sellerId: sellerId,
                      sellerName: profile.sellerName,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (profile.rating != null) ...[
                      Icon(Icons.star, size: 14, color: AppColors.brandOr),
                      const SizedBox(width: 3),
                      Text(
                        profile.rating!.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Text(' · '),
                    ],
                    Text(
                      [
                        l.assimeRatedSales(profile.reviewCount),
                        if (profile.area != null) profile.area!,
                      ].join(' · '),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (myUserId != sellerId) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(l.assimeMessage),
                        onPressed: myUserId == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    myUserId: myUserId,
                                    contactUserId: sellerId,
                                    contactName: profile.sellerName,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.outlined_flag, size: 18),
                        label: Text(l.assimeReport),
                        onPressed: () => _report(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                l.assimeListingsOf(profile.sellerName, products.length),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [
                  for (final p in products) _SellerListing(product: p),
                ],
              ),
              if (!profile.isPro) ...[
                const SizedBox(height: 12),
                Text(
                  l.assimeBadgeNote,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SellerListing extends StatelessWidget {
  const _SellerListing({required this.product});

  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final image = product.coverImage;
    final sold = product.soldAt != null;
    return InkWell(
      onTap: sold
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: image == null
                      ? ColoredBox(color: AppColors.surfaceElevated)
                      : MediaImage.meta(image, decodeWidth: 180),
                ),
                if (sold)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.assimeSoldBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${product.price} ${product.currency}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (product.location != null)
            Text(
              product.location!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
