import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared shadow presets — shadow COLOR was already 100% consistent
/// (`AppColors.shadowTint`) everywhere, but blur/offset pairs were 6
/// different inline combos with no shared "elevation" tier.
class AppElevation {
  AppElevation._();

  static final subtle = [
    BoxShadow(color: AppColors.shadowTint, blurRadius: 8, offset: Offset(0, 3)),
  ];

  static final card = [
    BoxShadow(color: AppColors.shadowTint, blurRadius: 12, offset: Offset(0, 4)),
  ];

  static final prominent = [
    BoxShadow(color: AppColors.shadowTint, blurRadius: 16, offset: Offset(0, 6)),
  ];
}
