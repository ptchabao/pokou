import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Solid backdrop shared by the tab shell and every pushed screen — painted
/// once here instead of per-screen so every part of the app reads as the
/// same surface (see AppColors.background).
class PokouBackground extends StatelessWidget {
  const PokouBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}
