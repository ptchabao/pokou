import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/media/media_repository.dart';

class _MockApiClient extends ApiClient {
  _MockApiClient() : super(baseUrl: 'https://mock.pokou');

  int getBytesCallCount = 0;
  int uploadCallCount = 0;

  @override
  Future<dynamic> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String mimeType,
    Map<String, String>? fields,
    void Function(double fraction)? onProgress,
    String fileField = 'file',
  }) async {
    uploadCallCount++;
    return {
      'id': 777,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
      'original_filename': filename,
    };
  }

  @override
  Future<List<int>> getBytes(String path) async {
    getBytesCallCount++;
    return [1, 2, 3, 4];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _MockApiClient mockApi;
  late MediaRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pokou_media_test_');
    mockApi = _MockApiClient();
    repository = MediaRepository(apiClient: mockApi);
    MediaRepository.viderLeCacheMemoire();
    // Injecte le répertoire de test au lieu de path_provider
    MediaRepository.setTestCacheDirectory(tempDir);
  });

  tearDown(() async {
    MediaRepository.viderLeCacheMemoire();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('memoriserDansCache rend le fichier disponible immédiatement et sans Future', () async {
    final bytes = [10, 20, 30, 40];
    await repository.memoriserDansCache(
      123,
      bytes: bytes,
      extension: 'jpg',
    );

    // Vérifie que fichierEnCache le résout SYNCHRONEMENT (sans Future)
    final enCache = repository.fichierEnCache(123, extension: 'jpg');
    expect(enCache, isNotNull);
    expect(await enCache!.readAsBytes(), equals(bytes));

    // Vérifie que resolveLocalFile n'appelle PAS l'API réseau
    final resolu = await repository.resolveLocalFile(123, extension: 'jpg');
    expect(resolu.path, equals(enCache.path));
    expect(mockApi.getBytesCallCount, equals(0));
  });

  test('upload met automatiquement en cache les octets envoyés', () async {
    final photoBytes = [99, 98, 97];
    final result = await repository.upload(
      bytes: photoBytes,
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
      messageType: 'IMAGE',
    );

    expect(result.id, equals(777));
    expect(mockApi.uploadCallCount, equals(1));

    // Immédiatement après upload, le média 777 doit être résoluble sans requête réseau
    final enCache = repository.fichierEnCache(777, extension: 'jpg');
    expect(enCache, isNotNull);
    expect(await enCache!.readAsBytes(), equals(photoBytes));

    // La bulle confirmée qui appelle resolveLocalFile ne doit PAS faire de GET /media/777
    final fichier = await repository.resolveLocalFile(777, extension: 'jpg');
    expect(fichier.path, equals(enCache.path));
    expect(mockApi.getBytesCallCount, equals(0));
  });

  test('fichierEnCache retrouve le média sur disque après redémarrage mémoire', () async {
    final bytes = [42, 43, 44];
    await repository.memoriserDansCache(888, bytes: bytes, extension: 'png');

    // Vérifie la présence en mémoire
    final resolusMemoire = repository.fichierEnCache(888, extension: 'png');
    expect(resolusMemoire, isNotNull);

    // Efface la mémoire RAM pour simuler une nouvelle session, MAIS
    // garde le répertoire synchrone pour simuler le warmup
    MediaRepository.viderLeCacheMemoire();
    MediaRepository.setTestCacheDirectory(tempDir);

    // fichierEnCache doit retrouver le fichier sur disque de façon SYNCHRONE
    final retrouve = repository.fichierEnCache(888, extension: 'png');
    expect(retrouve, isNotNull, reason: 'Le fichier sur disque doit être trouvé de manière synchrone');
    expect(await retrouve!.readAsBytes(), equals(bytes));

    // Et resolveLocalFile ne doit PAS appeler l'API
    expect(mockApi.getBytesCallCount, equals(0));
  });

  test('resolveLocalFile utilise SynchronousFuture quand le fichier est en cache', () async {
    final bytes = [55, 56, 57];
    await repository.memoriserDansCache(999, bytes: bytes, extension: 'webp');

    // Le résultat de resolveLocalFile doit se compléter immédiatement
    // (SynchronousFuture) et ne pas déclencher de requête réseau
    bool resolved = false;
    repository.resolveLocalFile(999, extension: 'webp').then((_) {
      resolved = true;
    });
    // SynchronousFuture se résout DANS LE MÊME microtask
    expect(resolved, isTrue, reason: 'SynchronousFuture doit se compléter immédiatement');
    expect(mockApi.getBytesCallCount, equals(0));
  });
}
