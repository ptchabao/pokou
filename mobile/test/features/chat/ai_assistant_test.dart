import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/features/chat/data/chat_local_store.dart';
import 'package:pokou/features/chat/data/chat_repository.dart';
import 'package:pokou/features/chat/presentation/chat_screen.dart';

/// L'assistant : les blocs de code dans les réponses, et la voix.

class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async => value == null ? _values.remove(key) : _values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _MemoryStorage();

  group('les blocs de code', () {
    test('le texte et le code se séparent, la langue annoncée disparaît', () {
      final parts = splitCodeBlocks(
        'Voici :\n```dart\nfinal x = 1;\n```\nEt voilà.',
      );
      expect(parts, [
        (text: 'Voici :', isCode: false),
        (text: 'final x = 1;', isCode: true),
        (text: 'Et voilà.', isCode: false),
      ]);
    });

    test('une réponse sans code reste un seul texte', () {
      expect(splitCodeBlocks('Bonjour'), [(text: 'Bonjour', isCode: false)]);
    });
  });

  test(
    'la voix part sous le champ « audio », et le fichier ne reste pas',
    () async {
      late http.BaseRequest sent;
      final api = ApiClient(
        tokenStorage: SecureTokenStorage(),
        baseUrl: 'https://pokou.test/api/v1',
        httpClient: MockClient.streaming((request, body) async {
          sent = request;
          await body.drain<void>();
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': ' Bonjour Aoussi '}))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repository = ChatRepository(
        apiClient: api,
        localStore: ChatLocalStore(),
      );
      final dir = await Directory.systemTemp.createTemp('pokou_voix_');
      final audio = File('${dir.path}/voix.m4a')..writeAsBytesSync([1, 2, 3]);

      final text = await repository.transcribe(audio, language: 'fr');

      expect(text, 'Bonjour Aoussi');
      expect(sent.url.path, '/api/v1/mahizu/ingest/audio');
      final multipart = sent as http.MultipartRequest;
      expect(multipart.files.single.field, 'audio');
      expect(multipart.fields['language'], 'fr');
      expect(audio.existsSync(), isFalse);
      await dir.delete(recursive: true);
    },
  );
}
