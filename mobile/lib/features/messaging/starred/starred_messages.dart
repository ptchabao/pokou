import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../pins/pinned_banner.dart';
import '../presentation/conversation_screen.dart';

/// « Marquer comme important » — l'étoile de WhatsApp.
///
/// Propre à chaque personne et gardée SUR LE TÉLÉPHONE seulement (table
/// `starred_messages` du cache local, voir PokouMessageStore) : c'est une
/// préférence personnelle dont le serveur n'a pas besoin, et le texte à
/// relire n'existe en clair qu'ici de toute façon.

class StarKey {
  const StarKey(this.scope, this.conversationId);

  final StarScope scope;
  final int conversationId;

  @override
  bool operator ==(Object other) =>
      other is StarKey &&
      other.scope == scope &&
      other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(scope, conversationId);
}

/// Les messages marqués importants d'une discussion.
class StarredController extends StateNotifier<Set<String>> {
  StarredController(this._store, this.key) : super(const {}) {
    _load();
  }

  final PokouMessageStore _store;
  final StarKey key;

  Future<void> _load() async {
    try {
      final ids = await _store.starredIds(key.scope, key.conversationId);
      if (mounted) state = ids;
    } catch (_) {
      // Cache illisible : pas d'étoiles plutôt qu'un écran cassé.
    }
  }

  /// Bascule l'étoile. L'écran change tout de suite ; l'écriture suit.
  Future<void> toggle(String messageId, {required String conversationName}) =>
      set(
        messageId,
        starred: !state.contains(messageId),
        conversationName: conversationName,
      );

  /// Marque ou démarque explicitement — c'est ce qu'utilise la liste des
  /// importants, qui sait ce qu'elle veut sans dépendre d'un état chargé.
  Future<void> set(
    String messageId, {
    required bool starred,
    required String conversationName,
  }) async {
    state = starred ? {...state, messageId} : state.difference({messageId});
    await _store.setStarred(
      messageId: messageId,
      scope: key.scope,
      conversationId: key.conversationId,
      conversationName: conversationName,
      starred: starred,
    );
    // Relu après l'écriture : un chargement initial encore en vol ne doit
    // pas laisser l'écran sur l'état d'avant.
    await _load();
  }
}

final starredControllerProvider = StateNotifierProvider.autoDispose
    .family<StarredController, Set<String>, StarKey>(
      (ref, key) =>
          StarredController(ref.watch(pokouMessageStoreProvider), key),
    );

/// La petite étoile à côté de l'heure d'une bulle.
class StarredMark extends StatelessWidget {
  const StarredMark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        label: L.of(context).msgStarA11y,
        child: Icon(Icons.star_rounded, size: 13, color: color),
      ),
    );
  }
}

/// L'écran « Messages importants ».
///
/// Ouvert depuis une discussion ([conversationId] renseigné), il ne montre
/// qu'elle, et toucher un message REVIENT à la discussion avec son
/// identifiant — l'écran appelant défile jusqu'à lui, comme pour la
/// recherche. Ouvert depuis « Plus », il montre tout et ouvre la
/// discussion au message.
class StarredMessagesScreen extends ConsumerStatefulWidget {
  const StarredMessagesScreen({
    super.key,
    required this.myUserId,
    this.scope,
    this.conversationId,
  });

  final int myUserId;
  final StarScope? scope;
  final int? conversationId;

  @override
  ConsumerState<StarredMessagesScreen> createState() =>
      _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends ConsumerState<StarredMessagesScreen> {
  late Future<List<StarredEntry>> _entries = _load();

  Future<List<StarredEntry>> _load() => ref
      .read(pokouMessageStoreProvider)
      .starredMessages(
        scope: widget.scope,
        conversationId: widget.conversationId,
      );

  Future<void> _unstar(StarredEntry entry) async {
    await ref
        .read(
          starredControllerProvider(
            StarKey(entry.scope, entry.conversationId),
          ).notifier,
        )
        .set(
          entry.messageId,
          starred: false,
          conversationName: entry.conversationName,
        );
    if (mounted) {
      setState(() {
        _entries = _load();
      });
    }
  }

  Future<void> _open(StarredEntry entry) async {
    if (widget.conversationId != null) {
      Navigator.of(context).pop(entry.messageId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => entry.scope == StarScope.group
            ? GroupConversationScreen(
                myUserId: widget.myUserId,
                groupId: entry.conversationId,
                groupName: entry.conversationName,
                initialMessageId: entry.messageId,
              )
            : ConversationScreen(
                myUserId: widget.myUserId,
                contactUserId: entry.conversationId,
                contactName: entry.conversationName,
                initialMessageId: entry.messageId,
              ),
      ),
    );
    if (mounted) {
      setState(() {
        _entries = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(l.msgStarTitle),
      ),
      body: FutureBuilder<List<StarredEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <StarredEntry>[];
          if (entries.isEmpty) {
            return StarredEmptyState(message: l.msgStarEmpty);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.msgStarOnlyHere,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              final entry = entries[index];
              return StarredMessageTile(
                entry: entry,
                myUserId: widget.myUserId,
                showConversation: widget.conversationId == null,
                onTap: () => _open(entry),
                onUnstar: () => _unstar(entry),
              );
            },
          );
        },
      ),
    );
  }
}

class StarredEmptyState extends StatelessWidget {
  const StarredEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de la liste : auteur (et discussion), date, texte déchiffré.
class StarredMessageTile extends StatelessWidget {
  const StarredMessageTile({
    super.key,
    required this.entry,
    required this.myUserId,
    required this.showConversation,
    required this.onTap,
    required this.onUnstar,
  });

  final StarredEntry entry;
  final int myUserId;
  final bool showConversation;
  final VoidCallback onTap;
  final VoidCallback onUnstar;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final direct = entry.direct;
    final group = entry.group;
    final senderId = direct?.senderId ?? group?.senderId;
    final author = senderId == myUserId
        ? l.navYou
        : (group?.senderName ?? entry.conversationName);
    final excerpt = messageExcerpt(
      l,
      content: direct?.content ?? group?.content,
      messageType: direct?.messageType ?? group?.messageType,
      locked: direct?.isEncrypted ?? group?.isEncrypted ?? false,
    );
    final createdAt = (direct?.createdAt ?? group?.createdAt)?.toLocal();
    final locale = Localizations.localeOf(context).languageCode;
    return ListTile(
      onTap: onTap,
      title: Text(
        showConversation &&
                (entry.scope == StarScope.group || senderId == myUserId)
            ? l.msgStarFrom(author, entry.conversationName)
            : author,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat.yMMMd(locale).add_Hm().format(createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.star_rounded, color: AppColors.accentPrimary),
        tooltip: l.msgStarRemove,
        onPressed: onUnstar,
      ),
    );
  }
}
