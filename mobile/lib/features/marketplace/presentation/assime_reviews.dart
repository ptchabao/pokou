import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';

final _sellerReviewsProvider = FutureProvider.autoDispose
    .family<SellerReviews, int>(
      (ref, sellerId) =>
          ref.watch(marketplaceRepositoryProvider).sellerReviewsFull(sellerId),
    );

/// Le libellé d'un point fort (ANN-19), partagé avec « Noter la
/// transaction ».
String assimeTagLabel(L l, String tag) => switch (tag) {
  'as_described' => l.annTagAsDescribed,
  'punctual' => l.annTagPunctual,
  'fair_price' => l.annTagFairPrice,
  'friendly' => l.annTagFriendly,
  _ => l.annTagCommunication,
};

/// Assimé 21 · Avis sur un vendeur : note moyenne et histogramme, points
/// forts, avis datés avec la réponse du vendeur, « Signaler un avis ».
class SellerReviewsScreen extends ConsumerWidget {
  const SellerReviewsScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  final int sellerId;
  final String sellerName;

  Future<void> _reply(
    BuildContext context,
    WidgetRef ref,
    SellerReview review,
  ) async {
    final l = L.of(context);
    final controller = TextEditingController(text: review.sellerReply ?? '');
    final text = await showModuleSheet<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleSheetTitle(l.assimeReplyAction),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(hintText: l.assimeReplyHint),
          ),
          ModuleActionButton(
            label: l.actionSave,
            onPressed: () => Navigator.of(sheetContext).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .replyToReview(review.id, text.trim());
      ref.invalidate(_sellerReviewsProvider(sellerId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
      }
    }
  }

  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    List<SellerReview> reviews,
  ) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final review = await showModuleSheet<SellerReview>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleSheetTitle(l.assimeReportReview),
          for (final r in reviews.where((r) => !r.isMine))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.authorName),
              subtitle: Text(
                r.comment ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(sheetContext).pop(r),
            ),
        ],
      ),
    );
    if (review == null) return;
    try {
      await ref.read(marketplaceRepositoryProvider).reportReview(review.id);
      messenger.showSnackBar(SnackBar(content: Text(l.assimeReviewReported)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isMe = ref.watch(authControllerProvider).user?.id == sellerId;
    final data = ref.watch(_sellerReviewsProvider(sellerId));
    return ModuleScaffold(
      title: l.assimeReviewsTitle(sellerName),
      subtitle: data.valueOrNull == null
          ? null
          : l.assimeReviewsCount(data.valueOrNull!.reviewCount),
      child: data.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
        data: (reviews) => reviews.items.isEmpty
            ? ModuleEmptyState(
                icon: Icons.star_border,
                title: l.productNoReviewYet,
                message: l.assimeNoReviews,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _Summary(reviews: reviews),
                  const SizedBox(height: 12),
                  ModuleCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < reviews.items.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: AppColors.border),
                          _ReviewRow(
                            review: reviews.items[i],
                            sellerName: sellerName,
                            date: DateFormat.MMMd(
                              locale,
                            ).format(reviews.items[i].createdAt.toLocal()),
                            onReply: isMe
                                ? () => _reply(context, ref, reviews.items[i])
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isMe)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _report(context, ref, reviews.items),
                        child: Text(l.assimeReportReview),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.reviews});

  final SellerReviews reviews;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rating = reviews.rating ?? 0;
    final max = reviews.histogram.values.fold<int>(0, (a, b) => b > a ? b : a);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(
                    rating.toStringAsFixed(1).replaceAll('.', ','),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _Stars(value: rating.round(), size: 13),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            child: Text(
                              '$star',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ModuleProgressBar(
                              value: max == 0
                                  ? 0
                                  : (reviews.histogram[star] ?? 0) / max,
                              color: AppColors.brandOr,
                              height: 5,
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${reviews.histogram[star] ?? 0}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (reviews.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in reviews.tags.entries)
                  Chip(
                    label: Text(
                      '${assimeTagLabel(l, entry.key)} · ${entry.value}',
                    ),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.size = 14});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= value ? Icons.star : Icons.star_border,
            size: size,
            color: AppColors.brandOr,
          ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.review,
    required this.sellerName,
    required this.date,
    this.onReply,
  });

  final SellerReview review;
  final String sellerName;
  final String date;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final initials = review.authorName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.terracottaTint,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.isMine ? l.productReviewMine : review.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                date,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Stars(value: review.rating, size: 12),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!),
          ],
          if (review.sellerReply != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l.assimeReviewReplyFrom(sellerName),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: review.sellerReply),
                  ],
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
          if (onReply != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onReply,
                child: Text(l.assimeReplyAction),
              ),
            ),
        ],
      ),
    );
  }
}
