import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import 'status_controller.dart';

enum _Mode { choose, text, mediaPreview }

/// Écran de publication d'un statut — texte, ou photo/vidéo (galerie ou
/// caméra) avec légende optionnelle. Retourne `true` via `Navigator.pop`
/// quand la publication a réussi, pour que l'appelant rafraîchisse le feed.
class PostStatusScreen extends ConsumerStatefulWidget {
  const PostStatusScreen({super.key});

  @override
  ConsumerState<PostStatusScreen> createState() => _PostStatusScreenState();
}

class _PostStatusScreenState extends ConsumerState<PostStatusScreen> {
  _Mode _mode = _Mode.choose;
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
            maxDuration: const Duration(minutes: 1),
          )
        : await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    if (video) {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
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
      await ref.read(statusPostControllerProvider.notifier).postText(text);
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

  @override
  Widget build(BuildContext context) {
    final posting = ref.watch(statusPostControllerProvider);

    return Scaffold(
      backgroundColor: _mode == _Mode.text
          ? AppColors.accentPrimaryDark
          : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          L.of(context).statusNewTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: switch (_mode) {
        _Mode.choose => _buildChooser(),
        _Mode.text => _buildTextComposer(posting),
        _Mode.mediaPreview => _buildMediaPreview(posting),
      },
    );
  }

  Widget _buildChooser() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChoiceTile(
            icon: Icons.text_fields,
            label: L.of(context).statusText,
            onTap: () => setState(() => _mode = _Mode.text),
          ),
          const SizedBox(height: 16),
          _ChoiceTile(
            icon: Icons.photo,
            label: L.of(context).mediaPhoto,
            onTap: () => _chooseSource(video: false),
          ),
          const SizedBox(height: 16),
          _ChoiceTile(
            icon: Icons.videocam,
            label: L.of(context).mediaVideo,
            onTap: () => _chooseSource(video: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer(bool posting) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: _textController,
                autofocus: true,
                maxLines: null,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: L.of(context).statusTypeHint,
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: posting ? null : _publishText,
              child: posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(L.of(context).statusPublish),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(bool posting) {
    final file = _pickedFile;
    if (file == null) return const SizedBox.shrink();
    final previewController = _previewController;

    return Column(
      children: [
        Expanded(
          child:
              _pickedContentType == 'VIDEO' &&
                  previewController != null &&
                  previewController.value.isInitialized
              ? AspectRatio(
                  aspectRatio: previewController.value.aspectRatio,
                  child: VideoPlayer(previewController),
                )
              : Image.file(File(file.path), fit: BoxFit.contain),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: L.of(context).composerCaptionHint,
                    hintStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: posting ? null : _publishMedia,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimaryDark,
                  ),
                  child: posting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
