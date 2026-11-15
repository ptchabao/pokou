import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart' show rootNavigatorKey;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_order_messages.dart';
import 'honam_tracking.dart' show honamRelayedCall;
import 'honam_ui.dart';

/// Les courses du coursier : disponibles et à lui.
final courierRidesProvider =
    FutureProvider.autoDispose<
      ({List<HonamOrder> available, List<HonamOrder> mine})
    >((ref) => ref.watch(honamRepositoryProvider).rides());

/// Maquette Coursiers 27 : un coursier DISPONIBLE reçoit les courses même
/// hors du mode coursier. Le serveur pousse `honam:ride_offered` ; la
/// proposition s'ouvre en plein écran, comme un appel entrant, par-dessus
/// l'écran en cours, puis on y revient.
final courierRideOfferListenerProvider = Provider<void>((ref) {
  final shown = <int>{};
  final subscription = ref.watch(wsClientProvider).events.listen((event) async {
    if (event['type'] != 'honam:ride_offered') return;
    final id = event['order_id'];
    if (id is! int || !shown.add(id)) return;
    try {
      final status = await ref.read(honamRepositoryProvider).courierMe();
      if (status == null || !status.available) return;
      final rides = await ref.read(honamRepositoryProvider).rides();
      final order = rides.available.where((o) => o.id == id).firstOrNull;
      if (order == null) return;
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CourierIncomingRideScreen(order: order, incoming: true),
        ),
      );
    } catch (_) {
      // Hors ligne : la course reste visible dans le mode coursier.
    }
  });
  ref.onDispose(subscription.cancel);
});

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

double _km(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = p2 - p1;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a =
      math.pow(math.sin(dp / 2), 2) +
      math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// La distance de l'officine à l'adresse de livraison, si les deux sont
/// connues.
double? rideLengthKm(HonamOrder order) {
  final p = order.pharmacy;
  if (p?.latitude == null || order.deliveryLatitude == null) return null;
  return _km(
    p!.latitude!,
    p.longitude!,
    order.deliveryLatitude!,
    order.deliveryLongitude!,
  );
}

/// Accepter une course. Un pack épuisé ouvre d'abord la feuille « Ton pack
/// est épuisé » (maquette Coursiers 14) : on passe au pack supérieur en
/// payant la différence, ou on laisse passer la course.
Future<bool> acceptRide(
  BuildContext context,
  WidgetRef ref,
  HonamOrder order,
  CourierStatus? status,
) async {
  final l = L.of(context);
  if (status != null &&
      status.status == 'MEMBER' &&
      !status.unlimited &&
      !status.launchPeriod &&
      status.ridesLeft <= 0) {
    await showPackExhaustedSheet(context, ref, status, order);
    return false;
  }
  try {
    await ref.read(honamRepositoryProvider).rideAction(order.id, 'accept');
    HapticFeedback.lightImpact();
    ref.invalidate(courierRidesProvider);
    ref.invalidate(courierStatusProvider);
    return true;
  } on ApiException catch (error) {
    if (context.mounted) koryToast(context, error.message);
  } catch (_) {
    if (context.mounted) koryToast(context, l.honamFailed);
  }
  return false;
}

/// Maquette Coursiers 14 : le pack est épuisé au moment d'une course.
Future<void> showPackExhaustedSheet(
  BuildContext context,
  WidgetRef ref,
  CourierStatus status,
  HonamOrder order,
) {
  final l = L.of(context);
  final current = status.packs.where((p) => p.code == status.currentPack).firstOrNull;
  final index = status.packs.indexWhere((p) => p.code == status.currentPack);
  final next = index >= 0 && index + 1 < status.packs.length
      ? status.packs[index + 1]
      : null;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.courierPackExhausted(current?.label ?? ''),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? l.courierPackExhaustedNoNext
                  : l.courierPackExhaustedBody(
                      formatFcfa(order.deliveryPrice ?? 0),
                      next.label,
                    ),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              KoryCard(
                child: Column(
                  children: [
                    KoryLine(
                      l.courierPackDifference(current?.label ?? '', next.label),
                      l.courierHt(formatFcfa(next.upgradePriceHt)),
                    ),
                    KoryLine(
                      l.courierToPay,
                      l.courierTtc(
                        formatFcfa(
                          (next.upgradePriceHt * (1 + status.vatRate)).round(),
                        ),
                      ),
                    ),
                    if (next.rides != null && current?.rides != null)
                      KoryLine(
                        l.courierMoreRides,
                        '${next.rides! - current!.rides!}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KoryButton(
                label: l.courierSwitchTo(
                  next.label,
                  formatFcfa((next.upgradePriceHt * (1 + status.vatRate)).round()),
                ),
                onPressed: () {
                  Navigator.pop(sheet);
                  openPayment(
                    context,
                    ref
                        .read(honamRepositoryProvider)
                        .pay('/honam/courier/pack', body: {'pack': next.code}),
                  );
                },
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: Text(l.courierLetGo),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La proposition de course (maquettes Coursiers 9 et 27) : 30 secondes pour
/// répondre. [incoming] : elle arrive par-dessus un autre écran, comme un
/// appel entrant, sur fond sombre ; on revient ensuite où l'on était.
class CourierIncomingRideScreen extends ConsumerStatefulWidget {
  const CourierIncomingRideScreen({
    super.key,
    required this.order,
    this.incoming = false,
  });

  final HonamOrder order;
  final bool incoming;

  @override
  ConsumerState<CourierIncomingRideScreen> createState() =>
      _CourierIncomingRideScreenState();
}

class _CourierIncomingRideScreenState
    extends ConsumerState<CourierIncomingRideScreen> {
  static const _seconds = 30;
  int _left = _seconds;
  Timer? _timer;
  bool _busy = false;
  double? _toPharmacyKm;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_left > 1) {
        setState(() => _left--);
      } else {
        timer.cancel();
        if (mounted) Navigator.of(context).maybePop();
      }
    });
    _locate();
  }

  Future<void> _locate() async {
    final p = widget.order.pharmacy;
    if (p?.latitude == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final here = await Geolocator.getLastKnownPosition();
      if (here != null && mounted) {
        setState(
          () => _toPharmacyKm = _km(
            here.latitude,
            here.longitude,
            p!.latitude!,
            p.longitude!,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    _timer?.cancel();
    setState(() => _busy = true);
    final status = ref.read(courierStatusProvider).valueOrNull;
    final ok = await acceptRide(context, ref, widget.order, status);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourierDeliveryScreen(orderId: widget.order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final status = ref.watch(courierStatusProvider).valueOrNull;
    final pharmacy = order.pharmacy;
    final length = rideLengthKm(order);
    final trialLeft = status != null && status.status == 'TRIAL'
        ? math.max(status.ridesLeft - 1, 0)
        : null;
    final dark = widget.incoming;
    final ink = dark ? Colors.white : AppColors.textPrimary;
    final soft = dark ? Colors.white70 : AppColors.textSecondary;
    final ring = SizedBox(
      width: dark ? 110 : 56,
      height: dark ? 110 : 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: _left / _seconds,
              strokeWidth: dark ? 6 : 4,
              color: dark ? Colors.white : AppColors.accentPrimaryDark,
              backgroundColor: (dark ? Colors.white : AppColors.accentPrimaryDark)
                  .withValues(alpha: 0.2),
            ),
          ),
          Text(
            '$_left',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: dark ? 34 : 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
    final route = KoryCard(
      color: dark ? Colors.white.withValues(alpha: 0.08) : null,
      borderColor: dark ? Colors.white24 : null,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.location_on_outlined, color: soft),
            title: Text(
              l.courierPickupAt(pharmacy?.name ?? l.honamUiPharmacy),
              style: TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            subtitle: Text(
              [
                if (pharmacy?.address.isNotEmpty ?? false) pharmacy!.address,
                if (_toPharmacyKm != null)
                  l.courierKmFromYou(_toPharmacyKm!.toStringAsFixed(1)),
              ].join(' · '),
              style: TextStyle(color: soft),
            ),
          ),
          ListTile(
            leading: Icon(Icons.route_outlined, color: soft),
            title: Text(
              l.courierDeliveryAt(order.deliveryAddress),
              style: TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            subtitle: Text(
              [
                if (length != null) l.courierKmAfterPickup(length.toStringAsFixed(1)),
                if (order.patientName != null) order.patientName!,
              ].join(' · '),
              style: TextStyle(color: soft),
            ),
          ),
        ],
      ),
    );
    final footnote = [
      l.courierPaidOnYourWallet,
      if (trialLeft != null) l.courierTrialLeftAfter(trialLeft),
    ].join(' ');

    if (dark) {
      return Scaffold(
        backgroundColor: const Color(0xFF3A1E14),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  l.courierNewRideMode,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ring,
                const SizedBox(height: 16),
                Text(
                  formatFcfa(order.deliveryPrice ?? 0),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  l.courierPaidByPharmacyShort,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                route,
                if (trialLeft != null) ...[
                  const SizedBox(height: 10),
                  HonamPill(
                    l.courierTrialLeftAfter(trialLeft),
                    background: Colors.white12,
                    ink: Colors.white,
                  ),
                ],
                const Spacer(),
                Text(
                  l.courierBackWhereYouWere,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundAction(
                      label: l.courierSkip,
                      icon: Icons.close,
                      color: AppColors.securityCritical,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    _RoundAction(
                      label: l.courierAccept,
                      icon: Icons.check,
                      color: AppColors.feedbackSuccess,
                      onTap: _busy ? null : _accept,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return KoryPage(
      title: l.courierNewRide,
      subtitle: l.courierAnswerIn30,
      footer: KoryFooter(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(l.courierSkip),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _accept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.feedbackSuccess,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l.courierAccept),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatFcfa(order.deliveryPrice ?? 0),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              ring,
            ],
          ),
          if (order.priority) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: HonamPill(
                l.courierProposedFirst(pharmacy?.name ?? ''),
                background: AppColors.securityWarning.withValues(alpha: 0.16),
                ink: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          route,
          const SizedBox(height: 10),
          Text(footnote, style: TextStyle(fontSize: 13, color: soft)),
          if (order.originalRequired) ...[
            const SizedBox(height: 10),
            KoryNotice(icon: Icons.description_outlined, text: l.honamOriginal),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white)),
    ],
  );
}

/// La course en cours, relue depuis la liste du coursier.
final _myRideProvider = FutureProvider.autoDispose.family<HonamOrder?, int>((
  ref,
  id,
) async {
  final rides = await ref.watch(courierRidesProvider.future);
  return rides.mine.where((o) => o.id == id).firstOrNull;
});

/// La livraison (maquette Coursiers 10) : l'adresse et son repère, l'appel
/// relayé, l'itinéraire dans l'application de cartes du téléphone, le code.
class CourierDeliveryScreen extends ConsumerStatefulWidget {
  const CourierDeliveryScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<CourierDeliveryScreen> createState() =>
      _CourierDeliveryScreenState();
}

class _CourierDeliveryScreenState extends ConsumerState<CourierDeliveryScreen> {
  bool _busy = false;

  Future<void> _pickup() async {
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).rideAction(widget.orderId, 'pickup');
      ref.invalidate(courierRidesProvider);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(_myRideProvider(widget.orderId));
    final order = async.valueOrNull;
    if (order == null) {
      return KoryPage(
        title: l.courierDelivery,
        loading: async.isLoading,
        body: KoryNotice(text: l.honamNoRides),
      );
    }
    final patient = order.patientName ?? l.courierThePatient;
    final picked = order.status == 'IN_DELIVERY';
    return KoryPage(
      title: l.courierDeliveryTo(patient),
      subtitle: picked && order.pickedUpAt != null
          ? l.courierPickedUpAt(honamWhen(context, order.pickedUpAt!))
          : order.pharmacy?.name,
      footer: KoryFooter(
        children: [
          if (!picked)
            KoryButton(
              label: l.honamPickup,
              busy: _busy,
              onPressed: _pickup,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: order.deliveryLatitude == null
                        ? null
                        : () => openInMaps(
                            order.deliveryLatitude!,
                            order.deliveryLongitude!,
                          ),
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: Text(l.courierItinerary),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KoryButton(
                    label: l.courierEnterCode,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourierCodeScreen(order: order),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CourierProblemScreen(order: order),
              ),
            ),
            icon: const Icon(Icons.help_outline, size: 18),
            label: Text(l.courierProblemDuringRide),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          CourierLocationBeacon(orderIds: [order.id]),
          const SizedBox(height: 8),
          KoryNotice(
            tone: KoryTone.success,
            icon: Icons.near_me_outlined,
            text: l.courierPositionShared(patient),
          ),
          const SizedBox(height: 12),
          KoryCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (!picked)
                  HonamLinkRow(
                    icon: Icons.local_hospital_outlined,
                    title: order.pharmacy?.name ?? l.honamUiPharmacy,
                    subtitle: order.pharmacy?.address,
                    onTap: order.pharmacy?.latitude == null
                        ? null
                        : () => openInMaps(
                            order.pharmacy!.latitude!,
                            order.pharmacy!.longitude!,
                          ),
                  ),
                if (!picked) Divider(height: 1, color: AppColors.border),
                HonamLinkRow(
                  icon: Icons.location_on_outlined,
                  title: order.deliveryAddress,
                  subtitle: order.deliveryLandmark == null
                      ? null
                      : l.honamPLandmark(order.deliveryLandmark!),
                ),
                if (order.patientUserId != null) ...[
                  Divider(height: 1, color: AppColors.border),
                  HonamLinkRow(
                    icon: Icons.call_outlined,
                    title: l.courierCallPatient(patient),
                    subtitle: l.courierCallRelayed,
                    onTap: () =>
                        honamRelayedCall(context, ref, order.patientUserId!),
                  ),
                ],
              ],
            ),
          ),
          if (order.originalRequired) ...[
            const SizedBox(height: 12),
            KoryNotice(
              tone: KoryTone.warning,
              icon: Icons.description_outlined,
              text: l.honamOriginal,
            ),
          ],
        ],
      ),
    );
  }
}

/// Le code de remise (maquette Coursiers 11). Le code fait 6 chiffres côté
/// serveur (la maquette en montre 4) : on garde 6.
class CourierCodeScreen extends ConsumerStatefulWidget {
  const CourierCodeScreen({super.key, required this.order});

  final HonamOrder order;

  @override
  ConsumerState<CourierCodeScreen> createState() => _CourierCodeScreenState();
}

class _CourierCodeScreenState extends ConsumerState<CourierCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _deliver() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .rideAction(widget.order.id, 'deliver', body: {'code': _code.text});
      HapticFeedback.mediumImpact();
      ref.invalidate(courierRidesProvider);
      ref.invalidate(courierStatusProvider);
      if (!mounted) return;
      koryToast(context, l.courierDelivered);
      Navigator.of(context)
        ..pop()
        ..pop();
    } on ApiException catch (error) {
      _code.clear();
      if (mounted) {
        setState(() => _busy = false);
        koryToast(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        koryFailed(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final patient = order.patientName ?? l.courierThePatient;
    return KoryPage(
      title: l.courierHandoverCode,
      subtitle: l.courierDeliveryTo(patient),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.courierValidateHandover,
            busy: _busy,
            onPressed: _code.text.length == 6 ? _deliver : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l.courierAskCode(patient),
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          HonamCodeBoxes(
            controller: _code,
            autofocus: true,
            onCompleted: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            l.courierFiveAttempts,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          KoryNotice(
            icon: Icons.info_outline,
            text: l.courierAfterHandover(
              order.pharmacy?.name ?? l.honamUiPharmacy,
              formatFcfa(order.deliveryPrice ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Un problème pendant la course ? » (maquette Coursiers 19).
class CourierProblemScreen extends ConsumerStatefulWidget {
  const CourierProblemScreen({super.key, required this.order});

  final HonamOrder order;

  @override
  ConsumerState<CourierProblemScreen> createState() =>
      _CourierProblemScreenState();
}

class _CourierProblemScreenState extends ConsumerState<CourierProblemScreen> {
  static const _wait = Duration(minutes: 10);
  late String? _kind = widget.order.incidentKind;
  late DateTime? _since = widget.order.incidentAt;
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _report(String kind) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .rideAction(widget.order.id, 'incident', body: {'kind': kind});
      ref.invalidate(courierRidesProvider);
      if (!mounted) return;
      setState(() {
        _kind = kind;
        _since = DateTime.now();
      });
      if (kind == 'ACCIDENT') {
        koryToast(context, L.of(context).courierRideReleased);
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _return() async {
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).rideAction(widget.order.id, 'return');
      ref.invalidate(courierRidesProvider);
      if (!mounted) return;
      koryToast(context, L.of(context).courierParcelReturned);
      Navigator.of(context)
        ..pop()
        ..pop();
    } on ApiException catch (error) {
      if (mounted) koryToast(context, error.message);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final patient = order.patientName ?? l.courierThePatient;
    final pharmacy = order.pharmacy?.name ?? l.honamUiPharmacy;
    final waited = _since == null || _kind != 'NO_ANSWER'
        ? Duration.zero
        : DateTime.now().toUtc().difference(_since!.toUtc());
    final minutes = math.min(waited.inMinutes, _wait.inMinutes);
    final options = [
      ('NO_ANSWER', l.courierNoAnswer(patient), l.courierNoAnswerBody),
      ('ADDRESS', l.courierAddressNotFound, l.courierAddressNotFoundBody(patient)),
      ('CODE', l.courierCodeRefused, l.courierCodeRefusedBody(patient)),
      ('ACCIDENT', l.courierAccident, l.courierAccidentBody),
    ];
    return KoryPage(
      title: l.courierProblem,
      subtitle: l.courierDeliveryTo(patient),
      footer: _kind == 'NO_ANSWER'
          ? KoryFooter(
              children: [
                if (order.patientUserId != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        honamRelayedCall(context, ref, order.patientUserId!),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(l.courierCallAgain(patient)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                const SizedBox(height: 8),
                KoryButton(
                  label: l.courierReturnParcel,
                  busy: _busy,
                  onPressed: waited >= _wait ? _return : null,
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (kind, title, body) in options)
            KoryChoice(
              selected: _kind == kind,
              title: title,
              subtitle: body,
              onTap: _busy || _kind == kind ? () {} : () => _report(kind),
            ),
          if (_kind == 'NO_ANSWER')
            KoryCard(
              color: AppColors.securityWarning.withValues(alpha: 0.10),
              borderColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.courierWaitingOnSite,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        l.courierMinutesOf(minutes, _wait.inMinutes),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: minutes / _wait.inMinutes,
                    color: AppColors.accentPrimaryDark,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.courierNoAnswerReturn(pharmacy),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          if (_kind == 'ADDRESS')
            KoryButton(
              quiet: true,
              icon: Icons.chat_bubble_outline,
              label: l.courierWriteToPatient(patient),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HonamOrderMessagesScreen(
                    orderId: order.id,
                    title: patient,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// « Défaut signalé » (maquette Coursiers 20).
class CourierDefaultScreen extends ConsumerStatefulWidget {
  const CourierDefaultScreen({
    super.key,
    required this.item,
    required this.count,
    required this.max,
  });

  final CourierDefault item;
  final int count;
  final int max;

  @override
  ConsumerState<CourierDefaultScreen> createState() =>
      _CourierDefaultScreenState();
}

class _CourierDefaultScreenState extends ConsumerState<CourierDefaultScreen> {
  bool _busy = false;

  Future<void> _act(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .defaultAction(widget.item.id, action, note: note);
      ref.invalidate(courierStatusProvider);
      if (!mounted) return;
      if (action == 'contest') koryToast(context, L.of(context).courierContestSent);
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contest() async {
    final l = L.of(context);
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.courierContestDefault),
        content: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.courierContestHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: Text(l.actionSend),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null) await _act('contest', note: note);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final item = widget.item;
    final pharmacy = item.pharmacyName ?? l.honamUiPharmacy;
    return KoryPage(
      title: l.courierDefaultTitle,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.courierUnderstood,
            busy: _busy,
            onPressed: () => _act('acknowledge'),
          ),
          if (item.canContest)
            TextButton(
              onPressed: _busy ? null : _contest,
              child: Text(l.courierContestDefault),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HonamRoundIcon(
            icon: Icons.warning_amber_rounded,
            color: AppColors.securityCritical,
          ),
          const SizedBox(height: 12),
          Text(
            l.courierDefaultLead(
              pharmacy,
              honamWhen(context, item.orderDate ?? item.createdAt),
            ),
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KoryCard(
                  child: _Tile(
                    label: l.courierDefaultsInProgress,
                    value: l.courierCountOf(widget.count, widget.max),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KoryCard(
                  child: _Tile(
                    label: l.courierContest,
                    value: item.contestUntil == null
                        ? '—'
                        : l.courierUntil(honamWhen(context, item.contestUntil!)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.courierPharmacyWrote,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text('« ${item.reason} »', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.courierContestHow),
          const SizedBox(height: 8),
          KoryNotice(
            tone: KoryTone.warning,
            icon: Icons.warning_amber_rounded,
            text: l.courierThirdDefault,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      if (caption != null)
        Text(caption!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );
}

/// Une tuile chiffrée (gains, défauts, courses).
class CourierTile extends StatelessWidget {
  const CourierTile({super.key, required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => KoryCard(
    padding: const EdgeInsets.all(12),
    child: _Tile(label: label, value: value, caption: caption),
  );
}

/// La position du coursier, envoyée toutes les 15 s pendant ses courses en
/// cours, et seulement pendant. Rien n'est envoyé hors course, et le serveur
/// efface la dernière position à la remise.
class CourierLocationBeacon extends ConsumerStatefulWidget {
  const CourierLocationBeacon({super.key, required this.orderIds});

  final List<int> orderIds;

  @override
  ConsumerState<CourierLocationBeacon> createState() =>
      _CourierLocationBeaconState();
}

class _CourierLocationBeaconState extends ConsumerState<CourierLocationBeacon> {
  static const _period = Duration(seconds: 15);
  Timer? _timer;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CourierLocationBeacon oldWidget) {
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
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
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
      // Réseau ou GPS indisponible : la prochaine tentative suit dans 15 s.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderIds.isEmpty || !_denied) return const SizedBox.shrink();
    return KoryNotice(
      tone: KoryTone.warning,
      icon: Icons.location_disabled,
      text: L.of(context).honamLocationDenied,
    );
  }
}
