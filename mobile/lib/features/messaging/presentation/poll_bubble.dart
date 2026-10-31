import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/direct_message_model.dart';
import 'messaging_controller.dart' show messagingRepositoryProvider;

/// Rendu d'un message de type POLL : question, options avec barre de
/// progression proportionnelle au nombre de votes, mise en évidence de mon
/// propre vote. Le vote/changement de vote appelle
/// `POST /polls/{id}/vote` (voir MessagingRepository.votePoll) — même route
/// qu'on soit dans une conversation 1:1 ou un groupe.
class PollBubble extends ConsumerStatefulWidget {
  const PollBubble({super.key, required this.poll, required this.onVoted});

  final PollData poll;

  /// Remonte le sondage mis à jour au parent, qui le fusionne dans le
  /// message affiché — ce widget ne connaît pas l'identifiant du MESSAGE
  /// porteur, seulement celui du sondage (`poll.id`).
  final void Function(PollData updated) onVoted;

  @override
  ConsumerState<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends ConsumerState<PollBubble> {
  bool _voting = false;

  Future<void> _toggle(PollOptionData option) async {
    if (_voting) return;
    final poll = widget.poll;
    final Set<int> wanted;
    if (poll.allowsMultiple) {
      wanted = {
        for (final o in poll.options)
          if (o.mine) o.id,
      };
      option.mine ? wanted.remove(option.id) : wanted.add(option.id);
    } else {
      // Retoucher son propre choix retire le vote (bascule), comme les
      // autres gestes de réaction de Pokou — sinon il n'y a aucun moyen de
      // se rétracter d'un sondage à choix unique.
      wanted = option.mine ? <int>{} : {option.id};
    }

    setState(() => _voting = true);
    try {
      final updated = await ref
          .read(messagingRepositoryProvider)
          .votePoll(pollId: poll.id, optionIds: wanted.toList());
      widget.onVoted(updated);
    } catch (_) {
      // Best-effort : si le vote échoue en silence, l'événement WS
      // `poll:vote` d'un autre participant ou un futur rechargement de la
      // conversation rattraperont l'état réel.
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final totalVoters = poll.totalVoters == 0 ? 1 : poll.totalVoters;
    final textColor = AppColors.chatTextReceived;
    final mutedColor = AppColors.chatIconMuted;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bar_chart, size: 16, color: mutedColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final option in poll.options) ...[
            _PollOptionRow(
              option: option,
              totalVoters: totalVoters,
              enabled: !_voting,
              onTap: () => _toggle(option),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            poll.allowsMultiple
                ? '${poll.totalVoters} vote(s) · choix multiple'
                : '${poll.totalVoters} vote(s)',
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.option,
    required this.totalVoters,
    required this.enabled,
    required this.onTap,
  });

  final PollOptionData option;
  final int totalVoters;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = (option.voteCount / totalVoters).clamp(0.0, 1.0);
    final trackColor = AppColors.chatBubbleReceived;
    final fillColor = AppColors.chatActionGreen;
    final textColor = AppColors.chatTextReceived;
    final percent = (ratio * 100).round();

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: option.mine ? fillColor : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fillColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (option.mine) ...[
                    Icon(Icons.check_circle, size: 14, color: fillColor),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: option.mine
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent %',
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
