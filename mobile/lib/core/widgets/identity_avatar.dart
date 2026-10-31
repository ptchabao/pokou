import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_providers.dart';
import '../media/media_repository.dart' show MediaMeta;
import '../theme/app_colors.dart';
import 'contact_avatar.dart';
import 'status_halo.dart';

/// La photo de quelqu'un, avec ce qu'on sait de lui.
///
/// ```
///     ◯ [ photo ] •
///     │            └─ en ligne maintenant
///     └────────────── a publié un statut que je n'ai pas vu
/// ```
///
/// ── Un seul widget, partout ───────────────────────────────────────────
///
/// Ces deux indicateurs auraient pu être ajoutés écran par écran. Ils
/// auraient alors divergé au premier écran oublié : l'anneau présent dans
/// les discussions et absent des contacts, le point vert dessiné d'après
/// « la session est valide » ici et d'après la vraie présence là. C'est
/// exactement ce qui fait qu'une application semble assemblée par plusieurs
/// équipes.
///
/// Ici : une source par indicateur, une seule façon de les dessiner.
///
/// ── Ce que chaque indicateur signifie, précisément ────────────────────
///
/// **L'anneau** ne dit pas « cette personne a un statut ». Il dit « cette
/// personne a au moins un statut QUE JE N'AI PAS VU ». Un anneau permanent
/// autour de quelqu'un qui publie tous les jours ne voudrait plus rien
/// dire ; celui-ci s'éteint dès qu'on a fini de regarder et se rallume à la
/// publication suivante.
///
/// **Le point** ne dit pas « cette personne a l'application installée » ni
/// « sa session est valide ». Il dit « une connexion temps réel est ouverte
/// en ce moment », avec une expiration côté serveur (90 s sans signe de vie)
/// pour qu'un téléphone qui perd le réseau ne reste pas vert pendant des
/// minutes. Et il ne s'affiche que sur un oui FRANC : une présence inconnue
/// — la personne l'a masquée, le serveur n'a pas répondu — ne dessine rien
/// plutôt que d'inventer un hors-ligne.
///
/// Les deux ne se fusionnent pas et ne se remplacent pas : ils répondent à
/// deux questions différentes.
class IdentityAvatar extends ConsumerWidget {
  const IdentityAvatar({
    super.key,
    required this.userId,
    required this.avatar,
    required this.displayName,
    this.size = 44,
    this.showPresence = true,
    this.showStatusRing = true,
    this.fallbackIcon,
    this.fallbackBackgroundColor,
    this.onTapRing,
  });

  /// `null` pour ce qui n'est pas une personne — un groupe, une chaîne.
  /// Ni anneau ni point ne s'affichent alors : un groupe n'a pas de statut
  /// et n'est pas « en ligne ».
  final int? userId;

  final MediaMeta? avatar;
  final String displayName;
  final double size;

  /// À couper là où l'information n'apporte rien : la liste des vues d'un
  /// statut, une grille de sélection. Un indicateur affiché partout sans
  /// distinction devient du bruit.
  final bool showPresence;
  final bool showStatusRing;

  final IconData? fallbackIcon;
  final Color? fallbackBackgroundColor;

  /// Ouvrir les statuts de cette personne depuis sa photo, comme dans les
  /// messageries où l'anneau est lui-même la porte d'entrée.
  final VoidCallback? onTapRing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final nonVu =
        id != null &&
        showStatusRing &&
        ref.watch(unseenStatusUsersProvider).contains(id);

    var enLigne = false;
    if (id != null && showPresence) {
      final connue = ref.watch(presenceProvider)[id];
      if (connue == null) {
        // Demandé APRÈS l'image de rendu : modifier un provider pendant un
        // `build` est interdit, et le regroupement des demandes a besoin de
        // ce tour de boucle pour rassembler toute la liste en une requête.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(presenceProvider.notifier).demander(id);
        });
      } else {
        enLigne = connue.afficherLePoint;
      }
    }

    // L'anneau prend de la place AUTOUR de la photo : sans réduire celle-ci,
    // la ligne de liste s'élargirait quand un statut arrive, et tout le
    // contenu sauterait d'un cran. La photo rétrécit donc du même montant.
    const epaisseur = 3.0;
    const ecart = 2.0;
    final tailleInterne = nonVu ? size - 2 * (epaisseur + ecart) : size;

    Widget photo = ContactAvatar(
      avatar: avatar,
      displayName: displayName,
      size: tailleInterne,
      fallbackIcon: fallbackIcon,
      fallbackBackgroundColor: fallbackBackgroundColor,
    );

    if (nonVu) {
      photo = StatusHalo(
        size: size,
        thickness: epaisseur,
        gap: ecart,
        child: photo,
      );
      if (onTapRing != null) {
        photo = InkWell(
          onTap: onTapRing,
          customBorder: const CircleBorder(),
          child: photo,
        );
      }
    }

    if (!enLigne) return photo;

    // Le point déborde volontairement du cercle, comme partout ailleurs :
    // posé à l'intérieur, il masquerait un visage.
    final taillePoint = (size * 0.28).clamp(8.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        photo,
        Positioned(
          right: 0,
          bottom: 0,
          child: Semantics(
            label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
            excludeSemantics: true,
            child: Container(
              width: taillePoint,
              height: taillePoint,
              decoration: BoxDecoration(
                color: AppColors.securityVerified,
                shape: BoxShape.circle,
                // Un liseré de la couleur du FOND, et non du blanc : sur un
                // fond sombre, un anneau blanc autour du point vert serait
                // plus visible que le point lui-même.
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
