import '../../../core/time/server_time.dart';
enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.monitorId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int monitorId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'monitor_id': monitorId,
    'role': role.name,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      monitorId: map['monitor_id'] as int,
      role: map['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: map['content'] as String,
      createdAt: parseServerTime(map['created_at'] as String),
    );
  }
}
