import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../messaging/presentation/day_separator.dart';
import '../data/status_model.dart';
import 'status_controller.dart';

/// « Vu par » d'un statut — qui l'a vu, à quelle heure, et le cœur qu'il a
/// posé dessus.
///
/// Feuille et non écran plein : on consulte ses vues d'un coup d'œil pendant
/// qu'on regarde son propre statut, sans quitter celui-ci.
///
/// Réservé à l'AUTEUR côté API : savoir qui regarde le statut de quelqu'un
/// d'autre n'est le droit de personne.
///
/// Le `Future` se résout à `true` quand le statut a été SUPPRIMÉ depuis
/// cette feuille — l'appelant (la visionneuse) doit alors se fermer aussi,
/// plutôt que de continuer à défiler un statut qui n'existe plus.
class StatusViewersSheet extends ConsumerStatefulWidget {
  const StatusViewersSheet({super.key, required this.status});

  final PokouStatus status;

  /// Ouvre la feuille — enveloppé ici pour que les appelants n'aient pas à
  /// répéter la forme et la couleur du conteneur.
  static Future<bool?> show(BuildContext context, {required PokouStatus status}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => StatusViewersSheet(status: status),
    );
  }

  @override
  ConsumerState<StatusViewersSheet> createState() => _StatusViewersSheetState();
}

class _StatusViewersSheetState extends ConsumerState<StatusViewersSheet> {
  List<StatusViewer>? _viewers;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final viewers = await ref
          .read(statusRepositoryProvider)
          .viewers(widget.status.id);
      if (mounted) setState(() => _viewers = viewers);
    } catch (_) {
      if (mounted)
        setState(() => _error = L.of(context).statusViewersUnavailable);
    }
  }

  /// Partage le statut hors de Pokou — texte ou légende, faute d'un vrai
  /// transfert vers une discussion depuis cet écran.
  Future<void> _forward() async {
    final l = L.of(context);
    final text = widget.status.textContent?.trim();
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.statusForwardMediaUnsupported)));
      return;
    }
    await Share.share(text);
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.statusDeleteTitle),
        content: Text(l.statusDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.semanticError,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(statusRepositoryProvider).delete(widget.status.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.statusDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final viewers = _viewers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.statusSeenBy(viewers?.length ?? widget.status.viewCount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: l.actionClose,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.semanticError,
                    fontSize: 13,
                  ),
                ),
              ),
            if (viewers == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (viewers != null && viewers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text(
                  l.statusNobodySeen,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            if (viewers != null && viewers.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          if (viewer.liked) ...[
                            const Icon(
                              Icons.favorite,
                              size: 15,
                              color: AppColors.semanticError,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            // Le jour ET l'heure : un statut vit 24 h, donc
                            // « hier 23:40 » et « aujourd'hui 00:10 » sont
                            // deux moments bien distincts à distinguer.
                            '${dayLabel(l, viewer.viewedAt)} ${DateFormat.Hm().format(viewer.viewedAt.toLocal())}',
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
            const SizedBox(height: 8),
            // STA-6 : la liste est privée, les réponses aussi.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l.statusViewersNote,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _forward,
                    icon: const Icon(Icons.forward_outlined, size: 18),
                    label: Text(l.conversationForward),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.semanticError,
                      side: const BorderSide(color: AppColors.semanticError),
                    ),
                    icon: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(l.actionDelete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
