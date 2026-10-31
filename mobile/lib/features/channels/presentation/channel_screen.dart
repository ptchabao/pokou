import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../messaging/data/direct_message_model.dart' show PollData;
import '../../messaging/presentation/contact_card_bubble.dart'
    show LinkifiedText, extractFirstUrl;
import '../../messaging/presentation/day_separator.dart';
import '../../messaging/presentation/link_preview_card.dart';
import '../../messaging/presentation/poll_bubble.dart';
import '../data/channel_model.dart';
import '../../../core/widgets/skeleton.dart';
import 'channel_avatar.dart';
import 'channel_controller.dart';
import 'channel_editor_screen.dart';
import '../../../core/widgets/media_image.dart';

/// Écran d'une chaîne — le fil de ses publications, façon chaînes WhatsApp :
/// diffusion à SENS UNIQUE. Les abonnés lisent et réagissent par emoji, ils
/// ne répondent pas ; seuls le créateur et ses admins publient.
///
/// Lisible SANS être abonné : on juge une chaîne sur son contenu avant de la
/// suivre (l'API l'autorise explicitement, voir channels.py::list_posts).
class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({
    super.key,
    required this.channel,
    this.targetPostId,
  });

  final PokouChannel channel;
  final int? targetPostId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  late PokouChannel _channel;
  List<ChannelPost>? _posts;
  String? _error;
  bool _busy = false;

  /// Publications dont la vue a déjà été signalée pendant cette session —
  /// l'API est idempotente, mais rappeler l'endpoint à chaque reconstruction
  /// de la liste serait un aller-retour réseau par défilement.
  final Set<String> _viewReported = {};

  final _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _realtime;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _loadPosts();

    // Une publication qui arrive pendant qu'on lit la chaîne doit apparaître
    // sous les yeux, comme un message. On filtre sur l'identifiant de CETTE
    // chaîne : sans ça, une publication dans une autre rechargerait celle-ci
    // pour rien.
    _realtime = ref.read(wsClientProvider).events.listen((event) {
      if (event['type'] != 'channel:post') return;
      if (event['channel_id'] != _channel.id) return;
      _loadPosts();
    });
  }

  @override
  void dispose() {
    _realtime?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _error = null);
    try {
      final posts = await ref
          .read(channelRepositoryProvider)
          .posts(_channel.id);
      if (!mounted) return;
      // Déjà dans l'ordre du temps — voir channel_repository.posts. L'écran
      // les empile donc de haut en bas comme une conversation, et se cale
      // sur la dernière.
      setState(() => _posts = posts);
      _scrollToBottom();
    } catch (_) {
      if (mounted)
        setState(() => _error = L.of(context).channelPostsUnavailable);
    }
  }

  /// Ouvre — et rouvre — sur la dernière publication.
  ///
  /// `jumpTo` et non `animateTo` : au premier chargement il n'y a rien à
  /// suivre des yeux, et voir le fil défiler tout seul depuis le haut ferait
  /// croire à un geste qu'on n'a pas fait. Le saut est invisible parce qu'il
  /// arrive avant la première image montrée.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _toggleFollow() async {
    setState(() => _busy = true);
    try {
      final following = !_channel.isFollowing;
      final updated = await ref
          .read(channelRepositoryProvider)
          .setFollowing(_channel.id, following);
      // `null` : hors ligne, le geste partira à la reconnexion. On montre
      // déjà l'état voulu plutôt qu'une erreur pour un geste qui aboutira.
      if (mounted) {
        setState(() => _channel = updated ?? _channel.withFollowing(following));
      }
      if (updated != null) ref.invalidate(myChannelsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).chatsActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportView(ChannelPost post) async {
    if (_viewReported.contains(post.id)) return;
    _viewReported.add(post.id);
    try {
      await ref
          .read(channelRepositoryProvider)
          .markViewed(channelId: _channel.id, postId: post.id);
    } catch (_) {
      // Best-effort : un compteur de vues manqué ne doit rien interrompre.
      _viewReported.remove(post.id);
    }
  }

  /// Le vote renvoie l'état complet du sondage : on le fusionne dans la
  /// publication concernée au lieu de recharger tout le fil — sinon voter
  /// ferait sauter le défilement à chaque voix.
  void _applyVote(ChannelPost post, PollData updated) {
    final posts = _posts;
    if (posts == null) return;
    setState(() {
      _posts = [
        for (final item in posts)
          if (item.id == post.id) item.withPoll(updated) else item,
      ];
    });
  }

  Future<void> _react(ChannelPost post, String emoji) async {
    try {
      final repository = ref.read(channelRepositoryProvider);
      // Toucher la réaction déjà posée la RETIRE — même geste pour mettre et
      // enlever, comme dans WhatsApp.
      final removing = post.myReaction?.emoji == emoji;
      final queued = removing
          ? await repository.removeReaction(
              channelId: _channel.id,
              postId: post.id,
            )
          : await repository.react(
              channelId: _channel.id,
              postId: post.id,
              emoji: emoji,
            );
      if (!queued) {
        await _loadPosts();
        return;
      }
      // Hors ligne : relire le fil échouerait. On pose la réaction sur la
      // publication affichée, comme le serveur le fera à la reconnexion.
      final posts = _posts;
      if (posts == null || !mounted) return;
      setState(() {
        _posts = [
          for (final item in posts)
            if (item.id == post.id)
              item.withMyReaction(removing ? null : emoji)
            else
              item,
        ];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelReactionFailed)),
        );
      }
    }
  }

  Future<void> _publish() async {
    final result = await showModalBottomSheet<_DraftPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => _PostComposer(channelId: _channel.id),
    );
    if (result == null) return;
    try {
      await ref
          .read(channelRepositoryProvider)
          .publish(
            channelId: _channel.id,
            textContent: result.text,
            mediaAssetId: result.mediaAssetId,
            pollQuestion: result.pollQuestion,
            pollOptions: result.pollOptions,
            pollAllowsMultiple: result.pollAllowsMultiple,
          );
      await _loadPosts();
      ref.invalidate(myChannelsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelPostFailed)),
        );
      }
    }
  }

  Future<void> _editPost(ChannelPost post) async {
    final controller = TextEditingController(text: post.textContent ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).channelEditPost),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(L.of(context).actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await ref
          .read(channelRepositoryProvider)
          .editPost(channelId: _channel.id, postId: post.id, textContent: text);
      await _loadPosts();
    } catch (_) {
      if (mounted) {
        // 409 côté API : au-delà de 15 minutes, une publication n'est plus
        // modifiable (même règle que pour un message).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelEditTooOld)),
        );
      }
    }
  }

  Future<void> _deletePost(ChannelPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).channelDeletePost),
        content: Text(L.of(context).channelDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(channelRepositoryProvider)
          .deletePost(channelId: _channel.id, postId: post.id);
      await _loadPosts();
      ref.invalidate(myChannelsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelDeleteFailed)),
        );
      }
    }
  }

  Future<void> _openEditor() async {
    final updated = await Navigator.of(context).push<PokouChannel>(
      MaterialPageRoute(builder: (_) => ChannelEditorScreen(channel: _channel)),
    );
    if (updated != null && mounted) {
      setState(() => _channel = updated);
      ref.invalidate(myChannelsProvider);
    }
  }

  Future<void> _shareOrCopyInviteLink() async {
    try {
      final link = await ref
          .read(channelRepositoryProvider)
          .regenerateInviteLink(_channel.id);
      if (!mounted) return;

      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share_outlined, color: AppColors.accentPrimaryDark),
                title: Text(L.of(context).actionShare),
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              ListTile(
                leading: Icon(Icons.copy, color: AppColors.accentPrimaryDark),
                title: Text(L.of(context).groupCopyLink),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || action == null) return;

      if (action == 'share') {
        await Share.share(
          '${_channel.name} — Suivez notre chaîne sur Pokou Messenger : $link',
          subject: _channel.name,
        );
      } else if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.of(context).channelLinkCopied)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelLinkUnavailable)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Flexible(
              child: Text(
                _channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_channel.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.verified,
                size: 16,
                color: AppColors.accentPrimary,
              ),
            ],
          ],
        ),
        actions: [
          if (_channel.isAdmin)
            IconButton(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
              tooltip: L.of(context).channelEdit,
            ),
          IconButton(
            onPressed: _shareOrCopyInviteLink,
            icon: const Icon(Icons.share_outlined),
            tooltip: L.of(context).actionShare,
          ),
        ],
      ),
      floatingActionButton: _channel.isAdmin
          ? FloatingActionButton(
              onPressed: _publish,
              backgroundColor: AppColors.accentPrimary,
              tooltip: L.of(context).channelPublish,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            _ChannelHeader(
              channel: _channel,
              busy: _busy,
              onToggleFollow: _toggleFollow,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.semanticError),
              ),
            if (posts == null && _error == null) const _PostListSkeleton(),
            if (posts != null && posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _channel.isAdmin
                      ? L.of(context).channelNothingPublishedAdmin
                      : L.of(context).channelNothingPublished,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            if (posts != null)
              for (var index = 0; index < posts.length; index++) ...[
                // Séparateur de journée, comme dans une conversation : le fil
                // étant chronologique, on compare avec la publication qui
                // précède, c'est-à-dire la plus ancienne des deux.
                if (index == 0 ||
                    isDifferentDay(
                      posts[index - 1].createdAt,
                      posts[index].createdAt,
                    ))
                  DaySeparator(instant: posts[index].createdAt),
                _PostCard(
                  post: posts[index],
                  canManage: _channel.isAdmin,
                  channelName: _channel.name,
                  channelInviteCode: _channel.inviteCode,
                  onVisible: () => _reportView(posts[index]),
                  onReact: (emoji) => _react(posts[index], emoji),
                  onPollVoted: (updated) => _applyVote(posts[index], updated),
                  onEdit: () => _editPost(posts[index]),
                  onDelete: () => _deletePost(posts[index]),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// L'attente du fil d'une chaîne : deux cartes de publication vides.
///
/// Deux et pas cinq — une carte est haute, et en promettre plus que ce qui
/// tient à l'écran ferait apparaître un fil long là où la chaîne n'a
/// peut-être publié qu'une fois.
class _PostListSkeleton extends StatelessWidget {
  const _PostListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 120, radius: 10),
                  SizedBox(height: 12),
                  SkeletonBox(width: double.infinity, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 200, height: 12),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      SkeletonBox(width: 64, height: 11),
                      Spacer(),
                      SkeletonBox(width: 44, height: 22, radius: 11),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelHeader extends ConsumerWidget {
  const _ChannelHeader({
    required this.channel,
    required this.busy,
    required this.onToggleFollow,
  });

  final PokouChannel channel;
  final bool busy;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Même widget que dans les listes : l'image résolue une fois et
        // gardée dans son `State`. L'ancienne version reconstruisait un
        // `FutureBuilder` à chaque `build()` — dans une ListView qui se
        // reconstruit au moindre défilement, la résolution repartait de zéro
        // sans jamais aboutir.
        ChannelAvatar(channel: channel, size: 72),
        const SizedBox(height: 10),
        Text(
          '${L.of(context).channelFollowers(channel.followerCount)} · '
          '${L.of(context).channelPosts(channel.postCount)}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (channel.description != null &&
            channel.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            channel.description!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        // Le créateur reste admin même désabonné (voir channels.py::_is_admin) :
        // le bouton lui sert donc juste à sortir la chaîne de sa liste.
        SizedBox(
          width: 180,
          child: channel.isFollowing
              ? OutlinedButton.icon(
                  onPressed: busy ? null : onToggleFollow,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(L.of(context).channelFollowing),
                )
              : FilledButton(
                  onPressed: busy ? null : onToggleFollow,
                  child: Text(L.of(context).channelFollow),
                ),
        ),
      ],
    );
  }
}

/// Réactions proposées — les mêmes que sur les messages, pour que le geste
/// soit le même partout dans l'app.
const _quickReactions = ['👍', '❤️', '🔥', '😂', '😮', '🙏'];

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.canManage,
    this.channelName,
    this.channelInviteCode,
    required this.onVisible,
    required this.onReact,
    required this.onPollVoted,
    required this.onEdit,
    required this.onDelete,
  });

  final ChannelPost post;
  final bool canManage;
  final String? channelName;
  final String? channelInviteCode;
  final VoidCallback onVisible;
  final ValueChanged<String> onReact;
  final ValueChanged<PollData> onPollVoted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  @override
  void initState() {
    super.initState();
    // Construite = affichée : c'est le signal de vue le plus simple qui soit
    // juste ici, la liste ne construisant que ce qui entre à l'écran.
    widget.onVisible();
  }

  /// `null` quand le texte ne cite aucun lien — la carte d'aperçu se charge
  /// elle-même du reste (elle reste invisible si le lien ne se laisse pas
  /// résumer, voir LinkPreviewCard).
  Widget? _previewFor(String text) {
    final url = extractFirstUrl(text);
    return url == null ? null : LinkPreviewCard(url: url);
  }

  /// Partager la publication vers d'autres applications avec son texte et son lien profond.
  void _sharePost() {
    final post = widget.post;
    final inviteCode = widget.channelInviteCode;
    final url = inviteCode != null ? channelPostLinkFor(inviteCode, post.id) : null;
    final buffer = StringBuffer();
    if (widget.channelName != null) {
      buffer.writeln('${widget.channelName} sur Pokou Messenger :');
    }
    if (post.textContent != null && post.textContent!.trim().isNotEmpty) {
      buffer.writeln(post.textContent!.trim());
    }
    if (url != null) {
      buffer.writeln();
      buffer.write(url);
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      unawaited(Share.share(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final mine = post.myReaction;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.media != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _ChannelMedia(media: post.media!, height: 200),
            ),
            const SizedBox(height: 10),
          ],
          if (post.textContent != null) ...[
            // Même rendu que le texte d'un message : liens et numéros
            // tappables, *gras*/_italique_/~barré~ — une publication de
            // chaîne est du texte lu par des humains, il n'y a pas de raison
            // qu'il se comporte autrement ici que dans une conversation.
            LinkifiedText(
              text: post.textContent!,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.chatTextReceived,
              ),
            ),
            // Aperçu du premier lien cité, comme dans une conversation. Pas
            // d'aperçu quand la publication porte déjà une image : c'est elle
            // le contenu visuel, une carte en plus ferait doublon (même règle
            // que conversation_screen.dart).
            if (post.media == null) ?_previewFor(post.textContent!),
            const SizedBox(height: 8),
          ],
          if (post.poll != null)
            // Exactement la bulle de sondage des conversations : même route
            // de vote, même barre de progression, même bascule pour se
            // rétracter. Elle n'affiche que des comptes, jamais des noms —
            // ce qui la rend utilisable telle quelle sur une chaîne, où la
            // liste des votants est volontairement masquée.
            PollBubble(poll: post.poll!, onVoted: widget.onPollVoted),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                DateFormat.Hm().format(post.createdAt.toLocal()),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              if (post.wasEdited) ...[
                const SizedBox(width: 4),
                Text(
                  L.of(context).channelEdited,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.visibility_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                '${post.viewCount}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const Spacer(),
              InkWell(
                onTap: _sharePost,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.share_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (widget.canManage) ...[
                InkWell(
                  onTap: widget.onEdit,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColors.semanticError,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final emoji in _quickReactions)
                _ReactionChip(
                  emoji: emoji,
                  count: post.reactions
                      .where((reaction) => reaction.emoji == emoji)
                      .fold<int>(
                        0,
                        (total, reaction) => total + reaction.count,
                      ),
                  selected: mine?.emoji == emoji,
                  onTap: () => widget.onReact(emoji),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentPrimaryLight.withValues(alpha: 0.25)
              : AppColors.surfaceElevated,
          borderRadius: AppRadius.chip,
          border: selected ? Border.all(color: AppColors.accentPrimary) : null,
        ),
        child: Text(
          count == 0 ? emoji : '$emoji $count',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// Ce que le compositeur rapporte : le texte et la pièce jointe DÉJÀ
/// téléversée (même approche que l'éditeur de produit — l'envoi part au choix
/// de l'image, pas au moment de publier).
class _DraftPost {
  const _DraftPost({
    this.text,
    this.mediaAssetId,
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollAllowsMultiple = false,
  });

  final String? text;
  final int? mediaAssetId;
  final String? pollQuestion;
  final List<String> pollOptions;
  final bool pollAllowsMultiple;
}

class _PostComposer extends ConsumerStatefulWidget {
  const _PostComposer({required this.channelId});

  final int channelId;

  @override
  ConsumerState<_PostComposer> createState() => _PostComposerState();
}

/// Plafond d'options aligné sur polls.py::_MAX_OPTIONS. C'est le SERVEUR qui
/// tranche (il refuse au-delà) ; ici on empêche seulement d'ajouter un champ
/// de plus, pour ne pas laisser composer un sondage voué à être refusé.
const _kMaxPollOptions = 12;

class _PostComposerState extends ConsumerState<_PostComposer> {
  final _controller = TextEditingController();
  MediaMeta? _media;
  bool _uploading = false;

  /// Mode sondage — replié par défaut : l'immense majorité des publications
  /// est un texte ou une image, le formulaire de sondage n'a pas à occuper
  /// l'écran de tout le monde.
  bool _pollMode = false;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _pollMultiple = false;

  @override
  void dispose() {
    _controller.dispose();
    _pollQuestion.dispose();
    for (final option in _pollOptions) {
      option.dispose();
    }
    super.dispose();
  }

  /// Un sondage exige une question ET deux vraies réponses — un champ vide
  /// laissé en fin de liste ne compte pas (le serveur applique la même règle,
  /// voir polls.py::_clean_options).
  bool get _pollReady {
    if (!_pollMode) return false;
    final filled = _pollOptions
        .where((option) => option.text.trim().isNotEmpty)
        .length;
    return _pollQuestion.text.trim().isNotEmpty && filled >= 2;
  }

  void _addOption() {
    if (_pollOptions.length >= _kMaxPollOptions) return;
    setState(() => _pollOptions.add(TextEditingController()));
  }

  void _removeOption(int index) {
    // Jamais en dessous de deux : un sondage à une réponse ne propose pas de
    // choix. Le contrôleur retiré est libéré tout de suite.
    if (_pollOptions.length <= 2) return;
    setState(() => _pollOptions.removeAt(index).dispose());
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: picked.name,
            mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
            messageType: 'IMAGE',
          );
      if (mounted) {
        setState(
          () => _media = MediaMeta(
            id: uploaded.id,
            mimeType: uploaded.mimeType,
            sizeBytes: uploaded.sizeBytes,
            originalFilename: picked.name,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelImageFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        _controller.text.trim().isNotEmpty || _media != null || _pollReady;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).channelNewPost,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_media != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _ChannelMedia(media: _media!, height: 140),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _media = null),
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black54,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 2,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: L.of(context).channelPostHint,
            ),
          ),
          const SizedBox(height: 10),
          if (_pollMode) ...[
            TextField(
              controller: _pollQuestion,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: L.of(context).pollQuestion,
                prefixIcon: Icon(Icons.bar_chart, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _pollOptions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pollOptions[index],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: L.of(context).pollAnswerN(index + 1),
                        ),
                      ),
                    ),
                    // Pas de croix sur les deux premières : elles ne peuvent
                    // pas être retirées, un bouton inerte ne ferait qu'égarer.
                    if (_pollOptions.length > 2)
                      IconButton(
                        onPressed: () => _removeOption(index),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textMuted,
                        ),

                        tooltip: L.of(context).actionClose,
                      ),
                  ],
                ),
              ),
            if (_pollOptions.length < _kMaxPollOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(L.of(context).pollAddAnswer),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pollMultiple,
              onChanged: (value) => setState(() => _pollMultiple = value),
              title: Text(
                L.of(context).pollMultiple,
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _uploading
                      ? L.of(context).commonSending
                      : L.of(context).pollAddImage,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _pollMode = !_pollMode),
                icon: Icon(_pollMode ? Icons.close : Icons.bar_chart, size: 18),
                label: Text(
                  _pollMode ? L.of(context).pollRemove : L.of(context).pollOne,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton(
            // Bloqué pendant l'envoi : publier maintenant partirait sans
            // l'image en cours de téléversement.
            onPressed: (!hasContent || _uploading)
                ? null
                : () => Navigator.pop(
                    context,
                    _DraftPost(
                      text: _controller.text.trim(),
                      mediaAssetId: _media?.id,
                      pollQuestion: _pollReady
                          ? _pollQuestion.text.trim()
                          : null,
                      pollOptions: _pollReady
                          ? [
                              for (final option in _pollOptions)
                                if (option.text.trim().isNotEmpty)
                                  option.text.trim(),
                            ]
                          : const [],
                      pollAllowsMultiple: _pollMultiple,
                    ),
                  ),
            child: Text(L.of(context).channelPublish),
          ),
        ],
      ),
    );
  }
}

/// Média d'une chaîne servi par l'API authentifiée (jamais d'URL publique),
/// donc résolu en fichier local comme les pièces jointes de conversation.
class _ChannelMedia extends ConsumerWidget {
  const _ChannelMedia({required this.media, this.height});

  final MediaMeta media;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: MediaImage.meta(
        media,
        // Pleine largeur : le palier 1080 suffit, l'original pèse dix fois plus.
        decodeWidth: 420,
      ),
    );
  }
}
