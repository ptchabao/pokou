import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../theme/app_colors.dart';

/// Recadrage carré d'une image, avant de l'envoyer comme photo de profil ou
/// photo de groupe — un portrait pris en 4:3 est sinon rogné arbitrairement à
/// l'affichage, souvent en coupant le visage.
///
/// Écrit avec `dart:ui` seul, sans le paquet `image_cropper` : celui-ci
/// exigerait une activité Android déclarée et une configuration iOS, alors que
/// décoder, transformer et réencoder tient entièrement dans le framework.
///
/// Renvoie du PNG (encodage sans perte disponible dans `dart:ui`) ou `null` si
/// l'utilisateur annule.
Future<Uint8List?> cropSquareImage(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SquareCropScreen(bytes: bytes),
    ),
  );
}

class _SquareCropScreen extends StatefulWidget {
  const _SquareCropScreen({required this.bytes});

  final Uint8List bytes;

  @override
  State<_SquareCropScreen> createState() => _SquareCropScreenState();
}

class _SquareCropScreenState extends State<_SquareCropScreen> {
  final _controller = TransformationController();
  ui.Image? _image;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Rend la portion visible du cadre carré dans une image de sortie.
  ///
  /// La zone source se déduit de la matrice de l'InteractiveViewer : elle
  /// place l'image dans le cadre, donc son inverse dit quelle partie de
  /// l'image occupe le cadre. C'est plus fiable que de suivre à la main un
  /// décalage et une échelle, qui divergeraient du geste réel.
  Future<void> _confirm(double viewportSize) async {
    final image = _image;
    if (image == null || _cropping) return;
    setState(() => _cropping = true);

    // Échelle appliquée par BoxFit.cover à l'entrée du cadre.
    final coverScale = viewportSize / min(image.width, image.height);
    final matrix = Matrix4.inverted(_controller.value);
    // MatrixUtils : l'utilitaire du framework, plutôt qu'un import de
    // vector_math qui n'est qu'une dépendance transitive de Flutter.
    final topLeft = MatrixUtils.transformPoint(matrix, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(matrix, Offset(viewportSize, viewportSize));

    // Coordonnées ramenées à l'image d'origine, puis bornées : un geste peut
    // sortir légèrement du cadre, et découper hors limites donnerait des
    // bords transparents.
    final centeredOffsetX = (image.width * coverScale - viewportSize) / 2;
    final centeredOffsetY = (image.height * coverScale - viewportSize) / 2;
    final left = ((topLeft.dx + centeredOffsetX) / coverScale).clamp(0.0, image.width.toDouble());
    final top = ((topLeft.dy + centeredOffsetY) / coverScale).clamp(0.0, image.height.toDouble());
    final right = ((bottomRight.dx + centeredOffsetX) / coverScale).clamp(0.0, image.width.toDouble());
    final bottom = ((bottomRight.dy + centeredOffsetY) / coverScale).clamp(0.0, image.height.toDouble());

    final side = min(right - left, bottom - top);
    if (side <= 0) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Sortie bornée à 1024px : une photo de profil n'a pas besoin de plus, et
    // c'est autant de données en moins à envoyer.
    final outputSide = min(side, 1024.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(left, top, side, side),
      Rect.fromLTWH(0, 0, outputSide, outputSide),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outputSide.round(), outputSide.round());
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    cropped.dispose();

    if (!mounted) return;
    Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(L.of(context).cropTitle,
            style: const TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: image == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : LayoutBuilder(
              builder: (context, constraints) {
                // Cadre carré, marge de 24 de chaque côté.
                final viewportSize = min(constraints.maxWidth, constraints.maxHeight) - 48;
                return Column(
                  children: [
                    const Spacer(),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: viewportSize,
                          height: viewportSize,
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 1,
                            maxScale: 5,
                            // Sans marge de débordement, impossible d'amener
                            // un bord de l'image au centre du cadre.
                            boundaryMargin: EdgeInsets.all(viewportSize),
                            clipBehavior: Clip.none,
                            child: RawImage(image: image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      L.of(context).cropHint,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cropping ? null : () => _confirm(viewportSize),
                          style: ElevatedButton.styleFrom(
                            // Libellé blanc : l'encre foncée, pas le bleu d'action.
                            backgroundColor: AppColors.accentPrimaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _cropping
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(L.of(context).cropConfirm),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
