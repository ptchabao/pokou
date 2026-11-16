import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';

/// Une conversation d'une commande, sur UN canal : « Écrire à la
/// pharmacie » (canal `patient`), ou la patiente et le coursier entre eux
/// (canal `livraison`). Chacun ne voit que les canaux qui le concernent.
class HonamOrderMessagesScreen extends ConsumerStatefulWidget {
  const HonamOrderMessagesScreen({
    super.key,
    required this.orderId,
    required this.title,
    this.channel = 'patient',
    this.myRole = 'PATIENT',
    this.heading,
  });

  final int orderId;
  final String title;
  final String channel;

  /// Le rôle de la personne qui lit : ses messages s'alignent à droite.
  final String myRole;

  /// Le titre de l'écran ; « Écrire à la pharmacie » par défaut.
  final String? heading;

  ({int id, String channel}) get threadKey => (id: orderId, channel: channel);

  @override
  ConsumerState<HonamOrderMessagesScreen> createState() =>
      _HonamOrderMessagesScreenState();
}

class _HonamOrderMessagesScreenState
    extends ConsumerState<HonamOrderMessagesScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .sendOrderMessage(widget.orderId, body, channel: widget.channel);
      _controller.clear();
      ref.invalidate(honamOrderMessagesProvider(widget.threadKey));
    } catch (_) {
      if (mounted) koryToast(context, L.of(context).honamFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messages = ref.watch(honamOrderMessagesProvider(widget.threadKey));
    final Widget list;
    if (messages.hasValue) {
      final items = messages.requireValue;
      list = items.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [KoryNotice(text: l.honamUiNoMessages)],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _MessageBlock(
                message: items[index],
                mine: items[index].senderRole == widget.myRole,
              ),
            );
    } else if (messages.hasError) {
      list = ListView(
        padding: const EdgeInsets.all(16),
        children: [KoryNotice(tone: KoryTone.danger, text: l.honamFailed)],
      );
    } else {
      list = const SkeletonPulse(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: double.infinity, height: 56, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 56, radius: 12),
            ],
          ),
        ),
      );
    }
    return KoryPage(
      title: widget.heading ?? l.honamPWriteToPharmacy,
      subtitle: widget.title,
      footer: KoryFooter(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _controller,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l.honamWriteMessage,
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _send,
                tooltip: l.actionSend,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.actionButtonBackground,
                  foregroundColor: AppColors.actionButtonForeground,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ],
      ),
      body: list,
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.message, required this.mine});

  final HonamOrderMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: mine ? AppColors.terracottaTint : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  message.senderName ?? message.senderRole,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateFormat.Hm(locale).format(message.createdAt.toLocal()),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
