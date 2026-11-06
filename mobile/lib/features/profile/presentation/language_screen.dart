import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Le choix de la langue.
///
/// Sept entrées : « langue du téléphone » d'abord, puis les six langues. La
/// première n'est pas un doublon du français — elle dit « suis mon
/// appareil », ce qui reste vrai le jour où l'utilisateur change la langue
/// de son téléphone. Enregistrer « fr » parce que le téléphone est en
/// français figerait ce choix pour toujours.
///
/// Chaque langue est écrite DANS sa propre langue, pas traduite : quelqu'un
/// qui ouvre l'application en russe par erreur doit pouvoir retrouver
/// « Français » sans comprendre un mot de ce qui l'entoure.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static const _languages = <({String code, String native})>[
    (code: 'fr', native: 'Français'),
    (code: 'en', native: 'English'),
    (code: 'es', native: 'Español'),
    (code: 'it', native: 'Italiano'),
    (code: 'ru', native: 'Русский'),
    (code: 'ar', native: 'العربية'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      appSettingsProvider.select((settings) => settings.localeCode),
    );
    final l = L.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: l.profileLanguage),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                l.profileLanguageSubtitle,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            // REG-9 : la langue de l'interface ne traduit pas les messages.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                l.languageNote,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _LanguageRow(
                    label: l.profileLanguageSystem,
                    selected: current == null,
                    onTap: () =>
                        ref.read(appSettingsProvider.notifier).setLocale(null),
                  ),
                  Divider(height: 1, color: AppColors.border, indent: 20),
                  for (final language in _languages)
                    _LanguageRow(
                      label: language.native,
                      selected: current == language.code,
                      onTap: () => ref
                          .read(appSettingsProvider.notifier)
                          .setLocale(language.code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      // Une coche plutôt qu'un bouton radio : le changement est immédiat, il
      // n'y a rien à valider ensuite.
      trailing: selected
          ? Icon(Icons.check, color: AppColors.accentPrimaryDark)
          : null,
      onTap: onTap,
    );
  }
}
