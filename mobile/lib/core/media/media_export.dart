import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'media_repository.dart';

/// Sortir un média du stockage privé de Pokou.
///
/// ── Pourquoi c'était nécessaire ──────────────────────────────────────────
///
/// Un média reçu vivait UNIQUEMENT dans le cache de l'application
/// (`getTemporaryDirectory`). On pouvait l'ouvrir, on pouvait le partager —
/// mais on ne pouvait pas le GARDER. Une photo reçue disparaissait au
/// prochain nettoyage du cache par le système, sans que rien ne prévienne.
///
/// Pire : c'est le répertoire TEMPORAIRE. Android le vide quand l'espace
/// manque, et il le fait sans demander.
///
/// ── Deux destinations, et il ne faut pas les confondre ───────────────────
///
/// Photos et vidéos vont dans la GALERIE : c'est là qu'on les cherche, et
/// c'est le seul endroit où les applications photo les trouveront.
///
/// Documents, audio et le reste n'ont rien à y faire — la galerie les
/// refuserait de toute façon. Ils passent par la feuille de partage du
/// système, qui laisse choisir « Enregistrer dans Fichiers », Drive, ou
/// n'importe quelle application capable de les recevoir. C'est moins direct,
/// et c'est le seul chemin qui fonctionne sur les deux plateformes sans
/// demander une permission de stockage large.
///
/// ── Ce que ça ne change pas ──────────────────────────────────────────────
///
/// Le chiffrement. Le fichier est déjà déchiffré localement quand il arrive
/// ici — c'est `MediaRepository` qui s'en charge. Exporter une copie en
/// clair est le but même de l'opération : l'utilisateur veut sa photo dans
/// sa galerie, pas un fichier que lui seul peut ouvrir.
class MediaExport {
  const MediaExport({required MediaRepository repository})
      : _repository = repository;

  final MediaRepository _repository;

  /// Enregistre un média dans la galerie du téléphone.
  ///
  /// Renvoie `true` si c'est fait. Les échecs sont RENDUS et non levés :
  /// l'appelant affiche un message, et une permission refusée n'est pas une
  /// erreur de programme — c'est une réponse de l'utilisateur.
  Future<MediaExportResult> saveToGallery({
    required int mediaAssetId,
    required String extension,
    required bool isVideo,
  }) async {
    final File file;
    try {
      file = await _repository.resolveLocalFile(
        mediaAssetId,
        extension: extension,
      );
    } catch (_) {
      return MediaExportResult.downloadFailed;
    }

    try {
      // La permission est demandée par `gal` lui-même, et seulement si la
      // version d'Android l'exige — depuis Android 10, écrire dans la
      // galerie via MediaStore n'en demande aucune.
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) {
          return MediaExportResult.permissionDenied;
        }
      }
      // `album` regroupe les médias de Pokou plutôt que de les mêler à la
      // pellicule : on retrouve ce qui vient d'une conversation sans
      // fouiller des milliers de photos.
      if (isVideo) {
        await Gal.putVideo(file.path, album: albumName);
      } else {
        await Gal.putImage(file.path, album: albumName);
      }
      return MediaExportResult.saved;
    } on GalException catch (exception) {
      return switch (exception.type) {
        GalExceptionType.accessDenied => MediaExportResult.permissionDenied,
        GalExceptionType.notEnoughSpace => MediaExportResult.noSpace,
        _ => MediaExportResult.failed,
      };
    } on PlatformException {
      return MediaExportResult.failed;
    } catch (_) {
      return MediaExportResult.failed;
    }
  }

  /// Propose d'enregistrer un document, un audio ou un fichier ailleurs.
  ///
  /// La feuille de partage du système, et non un chemin choisi par
  /// l'application : « Enregistrer dans Fichiers » y figure, et l'utilisateur
  /// range où il veut. Écrire nous-mêmes dans un dossier arbitraire
  /// demanderait une permission de stockage large — celle qu'Android
  /// restreint de version en version, et que le Play Store fait justifier.
  Future<MediaExportResult> exportFile({
    required int mediaAssetId,
    required String extension,
    String? suggestedName,
  }) async {
    final File source;
    try {
      source = await _repository.resolveLocalFile(
        mediaAssetId,
        extension: extension,
      );
    } catch (_) {
      return MediaExportResult.downloadFailed;
    }

    try {
      // Copié sous son VRAI nom avant d'être partagé : le cache nomme les
      // fichiers par identifiant (`pokou_media_42.pdf`), et c'est ce nom que
      // l'utilisateur retrouverait dans ses documents.
      final shared = await _underRealName(source, suggestedName, extension);
      await Share.shareXFiles([XFile(shared.path)]);
      return MediaExportResult.shared;
    } catch (_) {
      return MediaExportResult.failed;
    }
  }

  Future<File> _underRealName(
    File source,
    String? suggestedName,
    String extension,
  ) async {
    final name = (suggestedName ?? '').trim();
    if (name.isEmpty) return source;
    final dir = await getTemporaryDirectory();
    final safe = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final target = File('${dir.path}/$safe');
    if (target.path == source.path) return source;
    return source.copy(target.path);
  }

  /// Le nom de l'album. Public : l'écran de confirmation le cite.
  static const albumName = 'Pokou';
}

/// Ce qu'a donné l'export.
///
/// Une énumération plutôt qu'un booléen : « refusé », « pas de place » et
/// « échec » appellent trois messages différents, et les fondre en un seul
/// « ça n'a pas marché » laisserait l'utilisateur sans recours.
enum MediaExportResult {
  saved,
  shared,
  permissionDenied,
  noSpace,
  downloadFailed,
  failed;

  bool get isSuccess => this == saved || this == shared;
}
