import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import 'notification_policy.dart';
import '../time/server_time.dart';

/// Les notifications de message, façon WhatsApp : UNE notification par
/// conversation, qui se déroule sur ses derniers messages, toutes rangées
/// sous un même résumé « Pokou ».
///
/// Elles étaient affichées par Android à partir d'un push « notification » —
/// une ligne par message, sans regroupement possible, et « Nouveau message »
/// pour tout contenu. L'application les construit désormais elle-même, à
/// partir d'un push de données (voir api/app/routes/messages.py
/// ::_rich_push_data) : c'est ce qui permet le regroupement, le contenu, la
/// réponse rapide.
///
/// Ce fichier sert les DEUX isolats : celui de l'application, et celui que
/// Firebase réveille quand elle est fermée. Il n'y dépend de rien d'autre
/// que du greffon et d'un fichier.

/// Le port sous lequel l'isolat de l'application se fait connaître, pour que
/// l'isolat de Firebase lui confie les messages quand elle tourne — voir
/// push_service.dart.
const kMainNotificationsPortName = 'pokou.notifications.main';

const kMessagesGroupKey = 'com.pokou.pokou.MESSAGES';

/// Les actions d'une notification de message.
const kReplyActionId = 'reply';
const kMarkReadActionId = 'mark_read';

/// Combien de messages une notification garde en mémoire.
const _maxLinesPerThread = 7;

/// Un push de message enrichi, lu depuis `RemoteMessage.data`.
@immutable
class MessagePush {
  const MessagePush({
    required this.type,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.sentAt,
    required this.priority,
    required this.muted,
    this.contactUserId,
    this.groupId,
    this.groupName,
    this.senderCertifiedName,
    this.mentioned = false,
    this.isEncrypted = false,
    this.encryption,
    this.ciphertext,
    this.envelope,
  });

  final String type;
  final String messageId;
  final int senderId;
  final String senderName;
  final String? senderCertifiedName;
  final String messageType;
  final DateTime sentAt;
  final String? priority;
  final bool muted;
  final int? contactUserId;
  final int? groupId;
  final String? groupName;
  final bool mentioned;
  final bool isEncrypted;
  final String? encryption;
  final String? ciphertext;
  final Map<String, dynamic>? envelope;

  bool get isGroup => groupId != null;
  String get conversationKey => isGroup ? 'group:$groupId' : 'contact:$contactUserId';
  int get notificationId => conversationNotificationKeyId(conversationKey);

  /// `null` pour un push qui n'est pas un message enrichi — l'ancien format
  /// reste traité par le chemin d'avant.
  static MessagePush? tryParse(Map<String, dynamic> data) {
    if (data['rich'] != '1') return null;
    final messageId = data['message_id']?.toString();
    final senderId = int.tryParse(data['sender_id']?.toString() ?? '');
    if (messageId == null || senderId == null) return null;
    Map<String, dynamic>? envelope;
    final rawEnvelope = data['envelope'];
    if (rawEnvelope is String && rawEnvelope.isNotEmpty) {
      try {
        envelope = jsonDecode(rawEnvelope) as Map<String, dynamic>;
      } catch (_) {}
    }
    final certified = data['sender_certified_name']?.toString();
    return MessagePush(
      type: data['type']?.toString() ?? 'message',
      messageId: messageId,
      senderId: senderId,
      senderName: data['sender_name']?.toString() ?? data['contact_name']?.toString() ?? '',
      senderCertifiedName: certified == null || certified.isEmpty ? null : certified,
      // `msg_type` : Firebase réserve `message_type` (gardé en repli pour un
      // serveur plus ancien).
      messageType:
          (data['msg_type'] ?? data['message_type'])?.toString() ?? 'TEXT',
      sentAt: tryParseServerTime(data['sent_at']?.toString() ?? '') ?? DateTime.now(),
      priority: data['priority']?.toString(),
      muted: data['muted'] == '1',
      contactUserId: int.tryParse(data['contact_user_id']?.toString() ?? ''),
      groupId: int.tryParse(data['group_id']?.toString() ?? ''),
      groupName: data['group_name']?.toString(),
      mentioned: data['mentioned'] == '1',
      isEncrypted: data['is_encrypted'] == '1',
      encryption: data['encryption']?.toString(),
      ciphertext: data['ciphertext']?.toString(),
      envelope: envelope,
    );
  }
}

/// Une ligne de la notification déroulée.
class ThreadLine {
  const ThreadLine({
    required this.messageId,
    required this.sender,
    required this.text,
    required this.at,
    this.fromMe = false,
  });

  final String messageId;
  final String sender;
  final String text;
  final DateTime at;
  final bool fromMe;

  Map<String, dynamic> toJson() => {
    'id': messageId,
    'sender': sender,
    'text': text,
    'at': at.millisecondsSinceEpoch,
    'me': fromMe,
  };

  factory ThreadLine.fromJson(Map<String, dynamic> json) => ThreadLine(
    messageId: json['id'] as String? ?? '',
    sender: json['sender'] as String? ?? '',
    text: json['text'] as String? ?? '',
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
    fromMe: json['me'] as bool? ?? false,
  );
}

/// Une conversation notifiée : son titre et ses dernières lignes.
class NotificationThread {
  NotificationThread({
    required this.key,
    required this.title,
    required this.isGroup,
    required this.lines,
    this.payload = const {},
  });

  final String key;
  String title;
  final bool isGroup;
  final List<ThreadLine> lines;

  /// Le push d'origine : de quoi rouvrir la conversation au toucher, et
  /// répondre ou marquer comme lu sans rien redemander.
  Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'title': title,
    'group': isGroup,
    'lines': [for (final l in lines) l.toJson()],
    'payload': payload,
  };

  factory NotificationThread.fromJson(String key, Map<String, dynamic> json) =>
      NotificationThread(
        key: key,
        title: json['title'] as String? ?? '',
        isGroup: json['group'] as bool? ?? false,
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            ThreadLine.fromJson(Map<String, dynamic>.from(l as Map)),
        ],
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      );
}

/// La mémoire des notifications en cours, sur disque : Android ne rend pas
/// le contenu d'une notification déjà affichée, et chaque nouveau message
/// doit la reconstruire en entier — avec les précédents.
///
/// Un fichier JSON, et non la base chiffrée : il ne contient que ce qui est
/// DÉJÀ visible dans le volet de notifications, et il doit s'ouvrir depuis
/// l'isolat de Firebase en quelques millisecondes.
class NotificationThreads {
  NotificationThreads({File? file}) : _file = file;

  File? _file;

  Future<File> _target() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    return _file = File('${dir.path}/notification_threads.json');
  }

  Future<Map<String, NotificationThread>> load() async {
    try {
      final file = await _target();
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return {
        for (final entry in raw.entries)
          entry.key: NotificationThread.fromJson(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
    } catch (_) {
      // Illisible : on repart de zéro, la prochaine notification le réécrit.
      return {};
    }
  }

  Future<void> save(Map<String, NotificationThread> threads) async {
    try {
      final file = await _target();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({for (final t in threads.values) t.key: t.toJson()}),
        flush: true,
      );
      await tmp.rename(file.path);
    } catch (exc) {
      debugPrint('[Notif] Mémoire des notifications non écrite: $exc');
    }
  }
}

/// Les libellés d'un message sans texte.
String messagePreviewLabel(L l, String messageType, String? text) {
  final trimmed = text?.trim() ?? '';
  return switch (messageType) {
    'IMAGE' => trimmed.isEmpty ? l.notifPhoto : '📷 $trimmed',
    'VIDEO' => trimmed.isEmpty ? l.notifVideo : '🎥 $trimmed',
    'AUDIO' => l.notifVoice,
    'DOCUMENT' => l.notifDocument,
    'STICKER' => l.notifSticker,
    'LOCATION' => l.notifLocation,
    'CONTACT' => l.notifContact,
    'POLL' => l.notifPoll,
    _ => trimmed.isEmpty ? l.notifNewMessage : trimmed,
  };
}

/// Construit et publie les notifications de message.
class MessageNotificationPresenter {
  MessageNotificationPresenter({
    required this.plugin,
    required this.l,
    NotificationThreads? threads,
  }) : threads = threads ?? NotificationThreads();

  final FlutterLocalNotificationsPlugin plugin;
  final L l;
  final NotificationThreads threads;

  AndroidNotificationChannel get channel => AndroidNotificationChannel(
    'pokou_messages',
    l.pushMessagesChannel,
    description: l.pushMessagesChannelDesc,
    importance: Importance.high,
  );

  /// Ajoute une ligne à la conversation et republie sa notification.
  Future<void> add({
    required MessagePush push,
    required String title,
    required ThreadLine line,
    required Map<String, dynamic> payload,
    bool silent = false,
    bool withSound = true,
    bool alert = true,
  }) => _serialized(() async {
    final all = await threads.load();
    final thread = all[push.conversationKey] ??
        NotificationThread(
          key: push.conversationKey,
          title: title,
          isGroup: push.isGroup,
          lines: [],
        );
    thread
      ..title = title
      ..payload = payload;
    // Le même message, reçu deux fois (deux jetons, un rejeu) : remplacé, pas
    // dupliqué — c'est aussi ainsi que « Nouveau message » devient son texte.
    thread.lines.removeWhere((existing) => existing.messageId == line.messageId);
    thread.lines.add(line);
    thread.lines.sort((a, b) => a.at.compareTo(b.at));
    if (thread.lines.length > _maxLinesPerThread) {
      thread.lines.removeRange(0, thread.lines.length - _maxLinesPerThread);
    }
    all[thread.key] = thread;
    await threads.save(all);
    await _publish(thread, silent: silent, withSound: withSound, alert: alert);
    await _publishSummary(all);
  });

  /// La conversation a été lue (ouverte, ou « Marquer comme lu ») : sa
  /// notification disparaît, et le résumé se met à jour.
  Future<void> clear(String conversationKey) => _serialized(() async {
    final all = await threads.load();
    final removed = all.remove(conversationKey) != null;
    await plugin.cancel(conversationNotificationKeyId(conversationKey));
    if (!removed) return;
    await threads.save(all);
    await _publishSummary(all);
  });

  /// Lire, modifier, réécrire le fichier : deux messages arrivés ensemble
  /// feraient perdre la ligne de l'un. Une file par isolat — l'isolat de
  /// Firebase confie les siens à l'application quand elle tourne, il n'y a
  /// donc jamais deux isolats sur ce fichier à la fois.
  static Future<void> _queue = Future.value();

  Future<void> _serialized(Future<void> Function() step) {
    final next = _queue.then((_) => step());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<NotificationThread?> thread(String conversationKey) async =>
      (await threads.load())[conversationKey];

  Future<void> _publish(
    NotificationThread thread, {
    required bool silent,
    required bool withSound,
    required bool alert,
  }) async {
    final me = Person(name: l.notifMe, key: 'me');
    final style = MessagingStyleInformation(
      me,
      conversationTitle: thread.isGroup ? thread.title : null,
      groupConversation: thread.isGroup,
      messages: [
        for (final line in thread.lines)
          Message(
            line.text,
            line.at,
            line.fromMe ? me : Person(name: line.sender, key: line.sender),
          ),
      ],
    );
    final incoming = thread.lines.where((line) => !line.fromMe).length;
    await plugin.show(
      conversationNotificationKeyId(thread.key),
      thread.title,
      thread.lines.isEmpty ? '' : thread.lines.last.text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          // Sans teinte, Android retombe sur son vert par défaut.
          color: AppColors.accentPrimary,
          channelDescription: channel.description,
          category: AndroidNotificationCategory.message,
          importance: silent ? Importance.low : Importance.high,
          priority: silent ? Priority.low : Priority.high,
          styleInformation: style,
          groupKey: kMessagesGroupKey,
          number: incoming,
          // Chaque nouveau message sonne ; une MISE À JOUR — « Nouveau
          // message » qui devient son texte, une réponse envoyée depuis la
          // notification — ne refait pas sonner.
          onlyAlertOnce: !alert,
          playSound: withSound && !silent,
          enableVibration: withSound && !silent,
          autoCancel: true,
          actions: [
            AndroidNotificationAction(
              kReplyActionId,
              l.notifReply,
              inputs: [AndroidNotificationActionInput(label: l.notifReplyHint)],
              cancelNotification: false,
            ),
            AndroidNotificationAction(kMarkReadActionId, l.notifMarkRead),
          ],
        ),
      ),
      payload: jsonEncode(thread.payload),
    );
  }

  /// Le chapeau qui range toutes les conversations — « Pokou · 3
  /// conversations ». Sans lui, Android n'empile pas les notifications sous
  /// un même groupe avant la quatrième.
  Future<void> _publishSummary(Map<String, NotificationThread> all) async {
    if (all.isEmpty) {
      await plugin.cancel(kMessagesSummaryId);
      return;
    }
    final total = all.values.fold<int>(
      0,
      (sum, t) => sum + t.lines.where((line) => !line.fromMe).length,
    );
    await plugin.show(
      kMessagesSummaryId,
      'Pokou',
      l.notifSummary(total, all.length),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          // Sans teinte, Android retombe sur son vert par défaut.
          color: AppColors.accentPrimary,
          channelDescription: channel.description,
          groupKey: kMessagesGroupKey,
          setAsGroupSummary: true,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
    );
  }
}
