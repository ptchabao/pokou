import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../data/channel_model.dart';
import 'channel_controller.dart';
import 'channel_screen.dart';
import 'channel_avatar.dart';
import 'channel_skeletons.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Recherche de chaînes — une chaîne est PUBLIQUE : on la trouve et on la lit
/// sans y être abonné, contrairement à un groupe dont l'existence même n'est
/// pas consultable.
class ChannelSearchScreen extends ConsumerStatefulWidget {
  const ChannelSearchScreen({super.key});

  @override
  ConsumerState<ChannelSearchScreen> createState() =>
      _ChannelSearchScreenState();
}

class _ChannelSearchScreenState extends ConsumerState<ChannelSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PokouChannel>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Recherche différée de 300 ms : une requête par frappe saturerait l'API
  /// et ferait clignoter la liste avant même la fin du mot.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    try {
      final results = await ref.read(channelRepositoryProvider).search(query);
      // Une réponse arrivée après que le champ a changé ne doit pas écraser
      // la recherche courante.
      if (mounted && _controller.text.trim() == query) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _open(PokouChannel channel) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChannelScreen(channel: channel)));
    // L'abonnement a pu changer dans l'écran de la chaîne.
    if (mounted && _controller.text.trim().isNotEmpty)
      _search(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: L.of(context).channelSearchHint,
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
              icon: const Icon(Icons.close),

              tooltip: L.of(context).actionClose,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Un squelette tant qu'il n'y a RIEN à montrer. Ensuite, la
          // barre fine : remplacer des résultats déjà lisibles par des
          // formes grises à chaque frappe serait un clignotement, pas une
          // attente — on garde la liste précédente le temps de la
          // remplacer.
          if (_searching && results == null) const ChannelListSkeleton(),
          if (_searching && results != null) const LinearProgressIndicator(),
          if (results == null && !_searching)
            Text(
              L.of(context).channelSearchPrompt,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          if (results != null && results.isEmpty && !_searching)
            Text(
              L.of(context).channelSearchEmpty,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (results != null)
            for (final channel in results)
              _SearchResultTile(channel: channel, onTap: () => _open(channel)),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.channel, required this.onTap});

  final PokouChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: [
            ChannelAvatar(channel: channel),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: AppColors.accentPrimary,
                        ),
                      ],
                    ],
                  ),
                  if (channel.description != null &&
                      channel.description!.trim().isNotEmpty)
                    Text(
                      channel.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    L.of(context).channelFollowers(channel.followerCount),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (channel.isFollowing)
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
