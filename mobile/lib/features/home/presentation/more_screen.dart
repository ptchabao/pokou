import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'certified_screen.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../broadcasts/presentation/broadcast_lists_screen.dart';
import '../../calls/presentation/call_log_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../modules/presentation/modules_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../../profile/presentation/language_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../status/presentation/status_list_screen.dart';

/// « Plus » (écran APP-6) : le profil, les services secondaires et les
/// réglages. Les onglets Actus, Appels et Marché de la barre précédente
/// vivent ici, pour que la barre basse ne porte que les modules.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(authControllerProvider).user;
    final config = ref.watch(currentCountryConfigProvider);

    void push(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _Pushed(child: screen)));

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        PokouAppBar(title: l.navMore),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ModuleCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Row(
              children: [
                ContactAvatar(
                  avatar: user?.avatar,
                  displayName: user?.displayName ?? l.navYou,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? l.navYou,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (user?.phone != null)
                        Text(
                          _masked(user!.phone!),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Text(
                  l.moreEdit,
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (config.has('certified'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ModuleCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CertifiedScreen()),
              ),
              child: Row(
                children: [
                  ModuleBadge(
                    icon: Icons.verified_outlined,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.moreCertifiedTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          l.certPitch,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Section(
          title: l.moreSectionServices,
          rows: [
            _Row(Icons.donut_large_outlined, l.navStatus,
                () => push(const StatusListScreen())),
            _Row(Icons.call_outlined, l.navCalls,
                () => push(const CallLogScreen())),
            _Row(Icons.storefront_outlined, l.navMarket,
                () => push(const MarketplaceScreen())),
            _Row(Icons.apps_rounded, l.navModules,
                () => push(const ModulesScreen())),
            _Row(Icons.campaign_outlined, l.navBroadcasts,
                () => push(const BroadcastListsScreen())),
          ],
        ),
        _Section(
          title: l.moreSectionSettings,
          rows: [
            _Row(Icons.lock_outline, l.moreAccount,
                () => push(const ProfileScreen())),
            _Row(Icons.notifications_outlined, l.profileNotifications,
                () => push(const NotificationsSettingsScreen())),
            _Row(Icons.visibility_outlined, l.privacyTitle,
                () => push(const PrivacySettingsScreen())),
            _Row(Icons.language, l.profileLanguage,
                () => push(const LanguageScreen())),
          ],
        ),
      ],
    );
  }

  /// « +228 90 •• •• 33 » : le numéro reconnaissable par son titulaire,
  /// sans être lisible par quelqu'un qui regarde l'écran par-dessus
  /// l'épaule.
  static String _masked(String phone) {
    if (phone.length < 8) return phone;
    final head = phone.substring(0, phone.length - 6);
    final tail = phone.substring(phone.length - 2);
    return '$head •• •• $tail';
  }
}

/// Les écrans d'onglet (Actus, Appels, Marché) n'ont pas de bouton retour :
/// ils étaient faits pour la barre basse. Poussés depuis « Plus », ils en
/// reçoivent un, sans que leur code change.
class _Pushed extends StatelessWidget {
  const _Pushed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            child,
            Positioned(
              left: 4,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSectionTitle(title),
          ModuleCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final row in rows)
                  ListTile(
                    leading: Icon(row.icon, color: AppColors.textSecondary),
                    title: Text(row.label),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: row.onTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
