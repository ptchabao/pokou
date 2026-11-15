import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country/country_config.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../l10n/app_localizations.dart';

/// Le choix de la langue.
///
/// Les six langues, chacune dans son encadré ; celle du téléphone porte la
/// mention « Langue du téléphone ». La choisir n'enregistre pas son code :
/// elle dit « suis mon appareil », ce qui reste vrai le jour où
/// l'utilisateur change la langue de son téléphone. Enregistrer « fr »
/// parce que le téléphone est en français figerait ce choix pour toujours.
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
    final lot1 = isLot1(ref.watch(currentCountryConfigProvider).modules);
    // La langue du téléphone, si Pokou la parle : elle porte la mention
    // « Langue du téléphone », et la choisir revient à SUIVRE le téléphone
    // (voir plus haut) plutôt qu'à figer ce code.
    final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final phoneSupported = _languages.any((lang) => lang.code == phone);
    final effective = current ?? (phoneSupported ? phone : 'fr');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: l.profileLanguage),
            Expanded(
              child: RadioGroup<String>(
                groupValue: effective,
                onChanged: (code) => _choose(ref, code, phone),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    for (final language in _languages)
                      _LanguageRow(
                        code: language.code,
                        label: language.native,
                        subtitle: language.code == phone
                            ? l.profileLanguageSystem
                            : null,
                        selected: effective == language.code,
                        onTap: () => _choose(ref, language.code, phone),
                      ),
                    // REG-9 : la langue de l'interface ne traduit pas les
                    // messages.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        lot1 ? l.languageNoteLot1 : l.languageNote,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _choose(WidgetRef ref, String? code, String phone) {
    if (code == null) return;
    ref
        .read(appSettingsProvider.notifier)
        .setLocale(code == phone ? null : code);
  }
}

/// Une langue dans son encadré, bouton radio à gauche ; la sélection se
/// voit au trait de l'encadré. Le changement est immédiat.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String code;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.accentPrimary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Radio<String>(
                  value: code,
                  activeColor: AppColors.accentPrimary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
