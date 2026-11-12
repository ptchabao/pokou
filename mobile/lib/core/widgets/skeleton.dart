import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Les formes grises qui tiennent la place d'un contenu pendant son
/// chargement.
///
/// Elles remplacent les ronds qui tournent, et ce n'est pas une question de
/// goût. Un indicateur de progression dit « attendez » sans rien dire de
/// plus : l'écran reste vide, sa hauteur change d'un coup à l'arrivée des
/// données, et tout ce qui était en dessous saute. Un squelette dit « il y
/// aura ici une liste de chaînes, avec une image ronde et deux lignes de
/// texte » — la mise en page est déjà en place, l'arrivée du vrai contenu ne
/// déplace plus rien, et l'attente paraît plus courte parce qu'on a déjà
/// quelque chose à regarder.
///
/// D'où la règle qui suit ces classes : un squelette doit avoir la FORME de
/// ce qu'il remplace. Un rectangle générique ne vaut pas mieux qu'un rond
/// qui tourne.

/// Anime tout un groupe de formes d'une seule pulsation.
///
/// Un `AnimationController` par forme donnerait une dizaine de tickers pour
/// une liste, et — pire — des pulsations désynchronisées : l'écran
/// scintillerait au lieu de respirer. Un seul contrôleur ici, et les formes
/// en dessous restent de simples widgets sans état.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quelqu'un qui a demandé moins d'animations dans les réglages
    // d'accessibilité ne doit pas voir l'écran palpiter : les formes
    // restent alors immobiles, et disent la même chose.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.45,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Un bloc gris — une ligne de texte, une vignette, un bouton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  /// `double.infinity` pour occuper toute la largeur disponible.
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeletonFill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Un rond gris — une photo de profil, une image de chaîne, un statut.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.skeletonFill,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Les formes prêtes à l'emploi ─────────────────────────────────────────
//
// Une par famille d'écran. Chacune porte sa propre pulsation : on la pose à
// la place du contenu, sans rien autour.

/// Une ligne de liste : une photo ronde, un nom, une ligne dessous, et
/// l'heure à droite — discussions, contacts, appels, notifications.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    super.key,
    this.avatarSize = 48,
    this.titleWidth = 150,
    this.subtitleWidth = 210,
    this.trailing = true,
  });

  final double avatarSize;
  final double titleWidth;
  final double subtitleWidth;
  final bool trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        SkeletonCircle(size: avatarSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: titleWidth, height: 14),
              const SizedBox(height: 8),
              SkeletonBox(width: subtitleWidth, height: 12),
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: 12),
          const SkeletonBox(width: 34, height: 11),
        ],
      ],
    ),
  );
}

/// Une liste en attente. Les largeurs varient d'une ligne à l'autre : des
/// lignes toutes identiques se lisent comme un motif, pas comme une liste.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 8,
    this.avatarSize = 48,
    this.trailing = true,
    this.padding = EdgeInsets.zero,
  });

  final int count;
  final double avatarSize;
  final bool trailing;
  final EdgeInsets padding;

  static const _titles = [150.0, 118.0, 172.0, 96.0, 140.0];
  static const _subtitles = [210.0, 168.0, 232.0, 190.0, 144.0];

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            SkeletonListTile(
              avatarSize: avatarSize,
              trailing: trailing,
              titleWidth: _titles[i % _titles.length],
              subtitleWidth: _subtitles[i % _subtitles.length],
            ),
        ],
      ),
    ),
  );
}

/// Une conversation en attente : des bulles des deux côtés.
class SkeletonBubbles extends StatelessWidget {
  const SkeletonBubbles({super.key});

  // (largeur, hauteur, à moi)
  static const _bubbles = [
    (190.0, 38.0, false),
    (140.0, 38.0, false),
    (220.0, 56.0, true),
    (120.0, 38.0, true),
    (240.0, 72.0, false),
    (170.0, 38.0, true),
    (200.0, 38.0, false),
    (150.0, 56.0, true),
  ];

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          for (final (width, height, mine) in _bubbles)
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SkeletonBox(width: width, height: height, radius: 16),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Des cartes pleine largeur en attente — commandes, cagnottes, annonces.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({
    super.key,
    this.count = 3,
    this.height = 132,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final int count;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonCard(height: height),
            ),
        ],
      ),
    ),
  );
}

/// Une carte en attente : un titre, deux lignes, une barre.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 132});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 90, height: 10),
        SizedBox(height: 10),
        SkeletonBox(width: 180, height: 16),
        Spacer(),
        SkeletonBox(width: 130, height: 12),
        SizedBox(height: 10),
        SkeletonBox(width: double.infinity, height: 8, radius: 4),
      ],
    ),
  );
}

/// Une grille de vignettes en attente — produits, médias.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.count = 6,
    this.columns = 2,
    this.aspectRatio = 0.78,
    this.padding = const EdgeInsets.all(16),
  });

  final int count;
  final int columns;
  final double aspectRatio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        for (var i = 0; i < count; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.skeletonFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SkeletonBox(width: 110, height: 13),
              const SizedBox(height: 6),
              const SkeletonBox(width: 64, height: 12),
            ],
          ),
      ],
    ),
  );
}

/// N'affiche le squelette qu'après [delay].
///
/// Pour les écrans qui lisent d'abord un cache local : la lecture prend
/// quelques millisecondes, et un squelette qui apparaît puis disparaît dans
/// la même image fait clignoter l'écran — c'est pire que de ne rien montrer.
/// Il n'arrive donc que si l'attente dure vraiment, et en fondu.
class DelayedSkeleton extends StatefulWidget {
  const DelayedSkeleton({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 220),
  });

  final Widget child;
  final Duration delay;

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: const Duration(milliseconds: 180),
    child: widget.child,
  );
}
