import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/privacy_repository.dart';
import 'settings_widgets.dart';

final _phoneExceptionsProvider = FutureProvider.autoDispose<List<int>>(
  (ref) => ref.watch(privacyRepositoryProvider).phoneExceptions(),
);

/// Réglages › Confidentialité › « Mon numéro de téléphone ».
///
/// Deux choix : visible par mes contacts, ou masqué. Masqué, une liste de
/// contacts autorisés le voit quand même. Le serveur fait foi : un numéro
/// masqué n'est pas « caché dans l'application », il n'est pas envoyé — et
/// un membre d'un groupe commun ne le reçoit jamais, quel que soit ce choix.
class PhoneVisibilityScreen extends ConsumerStatefulWidget {
  const PhoneVisibilityScreen({super.key});

  @override
  ConsumerState<PhoneVisibilityScreen> createState() =>
      _PhoneVisibilityScreenState();
}

class _PhoneVisibilityScreenState extends ConsumerState<PhoneVisibilityScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(PrivacyRepository) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(privacyRepositoryProvider));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).privacySaveFailed)),
        );
      }
    } finally {
      ref.invalidate(privacySettingsProvider);
      ref.invalidate(_phoneExceptionsProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = ref.watch(privacySettingsProvider).valueOrNull;
    final hidden = settings?.phoneHidden ?? false;
    final allowed = ref.watch(_phoneExceptionsProvider).valueOrNull ?? const [];
    final contacts =
        [
          for (final c in ref.watch(contactsProvider).valueOrNull ?? const [])
            if (c.contactUserId != null && c.isRegistered) c,
        ]..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

    return SettingsScaffold(
      title: l.chatXPrivacyPhone,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            l.chatXPrivacyPhoneBody,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        SettingsCard(
          children: [
            _Choice(
              selected: !hidden,
              title: l.chatXPrivacyPhoneContacts,
              onTap: _busy || settings == null || !hidden
                  ? null
                  : () => _run((r) => r.update(phoneHidden: false)),
            ),
            _Choice(
              selected: hidden,
              title: l.chatXPrivacyPhoneHidden,
              subtitle: l.chatXPrivacyPhoneHiddenSub,
              onTap: _busy || settings == null || hidden
                  ? null
                  : () => _run((r) => r.update(phoneHidden: true)),
            ),
          ],
        ),
        if (hidden) ...[
          SettingsSectionTitle(l.chatXPrivacyPhoneAllowed),
          if (contacts.isEmpty)
            SettingsFootnote(l.chatXShareContactEmpty)
          else
            SettingsCard(
              children: [
                for (final contact in contacts)
                  CheckboxListTile(
                    value: allowed.contains(contact.contactUserId),
                    title: Text(contact.displayName),
                    onChanged: _busy
                        ? null
                        : (checked) => _run((r) async {
                            final next = {...allowed};
                            if (checked == true) {
                              next.add(contact.contactUserId!);
                            } else {
                              next.remove(contact.contactUserId);
                            }
                            await r.setPhoneExceptions(next.toList());
                          }),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Une option du choix, cochée ou non.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    selected: selected,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? AppColors.accentPrimaryDark : AppColors.textMuted,
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    onTap: onTap,
  );
}
