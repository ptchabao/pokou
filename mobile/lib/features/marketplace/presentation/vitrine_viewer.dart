import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/media_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_model.dart';
import '../data/vitrine.dart';
import 'marketplace_controller.dart';
import 'product_detail_screen.dart';

/// L'étiquette `Hero` d'un article de la vitrine : la même dans la bande,
/// dans la vitrine et sur la fiche, pour que la photo passe de l'une à
/// l'autre.
String vitrineHeroTag(MarketplaceProduct product) => 'vitrine-${product.id}';

/// La vitrine plein écran : du lèche-vitrine, en cartes.
///
/// Rien que les photos — ni nom, ni prix : on regarde, on ne lit pas. Les
/// cartes s'empilent comme sur Tinder et partent d'elles-mêmes au bout de
/// quelques secondes. Le doigt peut les devancer :
///
/// - **vers la droite** — ça me plaît : la fiche de l'article s'ouvre ;
/// - **vers la gauche** — suivant ;
/// - **toucher** — ouvre aussi la fiche ;
/// - **maintenir** — pause ;
/// - **glisser vers le bas** — fermer.
///
/// Au retour d'une fiche, la vitrine repart sur la carte suivante. À
/// l'approche de la fin, elle charge la page suivante du Marché ; elle ne
/// se ferme qu'au bout du catalogue.
class VitrineViewer extends ConsumerStatefulWidget {
  const VitrineViewer({
    super.key,
    required this.products,
    this.initialIndex = 0,
    this.nextOffset,
  });

  final List<MarketplaceProduct> products;
  final int initialIndex;

  /// Où reprendre dans le catalogue, ou `null` s'il n'y a plus rien après.
  final int? nextOffset;

  /// Combien de temps chaque carte reste avant de partir seule.
  static const perProduct = Duration(seconds: 5);

  static Future<void> open(
    BuildContext context, {
    required List<MarketplaceProduct> products,
    int initialIndex = 0,
    int? nextOffset,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => VitrineViewer(
          products: products,
          initialIndex: initialIndex,
          nextOffset: nextOffset,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  ConsumerState<VitrineViewer> createState() => _VitrineViewerState();
}

/// Au-delà de cette fraction de largeur, relâcher envoie la carte.
const _swipeThreshold = 0.28;

/// Une vitesse horizontale (points/s) qui envoie la carte même de près.
const _flingVelocity = 700.0;

class _VitrineViewerState extends ConsumerState<VitrineViewer>
    with TickerProviderStateMixin {
  late final List<MarketplaceProduct> _products = [...widget.products];
  late int? _nextOffset = widget.nextOffset;
  late int _index = widget.initialIndex.clamp(0, _products.length - 1);
  bool _loadingMore = false;

  /// Le compte à rebours de la carte du dessus.
  late final AnimationController _progress;

  /// Le déplacement de la carte : suit le doigt, puis s'envole ou revient.
  Offset _drag = Offset.zero;
  late final AnimationController _fly;
  Animation<Offset>? _flight;

  /// Une fiche ouverte par-dessus : rien ne bouge en attendant le retour.
  bool _away = false;

  /// Une carte en vol : les gestes attendent qu'elle soit partie.
  bool _flying = false;

  MarketplaceProduct get _current => _products[_index];

  @override
  void initState() {
    super.initState();
    _progress =
        AnimationController(vsync: this, duration: VitrineViewer.perProduct)
          ..addStatusListener((status) {
            // Le temps est écoulé : la carte part d'elle-même, vers la
            // gauche — « suivant », comme si on l'avait écartée.
            if (status == AnimationStatus.completed) unawaited(_send(-1));
          });
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() => _drag = _flight!.value));
    // Après l'entrée de la route : la première carte ne doit pas perdre
    // ses premières secondes pendant que la photo s'agrandit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _progress.forward(from: 0);
    });
    _maybeLoadMore();
  }

  @override
  void dispose() {
    _progress.dispose();
    _fly.dispose();
    super.dispose();
  }

  Future<void> _animateDragTo(Offset target, Curve curve) async {
    _flight = Tween<Offset>(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _fly, curve: curve));
    await _fly.forward(from: 0);
  }

  /// Envoie la carte du dessus : [direction] 1 à droite (elle plaît, sa
  /// fiche s'ouvre), -1 à gauche (suivante).
  Future<void> _send(int direction) async {
    if (!mounted || _away || _flying) return;
    _flying = true;
    _progress.stop();
    final width = MediaQuery.sizeOf(context).width;
    HapticFeedback.selectionClick();
    await _animateDragTo(
      Offset(direction * width * 1.5, _drag.dy + 40),
      Curves.easeIn,
    );
    if (!mounted) return;
    _flying = false;
    if (direction > 0) {
      // La carte vient de sortir de l'écran : pas de Hero, la photo
      // reviendrait de hors champ.
      await _openProduct(_current, flyPhoto: false);
    } else {
      await _next();
    }
  }

  /// Passe à la carte suivante, ou charge la suite, ou ferme au bout.
  Future<void> _next() async {
    if (_index >= _products.length - 1 && _nextOffset != null) {
      await _loadMore();
    }
    if (!mounted) return;
    if (_index >= _products.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _index++;
      _drag = Offset.zero;
    });
    _maybeLoadMore();
    if (!_away) _progress.forward(from: 0);
  }

  void _maybeLoadMore() {
    if (_products.length - _index <= 3) unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final offset = _nextOffset;
    if (_loadingMore || offset == null) return;
    _loadingMore = true;
    try {
      final page = await loadVitrinePage(
        ref.read(marketplaceRepositoryProvider),
        myUserId: ref.read(authControllerProvider).user?.id,
        offset: offset,
      );
      if (!mounted) return;
      final known = {for (final p in _products) p.id};
      setState(() {
        // Sans doublon : deux pages qui se chevauchent montreraient deux
        // fois le même article — et deux Hero de même étiquette.
        _products.addAll(page.items.where((p) => !known.contains(p.id)));
        _nextOffset = page.nextOffset;
      });
    } catch (_) {
      // Hors ligne : la vitrine s'arrêtera à la dernière carte chargée.
      _nextOffset = null;
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _openProduct(
    MarketplaceProduct product, {
    bool flyPhoto = true,
  }) async {
    _away = true;
    _progress.stop();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          heroTag: flyPhoto ? vitrineHeroTag(product) : null,
        ),
      ),
    );
    if (!mounted) return;
    _away = false;
    // Revenu de la fiche : la vitrine reprend sur la carte SUIVANTE, sans
    // remontrer celle qu'on vient de regarder.
    await _next();
  }

  Future<void> _tapOpen() async {
    if (_flying || _away) return;
    _progress.stop();
    await _openProduct(_current);
  }

  void _onPanStart(DragStartDetails _) {
    if (_flying) return;
    _progress.stop();
    _fly.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_flying) return;
    setState(() => _drag += details.delta);
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_flying) return;
    final size = MediaQuery.sizeOf(context);
    final velocity = details.velocity.pixelsPerSecond;
    // Vers le bas, franchement : on ferme.
    if (_drag.dy > 140 && _drag.dy.abs() > _drag.dx.abs() * 1.5) {
      Navigator.of(context).maybePop();
      return;
    }
    final fraction = _drag.dx / size.width;
    if (fraction > _swipeThreshold || velocity.dx > _flingVelocity) {
      await _send(1);
    } else if (fraction < -_swipeThreshold || velocity.dx < -_flingVelocity) {
      await _send(-1);
    } else {
      // Pas assez loin : la carte revient au centre et le compte reprend.
      await _animateDragTo(Offset.zero, Curves.easeOutBack);
      if (mounted && !_away) _progress.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final l = L.of(context);
    // -1 (tout à gauche) … 1 (tout à droite) : pilote la rotation, les
    // pictogrammes et la remontée de la carte suivante.
    final lean = (_drag.dx / (size.width * _swipeThreshold)).clamp(-1.0, 1.0);
    final hasNext = _index < _products.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                progress: _progress,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // La carte suivante, en retrait, qui remonte à mesure
                      // que celle du dessus s'écarte.
                      if (hasNext)
                        Transform.scale(
                          scale: 0.93 + 0.07 * lean.abs(),
                          child: _Card(
                            key: ValueKey(
                              'vitrine-card-${_products[_index + 1].id}',
                            ),
                            product: _products[_index + 1],
                            hero: false,
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _tapOpen,
                        onLongPressStart: (_) => _progress.stop(),
                        onLongPressEnd: (_) {
                          if (!_away && !_flying) _progress.forward();
                        },
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Transform.translate(
                          offset: _drag,
                          child: Transform.rotate(
                            // Pivote depuis le bas, comme une carte tenue
                            // par son coin.
                            angle: lean * math.pi / 18,
                            alignment: Alignment.bottomCenter,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _Card(
                                  key: ValueKey('vitrine-card-${_current.id}'),
                                  product: _current,
                                  hero: true,
                                ),
                                _Stamp(
                                  icon: Icons.favorite_rounded,
                                  color: const Color(0xFFA65527),
                                  opacity: lean.clamp(0.0, 1.0),
                                  alignment: Alignment.topLeft,
                                  label: l.vitrineSeeProduct,
                                ),
                                _Stamp(
                                  icon: Icons.close_rounded,
                                  color: Colors.white,
                                  opacity: (-lean).clamp(0.0, 1.0),
                                  alignment: Alignment.topRight,
                                  label: MaterialLocalizations.of(
                                    context,
                                  ).nextPageTooltip,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une carte : la photo de l'article, bord à bord, coins arrondis.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.product, required this.hero});

  final MarketplaceProduct product;

  /// Seule la carte du dessus porte le `Hero` : deux cartes de même
  /// étiquette sur un écran font échouer l'animation.
  final bool hero;

  /// La taille déjà décodée pour la fiche produit : vitrine et fiche se
  /// partagent le cache, la photo ne se décode qu'une fois.
  static const _decodeWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final image = MediaImage.meta(
      product.coverImage!,
      decodeWidth: _decodeWidth,
      placeholder: const ColoredBox(color: Color(0xFF1F2C34)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: hero ? Hero(tag: vitrineHeroTag(product), child: image) : image,
      ),
    );
  }
}

/// Le pictogramme qui apparaît à mesure que la carte penche : un cœur à
/// droite (ouvrir), une croix à gauche (suivant). Sans texte affiché — le
/// libellé est pour les lecteurs d'écran.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.icon,
    required this.color,
    required this.opacity,
    required this.alignment,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final double opacity;
  final Alignment alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Opacity(
          opacity: opacity,
          child: Semantics(
            label: label,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x66000000),
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.onClose});

  final Animation<double> progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.value,
                  minHeight: 2.5,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}
