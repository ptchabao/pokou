import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Copier, sélectionner et partager le texte d'un message — les gestes
/// qu'on attend d'une bulle, partagés par la discussion à deux et le groupe.
///
/// Le texte d'une bulle n'est pas sélectionnable directement : l'appui long
/// y ouvre déjà le menu (réactions, répondre, modifier). On le copie donc
/// d'un geste depuis ce menu, et « Sélectionner le texte » ouvre le message
/// en grand, où l'on choisit un mot, une adresse ou un numéro.

/// Le texte qu'un message offre à copier, ou `null` s'il n'en a pas (média
/// sans légende, message supprimé, message pas encore déchiffré).
String? copyableText(
  String? content, {
  bool deleted = false,
  bool locked = false,
}) {
  if (deleted || locked) return null;
  final text = content?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

Future<void> copyMessageText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(L.of(context).messageCopied)));
}

Future<void> shareMessageText(BuildContext context, String text) async {
  final box = context.findRenderObject() as RenderBox?;
  await Share.share(
    text,
    sharePositionOrigin: box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size,
  );
}

/// Le message en grand, sélectionnable mot par mot.
Future<void> showSelectableMessage(BuildContext context, String text) {
  final l = L.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.messageSelectText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.actionClose,
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l.messageSelectHint,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                // SelectableText : appui long ou double appui pour choisir
                // un mot, poignées pour étendre, menu Copier / Tout
                // sélectionner du système.
                child: SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareMessageText(sheetContext, text),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(l.actionShare),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await copyMessageText(context, text);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l.messageCopyAll),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Les trois entrées « Copier », « Sélectionner le texte », « Partager »
/// d'un menu de message. [close] referme le menu avant d'agir.
List<Widget> messageTextActionTiles({
  required BuildContext context,
  required String text,
  required VoidCallback close,
}) {
  final l = L.of(context);
  return [
    ListTile(
      leading: const Icon(Icons.copy_rounded),
      title: Text(l.messageCopy),
      onTap: () {
        close();
        copyMessageText(context, text);
      },
    ),
    ListTile(
      leading: const Icon(Icons.text_fields_rounded),
      title: Text(l.messageSelectText),
      onTap: () {
        close();
        showSelectableMessage(context, text);
      },
    ),
    ListTile(
      leading: const Icon(Icons.share_outlined),
      title: Text(l.actionShare),
      onTap: () {
        close();
        shareMessageText(context, text);
      },
    ),
  ];
}
