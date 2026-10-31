import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/theme/app_colors.dart';

/// Ce qu'on renvoie à l'écran de conversation : le fichier prêt, sa légende,
/// et s'il doit disparaître après avoir été ouvert.
typedef PreparedMedia = ({File file, String? caption, bool viewOnce});

/// Préparer une image avant de l'envoyer — l'étape qui manquait.
///
/// Choisir une photo l'envoyait AUSSITÔT. Pas d'aperçu, pas de recadrage,
/// pas de légende : une capture d'écran partait avec sa barre d'état, une
/// photo de produit avec la moitié de l'atelier autour, et il ne restait
/// qu'à supprimer et recommencer. C'est le geste le plus courant d'une
/// messagerie, et c'était celui qu'on ne pouvait pas rattraper.
///
/// Le rognage et la rotation passent par les éditeurs NATIFS (uCrop sur
/// Android, TOCropViewController sur iOS) plutôt que par une implémentation
/// maison : le geste est celui que l'utilisateur connaît déjà des autres
/// applications de son téléphone, et le redimensionnement est fait par la
/// plateforme — pas par du code Dart sur une image de douze mégapixels.
class MediaComposerScreen extends StatefulWidget {
  const MediaComposerScreen({
    super.key,
    required this.file,
    required this.recipientName,
  });

  final File file;

  /// Affiché sous le champ de légende — « à Awa ». On envoie une photo à
  /// QUELQU'UN, et cet écran arrive souvent après plusieurs manipulations
  /// dans la galerie, où il est facile d'avoir perdu le fil.
  final String recipientName;

  @override
  State<MediaComposerScreen> createState() => _MediaComposerScreenState();
}

class _MediaComposerScreenState extends State<MediaComposerScreen> {
  late File _file = widget.file;
  final _captionController = TextEditingController();
  bool _busy = false;

  /// La photo doit-elle disparaître après avoir été ouverte une fois ?
  bool _viewOnce = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Ouvre l'éditeur natif : recadrage, rotation, proportions libres.
  ///
  /// Le résultat REMPLACE le fichier courant, et l'aperçu se recharge
  /// dessus. Retour sans rien changer : `null`, et on garde l'original —
  /// annuler un recadrage ne doit jamais perdre la photo.
  Future<void> _edit() async {
    setState(() => _busy = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _file.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: L.of(context).composerEditPhoto,
            toolbarColor: AppColors.surface,
            toolbarWidgetColor: AppColors.textPrimary,
            activeControlsWidgetColor: AppColors.accentPrimaryDark,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: L.of(context).composerEditPhoto,
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _file = File(cropped.path));
        // Le cache de Flutter garde l'ancienne image sous le même chemin
        // quand l'éditeur réécrit par-dessus : sans ce vidage, l'aperçu
        // montre la version d'AVANT le recadrage, et on croit que rien ne
        // s'est passé.
        imageCache.clear();
        imageCache.clearLiveImages();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).composerEditorFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop<PreparedMedia>((
      file: _file,
      caption: caption.isEmpty ? null : caption,
      viewOnce: _viewOnce,
    ));
  }

  /// La vue unique se décide ICI, sur l'aperçu, et pas dans le menu des
  /// pièces jointes.
  ///
  /// C'est le moment où l'on voit ce qu'on s'apprête à envoyer : choisir
  /// « vue unique » avant même d'avoir pris la photo demanderait de le
  /// décider à l'aveugle, et de recommencer si on se trompe. Le réglage
  /// couvre du même coup la galerie et l'appareil photo, qui passent tous
  /// deux par cet écran.
  void _toggleViewOnce() {
    setState(() => _viewOnce = !_viewOnce);
    final l = L.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _viewOnce ? l.composerViewOnceOn : l.composerViewOnceOff,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fond sombre, comme tous les visualiseurs de médias : c'est ce qui
      // fait ressortir la photo au lieu de la noyer dans du blanc.
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),

                  tooltip: L.of(context).a11yBack,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.crop_rotate, color: Colors.white),
                  tooltip: L.of(context).composerCropRotate,
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : InteractiveViewer(
                        maxScale: 4,
                        child: Image.file(
                          _file,
                          key: ValueKey('${_file.path}-${_file.lengthSync()}'),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              color: Colors.black,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: L.of(context).composerCaptionHint,
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                          ),
                        ),
                        Text(
                          L.of(context).composerTo(widget.recipientName),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Le « 1 » entouré : le même signe que sur la bulle reçue,
                  // pour qu'on reconnaisse à l'envoi ce qu'on verra à la
                  // réception.
                  IconButton(
                    onPressed: _busy ? null : _toggleViewOnce,
                    tooltip: L.of(context).composerViewOnce,
                    icon: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _viewOnce
                            ? AppColors.accentPrimary
                            : Colors.transparent,
                        border: Border.all(
                          color: _viewOnce
                              ? AppColors.accentPrimary
                              : Colors.white70,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: _viewOnce ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _busy ? null : _send,
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    tooltip: L.of(context).composerSend,
                    child: const Icon(Icons.send),
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
