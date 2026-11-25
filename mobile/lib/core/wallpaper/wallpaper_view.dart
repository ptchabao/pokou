import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'wallpaper_catalog.dart';

/// Dessine un fond du catalogue, selon les règles du kit :
///
/// 1. la couleur `base` ;
/// 2. par-dessus, le fond lui-même (tuile répétée ou scène « cover »), à
///    l'opacité `intensité / 100` ;
/// 3. en mode SOMBRE, un voile ébène ([darkVeil]).
///
/// Le voile sombre est notre réponse au mode sombre, que le kit ne dessine
/// pas : ses 24 fonds sont pensés pour des bulles claires. En sombre, les
/// bulles deviennent ébène et terre cuite profonde, et texte clair ; posées
/// sur un Kente jaune vif ou un Sable presque blanc, elles feraient des
/// trous noirs dans une page éblouissante. Le voile garde le fond
/// reconnaissable (couleurs et motif se devinent) tout en le ramenant dans
/// la gamme de luminosité de l'app sombre. Il est plus léger sur les fonds
/// déjà sombres (`tone: dark` : Zã, Bogolan, Agadez, Maasaï, Ɣleti), qui
/// n'ont besoin que d'être un peu calmés. Le fond par défaut, Sable, prend
/// en sombre exactement la couleur de conversation sombre de l'app.
class WallpaperView extends StatelessWidget {
  const WallpaperView({
    super.key,
    required this.wallpaper,
    required this.intensity,
    required this.dark,
    this.isDefault = false,
  });

  final Wallpaper wallpaper;

  /// 20 à 100. Ignorée quand le fond n'est pas réglable.
  final int intensity;
  final bool dark;

  /// Le fond par défaut du catalogue (Sable).
  final bool isDefault;

  /// Voile ébène posé sur le fond en mode sombre.
  static double darkVeil(Wallpaper wallpaper) => wallpaper.isDark ? 0.35 : 0.8;

  /// Couleur du voile : celle de la conversation sombre de l'app.
  static const veilColor = Color(0xFF1A1615);

  @override
  Widget build(BuildContext context) {
    if (dark && isDefault && wallpaper.type == WallpaperType.color) {
      return ColoredBox(color: AppColors.chatBackground);
    }
    final opacity = wallpaper.intensityAdjustable
        ? (intensity.clamp(20, 100)) / 100
        : 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: wallpaper.base),
        if (wallpaper.type != WallpaperType.color)
          Opacity(opacity: opacity, child: _layer()),
        if (dark)
          ColoredBox(color: veilColor.withValues(alpha: darkVeil(wallpaper))),
      ],
    );
  }

  Widget _layer() {
    switch (wallpaper.type) {
      case WallpaperType.color:
        return const SizedBox.shrink();
      case WallpaperType.tile:
        // La PNG 1x fait exactement la taille logique du manifeste ; ses
        // variantes 2.0x/ et 3.0x/ gardent cette taille à l'écran.
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(wallpaper.tileAsset!),
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
              filterQuality: FilterQuality.medium,
            ),
          ),
        );
      case WallpaperType.scene:
        return LayoutBuilder(
          builder: (context, box) {
            // Décodée à la taille où elle s'affiche, et non aux 1560 × 2800
            // du fichier : 17 Mo de mémoire en moins sur un téléphone
            // modeste, pour une image identique à l'œil.
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
            final scale = math.max(box.maxWidth / 390, box.maxHeight / 700);
            final width = (390 * scale * dpr).ceil().clamp(1, 1560);
            return Image(
              image: ResizeImage(
                AssetImage(wallpaper.sceneAsset!),
                width: width,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
            );
          },
        );
    }
  }
}
