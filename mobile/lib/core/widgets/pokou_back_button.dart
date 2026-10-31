import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'soft_icon_button.dart';

/// Bouton retour unique pour tout l'écran — utilise go_router quand une
/// route nommée est sur la pile, sinon retombe sur le Navigator classique
/// (écrans poussés via MaterialPageRoute, ex. journal d'appels, profil
/// contact, conversation).
class PokouBackButton extends StatelessWidget {
  const PokouBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SoftIconButton(
      icon: Icons.arrow_back,
      onPressed: () => context.canPop() ? context.pop() : Navigator.of(context).maybePop(),
    
      tooltip: L.of(context).a11yBack,
    );
  }
}
