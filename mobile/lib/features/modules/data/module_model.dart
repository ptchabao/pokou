import 'package:flutter/material.dart';

/// Un module activable, tel que le serveur le décrit.
class AppModule {
  const AppModule({
    required this.slug,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.category,
    required this.isRecommended,
    required this.isActivated,
    required this.userCount,
  });

  final String slug;
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String category;
  final bool isRecommended;
  final bool isActivated;
  final int userCount;

  factory AppModule.fromJson(Map<String, dynamic> json) => AppModule(
    slug: json['slug'] as String,
    name: json['name'] as String,
    tagline: json['tagline'] as String? ?? '',
    description: json['description'] as String? ?? '',
    icon: moduleIcon(json['icon'] as String?),
    accentColor: moduleColor(json['accent_color'] as String?),
    category: json['category'] as String? ?? 'SOCIAL',
    isRecommended: json['is_recommended'] as bool? ?? false,
    isActivated: json['is_activated'] as bool? ?? false,
    userCount: json['user_count'] as int? ?? 0,
  );

  AppModule copyWith({bool? isActivated}) => AppModule(
    slug: slug,
    name: name,
    tagline: tagline,
    description: description,
    icon: icon,
    accentColor: accentColor,
    category: category,
    isRecommended: isRecommended,
    isActivated: isActivated ?? this.isActivated,
    userCount: userCount,
  );
}

/// Table EXPLICITE des icônes.
///
/// Le serveur envoie un nom (« favorite »), pas un point de code. Le résoudre
/// par réflexion — `IconData(codePoint, fontFamily: 'MaterialIcons')` — marche
/// en debug et casse en release : l'élagage d'icônes de Flutter ne conserve
/// que les glyphes qu'il voit CITÉS dans le code, et une icône construite
/// dynamiquement n'est vue nulle part. Le résultat est un carré vide, en
/// production seulement.
///
/// Cette table les cite donc une par une. Ajouter un module au catalogue
/// suppose d'ajouter son icône ici — c'est le prix à payer pour qu'elle
/// s'affiche.
IconData moduleIcon(String? name) {
  return switch (name) {
    'emoji_events' => Icons.emoji_events,
    'card_giftcard' => Icons.card_giftcard,
    'savings' => Icons.savings,
    'workspace_premium' => Icons.workspace_premium,
    'help_center' => Icons.help_center,
    'local_fire_department' => Icons.local_fire_department,
    'groups' => Icons.groups,
    'rocket_launch' => Icons.rocket_launch,
    'menu_book' => Icons.menu_book,
    'auto_stories' => Icons.auto_stories,
    // Conservées : des modules du premier catalogue peuvent survivre en
    // base sur un environnement qui n'a pas encore joué la migration v2.
    'favorite' => Icons.favorite,
    'auto_awesome' => Icons.auto_awesome,
    'verified_user' => Icons.verified_user,
    // Repli volontairement générique : un module dont l'icône n'est pas
    // encore dans cette table doit rester utilisable, pas disparaître.
    _ => Icons.extension,
  };
}

/// Couleur d'accent `#RRGGBB`, avec repli sur le teal de marque.
Color moduleColor(String? hex) {
  if (hex == null || hex.length < 7) return const Color(0xFF8A4520);
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? const Color(0xFF8A4520) : Color(0xFF000000 | value);
}

/// Le catalogue en trois rayons, tel que le serveur les compose.
///
/// Les trois listes viennent du SERVEUR et ne sont pas recalculées ici :
/// « recommandé » est un choix éditorial de l'équipe et « populaire » se
/// calcule sur l'ensemble des utilisateurs — deux informations que le client
/// n'a pas.
class ModuleCatalogue {
  const ModuleCatalogue({
    required this.mine,
    required this.recommended,
    required this.popular,
  });

  final List<AppModule> mine;
  final List<AppModule> recommended;
  final List<AppModule> popular;

  bool get isEmpty => mine.isEmpty && recommended.isEmpty && popular.isEmpty;

  factory ModuleCatalogue.fromJson(Map<String, dynamic> json) {
    List<AppModule> read(String key) => ((json[key] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppModule.fromJson)
        .toList();
    return ModuleCatalogue(
      mine: read('mine'),
      recommended: read('recommended'),
      popular: read('popular'),
    );
  }
}
