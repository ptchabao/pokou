/// Nature d'une invitation extraite d'un lien entrant.
/// `bot` n'est pas une invitation à rejoindre : c'est l'ouverture d'une
/// conversation avec le bot d'une entreprise (`/bot/<handle>`), qui passe
/// par le même chemin — y compris l'attente de la connexion.
enum DeepLinkInviteKind {
  group,
  community,
  channel,
  bot,
  koryPot,
  koryJoin,
  honamOrder,
}

const pokouLinkHost = 'apipokou.cabinet-p-et-associes.com';
const pokouLinkBaseUrl = 'https://$pokouLinkHost';
const _legacyLinkHost = 'pok.app';

/// Intention extraite d'un lien — invitation, ouverture de ressource ou post.
class PendingInvite {
  const PendingInvite({
    required this.kind,
    required this.code,
    this.postId,
    this.resourceId,
  });

  final DeepLinkInviteKind kind;
  final String code;
  final int? postId;
  final int? resourceId;

  @override
  bool operator ==(Object other) =>
      other is PendingInvite &&
      other.kind == kind &&
      other.code == code &&
      other.postId == postId &&
      other.resourceId == resourceId;

  @override
  int get hashCode => Object.hash(kind, code, postId, resourceId);

  @override
  String toString() =>
      'PendingInvite(kind: $kind, code: $code, postId: $postId, resourceId: $resourceId)';
}

/// Extrait une intention d'un lien Pokou, ou `null` si l'URI ne correspond
/// à aucun format connu.
PendingInvite? parseInviteLink(Uri uri) {
  final host = uri.host.toLowerCase();
  if (uri.scheme != 'https' ||
      (host != pokouLinkHost && host != _legacyLinkHost)) {
    return null;
  }

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;

  // Lien de partage d'une cagnotte : /kory/join/{code}.
  if (segments.length == 3 && segments[0] == 'kory' && segments[1] == 'join') {
    final code = segments[2].trim();
    if (code.isEmpty) return null;
    return PendingInvite(kind: DeepLinkInviteKind.koryJoin, code: code);
  }
  final isKoryPot =
      (segments.length == 2 && segments[0] == 'kory') ||
      (segments.length == 3 && segments[0] == 'kory' && segments[1] == 'pots');
  final isHonamOrder =
      (segments.length == 3 &&
      segments[0] == 'honam' &&
      (segments[1] == 'order' || segments[1] == 'orders'));
  if (isKoryPot || isHonamOrder) {
    final id = segments.last;
    final resourceId = int.tryParse(id);
    if (resourceId == null || resourceId <= 0) return null;
    return PendingInvite(
      kind: isKoryPot
          ? DeepLinkInviteKind.koryPot
          : DeepLinkInviteKind.honamOrder,
      code: id,
      resourceId: resourceId,
    );
  }

  if (segments[0] == 'invite') {
    const canonicalKinds = {'group', 'community', 'channel'};
    if (segments.length >= 2 && canonicalKinds.contains(segments[1])) {
      if (segments.length < 3) return null;
      final kind = switch (segments[1]) {
        'group' => DeepLinkInviteKind.group,
        'channel' => DeepLinkInviteKind.channel,
        _ => DeepLinkInviteKind.community,
      };
      final code = segments[2];
      if (code.isEmpty) return null;

      // Cas publication de chaîne : /invite/channel/{code}/post/{id}
      int? postId;
      if (kind == DeepLinkInviteKind.channel &&
          segments.length >= 5 &&
          segments[3] == 'post') {
        postId = int.tryParse(segments[4]);
      }
      return PendingInvite(kind: kind, code: code, postId: postId);
    }
    if (segments.length == 2) {
      // Format historique (groupes uniquement) — voir group_model.dart::inviteLinkFor.
      final code = segments[1];
      return code.isEmpty
          ? null
          : PendingInvite(kind: DeepLinkInviteKind.group, code: code);
    }
    return null;
  }

  if (segments[0] == 'bot' && segments.length == 2) {
    final handle = segments[1].toLowerCase();
    return RegExp(r'^[a-z][a-z0-9_]{2,31}$').hasMatch(handle)
        ? PendingInvite(kind: DeepLinkInviteKind.bot, code: handle)
        : null;
  }

  if (segments[0] == 'c' && segments.length == 2) {
    // Format historique (communautés) — voir community_model.dart::communityInviteLinkFor.
    final code = segments[1];
    return code.isEmpty
        ? null
        : PendingInvite(kind: DeepLinkInviteKind.community, code: code);
  }

  if (segments[0] == 'channel') {
    if (segments.length >= 4 && segments[2] == 'post') {
      // Publication de chaîne : /channel/{code}/post/{id}
      final code = segments[1];
      final postId = int.tryParse(segments[3]);
      return code.isEmpty
          ? null
          : PendingInvite(
              kind: DeepLinkInviteKind.channel,
              code: code,
              postId: postId,
            );
    }
    if (segments.length == 2) {
      final code = segments[1];
      return code.isEmpty
          ? null
          : PendingInvite(kind: DeepLinkInviteKind.channel, code: code);
    }
  }

  return null;
}
