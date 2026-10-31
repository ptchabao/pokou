import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Ce que l'écran dit d'une conversation avec le bot d'une entreprise.
///
/// À la place du bandeau de chiffrement : celui-ci dirait que le
/// correspondant « n'a pas encore la version qui chiffre », ce qui est
/// faux — un bot ne chiffre JAMAIS, il doit lire pour répondre, et c'est
/// l'entreprise qui reçoit ce qu'on lui écrit. C'est la règle de WhatsApp
/// Business, et elle doit être dite avant le premier message.
class BotConversationNotice extends StatelessWidget {
  const BotConversationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              L.of(context).botConversationNotice,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les boutons d'un message de bot (`payload.bot_buttons`).
///
/// Toucher un bouton envoie son TITRE en réponse citée au message : c'est
/// ce que l'utilisateur voit partir, et le serveur retrouve l'identifiant
/// choisi par le développeur (voir api/app/services/pokou_business/
/// messaging.py::reponse_bouton). Un seul geste, aucun texte à taper.
class BotButtonsRow extends StatelessWidget {
  const BotButtonsRow({
    super.key,
    required this.titles,
    required this.onPressed,
    this.maxWidth = 320,
  });

  final List<String> titles;
  final void Function(String title) onPressed;
  final double maxWidth;

  /// Les titres d'un `payload`, ou une liste vide s'il n'en porte pas.
  static List<String> titlesOf(Map<String, dynamic>? payload) {
    final raw = payload?['bot_buttons'];
    if (raw is! List) return const [];
    return [
      for (final b in raw)
        if (b is Map &&
            b['title'] is String &&
            (b['title'] as String).isNotEmpty)
          b['title'] as String,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final title in titles)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  onPressed: () => onPressed(title),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimaryDark,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
