import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pokou_back_button.dart';

/// Les pièces communes aux écrans PAYANTS de Pokou.
///
/// Dans leur propre fichier parce que « créer une publicité », « devenir
/// vendeur vérifié » et les modules payants posent exactement la même
/// question à l'utilisateur — qu'est-ce que j'achète, combien, et qu'est-ce
/// qui se passe ensuite — et doivent donc y répondre de la même façon. Deux
/// réponses différentes à la même question sur deux écrans voisins se
/// remarquent tout de suite.
///
/// Elles ont quitté `features/marketplace/` le jour où les modules s'en sont
/// servis : une pièce partagée par deux fonctionnalités n'appartient plus à
/// l'une d'elles.

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
      child: Row(
        children: [
          const PokouBackButton(),
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

typedef ExplainerStep = ({IconData icon, String title, String body});

/// Les quelques phrases qui manquaient.
///
/// Un écran qui demande de dépenser sans dire ce qui va se passer laisse
/// deux réactions possibles : renoncer, ou payer sans comprendre — et se
/// plaindre ensuite. Les deux coûtent plus cher que ces lignes.
class ExplainerCard extends StatelessWidget {
  const ExplainerCard({required this.steps});

  final List<ExplainerStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(steps[i].icon, size: 18, color: AppColors.accentPrimaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].body,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// La barre de paiement, toujours visible.
///
/// Le prix reste sous les yeux pendant qu'on remplit le formulaire : un
/// montant qui n'apparaît qu'au moment de payer se lit comme un piège, et
/// c'est exactement ce que faisait la boîte de dialogue précédente.
class PayBar extends StatelessWidget {
  const PayBar({
    required this.price,
    required this.caption,
    required this.actionLabel,
    required this.busy,
    required this.onPressed,
  });

  final int price;
  final String caption;
  final String actionLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$price FCFA',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              Text(
                caption,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
