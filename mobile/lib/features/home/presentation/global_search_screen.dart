import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../channels/data/channel_model.dart';
import '../../channels/presentation/channel_screen.dart';
import '../../contacts/data/conversation_summary.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../contacts/presentation/open_discussion.dart';
import '../../groups/data/group_model.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../../marketplace/data/product_model.dart';
import '../../marketplace/presentation/product_detail_screen.dart';
import '../../messaging/presentation/contact_card_bubble.dart'
    show extractFirstUrl;
import '../../messaging/presentation/conversation_screen.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Les puces de la recherche (Discussions · 22).
enum SearchScope { all, chats, messages, photos, links }

/// Un message trouvé — à deux ou en groupe, ramené à ce qu'une ligne montre.
class _Hit {
  const _Hit({
    required this.conversation,
    required this.text,
    required this.at,
    required this.messageType,
    this.contactUserId,
    this.groupId,
  });

  final String conversation;
  final String text;
  final DateTime at;
  final String messageType;
  final int? contactUserId;
  final int? groupId;
}

/// Discussions · 22 — Rechercher : discussions, messages, photos et liens.
///
/// Les MESSAGES se cherchent sur l'appareil (voir
/// PokouMessageStore.searchLocal) : chiffrés de bout en bout, ils ne sont
/// lisibles qu'ici. Les chaînes et le marché, publics, se cherchent sur le
/// serveur — et seulement là où ces modules sont ouverts.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  /// Recherches récentes de la session : un écran de recherche ne doit
  /// jamais s'ouvrir vide.
  static final List<String> _recent = [];

  late final TextEditingController _controller;
  Timer? _debounce;
  SearchScope _scope = SearchScope.all;
  String _query = '';
  List<_Hit> _hits = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _products = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _search(widget.initialQuery.trim()),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _hits = const [];
        _channels = const [];
        _products = const [];
      });
      return;
    }
    _recent
      ..remove(query)
      ..insert(0, query);
    if (_recent.length > 8) _recent.removeLast();
    setState(() {
      _query = query;
      _searching = true;
    });

    final names = _conversationNames();
    final found = await ref.read(pokouMessageStoreProvider).searchLocal(query);
    final myId = ref.read(authControllerProvider).user?.id;
    final hits = <_Hit>[
      for (final m in found.direct)
        _Hit(
          conversation:
              names['c${m.senderId == myId ? m.recipientId : m.senderId}'] ??
              '',
          text: m.content ?? '',
          at: m.createdAt,
          messageType: m.messageType,
          contactUserId: m.senderId == myId ? m.recipientId : m.senderId,
        ),
      for (final GroupMessage m in found.group)
        _Hit(
          conversation: names['g${m.groupId}'] ?? '',
          text: m.content ?? '',
          at: m.createdAt,
          messageType: m.messageType,
          groupId: m.groupId,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    // Chaînes et marché : publics, cherchés sur le serveur. Un échec réseau
    // n'efface pas ce que l'appareil a trouvé.
    var channels = const <Map<String, dynamic>>[];
    var products = const <Map<String, dynamic>>[];
    try {
      final api = ref.read(apiClientProvider);
      final encoded = Uri.encodeQueryComponent(query);
      final responses = await Future.wait([
        api.get('/channels/search?q=$encoded'),
        api.get('/marketplace?q=$encoded'),
      ]);
      channels = _items(responses[0]);
      products = _items(responses[1]);
    } catch (_) {}
    if (!mounted || _controller.text.trim() != query) return;
    setState(() {
      _hits = hits;
      _channels = channels;
      _products = products;
      _searching = false;
    });
  }

  /// `c<id de l'autre>` / `g<id du groupe>` → nom affiché dans la liste.
  Map<String, String> _conversationNames() {
    final discussions =
        ref.read(discussionsProvider).valueOrNull ??
        const <ConversationSummary>[];
    return {
      for (final d in discussions)
        if (d.kind == 'contact' && d.contactUserId != null)
          'c${d.contactUserId}': d.name
        else if (d.kind == 'group' && d.id != null)
          'g${d.id}': d.name,
    };
  }

  List<Map<String, dynamic>> _items(dynamic response) {
    final map = response as Map<String, dynamic>;
    return (map['items'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> _openHit(_Hit hit) async {
    final myId = ref.read(authControllerProvider).user?.id;
    if (myId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => hit.groupId != null
            ? GroupConversationScreen(
                myUserId: myId,
                groupId: hit.groupId!,
                groupName: hit.conversation,
              )
            : ConversationScreen(
                myUserId: myId,
                contactUserId: hit.contactUserId!,
                contactName: hit.conversation,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final needle = _query.toLowerCase();
    final chats = needle.isEmpty
        ? const <ConversationSummary>[]
        : (ref.watch(discussionsProvider).valueOrNull ?? const [])
              .where((d) => d.name.toLowerCase().contains(needle))
              .toList();
    final textHits = _hits.where((h) => h.messageType == 'TEXT').toList();
    final photoHits = _hits.where((h) => h.messageType == 'IMAGE').toList();
    final linkHits = _hits
        .where((h) => extractFirstUrl(h.text) != null)
        .toList();
    bool show(SearchScope scope) =>
        _scope == SearchScope.all || _scope == scope;

    final sections = <Widget>[
      if (show(SearchScope.chats) && chats.isNotEmpty) ...[
        _section(l.searchChatsSection),
        for (final d in chats)
          ListTile(
            leading: IdentityAvatar(
              userId: d.kind == 'contact' ? d.contactUserId : null,
              avatar: d.avatar,
              displayName: d.name,
              size: 40,
              showPresence: false,
              showStatusRing: false,
            ),
            title: Text(
              d.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: d.lastMessage == null
                ? null
                : Text(
                    l.searchLastMessage(d.lastMessage!.displayTextOf(l)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: d.lastMessage == null
                ? null
                : Text(
                    _date(d.lastMessage!.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
            onTap: () => openDiscussion(context, ref, d),
          ),
      ],
      for (final (scope, title, hits) in [
        (
          SearchScope.messages,
          l.searchMessagesSection(textHits.length),
          textHits,
        ),
        (
          SearchScope.photos,
          l.searchPhotosSection(photoHits.length),
          photoHits,
        ),
        (SearchScope.links, l.searchLinksSection(linkHits.length), linkHits),
      ])
        if (show(scope) &&
            hits.isNotEmpty &&
            // « Tout » ne répète pas sous Liens ce que Messages montre déjà.
            !(_scope == SearchScope.all && scope == SearchScope.links)) ...[
          _section(title),
          for (final hit in hits)
            ListTile(
              leading: IdentityAvatar(
                userId: hit.contactUserId,
                avatar: null,
                displayName: hit.conversation,
                size: 40,
                showPresence: false,
                showStatusRing: false,
              ),
              title: Text(
                hit.conversation,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                hit.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _date(hit.at),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              onTap: () => _openHit(hit),
            ),
        ],
      if (_scope == SearchScope.all && _channels.isNotEmpty) ...[
        _section(l.navBroadcasts),
        for (final item in _channels)
          Builder(
            builder: (context) {
              final channel = PokouChannel.fromJson(item);
              return ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(channel.name),
                subtitle: Text(channel.description ?? ''),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChannelScreen(channel: channel),
                  ),
                ),
              );
            },
          ),
      ],
      if (_scope == SearchScope.all && _products.isNotEmpty) ...[
        _section(l.marketTitle),
        for (final item in _products)
          Builder(
            builder: (context) {
              final product = MarketplaceProduct.fromJson(item);
              return ListTile(
                leading: const PokouIcon(PokouModuleIcon.assime),
                title: Text(product.name),
                subtitle: Text('${product.price} ${product.currency}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                ),
              );
            },
          ),
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (value) => _search(value.trim()),
          decoration: InputDecoration(
            hintText: l.homeSearchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (scope, label) in [
                  (SearchScope.all, l.searchScopeAll),
                  (SearchScope.chats, l.searchScopeChats),
                  (SearchScope.messages, l.searchScopeMessages),
                  (SearchScope.photos, l.searchScopePhotos),
                  (SearchScope.links, l.searchScopeLinks),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _scope == scope,
                    onSelected: (_) => setState(() => _scope = scope),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...sections,
                // Avant toute recherche : quoi chercher, et les récentes.
                if (_query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchIntro,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        if (_recent.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l.searchRecent,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final q in _recent)
                                ActionChip(
                                  avatar: const Icon(Icons.history, size: 16),
                                  label: Text(q),
                                  onPressed: () {
                                    _controller.text = q;
                                    _search(q);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_query.isNotEmpty && !_searching && sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(l.marketNoMatch)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// « 16:05 » aujourd'hui, « Hier », sinon « 28/10 ».
  String _date(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat.Hm().format(local);
    if (diff == 1) return L.of(context).dayYesterday;
    return DateFormat('dd/MM').format(local);
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textMuted,
      ),
    ),
  );
}
