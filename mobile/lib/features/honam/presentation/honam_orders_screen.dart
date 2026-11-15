import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_order_screen.dart';
import 'honam_send_screen.dart';
import 'honam_ui.dart';

/// Mes commandes (maquette Honam patient 8) : en cours, puis passées. Une
/// carte par commande — la pharmacie, la date, le nombre de produits, le
/// montant et l'état — jamais un nom de médicament (HON-04).
class HonamOrdersScreen extends ConsumerWidget {
  const HonamOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(honamOrdersProvider);
    final orders = async.valueOrNull;
    return KoryPage(
      title: l.honamMyOrders,
      loading: orders == null && !async.hasError,
      footer: KoryFooter(
        children: [
          KoryButton(
            icon: Icons.photo_camera_outlined,
            label: l.honamSend,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HonamSendScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(honamOrdersProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (async.hasError && orders == null)
              KoryNotice(
                tone: KoryTone.danger,
                text: l.honamUiOrdersError,
              )
            else if (orders != null && orders.isEmpty)
              KoryNotice(text: l.honamUiEmptyBody, title: l.honamUiEmptyTitle)
            else if (orders != null) ...[
              if (orders.any((o) => !o.isFinished)) ...[
                KorySection(l.honamPInProgress),
                for (final order in orders.where((o) => !o.isFinished))
                  HonamOrderTile(order: order),
              ],
              if (orders.any((o) => o.isFinished)) ...[
                KorySection(l.honamPPast),
                for (final order in orders.where((o) => o.isFinished))
                  HonamOrderTile(order: order),
              ],
              const SizedBox(height: 8),
              Text(
                l.honamPPastQuestion,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une commande dans une liste : le logo, la pharmacie, une ligne d'état,
/// le montant et sa pastille.
class HonamOrderTile extends StatelessWidget {
  const HonamOrderTile({super.key, required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final count = order.quoteItems.isEmpty ? null : honamItemsCount(order);
    final line = order.isFinished
        ? [
            honamWhen(context, order.createdAt),
            if (order.status != 'DELIVERED')
              honamStatusLabel(l, order.status).toLowerCase(),
            if (count != null && order.status == 'DELIVERED')
              l.honamPProducts(count),
          ].join(' · ')
        : honamStatusPhrase(context, order);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KoryCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HonamOrderScreen(orderId: order.id),
          ),
        ),
        child: Row(
          children: [
            const PokouModuleLogo(PokouModule.honam, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.pharmacy?.name ?? l.navHonam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.total != null)
                  Text(
                    formatFcfa(order.total!),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(height: 4),
                honamOrderPill(l, order),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
