import 'dart:convert';

import '../settings/app_settings.dart';
import 'active_conversation.dart';

/// Comment présenter une notification, une fois qu'elle est arrivée.
///
/// Le serveur a déjà tranché s'il fallait l'envoyer (voir
/// api/app/services/notification_policy.py). Ce qu'il ne peut pas savoir,
/// c'est ce que l'écran affiche à cet instant, ni ce que l'utilisateur a
/// coché dans Réglages › Notifications. C'est donc ici, et seulement ici,
/// qu'on décide de la forme.
enum NotificationPresentation {
  /// Rien du tout. La conversation est déjà ouverte, ou le type a été coupé
  /// dans les réglages.
  suppressed,

  /// Visible en ouvrant le volet, mais sans son ni vibration.
  silent,

  /// Le comportement ordinaire.
  standard,

  /// Bandeau qui s'impose — une mention, une réponse.
  heads_up,

  /// Prend l'écran : un appel entrant, et rien d'autre.
  fullScreen,
}

/// Le niveau d'interruption décidé par le serveur.
enum NotificationPriority { low, normal, high, urgent }

NotificationPriority parsePriority(String? value) => switch (value) {
      'low' => NotificationPriority.low,
      'high' => NotificationPriority.high,
      'urgent' => NotificationPriority.urgent,
      _ => NotificationPriority.normal,
    };

/// Décide de la présentation d'une notification reçue.
///
/// L'ordre des règles est le fond du sujet, pas un détail d'écriture :
///
/// 1. **Un appel d'abord.** Il passe avant les réglages et avant la
///    conversation ouverte. Couper « Appels » dans les réglages ne fait
///    taire que la bannière app ouverte ; l'écran d'appel entrant, lui,
///    arrive par le WebSocket et reste impossible à manquer.
/// 2. **La conversation ouverte ensuite.** Se notifier soi-même pendant
///    qu'on lit est le défaut le plus visible qu'une messagerie puisse
///    avoir.
/// 3. **Les réglages.** Ce que l'utilisateur a explicitement coupé.
/// 4. **La sourdine.** Elle rend silencieux, elle ne supprime pas : le
///    serveur a déjà écarté ce qui ne méritait pas d'arriver jusqu'ici.
NotificationPresentation decidePresentation({
  required String? type,
  required NotificationPriority priority,
  required bool muted,
  required int? contactUserId,
  required int? groupId,
  required ActiveConversation? active,
  required AppSettings settings,
}) {
  if (type == 'call') {
    return settings.callNotifications
        ? NotificationPresentation.fullScreen
        : NotificationPresentation.suppressed;
  }

  final isOpenConversation =
      active?.matches(contactUserId: contactUserId, groupId: groupId) ?? false;
  if (isOpenConversation) return NotificationPresentation.suppressed;

  final allowedBySettings = switch (type) {
    'group_message' || 'group_mention' => settings.groupNotifications,
    _ => settings.messageNotifications,
  };
  if (!allowedBySettings) return NotificationPresentation.suppressed;

  if (muted) return NotificationPresentation.silent;

  return switch (priority) {
    NotificationPriority.urgent => NotificationPresentation.fullScreen,
    NotificationPriority.high => NotificationPresentation.heads_up,
    NotificationPriority.low => NotificationPresentation.silent,
    NotificationPriority.normal => NotificationPresentation.standard,
  };
}

/// Sous quelle notification ranger celle-ci.
///
/// Un identifiant STABLE par conversation, et c'est tout l'intérêt : trois
/// messages de Kodjo remplacent la même notification au lieu d'en empiler
/// trois. Android affiche alors « Kodjo — 3 nouveaux messages » plutôt que
/// trois lignes qui repoussent le reste du volet.
int conversationNotificationId({int? contactUserId, int? groupId}) =>
    conversationNotificationKeyId(
      groupId != null ? 'group:$groupId' : 'contact:$contactUserId',
    );

/// L'identifiant réservé au résumé « Pokou · n conversations », hors de la
/// plage des conversations.
const kMessagesSummaryId = 0x7ffffff0;

/// L'identifiant de notification d'une clé de conversation.
///
/// FNV-1a, et non `String.hashCode` : Dart ne promet pas que ce dernier
/// reste le même d'un lancement à l'autre, ni d'un isolat à l'autre — or la
/// notification est publiée par l'isolat de Firebase quand l'application est
/// fermée, puis effacée par l'application quand on ouvre la conversation.
/// Deux identifiants différents, et elle ne disparaîtrait jamais.
int conversationNotificationKeyId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(key)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Positif et sous le résumé : un identifiant Android est un entier 32
  // bits signé.
  return hash % kMessagesSummaryId;
}
