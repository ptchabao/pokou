import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/messaging/data/direct_message_model.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_client.dart';
import 'message_notifications.dart';
import 'notification_policy.dart';

/// Ce que fait l'appareil d'un push de message enrichi, et des boutons de
/// sa notification — dans l'application comme dans l'isolat de Firebase.
///
/// ── Le contenu ─────────────────────────────────────────────────────────
///
/// Le texte ne voyage jamais par Firebase. Le push donne l'identifiant du
/// message ; l'appareil va le chercher (ou, pour un message chiffré, ouvre
/// le chiffré que le push transporte déjà) et le déchiffre lui-même.
///
/// Un message chiffré ne s'ouvre qu'UNE fois — sa clé est consommée. Le
/// déchiffrement passe donc par [MessagingRepository.decryptIncoming], qui
/// écrit le clair dans le cache local avant de rendre la main : quand
/// l'application s'ouvrira, elle le trouvera là au lieu d'échouer à le
/// rouvrir.
///
/// ── La réponse ─────────────────────────────────────────────────────────
///
/// Un groupe n'est pas chiffré de bout en bout : la réponse part tout de
/// suite. Une conversation privée, elle, demande de SCELLER le message, ce
/// qui fait avancer l'état de chiffrement de la conversation. Hors de
/// l'application, cet état pourrait être modifié en même temps par elle si
/// elle démarre à cet instant — et un état de chiffrement corrompu rend la
/// conversation illisible. La réponse est donc mise en attente
/// ([PendingReplies]) et part à la prochaine ouverture de Pokou : c'est
/// [sendDirect] qui décide.
class MessageNotificationHandler {
  MessageNotificationHandler({
    required this.presenter,
    required this.api,
    required this.messaging,
    required this.sendDirect,
    this.myUserId,
  });

  final MessageNotificationPresenter presenter;
  final ApiClient api;
  final MessagingRepository messaging;

  /// Envoie (dans l'application) ou met en attente (hors d'elle) une
  /// réponse privée. Rend `true` si elle est partie.
  final Future<bool> Function(int recipientId, String text) sendDirect;

  /// L'utilisateur connecté. Sans lui, le message ne se reconstruit pas
  /// depuis le push : le clair est rangé dans le cache sous sa
  /// conversation, et un destinataire inconnu l'y égarerait.
  final int? myUserId;

  L get l => presenter.l;

  /// Publie la notification d'un message reçu.
  ///
  /// `fallbackFirst` : publier tout de suite « Nouveau message », puis le
  /// remplacer par son texte. Hors de l'application, Android peut arrêter
  /// l'isolat à tout moment — le téléphone doit sonner même si le
  /// contenu n'arrive jamais.
  Future<void> handle(
    MessagePush push, {
    required NotificationPresentation presentation,
    required bool withSound,
    bool fallbackFirst = false,
  }) async {
    if (presentation == NotificationPresentation.suppressed) return;
    final silent = presentation == NotificationPresentation.silent;
    final title = push.isGroup
        ? (push.groupName?.isNotEmpty == true ? push.groupName! : l.pushGroupFallback)
        : push.senderName;
    final sender = push.senderCertifiedName ?? push.senderName;
    final payload = <String, dynamic>{
      'rich': '1',
      'type': push.type,
      'message_id': push.messageId,
      'sender_id': '${push.senderId}',
      if (push.contactUserId != null) 'contact_user_id': '${push.contactUserId}',
      if (!push.isGroup) 'contact_name': push.senderName,
      if (push.groupId != null) 'group_id': '${push.groupId}',
      if (push.groupName != null) 'group_name': push.groupName,
    };

    ThreadLine lineWith(String text) => ThreadLine(
      messageId: push.messageId,
      sender: sender,
      text: text,
      at: push.sentAt,
    );

    final fallback = messagePreviewLabel(l, push.messageType, null);
    if (fallbackFirst) {
      await presenter.add(
        push: push,
        title: title,
        line: lineWith(fallback),
        payload: payload,
        silent: silent,
        withSound: withSound,
      );
    }
    final text = await resolveText(push);
    if (fallbackFirst && text == null) return;
    await presenter.add(
      push: push,
      title: title,
      line: lineWith(text ?? fallback),
      payload: payload,
      silent: silent,
      withSound: withSound,
      // Déjà sonné avec « Nouveau message » : la mise à jour se fait en
      // silence.
      alert: !fallbackFirst,
    );
  }

  /// Le texte à afficher, ou `null` s'il n'a pas pu être obtenu — la
  /// notification garde alors « Nouveau message ».
  Future<String?> resolveText(MessagePush push) async {
    try {
      if (push.isGroup) {
        final json = await api.get('/groups/${push.groupId}/messages/${push.messageId}')
            as Map<String, dynamic>;
        return messagePreviewLabel(
          l,
          json['message_type'] as String? ?? push.messageType,
          json['content'] as String?,
        );
      }
      final message = await _directMessage(push);
      final opened = message.isEncrypted
          ? await messaging.decryptIncoming(message, push.senderId)
          : message;
      // Toujours chiffré : il n'a pas pu s'ouvrir. On ne montre pas de
      // chiffré, ni d'erreur, dans le volet.
      if (opened.isEncrypted) return null;
      return messagePreviewLabel(l, opened.messageType, opened.content);
    } catch (exc) {
      debugPrint('[Notif] Contenu du message indisponible: $exc');
      return null;
    }
  }

  /// Le message tel que le serveur le connaît. Le chiffré voyage dans le
  /// push quand il est assez court : c'est un aller-retour réseau de moins,
  /// sur un téléphone qui vient à peine de se réveiller.
  Future<DirectMessage> _directMessage(MessagePush push) async {
    final me = myUserId;
    // Un texte seulement : une photo porte des métadonnées que le push
    // n'a pas, et le message rangé dans le cache doit être complet.
    if (me != null &&
        push.messageType == 'TEXT' &&
        push.isEncrypted &&
        push.ciphertext != null &&
        push.envelope != null) {
      return DirectMessage(
        id: push.messageId,
        senderId: push.senderId,
        recipientId: me,
        messageType: push.messageType,
        content: null,
        encryption: push.encryption,
        ciphertext: push.ciphertext,
        envelope: push.envelope,
        mediaAssetId: null,
        media: null,
        status: DirectMessageStatus.delivered,
        createdAt: push.sentAt.toUtc(),
      );
    }
    final json = await api.get('/messages/by-id/${push.messageId}');
    return DirectMessage.fromJson(json as Map<String, dynamic>);
  }

  /// Un bouton de la notification : « Répondre » ou « Marquer comme lu ».
  Future<void> onAction(
    String actionId,
    Map<String, dynamic> payload, {
    String? input,
  }) async {
    final groupId = int.tryParse(payload['group_id']?.toString() ?? '');
    final contactUserId = int.tryParse(payload['contact_user_id']?.toString() ?? '');
    final key = groupId != null ? 'group:$groupId' : 'contact:$contactUserId';
    if (groupId == null && contactUserId == null) return;

    if (actionId == kMarkReadActionId) {
      await _markRead(key, isGroup: groupId != null);
      await presenter.clear(key);
      return;
    }
    if (actionId != kReplyActionId) return;
    final text = input?.trim() ?? '';
    if (text.isEmpty) return;

    var sent = false;
    try {
      if (groupId != null) {
        await api.post('/groups/$groupId/messages', body: {'content': text});
        sent = true;
      } else {
        sent = await sendDirect(contactUserId!, text);
      }
    } catch (exc) {
      debugPrint('[Notif] Réponse impossible: $exc');
      await _appendOwnLine(key, payload, l.notifReplyFailed);
      return;
    }
    // Répondre, c'est avoir lu.
    if (sent) await _markRead(key, isGroup: groupId != null);
    await _appendOwnLine(key, payload, sent ? text : '$text · ${l.notifReplyQueued}');
  }

  /// Ce que l'on vient d'écrire s'ajoute au fil, comme sur WhatsApp — et
  /// la notification se met à jour sans sonner, ce qui retire aussi le
  /// sablier qu'Android affiche sur le champ de réponse.
  Future<void> _appendOwnLine(
    String key,
    Map<String, dynamic> payload,
    String text,
  ) async {
    final thread = await presenter.thread(key);
    final groupId = int.tryParse(payload['group_id']?.toString() ?? '');
    // Après le message auquel on répond, même si l'horloge du téléphone
    // retarde sur celle du serveur : la réponse ne doit pas remonter
    // au-dessus de la question.
    var at = DateTime.now();
    final last = thread?.lines.isEmpty ?? true ? null : thread!.lines.last.at;
    if (last != null && !at.isAfter(last)) {
      at = last.add(const Duration(milliseconds: 1));
    }
    final push = MessagePush(
      type: payload['type']?.toString() ?? 'message',
      messageId: 'me-${DateTime.now().microsecondsSinceEpoch}',
      senderId: 0,
      senderName: thread?.title ?? payload['contact_name']?.toString() ?? '',
      messageType: 'TEXT',
      sentAt: at,
      priority: null,
      muted: false,
      contactUserId: int.tryParse(payload['contact_user_id']?.toString() ?? ''),
      groupId: groupId,
      groupName: payload['group_name']?.toString(),
    );
    await presenter.add(
      push: push,
      title: thread?.title ?? push.senderName,
      line: ThreadLine(
        messageId: push.messageId,
        sender: l.notifMe,
        text: text,
        at: push.sentAt,
        fromMe: true,
      ),
      payload: thread?.payload ?? payload,
      alert: false,
    );
  }

  /// Les messages privés notifiés passent à « lu » chez l'expéditeur. Un
  /// groupe n'a pas d'accusé de lecture : effacer la notification suffit.
  Future<void> _markRead(String key, {required bool isGroup}) async {
    if (isGroup) return;
    final thread = await presenter.thread(key);
    if (thread == null) return;
    for (final line in thread.lines) {
      if (line.fromMe) continue;
      try {
        await messaging.markRead(line.messageId);
      } catch (exc) {
        debugPrint('[Notif] Accusé de lecture non envoyé: $exc');
      }
    }
  }
}

/// Les réponses privées écrites depuis une notification quand Pokou était
/// fermé, en attente de l'application pour être scellées et envoyées —
/// voir [MessageNotificationHandler].
class PendingReplies {
  PendingReplies({File? file}) : _file = file;

  File? _file;

  Future<File> _target() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    return _file = File('${dir.path}/pending_replies.json');
  }

  Future<List<Map<String, dynamic>>> _read() async {
    try {
      final file = await _target();
      if (!await file.exists()) return [];
      return [
        for (final item in jsonDecode(await file.readAsString()) as List)
          Map<String, dynamic>.from(item as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    final file = await _target();
    if (items.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(items), flush: true);
    await tmp.rename(file.path);
  }

  Future<void> add(int recipientId, String text) async {
    final items = await _read();
    items.add({
      'recipient_id': recipientId,
      'content': text,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await _write(items);
  }

  /// Envoie, dans l'ordre où elles ont été écrites, les réponses en
  /// attente. Celle qui échoue reste en attente avec les suivantes : une
  /// conversation ne doit pas recevoir ses réponses dans le désordre.
  Future<int> drain(Future<void> Function(int recipientId, String text) send) async {
    final items = await _read();
    var sent = 0;
    while (sent < items.length) {
      final item = items[sent];
      try {
        await send(item['recipient_id'] as int, item['content'] as String);
      } catch (exc) {
        debugPrint('[Notif] Réponse en attente non envoyée: $exc');
        break;
      }
      sent++;
    }
    if (sent > 0) await _write(items.sublist(sent));
    return sent;
  }
}
