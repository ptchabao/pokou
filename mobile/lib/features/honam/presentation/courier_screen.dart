import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../auth/presentation/auth_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';

final _courierProvider = FutureProvider.autoDispose<CourierStatus?>((ref) {
  return ref.watch(honamRepositoryProvider).courierMe();
});

final _ridesProvider = FutureProvider.autoDispose<({List<HonamOrder> available, List<HonamOrder> mine})>((ref) {
  return ref.watch(honamRepositoryProvider).rides();
});

/// Le mode coursier Win Pokou (BM-08) : un mode de l'application, pas une
/// application à part.
class CourierScreen extends ConsumerWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final courier = ref.watch(_courierProvider);

    void refresh() {
      ref.invalidate(_courierProvider);
      ref.invalidate(_ridesProvider);
    }

    return ModuleScaffold(
      title: l.honamCourierMode,
      subtitle: 'Win Pokou',
      child: courier.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(icon: Icons.cloud_off, title: l.honamFailed, message: l.modulesCheckNetwork),
        data: (status) => status == null
            ? _Application(onSent: refresh)
            : RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _StatusCard(status: status),
                    if (status.launchPeriod)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.honamLaunch, style: const TextStyle(color: AppColors.feedbackInfo)),
                      ),
                    if (!status.launchPeriod && (status.status == 'ENDED' || status.status == 'MEMBER'))
                      _Offer(status: status),
                    if (status.status != 'SUSPENDED' && status.status != 'PENDING') _Rides(onChanged: refresh),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (status.status == 'PENDING') {
      return ModuleCard(
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: AppColors.feedbackWarning),
            const SizedBox(width: 12),
            Expanded(child: Text(l.honamPending)),
          ],
        ),
      );
    }
    if (status.status == 'SUSPENDED') {
      return ModuleCard(
        child: Row(
          children: [
            const Icon(Icons.block, color: AppColors.feedbackDanger),
            const SizedBox(width: 12),
            Expanded(child: Text(l.honamCourierSuspended)),
          ],
        ),
      );
    }
    return ModuleCard(
      child: Row(
        children: [
          ModuleBadge(icon: Icons.delivery_dining_outlined, color: AppColors.accentPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.unlimited ? l.honamUnlimited : l.honamRidesLeft('${status.ridesLeft}'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Offer extends ConsumerWidget {
  const _Offer({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final repository = ref.read(honamRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.status == 'ENDED') ...[
          const SizedBox(height: 12),
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.honamMembership(formatFcfa(status.membershipPriceHt))),
                const SizedBox(height: 8),
                ModuleActionButton(
                  label: l.honamPayMembership,
                  onPressed: () => openPayment(context, repository.pay('/honam/courier/membership')),
                ),
              ],
            ),
          ),
        ],
        if (status.status == 'MEMBER') ...[
          ModuleSectionTitle(l.honamPacks),
          for (final pack in status.packs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: pack.code == status.currentPack,
              title: Text(pack.label),
              subtitle: Text(pack.rides == null ? l.honamUnlimited : l.honamRidesLeft('${pack.rides}')),
              trailing: Text(l.honamPackPrice(formatFcfa(pack.upgradePriceHt))),
              enabled: pack.code != 'QUEEN' || status.queenUnlocked,
              onTap: pack.code == status.currentPack
                  ? null
                  : () => openPayment(context, repository.pay('/honam/courier/pack', body: {'pack': pack.code})),
            ),
          if (!status.queenUnlocked)
            Text(l.honamQueenLocked, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(l.honamPriceNote, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ],
    );
  }
}

class _Rides extends ConsumerWidget {
  const _Rides({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final rides = ref.watch(_ridesProvider);
    return rides.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(l.modulesCheckNetwork),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSectionTitle(l.honamMyRides),
          if (data.mine.where((o) => o.status != 'DELIVERED' || !o.courierPaid).isEmpty)
            Text(l.honamNoRides, style: TextStyle(color: AppColors.textSecondary))
          else
            for (final order in data.mine.where((o) => o.status != 'DELIVERED' || !o.courierPaid))
              _RideCard(order: order, mine: true, onChanged: onChanged),
          ModuleSectionTitle(l.honamAvailableRides),
          if (data.available.isEmpty)
            Text(l.honamNoRides, style: TextStyle(color: AppColors.textSecondary))
          else
            for (final order in data.available) _RideCard(order: order, mine: false, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RideCard extends ConsumerWidget {
  const _RideCard({required this.order, required this.mine, required this.onChanged});

  final HonamOrder order;
  final bool mine;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final repository = ref.read(honamRepositoryProvider);

    Future<void> act(String action, {Map<String, dynamic>? body}) async {
      try {
        await repository.rideAction(order.id, action, body: body);
        HapticFeedback.lightImpact();
        onChanged();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    }

    Future<void> deliver() async {
      final controller = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.honamDeliver),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l.honamEnterCode),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.actionCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(l.honamDeliver),
            ),
          ],
        ),
      );
      controller.dispose();
      if (code != null && code.length == 6) await act('deliver', body: {'code': code});
    }

    final pharmacy = order.pharmacy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pharmacy?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(pharmacy?.address ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text(order.deliveryAddress)),
                Text(formatFcfa(order.deliveryPrice ?? 0), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (order.originalRequired) ...[
              const SizedBox(height: 4),
              Text(l.honamOriginal, style: const TextStyle(color: AppColors.feedbackInfo)),
            ],
            const SizedBox(height: 8),
            if (!mine)
              ModuleActionButton(label: l.honamAcceptRide, onPressed: () => act('accept'))
            else if (order.status == 'READY')
              ModuleActionButton(label: l.honamPickup, onPressed: () => act('pickup'))
            else if (order.status == 'IN_DELIVERY')
              ModuleActionButton(label: l.honamDeliver, onPressed: deliver)
            else if (order.status == 'DELIVERED' && !order.courierPaid)
              ModuleQuietButton(label: l.honamCoursePaid, onPressed: () => act('paid')),
          ],
        ),
      ),
    );
  }
}


/// La candidature (maquettes Coursiers 2 à 7) : zones, wallet, règles d'or.
class _Application extends ConsumerStatefulWidget {
  const _Application({required this.onSent});

  final VoidCallback onSent;

  @override
  ConsumerState<_Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<_Application> {
  final _zones = TextEditingController();
  late final _wallet = TextEditingController(
    text: ref.read(authControllerProvider).user?.phone ?? '',
  );
  bool _rules = false;
  bool _busy = false;

  @override
  void dispose() {
    _zones.dispose();
    _wallet.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).courierJoin(
        zones: _zones.text.trim(),
        walletPhone: _wallet.text.trim(),
      );
      widget.onSent();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ready = _rules && _zones.text.trim().length >= 2 && _wallet.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.honamCourierJoin, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(l.honamCourierJoinBody),
        const SizedBox(height: 16),
        TextField(
          controller: _zones,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.honamZones),
        ),
        TextField(
          controller: _wallet,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.honamWallet),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _rules,
          onChanged: (v) => setState(() => _rules = v ?? false),
          title: Text(l.honamRules),
        ),
        const SizedBox(height: 8),
        ModuleActionButton(
          label: l.honamApply,
          icon: Icons.delivery_dining_outlined,
          busy: _busy,
          onPressed: ready && !_busy ? _send : null,
        ),
      ],
    );
  }
}
