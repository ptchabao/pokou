import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/media_image.dart';
import '../../../l10n/app_localizations.dart';
import '../data/direct_message_model.dart';
import 'media_bubble.dart';

/// Ce qu'une conversation a échangé, rangé en trois : visuels, documents,
/// liens. Tiré des messages DÉCHIFFRÉS gardés sur cet appareil — le serveur
/// ne connaît ni la clé d'un fichier chiffré, ni le texte qui porte un lien.
class ConversationMediaIndex {
  const ConversationMediaIndex({
    required this.visuals,
    required this.documents,
    required this.links,
  });

  /// Photos et vidéos, la plus récente d'abord.
  final List<DirectMessage> visuals;

  /// Documents et notes vocales.
  final List<DirectMessage> documents;

  /// Liens cités, sans doublon, du plus récent au plus ancien.
  final List<({String url, DirectMessage message})> links;

  bool get isEmpty => visuals.isEmpty && documents.isEmpty && links.isEmpty;
}

final _urlPattern = RegExp(
  r'(https?://[^\s]+|www\.[^\s]+)',
  caseSensitive: false,
);

/// Range [messages] (dans n'importe quel ordre).
ConversationMediaIndex indexConversationMedia(List<DirectMessage> messages) {
  final sorted = [...messages]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final visuals = <DirectMessage>[];
  final documents = <DirectMessage>[];
  final links = <({String url, DirectMessage message})>[];
  final seen = <String>{};
  for (final message in sorted) {
    // Encore chiffré, supprimé, ou vue unique : rien de montrable ici.
    if (message.isEncrypted || message.deletedAt != null || message.viewOnce) {
      continue;
    }
    final media = message.media;
    if (media != null && message.pendingMedia == null) {
      switch (message.messageType) {
        case 'IMAGE':
        case 'VIDEO':
          visuals.add(message);
        case 'DOCUMENT':
        case 'AUDIO':
          documents.add(message);
      }
    }
    for (final match in _urlPattern.allMatches(message.content ?? '')) {
      final raw = match.group(0)!;
      final url = raw.startsWith('www.') ? 'https://$raw' : raw;
      if (seen.add(url)) links.add((url: url, message: message));
    }
  }
  return ConversationMediaIndex(
    visuals: visuals,
    documents: documents,
    links: links,
  );
}

final _mediaIndexProvider = FutureProvider.autoDispose
    .family<ConversationMediaIndex, ({int me, int contact})>((ref, key) async {
      final cached = await ref
          .read(pokouMessageStoreProvider)
          .directConversation(myUserId: key.me, contactUserId: key.contact);
      return indexConversationMedia(cached.messages);
    });

/// « ⋮ › Voir les médias » d'une discussion à deux.
class ConversationMediaScreen extends ConsumerWidget {
  const ConversationMediaScreen({
    super.key,
    required this.myUserId,
    required this.contactUserId,
    required this.contactName,
  });

  final int myUserId;
  final int contactUserId;
  final String contactName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final index = ref.watch(
      _mediaIndexProvider((me: myUserId, contact: contactUserId)),
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: Text(contactName),
          bottom: TabBar(
            tabs: [
              Tab(text: l.chatXMediaTabMedia),
              Tab(text: l.chatXMediaTabDocs),
              Tab(text: l.chatXMediaTabLinks),
            ],
          ),
        ),
        body: index.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.chatXMediaEmpty)),
          data: (index) => TabBarView(
            children: [
              _VisualsGrid(messages: index.visuals),
              _DocumentsList(messages: index.documents, myUserId: myUserId),
              _LinksList(links: index.links),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        L.of(context).chatXMediaEmpty,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _VisualsGrid extends StatelessWidget {
  const _VisualsGrid({required this.messages});

  final List<DirectMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const _Empty();
    final images = [
      for (final m in messages)
        if (m.messageType == 'IMAGE') m,
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final media = message.media!;
        if (message.messageType == 'VIDEO') {
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black),
                  body: Center(child: VideoMessageBubble(media: media)),
                ),
              ),
            ),
            child: Container(
              color: AppColors.surfaceElevated,
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_outline,
                size: 36,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => ImageViewer.open(
            context,
            images: [
              for (final image in images)
                ViewerImage(
                  full: MediaImage.meta(image.media!, fit: BoxFit.contain),
                  caption: image.content,
                ),
            ],
            initialIndex: images.indexOf(message).clamp(0, images.length - 1),
          ),
          child: MediaImage.meta(media, decodeWidth: 130),
        );
      },
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.messages, required this.myUserId});

  final List<DirectMessage> messages;
  final int myUserId;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const _Empty();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.senderId == myUserId;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
          ),
          child: message.messageType == 'AUDIO'
              ? AudioMessageBubble(
                  media: message.media!,
                  isMine: isMine,
                  mediaKey: message.mediaKey,
                )
              : DocumentMessageBubble(media: message.media!, isMine: isMine),
        );
      },
    );
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList({required this.links});

  final List<({String url, DirectMessage message})> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const _Empty();
    return ListView.builder(
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        return ListTile(
          leading: Icon(Icons.link, color: AppColors.accentPrimaryDark),
          title: Text(
            link.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.accentPrimaryDark),
          ),
          onTap: () => launchUrl(
            Uri.parse(link.url),
            mode: LaunchMode.externalApplication,
          ),
        );
      },
    );
  }
}
