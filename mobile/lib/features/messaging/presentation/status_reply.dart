import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Réponse privée à un statut (fiche Statuts · 7).
///
/// ── Le format ─────────────────────────────────────────────────────────
///
/// La réponse part comme un message à deux ORDINAIRE, chiffré de bout en
/// bout : la citation du statut voyage DANS le texte, jamais en clair à côté
/// (le serveur n'en saura rien). Première ligne : un marqueur invisible
/// suivi de « ↩ » et de la légende du statut ; le reste est la réponse.
///
/// Une application qui ne connaît pas ce format affiche simplement
/// « ↩ légende » puis la réponse : lisible partout, sans rien casser.
const _marker = '⁣↩ ';

/// Le texte à envoyer pour répondre à un statut dont la légende est
/// [caption] (ou son type, « Photo », pour un statut sans texte).
String encodeStatusReply({required String caption, required String text}) {
  final firstLine = caption.replaceAll('\n', ' ').trim();
  return '$_marker$firstLine\n$text';
}

/// La citation et la réponse d'un message, si c'est une réponse à un
/// statut — `null` sinon. Reconnaît aussi l'ancien format (la ligne
/// « ↩ En réponse à ton statut » des versions précédentes).
({String caption, String text})? decodeStatusReply(String? content, L l) {
  if (content == null) return null;
  final newline = content.indexOf('\n');
  if (newline < 0) return null;
  final first = content.substring(0, newline);
  final rest = content.substring(newline + 1);
  if (first.startsWith(_marker)) {
    return (caption: first.substring(_marker.length), text: rest);
  }
  if (first == l.statusReplyQuote) return (caption: '', text: rest);
  return null;
}

/// La carte-vignette « {Nom} · Statut » et la légende citée, en tête de la
/// bulle.
class StatusReplyCard extends StatelessWidget {
  const StatusReplyCard({
    super.key,
    required this.title,
    required this.caption,
    required this.isMine,
  });

  /// « Edem K. · Statut », ou « Ton statut » quand on m'a répondu.
  final String title;
  final String caption;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final tint = isMine
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.chatActionGreen.withValues(alpha: 0.10);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.brandTerracotta100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.amp_stories_outlined,
              size: 18,
              color: AppColors.brandEbene,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.chatTextReceived,
                  ),
                ),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.chatTextReceived.withValues(alpha: 0.8),
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

/// « Ta réponse au statut de {nom} est arrivée ici, en privé. Les autres
/// contacts ne la voient pas. » — au-dessus de la première réponse.
class StatusReplyNotice extends StatelessWidget {
  const StatusReplyNotice({super.key, required this.authorName});

  final String authorName;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandTerracotta100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 13, color: AppColors.brandEbene),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              L.of(context).statusReplyNotice(authorName),
              style: const TextStyle(fontSize: 11.5, color: AppColors.brandEbene),
            ),
          ),
        ],
      ),
    ),
  );
}
