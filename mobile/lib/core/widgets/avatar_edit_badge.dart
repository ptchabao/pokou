import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Une photo de profil avec son crayon ✏️ : un geste pour la changer.
///
/// Le crayon n'apparaît que si [onEdit] est fourni — pour MON profil, ou
/// pour la photo d'un groupe que j'ai le droit de modifier. Toucher la
/// photo elle-même garde son geste à elle ([onTap], la visionneuse).
class AvatarEditBadge extends StatelessWidget {
  const AvatarEditBadge({
    super.key,
    required this.child,
    this.onEdit,
    this.onTap,
    this.size = 88,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pencil = (size * 0.34).clamp(26.0, 36.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(onTap: onTap ?? onEdit, child: child),
          ),
          if (onEdit != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Tooltip(
                message: tooltip ?? '',
                child: Material(
                  color: AppColors.accentPrimary,
                  shape: CircleBorder(
                    side: BorderSide(color: AppColors.background, width: 2),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEdit,
                    child: SizedBox(
                      width: pencil,
                      height: pencil,
                      child: Icon(
                        Icons.edit,
                        size: pencil * 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
