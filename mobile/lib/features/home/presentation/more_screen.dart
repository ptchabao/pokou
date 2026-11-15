import 'package:flutter/material.dart';
import '../../settings/presentation/account_security_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'certified_screen.dart';

import '../../../core/country/country_config.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../core/widgets/pokou_tab_page.dart';
import 'pokou_page_header.dart';
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
import '../../settings/presentation/about_screen.dart';
import '../../settings/presentation/help_screen.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../settings/presentation/storage_settings_screen.dart';
import '../../../core/widgets/pokou_icon.dart';

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

    void showAbout() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AboutScreen(lot1: lot1)));

    void showHelp() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HelpScreen()));

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // Le même en-tête que les autres onglets. Sans la photo : la carte
        // du profil est juste dessous.
        PokouPageHeader(
          title: lot1 ? l.moreSectionSettings : l.navMore,
          showAvatar: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: ModuleCard(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
            // Maquette Figma `.certified-card` : carte ébène en dégradé,
            // rond or, texte crème.
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.certified,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x241E1814),
                    blurRadius: 22,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CertifiedScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.brandOr,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_outlined,
                            color: Color(0xFF352A20),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.moreCertifiedTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFF9E5),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.certPitch,
                                style: const TextStyle(
                                  color: Color(0xFFE6D9BD),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.brandOr,
                        ),
                      ],
                    ),
                  ),
                ),
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
                    color:
                        courier != null &&
                            courier.status != 'SUSPENDED' &&
                            courier.status != 'PENDING'
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
                              courier != null
                                  ? 'Mode coursier'
                                  : 'Devenir coursier Honam',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (courier != null &&
                                courier.status != 'SUSPENDED' &&
                                courier.status != 'PENDING') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.feedbackSuccess.withValues(
                                    alpha: 0.15,
                                  ),
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
                              : '1 000 FCFA par course, près de chez toi',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.accentPrimary,
                  ),
                ],
              ),
            ),
          ),

        // Maquette p.15 (Plus) et p.52 (Réglages du Lot 1) : des groupes sans
        // titre — services, compte, aide — et la valeur courante à droite.
        if (!lot1)
          _Section(
            rows: [
              if (config.has('assime'))
                _Row(
                  Icons.storefront_outlined,
                  l.homeAssimeTitle,
                  () => PokouTabPage.push(
                    context,
                    tab: PokouTab.more,
                    child: const MarketplaceScreen(),
                  ),
                  subtitle: l.marketSubtitle,
                  leading: const PokouModuleLogo(PokouModule.assime, size: 28),
                ),
              _Row(
                Icons.call_outlined,
                l.navCalls,
                () => push(const CallLogScreen()),
                leading: PokouIcon(
                  PokouModuleIcon.appels,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

        _Section(
          rows: [
            _Row(
              Icons.lock_outline,
              l.moreAccount,
              // Compte et sécurité (REG-3) : le Profil reste ouvert par la
              // carte d'identité en tête de cet écran.
              () => push(const AccountSecurityScreen()),
            ),
            if (lot1) ...[
              _Row(
                Icons.shield_outlined,
                l.privacyTitle,
                () => push(const PrivacySettingsScreen()),
              ),
              _Row(
                Icons.notifications_outlined,
                l.profileNotifications,
                () => push(const NotificationsSettingsScreen()),
              ),
              _Row(
                Icons.cloud_outlined,
                l.storageTitle,
                () => push(const StorageSettingsScreen()),
                value: ref.watch(_cacheSizeProvider).valueOrNull,
              ),
            ] else ...[
              _Row(
                Icons.notifications_outlined,
                l.profileNotifications,
                () => push(const NotificationsSettingsScreen()),
              ),
              _Row(
                Icons.shield_outlined,
                l.privacyTitle,
                () => push(const PrivacySettingsScreen()),
              ),
            ],
            _Row(
              Icons.language,
              l.profileLanguage,
              () => push(const LanguageScreen()),
              value: _languageName(context, ref),
            ),
          ],
        ),

        _Section(
          rows: [
            _Row(Icons.help_outline, l.helpTitle, showHelp),
            _Row(Icons.info_outline, l.aboutTitle, showAbout),
          ],
        ),

        // Absents de la maquette, mais sans autre entrée depuis que l'en-tête
        // des Discussions suit la maquette : gardés ici, en dernier.
        _Section(
          rows: [
            _Row(
              Icons.campaign_outlined,
              l.navBroadcasts,
              () => push(const BroadcastListsScreen()),
            ),
            if (!lot1)
              _Row(
                Icons.apps_rounded,
                l.navModules,
                () => push(const ModulesScreen()),
              ),
          ],
        ),

        // Lot 1 : encart « Bientôt : Kory, Honam, Assimé » EN BAS (maquette
        // p.52, LOT-4 / NAV-12).
        if (lot1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.lot1SoonTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.lot1SoonBody,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.lot1SoonNoted)));
                    },
                    child: Text(l.lot1SoonNotify),
                  ),
                ],
              ),
            ),
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
  const _Row(
    this.icon,
    this.label,
    this.onTap, {
    this.leading,
    this.subtitle,
    this.value,
  });

  final IconData icon;

  /// Une icône ou un logo Pokou à la place de l'icône générique.
  final Widget? leading;
  final String label;
  final VoidCallback onTap;

  /// Sous le libellé (« Petites annonces » sous Assimé).
  final String? subtitle;

  /// La valeur courante, à droite (« Français », « 1,8 Go »).
  final String? value;
}

/// Un groupe de lignes dans une carte, sans titre (maquettes p.15 et p.52).
class _Section extends StatelessWidget {
  const _Section({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ModuleCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, color: AppColors.border),
              ListTile(
                leading:
                    row.leading ??
                    Icon(row.icon, color: AppColors.textSecondary),
                title: Text(row.label),
                subtitle: row.subtitle == null ? null : Text(row.subtitle!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row.value != null)
                      Text(
                        row.value!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
                onTap: row.onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La place prise par les médias sur l'appareil (Stockage et données).
final _cacheSizeProvider = FutureProvider.autoDispose<String>((ref) async {
  final stats = await ref.watch(mediaRepositoryProvider).cacheStats();
  return formatBytes(stats.totalBytes);
});

/// La langue affichée, dans sa propre langue.
String _languageName(BuildContext context, WidgetRef ref) {
  final code =
      ref.watch(appSettingsProvider.select((s) => s.localeCode)) ??
      Localizations.localeOf(context).languageCode;
  return LanguageScreen.nativeNameOf(code);
}
