import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';
import 'certified_pay_screen.dart';
import 'certified_pro_screen.dart';
import 'certified_status_screens.dart';
import '../../../core/time/server_time.dart';
import '../../../core/widgets/skeleton.dart';

final _certifiedProvider =
    FutureProvider.autoDispose<
      ({Map<String, dynamic> status, Map<String, dynamic> offer})
    >((ref) async {
      final api = ref.watch(apiClientProvider);
      final results = await Future.wait([
        api.get('/certified/me'),
        api.get('/certified/offer'),
      ]);
      return (
        status: results[0] as Map<String, dynamic>,
        offer: results[1] as Map<String, dynamic>,
      );
    });

/// Pokou certifié (section 9.5) : l'offre, l'essai, et chacun des écrans
/// qu'un abonnement traverse — « Badge actif », « Noms différents », « Fin
/// de l'essai », « Badge en pause » — selon l'état renvoyé par le serveur.
///
/// Un ROUTEUR, volontairement : les maquettes traitent chaque état comme un
/// écran séparé, et les mélanger dans une seule liste qui s'allonge ou se
/// raccourcit (comme le faisait l'ancienne version) cache le fait que
/// « Badge en pause » n'a RIEN à voir avec l'offre qui s'affiche en dessous.
class CertifiedScreen extends ConsumerWidget {
  const CertifiedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final data = ref.watch(_certifiedProvider);

    return data.when(
      loading: () => ModuleScaffold(title: l.certTitle, child: const SkeletonCards()),
      error: (_, _) => ModuleScaffold(
        title: l.certTitle,
        child: ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
      ),
      data: (data) {
        final status = data.status;
        final state = status['status'] as String;
        // La formule Pro a son propre parcours : justificatif d'abord,
        // paiement après validation (maquettes Pro).
        final plans = [
          for (final plan in (data.offer['plans'] as List).cast<Map<String, dynamic>>())
            if (!(plan['code'] as String).startsWith('PRO')) plan,
        ];
        void refresh() {
          ref.invalidate(_certifiedProvider);
          ref.read(authControllerProvider.notifier).reloadProfile();
        }

        if (state == 'PAUSED') {
          return _BadgePausedScreen(status: status, plans: plans, onChanged: refresh);
        }
        if (state == 'NAME_MISMATCH') {
          final plan = plans.where((p) => p['code'] == status['plan']).firstOrNull ?? plans.firstOrNull;
          return CertifiedPayScreen(
            plan: plan ?? const {'code': 'PARTICULIER_MONTHLY', 'label': ''},
            nameMismatch: true,
            onResolved: refresh,
          );
        }
        if (state == 'ACTIVE') {
          return CertifiedBadgeActiveScreen(status: status);
        }
        if (state == 'TRIAL') {
          final trialEnd = parseServerTime(status['trial_ends_at'] as String);
          if (trialEnd.difference(DateTime.now()).inDays <= 3) {
            return CertifiedTrialEndingScreen(status: status, plans: plans);
          }
        }
        return _OfferScreen(
          status: status,
          offer: data.offer,
          plans: plans,
          onTrialStarted: refresh,
        );
      },
    );
  }
}

/// « 1. Offre » (maquette 25/66) : l'accroche, les trois avantages, la
/// formule, puis l'essai ou le paiement direct.
class _OfferScreen extends ConsumerStatefulWidget {
  const _OfferScreen({
    required this.status,
    required this.offer,
    required this.plans,
    required this.onTrialStarted,
  });

  final Map<String, dynamic> status;
  final Map<String, dynamic> offer;
  final List<Map<String, dynamic>> plans;
  final VoidCallback onTrialStarted;

  @override
  ConsumerState<_OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<_OfferScreen> {
  late String _planCode = widget.plans.first['code'] as String;
  bool _busy = false;

  Future<void> _startTrial() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post('/certified/trial');
      widget.onTrialStarted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = widget.plans.firstWhere((p) => p['code'] == _planCode, orElse: () => widget.plans.first);
    final yearly = widget.plans.where((p) => p['code'].toString().contains('YEARLY')).firstOrNull;
    final monthly = widget.plans.where((p) => p['code'].toString().contains('MONTHLY')).firstOrNull;

    return ModuleScaffold(
      title: l.certTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VerifiedBadge(size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.certPitch,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _advantage(Icons.person_outline, l.certAdvantageNameTitle, l.certAdvantageNameBody),
          _advantage(Icons.schedule, l.certAdvantageProofTitle, l.certAdvantageProofBody),
          _advantage(Icons.description_outlined, l.certAdvantageExportTitle, l.certAdvantageExportBody),
          const SizedBox(height: 10),
          ModuleSectionTitle(l.certFormulaLabel),
          if (monthly != null)
            _planChoice(monthly, l.certMonthlyLabel)
          else
            const SizedBox.shrink(),
          if (yearly != null)
            _planChoice(
              yearly,
              l.certYearlyLabel,
              // « Deux mois offerts » se DÉDUIT des deux prix de l'API.
              badge: monthly == null
                  ? null
                  : switch (((monthly['price_ht'] as int) * 12 - (yearly['price_ht'] as int)) ~/
                        (monthly['price_ht'] as int)) {
                      final months when months > 0 => l.certMonthsOffered(months),
                      _ => null,
                    },
            ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CertifiedProScreen()),
              ),
              child: Text(l.certSeeProOffer),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.status['trial_available'] == true) ...[
            Text(
              l.certTrialNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ModuleActionButton(
              label: l.certStartTrial('${widget.offer['trial_days']}'),
              busy: _busy,
              onPressed: _busy ? null : _startTrial,
            ),
            const SizedBox(height: 6),
          ] else if (widget.status['status'] == 'EXPIRED') ...[
            Text(
              l.certExpired,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.feedbackDanger),
            ),
            const SizedBox(height: 10),
          ],
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CertifiedPayScreen(plan: plan)),
              ),
              child: Text(l.certPayNowShowBadge),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advantage(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.accentPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(body, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _planChoice(Map<String, dynamic> p, String title, {String? badge}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ModuleCard(
          onTap: () => setState(() => _planCode = p['code'] as String),
          child: Row(
            children: [
              Radio<String>(
                value: p['code'] as String,
                groupValue: _planCode,
                onChanged: (v) => setState(() => _planCode = v!),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.terracottaTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    Text('${formatFcfa(p['price_ht'] as int)} HT'),
                    Text(
                      l10nTtcLine(context, p),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// « 5. Badge en pause » (maquette 105) : un écran DÉDIÉ, sans la liste des
/// formules ni la carte Pro en dessous — sinon la personne croit devoir
/// re-choisir une formule alors qu'elle en a déjà une.
class _BadgePausedScreen extends StatelessWidget {
  const _BadgePausedScreen({required this.status, required this.plans, required this.onChanged});

  final Map<String, dynamic> status;
  final List<Map<String, dynamic>> plans;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(String? iso) =>
        iso == null ? '' : DateFormat.yMMMd(locale).format(parseServerTime(iso));

    return ModuleScaffold(
      title: l.certPausedScreenTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.feedbackWarning),
          const SizedBox(height: 14),
          _BadgePaused(
            status: status,
            plans: plans,
            date: date,
            onPay: (code) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CertifiedPayScreen(
                    plan: plans.firstWhere((p) => p['code'] == code),
                  ),
                ),
              );
              onChanged();
            },
            onChangePlan: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// « 590 FCFA TTC par mois » / « 5 900 FCFA TTC par an » sous le prix HT
/// d'une formule (maquette 25).
String l10nTtcLine(BuildContext context, Map<String, dynamic> plan) {
  final l = L.of(context);
  final ttc = formatFcfa(plan['price_ttc'] as int);
  return (plan['days'] as int? ?? 30) >= 365 ? l.certTtcPerYear(ttc) : l.certTtcPerMonth(ttc);
}

class _BadgePaused extends StatelessWidget {
  const _BadgePaused({
    required this.status,
    required this.plans,
    required this.date,
    required this.onPay,
    this.onChangePlan,
  });

  final Map<String, dynamic> status;
  final List<Map<String, dynamic>> plans;
  final String Function(String?) date;
  final void Function(String planCode) onPay;

  /// « Changer de formule » (maquette 105) : ramène à l'offre, où les deux
  /// formules redeviennent choisissables.
  final VoidCallback? onChangePlan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final code = status['plan'] as String?;
    final plan =
        plans.where((p) => p['code'] == code).firstOrNull ?? plans.firstOrNull;
    Widget list(String title, List<String> items) => ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.certPausedTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          l.certPausedBody(
            date(status['current_period_end'] as String?),
            date(status['paused_since'] as String?),
            '${status['grace_days'] ?? 7}',
          ),
        ),
        const SizedBox(height: 12),
        list(l.certWhatRemains, [l.certRemainsChats, l.certRemainsTraces]),
        const SizedBox(height: 8),
        list(l.certWhatPaused, [l.certPausedBadge, l.certPausedProof]),
        const SizedBox(height: 8),
        ModuleCallout(tone: CalloutTone.beige, text: l.certPausedWallet),
        if (plan != null) ...[
          const SizedBox(height: 12),
          ModuleActionButton(
            label: l.certPausedPay(formatFcfa(plan['price_ttc'] as int)),
            onPressed: () => onPay(plan['code'] as String),
          ),
          Center(
            child: TextButton(
              onPressed: onChangePlan,
              child: Text(
                l.certChangePlan,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
