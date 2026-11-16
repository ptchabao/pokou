import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_ui.dart';

/// Officine · 13. Téléphones du comptoir : les comptes Pokou de l'équipe,
/// qui reçoivent les ordonnances et traitent les commandes. Numéros
/// masqués ; seul le titulaire en ajoute ou en retire.
class OfficinePhonesScreen extends ConsumerWidget {
  const OfficinePhonesScreen({super.key, required this.titulaire});

  /// Ce téléphone est celui du titulaire.
  final bool titulaire;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final phone = await showModuleSheet<String>(
      context: context,
      builder: (_) => const _AddPhoneSheet(),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(officineRepositoryProvider).addPhone(phone);
      HapticFeedback.lightImpact();
      ref.invalidate(officinePhonesProvider);
      ref.invalidate(officineMeProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CounterPhone phone,
  ) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.officineAccountRemovePhone),
        content: Text(phone.name ?? phone.phoneMasked ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.officineAccountRemovePhone),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(officineRepositoryProvider).removePhone(phone.id);
      ref.invalidate(officinePhonesProvider);
      ref.invalidate(officineMeProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(officinePhonesProvider);
    final phones = async.valueOrNull;
    return OfficinePage(
      title: l.officineAccountCounterPhones,
      onRefresh: () async => ref.invalidate(officinePhonesProvider),
      primary: titulaire
          ? HonamPrimaryButton(
              label: l.officineAccountAddPhone,
              icon: Icons.add,
              onPressed: () => _add(context, ref),
            )
          : null,
      children: [
        if (phones == null && async.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (phones == null)
          ModuleCallout(
            tone: CalloutTone.red,
            text: officineError(l, async.error ?? ''),
          )
        else
          ModuleCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final phone in phones)
                  ListTile(
                    leading: Icon(
                      Icons.smartphone_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(
                      phone.me
                          ? l.officineAccountThisPhone
                          : phone.name ?? phone.phoneMasked ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        phone.phoneMasked ?? '',
                        phone.role == 'TITULAIRE'
                            ? l.officineAccountTitulaire
                            : l.officineAccountCollaborator,
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: titulaire && !phone.me
                        ? IconButton(
                            tooltip: l.officineAccountRemovePhone,
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => _remove(context, ref, phone),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        OfficineNote(l.officineAccountPhonesNote),
      ],
    );
  }
}

class _AddPhoneSheet extends StatefulWidget {
  const _AddPhoneSheet();

  @override
  State<_AddPhoneSheet> createState() => _AddPhoneSheetState();
}

class _AddPhoneSheetState extends State<_AddPhoneSheet> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
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
          l.officineAccountAddPhone,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l.officineAccountAddPhoneHint,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '+228 90 00 00 00',
          ),
        ),
        const SizedBox(height: 14),
        HonamPrimaryButton(
          label: l.officineAccountAdd,
          onPressed: () => Navigator.of(context).pop(_phone.text.trim()),
        ),
      ],
    );
  }
}
