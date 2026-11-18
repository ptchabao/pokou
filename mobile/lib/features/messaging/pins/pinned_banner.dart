import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_sheet.dart';
import '../../../l10n/app_localizations.dart';
import 'message_pins.dart';

/// L'extrait d'un message pour le bandeau d'épingle ou la liste des
/// importants : son texte DÉCHIFFRÉ sur ce téléphone, sinon la nature de la
/// pièce jointe (« Photo »), sinon « Message ». Un message resté chiffré
/// (`locked`) ne montre jamais son chiffré.
String messageExcerpt(
  L l, {
  required String? content,
  required String? messageType,
  bool locked = false,
}) {
  final text = content?.trim();
  if (!locked && text != null && text.isNotEmpty) {
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
  return switch (messageType) {
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

/// Le bandeau en haut d'une discussion qui montre le message épinglé.
///
/// Toucher fait défiler jusqu'au message affiché, puis passe au suivant
/// (indicateur « 1/3 ») : avec plusieurs épingles, des touches successives
/// les parcourent toutes, comme chez WhatsApp.
class PinnedMessagesBanner extends StatefulWidget {
  const PinnedMessagesBanner({
    super.key,
    required this.pins,
    required this.excerptFor,
    required this.onOpen,
  });

  /// Les épingles actives, la plus récente d'abord.
  final List<MessagePin> pins;

  /// L'extrait déchiffré localement de chaque message épinglé.
  final String Function(String messageId) excerptFor;

  /// Défile jusqu'au message.
  final void Function(String messageId) onOpen;

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    if (pins.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final index = _index % pins.length;
    final current = pins[index];
    return Semantics(
      button: true,
      label: l.msgPinBannerLabel,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: () {
            widget.onOpen(current.messageId);
            if (pins.length > 1) {
              setState(() => _index = (index + 1) % pins.length);
            }
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (pins.length > 1) ...[
                  _Segments(count: pins.length, current: index),
                  const SizedBox(width: 10),
                ],
                const Icon(
                  Icons.push_pin_outlined,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.msgPinBannerLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      Text(
                        widget.excerptFor(current.messageId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pins.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      l.msgPinCounter(index + 1, pins.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les petits traits verticaux de WhatsApp : un par épingle, celui affiché
/// en couleur.
class _Segments extends StatelessWidget {
  const _Segments({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Container(
                width: 3,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: i == current
                      ? AppColors.accentPrimary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le choix de durée : 24 h, 7 jours, 30 jours. Renvoie des secondes, ou
/// `null` si la feuille est fermée sans choix.
Future<int?> showPinDurationSheet(
  BuildContext context, {
  required bool replacesOldest,
}) {
  final l = L.of(context);
  final labels = {
    pinDurations[0]: l.msgPin24h,
    pinDurations[1]: l.msgPin7d,
    pinDurations[2]: l.msgPin30d,
  };
  return showPokouSheet<int>(
    context: context,
    scrollable: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              l.msgPinDurationTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              replacesOldest ? l.msgPinReplaceNote : l.msgPinDurationHint,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          for (final entry in labels.entries)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(entry.value),
              onTap: () => Navigator.pop(sheetContext, entry.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Le message à montrer après un geste d'épinglage.
String pinOutcomeMessage(L l, PinOutcome outcome, {required bool pinned}) =>
    switch (outcome) {
      PinOutcome.done => pinned ? l.msgPinDone : l.msgPinRemoved,
      PinOutcome.forbidden => l.msgPinForbidden,
      PinOutcome.failed => l.msgPinFailed,
    };
