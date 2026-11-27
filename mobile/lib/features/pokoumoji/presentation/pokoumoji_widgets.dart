import 'dart:io';

import 'package:flutter/material.dart';

import '../data/pokoumoji_runtime.dart';
import '../domain/pokoumoji.dart';

/// Un Pokoumoji à l'écran : l'image vérifiée du pack, sinon son fallback.
///
/// Le fallback n'est pas un état d'erreur : c'est ce que le contrat
/// prévoit tant que le fichier n'est pas là (téléchargement, hors ligne,
/// fichier refusé, entrée non approuvée). Il prend la même place que
/// l'image, pour que la ligne ne saute pas à l'arrivée du fichier.
class PokoumojiGlyph extends StatefulWidget {
  const PokoumojiGlyph({
    super.key,
    required this.entry,
    required this.size,
    this.context = PokoumojiSizeContext.inline,
    this.fallback,
  });

  final PokoumojiEntry entry;
  final double size;
  final PokoumojiSizeContext context;

  /// Le fallback porté par le message (sinon celui du catalogue).
  final String? fallback;

  @override
  State<PokoumojiGlyph> createState() => _PokoumojiGlyphState();
}

class _PokoumojiGlyphState extends State<PokoumojiGlyph> {
  Future<File?>? _file;
  int? _px;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PokoumojiGlyph old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id || old.context != widget.context) {
      _px = null;
      _resolve();
    }
  }

  void _resolve() {
    final rt = PokoumojiRuntime.instance;
    final px = pokoumojiPickSize(
      widget.context,
      MediaQuery.devicePixelRatioOf(context),
    );
    if (px == _px && _file != null) return;
    _px = px;
    _file =
        rt.hasAsset(widget.entry) &&
            (rt.catalogue.value?.isVisible(widget.entry) ?? false)
        ? rt.fileFor(widget.entry, px)
        : Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.fallback ?? widget.entry.fallback;
    return Semantics(
      label: widget.entry.labelFr,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<File?>(
          future: _file,
          builder: (context, snap) {
            final f = snap.data;
            if (f != null) {
              return Image.file(
                f,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              );
            }
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  fb,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: widget.size * 0.62, height: 1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Le contenu d'un message Pokoumoji dans une bulle.
///
/// * sticker → l'image en grand, sans cadre ;
/// * 1 à 3 emojis seuls → en grand (64–96 dp), comme un emoji seul ;
/// * sinon → le texte avec les emojis en ligne (24–32 dp).
///
/// Un identifiant inconnu, non approuvé ou sans fichier s'affiche par son
/// fallback, en texte échappé — jamais d'erreur (§3, T10).
class PokoumojiMessageView extends StatelessWidget {
  const PokoumojiMessageView({
    super.key,
    required this.message,
    required this.style,
  });

  final Map<String, dynamic> message;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final rt = PokoumojiRuntime.instance;
    return ValueListenableBuilder(
      valueListenable: rt.manifest,
      builder: (context, _, _) {
        final catalogue = rt.catalogue.value;
        if (catalogue == null) {
          return Text(pokoumojiPlainText(message), style: style);
        }
        final plan = pokoumojiRenderPlan(
          message,
          catalogue,
          hasAsset: rt.hasAsset,
        );
        if (message['type'] == 'sticker') {
          final piece = plan.firstOrNull;
          if (piece is PokoumojiImagePiece) {
            return PokoumojiGlyph(
              entry: piece.entry,
              fallback: piece.fallback,
              size: 150,
              context: PokoumojiSizeContext.single,
            );
          }
          return Text(pokoumojiPlainText(message), style: style);
        }
        final images = plan.whereType<PokoumojiImagePiece>().length;
        final onlyEmoji =
            images > 0 &&
            images <= 3 &&
            plan.every(
              (p) =>
                  p is PokoumojiImagePiece ||
                  (p is PokoumojiTextPiece && p.text.trim().isEmpty),
            );
        final size = onlyEmoji
            ? (images == 1 ? 88.0 : 64.0)
            : (style.fontSize ?? 15) * 1.6;
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              for (final p in plan)
                switch (p) {
                  PokoumojiTextPiece(:final text) => TextSpan(text: text),
                  PokoumojiFallbackPiece(:final text) => TextSpan(text: text),
                  PokoumojiImagePiece(:final entry, :final fallback) =>
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: PokoumojiGlyph(
                          entry: entry,
                          fallback: fallback,
                          size: size,
                          context: onlyEmoji
                              ? PokoumojiSizeContext.single
                              : PokoumojiSizeContext.inline,
                        ),
                      ),
                    ),
                },
            ],
          ),
        );
      },
    );
  }
}
