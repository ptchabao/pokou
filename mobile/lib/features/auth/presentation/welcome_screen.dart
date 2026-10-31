import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../../profile/presentation/language_screen.dart';
import 'legal_screen.dart';

/// Bienvenue (écran INS-1) : une seule promesse, une seule signature.
///
/// « Créer un compte » et « Se connecter » ouvrent le même parcours par
/// numéro : c'est le serveur qui distingue création et reconnexion. Les
/// deux boutons existent parce que les gens cherchent l'un ou l'autre.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Avant la connexion, le pays n'est connu que par la région du
    // téléphone : on n'annonce Kory que là où il est lancé.
    final region = Localizations.localeOf(context).countryCode;
    final showKory = region == null || region == 'TG';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PokouBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: l.profileLanguage,
                    icon: const Icon(Icons.language),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LanguageScreen()),
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l.appName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l.welcomePromise,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                _Service(icon: Icons.forum_outlined, label: l.welcomeServiceChats),
                if (showKory)
                  _Service(icon: Icons.savings_outlined, label: l.welcomeServiceKory),
                const Spacer(),
                ModuleActionButton(
                  label: l.welcomeCreate,
                  expanded: true,
                  onPressed: () => context.push('/phone'),
                ),
                const SizedBox(height: 12),
                ModuleQuietButton(
                  label: l.welcomeSignIn,
                  expanded: true,
                  onPressed: () => context.push('/phone'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(name: 'confidentialite'),
                    ),
                  ),
                  child: Text(l.legalPrivacy),
                ),
                Text(
                  l.welcomeSignature,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Service extends StatelessWidget {
  const _Service({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.accentPrimaryDark),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
