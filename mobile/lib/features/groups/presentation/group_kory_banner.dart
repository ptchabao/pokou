import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/data/kory_model.dart';
import '../../kory/presentation/kory_controller.dart';
import '../../kory/presentation/kory_pot_screen.dart';

/// Les cagnottes rattachées à un groupe (GET /kory/pots?group_id=…).
final groupKoryPotsProvider = FutureProvider.autoDispose
    .family<List<KoryPot>, int>(
      (ref, groupId) => ref.watch(koryRepositoryProvider).pots(groupId: groupId),
    );

/// Discussions · 1 — « Cagnotte en cours · {titre} » sous l'en-tête d'un
/// groupe, seulement là où Kory est ouvert : en Lot 1, rien de Kory ne
/// s'affiche. Toucher le bandeau ouvre la cagnotte.
///
/// Un échec de chargement ne montre rien : le bandeau est un raccourci, pas
/// une information dont la conversation aurait besoin.
class GroupKoryBanner extends ConsumerWidget {
  const GroupKoryBanner({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(currentCountryConfigProvider).has('kory')) {
      return const SizedBox.shrink();
    }
    final pots = ref.watch(groupKoryPotsProvider(groupId)).valueOrNull;
    final pot = pots?.where((p) => p.isOpen).firstOrNull;
    if (pot == null) return const SizedBox.shrink();

    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final amount = NumberFormat.decimalPattern(locale);
    final parts = [
      pot.goalAmount != null
          ? l.groupKoryProgress(
              amount.format(pot.confirmedTotal),
              amount.format(pot.goalAmount),
            )
          : l.groupKoryCollected(amount.format(pot.confirmedTotal)),
      if (pot.dueAt != null)
        l.groupKoryCloses(DateFormat.MMMd(locale).format(pot.dueAt!.toLocal())),
    ];

    return Material(
      color: AppColors.brandTerracotta100,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                size: 18,
                color: AppColors.brandEbene,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.groupKoryOngoing(pot.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEbene,
                      ),
                    ),
                    Text(
                      parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.brandEbene,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.brandEbene,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
