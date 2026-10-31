import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/media/media_export.dart';
import 'package:pokou/core/crypto/media_cipher.dart';
import 'package:pokou/core/media/media_repository.dart';

/// Sortir un média du stockage privé de Pokou.
///
/// Un fichier reçu vivait UNIQUEMENT dans le cache de l'application —
/// c'est-à-dire le répertoire TEMPORAIRE, qu'Android vide quand l'espace
/// manque, sans prévenir. On pouvait ouvrir et partager une photo reçue ;
/// on ne pouvait pas la garder.
///
/// Ce qui se teste ici sans appareil : la décision (galerie ou feuille de
/// partage), et le fait qu'un échec soit RENDU plutôt que levé — une
/// permission refusée est une réponse de l'utilisateur, pas une erreur de
/// programme.
class _RepoQuiEchoue extends MediaRepository {
  _RepoQuiEchoue() : super(apiClient: ApiClient(baseUrl: 'https://inutilise'));

  @override
  Future<File> resolveLocalFile(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
    MediaKey? mediaKey,
  }) => Future.error(Exception('média indisponible'));
}

void main() {
  test('un média qu\'on ne peut pas télécharger ne lève pas', () async {
    // L'appelant affiche un message ; une exception ferait remonter une
    // erreur rouge pour un fichier simplement absent.
    final export = MediaExport(repository: _RepoQuiEchoue());

    expect(
      await export.saveToGallery(
        mediaAssetId: 1,
        extension: '.jpg',
        isVideo: false,
      ),
      MediaExportResult.downloadFailed,
    );
    expect(
      await export.exportFile(mediaAssetId: 1, extension: '.pdf'),
      MediaExportResult.downloadFailed,
    );
  });

  group('ce que chaque issue veut dire', () {
    test('seuls « enregistré » et « partagé » sont des succès', () {
      // Une énumération plutôt qu'un booléen : « refusé », « pas de place »
      // et « échec » appellent trois conduites différentes, et les fondre
      // en un seul « ça n'a pas marché » laisserait sans recours.
      expect(MediaExportResult.saved.isSuccess, isTrue);
      expect(MediaExportResult.shared.isSuccess, isTrue);
      expect(MediaExportResult.permissionDenied.isSuccess, isFalse);
      expect(MediaExportResult.noSpace.isSuccess, isFalse);
      expect(MediaExportResult.downloadFailed.isSuccess, isFalse);
      expect(MediaExportResult.failed.isSuccess, isFalse);
    });

    test('chaque issue a son message dans les six langues', () {
      // Le garde-fou : ajouter une issue sans son libellé ferait échouer la
      // compilation du `switch` exhaustif côté écran, pas ce test — mais
      // celui-ci documente le contrat.
      expect(MediaExportResult.values, hasLength(6));
    });
  });

  test('les médias de Pokou vont dans leur propre album', () {
    // Plutôt que mêlés à la pellicule : on retrouve ce qui vient d'une
    // conversation sans fouiller des milliers de photos.
    expect(MediaExport.albumName, 'Pokou');
  });
}
