import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';

/// Bouton d'action flottant de la maquette Figma : 56 pt, dégradé terre
/// cuite #B86538 → #7F3D1E, ombre chaude.
class PokouFab extends StatelessWidget {
  const PokouFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.action,
            boxShadow: AppElevation.prominent,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
