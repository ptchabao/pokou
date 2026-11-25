import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Un fond choisi : son identifiant dans le catalogue et son intensité
/// (20 à 100 %, ignorée pour les fonds unis).
class WallpaperChoice {
  const WallpaperChoice({required this.id, this.intensity = 100});

  final String id;
  final int intensity;

  static const minIntensity = 20;
  static const maxIntensity = 100;

  Map<String, dynamic> toJson() => {'id': id, 'intensity': intensity};

  static WallpaperChoice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String) return null;
    final intensity = (raw['intensity'] as num?)?.toInt() ?? 100;
    return WallpaperChoice(
      id: id,
      intensity: intensity.clamp(minIntensity, maxIntensity),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WallpaperChoice &&
      other.id == id &&
      other.intensity == intensity;

  @override
  int get hashCode => Object.hash(id, intensity);
}

/// Les fonds choisis sur CE téléphone : le fond par défaut de toutes les
/// discussions, et ceux propres à certaines discussions.
///
/// Préférence personnelle et locale, comme sur WhatsApp : l'autre personne
/// ne voit jamais mon fond, et rien ne part au serveur. Une discussion est
/// désignée par `contact:<id>` ou `group:<id>` ([scopeForContact],
/// [scopeForGroup]).
class ChatWallpaperSettings {
  const ChatWallpaperSettings({this.global, this.perChat = const {}});

  /// `null` : le fond par défaut du catalogue (« Sable »).
  final WallpaperChoice? global;
  final Map<String, WallpaperChoice> perChat;

  /// Le fond d'une discussion : le sien s'il en a un, sinon le défaut.
  WallpaperChoice? resolve(String? scope) =>
      (scope == null ? null : perChat[scope]) ?? global;

  Map<String, dynamic> toJson() => {
    if (global != null) 'global': global!.toJson(),
    'chats': {for (final e in perChat.entries) e.key: e.value.toJson()},
  };

  factory ChatWallpaperSettings.fromJson(Map<String, dynamic> json) {
    final chats = <String, WallpaperChoice>{};
    final raw = json['chats'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final choice = WallpaperChoice.fromJson(e.value);
        if (e.key is String && choice != null) chats[e.key as String] = choice;
      }
    }
    return ChatWallpaperSettings(
      global: WallpaperChoice.fromJson(json['global']),
      perChat: chats,
    );
  }
}

String scopeForContact(int userId) => 'contact:$userId';
String scopeForGroup(int groupId) => 'group:$groupId';

/// Rangé dans le même coffre local que les autres réglages de l'app
/// (`AppSettingsController`), sous sa propre clé : la liste par discussion
/// grandit avec le temps, elle n'a pas à être réécrite avec les
/// notifications.
class ChatWallpaperController extends StateNotifier<ChatWallpaperSettings> {
  ChatWallpaperController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(const ChatWallpaperSettings()) {
    _loaded = _load();
  }

  final FlutterSecureStorage _storage;
  late final Future<void> _loaded;

  static const storageKey = 'pokou_chat_wallpapers';

  /// Terminé quand le réglage enregistré a été relu.
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null) return;
      state = ChatWallpaperSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Réglage illisible : le fond par défaut, plutôt qu'un écran cassé.
    }
  }

  Future<void> _persist(ChatWallpaperSettings next) async {
    state = next;
    try {
      await _storage.write(key: storageKey, value: jsonEncode(next.toJson()));
    } catch (_) {}
  }

  /// [scope] `null` : le fond par défaut de toutes les discussions.
  Future<void> choose(String? scope, WallpaperChoice choice) async {
    await _loaded;
    if (scope == null) {
      return _persist(
        ChatWallpaperSettings(global: choice, perChat: state.perChat),
      );
    }
    return _persist(
      ChatWallpaperSettings(
        global: state.global,
        perChat: {...state.perChat, scope: choice},
      ),
    );
  }

  /// La discussion suit de nouveau le fond par défaut.
  Future<void> useDefault(String scope) async {
    await _loaded;
    final chats = {...state.perChat}..remove(scope);
    return _persist(
      ChatWallpaperSettings(global: state.global, perChat: chats),
    );
  }
}

final chatWallpaperProvider =
    StateNotifierProvider<ChatWallpaperController, ChatWallpaperSettings>(
      (ref) => ChatWallpaperController(),
    );
