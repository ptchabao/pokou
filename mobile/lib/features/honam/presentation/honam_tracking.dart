import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_order_messages.dart';

/// Un appel relayé par Pokou (maquettes « Suivi » et Coursiers 10) : un
/// appel audio de l'application, jamais le numéro de l'autre.
Future<void> honamRelayedCall(
  BuildContext context,
  WidgetRef ref,
  int userId,
) async {
  final l = L.of(context);
  try {
    final token = await ref.read(callRepositoryProvider).startCall([
      userId,
    ], isVideo: false);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          livekitUrl: token.livekitUrl,
          token: token.token,
          room: token.room,
          otherParticipantIds: [userId],
          startWithVideo: false,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) koryToast(context, l.contactCallFailed);
  }
}

/// « moto », « vélo », « à pied ».
String honamTransportLabel(L l, String? transport) => switch (transport) {
  'VELO' => l.courierTransportBike,
  'PIED' => l.courierTransportWalk,
  _ => l.courierTransportMoto,
};

/// La position du coursier, relue au rythme où il l'envoie (15 s), tant
/// que la course dure.
final honamTrackingProvider = StreamProvider.autoDispose
    .family<CourierTracking, int>((ref, orderId) async* {
      final repository = ref.watch(honamRepositoryProvider);
      while (true) {
        CourierTracking? tracking;
        try {
          tracking = await repository.tracking(orderId);
        } catch (_) {
          // Hors ligne : la dernière position reste affichée.
        }
        if (tracking != null) yield tracking;
        if (tracking != null && !tracking.active) return;
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    });

/// Le suivi SANS carte (maquette « Honam · Suivi sans carte ») : l'heure
/// d'arrivée, la frise Pharmacie → Chez toi, le coursier et le code. Une
/// ligne de texte coûte quelques octets ; la carte se charge à la demande.
class HonamTrackingBody extends ConsumerWidget {
  const HonamTrackingBody({super.key, required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final tracking = ref.watch(honamTrackingProvider(order.id)).valueOrNull;
    final courier = order.courierName ?? l.honamCourier;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        KoryCard(
          child: _EtaBlock(order: order, tracking: tracking),
        ),
        const SizedBox(height: 12),
        _CourierCard(order: order, tracking: tracking),
        if (order.deliveryCode != null) ...[
          const SizedBox(height: 12),
          HonamCodeCard(code: order.deliveryCode!, courier: courier),
        ],
        const SizedBox(height: 12),
        KoryNotice(text: l.honamPLightTracking),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HonamMapScreen(order: order)),
            ),
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: Text(l.honamPShowMap),
          ),
        ),
      ],
    );
  }
}

/// « Kodjo arrive vers 10 h 31 · À 1,2 km · mis à jour il y a 20 s », et la
/// frise Pharmacie → Chez toi.
class _EtaBlock extends StatelessWidget {
  const _EtaBlock({required this.order, required this.tracking});

  final HonamOrder order;
  final CourierTracking? tracking;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final courier = order.courierName ?? l.honamCourier;
    final eta = tracking?.etaMinutes;
    final title = eta != null
        ? l.honamPArrivesAround(
            courier,
            DateFormat.Hm(
              locale,
            ).format(DateTime.now().add(Duration(minutes: eta))),
          )
        : order.status == 'IN_DELIVERY'
        ? l.honamTrackingTitle(courier)
        : l.honamPGoingToPharmacy(courier);
    final details = <String>[
      if (tracking?.distanceKm != null)
        l.honamPAtKm(
          NumberFormat.decimalPatternDigits(
            locale: locale,
            decimalDigits: 1,
          ).format(tracking!.distanceKm!),
        ),
      if (tracking?.at != null)
        tracking!.stale
            ? l.honamTrackingStale
            : l.honamPUpdatedSecondsAgo(
                math.max(
                  0,
                  DateTime.now().toUtc().difference(tracking!.at!).inSeconds,
                ),
              ),
    ];
    // Le colis retiré : le coursier est à mi-chemin, faute de mieux.
    final progress = order.status == 'IN_DELIVERY' ? 0.5 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (details.isNotEmpty)
          Text(
            details.join(' · '),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 4, color: AppColors.surfaceElevated),
                  Container(
                    height: 4,
                    width: width * progress,
                    color: AppColors.accentPrimaryDark,
                  ),
                  _Dot(
                    left: 0,
                    filled: false,
                    color: AppColors.feedbackSuccess,
                  ),
                  _Dot(
                    left: (width - 24) * progress,
                    filled: true,
                    color: AppColors.accentPrimaryDark,
                    icon: Icons.delivery_dining,
                  ),
                  _Dot(
                    left: width - 24,
                    filled: false,
                    color: AppColors.accentPrimaryDark,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                l.honamUiPharmacy,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Text(
              l.honamPHome,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.left,
    required this.filled,
    required this.color,
    this.icon,
  });

  final double left;
  final bool filled;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : AppColors.surface,
        border: Border.all(color: color, width: 3),
      ),
      child: icon == null ? null : Icon(icon, size: 13, color: Colors.white),
    ),
  );
}

/// Le coursier : son nom, « Coursier vérifié · moto · à 1,2 km », et
/// l'appel relayé par Pokou.
class _CourierCard extends ConsumerWidget {
  const _CourierCard({required this.order, required this.tracking});

  final HonamOrder order;
  final CourierTracking? tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final courier = order.courierName ?? l.honamCourier;
    final transport = tracking?.courierTransport ?? order.courierTransport;
    final userId = tracking?.courierUserId ?? order.courierUserId;
    final line = [
      if (tracking?.courierVerified ?? false) l.honamPVerifiedCourier,
      if (transport != null) honamTransportLabel(l, transport),
      if (tracking?.distanceKm != null)
        l.honamPAtKm(tracking!.distanceKm!.toStringAsFixed(1)),
    ].join(' · ');
    return KoryCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: KoryPersonRow(
        name: courier,
        subtitle: line,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Canal « livraison » : la patiente et le coursier, seuls.
            IconButton(
              tooltip: l.offiPatientWriteToCourier(courier),
              icon: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.accentPrimary,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HonamOrderMessagesScreen(
                    orderId: order.id,
                    title: courier,
                    channel: 'livraison',
                    heading: l.offiPatientWriteToCourier(courier),
                  ),
                ),
              ),
            ),
            if (userId != null)
              IconButton(
                tooltip: l.honamPCallRelayed(courier),
                icon: Icon(Icons.call_outlined, color: AppColors.accentPrimary),
                onPressed: () => honamRelayedCall(context, ref, userId),
              ),
          ],
        ),
      ),
    );
  }
}

/// « Ton code de remise » en grand : c'est lui qu'on donne au coursier.
class HonamCodeCard extends StatelessWidget {
  const HonamCodeCard({super.key, required this.code, required this.courier});

  final String code;
  final String courier;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryCard(
      color: AppColors.terracottaTint,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.honamCode,
            style: TextStyle(fontSize: 13, color: AppColors.onTerracottaTint),
          ),
          Semantics(
            label: code.split('').join(' '),
            child: ExcludeSemantics(
              child: Text(
                code.split('').join(' '),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Text(
            l.honamPGiveCodeOnly(courier),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Le suivi SUR la carte (maquette « Honam · Suivi sur la carte ») : la
/// carte, chargée à la demande, avec l'officine, le coursier et l'adresse.
class HonamMapScreen extends ConsumerWidget {
  const HonamMapScreen({super.key, required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final tracking = ref.watch(honamTrackingProvider(order.id)).valueOrNull;
    final courier = order.courierName ?? l.honamCourier;
    final eta = tracking?.etaMinutes;
    return KoryPage(
      title: l.honamPPharmacyHonam(order.pharmacy?.name ?? l.honamUiPharmacy),
      subtitle: l.honamPInDelivery,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 300,
            child: tracking == null || !tracking.hasPosition
                ? Container(
                    color: AppColors.surfaceElevated,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.honamTrackingWaiting,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : HonamRouteMap(tracking: tracking),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KoryCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: KoryPersonRow(
                    name: eta == null
                        ? courier
                        : l.honamPArrivesIn(courier, eta),
                    subtitle: [
                      if (tracking?.courierVerified ?? false)
                        l.honamPVerifiedCourier,
                      honamTransportLabel(
                        l,
                        tracking?.courierTransport ?? order.courierTransport,
                      ),
                      if (tracking?.distanceKm != null)
                        l.honamPAtKm(tracking!.distanceKm!.toStringAsFixed(1)),
                    ].join(' · '),
                    trailing:
                        (tracking?.courierUserId ?? order.courierUserId) == null
                        ? null
                        : IconButton(
                            tooltip: l.honamPCallRelayed(courier),
                            icon: Icon(
                              Icons.call_outlined,
                              color: AppColors.accentPrimary,
                            ),
                            onPressed: () => honamRelayedCall(
                              context,
                              ref,
                              (tracking?.courierUserId ?? order.courierUserId)!,
                            ),
                          ),
                  ),
                ),
                if (order.deliveryCode != null) ...[
                  const SizedBox(height: 12),
                  HonamCodeCard(code: order.deliveryCode!, courier: courier),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.honamPFollowWithoutMap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quelques tuiles OpenStreetMap autour du coursier, sans bibliothèque de
/// cartes : l'officine (croix verte), le coursier et l'adresse, reliés par
/// le trajet à vol d'oiseau.
class HonamRouteMap extends StatelessWidget {
  const HonamRouteMap({super.key, required this.tracking});

  final CourierTracking tracking;

  static const _zoom = 15;
  static const _tile = 256.0;

  static Offset _project(double lat, double lng) {
    final n = math.pow(2, _zoom).toDouble();
    final x = (lng + 180) / 360 * n;
    final rad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;
    return Offset(x * _tile, y * _tile);
  }

  @override
  Widget build(BuildContext context) {
    final center = _project(tracking.latitude!, tracking.longitude!);
    Offset? at(double? lat, double? lng) =>
        lat == null || lng == null ? null : _project(lat, lng);
    final pharmacy = at(tracking.pharmacyLatitude, tracking.pharmacyLongitude);
    final home = at(tracking.deliveryLatitude, tracking.deliveryLongitude);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final origin = center - Offset(size.width / 2, size.height / 2);
        Offset local(Offset world) => world - origin;
        final firstX = (origin.dx / _tile).floor();
        final firstY = (origin.dy / _tile).floor();
        final lastX = ((origin.dx + size.width) / _tile).floor();
        final lastY = ((origin.dy + size.height) / _tile).floor();
        return ClipRect(
          child: Stack(
            children: [
              Container(color: AppColors.surfaceElevated),
              for (var x = firstX; x <= lastX; x++)
                for (var y = firstY; y <= lastY; y++)
                  Positioned(
                    left: x * _tile - origin.dx,
                    top: y * _tile - origin.dy,
                    child: Image.network(
                      'https://tile.openstreetmap.org/$_zoom/$x/$y.png',
                      width: _tile,
                      height: _tile,
                      headers: const {'User-Agent': 'Pokou/1.0 (suivi Honam)'},
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: _tile, height: _tile),
                    ),
                  ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoutePainter([
                    if (pharmacy != null) local(pharmacy),
                    local(center),
                    if (home != null) local(home),
                  ], AppColors.accentPrimaryDark),
                ),
              ),
              if (pharmacy != null)
                _Marker(
                  at: local(pharmacy),
                  icon: Icons.local_hospital,
                  color: AppColors.feedbackSuccess,
                ),
              if (home != null)
                _Marker(
                  at: local(home),
                  icon: Icons.location_on,
                  color: AppColors.accentPrimaryDark,
                ),
              _Marker(
                at: local(center),
                icon: Icons.delivery_dining,
                color: AppColors.accentPrimaryDark,
              ),
              PositionedDirectional(
                end: 6,
                bottom: 4,
                child: Text(
                  '© OpenStreetMap',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.at, required this.icon, required this.color});

  final Offset at;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx - 16,
    top: at.dy - 16,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
      ),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points, this.color);

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      final length = (b - a).distance;
      if (length == 0) continue;
      final step = (b - a) / length;
      // Le trajet restant en pointillés, comme sur la maquette.
      for (var d = 0.0; d < length; d += 9) {
        canvas.drawLine(
          a + step * d,
          a + step * math.min(d + 4, length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
