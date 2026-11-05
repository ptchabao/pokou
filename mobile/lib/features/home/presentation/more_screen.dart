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
import '../../honam/presentation/courier_screen.dart';
import '../../honam/presentation/honam_controller.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../modules/presentation/modules_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../../profile/presentation/language_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/theme_screen.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../settings/presentation/storage_settings_screen.dart';
import '../../status/presentation/status_list_screen.dart';

/// « Plus » (écran APP-6) ou « Réglages » au lot 1 (écran LOT-4).
///
/// Dans l'application complète : profil, services secondaires, mode coursier
/// (COU-26) et réglages.
/// Au lot 1 (« Discussions d'abord ») : profil, Pokou certifié (CRT-1), réglages
/// complets (REG-1 à REG-11) et l'encart « Bientôt : Kory, Honam, Assimé » avec
/// « Me prévenir » (NAV-12), sans services secondaires ni offre coursier.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key, this.lot1 = false});

  final bool lot1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(authControllerProvider).user;
    final config = ref.watch(currentCountryConfigProvider);
    final courier = ref.watch(courierStatusProvider).valueOrNull;

    void push(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _Pushed(child: screen)));

    void showAbout() {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('À propos de Pokou'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pokou v3.4 (Lot 1 & Services)'),
              const SizedBox(height: 8),
              Text(
                'Deux rives réunies — Plus qu’une messagerie, une communauté.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Le sens de nos noms :',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '• Pokou : reine de paix et d’unité\n• Kory : calebasse et tontines solidaires\n• Honam : santé et bien-être\n• Assimé : grand marché\n• Win Pokou : modèle équitable coursiers',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }

    void showHelp() {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aide et support (REG-10)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined, color: AppColors.accentPrimary),
                title: const Text('Demander à Baba (IA)'),
                subtitle: const Text('Réponses instantanées sur le fonctionnement de Pokou'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Baba est dans la liste des discussions
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Questions fréquentes'),
                subtitle: const Text('Sécurité, mode preuve, codes SMS, livraisons'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Écrire au support'),
                subtitle: const Text('Réponse garantie directement dans l’application'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        PokouAppBar(title: lot1 ? l.moreSectionSettings : l.navMore),
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

        // Carte Pokou certifié (CRT-1)
        if (lot1 || config.has('certified'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ModuleCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CertifiedScreen()),
              ),
              child: Row(
                children: [
                  const ModuleBadge(
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
                          lot1 ? 'Essai gratuit d’un mois offert · Badge et mode preuve' : l.certPitch,
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

        // COU-26 · Carte « Mode coursier » dans Plus si actif, ou proposition
        if (!lot1 && config.has('honam'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ModuleCard(
              onTap: () => push(const CourierScreen()),
              child: Row(
                children: [
                  ModuleBadge(
                    icon: Icons.delivery_dining,
                    color: courier != null && courier.status != 'SUSPENDED' && courier.status != 'PENDING'
                        ? AppColors.feedbackSuccess
                        : AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              courier != null ? 'Mode coursier' : 'Devenir coursier Honam',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (courier != null && courier.status != 'SUSPENDED' && courier.status != 'PENDING') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.feedbackSuccess.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Disponible',
                                  style: TextStyle(
                                    color: AppColors.feedbackSuccess,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          courier != null
                              ? (courier.launchPeriod
                                  ? 'Période de lancement · courses illimitées'
                                  : (courier.unlimited
                                      ? 'Pack Queen Pokou illimité'
                                      : '${courier.ridesLeft} courses restantes'))
                              : 'Rejoignez la flotte Win Pokou dans votre ville',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.accentPrimary),
                ],
              ),
            ),
          ),

        // Lot 1 : Encart « Bientôt : Kory, Honam, Assimé » (LOT-4 / NAV-12)
        if (lot1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ModuleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.brandOr, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Bientôt disponibles',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kory (Cagnottes et tontines), Honam (Pharmacies & livraison) et Assimé (Petites annonces) arrivent bientôt dans votre ville.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Votre intérêt est enregistré. Vous serez alerté dès l’ouverture !'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('Me prévenir'),
                  ),
                ],
              ),
            ),
          ),

        // Section Services (application complète uniquement)
        if (!lot1)
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

        // Section Réglages
        _Section(
          title: l.moreSectionSettings,
          rows: [
            _Row(Icons.lock_outline, l.moreAccount,
                () => push(const ProfileScreen())),
            _Row(Icons.visibility_outlined, l.privacyTitle,
                () => push(const PrivacySettingsScreen())),
            _Row(Icons.notifications_outlined, l.profileNotifications,
                () => push(const NotificationsSettingsScreen())),
            _Row(Icons.storage_outlined, l.storageTitle,
                () => push(const StorageSettingsScreen())),
            _Row(Icons.palette_outlined, l.profileTheme,
                () => push(const ThemeScreen())),
            _Row(Icons.language, l.profileLanguage,
                () => push(const LanguageScreen())),
            _Row(Icons.help_outline, 'Aide et support', showHelp),
            _Row(Icons.info_outline, 'À propos de Pokou', showAbout),
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
