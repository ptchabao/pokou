import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_pledge_screens.dart';
import 'kory_pot_screen.dart';
import 'kory_ui.dart';

final koryPreviewProvider = FutureProvider.autoDispose
    .family<KoryPreview, String>(
      (ref, code) => ref.watch(koryRepositoryProvider).preview(code),
    );

// ── KOR-10 · Rejoindre ───────────────────────────────────────────────────

/// L'invitation reçue par lien ou par code : ce qu'on rejoint, avant de le
/// rejoindre. Rien n'est enregistré tant qu'on n'a pas touché « Rejoindre ».
class KoryInviteScreen extends ConsumerStatefulWidget {
  const KoryInviteScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<KoryInviteScreen> createState() => _KoryInviteScreenState();
}

class _KoryInviteScreenState extends ConsumerState<KoryInviteScreen> {
  bool _busy = false;

  Future<void> _join(KoryPreview preview) async {
    setState(() => _busy = true);
    try {
      final pot = await ref.read(koryRepositoryProvider).join(preview.joinCode);
      refreshKory(ref, potId: pot.id);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      // Rejoindre, puis s'engager (KOR-12) ; la cagnotte s'ouvre ensuite.
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
      );
      if (!preview.alreadyMember &&
          pot.kind == 'CAGNOTTE' &&
          pot.myPledge == null &&
          !pot.isCollector) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => KoryPledgeScreen(pot: pot)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      koryFailed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(koryPreviewProvider(widget.code));
    final preview = async.valueOrNull;
    if (preview == null) {
      return KoryPage(
        title: l.koryXInvitation,
        loading: async.isLoading,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: KoryNotice(tone: KoryTone.danger, text: l.koryJoinUnknown),
        ),
      );
    }
    final kind = switch (preview.kind) {
      'COTISATION' => l.koryKindCotisation,
      _ => l.koryKindCagnotte,
    };
    final period = switch (preview.period) {
      'WEEKLY' => l.koryPeriodWeekly,
      'MONTHLY' => l.koryPeriodMonthly,
      'QUARTERLY' => l.koryXPeriodQuarterly,
      _ => null,
    };
    return KoryPage(
      title: l.koryXInvitation,
      subtitle: preview.organizerName == null
          ? null
          : l.koryXLinkFrom(preview.organizerName!),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: preview.alreadyMember
                ? l.koryXOpenPot
                : (preview.kind == 'CAGNOTTE'
                      ? l.koryXJoinAndPledge
                      : l.koryJoin),
            busy: _busy,
            onPressed: () => _join(preview),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.koryXNotNow),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            preview.title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            [kind, ?preview.groupName].join(' · '),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          KoryCard(
            child: Column(
              children: [
                if (preview.beneficiaryName != null)
                  KoryLine(l.koryXBeneficiary, preview.beneficiaryName!),
                if (preview.goalAmount != null)
                  KoryLine(l.koryXGoalLabel, formatFcfa(preview.goalAmount!)),
                if (preview.amountPerMember != null && period != null)
                  KoryLine(
                    l.koryXAmountLabel,
                    l.koryPerMember(
                      formatFcfa(preview.amountPerMember!),
                      period,
                    ),
                  ),
                if (preview.dueAt != null)
                  KoryLine(
                    preview.kind == 'COTISATION'
                        ? l.koryXFirstDue
                        : l.koryXClosing,
                    koryDate(context, preview.dueAt!),
                  ),
                KoryLine(
                  l.koryXParticipants,
                  l.koryXIncludingYou(preview.participantsCount),
                ),
                KoryLine(
                  l.koryXAmountsLabel,
                  preview.amountsVisible
                      ? l.koryXVisibleToAll
                      : l.koryXVisibleToCollector,
                ),
              ],
            ),
          ),
          KorySection(l.koryXCollectorLabel),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: KoryPersonRow(
              name: preview.collectorName ?? '—',
              subtitle: preview.collectorPhoneMasked,
            ),
          ),
          if (preview.description != null) ...[
            const SizedBox(height: 12),
            Text(
              preview.description!,
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 16),
          KoryNotice(text: l.koryXJoinNotice),
        ],
      ),
    );
  }
}
