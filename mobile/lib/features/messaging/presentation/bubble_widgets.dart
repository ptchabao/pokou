import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../data/direct_message_model.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Émojis de réaction rapide, façon barre WhatsApp — six choix courants
/// suffisent à la plupart des réactions, le bouton "plus" couvre le reste
/// sans qu'il faille embarquer un sélecteur d'émojis complet pour ça.
const List<String> kQuickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Barre d'émojis de réaction rapide, partagée par les bulles 1:1 et de
/// groupe — ouverte depuis l'appui long sur une bulle.
class ReactionQuickBar extends StatelessWidget {
  const ReactionQuickBar({
    super.key,
    required this.onPick,
    required this.onMore,
  });

  final void Function(String emoji) onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in kQuickReactionEmojis)
            InkWell(
              onTap: () => onPick(emoji),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
          InkWell(
            onTap: onMore,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.add_circle_outline,
                color: AppColors.chatIconMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boîte de dialogue minimale pour un émoji "libre" — le clavier du système
/// donne déjà accès à tous les émojis (onglet dédié), inutile d'embarquer un
/// sélecteur pour n'en choisir qu'un.
Future<String?> promptCustomEmoji(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(L.of(context).reactWith),
      content: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
        controller: controller,
        autofocus: true,
        maxLength: 16,
        decoration: InputDecoration(hintText: L.of(context).reactPickEmoji),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(L.of(context).actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(L.of(context).reactAction),
        ),
      ],
    ),
  );
}

/// Pastille de réaction superposée au coin de la bulle (façon WhatsApp/
/// iMessage) : émoji + compteur, liseré marqué si c'est ma propre réaction.
/// Toucher une pastille retire/pose la même réaction (bascule), comme
/// toucher un émoji dans la barre rapide.
class ReactionPillRow extends StatelessWidget {
  const ReactionPillRow({super.key, required this.reactions, this.onTap});

  final List<MessageReactionSummary> reactions;
  final void Function(String emoji)? onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      children: [
        for (final reaction in reactions)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(reaction.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reaction.mine
                      ? AppColors.chatActionGreen
                      : AppColors.chatBubbleReceivedBorder,
                  width: reaction.mine ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowTint,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction.emoji, style: const TextStyle(fontSize: 12)),
                  if (reaction.count > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${reaction.count}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bandeau de réponse citée, au-dessus du texte d'un message — bande
/// verticale + auteur + extrait tronqué, dans un ton dérivé de la bulle qui
/// la porte plutôt qu'une nouvelle couleur (voir contrainte de palette).
class ReplyPreviewBanner extends StatelessWidget {
  const ReplyPreviewBanner({
    super.key,
    required this.preview,
    required this.senderLabel,
    required this.isMine,
    this.onTap,
  });

  final MessageReplyPreview preview;

  /// Résolu par l'appelant : « Vous », le nom du contact, ou le nom du
  /// membre du groupe — cette bannière ne sait pas d'où vient le nom.
  final String senderLabel;
  final bool isMine;
  final VoidCallback? onTap;

  String _labelOf(L l) {
    final content = preview.content;
    if (content != null && content.trim().isNotEmpty) return content;
    return switch (preview.messageType) {
      'IMAGE' => l.mediaPhoto,
      'VIDEO' => l.mediaVideo,
      'AUDIO' => l.mediaVoiceNote,
      'DOCUMENT' => l.mediaDocument,
      'POLL' => l.mediaPoll,
      'LOCATION' => l.mediaLocation,
      'CONTACT' => l.mediaContact,
      'STICKER' => l.stickerLabel,
      _ => l.mediaMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Le bandeau de citation doit se détacher de la bulle QUI LE PORTE :
    // un voile olive sur la bulle envoyée (verte très claire), un voile
    // noir sur la bulle reçue (grise). Le noir à 16 % d'avant supposait un
    // fond vert saturé — sur la bulle claire il ferait une tache.
    final tint = isMine
        ? AppColors.chatActionGreen.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.05);
    final barColor = AppColors.chatActionGreen;
    final textColor = AppColors.chatTextReceived;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 32,
              color: barColor,
              margin: const EdgeInsets.only(right: 8),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    _labelOf(L.of(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Libellé « modifié » à côté de l'heure, quand `editedAt` est renseigné.
class EditedLabel extends StatelessWidget {
  const EditedLabel({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        L.of(context).convEdited,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
