import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/pokou_sheet.dart';

/// Ce qu'on peut joindre (Discussions · 2).
enum AttachChoice { gallery, camera, document, location, contact, poll, kory }

/// Discussions · 2 — « Joindre à {nom} » : quatre pastilles en ligne et la
/// note sur la compression.
///
/// La même feuille pour la discussion à deux et le groupe, pour qu'elles ne
/// divergent pas. Ce qui change d'un fil à l'autre est décidé par l'appelant :
///
/// - [offerPoll] : le sondage. Proposé en discussion à deux et en groupe
///   (où il est chiffré de bout en bout : voir groups/data/group_poll.dart).
/// - [offerKory] : la cagnotte Kory, seulement dans un groupe ET là où Kory
///   est ouvert. En lot 1, aucune mention de Kory n'apparaît.
/// - [koryGroupsOnlyNote] : en discussion à deux là où Kory est ouvert, la
///   note rappelle que la cagnotte se crée dans un groupe.
///
/// - [offerContact] : partager un contact — en discussion à deux SEULEMENT.
///   Donner le numéro d'un tiers à tout un groupe, c'est le donner à des
///   gens qu'il ne connaît pas (le serveur le refuse aussi).
///
/// La position, elle, est proposée partout : discussion à deux et groupe.
///
/// La galerie propose photos ET vidéos : la maquette n'a qu'une pastille
/// « Galerie », et la distinction se fait sur le fichier choisi.
Future<AttachChoice?> showAttachSheet(
  BuildContext context, {
  required String targetName,
  bool offerPoll = false,
  bool offerKory = false,
  bool offerContact = false,
  bool koryGroupsOnlyNote = false,
}) {
  return showPokouSheet<AttachChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) {
      final l = L.of(sheetContext);
      final options = <(AttachChoice, IconData, String, Color)>[
        (
          AttachChoice.gallery,
          Icons.photo_outlined,
          l.attachGallery,
          const Color(0xFF3F6FB5),
        ),
        (
          AttachChoice.camera,
          Icons.photo_camera_outlined,
          l.attachCamera,
          AppColors.accentPrimary,
        ),
        (
          AttachChoice.document,
          Icons.description_outlined,
          l.convAttachDocument,
          const Color(0xFF7A6A5C),
        ),
        (
          AttachChoice.location,
          Icons.location_on_outlined,
          l.chatXAttachLocation,
          const Color(0xFF2E8B57),
        ),
        if (offerContact)
          (
            AttachChoice.contact,
            Icons.person_outline,
            l.chatXAttachContact,
            const Color(0xFF3F6FB5),
          ),
        if (offerPoll)
          (
            AttachChoice.poll,
            Icons.bar_chart_rounded,
            l.attachPoll,
            const Color(0xFFB8860B),
          ),
        if (offerKory)
          (
            AttachChoice.kory,
            Icons.savings_outlined,
            l.attachKory,
            const Color(0xFFB8860B),
          ),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.attachTo(targetName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                    tooltip: l.actionClose,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quatre pastilles par ligne : au-delà, les libellés se
              // tassaient jusqu'à devenir illisibles sur un petit écran.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth / 4;
                  return Wrap(
                    alignment: WrapAlignment.start,
                    runSpacing: 6,
                    children: [
                      for (final (choice, icon, label, tint) in options)
                        SizedBox(
                          width: width,
                          child: _AttachPill(
                            icon: icon,
                            label: label,
                            tint: tint,
                            onTap: () => Navigator.pop(sheetContext, choice),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        koryGroupsOnlyNote || offerKory
                            ? '${l.attachCompressNote} ${l.attachKoryGroupsOnly}'
                            : l.attachCompressNote,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttachPill extends StatelessWidget {
  const _AttachPill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
