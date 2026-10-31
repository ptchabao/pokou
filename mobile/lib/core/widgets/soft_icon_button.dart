import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The circular white "soft" buttons in the app bar (menu, profile, back,
/// edit…) — matches the design reference's floating icon-button style.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({super.key, required this.icon, this.onPressed, this.tooltip,});

  final IconData icon;
  final VoidCallback? onPressed;

  /// Le libellé lu par un lecteur d'écran, et affiché à l'appui long.
  ///
  /// Ces boutons enveloppent un `InkWell` nu : sans lui, TalkBack et
  /// VoiceOver annoncent « bouton » sans dire lequel. Une seule propriété
  /// couvre les deux besoins.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.shadowTint, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
