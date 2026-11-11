import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/status_model.dart';
import 'status_controller.dart';
import 'status_viewers_sheet.dart';
import '../../messaging/presentation/messaging_controller.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/status_halo.dart';
import '../data/status_text_style.dart';

/// Durée d'un statut texte ou photo.
const _kStoryDuration = Duration(seconds: 6);

/// Une vidéo défile pendant SA durée, plafonnée à ce que la publication
/// accepte. Elle était coupée à 6 s : une vidéo de 30 s ne montrait que son
/// début, et la barre de progression annonçait la fin d'un contenu qui
/// n'était pas fini.
const _kMaxVideoDuration = Duration(seconds: 60);

/// Visionneuse plein écran d'un auteur — défilement automatique entre ses
/// statuts, façon WhatsApp/Instagram stories. Marque chaque statut comme vu
/// dès qu'il s'affiche (sauf les siens, voir POST /status/{id}/view côté API).
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.item});

  final StatusFeedItem item;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _index = 0;
  bool _deleting = false;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kStoryDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _startCurrent();
  }

  @override
  void dispose() {
    _controller.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  /// STA-2 / STA-7 (MSG-15) : la réponse part EN PRIVÉ, dans la discussion
  /// à deux avec l'auteur — chiffrée comme tout message direct.
  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sendingReply) return;
    final l = L.of(context);
    setState(() => _sendingReply = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .send(
            recipientId: widget.item.userId,
            content: '${l.statusReplyQuote}\n$text',
          );
      if (!mounted) return;
      _reply.clear();
      _replyFocus.unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.statusReplySent)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.convAttachmentFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _sendingReply = false);
        _controller.forward();
      }
    }
  }

  void _startCurrent() {
    final current = widget.item.statuses[_index];
    _controller.duration = _kStoryDuration;
    // Une vidéo attend d'être chargée pour connaître sa durée : la barre
    // partirait sinon sur 6 s, puis sauterait au statut suivant.
    if (current.contentType == 'VIDEO' && current.media != null) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.forward(from: 0);
    }
    if (!current.viewedByMe) {
      ref.read(statusRepositoryProvider).markViewed(current.id);
    }
  }

  void _onVideoReady(String statusId, Duration? duration) {
    if (!mounted || widget.item.statuses[_index].id != statusId) return;
    var length = duration ?? _kStoryDuration;
    if (length <= Duration.zero) length = _kStoryDuration;
    if (length > _kMaxVideoDuration) length = _kMaxVideoDuration;
    _controller.duration = length;
    _controller.forward(from: 0);
  }

  Future<void> _deleteCurrent() async {
    final l = L.of(context);
    final status = widget.item.statuses[_index];
    _controller.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.statusDeleteTitle),
        content: Text(l.statusDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.semanticError,
            ),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) _controller.forward();
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(statusRepositoryProvider).delete(status.id);
      ref.invalidate(statusFeedProvider);
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.statusDeleteFailed)));
        _controller.forward();
      }
    }
  }

  void _next() {
    if (_index < widget.item.statuses.length - 1) {
      setState(() => _index++);
      _startCurrent();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
      _startCurrent();
    } else {
      _controller.forward(from: 0);
    }
  }

  Future<void> _boostCurrent() async {
    try {
      final result = await ref
          .read(statusRepositoryProvider)
          .boost(widget.item.statuses[_index].id);
      final url = result['payment_url'] as String?;
      if (url != null && url.isNotEmpty && mounted) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).statusBoostFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item.statuses[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _StoryContent(
                // Une clé par statut : sans elle, deux vidéos à la suite
                // partageaient le même lecteur, et la seconde montrait la
                // première.
                key: ValueKey(status.id),
                status: status,
                onVideoReady: (duration) => _onVideoReady(status.id, duration),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _previous,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _next,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  for (var i = 0; i < widget.item.statuses.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: i < _index
                                  ? 1
                                  : (i == _index ? _controller.value : 0),
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // « Vu par N » — seulement sur MES statuts : l'API réserve la
            // liste des spectateurs à l'auteur, et l'afficher ailleurs
            // n'aurait rien à montrer.
            if (widget.item.userId ==
                ref.watch(authControllerProvider).user?.id)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Center(
                  child: InkWell(
                    onTap: () {
                      // La progression continue pendant la feuille : on la
                      // met en pause, sinon le statut défile derrière elle.
                      _controller.stop();
                      StatusViewersSheet.show(
                        context,
                        statusId: status.id,
                        viewCount: status.viewCount,
                      ).whenComplete(() {
                        if (mounted) _controller.forward();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            L.of(context).statusSeenBy(status.viewCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.item.userId ==
                ref.watch(authControllerProvider).user?.id)
              Positioned(
                bottom: 70,
                left: 24,
                right: 24,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _boostCurrent,
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: Text(L.of(context).statusBoostAction),
                  ),
                ),
              ),
            // STA-2 : répondre à quelqu'un d'autre — pause pendant la saisie.
            if (widget.item.userId !=
                ref.watch(authControllerProvider).user?.id)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            focusNode: _replyFocus,
                            onTap: _controller.stop,
                            onSubmitted: (_) => _sendReply(),
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: L
                                  .of(context)
                                  .statusReplyHint(widget.item.displayName),
                              hintStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black54,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: L.of(context).actionSend,
                          onPressed: _sendingReply ? null : _sendReply,
                          icon: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      L.of(context).statusReplyPrivate,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  StatusHalo(
                    size: 42,
                    thickness: 3,
                    gap: 2,
                    onDark: true,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentPrimaryLight,
                      child: Text(
                        widget.item.displayName.isNotEmpty
                            ? widget.item.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.item.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.item.userId ==
                      ref.watch(authControllerProvider).user?.id)
                    IconButton(
                      icon: _deleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                      onPressed: _deleting ? null : _deleteCurrent,
                      tooltip: L.of(context).statusDeleteTitle,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),

                    tooltip: L.of(context).actionClose,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryContent extends ConsumerWidget {
  const _StoryContent({
    super.key,
    required this.status,
    required this.onVideoReady,
  });

  final PokouStatus status;

  /// La durée réelle de la vidéo, ou `null` si elle n'a pas pu être lue.
  final ValueChanged<Duration?> onVideoReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status.contentUnavailable) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.lock_outline, color: Colors.white70, size: 42),
        ),
      );
    }
    if (status.contentType == 'TEXT') {
      final text = status.textContent ?? '';
      return StatusTextCanvas(
        style: status.textStyle,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 96, 28, 120),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: status.textStyle.textStyle(text),
            ),
          ),
        ),
      );
    }

    final media = status.media;
    if (media == null) return const ColoredBox(color: Colors.black);

    if (status.contentType == 'VIDEO') {
      return _StoryVideo(media: media, onReady: onVideoReady);
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        const ColoredBox(color: Colors.black),
        // Plein écran : pas de `decodeWidth`, la définition est le sujet.
        Center(
          child: MediaImage.meta(
            media,
            fit: BoxFit.contain,
            placeholder: const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        ),
        if (status.textContent != null && status.textContent!.trim().isNotEmpty)
          _caption(status.textContent!),
      ],
    );
  }

  Widget _caption(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

class _StoryVideo extends ConsumerStatefulWidget {
  const _StoryVideo({required this.media, required this.onReady});

  final MediaMeta media;
  final ValueChanged<Duration?> onReady;

  @override
  ConsumerState<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends ConsumerState<_StoryVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final VideoPlayerController controller;
    try {
      final file = await ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(
            widget.media.id,
            extension: mediaExtension(widget.media),
          );
      controller = VideoPlayerController.file(file);
      await controller.initialize();
    } catch (_) {
      // Illisible ou réseau coupé : on défile quand même, sur la durée
      // d'un statut ordinaire, plutôt que de rester bloqué sur l'attente.
      if (mounted) {
        setState(() => _failed = true);
        widget.onReady(null);
      }
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    controller.play();
    widget.onReady(controller.value.duration);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            L.of(context).mediaVideoUnavailable,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
