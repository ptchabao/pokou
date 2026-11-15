import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/soft_icon_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_account_tab.dart';
import 'officine_controller.dart';
import 'officine_history_tab.dart';
import 'officine_orders_tab.dart';
import 'officine_subscription_tab.dart';
import 'officine_ui.dart';

/// L'espace officine sur téléphone (maquettes Honam, sections 1, 2 et 25).
///
/// Une coquille à part, avec SA barre du bas — Commandes, Historique,
/// Abonnement, Compte : l'équipe d'une officine y passe sa journée de
/// comptoir, et n'a rien à faire des onglets de la messagerie pendant ce
/// temps. Les écrans d'une commande sont poussés par-dessus, sans barre,
/// avec leurs boutons épinglés.
class OfficineShell extends ConsumerStatefulWidget {
  const OfficineShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<OfficineShell> createState() => _OfficineShellState();
}

class _OfficineShellState extends ConsumerState<OfficineShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(officineMeProvider);
    final me = async.valueOrNull;

    final Widget body;
    if (me != null) {
      body = IndexedStack(
        index: _tab,
        children: [
          OfficineOrdersTab(me: me),
          OfficineHistoryTab(me: me),
          OfficineSubscriptionTab(me: me),
          OfficineAccountTab(me: me),
        ],
      );
    } else if (async.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      // Erreur réseau, ou compte détaché de l'officine entre-temps.
      body = ModuleEmptyState(
        icon: Icons.cloud_off,
        title: async.hasError ? l.honamFailed : l.offiNotStaffTitle,
        message: async.hasError ? l.modulesCheckNetwork : l.offiNotStaffBody,
        action: HonamPrimaryButton(
          label: l.actionRetry,
          icon: Icons.refresh,
          expanded: false,
          onPressed: () => ref.invalidate(officineMeProvider),
        ),
      );
    }

    final tabs = [
      (Icons.inbox_outlined, Icons.inbox, l.offiTabOrders),
      (Icons.history, Icons.history, l.offiTabHistory),
      (Icons.credit_card_outlined, Icons.credit_card, l.offiTabSubscription),
      (Icons.person_outline, Icons.person, l.offiTabAccount),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: me == null
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.terracottaTint,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 12,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                height: 66,
                onDestinationSelected: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = index);
                },
                destinations: [
                  for (final (icon, selected, label) in tabs)
                    NavigationDestination(
                      icon: Icon(icon, color: AppColors.textSecondary),
                      selectedIcon: Icon(
                        selected,
                        color: AppColors.accentPrimary,
                      ),
                      label: label,
                    ),
                ],
              ),
            ),
    );
  }
}

/// L'en-tête des quatre onglets : le logo, le nom et le quartier de
/// l'officine, et si les patients la voient.
class OfficineTabHeader extends StatelessWidget {
  const OfficineTabHeader({
    super.key,
    required this.me,
    required this.title,
    this.trailing,
  });

  final OfficineMe me;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIconButton(
                icon: Icons.arrow_back,
                tooltip: l.offiLeave,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 6),
              HonamThumb(
                size: 40,
                child: const Icon(Icons.local_pharmacy_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.pharmacy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      me.pharmacy.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OfficineTag(
                me.visible ? l.offiOpen : l.offiHidden,
                tone: me.visible ? OfficineTone.success : OfficineTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (!me.visible) ...[
            const SizedBox(height: 10),
            ModuleCallout(
              tone: CalloutTone.red,
              text: me.pharmacy.status != 'ACTIVE'
                  ? l.offiSuspended(me.pharmacy.suspensionReason ?? '')
                  : !me.pharmacy.walletVerified
                  ? l.offiWalletNotVerified
                  : l.offiRenewToShow,
            ),
          ],
        ],
      ),
    );
  }
}

/// Le sélecteur à trois cases des onglets (À traiter · 3 / En cours · 4…).
class OfficineSegments extends StatelessWidget {
  const OfficineSegments({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.surface : null,
                      borderRadius: BorderRadius.circular(11),
                      border: i == index
                          ? Border.all(color: AppColors.border)
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == index
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
