import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';

/// Les deux formules, en montants ronds TTC — ceux du serveur
/// (`PRODUCT_BOOST_OPTIONS`), qui reste seul à facturer.
const assimePromoteOptions = {3: 600, 7: 1300};

/// Assimé 10 · Mettre en avant : 3 ou 7 jours, ce que chacune donne, le
/// récapitulatif et le paiement. Rend le nombre de jours choisi ; le
/// paiement Mobile Money part ensuite de `MarketplaceActions.boostProduct`.
class AssimePromoteScreen extends StatefulWidget {
  const AssimePromoteScreen({super.key, required this.product});

  final MarketplaceProduct product;

  @override
  State<AssimePromoteScreen> createState() => _AssimePromoteScreenState();
}

class _AssimePromoteScreenState extends State<AssimePromoteScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.decimalPattern(locale);
    final end = DateTime.now().add(Duration(days: _days));
    Widget perk(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: AppColors.feedbackSuccess),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
    Widget option(int days, List<Widget> perks) {
      final selected = _days == days;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ModuleCard(
          onTap: () => setState(() => _days = days),
          backgroundColor: selected ? AppColors.terracottaTint : null,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.assimePromoteDays(days),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${money.format(assimePromoteOptions[days])} FCFA',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              ...perks,
            ],
          ),
        ),
      );
    }

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ModuleScaffold(
        title: l.assimePromote,
        subtitle: '${widget.product.name} · ${widget.product.price} FCFA',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            option(3, [perk(l.assimePromoteTop)]),
            option(7, [
              perk(l.assimePromoteTop),
              perk(l.assimePromoteStatus),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.assimePromoteCheaper,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.feedbackSuccess,
                  ),
                ),
              ),
            ]),
            Text(
              l.assimePromoteTtc,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  line(l.assimePromoteStart, l.assimePromoteStartNow),
                  Divider(height: 1, color: AppColors.border),
                  line(
                    l.assimePromoteEnd,
                    DateFormat('EEEE d MMM', locale).format(end),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  line(l.assimePromotePayment, l.assimePromotePaymentMm),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ModuleCallout(
              tone: CalloutTone.beige,
              text: l.assimePromoteModeration,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.assimePromotePay(
              money.format(assimePromoteOptions[_days]),
            ),
            onPressed: () => Navigator.of(context).pop(_days),
          ),
        ),
      ),
    );
  }
}
