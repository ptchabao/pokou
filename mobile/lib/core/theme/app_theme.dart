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
      // Les EMOJI (et les drapeaux) : sans eux dans la chaîne, iOS affichait
      // des carrés « ? » à la place.
      'Apple Color Emoji',
      'Noto Color Emoji',
    ];

    final applied = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Inter',
      fontFamilyFallback: fallback,
    );
    // Jetons « display » des maquettes : demi-gras, interlettrage -0,2.
    TextStyle? titre(TextStyle? s) =>
        s?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2);
    final corps = applied.copyWith(
      displayLarge: titre(applied.displayLarge),
      displayMedium: titre(applied.displayMedium),
      displaySmall: titre(applied.displaySmall),
      headlineLarge: titre(applied.headlineLarge),
      headlineMedium: titre(applied.headlineMedium),
      headlineSmall: titre(applied.headlineSmall),
      titleLarge: titre(applied.titleLarge),
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
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: fallback,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
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
      // ── Maquettes Stitch « Terre de Confiance » ───────────────────────
      // Cartes blanches arrondies sur fond crème, actions en pastille,
      // filtres en pastille beige, titres Inter demi-gras.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.shadowTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.actionButtonBackground,
          foregroundColor: AppColors.actionButtonForeground,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimaryDark,
          backgroundColor: AppColors.neutralBeige.withValues(alpha: 0.6),
          minimumSize: const Size(64, 52),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimaryDark,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceElevated,
        selectedColor: AppColors.terracottaTint,
        checkmarkColor: AppColors.onTerracottaTint,
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: AppColors.onTerracottaTint,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.2,
          color: AppColors.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.accentPrimaryDark,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentPrimary
              : AppColors.neutralSable,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, space: 1),
      // Glissement court et fondu plutôt que le zoom par défaut — voir
      // page_transitions.dart.
      pageTransitionsTheme: pokouPageTransitionsTheme,
    );
  }
}
