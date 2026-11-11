import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Les icônes dessinées pour Pokou (paquet du 6 novembre 2026, grille 24,
/// trait 1,8) — à la place des icônes génériques de Material.
///
/// Les icônes de MODULES existent en trait (inactif, listes) et en plein
/// (onglet actif). Elles n'ont pas de couleur propre (`currentColor`) : comme
/// une `Icon`, elles prennent celle du thème d'icône en vigueur — c'est ce qui
/// permet à la barre d'onglets de les colorer seule, active ou non.
enum PokouModuleIcon {
  accueil,
  discussions,
  statuts,
  appels,
  reglages,
  plus,
  kory,
  honam,
  assime,
  baba,
  coursier;

  String asset({bool filled = false}) =>
      'assets/icons/modules/$name${filled ? '-fill' : ''}.svg';
}

class PokouIcon extends StatelessWidget {
  const PokouIcon(
    this.icon, {
    super.key,
    this.filled = false,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final PokouModuleIcon icon;
  final bool filled;
  final double? size;
  final Color? color;

  /// `null` : icône décorative (un texte à côté dit déjà la même chose).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    final tint = color ?? theme.color ?? Theme.of(context).iconTheme.color;
    final picture = SvgPicture.asset(
      icon.asset(filled: filled),
      width: dimension,
      height: dimension,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox.square(dimension: dimension),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: picture)
        : Semantics(label: semanticLabel, image: true, child: picture);
  }
}

/// Les logos des modules Honam, Kory et Assimé : la bulle de Pokou et son
/// emblème. Ils gardent LEURS couleurs (jamais teintés) ; le symbole est le
/// même en clair et en sombre (guide des logos, novembre 2026).
enum PokouModule { honam, kory, assime }

enum PokouLogoVariant {
  /// La bulle terre cuite, l'emblème crème — fonds clairs et sombres.
  symbol('symbole-couleur'),

  /// Posé sur un fond terre cuite.
  symbolInverse('symbole-inverse');

  const PokouLogoVariant(this.file);
  final String file;
}

class PokouModuleLogo extends StatelessWidget {
  const PokouModuleLogo(
    this.module, {
    super.key,
    this.size = 32,
    this.variant = PokouLogoVariant.symbol,
    this.semanticLabel,
  });

  final PokouModule module;
  final double size;
  final PokouLogoVariant variant;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      'assets/logos/${module.name}-${variant.file}.svg',
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox.square(dimension: size),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: picture)
        : Semantics(label: semanticLabel, image: true, child: picture);
  }
}
