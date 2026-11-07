import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_repository.dart';
import '../providers.dart';
import '../theme/app_colors.dart';

/// Avatar d'un contact — affiche sa photo de profil si elle existe, sinon
/// retombe sur un cercle avec son initiale (même comportement que
/// ProfileScreen/ContactProfileScreen, factorisé ici pour les listes/appels
/// où le même besoin se répète : contacts, journal d'appels, en-tête de
/// conversation, écran d'appel entrant).
///
/// StatefulWidget plutôt que Consumer+FutureBuilder à la volée : la liste de
/// contacts se reconstruit souvent (recherche tapée, tirer-pour-rafraîchir,
/// tout `setState` du parent) et un `FutureBuilder` dont le `future:` est
/// recréé à chaque `build()` repart de zéro à chaque fois — la photo
/// n'apparaissait donc jamais, coincée en boucle sur le repli à l'initiale.
/// Ici le fichier est résolu une seule fois et mis en cache dans le State.
class ContactAvatar extends ConsumerStatefulWidget {
  ContactAvatar({
    super.key,
    required this.avatar,
    required this.displayName,
    this.size = 44,
    this.fallbackBackgroundColor,
    this.fallbackIcon,
  });

  final MediaMeta? avatar;
  final String displayName;
  final double size;

  /// Nullable, et non une valeur par défaut : un paramètre optionnel exige
  /// une CONSTANTE, ce que les jetons de couleur ne sont plus depuis qu'ils
  /// suivent le thème. Résolu à la construction, donc au bon moment.
  final Color? fallbackBackgroundColor;

  /// Ce qu'on met à la place de l'initiale quand il n'y a pas d'image.
  ///
  /// Une initiale désigne quelqu'un ; elle ne convient pas à tout. Une
  /// chaîne n'est pas une personne, et son « C » ne dit rien — alors qu'un
  /// porte-voix dit immédiatement de quoi il s'agit, y compris dans une
  /// liste où voisinent des contacts et des chaînes.
  final IconData? fallbackIcon;

  @override
  ConsumerState<ContactAvatar> createState() => _ContactAvatarState();
}

class _ContactAvatarState extends ConsumerState<ContactAvatar> {
  File? _file;

  @override
  void initState() {
    super.initState();
  }

  /// Le chargement part d'ici, et non d'`initState` : la largeur de vignette
  /// à demander dépend de la densité de l'écran, que `MediaQuery` ne connaît
  /// pas encore au moment d'`initState`.
  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_demarre) {
      _demarre = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(ContactAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar?.id != widget.avatar?.id) {
      _file = null;
      _load();
    }
  }

  /// La largeur de vignette pour cette pastille.
  ///
  /// Un avatar fait 40 points de côté dans une liste. Le serveur envoyait
  /// pourtant la photo d'origine — plusieurs méga-octets sortis d'un
  /// appareil photo — et l'application la décodait en pleine définition :
  /// une liste de cinquante contacts téléchargeait des dizaines de
  /// méga-octets et saturait le cache d'images de Flutter pour afficher
  /// l'équivalent de quelques dizaines de kilo-octets.
  int? get _largeurVignette => MediaRepository.vignettePour(
    widget.size,
    MediaQuery.devicePixelRatioOf(context),
  );

  Future<void> _load() async {
    final media = widget.avatar;
    if (media == null) return;
    try {
      final file = await ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(
            media.id,
            extension: mediaExtension(media),
            largeur: _largeurVignette,
          );
      if (mounted) setState(() => _file = file);
    } catch (_) {
      // Best-effort — reste sur le repli à l'initiale (_file == null).
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) return _initial();
    return ClipOval(
      child: Image.file(
        file,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        // Borne la taille DÉCODÉE : sans elle, une photo de 3 000 points
        // occupe 36 Mo de mémoire vive pour une pastille de 40.
        cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
            .round(),
        errorBuilder: (context, error, stackTrace) => _initial(),
      ),
    );
  }

  Widget _initial() {
    final icon = widget.fallbackIcon;
    if (icon != null) {
      return CircleAvatar(
        radius: widget.size / 2,
        backgroundColor:
            widget.fallbackBackgroundColor ?? AppColors.accentPrimaryLight,
        child: Icon(icon, color: Colors.white, size: widget.size * 0.5),
      );
    }
    // Terre de Confiance : monogramme de deux lettres, terre cuite foncée
    // sur beige — jamais une silhouette anonyme.
    final custom = widget.fallbackBackgroundColor;
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: custom ?? AppColors.surfaceElevated,
      child: Text(
        monogramOf(widget.displayName),
        style: TextStyle(
          color: custom != null ? Colors.white : AppColors.accentPrimaryDark,
          fontWeight: FontWeight.w600,
          fontSize: widget.size * 0.36,
        ),
      ),
    );
  }
}

/// « Famille Koffi » → « FK », « Ama » → « A ».
String monogramOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}
