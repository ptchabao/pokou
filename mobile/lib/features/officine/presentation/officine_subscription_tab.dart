import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_payment.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_shell.dart';
import 'officine_ui.dart';

/// Officine · 5. Abonnement : la formule (Wétri HONAM au mois, ÉPÉ HONAM à
/// l'année) et le crédit prépayé, décompté de 100 FCFA HT par commande
/// payée. Le paiement passe par CashPay ; rien n'est accordé avant sa
/// confirmation par le serveur.
class OfficineSubscriptionTab extends ConsumerStatefulWidget {
  const OfficineSubscriptionTab({super.key, required this.me});

  final OfficineMe me;

  @override
  ConsumerState<OfficineSubscriptionTab> createState() =>
      _OfficineSubscriptionTabState();
}

class _OfficineSubscriptionTabState
    extends ConsumerState<OfficineSubscriptionTab> {
  int _credit = 5000;
  bool _busy = false;

  Future<void> _pay(Future<Map<String, dynamic>> Function() open) async {
    if (_busy) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final payment = await open();
      if (!mounted) return;
      final simulated = await openPaymentResponse(
        context,
        payment,
        pendingMessage: l.offiPaymentPending,
      );
      // Pays de test : l'abonnement ou le crédit est déjà là.
      if (simulated) ref.invalidate(officineMeProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final me = widget.me;
    final repository = ref.read(officineRepositoryProvider);
    final testCountry = ref.watch(currentCountryConfigProvider).testOnly;
    final wetri = me.pricesHt['WETRI'] ?? 0;
    final epe = me.pricesHt['EPE'] ?? 0;
    final vat = (me.vatRate * 100).round();
    final freeMonths = wetri > 0 && epe > 0 ? (12 * wetri - epe) ~/ wetri : 0;
    // Un tarif absent de la configuration du pays : « non fixé », jamais
    // « 0 FCFA », et pas de souscription possible.
    final unset = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    final activeWetri = me.subscribed && me.plan == 'WETRI';
    final activeEpe = me.subscribed && me.plan == 'EPE';

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(officineMeProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OfficineTabHeader(me: me, title: l.offiSubscriptionTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.offiPlanWetri,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (activeWetri)
                            OfficineTag(
                              l.offiActive,
                              tone: OfficineTone.success,
                            ),
                        ],
                      ),
                      if (wetri > 0) ...[
                        Text(
                          l.offiPerMonthHt(fcfa(wetri)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l.offiTtcWithVat(fcfa(me.ttc(wetri)), vat),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else
                        Text(l.hnxPriceUnset, style: unset),
                      if (activeWetri && me.subscriptionUntil != null)
                        Text(
                          l.offiNextPayment(
                            honamDateTime(context, me.subscriptionUntil!),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 12),
                      HonamPrimaryButton(
                        label: activeWetri ? l.offiRenewNow : l.offiChoose,
                        busy: _busy,
                        onPressed: wetri > 0
                            ? () => _pay(() => repository.subscribe('WETRI'))
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          testCountry
                              ? l.hnxTestPaymentNote
                              : l.offiPaidByCashPay,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                officineGap,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandEbene,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.offiPlanEpe,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (activeEpe)
                            OfficineTag(
                              l.offiActive,
                              tone: OfficineTone.success,
                            )
                          else if (freeMonths > 0)
                            HonamPill(
                              l.offiFreeMonths(freeMonths),
                              background: AppColors.brandOr,
                              ink: AppColors.brandEbene,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        epe > 0
                            ? l.offiEpePitch(
                                fcfa(epe),
                                fcfa(12 * wetri),
                                fcfa(me.ttc(epe)),
                              )
                            : l.hnxPriceUnset,
                        style: const TextStyle(
                          color: Color(0xFFE6D9BD),
                          fontSize: 13,
                        ),
                      ),
                      if (activeEpe && me.subscriptionUntil != null)
                        Text(
                          l.offiNextPayment(
                            honamDateTime(context, me.subscriptionUntil!),
                          ),
                          style: const TextStyle(
                            color: Color(0xFFE6D9BD),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy || epe <= 0
                              ? null
                              : () => _pay(() => repository.subscribe('EPE')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.brandOr),
                            minimumSize: const Size(48, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            activeEpe ? l.offiRenewNow : l.offiSwitchToYearly,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ModuleSectionTitle(
                  l.offiCreditTitle,
                  subtitle: l.offiCreditSubtitle,
                ),
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OfficineBigAmount(
                              label: l.offiCreditBalance,
                              amount: me.creditBalanceHt,
                              caption: l.offiOrdersLeft(me.ordersLeft),
                            ),
                          ),
                        ],
                      ),
                      if (me.ordersLeft <= 10) ...[
                        const SizedBox(height: 8),
                        OfficineTag(
                          l.offiCreditLow,
                          tone: OfficineTone.warning,
                        ),
                      ],
                      const SizedBox(height: 12),
                      ModuleAmountPicker(
                        amounts: const [2000, 5000, 10000, 20000],
                        selected: _credit,
                        onChanged: (v) => setState(() => _credit = v),
                      ),
                      const SizedBox(height: 12),
                      HonamPrimaryButton(
                        label: l.offiBuyCredit(
                          fcfa(_credit),
                          fcfa(me.ttc(_credit)),
                        ),
                        busy: _busy,
                        onPressed: () =>
                            _pay(() => repository.buyCredit(_credit)),
                      ),
                    ],
                  ),
                ),
                OfficineNote(l.offiPricesHt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
