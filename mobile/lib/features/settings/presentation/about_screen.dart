import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/legal_screen.dart';

/// Version affichée : passée au build (`--dart-define=POKOU_VERSION=…`),
/// pour ne pas embarquer un greffon natif juste pour lire un numéro.
const _version = String.fromEnvironment('POKOU_VERSION', defaultValue: '1.21.0');

/// REG-11 · À propos de Pokou : version, sens des noms, documents légaux.
///
/// Au lot 1, seul le nom Pokou est expliqué (section 6.3) : les autres
/// services ne sont pas encore ouverts, les nommer ici les annoncerait.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.lot1 = false});

  final bool lot1;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final names = <(String, String)>[
      ('Pokou', l.aboutPokou),
      if (!lot1) ...[
        ('Kory', l.aboutKory),
        ('Honam', l.aboutHonam),
        ('Assimé', l.aboutAssime),
        ('Wétri', l.aboutWetri),
        ('ÉPÉ', l.aboutEpe),
      ],
    ];
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l.aboutVersion(_version),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.aboutNamesTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  for (final (name, meaning) in names)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 76,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              meaning,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l.aboutNextNames,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(l.legalTerms),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const LegalScreen(name: 'conditions')),
                ),
                ListTile(
                  title: Text(l.legalPrivacy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(const LegalScreen(name: 'confidentialite')),
                ),
                ListTile(
                  title: Text(l.aboutLicenses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Pokou',
                    applicationVersion: _version,
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
