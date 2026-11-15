import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Le badge d'un compte certifié, à côté d'un nom.
///
/// ── Deux badges, deux formes ──────────────────────────────────────────
///
/// Même vérification d'identité, mêmes droits sur le mode preuve : seule la
/// FORME dit ce qui est derrière le nom. Une rosette terre cuite à coche
/// blanche pour Pokou certifié (une personne), un hexagone ébène à coche or
/// pour Pokou certifié Pro (une activité). Jamais la couleur seule : le
/// lecteur d'écran dit « Pokou certifié » ou « Pokou certifié Pro », et sur
/// fond sombre l'hexagone prend un contour or au lieu de disparaître.
///
/// ── Une propriété du compte, pas une décoration d'écran ───────────────
///
/// Le badge vient d'`is_verified`, et sa forme de `badge` ("PRO" ou
/// "CERTIFIED"), servis ensemble par chaque sérialisation d'utilisateur
/// (api/app/utils/identity.py). Aucun écran ne connaît la colonne d'origine.
///
/// ── Pourquoi un widget et pas une icône recopiée ──────────────────────
///
/// Recopier une icône dans huit écrans garantit qu'au neuvième il manquera,
/// et qu'au dixième il aura une autre taille ou une autre couleur. Un badge
/// d'identité qui apparaît par intermittence est pire qu'absent : il
/// apprend à ne pas s'y fier.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14, this.pro = false});

  final double size;

  /// L'hexagone de Pokou certifié Pro, au lieu de la rosette.
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final label = pro ? L.of(context).badgeProLabel : L.of(context).identityVerifiedAccount;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: CustomPaint(
          size: Size.square(size),
          painter: PokouBadgePainter(pro: pro, dark: AppColors.isDark),
        ),
      ),
    );
  }
}

/// Le dessin des deux badges, partagé avec l'écran « Deux badges, deux
/// formes » qui les montre en grand.
class PokouBadgePainter extends CustomPainter {
  const PokouBadgePainter({required this.pro, required this.dark});

  final bool pro;
  final bool dark;

  /// L'ébène et l'or de la charte (brand.ebene-900, brand.or-500).
  static const _ebony = AppColors.brandEbene;
  static const _gold = AppColors.brandOr;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side / 2;
    if (pro) {
      final hexagon = _hexagon(center, radius * 0.98);
      if (dark) {
        // Sur fond sombre, un hexagone ébène plein se confondrait avec le
        // fond : il prend un contour or (maquette, « sur fond sombre »).
        canvas.drawPath(
          hexagon,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.09
            ..strokeJoin = StrokeJoin.round
            ..color = _gold,
        );
      } else {
        canvas.drawPath(
          hexagon,
          Paint()
            ..color = _ebony
            ..strokeJoin = StrokeJoin.round,
        );
      }
      _check(canvas, center, side, _gold);
    } else {
      canvas.drawPath(
        _rosette(center, radius),
        Paint()..color = AppColors.accentPrimary,
      );
      _check(canvas, center, side, Colors.white);
    }
  }

  /// Une rosette à dix festons : un cercle dont le rayon ondule.
  static Path _rosette(Offset c, double r) {
    const lobes = 10;
    const steps = 120;
    final base = r * 0.88;
    final wave = r * 0.12;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final rho = base + wave * math.cos(lobes * t);
      final point = Offset(c.dx + rho * math.cos(t), c.dy + rho * math.sin(t));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  /// Un hexagone pointe en haut.
  static Path _hexagon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final t = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(c.dx + r * math.cos(t), c.dy + r * math.sin(t));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  static void _check(Canvas canvas, Offset c, double side, Color color) {
    final s = side;
    final path = Path()
      ..moveTo(c.dx - s * 0.22, c.dy + s * 0.01)
      ..lineTo(c.dx - s * 0.06, c.dy + s * 0.16)
      ..lineTo(c.dx + s * 0.23, c.dy - s * 0.15);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, s * 0.11)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(PokouBadgePainter oldDelegate) =>
      oldDelegate.pro != pro || oldDelegate.dark != dark;
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
    this.isPro = false,
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

  /// Pokou certifié Pro : l'hexagone au lieu de la rosette.
  final bool isPro;

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
          VerifiedBadge(size: badgeSize, pro: isPro),
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
