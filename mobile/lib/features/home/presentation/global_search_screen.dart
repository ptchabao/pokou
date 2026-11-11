import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../channels/data/channel_model.dart';
import '../../channels/presentation/channel_screen.dart';
import '../../marketplace/data/product_model.dart';
import '../../marketplace/presentation/product_detail_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_context_menu.dart';

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
  Map<String, List<Map<String, dynamic>>> _results = const {};
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _searching) return;
    _recent
      ..remove(query)
      ..insert(0, query);
    if (_recent.length > 8) _recent.removeLast();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final responses = await Future.wait([
        api.get('/messages/search?q=${Uri.encodeQueryComponent(query)}'),
        api.get('/channels/search?q=${Uri.encodeQueryComponent(query)}'),
        api.get('/marketplace?q=${Uri.encodeQueryComponent(query)}'),
      ]);
      if (!mounted) return;
      setState(() {
        _results = {
          'messages': _items(responses[0]),
          'channels': _items(responses[1]),
          'marketplace': _items(responses[2]),
        };
      });
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).modulesCheckNetwork);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<Map<String, dynamic>> _items(dynamic response) {
    final map = response as Map<String, dynamic>;
    return (map['items'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messageResults = _results['messages'] ?? const [];
    final channelResults = _results['channels'] ?? const [];
    final productResults = _results['marketplace'] ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.actionSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: l.homeSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: l.actionSearch,
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.semanticError),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (messageResults.isNotEmpty) ...[
                  _section(l.navChats),
                  for (final item in messageResults)
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text((item['content'] as String?) ?? ''),
                      subtitle: Text(l.navChats),
                      onTap: () {
                        final contactId = item['contact_user_id'] as int?;
                        final myId = ref.read(authControllerProvider).user?.id;
                        if (contactId == null || myId == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              myUserId: myId,
                              contactUserId: contactId,
                              contactName: l.navChats,
                            ),
                          ),
                        );
                      },
                    ),
                ],
                if (channelResults.isNotEmpty) ...[
                  _section(l.navBroadcasts),
                  for (final item in channelResults)
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
                if (productResults.isNotEmpty) ...[
                  _section(l.marketTitle),
                  for (final item in productResults)
                    Builder(
                      builder: (context) {
                        final product = MarketplaceProduct.fromJson(item);
                        return ListTile(
                          leading: const PokouIcon(PokouModuleIcon.assime),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.price} ${product.currency}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(product: product),
                            ),
                          ),
                        );
                      },
                    ),
                ],
                // Avant toute recherche : quoi chercher, et les récentes.
                if (_results.isEmpty && !_searching && _error == null)
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
                                    _search();
                                  },
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (!_searching &&
                    _error == null &&
                    _results.isNotEmpty &&
                    messageResults.isEmpty &&
                    channelResults.isEmpty &&
                    productResults.isEmpty)
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

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
