import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/time/server_time.dart';

/// Rendu d'un message de type LOCATION — pas de carte interactive (aucune clé
/// de service de cartes n'est configurée dans ce projet), une carte compacte
/// avec l'étiquette éventuelle, les coordonnées et un bouton qui ouvre l'app
/// de cartes du téléphone. `payload` est la charge utile brute du message
/// (voir api/app/routes/polls.py::_location_payload).
class LocationBubble extends StatefulWidget {
  const LocationBubble({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  State<LocationBubble> createState() => _LocationBubbleState();
}

class _LocationBubbleState extends State<LocationBubble> {
  Timer? _ticker;

  double? get _latitude => (widget.payload['latitude'] as num?)?.toDouble();
  double? get _longitude => (widget.payload['longitude'] as num?)?.toDouble();
  String? get _label => widget.payload['label'] as String?;

  DateTime? get _liveUntil {
    final raw = widget.payload['live_until'] as String?;
    return raw == null ? null : tryParseServerTime(raw);
  }

  bool get _isLive {
    final until = _liveUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    // Le compte à rebours "En direct" doit avancer même si rien d'autre ne
    // reconstruit cette bulle (aucun nouvel événement WS entre deux points).
    if (_isLive) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _remaining(L l, DateTime until) {
    final diff = until.difference(DateTime.now());
    if (diff.inHours >= 1) return l.liveHoursLeft(diff.inHours);
    if (diff.inMinutes >= 1) return l.liveMinutesLeft(diff.inMinutes);
    return l.liveAlmostOver;
  }

  Future<void> _openInMaps() async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) return;
    // `geo:` ouvre directement l'app de cartes installée (Android) ; le lien
    // https sert de repli universel (iOS, ou aucune app `geo:` enregistrée).
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }
    await launchUrl(
      Uri.parse('https://maps.google.com/?q=$lat,$lon'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lat = _latitude;
    final lon = _longitude;
    final textColor = AppColors.chatTextReceived;
    final mutedColor = AppColors.chatIconMuted;
    final accent = AppColors.chatActionGreen;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 96,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.chatBubbleReceived,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on, size: 36, color: accent),
          ),
          const SizedBox(height: 6),
          if (_isLive)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.chatActionGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: accent),
                  const SizedBox(width: 4),
                  // Flexible + ellipsis : "En direct · X h restantes" peut
                  // dépasser la largeur compacte de cette carte, tronquer
                  // vaut mieux qu'un débordement de rendu.
                  Flexible(
                    child: Text(
                      L
                          .of(context)
                          .liveLocation(_remaining(L.of(context), _liveUntil!)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_label != null && _label!.trim().isNotEmpty)
            Text(
              _label!,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          if (lat != null && lon != null)
            Text(
              '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          const SizedBox(height: 6),
          InkWell(
            onTap: (lat == null || lon == null) ? null : _openInMaps,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 16, color: accent),
                const SizedBox(width: 4),
                Text(
                  L.of(context).openInMaps,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
