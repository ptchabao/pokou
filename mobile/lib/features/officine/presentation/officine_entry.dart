import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import 'officine_controller.dart';
import 'officine_registration_screens.dart';
import 'officine_shell.dart';

/// L'entrée de l'espace officine dans « Plus ».
///
/// Pour un compte de l'équipe d'une officine, l'espace officine : le serveur
/// le dit (`/honam/pharmacy/me` répond 403 aux autres), l'application ne le
/// devine pas. Pour tous les autres, « Référencer mon officine » (maquettes
/// Officine 14 à 16), ou la vérification en cours si un dossier attend.
class OfficineEntryCard extends ConsumerWidget {
  const OfficineEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final meState = ref.watch(officineMeProvider);
    final me = meState.valueOrNull;
    if (me == null) {
      // Seulement une fois sûr que le compte n'a pas d'officine.
      if (!meState.hasValue) return const SizedBox.shrink();
      return const _RegistrationEntry();
    }
    final queue = ref.watch(officineQueueProvider).valueOrNull;
    final toDo = queue?.where((o) => o.needsAction).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ModuleCard(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const OfficineShell())),
        child: Row(
          children: [
            const ModuleBadge(
              icon: Icons.local_pharmacy_outlined,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.offiEntryTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    toDo > 0
                        ? l.offiEntryToDo(me.pharmacy.name, toDo)
                        : me.pharmacy.name,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accentPrimary),
          ],
        ),
      ),
    );
  }
}

/// « Référencer mon officine », ou le dossier en vérification (écran 16).
/// Rien si Honam est fermé dans le pays ou si le dossier est validé.
class _RegistrationEntry extends ConsumerWidget {
  const _RegistrationEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final registration = ref.watch(officineRegistrationProvider).valueOrNull;
    if (registration == null ||
        !(registration.pending || registration.canApply)) {
      return const SizedBox.shrink();
    }
    final pending = registration.pending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ModuleCard(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => pending
                  ? OfficineRegistrationPendingScreen(
                      registration: registration,
                    )
                  : OfficineRegistrationInfoScreen(
                      initial: registration.rejected ? registration : null,
                    ),
            ),
          );
          ref.invalidate(officineRegistrationProvider);
          ref.invalidate(officineMeProvider);
        },
        child: Row(
          children: [
            const ModuleBadge(
              icon: Icons.local_pharmacy_outlined,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending
                        ? l.officineRegPendingTitle
                        : l.officineRegEntryTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    pending
                        ? l.officineRegEntryPending
                        : registration.rejected
                        ? l.officineRegEntryRejected
                        : l.officineRegEntrySubtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accentPrimary),
          ],
        ),
      ),
    );
  }
}
