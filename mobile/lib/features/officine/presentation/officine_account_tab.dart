import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_courier_screens.dart';
import 'officine_shell.dart';
import 'officine_ui.dart';

/// Officine · 13. Compte de l'officine : l'adresse, les horaires, la garde,
/// le wallet qui reçoit les paiements, les livreurs habituels.
class OfficineAccountTab extends ConsumerStatefulWidget {
  const OfficineAccountTab({super.key, required this.me});

  final OfficineMe me;

  @override
  ConsumerState<OfficineAccountTab> createState() => _OfficineAccountTabState();
}

class _OfficineAccountTabState extends ConsumerState<OfficineAccountTab> {
  bool? _onDuty;

  Future<void> _setOnDuty(bool value) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _onDuty = value);
    try {
      await ref.read(officineRepositoryProvider).setOnDuty(value);
      HapticFeedback.selectionClick();
      ref.invalidate(officineMeProvider);
    } catch (e) {
      if (mounted) setState(() => _onDuty = !value);
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = widget.me.pharmacy;
    final couriers = ref.watch(officineCouriersProvider).valueOrNull;
    final onDuty = _onDuty ?? p.isOnDuty;

    Widget row(
      IconData icon,
      String title, {
      String? subtitle,
      String? trailing,
      VoidCallback? onTap,
    }) => ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing, style: TextStyle(color: AppColors.textSecondary)),
          if (onTap != null)
            Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
      onTap: onTap,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(officineMeProvider);
        ref.invalidate(officineCouriersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OfficineTabHeader(me: widget.me, title: l.offiAccountTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      row(Icons.place_outlined, p.name, subtitle: p.address),
                      row(
                        Icons.schedule,
                        l.offiOpeningHours,
                        trailing: p.openingHours ?? '—',
                      ),
                      row(
                        Icons.call_outlined,
                        l.offiCounterPhone,
                        trailing: p.phone,
                      ),
                      row(
                        Icons.account_balance_wallet_outlined,
                        l.offiReceivingWallet,
                        subtitle: [
                          officineMasked(p.walletPhone),
                          p.walletVerified
                              ? l.offiWalletVerified
                              : l.offiWalletPending,
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
                officineGap,
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      row(
                        Icons.delivery_dining_outlined,
                        l.offiCouriersTitle,
                        trailing: couriers == null
                            ? null
                            : l.offiAttachedCount(couriers.items.length),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OfficineCouriersScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                officineGap,
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    value: onDuty,
                    onChanged: _setOnDuty,
                    activeThumbColor: AppColors.accentPrimary,
                    title: Text(
                      l.offiOnDuty,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l.offiOnDutyHint),
                  ),
                ),
                officineGap,
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: AppColors.accentPrimary,
                    ),
                    title: Text(
                      l.offiLeave,
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                OfficineNote(l.offiTeamNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
