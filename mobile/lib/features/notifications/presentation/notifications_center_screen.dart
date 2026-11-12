import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_order_screen.dart';
import '../../kory/presentation/kory_pot_screen.dart';
import '../../marketplace/presentation/assime_sale_screens.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../data/service_notification.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../core/widgets/skeleton.dart';

final serviceNotificationsRepositoryProvider =
    Provider<ServiceNotificationsRepository>(
      (ref) => ServiceNotificationsRepository(ref.watch(apiClientProvider)),
    );

/// Le centre de notifications, et le nombre de non-lues pour la cloche de
/// l'Accueil. Rechargé à l'ouverture, au retour de l'app et à chaque push
/// de service reçu (voir push_service.dart).
final serviceNotificationsProvider =
    FutureProvider.autoDispose<ServiceNotificationsPage>(
      (ref) => ref.watch(serviceNotificationsRepositoryProvider).list(),
    );

/// Ouvre l'écran qu'une notification de service désigne (« kory/12 »,
/// « honam/order/34 »). Inconnu : rien — mieux vaut ne pas bouger que
/// d'ouvrir un mauvais écran.
void openServiceRoute(NavigatorState navigator, String? route) {
  final parts = (route ?? '').split('/');
  Widget? screen;
  if (parts.length == 2 && parts[0] == 'kory') {
    final id = int.tryParse(parts[1]);
    if (id != null) screen = KoryPotScreen(potId: id);
  } else if (parts.length == 3 &&
      parts[0] == 'assime' &&
      parts[1] == 'review') {
    final id = int.tryParse(parts[2]);
    if (id != null) screen = AssimeRateSaleScreen(productId: id);
  } else if (parts.length == 3 && parts[0] == 'honam' && parts[1] == 'order') {
    final id = int.tryParse(parts[2]);
    if (id != null) screen = HonamOrderScreen(orderId: id);
  }
  if (screen != null) {
    navigator.push(MaterialPageRoute(builder: (_) => screen!));
  }
}

/// NOT-1 · Centre de notifications : ce que les services ont à dire. Les
/// messages n'y apparaissent pas : ils restent dans Discussions.
class NotificationsCenterScreen extends ConsumerWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(serviceNotificationsProvider);
    final page = async.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.notifCenterTitle),
        actions: [
          if ((page?.unread ?? 0) > 0)
            TextButton(
              onPressed: () async {
                await ref
                    .read(serviceNotificationsRepositoryProvider)
                    .readAll();
                ref.invalidate(serviceNotificationsProvider);
              },
              child: Text(l.notifReadAll),
            ),
          IconButton(
            tooltip: l.notifSettings,
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serviceNotificationsProvider);
          await ref.read(serviceNotificationsProvider.future);
        },
        child: async.when(
          loading: () => const SkeletonList(),
          error: (_, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.modulesCheckNetwork,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          data: (page) => _List(page: page),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.page});

  final ServiceNotificationsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sections = <String, List<ServiceNotification>>{};
    for (final n in page.items) {
      final local = n.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final key = day == today
          ? l.notifToday
          : day == yesterday
          ? l.notifYesterday
          : l.notifEarlier;
      sections.putIfAbsent(key, () => []).add(n);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (page.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const PokouIllustration(
                  PokouIllustrations.notificationsEmpty,
                  height: 150,
                ),
                const SizedBox(height: 16),
                Text(
                  l.notifEmpty,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final (i, n) in entry.value.indexed) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.border),
                  _Tile(notification: n),
                ],
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            l.notifMessagesElsewhere,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final ServiceNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final n = notification;
    final (
      IconData icon,
      Color tint,
      Color ink,
      String label,
    ) = switch (n.service) {
      'kory' => (
        Icons.savings_outlined,
        AppColors.terracottaTint,
        AppColors.onTerracottaTint,
        l.navKory,
      ),
      'honam' => (
        Icons.local_pharmacy_outlined,
        const Color(0xFFF5E5BD),
        AppColors.warning,
        l.navHonam,
      ),
      'assime' => (
        Icons.storefront_outlined,
        const Color(0xFFDCE9F0),
        AppColors.feedbackInfo,
        'Assimé',
      ),
      'certified' => (
        Icons.verified_outlined,
        const Color(0xFFF2E8BD),
        const Color(0xFF6B5412),
        l.notifServiceCertified,
      ),
      _ => (
        Icons.forum_outlined,
        AppColors.surfaceElevated,
        AppColors.textSecondary,
        l.navChats,
      ),
    };
    return InkWell(
      onTap: () async {
        if (!n.read) {
          await ref.read(serviceNotificationsRepositoryProvider).read(n.id);
          ref.invalidate(serviceNotificationsProvider);
        }
        if (context.mounted) openServiceRoute(Navigator.of(context), n.route);
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.isDark ? ink.withValues(alpha: 0.2) : tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.isDark ? AppColors.textPrimary : ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label · ${DateFormat.Hm().format(n.createdAt.toLocal())}',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    n.body,
                    style: TextStyle(
                      color: n.read
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.read)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
