import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../wallpaper/wallpaper_catalog.dart';
import '../wallpaper/wallpaper_settings.dart';
import '../wallpaper/wallpaper_view.dart';

/// Le fond d'écran derrière les bulles d'une conversation.
///
/// Il vient du catalogue du kit « pokou-fonds-ecran » (voir
/// core/wallpaper/) : le fond propre à cette discussion ([scope] :
/// `contact:<id>` ou `group:<id>`) s'il y en a un, sinon le fond par défaut
/// choisi dans les Réglages, sinon Sable.
///
/// Deux règles du kit tiennent ici :
///
/// - **Fond fixe** : il est peint SOUS le contenu, et non dans la liste ; il
///   ne défile pas avec les messages.
/// - **Clavier** : le fond garde la hauteur de l'ÉCRAN, pas celle du corps
///   de page que le clavier raccourcit. Sans cela une scène « cover » se
///   recadrerait — elle « sauterait » — à chaque ouverture du clavier.
class ChatWallpaper extends ConsumerWidget {
  const ChatWallpaper({super.key, this.scope, required this.child});

  /// La discussion, ou `null` pour le fond par défaut (diffusions).
  final String? scope;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(wallpaperCatalogProvider).valueOrNull;
    final choice = ref.watch(
      chatWallpaperProvider.select((s) => s.resolve(scope)),
    );
    final Widget background;
    if (catalog == null) {
      // Le manifeste se lit en quelques millisecondes au premier écran :
      // en attendant, la couleur de conversation habituelle.
      background = ColoredBox(color: AppColors.chatBackground);
    } else {
      final wallpaper = catalog.byId(choice?.id);
      background = WallpaperView(
        wallpaper: wallpaper,
        intensity: choice?.intensity ?? wallpaper.intensityDefault,
        dark: AppColors.isDark,
        isDefault: wallpaper.id == catalog.defaultId,
      );
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: screenHeight,
            maxHeight: screenHeight,
            child: background,
          ),
        ),
        child,
      ],
    );
  }
}
