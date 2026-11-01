import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/chat/data/chat_message_model.dart';

void main() {
  test('ChatMessage round-trips through toMap/fromMap', () {
    final original = ChatMessage(
      id: 7,
      monitorId: 3,
      role: ChatRole.assistant,
      content: 'Il vous reste 42 unités en stock.',
      createdAt: DateTime.utc(2026, 8, 5, 10, 30),
    );

    final restored = ChatMessage.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.monitorId, original.monitorId);
    expect(restored.role, ChatRole.assistant);
    expect(restored.content, original.content);
    // Le même instant, rendu dans le fuseau du téléphone.
    expect(restored.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
  });

  test(
    'role "user" maps correctly and anything else falls back to assistant',
    () {
      expect(
        ChatMessage.fromMap({
          'monitor_id': 1,
          'role': 'user',
          'content': 'hi',
          'created_at': DateTime.now().toIso8601String(),
        }).role,
        ChatRole.user,
      );

      expect(
        ChatMessage.fromMap({
          'monitor_id': 1,
          'role': 'assistant',
          'content': 'hi',
          'created_at': DateTime.now().toIso8601String(),
        }).role,
        ChatRole.assistant,
      );
    },
  );
}
