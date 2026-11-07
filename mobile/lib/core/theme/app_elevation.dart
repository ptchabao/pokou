import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared shadow presets — shadow COLOR was already 100% consistent
/// (`AppColors.shadowTint`) everywhere, but blur/offset pairs were 6
/// different inline combos with no shared "elevation" tier.
class AppElevation {
  AppElevation._();

  static final subtle = [
    // shadow-[0px_1px_2px_0px_rgba(26,22,21,0.08)] des maquettes.
    BoxShadow(color: AppColors.shadowTint, blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Carte : 0 8px 22px rgba(73,50,36,.055), 0 1px 2px rgba(44,31,24,.045).
  static List<BoxShadow> get card => AppColors.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0E493224),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x0B2C1F18),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];

  /// Bouton d'action flottant et bouton principal : ombre terre cuite
  /// 0 10px 24px rgba(127,61,30,.3).
  static final prominent = [
    BoxShadow(color: Color(0x4D7F3D1E), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Carte de marque (Discussions, ordonnance) : 0 12px 26px rgba(127,61,30,.2).
  static const brand = [
    BoxShadow(color: Color(0x337F3D1E), blurRadius: 26, offset: Offset(0, 12)),
  ];
}
