import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../messaging/presentation/day_separator.dart';
import '../data/status_model.dart';
import 'status_controller.dart';

/// « Vu par » d'un statut — qui l'a vu et à quelle heure.
///
/// Feuille et non écran plein : on consulte ses vues d'un coup d'œil pendant
/// qu'on regarde son propre statut, sans quitter celui-ci.
///
/// Réservé à l'AUTEUR côté API : savoir qui regarde le statut de quelqu'un
/// d'autre n'est le droit de personne.
class StatusViewersSheet extends ConsumerStatefulWidget {
  const StatusViewersSheet({
    super.key,
    required this.statusId,
    required this.viewCount,
  });

  final String statusId;
  final int viewCount;

  /// Ouvre la feuille — enveloppé ici pour que les appelants n'aient pas à
  /// répéter la forme et la couleur du conteneur.
  static Future<void> show(
    BuildContext context, {
    required String statusId,
    required int viewCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) =>
          StatusViewersSheet(statusId: statusId, viewCount: viewCount),
    );
  }

  @override
  ConsumerState<StatusViewersSheet> createState() => _StatusViewersSheetState();
}

class _StatusViewersSheetState extends ConsumerState<StatusViewersSheet> {
  List<StatusViewer>? _viewers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final viewers = await ref
          .read(statusRepositoryProvider)
          .viewers(widget.statusId);
      if (mounted) setState(() => _viewers = viewers);
    } catch (_) {
      if (mounted)
        setState(() => _error = L.of(context).statusViewersUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewers = _viewers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.accentPrimaryDark,
                ),
                const SizedBox(width: 8),
                Text(
                  L
                      .of(context)
                      .statusSeenBy(viewers?.length ?? widget.viewCount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.semanticError,
                  fontSize: 13,
                ),
              ),
            if (viewers == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (viewers != null && viewers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  L.of(context).statusNobodySeen,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            if (viewers != null && viewers.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: viewers.length,
                  itemBuilder: (context, index) {
                    final viewer = viewers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ContactAvatar(
                            avatar: viewer.avatar,
                            displayName: viewer.displayName,
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              viewer.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            // Le jour ET l'heure : un statut vit 24 h, donc
                            // « hier 23:40 » et « aujourd'hui 00:10 » sont
                            // deux moments bien distincts à distinguer.
                            '${dayLabel(L.of(context), viewer.viewedAt)} ${DateFormat.Hm().format(viewer.viewedAt.toLocal())}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
