import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import 'officine_controller.dart';
import 'officine_shell.dart';

/// L'entrée de l'espace officine dans « Plus ».
///
/// Elle n'existe que pour un compte de l'équipe d'une officine : le serveur
/// le dit (`/honam/pharmacy/me` répond 403 aux autres), l'application ne le
/// devine pas. Pour tous les autres, rien ne s'affiche.
class OfficineEntryCard extends ConsumerWidget {
  const OfficineEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final me = ref.watch(officineMeProvider).valueOrNull;
    if (me == null) return const SizedBox.shrink();
    final queue = ref.watch(officineQueueProvider).valueOrNull;
    final toDo = queue?.where((o) => o.needsAction).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ModuleCard(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OfficineShell())),
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
