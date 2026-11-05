import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme/app_colors.dart';

/// L'état de la connexion temps réel, pour le bandeau d'en-tête.
///
/// `WsClient` émettait déjà `connectionChanges` sans que rien ne l'écoute en
/// dehors de la messagerie. C'est pourtant l'information la plus utile à
/// afficher en permanence sur ce marché : savoir si l'application est reliée
/// au serveur, avant même d'essayer d'envoyer quelque chose.
final wsOnlineProvider = StreamProvider<bool>((ref) {
  final ws = ref.watch(wsClientProvider);
  // La valeur COURANTE d'abord : un flux qui n'émet qu'au changement
  // laisserait l'en-tête vide tant que rien ne bouge, c'est-à-dire
  // justement quand tout va bien.
  return ws.connectionChanges.asBroadcastStream();
});

/// La barre d'en-tête verte, commune aux écrans principaux.
///
/// ── Blanche, et non verte ─────────────────────────────────────────────
///
/// Le système de design la pose en vert plein. Elle est ici BLANCHE, à la
/// demande du fondateur, et ça change deux choses pour le mieux :
///
/// - le vert ne sert plus qu'aux ACTIONS. Une barre verte en permanence en
///   haut de chaque écran diluait le signal : tout ce qui compte dans cette
///   application est vert, et il ne restait plus de quoi distinguer un
///   bouton d'un décor ;
/// - le contraste monte. Un titre ardoise sur blanc tient 17,85:1, contre
///   4,89:1 pour du blanc sur le vert — et ces écrans se lisent dehors.
///
/// Ce qui vient du système reste : la hauteur, la ligne de statut, la
/// séparation par un trait plutôt que par une ombre.
///
/// ── Ce que le bandeau de statut affiche, et ce qu'il n'invente pas ────
///
/// La maquette montre « En ligne • 4G Lomé ». Le type de réseau et la ville
/// ne sont pas connus de l'application, et les afficher en dur aurait donné
/// un en-tête qui ment avec aplomb. On garde donc la ligne et sa pastille,
/// alimentées par ce qu'on sait vraiment : la connexion au serveur.
class PokouAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const PokouAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showStatus = true,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Le bouton de retour, sur les écrans poussés par-dessus un onglet.
  ///
  /// Les quatre écrans de la barre du bas n'en ont pas — on ne « revient »
  /// pas d'un onglet. Les pages qu'ils ouvrent, si.
  final Widget? leading;

  /// La ligne de statut sous le titre. Masquée sur les écrans où elle
  /// n'apprend rien — un écran de réglages n'a pas besoin de dire que le
  /// temps réel fonctionne.
  final bool showStatus;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // `valueOrNull` et non `value` : au tout premier rendu le flux n'a
    // encore rien émis, et on préfère dire « en ligne » que faire clignoter
    // un avertissement au démarrage. La coupure, elle, se verra.
    final enLigne = ref.watch(wsOnlineProvider).valueOrNull ?? true;

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          // Un trait d'un point, comme la barre du bas : le système
          // supprime les ombres diffuses pour tenir la fréquence d'images
          // sur les appareils d'entrée de gamme.
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 4)],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null || showStatus) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (subtitle != null)
                                Expanded(
                                  child: Text(
                                    subtitle!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (showStatus) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    // Vert clair en ligne, ambre hors ligne.
                                    // Pas de rouge : une coupure réseau n'est
                                    // pas une erreur de l'utilisateur, et Pokou
                                    // reste utilisable — les conversations sont
                                    // en cache.
                                    // Sur blanc, les teintes claires de la
                                    // maquette disparaissent — le vert d'eau
                                    // tombait à 1,51:1. On reprend le vert et
                                    // l'ambre pleins, à 4,89 et 5,02:1.
                                    color: enLigne
                                        ? AppColors.accentPrimary
                                        : AppColors.chatAiLinkColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  enLigne ? l.appBarOnline : l.appBarOffline,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un bouton d'en-tête — glyphe ardoise sur la barre blanche.
///
/// Séparé d'`IconButton` pour une raison : la taille de frappe. Le gabarit
/// par défaut réserve 48 points de large, ce qui pousse trois actions et un
/// avatar hors de l'écran sur un téléphone étroit. Ici la zone reste
/// touchable sans réserver l'espace d'un bouton plein.
class PokouAppBarAction extends StatelessWidget {
  const PokouAppBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}
