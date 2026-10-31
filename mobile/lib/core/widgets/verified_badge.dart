import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Le ✓ d'un compte certifié, à côté d'un nom.
///
/// ── Une propriété du compte, pas une décoration d'écran ───────────────
///
/// Le badge vient d'`User.is_certified_seller`, exposé par le serveur sous
/// le nom neutre `is_verified` dans chaque sérialisation d'utilisateur. Ce
/// détour a une raison : le jour où la certification de compte se sépare de
/// la vérification vendeur, seule la ligne qui produit `is_verified` change
/// — aucun écran ne connaît la colonne d'origine.
///
/// ── Pourquoi un widget et pas une icône recopiée ──────────────────────
///
/// Recopier `Icon(Icons.verified)` dans huit écrans garantit qu'au neuvième
/// il manquera, et qu'au dixième il aura une autre taille ou une autre
/// couleur. Un badge d'identité qui apparaît par intermittence est pire
/// qu'absent : il apprend à ne pas s'y fier.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L.of(context).identityVerifiedAccount,
      child: Semantics(
        label: L.of(context).identityVerifiedAccount,
        child: Icon(
          Icons.verified,
          size: size,
          color: AppColors.certifiedBadgeBlue,
        ),
      ),
    );
  }
}

/// Un nom, suivi du badge quand le compte est certifié.
///
/// À préférer au couple `Text` + `if (verifie) VerifiedBadge()` recopié :
/// c'est ici que se règle l'espacement, et surtout le comportement quand le
/// nom est trop long. Un nom tronqué doit perdre ses dernières lettres, pas
/// son badge — sinon la certification disparaît précisément pour les noms
/// longs, sans que rien ne l'explique.
class VerifiedName extends StatelessWidget {
  const VerifiedName({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.badgeSize = 14,
    this.maxLines = 1,
    this.isBot = false,
  });

  final String name;
  final bool isVerified;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;

  /// Le compte est le bot d'une entreprise (Pokou Business) : une pastille
  /// « Bot » le dit à côté du nom, partout. On doit savoir qu'on écrit à
  /// un programme — et que ce programme lit ce qu'on lui écrit.
  final bool isBot;

  @override
  Widget build(BuildContext context) {
    if (!isVerified && !isBot) {
      return Text(
        name,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // `Flexible` et non `Expanded` : dans une ligne de liste le nom ne
        // doit prendre que la place dont il a besoin, pour laisser l'heure
        // et le compteur de non-lus à leur place.
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 4),
          VerifiedBadge(size: badgeSize),
        ],
        if (isBot) ...[
          const SizedBox(width: 5),
          const BotPill(),
        ],
      ],
    );
  }
}

/// La pastille « Bot ».
class BotPill extends StatelessWidget {
  const BotPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: L.of(context).botLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: ExcludeSemantics(
          child: Text(
            L.of(context).botLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
