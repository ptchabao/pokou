import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

// Les éléments du mode preuve, communs aux groupes et aux discussions à
// deux : bandeau permanent, message système, message gardé.

/// Le mode preuve est actif : toute la discussion le sait, en permanence.
class ProofModeBanner extends StatelessWidget {
  const ProofModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.feedbackInfo.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.gavel_outlined, size: 18, color: AppColors.feedbackInfo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              L.of(context).proofModeOnBanner,
              style: const TextStyle(fontSize: 13, color: AppColors.feedbackInfo),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un message supprimé en mode preuve : lisible, BARRÉ, et dit pourquoi il
/// est encore là. L'état ne repose pas sur le barré seul (DS-06) : une icône
/// et un libellé l'accompagnent.
class ProofKeptMessage extends StatelessWidget {
  const ProofKeptMessage({
    super.key,
    required this.author,
    required this.content,
    required this.isMine,
    this.original,
    this.editedAt,
  });

  final String author;
  final String? content;
  final bool isMine;

  /// Renseigné pour un message MODIFIÉ (et non supprimé) en mode preuve.
  final String? original;
  final DateTime? editedAt;

  bool get _edited => original != null;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (content != null)
              Text(
                content!,
                style: _edited
                    ? null
                    : TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textSecondary,
                      ),
              ),
            if (_edited) ...[
              const SizedBox(height: 4),
              Text(
                L.of(context).proofOriginal(original!),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _edited
                        ? '${L.of(context).convEdited} · ${TimeOfDay.fromDateTime(editedAt!.toLocal()).format(context)}'
                        : L.of(context).deletedKept,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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


/// Le message système du mode preuve : au centre, comme un appel terminé —
/// c'est un évènement de la discussion, pas la parole de quelqu'un.
class ProofModeNotice extends StatelessWidget {
  const ProofModeNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.feedbackInfo.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel_outlined, size: 14, color: AppColors.feedbackInfo),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.feedbackInfo)),
            ),
          ],
        ),
      ),
    );
  }
}
