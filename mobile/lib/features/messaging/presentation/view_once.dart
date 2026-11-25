import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/crypto/media_cipher.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/platform/secure_screen.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// La bulle d'une photo ou d'une vidéo à VUE UNIQUE, comme WhatsApp : une
/// pastille discrète — l'icône « 1 » et « Photo » / « Vidéo » — et JAMAIS
/// d'aperçu de l'image, ni chez l'expéditeur ni chez le destinataire.
///
/// Trois états :
///
/// - à ouvrir (destinataire) : toucher télécharge, marque la vue unique
///   OUVERTE sur l'appareil et au serveur, puis l'affiche dans une
///   visionneuse protégée des captures d'écran ;
/// - ouverte : « Ouvert », plus rien ne s'ouvre — y compris après un
///   redémarrage, l'état est écrit dans le cache local ;
/// - envoyée par moi : la même pastille, inerte (« Ouvert » quand le
///   destinataire l'a vue).
///
/// Aucun geste n'y propose transférer, enregistrer ou partager : la bulle
/// n'a pas de visionneuse ordinaire, et le menu d'appui long les retire
/// (voir conversation_screen.dart::_showMessageActions).
class ViewOnceBubble extends ConsumerStatefulWidget {
  const ViewOnceBubble({
    super.key,
    required this.media,
    required this.isVideo,
    required this.isMine,
    required this.opened,
    required this.onOpen,
    this.mediaKey,
  });

  final MediaMeta media;
  final MediaKey? mediaKey;
  final bool isVideo;
  final bool isMine;

  /// Déjà consommée : par moi (destinataire), ou par le destinataire (moi
  /// expéditeur, quand je le sais).
  final bool opened;

  /// Marque la vue unique ouverte, une fois pour toutes. `false` : elle
  /// l'était déjà (second appui, autre chemin) — on n'affiche rien.
  final Future<bool> Function() onOpen;

  @override
  ConsumerState<ViewOnceBubble> createState() => _ViewOnceBubbleState();
}

class _ViewOnceBubbleState extends ConsumerState<ViewOnceBubble> {
  bool _busy = false;

  /// Vrai dès le premier appui accepté : la bulle passe à « Ouvert » sans
  /// attendre que le parent relise l'état.
  bool _consumed = false;

  bool get _opened => widget.opened || _consumed;

  Future<void> _open() async {
    if (widget.isMine || _opened || _busy) return;
    setState(() => _busy = true);
    final repository = ref.read(mediaRepositoryProvider);
    final extension = mediaExtension(widget.media);
    final File file;
    try {
      // Le fichier d'abord : le serveur cesse de le servir dès qu'il apprend
      // l'ouverture. Le marquer ouvert avant de l'avoir laisserait une vue
      // unique consommée et jamais vue.
      file = await repository
          .resolveLocalFile(
            widget.media.id,
            extension: extension,
            mediaKey: widget.mediaKey,
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).msgFixViewOnceUnavailable)),
        );
      }
      return;
    }
    final accepted = await widget.onOpen();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _consumed = true;
    });
    try {
      if (accepted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ViewOnceViewer(file: file, isVideo: widget.isVideo),
          ),
        );
      }
    } finally {
      // Plus de copie en clair sur l'appareil une fois vue.
      unawaited(repository.oublier(widget.media.id, extension: extension));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final muted = AppColors.chatIconMuted;
    final active = !widget.isMine && !_opened;
    final label = _opened
        ? l.msgFixViewOnceOpened
        : (widget.isVideo ? l.msgFixViewOnceVideo : l.msgFixViewOncePhoto);
    return Semantics(
      button: active,
      label: '${l.msgFixViewOnceLabel}, $label',
      child: InkWell(
        key: const ValueKey('view-once-bubble'),
        onTap: active ? _open : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: _busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.chatActionGreen,
                      )
                    : _OneBadge(
                        color: _opened ? muted : AppColors.chatActionGreen,
                        dashed: _opened,
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: _opened ? muted : AppColors.chatTextReceived,
                  fontWeight: FontWeight.w600,
                  fontStyle: _opened ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le « 1 » cerclé de la vue unique ; en pointillés une fois ouverte.
class _OneBadge extends StatelessWidget {
  const _OneBadge({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(color: color, dashed: dashed),
    child: Center(
      child: Text(
        '1',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final rect = Offset.zero & size;
    final ring = rect.deflate(1.5);
    if (!dashed) {
      canvas.drawOval(ring, paint);
      return;
    }
    const segments = 12;
    const sweep = 3.14159265 * 2 / segments;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(ring, i * sweep, sweep * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.dashed != dashed;
}

/// La visionneuse d'une vue unique : plein écran, protégée des captures
/// (FLAG_SECURE sur Android, voir SecureScreen), et SANS aucune action —
/// ni répondre, ni transférer, ni enregistrer, ni partager, ni zoom de
/// confort qui inviterait à la garder ouverte.
class ViewOnceViewer extends StatefulWidget {
  const ViewOnceViewer({super.key, required this.file, required this.isVideo});

  final File file;
  final bool isVideo;

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    unawaited(SecureScreen.acquire());
    if (widget.isVideo) {
      final controller = VideoPlayerController.file(widget.file);
      _video = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller.play();
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    unawaited(SecureScreen.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          L.of(context).msgFixViewOnceLabel,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: widget.isVideo
            ? (video != null && video.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: video.value.aspectRatio,
                      child: VideoPlayer(video),
                    )
                  : const CircularProgressIndicator(color: Colors.white))
            : Image.file(
                widget.file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
      ),
    );
  }
}
