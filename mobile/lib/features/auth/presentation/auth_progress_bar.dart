import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// La barre à 3 segments de l'inscription (maquette « Étape N sur 3 ») : vert
/// pour une étape franchie, terre cuite pour l'étape en cours, gris pour ce
/// qui reste. Le premier écran (bienvenue et numéro) n'en a pas — il n'a pas
/// encore de parcours à montrer — elle apparaît à partir du code reçu.
class AuthProgressBar extends StatelessWidget {
  const AuthProgressBar({super.key, required this.step, this.totalSteps = 3});

  /// L'étape courante, à partir de 1.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < step
                    ? AppColors.feedbackSuccess
                    : i == step
                    ? AppColors.accentPrimary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
