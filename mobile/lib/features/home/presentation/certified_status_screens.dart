import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/server_time.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart' show KoryLine;
import '../../modules/shared/module_ui.dart';
import '../../messaging/presentation/proof_choose_discussion_screen.dart';
import 'certified_pay_screen.dart';

/// « 3. Badge actif » (maquette 26) : le nom vérifié par l'opérateur, la
/// formule, le prochain paiement, la facture, et l'entrée du mode preuve.
class CertifiedBadgeActiveScreen extends ConsumerWidget {
  const CertifiedBadgeActiveScreen({super.key, required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(String? iso) =>
        iso == null ? '' : DateFormat.yMMMd(locale).format(parseServerTime(iso));
    final operator = status['wallet_operator'] as String?;
    final planCode = status['plan'] as String?;
    final isYearly = planCode?.contains('YEARLY') == true;

    return ModuleScaffold(
      title: l.certTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          const Center(child: VerifiedBadge(size: 72)),
          const SizedBox(height: 16),
          Text(
            l.certBadgeActiveTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l.certBadgeActiveBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status['profile_name'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const VerifiedBadge(size: 18),
                  ],
                ),
                if (operator != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.certNameVerifiedBy(operator),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                KoryLine(l.certFormulaLabel, isYearly ? l.certYearlyLabel : l.certMonthlyLabel),
                KoryLine(
                  l.certNextPaymentLabel,
                  status['plan_price_ttc'] != null
                      ? '${date(status['current_period_end'] as String?)} · ${formatFcfa(status['plan_price_ttc'] as int)} TTC'
                      : date(status['current_period_end'] as String?),
                ),
                if (status['invoice_available'] == true) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _downloadInvoice(context, ref),
                    child: Text(l.certDownloadInvoice),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.proofModeActivatesAnywhere,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ModuleActionButton(
            label: l.proofModeEnable,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProofChooseDiscussionScreen()),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.actionDone),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    try {
      final bytes = await ref.read(apiClientProvider).getBytes('/certified/invoice');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pokou-facture-certifie.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
    }
  }
}

/// « 4. Fin de l'essai » (maquette 105) : trois jours avant, ce que le
/// paiement change et ce que l'absence de paiement retire.
class CertifiedTrialEndingScreen extends StatefulWidget {
  const CertifiedTrialEndingScreen({
    super.key,
    required this.status,
    required this.plans,
  });

  final Map<String, dynamic> status;
  final List<Map<String, dynamic>> plans;

  @override
  State<CertifiedTrialEndingScreen> createState() => _CertifiedTrialEndingScreenState();
}

class _CertifiedTrialEndingScreenState extends State<CertifiedTrialEndingScreen> {
  late String _planCode = widget.plans
      .firstWhere((p) => p['code'] == 'PARTICULIER_MONTHLY', orElse: () => widget.plans.first)['code']
      as String;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final trialEnd = parseServerTime(widget.status['trial_ends_at'] as String);
    final daysLeft = trialEnd.difference(DateTime.now()).inDays.clamp(0, 999);
    final plan = widget.plans.firstWhere((p) => p['code'] == _planCode, orElse: () => widget.plans.first);

    Widget list(List<String> items, bool positive) => ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                positive ? l.certIfYouPay : l.certWithoutPayment,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        positive ? Icons.check : Icons.close,
                        size: 16,
                        color: positive ? AppColors.feedbackSuccess : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
            ],
          ),
        );

    return ModuleScaffold(
      title: l.certTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          const Icon(Icons.schedule, size: 48, color: AppColors.accentPrimary),
          const SizedBox(height: 12),
          Text(
            l.certTrialEndingTitle('$daysLeft', DateFormat.yMMMd(locale).format(trialEnd)),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          list([l.certIfYouPayBadge, l.certIfYouPayProof], true),
          const SizedBox(height: 10),
          list([l.certWithoutPaymentActivate, l.certWithoutPaymentTraces], false),
          const SizedBox(height: 16),
          ModuleSectionTitle(l.certFormulaLabel),
          for (final p in widget.plans)
            Padding(
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
                          Text(p['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(formatFcfa(p['price_ttc'] as int)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          ModuleActionButton(
            label: l.certPayAndShowBadge,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CertifiedPayScreen(plan: plan)),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.certLater),
            ),
          ),
        ],
      ),
    );
  }
}
