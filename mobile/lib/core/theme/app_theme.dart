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
    // Inter is the design system's UI and heading family. The explicit
    // fallback list preserves Arabic and other script coverage.
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

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: corps,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.actionButtonBackground,
        onPrimary: AppColors.actionButtonForeground,
        secondary: AppColors.securityVerified,
        error: AppColors.feedbackDanger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.actionButtonBackground,
          foregroundColor: AppColors.actionButtonForeground,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
          ),
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
