import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';

/// Le suivi de la course (maquettes « Suivi sur la carte », « Suivi sans
/// carte » et Officine 7).
///
/// Sans carte par défaut : une ligne de texte coûte quelques octets, une
/// carte des centaines de kilo-octets. La carte se charge À LA DEMANDE, et
/// jamais en économie de données tant que la personne ne la demande pas.
/// Elle n'existe que pendant la course : la position est effacée à la remise.
class CourierTrackingCard extends ConsumerStatefulWidget {
  const CourierTrackingCard({super.key, required this.orderId, this.asPharmacy = false});

  final int orderId;
  final bool asPharmacy;

  @override
  ConsumerState<CourierTrackingCard> createState() => _CourierTrackingCardState();
}

class _CourierTrackingCardState extends ConsumerState<CourierTrackingCard> {
  CourierTracking? _tracking;
  Timer? _timer;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    // Au rythme où le coursier envoie sa position.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final tracking = await ref
          .read(honamRepositoryProvider)
          .tracking(widget.orderId, asPharmacy: widget.asPharmacy);
      if (!mounted) return;
      setState(() => _tracking = tracking);
      if (!tracking.active) _timer?.cancel();
    } catch (_) {
      // Hors ligne : la dernière position reste affichée, marquée non à jour.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tracking = _tracking;
    if (tracking == null || !tracking.active) return const SizedBox.shrink();
    final dataSaver = ref.watch(appSettingsProvider.select((s) => s.dataSaver));
    final minutes = tracking.at == null ? null : DateTime.now().toUtc().difference(tracking.at!).inMinutes;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delivery_dining_outlined, color: AppColors.accentPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.honamTrackingTitle(tracking.courierName ?? l.honamCourier),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!tracking.hasPosition)
              Text(l.honamTrackingWaiting, style: TextStyle(color: AppColors.textSecondary))
            else ...[
              if (tracking.distanceKm != null)
                Text(l.honamTrackingDistance(tracking.distanceKm!.toStringAsFixed(1))),
              Text(
                tracking.stale
                    ? l.honamTrackingStale
                    : l.honamTrackingUpdated('${minutes ?? 0}'),
                style: TextStyle(
                  fontSize: 12,
                  color: tracking.stale ? AppColors.feedbackWarning : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_showMap)
                _OsmTile(latitude: tracking.latitude!, longitude: tracking.longitude!)
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showMap = true),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(dataSaver ? l.honamTrackingMapDataSaver : l.honamTrackingShowMap),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une seule tuile OpenStreetMap, centrée sur le coursier : de quoi voir le
/// quartier sans embarquer de bibliothèque de cartes. Rechargée seulement
/// quand la position change.
class _OsmTile extends StatelessWidget {
  const _OsmTile({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static const _zoom = 16;
  static const _size = 256.0;

  @override
  Widget build(BuildContext context) {
    final n = math.pow(2, _zoom).toDouble();
    final x = (longitude + 180) / 360 * n;
    final latRad = latitude * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;
    final tileX = x.floor();
    final tileY = y.floor();
    final dx = (x - tileX) * _size;
    final dy = (y - tileY) * _size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              children: [
                Image.network(
                  'https://tile.openstreetmap.org/$_zoom/$tileX/$tileY.png',
                  width: _size,
                  height: _size,
                  headers: const {'User-Agent': 'Pokou/1.0 (suivi Honam)'},
                  errorBuilder: (_, _, _) => Container(color: AppColors.surface),
                ),
                Positioned(
                  left: dx - 14,
                  top: dy - 28,
                  child: const Icon(Icons.location_on, size: 28, color: AppColors.feedbackDanger),
                ),
              ],
            ),
          ),
        ),
        Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
