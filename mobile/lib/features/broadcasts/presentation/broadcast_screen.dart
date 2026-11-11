import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chat_wallpaper.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../data/broadcast_model.dart';
import 'broadcast_controller.dart';
import 'broadcast_editor_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// La conversation d'une liste de diffusion — vue par son auteur seul.
///
/// Elle ressemble à une discussion, et c'est voulu : on y compose comme
/// ailleurs. Mais rien de ce qui s'y affiche n'est partagé — c'est le
/// journal de ce qui est parti, pas un lieu où quelqu'un pourrait répondre.
/// Les réponses, elles, arrivent dans les conversations privées habituelles.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key, required this.broadcast});

  final BroadcastList broadcast;

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  late BroadcastList _broadcast = widget.broadcast;
  final _inputController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final result = await ref
          .read(broadcastRepositoryProvider)
          .send(listId: _broadcast.id, content: text);
      _inputController.clear();
      ref.invalidate(broadcastMessagesProvider(_broadcast.id));
      if (!mounted) return;
      // On dit le chiffre RÉEL, pas celui de la liste : un destinataire qui a
      // bloqué l'expéditeur est sauté, et le taire laisserait croire à un
      // envoi complet.
      final skipped = result.skippedBlocked;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipped == 0
                ? L.of(context).bcastSentTo(result.recipientCount)
                : L
                      .of(context)
                      .bcastSentPartly(
                        result.recipientCount,
                        result.recipientCount + skipped,
                        skipped,
                      ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).bcastSendFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BroadcastEditorScreen(existing: _broadcast),
      ),
    );
    if (changed != true || !mounted) return;
    final lists = await ref.refresh(broadcastListsProvider.future);
    final updated = lists.where((l) => l.id == _broadcast.id).firstOrNull;
    if (updated != null && mounted) setState(() => _broadcast = updated);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(broadcastMessagesProvider(_broadcast.id));

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: ChatWallpaper(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Row(
                  children: [
                    const PokouBackButton(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _broadcast.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_broadcast.memberCount} destinataire${_broadcast.memberCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _edit,
                      icon: Icon(
                        Icons.group_outlined,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: L.of(context).bcastEditRecipients,
                    ),
                  ],
                ),
              ),
              const _PrivacyNotice(),
              Expanded(
                child: messagesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text(L.of(context).bcastHistoryUnavailable),
                  ),
                  data: (messages) => messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              L.of(context).bcastNothingSent,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) =>
                              _SentBubble(message: messages[index]),
                        ),
                ),
              ),
              Container(
                color: AppColors.chatComposerBg,
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: L.of(context).bcastMessageHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                      ),
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La phrase qui évite le malentendu le plus coûteux de cette fonctionnalité.
///
/// Sans elle, on croit écrire dans un groupe — et on découvre après coup que
/// quarante clients ont reçu, chacun séparément, un message qu'on pensait
/// collectif. WhatsApp affiche le même avertissement, pour la même raison.
class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chatAiCardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        L.of(context).bcastPrivacyNotice,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

class _SentBubble extends StatelessWidget {
  const _SentBubble({required this.message});

  final BroadcastSentMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: AppColors.chatBubbleSent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content ?? '',
              style: TextStyle(
                color: AppColors.chatTextReceived,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormat.Hm().format(message.createdAt.toLocal())} · '
              '${message.recipientCount} destinataire${message.recipientCount > 1 ? 's' : ''}',
              style: TextStyle(color: AppColors.chatTimestamp, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
