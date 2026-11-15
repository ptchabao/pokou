import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Une photo de la visionneuse.
class ViewerImage {
  const ViewerImage({
    required this.full,
    this.preview,
    this.heroTag,
    this.title,
    this.subtitle,
    this.caption,
  });

  /// Discussions · 25 — l'auteur en tête (« Séna K. »), puis la
  /// conversation et l'heure (« Famille Koffi · aujourd'hui, 15:10 »).
  final String? title;
  final String? subtitle;

  /// La légende, posée sous la photo.
  final String? caption;

  /// L'image en pleine définition, ajustée à l'écran (`BoxFit.contain`).
  final Widget full;

  /// La même image, déjà décodée à la taille de la vignette qu'on vient de
  /// toucher. Affichée sous [full] le temps que celle-ci se décode : sans
  /// elle, la photo qui s'agrandit passe par un cadre vide.
  final Widget? preview;

  /// Le `Hero` de la vignette d'origine : la photo s'agrandit depuis elle
  /// au lieu d'apparaître d'un bloc, et y retourne à la fermeture.
  final Object? heroTag;
}

/// La visionneuse plein écran, la même partout : photo de conversation,
/// fiche produit.
///
/// ── Ce que faisait l'ancienne ──────────────────────────────────────────
///
/// Un écran noir poussé comme n'importe quel autre, avec un
/// `InteractiveViewer` nu. Le noir arrivait d'un coup, la photo
/// apparaissait sans lien avec la vignette touchée, et seule la flèche
/// retour fermait.
///
/// ── Ce que fait celle-ci ───────────────────────────────────────────────
///
/// - la photo s'agrandit depuis la vignette (`Hero`) pendant que le noir
///   monte en fondu ;
/// - pincer pour zoomer, double toucher pour zoomer là où l'on touche ;
/// - glisser vers le bas (ou le haut) ferme, comme sur WhatsApp : la photo
///   suit le doigt en rétrécissant, le noir s'éclaircit, et elle retourne
///   dans sa vignette ;
/// - plusieurs photos se parcourent en glissant latéralement.
/// Les gestes de la barre du bas (Discussions · 25) : Répondre,
/// Transférer, Enregistrer, Réagir. Absente quand rien n'est fourni — la
/// fiche produit, par exemple, n'a rien de tout cela.
class ViewerActions {
  const ViewerActions({
    this.onReply,
    this.onForward,
    this.onSave,
    this.onReact,
    this.onShare,
  });

  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onSave;

  /// Reçoit l'émoji choisi dans la barre rapide.
  final ValueChanged<String>? onReact;
  final VoidCallback? onShare;
}

class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.actions,
  }) : assert(images.length > 0);

  final List<ViewerImage> images;
  final int initialIndex;
  final ViewerActions? actions;

  /// Ouvre la visionneuse par-dessus l'écran courant.
  ///
  /// Une route NON opaque : l'écran d'en dessous reste peint, c'est ce qui
  /// permet au noir de monter en fondu et de s'éclaircir pendant le
  /// glissement de fermeture.
  static Future<void> open(
    BuildContext context, {
    required List<ViewerImage> images,
    int initialIndex = 0,
    ViewerActions? actions,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: null,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => ImageViewer(
          images: images,
          initialIndex: initialIndex,
          actions: actions,
        ),
        // Le fondu porte sur le noir et la barre du haut, dans la page —
        // la photo, elle, est portée par son Hero.
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

/// Distance de glissement (en points) au-delà de laquelle relâcher ferme.
const _dismissDistance = 110.0;

/// Vitesse verticale (points/s) qui ferme même sur une courte distance —
/// un geste vif vers le bas.
const _dismissVelocity = 900.0;

const _doubleTapScale = 2.5;

class _ImageViewerState extends State<ImageViewer>
    with TickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  final _transform = TransformationController();
  bool _zoomed = false;
  TapDownDetails? _doubleTapAt;
  // Créés dans initState, et non à la demande : un contrôleur paresseux
  // qu'on n'a jamais utilisé naîtrait dans `dispose`, au moment où l'état
  // ne peut plus créer de ticker.
  late final AnimationController _zoomAnimation;
  late final CurvedAnimation _zoomCurve;
  Matrix4Tween? _zoomTween;

  /// Le décalage vertical du glissement de fermeture.
  double _drag = 0;
  late final AnimationController _dragBack;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _zoomAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => _transform.value = _zoomTween!.evaluate(_zoomCurve));
    _zoomCurve = CurvedAnimation(
      parent: _zoomAnimation,
      curve: Curves.fastOutSlowIn,
    );
    _dragBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _zoomCurve.dispose();
    _zoomAnimation.dispose();
    _dragBack.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target);
    _zoomAnimation.forward(from: 0);
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final at = _doubleTapAt?.localPosition;
    if (at == null) return;
    // Zoomer AUTOUR du point touché : on agrandit, puis on décale pour que
    // ce point reste sous le doigt.
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(
          -at.dx * (_doubleTapScale - 1),
          -at.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1),
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_zoomed) return;
    _dragBack.stop();
    setState(() => _drag += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_zoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.abs() > _dismissDistance || velocity.abs() > _dismissVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    // Pas assez loin : la photo revient à sa place.
    final from = _drag;
    final back = CurvedAnimation(parent: _dragBack, curve: Curves.easeOut);
    void step() => setState(() => _drag = from * (1 - back.value));
    _dragBack
      ..removeListener(step)
      ..addListener(step)
      ..forward(
        from: 0,
      ).whenCompleteOrCancel(() => _dragBack.removeListener(step));
  }

  void _onPageChanged(int index) {
    // Une autre photo s'ouvre au cadrage d'origine.
    _transform.value = Matrix4.identity();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)!.animation!;
    final size = MediaQuery.sizeOf(context);
    // 0 au repos, 1 à la distance de fermeture : pilote le fond et la taille.
    final progress = (_drag.abs() / (size.height / 2)).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Le noir monte avec la route et s'éclaircit avec le glissement.
          AnimatedBuilder(
            animation: route,
            builder: (context, _) => ColoredBox(
              color: Colors.black.withValues(
                alpha: Curves.easeOut.transform(route.value) * (1 - progress),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            onDoubleTapDown: (details) => _doubleTapAt = details,
            onDoubleTap: _onDoubleTap,
            onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
            onVerticalDragEnd: _zoomed ? null : _onDragEnd,
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: Transform.scale(
                scale: 1 - progress * 0.25,
                child: PageView.builder(
                  controller: _pages,
                  // Zoomé, le glissement déplace la photo, pas la page.
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) => _page(index),
                ),
              ),
            ),
          ),
          _chrome(route),
          _bottom(route),
        ],
      ),
    );
  }

  /// La légende et la barre d'actions, en bas.
  Widget _bottom(Animation<double> route) {
    final image = widget.images[_index];
    final actions = widget.actions;
    final caption = image.caption?.trim() ?? '';
    if (actions == null && caption.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: route,
        child: AnimatedOpacity(
          opacity: _chromeVisible && _drag == 0 ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (caption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (actions != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (actions.onReply != null)
                            _ViewerAction(
                              icon: Icons.chat_bubble_outline,
                              label: l.viewerReply,
                              onTap: () {
                                Navigator.of(context).maybePop();
                                actions.onReply!();
                              },
                            ),
                          if (actions.onForward != null)
                            _ViewerAction(
                              icon: Icons.forward,
                              label: l.viewerForward,
                              onTap: () {
                                Navigator.of(context).maybePop();
                                actions.onForward!();
                              },
                            ),
                          if (actions.onSave != null)
                            _ViewerAction(
                              icon: Icons.download_outlined,
                              label: l.viewerSave,
                              onTap: actions.onSave!,
                            ),
                          if (actions.onReact != null)
                            _ViewerAction(
                              icon: Icons.favorite_border,
                              label: l.viewerReact,
                              onTap: () => _pickReaction(actions.onReact!),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// La barre rapide de réactions, la même que sur une bulle.
  Future<void> _pickReaction(ValueChanged<String> onReact) async {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in emojis)
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext, e),
                  tooltip: e,
                  icon: Text(e, style: const TextStyle(fontSize: 26)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji != null) onReact(emoji);
  }

  Widget _page(int index) {
    final image = widget.images[index];
    final content = Stack(
      fit: StackFit.expand,
      children: [if (image.preview != null) image.preview!, image.full],
    );
    final current = index == _index;
    return InteractiveViewer(
      // Seule la photo affichée suit les gestes de zoom ; les voisines,
      // en attente dans le PageView, restent au cadrage d'origine.
      transformationController: current ? _transform : null,
      minScale: 1,
      maxScale: 5,
      // Au repos, un glissement appartient au PageView ou à la fermeture,
      // pas au déplacement de la photo.
      panEnabled: _zoomed,
      child: image.heroTag != null && current
          ? Hero(tag: image.heroTag!, child: content)
          : content,
    );
  }

  Widget _chrome(Animation<double> route) {
    final count = widget.images.length;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: FadeTransition(
        opacity: route,
        child: AnimatedOpacity(
          opacity: _chromeVisible && _drag == 0 ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
                // Discussions · 25 — qui l'a envoyée, où et quand.
                if (widget.images[_index].title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.images[_index].title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.images[_index].subtitle != null)
                          Text(
                            widget.images[_index].subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (count > 1)
                  Text(
                    '${_index + 1} / $count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (widget.images[_index].title == null) const Spacer(),
                if (widget.actions?.onShare != null)
                  IconButton(
                    onPressed: widget.actions!.onShare,
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                    tooltip: L.of(context).actionShare,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}
