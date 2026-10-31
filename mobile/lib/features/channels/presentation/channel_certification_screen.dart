import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_payment.dart';
import '../data/channel_model.dart';
import 'channel_controller.dart';

/// Les deux formules, et ce qu'elles coûtent.
///
/// Recopiées du serveur, qui reste seul juge — le client n'envoie que le nom
/// de la formule, jamais un montant. C'est la leçon des campagnes
/// publicitaires, où le prix arrivait de la requête et où n'importe qui
/// pouvait donc s'offrir une semaine au dixième du tarif.
enum CertificationPlan {
  monthly('MONTHLY', 3000),
  annual('ANNUAL', 30000);

  const CertificationPlan(this.code, this.price);

  final String code;
  final int price;
}

/// Faire certifier sa chaîne — un abonnement mensuel ou annuel.
///
/// Le badge existait déjà en base mais rien ne permettait de le demander :
/// il fallait l'accorder à la main. Or c'est lui qui met une chaîne en tête
/// des suggestions, donc qui décide de ce qu'on recommande à quelqu'un qui
/// découvre l'application.
///
/// L'écran dit le prix AVANT la page de paiement, et dit aussi que payer
/// n'accorde rien : l'équipe examine. Découvrir l'un ou l'autre après coup
/// est ce qui transforme une fonctionnalité payante en mauvaise surprise.
class ChannelCertificationScreen extends ConsumerStatefulWidget {
  const ChannelCertificationScreen({super.key, required this.channel});

  final PokouChannel channel;

  @override
  ConsumerState<ChannelCertificationScreen> createState() =>
      _ChannelCertificationScreenState();
}

class _ChannelCertificationScreenState
    extends ConsumerState<ChannelCertificationScreen> {
  CertificationPlan _plan = CertificationPlan.annual;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final l = L.of(context);
    try {
      final url = await ref
          .read(channelRepositoryProvider)
          .requestCertification(widget.channel.id, plan: _plan.code);
      if (!mounted) return;
      await openPaymentGateway(context, url, pendingMessage: l.certifyPending);
      ref.invalidate(myChannelsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.certifyFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: l.certifyTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ExplainerCard(
                    steps: [
                      (
                        icon: Icons.verified_outlined,
                        title: l.certifyWhyTitle,
                        body: l.certifyWhyBody,
                      ),
                      (
                        icon: Icons.fact_check_outlined,
                        title: l.certifyReviewTitle,
                        body: l.certifyReviewBody,
                      ),
                      (
                        icon: Icons.event_repeat_outlined,
                        title: l.certifyRenewTitle,
                        body: l.certifyRenewBody,
                      ),
                      (
                        icon: Icons.replay,
                        title: l.certifyRefundTitle,
                        body: l.certifyRefundBody,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // L'annuel d'abord, et sélectionné : c'est le meilleur
                  // rapport, et l'ordre inverse ferait passer l'économie
                  // pour une option qu'on découvre en dernier.
                  for (final plan in [
                    CertificationPlan.annual,
                    CertificationPlan.monthly,
                  ])
                    RadioListTile<CertificationPlan>(
                      value: plan,
                      groupValue: _plan,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _plan = value!),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        plan == CertificationPlan.annual
                            ? l.certifyPlanAnnual
                            : l.certifyPlanMonthly,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            PayBar(
              price: _plan.price,
              caption: l.adPayCaption,
              actionLabel: l.certifyAction,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
