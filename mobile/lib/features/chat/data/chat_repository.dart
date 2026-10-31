import 'dart:io';

import '../../../core/api/api_client.dart';
import 'chat_local_store.dart';
import 'chat_message_model.dart';

class ChatRepository {
  ChatRepository({
    required ApiClient apiClient,
    required ChatLocalStore localStore,
  }) : _api = apiClient,
       _local = localStore;

  final ApiClient _api;
  final ChatLocalStore _local;

  Future<List<ChatMessage>> loadHistory(int monitorId) =>
      _local.forMonitor(monitorId);

  Future<void> clearHistory(int monitorId) =>
      _local.deleteForMonitor(monitorId);

  /// Recopie sur l'appareil un fil dont le serveur est la source de vérité —
  /// voir ChatLocalStore.replaceForMonitor.
  Future<void> replaceHistory(int monitorId, List<ChatMessage> messages) =>
      _local.replaceForMonitor(monitorId, messages);

  /// Ce que l'utilisateur a dit à l'assistant, en texte.
  ///
  /// Le fichier part vers la transcription (Whisper, côté API) et n'est pas
  /// conservé : supprimé ici dès la réponse reçue, qu'elle réussisse ou
  /// non — c'est la voix de quelqu'un.
  Future<String> transcribe(File audio, {required String language}) async {
    try {
      final response = await _api.uploadFile(
        '/mahizu/ingest/audio',
        bytes: await audio.readAsBytes(),
        filename: 'voix.m4a',
        mimeType: 'audio/mp4',
        fileField: 'audio',
        fields: {'language': language},
      );
      return ((response as Map<String, dynamic>)['text'] as String? ?? '')
          .trim();
    } finally {
      if (await audio.exists()) await audio.delete();
    }
  }

  /// Persists the user's message immediately (so it survives an offline
  /// send failure), calls the API, then persists and returns the reply.
  ///
  /// `monitorId == 0` is the sentinel for "chat général, aucun moniteur" —
  /// Mahizu reste joignable même si l'utilisateur n'a connecté aucune
  /// source de données (voir _PinnedMahizuTile). Purement local (clé de
  /// regroupement SQLite, jamais validée contre le backend) ; `monitor_id`
  /// est omis du corps de la requête dans ce cas pour que l'API bascule
  /// sur le mode assistant généraliste (voir routes/mahizu.py).
  Future<ChatMessage> sendMessage({
    required int monitorId,
    required String text,
  }) async {
    await _local.insert(
      ChatMessage(
        monitorId: monitorId,
        role: ChatRole.user,
        content: text,
        createdAt: DateTime.now(),
      ),
    );

    final response = await _api.post(
      '/mahizu/chat',
      body: {if (monitorId != 0) 'monitor_id': monitorId, 'message': text},
    );
    final answer = response['answer'] as String;

    return _local.insert(
      ChatMessage(
        monitorId: monitorId,
        role: ChatRole.assistant,
        content: answer,
        createdAt: DateTime.now(),
      ),
    );
  }
}
