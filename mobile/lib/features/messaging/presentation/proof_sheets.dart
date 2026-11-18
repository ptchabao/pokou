import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';
import '../../../core/widgets/pokou_sheet.dart';

// Les feuilles du mode preuve, communes aux groupes et aux discussions à
// deux : activer, supprimer un message, désactivation réservée, désactiver,
// « en savoir plus ». Extraites ici pour ne toucher que peu de lignes dans
// conversation_screen.dart et group_conversation_screen.dart.

/// « Activer le mode preuve ? » (maquettes 4, 4b) : le même texte pour un
/// groupe et une discussion à deux, à un détail près — qui est prévenu.
Future<bool> showProofActivationSheet(
  BuildContext context, {
  required bool isGroup,
  required String scopeName,
  int? memberCount,
}) async {
  final l = L.of(context);
  final confirmed = await showPokouSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, color: AppColors.accentPrimaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.proofActivateTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              !isGroup
                  ? l.proofActivateDirectBody(scopeName)
                  // La liste des discussions ne porte pas le nombre de
                  // membres : la phrase s'en passe plutôt que d'en inventer un.
                  : memberCount == null
                  ? l.proofActivateGroupBodyAll(scopeName)
                  : l.proofActivateGroupBody(scopeName, '$memberCount'),
            ),
            const SizedBox(height: 14),
            _bullet(
              Icons.info_outline,
              isGroup
                  ? l.proofActivateBulletGroupNotice
                  : l.proofActivateBulletDirectNotice(scopeName),
            ),
            _bullet(Icons.schedule, l.proofActivateBulletFromNow),
            _bullet(Icons.person_outline, l.proofActivateBulletCanDisable),
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.proofModeEnable,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(l.actionCancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

Widget _bullet(IconData icon, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    ],
  ),
);

/// « Désactiver le mode preuve ? » (maquette 10) : simple confirmation, trois
/// puces.
Future<bool> showProofDeactivateSheet(BuildContext context) async {
  final l = L.of(context);
  final confirmed = await showPokouSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, color: AppColors.accentPrimaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.proofDeactivateTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _bullet(Icons.info_outline, l.proofDeactivateBulletNotice),
            _bullet(Icons.history, l.proofDeactivateBulletKeepsRule),
            _bullet(Icons.refresh, l.proofDeactivateBulletReenable),
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.proofModeDisable,
              onPressed: () => Navigator.pop(sheetContext, true),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(l.proofKeepMode),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// « Désactivation réservée » (maquette 7) : l'essai ne suffit pas, il faut
/// payer le badge pour couper le mode preuve en tant qu'administrateur.
enum ProofDisableReservedAction { pay, keep }

Future<ProofDisableReservedAction> showProofDisableReservedSheet(
  BuildContext context, {
  required String trialOrBadgeLabel,
  required Map<String, dynamic>? plan,
}) async {
  final l = L.of(context);
  final choice = await showPokouSheet<ProofDisableReservedAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.accentPrimaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.proofReservedTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l.proofReservedBody),
            const SizedBox(height: 12),
            ModuleCard(
              child: Column(
                children: [
                  _line(l.proofReservedYourBadge, trialOrBadgeLabel),
                  _line(l.proofReservedLevelRequired, l.proofReservedPaidBadge),
                ],
              ),
            ),
            if (plan != null) ...[
              const SizedBox(height: 10),
              ModuleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l.certPlanPrice(
                        formatFcfa(plan['price_ht'] as int),
                        formatFcfa(plan['price_ttc'] as int),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.proofReservedNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.certPayAndShowBadge,
              onPressed: () =>
                  Navigator.pop(sheetContext, ProofDisableReservedAction.pay),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  ProofDisableReservedAction.keep,
                ),
                child: Text(l.proofKeepMode),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return choice ?? ProofDisableReservedAction.keep;
}

Widget _line(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  ),
);

/// « Supprimer ce message ? » (maquette 6) : l'aperçu du message, un
/// avertissement si le mode preuve est actif, et les deux façons de
/// supprimer.
enum ProofDeleteChoice { forAll, forMeOnly }

Future<ProofDeleteChoice?> showProofDeleteSheet(
  BuildContext context, {
  required String preview,
  required bool proofActive,
}) async {
  final l = L.of(context);
  return showPokouSheet<ProofDeleteChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.proofDeleteTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (proofActive) ...[
              const SizedBox(height: 10),
              ModuleCallout(
                tone: CalloutTone.beige,
                title: l.proofDeleteWarningTitle,
                text: l.deleteProofWarning,
              ),
            ],
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.deleteForAll,
              onPressed: () =>
                  Navigator.pop(sheetContext, ProofDeleteChoice.forAll),
            ),
            const SizedBox(height: 8),
            ModuleQuietButton(
              label: l.proofDeleteForMeOnly,
              onPressed: () =>
                  Navigator.pop(sheetContext, ProofDeleteChoice.forMeOnly),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(l.actionCancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// « En savoir plus » depuis le bandeau — l'explication complète du mode
/// preuve, celle de l'offre Pokou certifié.
void showProofLearnMoreSheet(BuildContext context) {
  final l = L.of(context);
  showPokouSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.proofModeTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Text(l.proofLearnMoreBody),
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.actionDone,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );
}
