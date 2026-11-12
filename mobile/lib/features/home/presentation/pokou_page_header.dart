import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notifications_center_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// L'en-tête des onglets — le même sur l'Accueil, Kory, Honam.
///
/// Un titre en gras à gauche, une ligne dessous qui dit ce qui attend, et à
/// droite la cloche et la photo. Pas de barre de titre : l'onglet dit déjà
/// où l'on est, et une barre de plus mange la hauteur de l'écran.
class PokouPageHeader extends ConsumerWidget {
  const PokouPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.emphasized = false,
    this.leading,
    this.actions = const [],
    this.showBell = true,
    this.showAvatar = true,
  });

  /// Ma photo, qui mène au profil. Masquée là où le profil est déjà la
  /// première chose de l'écran.
  final bool showAvatar;

  /// La cloche des notifications de services. Masquée sur les onglets qui
  /// ont déjà leurs propres actions : l'en-tête doit tenir sur un téléphone
  /// étroit.
  final bool showBell;

  final String title;
  final String? subtitle;

  /// La ligne du dessous annonce quelque chose à faire (non-lus, alerte) :
  /// elle passe en terre cuite, en gras.
  final bool emphasized;

  /// Avant le titre — le logo d'un module, par exemple.
  final Widget? leading;

  /// Entre le titre et la cloche — les actions propres à l'onglet.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(authControllerProvider).user;
    final unread =
        ref.watch(serviceNotificationsProvider).valueOrNull?.unread ?? 0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 26,
                      height: 1.2,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: emphasized
                            ? AppColors.accentPrimaryDark
                            : AppColors.textSecondary,
                        fontWeight: emphasized
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
            if (showBell)
              IconButton(
                tooltip: l.notifCenterTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsCenterScreen(),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.accentPrimary,
                  label: Text(unread > 9 ? '9+' : '$unread'),
                  child: const Icon(Icons.notifications_none_outlined),
                ),
              ),
            if (showAvatar && user != null) ...[
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: l.navProfile,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: ContactAvatar(
                      avatar: user.avatar,
                      displayName: user.fullName ?? '',
                      size: 42,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
