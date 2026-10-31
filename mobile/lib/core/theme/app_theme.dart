import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'page_transitions.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  /// Le thème sombre.
  ///
  /// Construit à partir des MÊMES jetons que le clair : `AppColors` résout
  /// chaque couleur selon la luminosité en vigueur (voir
  /// AppColors.applyBrightness). Deux fichiers de thème séparés auraient
  /// divergé au premier ajout de couleur — celui-ci ne peut pas, puisqu'il
  /// n'y a qu'une palette.
  ///
  /// `AppColors.applyBrightness` doit avoir été appelé AVANT : ce
  /// constructeur lit les jetons au moment où il s'exécute.
  static ThemeData get dark => _build(ThemeData.dark(useMaterial3: true));

  static ThemeData get light => _build(ThemeData.light(useMaterial3: true));

  static ThemeData _build(ThemeData base) {
    // ── Outfit pour les titres, Inter pour le reste ─────────────────────
    //
    // Le système de design choisit Outfit pour ses « distinct character
    // openings » : des lettres qui restent distinctes quand le soleil
    // écrase le contraste. Elle porte aussi les MONTANTS, là où un chiffre
    // mal lu coûte de l'argent. Inter porte le corps, les libellés et les
    // données, pour sa netteté aux petites tailles.
    //
    // Ce choix revient sur une décision antérieure — la police système —
    // qui invoquait deux raisons. Une seule tenait :
    //
    // - la TAILLE de texte d'accessibilité ne dépend pas de la famille.
    //   `textScaler` s'applique quelle que soit la police, et rien ici ne
    //   le désactive. Pokou continue d'obéir aux réglages du système ;
    // - la SUBSTITUTION des écritures non latines, elle, est réelle. Ni
    //   Outfit ni Inter ne contiennent l'arabe, que Pokou parle. Sans repli
    //   explicite, un texte arabe s'afficherait en carrés vides sur les
    //   plateformes qui ne comblent pas d'elles-mêmes.
    //
    // D'où `fontFamilyFallback` : Flutter descend la liste glyphe par
    // glyphe. Le russe est couvert par Inter (le cyrillique est conservé au
    // sous-ensemble) ; l'arabe tombe sur la police système.
    const fallback = <String>[
      // Noms Android ; sur iOS ils sont ignorés et le moteur retombe sur sa
      // propre chaîne, qui couvre l'arabe.
      'Roboto',
      'Noto Sans Arabic',
      'Noto Sans',
    ];

    final corps = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Inter',
      fontFamilyFallback: fallback,
    );

    TextStyle? outfit(TextStyle? s) =>
        s?.copyWith(fontFamily: 'Outfit', fontFamilyFallback: fallback);

    final textTheme = corps.copyWith(
      displayLarge: outfit(corps.displayLarge),
      displayMedium: outfit(corps.displayMedium),
      displaySmall: outfit(corps.displaySmall),
      headlineLarge: outfit(corps.headlineLarge),
      headlineMedium: outfit(corps.headlineMedium),
      headlineSmall: outfit(corps.headlineSmall),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentPrimaryDark,
        secondary: AppColors.securityVerified,
        error: AppColors.securityCritical,
        surface: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        // Pas de bordure au focus non plus.
        //
        // Le champ est déjà distingué par son fond plein, et le curseur dit
        // où l'on écrit. Un liseré vert par-dessus ajoutait une deuxième
        // marque pour la même information, et faisait sauter la hauteur du
        // champ au moment précis où l'on commence à taper.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, space: 1),
      // Glissement court et fondu plutôt que le zoom par défaut — voir
      // page_transitions.dart.
      pageTransitionsTheme: pokouPageTransitionsTheme,
    );
  }
}
