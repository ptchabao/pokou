import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exceptions.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../auth/presentation/auth_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';

final _ridesProvider = FutureProvider.autoDispose<({List<HonamOrder> available, List<HonamOrder> mine})>((ref) {
  return ref.watch(honamRepositoryProvider).rides();
});

/// Le mode coursier Win Pokou (BM-08, COU-8, COU-26) : un mode de l'application, pas une
/// application à part.
class CourierScreen extends ConsumerWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final courier = ref.watch(courierStatusProvider);

    void refresh() {
      ref.invalidate(courierStatusProvider);
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
                    if (status.referralCode != null && status.status != 'SUSPENDED')
                      _Referral(status: status),
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
                // Fin d'essai : on parle d'argent APRÈS les premiers gains,
                // avec le pack qui couvre l'activité réelle.
                if (status.recommendedPack != null) ...[
                  Text(l.honamTrialEnded, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(l.honamRecommendedPack(
                    status.packs.where((p) => p.code == status.recommendedPack).firstOrNull?.label ??
                        status.recommendedPack!,
                  )),
                  const SizedBox(height: 8),
                ],
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
          _LocationBeacon(
            orderIds: [
              for (final o in data.mine)
                if (o.status == 'READY' || o.status == 'IN_DELIVERY') o.id,
            ],
          ),
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
            if (mine &&
                order.status == 'IN_DELIVERY' &&
                order.deliveryLatitude != null &&
                order.deliveryLongitude != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => openInMaps(order.deliveryLatitude!, order.deliveryLongitude!),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: Text(l.honamNavigate),
                ),
              ),
            const SizedBox(height: 8),
            if (!mine) ...[
              Row(
                children: [
                  Expanded(
                    child: ModuleActionButton(
                      label: l.honamAcceptRide,
                      onPressed: () => act('accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Aperçu plein écran (COU-27)',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourierIncomingRideScreen(
                          order: order,
                          onAccept: () => act('accept'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (order.status == 'READY')
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

/// COU-27 · Course reçue pendant une discussion / Proposition plein écran.
///
/// Propose une course à un coursier disponible en plein écran, avec un compte
/// à rebours de 30 secondes, les adresses de retrait et livraison, le gain
/// versé par l'officine et la mention de retour à l'activité en cours.
class CourierIncomingRideScreen extends StatefulWidget {
  const CourierIncomingRideScreen({
    super.key,
    required this.order,
    required this.onAccept,
  });

  final HonamOrder order;
  final VoidCallback onAccept;

  @override
  State<CourierIncomingRideScreen> createState() => _CourierIncomingRideScreenState();
}

class _CourierIncomingRideScreenState extends State<CourierIncomingRideScreen> {
  int _secondsRemaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pharmacy = widget.order.pharmacy;
    final gain = formatFcfa(widget.order.deliveryPrice ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête type appel entrant
              Row(
                children: [
                  const Icon(Icons.delivery_dining, color: AppColors.accentPrimary),
                  const SizedBox(width: 8),
                  const Text(
                    'Nouvelle course · mode coursier',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.feedbackWarning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_secondsRemaining}s',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.feedbackWarning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Montant du gain
              Center(
                child: Column(
                  children: [
                    Text(
                      gain,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Payés directement par l’officine sur ton wallet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Détails du trajet
              ModuleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.storefront, color: AppColors.feedbackSuccess, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Retrait en pharmacie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(pharmacy?.name ?? 'Pharmacie', style: const TextStyle(fontSize: 15)),
                              if (pharmacy?.address != null)
                                Text(pharmacy!.address, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.accentPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Livraison au patient', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(widget.order.deliveryAddress, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Rappel contextuel COU-27
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.accentPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu étais dans une autre section : tu y reviens après ta réponse.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Boutons d'action
              ModuleActionButton(
                label: 'Accepter la course',
                icon: Icons.check,
                onPressed: () {
                  _timer?.cancel();
                  widget.onAccept();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  _timer?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Passer la course'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


/// Le coursier navigue avec l'application de cartes de son téléphone :
/// aucun guidage dans Pokou.
Future<void> openInMaps(double lat, double lng) async {
  final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
  if (await canLaunchUrl(geo)) {
    await launchUrl(geo);
    return;
  }
  await launchUrl(
    Uri.parse('https://maps.google.com/?q=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  );
}

/// La position du coursier, envoyée toutes les 15 s pendant ses courses en
/// cours, et seulement pendant. Rien n'est envoyé hors course, et le serveur
/// efface la dernière position à la remise.
class _LocationBeacon extends ConsumerStatefulWidget {
  const _LocationBeacon({required this.orderIds});

  final List<int> orderIds;

  @override
  ConsumerState<_LocationBeacon> createState() => _LocationBeaconState();
}

class _LocationBeaconState extends ConsumerState<_LocationBeacon> {
  static const _period = Duration(seconds: 15);
  Timer? _timer;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LocationBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.orderIds.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    unawaited(_send());
    _timer = Timer.periodic(_period, (_) => _send());
  }

  Future<void> _send() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted && !_denied) setState(() => _denied = true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final repository = ref.read(honamRepositoryProvider);
      for (final id in widget.orderIds) {
        await repository.sendLocation(id, position.latitude, position.longitude);
      }
      if (mounted && _denied) setState(() => _denied = false);
    } catch (_) {
      // Réseau ou GPS indisponible : la prochaine tentative suit dans 15 s,
      // le patient voit « position non à jour » entre-temps.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderIds.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(
            _denied ? Icons.location_disabled : Icons.my_location,
            size: 18,
            color: _denied ? AppColors.feedbackWarning : AppColors.feedbackInfo,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _denied ? l.honamLocationDenied : l.honamLocationShared,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parrainage (maquette Coursiers 15).
class _Referral extends StatelessWidget {
  const _Referral({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final code = status.referralCode!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.honamReferralTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l.honamReferralBody('${status.referralGiftRides}')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
                  ),
                ),
                IconButton(
                  tooltip: l.honamReferralShare,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => Share.share(l.honamReferralMessage(code)),
                ),
              ],
            ),
            if (status.referralsCount > 0)
              Text(l.honamReferralCount('${status.referralsCount}'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

final _citiesProvider = FutureProvider.autoDispose<HonamCities?>((ref) async {
  try {
    return await ref.watch(honamRepositoryProvider).cities();
  } catch (_) {
    return null;
  }
});

/// La candidature (maquettes Coursiers 2 à 7) : ville, zones, wallet,
/// règles d'or, code de parrainage. Hors des villes desservies, la liste
/// d'attente (maquette Coursiers 16).
class _Application extends ConsumerStatefulWidget {
  const _Application({required this.onSent});

  final VoidCallback onSent;

  @override
  ConsumerState<_Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<_Application> {
  static const _otherCity = '';
  final _zones = TextEditingController();
  final _referral = TextEditingController();
  final _otherCityName = TextEditingController();
  late final _wallet = TextEditingController(
    text: ref.read(authControllerProvider).user?.phone ?? '',
  );
  String? _city;
  bool _rules = false;
  bool _busy = false;
  String? _waitlisted;

  @override
  void dispose() {
    _zones.dispose();
    _referral.dispose();
    _otherCityName.dispose();
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
        city: _city,
        referralCode: _referral.text.trim().toUpperCase(),
      );
      widget.onSent();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinWaitlist() async {
    final city = _otherCityName.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).joinWaitlist(city);
      if (mounted) setState(() => _waitlisted = city);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cities = ref.watch(_citiesProvider).valueOrNull;
    final served = cities?.served ?? const <String>[];
    final waitlisted = _waitlisted ?? cities?.waitlistCity;
    final elsewhere = _city == _otherCity;
    if (waitlisted != null) {
      return ModuleEmptyState(
        icon: Icons.hourglass_empty,
        title: l.honamWaitlistDone(waitlisted),
        message: l.honamWaitlistBody,
      );
    }
    final ready = _rules && _zones.text.trim().length >= 2 && _wallet.text.trim().isNotEmpty &&
        (served.isEmpty || (_city != null && !elsewhere));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.honamCourierJoin, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(l.honamCourierJoinBody),
        const SizedBox(height: 16),
        if (served.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: InputDecoration(labelText: l.honamCity),
            items: [
              for (final city in served) DropdownMenuItem(value: city, child: Text(city)),
              DropdownMenuItem(value: _otherCity, child: Text(l.honamOtherCity)),
            ],
            onChanged: (value) => setState(() => _city = value),
          ),
        if (elsewhere) ...[
          const SizedBox(height: 8),
          Text(l.honamNotServed),
          TextField(
            controller: _otherCityName,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.honamYourCity),
          ),
          const SizedBox(height: 8),
          ModuleActionButton(
            label: l.honamJoinWaitlist,
            icon: Icons.notifications_active_outlined,
            busy: _busy,
            onPressed: _otherCityName.text.trim().length >= 2 && !_busy ? _joinWaitlist : null,
          ),
        ] else ...[
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
          TextField(
            controller: _referral,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l.honamReferralCodeField),
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
      ],
    );
  }
}
