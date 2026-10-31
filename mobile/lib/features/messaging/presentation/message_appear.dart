import 'package:flutter/material.dart';

import '../../../core/storage/pokou_message_store.dart';

/// L'arrivée d'une bulle : elle grandit de 95 % à 100 % en apparaissant,
/// depuis son coin d'ancrage (en bas à droite pour les siens, en bas à
/// gauche pour les autres).
///
/// ── Seulement pour un message qui ARRIVE ───────────────────────────────
///
/// Animer chaque bulle construite ferait trembler tout l'historique à
/// l'ouverture, et à chaque page remontée en défilant. Une bulle s'anime
/// donc si, et seulement si :
///
/// - c'est la DERNIÈRE de la conversation — ce qui vient d'arriver se met
///   en bas, une page d'historique se met en haut ;
/// - elle n'a jamais été montrée — une bulle qui sort de l'écran puis y
///   revient ne rejoue pas son entrée ;
/// - l'écran a fini de s'ouvrir — la dernière bulle d'une conversation
///   qu'on ouvre n'« arrive » pas ;
/// - pour ses propres messages, c'est l'envoi OPTIMISTE (identifiant
///   local). Le message confirmé par le serveur remplace cette bulle sous
///   un autre identifiant : sans cette règle, chaque message envoyé
///   apparaîtrait deux fois.
class MessageAppear extends StatefulWidget {
  const MessageAppear({
    super.key,
    required this.messageId,
    required this.isMine,
    required this.isLast,
    required this.child,
  });

  final String messageId;
  final bool isMine;
  final bool isLast;
  final Widget child;

  /// Les bulles déjà montrées, pour toute l'application : une conversation
  /// rouverte ne rejoue rien. Vidé au-delà d'un plafond — au pire, une
  /// bulle ancienne redevenue « dernière » s'animerait une fois de trop.
  static final Set<String> _shown = {};
  static const _shownCap = 5000;

  @override
  State<MessageAppear> createState() => _MessageAppearState();
}

class _MessageAppearState extends State<MessageAppear>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final CurvedAnimation _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null ||
        MessageAppear._shown.contains(widget.messageId)) {
      return;
    }
    if (MessageAppear._shown.length > MessageAppear._shownCap) {
      MessageAppear._shown.clear();
    }
    MessageAppear._shown.add(widget.messageId);

    final routeSettled = ModalRoute.of(context)?.animation?.isCompleted ?? true;
    final arriving =
        widget.isLast &&
        routeSettled &&
        (!widget.isMine || PokouMessageStore.isLocalId(widget.messageId));
    if (!arriving) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    controller.forward();
  }

  @override
  void dispose() {
    if (_controller != null) _curve.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final curve = _curve;
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1).animate(curve),
        alignment: widget.isMine
            ? AlignmentDirectional.bottomEnd.resolve(Directionality.of(context))
            : AlignmentDirectional.bottomStart.resolve(
                Directionality.of(context),
              ),
        child: widget.child,
      ),
    );
  }
}
