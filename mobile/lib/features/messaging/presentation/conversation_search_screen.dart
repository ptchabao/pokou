import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/direct_message_model.dart';
import 'day_separator.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Les messages lisibles de [messages] qui contiennent [query] (casse
/// ignorée), du plus récent au plus ancien. Un message encore chiffré, ou
/// supprimé, ne compte pas : son « texte » n'est pas le sien.
List<DirectMessage> searchDecrypted(
  List<DirectMessage> messages,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return [
    for (final message in messages.reversed)
      if (!message.isEncrypted &&
          message.deletedAt == null &&
          (message.content ?? '').toLowerCase().contains(needle))
        message,
  ];
}

/// Recherche DANS une conversation — l'écran renvoie l'identifiant du message
/// choisi, que la conversation fait défiler jusqu'à lui (voir
/// `_scrollToMessage`, déjà utilisé pour les réponses citées) plutôt que de
/// rouvrir un second fil.
class ConversationSearchScreen extends ConsumerStatefulWidget {
  const ConversationSearchScreen({
    super.key,
    required this.contactUserId,
    required this.contactName,
  });

  final int contactUserId;
  final String contactName;

  @override
  ConsumerState<ConversationSearchScreen> createState() =>
      _ConversationSearchScreenState();
}

class _ConversationSearchScreenState
    extends ConsumerState<ConversationSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<DirectMessage>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Différé de 300 ms : relire le cache à chaque frappe ferait clignoter
  /// la liste avant la fin du mot.
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

  /// Cherche dans les messages DÉCHIFFRÉS gardés sur cet appareil.
  ///
  /// La recherche du serveur ne peut rien trouver dans une conversation
  /// chiffrée de bout en bout : il n'en a jamais lu un mot. C'était
  /// pourtant elle qu'interrogeait la loupe — d'où « aucun résultat », à
  /// chaque fois. Le cache local, lui, tient le clair.
  Future<void> _search(String query) async {
    try {
      final myUserId = ref.read(authControllerProvider).user?.id;
      if (myUserId == null) return;
      final cached = await ref
          .read(pokouMessageStoreProvider)
          .directConversation(
            myUserId: myUserId,
            contactUserId: widget.contactUserId,
          );
      final results = searchDecrypted(cached.messages, query);
      // Une réponse arrivée après un nouveau mot ne doit pas écraser la
      // recherche courante.
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
            hintText: L.of(context).convSearchHint(widget.contactName),
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_searching) const LinearProgressIndicator(),
          if (results == null && !_searching)
            Text(
              L.of(context).convSearchPrompt,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          if (results != null && results.isEmpty && !_searching)
            Text(
              L.of(context).convSearchEmpty,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (results != null)
            for (final message in results)
              _ResultTile(
                message: message,
                query: _controller.text.trim(),
                isMine: message.senderId != widget.contactUserId,
                contactName: widget.contactName,
                // On renvoie l'identifiant : c'est la conversation qui sait
                // faire défiler jusqu'à la bulle.
                onTap: () => Navigator.of(context).pop(message.id),
              ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.message,
    required this.query,
    required this.isMine,
    required this.contactName,
    required this.onTap,
  });

  final DirectMessage message;
  final String query;
  final bool isMine;
  final String contactName;
  final VoidCallback onTap;

  /// Met en évidence le terme cherché dans l'extrait — sans ça, retrouver
  /// pourquoi une ligne correspond demande de relire toute la phrase.
  List<TextSpan> _highlighted(String text) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start)
        spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.accentPrimaryDark,
          ),
        ),
      );
      start = index + query.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isMine ? L.of(context).callYou : contactName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dayLabel(L.of(context), message.createdAt)} · ${DateFormat.Hm().format(message.createdAt.toLocal())}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                children: _highlighted(message.content ?? ''),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
