import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_courier_screens.dart';
import 'officine_phones_screen.dart';
import 'officine_shell.dart';
import 'officine_ui.dart';

/// Officine · 13. Compte de l'officine : l'adresse, les horaires, la
/// prochaine garde, le wallet qui reçoit les paiements, les livreurs
/// habituels, les téléphones du comptoir, la sonnerie de ce téléphone et la
/// fermeture temporaire.
class OfficineAccountTab extends ConsumerStatefulWidget {
  const OfficineAccountTab({super.key, required this.me});

  final OfficineMe me;

  @override
  ConsumerState<OfficineAccountTab> createState() => _OfficineAccountTabState();
}

class _OfficineAccountTabState extends ConsumerState<OfficineAccountTab> {
  /// Les interrupteurs bougent tout de suite ; le serveur confirme ensuite.
  bool? _ring;
  bool? _closed;

  OfficinePharmacy get p => widget.me.pharmacy;

  /// Un changement du compte ; `true` si le serveur l'a accepté.
  Future<bool> _update(Map<String, dynamic> fields, {bool toast = true}) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(officineRepositoryProvider).updatePharmacy(fields);
      HapticFeedback.selectionClick();
      ref.invalidate(officineMeProvider);
      if (toast) {
        messenger.showSnackBar(SnackBar(content: Text(l.officineAccountSaved)));
      }
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
      return false;
    }
  }

  Future<void> _setRing(bool value) async {
    setState(() => _ring = value);
    if (!await _update({'ring_on_order': value}, toast: false) && mounted) {
      setState(() => _ring = !value);
    }
  }

  Future<void> _setClosed(bool value) async {
    final l = L.of(context);
    if (value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.officineAccountCloseTitle),
          content: Text(l.officineAccountCloseBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.officineAccountCloseYes),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _closed = value);
    if (!await _update({'temporarily_closed': value}, toast: false) &&
        mounted) {
      setState(() => _closed = !value);
    }
  }

  Future<void> _editInfo() async {
    final fields = await showModuleSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => _InfoSheet(pharmacy: p),
    );
    if (fields != null && fields.isNotEmpty) await _update(fields);
  }

  Future<void> _editHours() async {
    final l = L.of(context);
    final hours = await showModuleSheet<String>(
      context: context,
      builder: (_) => _TextSheet(
        title: l.offiOpeningHours,
        initial: p.openingHours ?? '',
        hint: l.officineAccountHoursHint,
      ),
    );
    if (hours != null) await _update({'opening_hours': hours});
  }

  Future<void> _editDuty() async {
    final fields = await showModuleSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DutySheet(pharmacy: p),
    );
    if (fields != null && fields.isNotEmpty) await _update(fields);
  }

  Future<void> _editWallet() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!widget.me.isTitulaire) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.officineAccountTitulaireOnly)),
      );
      return;
    }
    final phone = await showModuleSheet<String>(
      context: context,
      builder: (_) => _TextSheet(
        title: l.officineAccountWalletTitle,
        body: l.officineAccountWalletBody,
        initial: '',
        hint: '+228 96 00 00 12',
        phone: true,
      ),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(officineRepositoryProvider).changeWallet(phone);
      ref.invalidate(officineMeProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.officineAccountSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  /// « Se déconnecter de ce téléphone » : ce compte quitte l'équipe de
  /// l'officine, et l'espace officine se ferme.
  Future<void> _logout() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.officineAccountLogoutTitle),
        content: Text(l.officineAccountLogoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.officineAccountLogout),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(officineRepositoryProvider).leaveCounter();
      ref.invalidate(officineMeProvider);
      ref.invalidate(officineQueueProvider);
      await navigator.maybePop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final me = widget.me;
    final couriers = ref.watch(officineCouriersProvider).valueOrNull;
    final ring = _ring ?? me.ringOnOrder;
    final closed = _closed ?? p.temporarilyClosed;
    final nextDuty = p.nextDutyOn;
    final pendingWallet = p.walletPhonePending;

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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                trailing,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
      onTap: onTap,
    );

    Widget toggle({
      required String title,
      String? subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.accentPrimary,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(officineMeProvider);
        ref.invalidate(officineCouriersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OfficineTabHeader(me: me, title: l.offiAccountTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      row(
                        Icons.place_outlined,
                        p.name,
                        subtitle: p.address,
                        onTap: _editInfo,
                      ),
                      row(
                        Icons.schedule,
                        l.offiOpeningHours,
                        trailing: p.openingHours ?? '—',
                        onTap: _editHours,
                      ),
                      row(
                        Icons.calendar_today_outlined,
                        l.officineAccountNextDuty,
                        trailing: nextDuty == null
                            ? l.officineAccountNextDutyNone
                            : officineDate(context, nextDuty),
                        onTap: _editDuty,
                      ),
                      row(
                        Icons.account_balance_wallet_outlined,
                        l.offiReceivingWallet,
                        subtitle: [
                          l.officineAccountWalletName(
                            officineMasked(p.walletPhone),
                          ),
                          if (!p.walletVerified) l.offiWalletPending,
                          if (pendingWallet != null)
                            l.officineAccountWalletPending(
                              officineMasked(pendingWallet),
                            ),
                        ].join('\n'),
                        onTap: _editWallet,
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
                      row(
                        Icons.smartphone_outlined,
                        l.officineAccountCounterPhones,
                        trailing: '${me.phonesCount}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OfficinePhonesScreen(titulaire: me.isTitulaire),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                officineGap,
                ModuleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      toggle(
                        title: l.officineAccountRing,
                        subtitle: l.officineAccountRingHint,
                        value: ring,
                        onChanged: _setRing,
                      ),
                      toggle(
                        title: l.officineAccountClose,
                        subtitle: l.officineAccountCloseHint,
                        value: closed,
                        onChanged: _setClosed,
                      ),
                    ],
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
                      l.officineAccountLogout,
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'adresse et le téléphone de l'officine. Le nom, enregistré auprès de
/// l'Ordre, se change avec l'équipe Pokou.
class _InfoSheet extends StatefulWidget {
  const _InfoSheet({required this.pharmacy});

  final OfficinePharmacy pharmacy;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  late final _address = TextEditingController(text: widget.pharmacy.address);
  late final _phone = TextEditingController(text: widget.pharmacy.phone);

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final address = _address.text.trim();
    final phone = _phone.text.trim();
    Navigator.of(context).pop(<String, dynamic>{
      if (address.isNotEmpty && address != widget.pharmacy.address)
        'address': address,
      if (phone.isNotEmpty && phone != widget.pharmacy.phone) 'phone': phone,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.officineAccountInfoTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.pharmacy.name} · ${l.officineAccountNameNote}',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          maxLength: 255,
          decoration: InputDecoration(
            labelText: l.officineAccountAddress,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l.officineAccountPhone,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        HonamPrimaryButton(label: l.officineAccountSave, onPressed: _save),
      ],
    );
  }
}

/// Une seule valeur à saisir : les horaires, ou le numéro du nouveau
/// wallet.
class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.initial,
    required this.hint,
    this.body,
    this.phone = false,
  });

  final String title;
  final String? body;
  final String initial;
  final String hint;
  final bool phone;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (widget.body != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.body!,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: 255,
          keyboardType: widget.phone ? TextInputType.phone : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        HonamPrimaryButton(
          label: l.officineAccountSave,
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
        ),
      ],
    );
  }
}

/// « Prochaine garde » : la date du prochain tour, et la mention « De
/// garde » de l'annuaire pour le tour en cours.
class _DutySheet extends ConsumerStatefulWidget {
  const _DutySheet({required this.pharmacy});

  final OfficinePharmacy pharmacy;

  @override
  ConsumerState<_DutySheet> createState() => _DutySheetState();
}

class _DutySheetState extends ConsumerState<_DutySheet> {
  late bool _onDuty = widget.pharmacy.isOnDuty;

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

  Future<void> _pick() async {
    final navigator = Navigator.of(context);
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.pharmacy.nextDutyOn ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 366)),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    navigator.pop(<String, dynamic>{'next_duty_on': '$y-$m-$d'});
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final next = widget.pharmacy.nextDutyOn;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.officineAccountNextDuty,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          next == null
              ? l.officineAccountNextDutyNone
              : officineDate(context, next),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        HonamPrimaryButton(
          label: l.officineAccountChooseDate,
          icon: Icons.calendar_today_outlined,
          onPressed: _pick,
        ),
        if (next != null)
          OfficineTextAction(
            label: l.officineAccountClearDuty,
            onPressed: () => Navigator.of(
              context,
            ).pop(<String, dynamic>{'clear_next_duty': true}),
          ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _onDuty,
          onChanged: _setOnDuty,
          activeThumbColor: AppColors.accentPrimary,
          title: Text(
            l.offiOnDuty,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l.offiOnDutyHint),
        ),
      ],
    );
  }
}
