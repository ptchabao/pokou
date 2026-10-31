import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';

/// Clair, sombre, ou comme le téléphone.
///
/// « Comme le téléphone » d'abord, et par défaut : quelqu'un qui a réglé son
/// appareil en sombre l'a fait pour toutes ses applications, et lui
/// redemander reviendrait à lui faire refaire un choix déjà exprimé. Le
/// réglage explicite existe quand même, parce que beaucoup de gens veulent
/// leur messagerie sombre sans passer tout le téléphone en sombre — ou
/// l'inverse.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(
      appSettingsProvider.select((settings) => settings.themeMode),
    );

    return PokouBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.profileTheme)),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            for (final (mode, label, icon) in <(ThemeMode, String, IconData)>[
              (ThemeMode.system, l.themeSystem, Icons.brightness_auto_outlined),
              (ThemeMode.light, l.themeLight, Icons.light_mode_outlined),
              (ThemeMode.dark, l.themeDark, Icons.dark_mode_outlined),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.textSecondary),
                title: Text(label),
                trailing: current == mode
                    ? Icon(Icons.check, color: AppColors.accentPrimaryDark)
                    : null,
                selected: current == mode,
                onTap: () =>
                    ref.read(appSettingsProvider.notifier).setThemeMode(mode),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.themeHint,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
