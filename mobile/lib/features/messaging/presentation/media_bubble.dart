import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'composer/waveform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../../core/crypto/media_cipher.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/image_viewer.dart';

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

/// Verrou "vue unique" façon WhatsApp, posé devant une IMAGE/VIDEO dont
/// `message.viewOnce` est vrai. Trois états : jamais ouvert (icône "1", tap
/// pour révéler), déjà consulté (grisé, plus jamais le contenu), ou envoyé
/// par MOI (toujours visible — je n'ai rien à "consommer" chez mon propre
/// envoi, seul le destinataire passe par la révélation).
///
/// La révélation reste locale au widget une fois déclenchée : `viewed`
/// passera à vrai après confirmation serveur (voir
/// conversation_screen.dart::_markViewOnceViewed), mais ce média doit rester
/// affiché pour CETTE session d'écran — seule une réouverture ultérieure de
/// la conversation doit retomber sur l'état grisé "consultée".
class ViewOnceGate extends StatefulWidget {
  const ViewOnceGate({
    super.key,
    required this.viewed,
    required this.isMine,
    required this.onReveal,
    required this.builder,
  });

  final bool viewed;
  final bool isMine;
  final VoidCallback onReveal;
  final WidgetBuilder builder;

  @override
  State<ViewOnceGate> createState() => _ViewOnceGateState();
}

class _ViewOnceGateState extends State<ViewOnceGate> {
  bool _revealedLocally = false;

  void _reveal() {
    if (_revealedLocally) return;
    setState(() => _revealedLocally = true);
    widget.onReveal();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMine || _revealedLocally) return widget.builder(context);

    if (widget.viewed) {
      return Container(
        width: 200,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.chatBubbleReceived,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.chatIconMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              L.of(context).viewOnceSeen,
              style: const TextStyle(
                color: AppColors.chatIconMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _reveal,
      child: Container(
        width: 200,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L.of(context).viewOnceTapToSee,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Note vocale — lecture via just_audio, source mise en cache localement par
/// MediaRepository (l'API exige un Bearer token, donc pas d'URL directe).
AudioPlayer? _activeAudioPlayer;

class AudioMessageBubble extends ConsumerStatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.media,
    required this.isMine,
    this.mediaKey,
  });

  final MediaMeta media;
  final bool isMine;

  /// La clé de la note chiffrée, portée par le message. Sans elle, c'est le
  /// CHIFFRÉ qui partait au lecteur : la note tournait dans le vide.
  final MediaKey? mediaKey;

  @override
  ConsumerState<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends ConsumerState<AudioMessageBubble> {
  final _player = AudioPlayer();
  bool _loading = false;
  String? _error;

  /// La silhouette de cette note, faute d'avoir mesuré son niveau réel.
  ///
  /// Calculée UNE fois à partir de l'identifiant du média : une forme
  /// tirée au sort à chaque reconstruction donnerait l'impression que
  /// l'audio change tout seul pendant qu'on l'écoute.
  late final List<double> _silhouette = silhouetteFor(
    'audio-${widget.media.id}',
  );

  /// Le téléchargement de la note — lancé DÈS l'affichage, comme WhatsApp,
  /// pour que la lecture parte aussitôt qu'on touche « lecture ».
  Future<File>? _download;

  Future<File> _fetch() => _download ??= ref
      .read(mediaRepositoryProvider)
      .resolveLocalFile(
        widget.media.id,
        extension: mediaExtension(widget.media),
        mediaKey: widget.mediaKey,
      )
      .timeout(const Duration(seconds: 45))
      .catchError((Object e) {
        _download = null; // un nouvel appui relance
        throw e;
      });

  @override
  void initState() {
    super.initState();
    // Préchargement silencieux : une note vocale pèse peu.
    unawaited(_fetch().then((_) {}, onError: (_) {}));
  }

  @override
  void dispose() {
    if (identical(_activeAudioPlayer, _player)) _activeAudioPlayer = null;
    _player.dispose();
    super.dispose();
  }

  /// Démarre la lecture SANS l'attendre.
  ///
  /// `play()` de just_audio ne rend la main qu'à la FIN du son, pas à son
  /// début. L'attendre gardait l'indicateur de chargement affiché pendant
  /// toute l'écoute : on voyait tourner un rond là où le bouton pause
  /// devait être, et il n'y avait aucun moyen d'arrêter la lecture.
  void _startPlayback() {
    _activeAudioPlayer?.pause();
    _activeAudioPlayer = _player;
    unawaited(_player.play());
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.ready ||
        _player.processingState == ProcessingState.completed) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _startPlayback();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await _fetch();
      await _player
          .setFilePath(file.path)
          .timeout(const Duration(seconds: 15));
      _startPlayback();
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).audioPlayFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final completed =
            snapshot.data?.processingState == ProcessingState.completed;
        return Row(
          mainAxisSize: MainAxisSize.min,
          // Le bouton se centre sur la hauteur de la colonne d'à côté
          // (onde + durée). Sans cela il s'alignait en haut, et la bulle
          // paraissait de travers.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: _loading ? null : _togglePlay,
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.chatActionGreen,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        playing && !completed ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, durationSnapshot) {
                final total = durationSnapshot.data ?? _player.duration;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final hasDuration = total != null && total > Duration.zero;
                    final safePosition = hasDuration && position > total
                        ? total
                        : position;
                    final progress = hasDuration
                        ? safePosition.inMilliseconds / total.inMilliseconds
                        : 0.0;
                    return SizedBox(
                      width: 170,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Une forme d'onde plutôt qu'un curseur : elle dit
                          // d'un coup d'œil où en est la lecture ET ce qui
                          // reste à écouter. Un `Slider` ne montre que la
                          // position, et ressemble à un réglage plus qu'à
                          // un message.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: hasDuration
                                ? (details) {
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    if (box == null) return;
                                    final ratio =
                                        (details.localPosition.dx /
                                                box.size.width)
                                            .clamp(0.0, 1.0);
                                    _player.seek(total * ratio);
                                  }
                                : null,
                            child: Waveform(
                              levels: _silhouette,
                              progress: progress,
                              playedColor: AppColors.chatActionGreen,
                              remainingColor: AppColors.chatIconMuted,
                              height: 26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // La durée RESTANTE pendant la lecture, la durée
                            // totale à l'arrêt : c'est l'information utile à
                            // chaque moment, et c'est ce que fait WhatsApp.
                            hasDuration
                                ? (playing
                                      ? _fmt(total - safePosition)
                                      : _fmt(total))
                                : (_error ?? L.of(context).mediaVoiceNote),
                            style: TextStyle(
                              color: AppColors.chatTextReceived,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Image — miniature dans la bulle, plein écran au tap.
///
/// C'est la seule pièce jointe qui se télécharge d'elle-même (les notes
/// vocales et les vidéos attendent déjà un tap), donc la seule concernée par
/// le mode économie de données : voir _startIfAllowed.
class ImageMessageBubble extends ConsumerStatefulWidget {
  const ImageMessageBubble({super.key, required this.media});

  final MediaMeta media;

  @override
  ConsumerState<ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends ConsumerState<ImageMessageBubble> {
  Future<File>? _download;
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _cachedFile = _fichierLocal();
    if (_cachedFile == null) {
      _startIfAllowed();
    }
  }

  @override
  void didUpdateWidget(ImageMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _cachedFile = _fichierLocal();
      _download = null;
      if (_cachedFile == null) {
        _startIfAllowed();
      }
    }
  }

  File? _fichierLocal() {
    return ref.read(mediaRepositoryProvider).fichierEnCache(
      widget.media.id,
      extension: mediaExtension(widget.media),
    );
  }

  Future<File> _resolve() => ref
      .read(mediaRepositoryProvider)
      .resolveLocalFile(
        widget.media.id,
        extension: mediaExtension(widget.media),
      );

  /// En économie de données, une photo pas encore sur l'appareil attend un
  /// geste explicite. Une photo DÉJÀ en cache s'affiche directement : il n'y
  /// a rien à télécharger, donc rien à économiser — sinon le mode
  /// transformerait tout l'historique déjà téléchargé en vignettes grises.
  Future<void> _startIfAllowed() async {
    final cached = _fichierLocal();
    if (cached != null) {
      setState(() => _cachedFile = cached);
      return;
    }

    // REG-2 : selon le réseau et le type de média.
    final onWifi = ref.read(onWifiProvider).valueOrNull ?? false;
    if (ref
        .read(appSettingsProvider)
        .autoDownloads(mimeType: widget.media.mimeType, onWifi: onWifi)) {
      final fut = _resolve();
      fut.then((f) {
        if (mounted) setState(() => _cachedFile = f);
      });
      setState(() {
        _download = fut;
      });
      return;
    }

    final isCachedOnDisk = await ref
        .read(mediaRepositoryProvider)
        .isCached(widget.media.id, extension: mediaExtension(widget.media));
    if (isCachedOnDisk && mounted) {
      final fut = _resolve();
      fut.then((f) {
        if (mounted) setState(() => _cachedFile = f);
      });
      setState(() {
        _download = fut;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _cachedFile ?? _fichierLocal();
    if (file != null) return _thumbnail(file);

    final download = _download;
    if (download == null) {
      return _Placeholder(
        media: widget.media,
        onTap: () => setState(() {
          final fut = _resolve();
          fut.then((f) {
            if (mounted) setState(() => _cachedFile = f);
          });
          _download = fut;
        }),
      );
    }

    return FutureBuilder<File>(
      future: download,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 220,
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.chatBubbleReceived,
              borderRadius: BorderRadius.circular(14),
            ),
            child: snapshot.hasError
                ? const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.chatIconMuted,
                    size: 32,
                  )
                : const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.chatActionGreen,
                    ),
                  ),
          );
        }
        return _thumbnail(snapshot.data!);
      },
    );
  }

  /// Le `Hero` de CETTE bulle. Un objet propre à l'état, et non l'identifiant
  /// du média : une même photo transférée deux fois apparaît dans deux
  /// bulles de la même conversation, et deux `Hero` de même étiquette sur un
  /// écran font échouer l'animation.
  final Object _heroTag = Object();

  /// La bulle fait 220 points : on décode à cette taille, et non en pleine
  /// définition. Un fil de dix photos d'appareil photo saturait autrement le
  /// cache d'images de Flutter — il les expulsait puis les redécodait au
  /// moindre défilement.
  int _thumbnailCacheWidth(BuildContext context) =>
      (220 * MediaQuery.devicePixelRatioOf(context)).round();

  Widget _thumbnail(File file) {
    return GestureDetector(
      onTap: () => ImageViewer.open(
        context,
        images: [
          ViewerImage(
            full: Image.file(file, fit: BoxFit.contain, gaplessPlayback: true),
            // La vignette déjà décodée, en attendant la pleine définition :
            // même fichier, même largeur, donc servie par le cache.
            preview: Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: _thumbnailCacheWidth(context),
            ),
            heroTag: _heroTag,
          ),
        ],
      ),
      child: Hero(
        tag: _heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            width: 220,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: _thumbnailCacheWidth(context),
          ),
        ),
      ),
    );
  }
}

/// Vignette « économie de données » — annonce le poids avant de le dépenser.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.media, required this.onTap});

  final MediaMeta media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.chatBubbleReceived,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_outlined,
              color: AppColors.chatIconMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              L.of(context).mediaPhotoSize(formatFileSize(media.sizeBytes)),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.chatTextReceived,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              L.of(context).mediaTapToDownload,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.chatIconMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vidéo — lecture inline avec contrôles minimaux.
class VideoMessageBubble extends ConsumerStatefulWidget {
  const VideoMessageBubble({super.key, required this.media});

  final MediaMeta media;

  @override
  ConsumerState<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends ConsumerState<VideoMessageBubble> {
  VideoPlayerController? _controller;
  File? _file;
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    if (_controller != null || _loading) return;
    setState(() => _loading = true);
    try {
      final file = await ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(
            widget.media.id,
            extension: mediaExtension(widget.media),
          );
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _file = file;
      });
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).mediaVideoUnavailable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFullscreen() {
    final file = _file;
    if (file == null) return;
    _controller?.pause();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _FullScreenVideo(file: file)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return GestureDetector(
        onTap: _load,
        child: Container(
          width: 220,
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _loading
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : Icon(
                  _error != null ? Icons.error_outline : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 42,
                ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 220,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              InkWell(
                onTap: () => setState(
                  () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                ),
                child: AnimatedOpacity(
                  opacity: controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openFullscreen,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  colors: const VideoProgressColors(
                    playedColor: AppColors.chatActionGreen,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
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

/// Vidéo plein écran — mêmes contrôles que la bulle (lecture/pause au tap,
/// scrubber), ouverte depuis l'icône plein écran de VideoMessageBubble.
class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({required this.file});

  final File file;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    InkWell(
                      onTap: () => setState(
                        () => _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                      ),
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.all(12),
                        colors: const VideoProgressColors(
                          playedColor: AppColors.chatActionGreen,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

/// Document — icône + nom + taille, ouverture avec l'app native associée.
class DocumentMessageBubble extends ConsumerStatefulWidget {
  const DocumentMessageBubble({
    super.key,
    required this.media,
    required this.isMine,
  });

  final MediaMeta media;
  final bool isMine;

  @override
  ConsumerState<DocumentMessageBubble> createState() =>
      _DocumentMessageBubbleState();
}

class _DocumentMessageBubbleState extends ConsumerState<DocumentMessageBubble> {
  bool _opening = false;
  bool _error = false;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = false;
    });
    try {
      final file = await ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(
            widget.media.id,
            extension: mediaExtension(widget.media),
          );
      await OpenFilex.open(file.path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).mediaOpenDocFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.media.originalFilename ?? L.of(context).mediaDocument;
    return InkWell(
      onTap: _opening ? null : _open,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _error
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.chatActionGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _opening
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _error ? Icons.error_outline : Icons.insert_drive_file,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.chatTextReceived,
                  ),
                ),
                Text(
                  _error
                      ? L.of(context).mediaOpenRetry
                      : formatFileSize(widget.media.sizeBytes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _error
                        ? AppColors.chatActionGreen
                        : AppColors.chatIconMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
