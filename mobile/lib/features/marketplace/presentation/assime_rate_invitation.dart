import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import 'assime_sale_screens.dart';
import 'marketplace_controller.dart';

/// La vente que l'acheteur peut noter, ou `null` : pas acheteur de cette
/// annonce, ou déjà noté. Une erreur (404 compris) ne montre rien.
final _saleToRateProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, productId) async {
      try {
        final sale = await ref
            .read(marketplaceRepositoryProvider)
            .sale(productId);
        return sale['reviewed'] == true ? null : sale;
      } catch (_) {
        return null;
      }
    });

/// Assimé 19 · Invitation à noter, dans la discussion liée à l'annonce :
/// « {vendeur} a indiqué que tu as acheté cet article pour … », des
/// étoiles et « Noter la transaction ». Rien tant que le vendeur n'a pas
/// confirmé la vente à CET acheteur : pas de vente confirmée, pas de note.
class AssimeRateInvitationCard extends ConsumerWidget {
  const AssimeRateInvitationCard({super.key, required this.productId});

  final int productId;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssimeRateSaleScreen(productId: productId),
      ),
    );
    if (done == true) ref.invalidate(_saleToRateProvider(productId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(_saleToRateProvider(productId)).valueOrNull;
    if (sale == null) return const SizedBox.shrink();
    final l = L.of(context);
    final price = sale['final_price'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ModuleCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.assimeRateInvite(
                      sale['seller_name'] as String? ?? '',
                      price == null ? '' : '$price FCFA',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _open(context, ref),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Icon(Icons.star_border, color: AppColors.brandOr),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ModuleActionButton(
              label: l.annRateTitle,
              onPressed: () => _open(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
