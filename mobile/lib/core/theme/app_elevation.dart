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

  static final card = [
    BoxShadow(color: AppColors.shadowTint, blurRadius: 2, offset: Offset(0, 1)),
  ];

  static final prominent = [
    // Bouton d'action flottant : 0 4px 12px rgba(26,22,21,0.10).
    BoxShadow(color: Color(0x1A1A1615), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
