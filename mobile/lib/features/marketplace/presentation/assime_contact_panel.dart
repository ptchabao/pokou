import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';

/// Assimé 4 · Contacter le vendeur : tant que la discussion est vide, la
/// carte « Avant d'acheter », la mention « Ton numéro n'est pas montré au
/// vendeur » et trois réponses rapides. Une réponse rapide REMPLIT le
/// champ de saisie : rien ne part sans que l'acheteur appuie sur envoyer.
class AssimeContactPanel extends StatelessWidget {
  const AssimeContactPanel({super.key, required this.onQuickReply});

  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget tip(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: AppColors.feedbackSuccess),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
    final replies = [
      l.assimeQuickPhotos,
      l.assimeQuickAvailable,
      l.assimeQuickNegotiable,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.assimeBeforeBuying,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                tip(l.assimeTipPublicPlace),
                tip(l.assimeTipNoAdvance),
                tip(l.assimeTipNoCode),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.assimeNumberHidden,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: replies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(replies[i]),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.accentPrimary),
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                onPressed: () => onQuickReply(replies[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
