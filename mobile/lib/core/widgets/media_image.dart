import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_repository.dart';
import '../providers.dart';
import '../theme/app_colors.dart';

/// Une image de média Pokou — vignette de produit, photo de profil, pièce
/// jointe, couverture de salon.
///
/// ── Pourquoi un widget, et pas un `FutureBuilder` de plus ──────────────
///
/// Le même bloc était recopié treize fois dans l'application :
///
/// ```dart
/// FutureBuilder<File>(
///   future: ref.read(mediaRepositoryProvider).resolveLocalFile(id, …),
///   builder: (context, snapshot) => snapshot.hasData
///       ? Image.file(snapshot.data!, fit: BoxFit.cover)
///       : const CircularProgressIndicator(),
/// )
/// ```
///
/// Il a trois défauts, et les treize copies les avaient tous les trois :
///
/// 1. **Le `Future` naît dans le `build`.** Chaque reconstruction en crée un
///    nouveau, donc chaque image de défilement relançait la résolution et
///    repassait par l'indicateur de chargement. Les vignettes clignotaient.
/// 2. **L'image est décodée en pleine résolution.** Une photo de 3 000
///    points affichée sur une vignette de 76 occupe 36 Mo en mémoire vive
///    au lieu de 23 Ko. Le cache d'images de Flutter tient 100 Mo : trois
///    photos suffisaient à en expulser tout le reste, qu'il fallait ensuite
///    redécoder. C'est ce qui donnait l'impression que « tout se recharge ».
/// 3. **Aucune n'avait de cas d'erreur.** Un fichier effacé par le système
///    sous le répertoire temporaire laissait une exception à l'écran.
///
/// Ici : le fichier déjà connu est lu SANS `Future` (voir
/// `MediaRepository.fichierEnCache`), donc la première image de rendu porte
/// déjà la photo ; [decodeWidth] borne la taille décodée ; et un fichier
/// disparu est oublié puis redemandé une fois.
class MediaImage extends ConsumerStatefulWidget {
  const MediaImage({
    super.key,
    required this.mediaId,
    this.extension = '',
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.placeholder,
    this.error,
    this.semanticLabel,
  });

  /// Construit à partir d'un [MediaMeta], qui porte déjà l'extension.
  MediaImage.meta(
    MediaMeta media, {
    super.key,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.placeholder,
    this.error,
    this.semanticLabel,
  }) : mediaId = media.id,
       extension = mediaExtension(media);

  final int mediaId;
  final String extension;
  final BoxFit fit;

  /// Largeur d'AFFICHAGE en points logiques, quand elle est connue.
  ///
  /// L'image est alors décodée à cette taille (multipliée par la densité de
  /// l'écran) plutôt qu'en pleine résolution. À renseigner dès qu'on affiche
  /// une vignette ; à laisser nul pour une visionneuse plein écran, où la
  /// définition est le sujet.
  final double? decodeWidth;

  final Widget? placeholder;
  final Widget? error;
  final String? semanticLabel;

  @override
  ConsumerState<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends ConsumerState<MediaImage> {
  File? _fichier;
  Object? _erreur;

  /// Vrai tant qu'on n'a pas encore retenté après un fichier disparu. Une
  /// seule reprise : si la seconde échoue aussi, le média n'est pas
  /// récupérable et insister ferait boucler le téléchargement.
  bool _reprisePossible = true;

  /// Le premier chargement part de `didChangeDependencies`, et non
  /// d'`initState` : la largeur de vignette à demander dépend de la densité
  /// de l'écran, que `MediaQuery` ne connaît pas encore au moment
  /// d'`initState`.
  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_demarre) {
      _demarre = true;
      _charger();
    }
  }

  @override
  void didUpdateWidget(MediaImage ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.mediaId != widget.mediaId ||
        ancien.extension != widget.extension) {
      _fichier = null;
      _erreur = null;
      _reprisePossible = true;
      _charger();
    }
  }

  /// La largeur de vignette à réclamer au serveur, ou `null` pour
  /// l'original.
  ///
  /// Dépend de la densité de l'écran, donc ne peut pas être calculée dans
  /// `initState` — `MediaQuery` n'y est pas encore disponible.
  int? _largeur(BuildContext context) {
    final voulue = widget.decodeWidth;
    if (voulue == null) return null;
    return MediaRepository.vignettePour(
      voulue,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  void _charger() {
    final depot = ref.read(mediaRepositoryProvider);
    final largeur = _largeur(context);
    // Le chemin synchrone : le fichier a déjà été résolu dans cette session,
    // donc la première image de rendu porte la photo. Pas de `setState`, pas
    // d'indicateur, pas de clignotement.
    final deja = depot.fichierEnCache(
      widget.mediaId,
      extension: widget.extension,
      largeur: largeur,
    );
    if (deja != null) {
      _fichier = deja;
      return;
    }
    depot
        .resolveLocalFile(
          widget.mediaId,
          extension: widget.extension,
          largeur: largeur,
        )
        .then((fichier) {
          if (mounted) setState(() => _fichier = fichier);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _erreur = e);
        });
  }

  /// Le fichier annoncé par le cache n'est plus lisible — le système a vidé
  /// le répertoire temporaire entre-temps. On l'oublie et on redemande.
  void _fichierIllisible() {
    if (!_reprisePossible) {
      if (mounted) setState(() => _erreur = 'illisible');
      return;
    }
    _reprisePossible = false;
    if (mounted) setState(() => _fichier = null);
    // L'effacement est asynchrone : recharger AVANT l'aurait fait retrouver
    // le fichier cassé encore sur le disque.
    ref
        .read(mediaRepositoryProvider)
        .oublier(
          widget.mediaId,
          extension: widget.extension,
          largeur: _largeur(context),
        )
        .then((_) {
          if (mounted) _charger();
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return widget.error ?? const _Fond(icone: Icons.broken_image_outlined);
    }
    final fichier = _fichier;
    if (fichier == null) {
      return widget.placeholder ?? const _Fond(chargement: true);
    }
    final densite = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      fichier,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      // Garde l'image précédente à l'écran pendant qu'une nouvelle se
      // décode, au lieu de laisser un trou blanc.
      gaplessPlayback: true,
      cacheWidth: widget.decodeWidth == null
          ? null
          : (widget.decodeWidth! * densite).round(),
      errorBuilder: (context, _, _) {
        // Reporté après l'image de rendu en cours : `errorBuilder` s'exécute
        // pendant le `build`, où `setState` est interdit.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fichierIllisible(),
        );
        return widget.placeholder ?? const _Fond(chargement: true);
      },
    );
  }
}

class _Fond extends StatelessWidget {
  const _Fond({this.icone, this.chargement = false});

  final IconData? icone;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceElevated,
      child: Center(
        child: chargement
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icone, size: 22, color: AppColors.textMuted),
      ),
    );
  }
}
