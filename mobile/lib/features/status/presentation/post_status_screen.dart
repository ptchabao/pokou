import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../data/status_text_style.dart';
import 'status_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

enum _Mode { text, mediaPreview }

/// Durée maximale d'un statut vidéo. Une demi-seconde de marge : la durée
/// lue dans le fichier d'un enregistrement « de 60 s » dépasse souvent de
/// quelques images.
const kStatusMaxVideoDuration = Duration(seconds: 60, milliseconds: 500);

/// Écran de publication d'un statut — texte, ou photo/vidéo (galerie ou
/// caméra) avec légende optionnelle. Retourne `true` via `Navigator.pop`
/// quand la publication a réussi, pour que l'appelant rafraîchisse le feed.
class PostStatusScreen extends ConsumerStatefulWidget {
  const PostStatusScreen({super.key});

  @override
  ConsumerState<PostStatusScreen> createState() => _PostStatusScreenState();
}

class _PostStatusScreenState extends ConsumerState<PostStatusScreen> {
  _Mode _mode = _Mode.text;
  StatusTextStyle _style = StatusTextStyle.plain;
  final _textController = TextEditingController();
  final _captionController = TextEditingController();

  XFile? _pickedFile;
  String? _pickedContentType; // IMAGE | VIDEO
  VideoPlayerController? _previewController;

  @override
  void dispose() {
    _textController.dispose();
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _chooseSource({required bool video}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).statusGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).statusCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickMedia(video: video, source: source);
  }

  Future<void> _pickMedia({
    required bool video,
    required ImageSource source,
  }) async {
    final picker = ImagePicker();
    final picked = video
        ? await picker.pickVideo(
            source: source,
            maxDuration: kStatusMaxVideoDuration,
          )
        : await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    if (video) {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      // `maxDuration` ne borne que l'ENREGISTREMENT par la caméra : une
      // vidéo choisie dans la galerie passait quelle que soit sa durée. Un
      // statut dure 60 secondes au plus — on le dit, et on ne publie pas.
      if (controller.value.duration > kStatusMaxVideoDuration) {
        await controller.dispose();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).statusVideoTooLong)),
        );
        return;
      }
      controller.setLooping(true);
      controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _previewController = controller);
    }

    setState(() {
      _pickedFile = picked;
      _pickedContentType = video ? 'VIDEO' : 'IMAGE';
      _mode = _Mode.mediaPreview;
    });
  }

  Future<void> _publishText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    try {
      await ref
          .read(statusPostControllerProvider.notifier)
          .postText(text, style: _style);
    } catch (_) {
      _showPublishFailed();
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// L'échec se DIT. Le bouton cessait de tourner et rien d'autre ne se
  /// passait : on ne savait ni si le statut était parti, ni s'il fallait
  /// réessayer. Le texte et le média restent en place pour un nouvel essai.
  void _showPublishFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).statusPublishFailed)));
  }

  Future<void> _publishMedia() async {
    final file = _pickedFile;
    final contentType = _pickedContentType;
    if (file == null || contentType == null) return;
    try {
      final bytes = await file.readAsBytes();
      await ref
          .read(statusPostControllerProvider.notifier)
          .postMedia(
            bytes: bytes,
            filename: file.name,
            mimeType:
                lookupMimeType(file.name) ??
                (contentType == 'VIDEO' ? 'video/mp4' : 'image/jpeg'),
            contentType: contentType,
            caption: _captionController.text,
          );
    } catch (_) {
      _showPublishFailed();
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  void _backToText() {
    _previewController?.dispose();
    setState(() {
      _previewController = null;
      _pickedFile = null;
      _pickedContentType = null;
      _mode = _Mode.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final posting = ref.watch(statusPostControllerProvider);
    final onMedia = _mode == _Mode.mediaPreview;
    // Les icônes de la barre du téléphone suivent le fond : sombres sur un
    // fond clair (or, crème), claires sinon.
    final lightInk = onMedia || _style.look.ink == Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightInk ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: onMedia
            ? _buildMediaPreview(posting)
            : _buildTextComposer(posting),
      ),
    );
  }

  Widget _buildTextComposer(bool posting) {
    final l = L.of(context);
    final ink = _style.look.ink;
    final text = _textController.text;
    final count = text.runes.length;
    return StatusTextCanvas(
      style: _style,
      child: SafeArea(
        child: Column(
          children: [
            // ── En haut : fermer, police, fond ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l.actionClose,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: ink),
                  ),
                  const Spacer(),
                  _GlassButton(
                    tooltip: l.statusChangeFont,
                    ink: ink,
                    onTap: () => setState(
                      () => _style = _style.copyWith(
                        font: (_style.font + 1) % statusFonts.length,
                      ),
                    ),
                    child: Text(
                      'Aa',
                      style: _style
                          .textStyle('Aa')
                          .copyWith(fontSize: 17, height: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GlassButton(
                    tooltip: l.statusChangeBackground,
                    ink: ink,
                    onTap: () => setState(
                      () => _style = _style.copyWith(
                        background:
                            (_style.background + 1) % statusBackgrounds.length,
                      ),
                    ),
                    child: Icon(Icons.palette_outlined, color: ink, size: 20),
                  ),
                ],
              ),
            ),
            // ── Le texte, au centre, à la taille qu'il aura une fois publié
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: TextField(
                    contextMenuBuilder: pokouContextMenuBuilder,
                    controller: _textController,
                    autofocus: true,
                    maxLines: null,
                    maxLength: 700,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: ink,
                    cursorWidth: 2.5,
                    onChanged: (_) => setState(() {}),
                    style: _style.textStyle(text),
                    decoration: InputDecoration(
                      hintText: l.statusTypeHint,
                      hintStyle: _style
                          .textStyle('')
                          .copyWith(color: ink.withValues(alpha: 0.55)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ),
            if (count > 560)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$count / 700',
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // ── Les fonds, d'un geste ──────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: statusBackgrounds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _Swatch(
                  background: statusBackgrounds[index],
                  selected: index == _style.background,
                  ring: ink,
                  label: l.statusBackgroundNumber('${index + 1}'),
                  onTap: () => setState(
                    () => _style = _style.copyWith(background: index),
                  ),
                ),
              ),
            ),
            // ── En bas : photo, vidéo, à qui, publier ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
              child: Row(
                children: [
                  _GlassButton(
                    tooltip: l.mediaPhoto,
                    ink: ink,
                    onTap: posting ? null : () => _chooseSource(video: false),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: ink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GlassButton(
                    tooltip: l.statusVideoLimitHint,
                    ink: ink,
                    onTap: posting ? null : () => _chooseSource(video: true),
                    child: Icon(Icons.videocam_outlined, color: ink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: ink.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.statusVisible24h,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.75),
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SendButton(
                    label: l.statusPublish,
                    busy: posting,
                    enabled: text.trim().isNotEmpty,
                    // Le bouton prend la couleur du TEXTE : il se détache
                    // de n'importe quel fond de la palette.
                    color: ink,
                    onColor: _style.look.bottom,
                    onTap: _publishText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(bool posting) {
    final l = L.of(context);
    final file = _pickedFile;
    if (file == null) return const SizedBox.shrink();
    final previewController = _previewController;
    final isVideo =
        _pickedContentType == 'VIDEO' &&
        previewController != null &&
        previewController.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: isVideo
              ? AspectRatio(
                  aspectRatio: previewController.value.aspectRatio,
                  child: VideoPlayer(previewController),
                )
              : Image.file(File(file.path), fit: BoxFit.contain),
        ),
        // Un voile en haut et en bas : les commandes restent lisibles sur
        // une photo claire.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
                stops: [0, 0.18, 0.68, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: IconButton(
                    tooltip: l.actionClose,
                    onPressed: posting ? null : _backToText,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: TextField(
                          contextMenuBuilder: pokouContextMenuBuilder,
                          controller: _captionController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 700,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: l.composerCaptionHint,
                            hintStyle: const TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SendButton(
                      label: l.statusPublish,
                      busy: posting,
                      enabled: true,
                      color: Colors.white,
                      onColor: AppColors.accentPrimary,
                      onTap: _publishMedia,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un bouton rond translucide, lisible sur tous les fonds de la palette.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.tooltip,
    required this.ink,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final Color ink;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: ink.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: ExcludeSemantics(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.background,
    required this.selected,
    required this.ring,
    required this.label,
    required this.onTap,
  });

  final StatusBackground background;
  final bool selected;
  final Color ring;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          padding: EdgeInsets.all(selected ? 3 : 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ring : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: background.gradient,
              border: Border.all(color: ring.withValues(alpha: 0.35)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !busy;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: active,
        label: label,
        child: Material(
          color: enabled ? color : color.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onTap : null,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: onColor,
                        ),
                      )
                    : ExcludeSemantics(
                        child: Icon(Icons.send_rounded, color: onColor),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
