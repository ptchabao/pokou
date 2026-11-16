import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../core/widgets/pokou_tab_page.dart';
import '../../../l10n/app_localizations.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../data/home_banner.dart';

/// Le carrousel du haut de l'Accueil : les bannières de la zone de la
/// personne (pays, région). Sans campagne en cours, il ne prend aucune
/// place — plus de page fixe sur le chiffrement.
///
/// Il avance seul toutes les six secondes, s'arrête dès qu'on y touche, et
/// ne bouge pas si la personne a demandé moins d'animations.
class HomeCarousel extends ConsumerStatefulWidget {
  const HomeCarousel({super.key, required this.onOpenTab});

  final ValueChanged<PokouTab> onOpenTab;

  @override
  ConsumerState<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends ConsumerState<HomeCarousel> {
  static const _height = 120.0;
  static const _interval = Duration(seconds: 6);

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  int _count = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (_count < 2 || MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _count,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _open(HomeBanner banner) async {
    final url = banner.ctaUrl;
    if (url == null) return;
    switch (url) {
      case 'app:kory':
        widget.onOpenTab(PokouTab.kory);
      case 'app:honam':
        widget.onOpenTab(PokouTab.honam);
      case 'app:assime':
        // Barre du bas conservée, « Plus » actif (maquette p.15) : Assimé
        // n'a pas son propre onglet avant le lot 3.
        await PokouTabPage.push(
          context,
          tab: PokouTab.more,
          child: const MarketplaceScreen(),
        );
      default:
        final uri = Uri.tryParse(url);
        // Seulement du https : ce lien vient du serveur, et il s'ouvre chez
        // tout le monde.
        if (uri == null || uri.scheme != 'https') return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners =
        ref.watch(homeBannersProvider).valueOrNull ?? const <HomeBanner>[];
    final count = banners.length;
    if (count != _count) {
      _count = count;
      if (_page >= count) _page = count - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule();
      });
    } else if (_timer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule();
      });
    }

    if (count == 0) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: Listener(
            // Un doigt posé arrête le défilement ; il reprend ensuite.
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _schedule(),
            onPointerCancel: (_) => _schedule(),
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BannerSlide(
                  banner: banners[index],
                  tone: index,
                  onTap: () => _open(banners[index]),
                ),
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          _Dots(count: count, current: _page),
        ],
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? AppColors.accentPrimary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    ),
  );
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({
    required this.banner,
    required this.tone,
    required this.onTap,
  });

  final HomeBanner banner;

  /// Sans image, les bannières alternent entre les fonds de la marque.
  final int tone;
  final VoidCallback onTap;

  static const _fills = [AppGradients.brand, AppGradients.certified];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final image = banner.image;
    final tappable = banner.ctaUrl != null;
    const ink = Color(0xFFFFF9E5);
    return Semantics(
      button: tappable,
      label: [banner.label ?? l.homeAdLabel, banner.title].join(' — '),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: _fills[tone % _fills.length]),
            ),
            if (image != null)
              MediaImage.meta(image, fit: BoxFit.cover, decodeWidth: 900),
            if (image != null)
              // Un voile du bas vers le haut : le texte reste lisible sur
              // n'importe quelle photo, sans l'éteindre entièrement.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xD91A1615), Color(0x401A1615)],
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: tappable ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  // Une bannière basse : le texte à gauche, le bouton à
                  // droite, centrés en hauteur.
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (banner.label ?? l.homeAdLabel).toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandOr,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                banner.title,
                                maxLines: banner.body == null ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 19,
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              if (banner.body != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  banner.body!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.3,
                                    color: ink.withValues(alpha: 0.86),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (tappable) const SizedBox(width: 10),
                      if (tappable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  banner.ctaLabel ?? l.homeAdCta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandEbene,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward,
                                size: 15,
                                color: AppColors.brandEbene,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
