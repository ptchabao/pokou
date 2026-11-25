import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/direct_message_model.dart';
import 'messaging_controller.dart' show messagingRepositoryProvider;
import '../../../core/widgets/pokou_sheet.dart';

/// Rendu d'un message de type POLL : question, options avec barre de
/// progression proportionnelle au nombre de votes, mise en évidence de mon
/// propre vote. Le vote/changement de vote appelle
/// `POST /polls/{id}/vote` (voir MessagingRepository.votePoll) — sauf si
/// l'appelant fournit [castVote] : un sondage de GROUPE est chiffré, son vote
/// part par une autre route (voir group_poll_bubble.dart). Le rendu, lui, est
/// le même partout.
class PollBubble extends ConsumerStatefulWidget {
  const PollBubble({
    super.key,
    required this.poll,
    required this.onVoted,
    this.castVote,
    this.voterName,
  });

  final PollData poll;

  /// Remonte le sondage mis à jour au parent, qui le fusionne dans le
  /// message affiché — ce widget ne connaît pas l'identifiant du MESSAGE
  /// porteur, seulement celui du sondage (`poll.id`).
  final void Function(PollData updated) onVoted;

  /// Envoie l'état voulu de mon vote (liste vide = retrait) et renvoie le
  /// sondage à jour. Absent : la route des sondages en clair.
  final Future<PollData> Function(List<int> optionIds)? castVote;

  /// Le nom d'un votant absent du carnet, quand l'appelant en connaît un
  /// (un membre du groupe) ; `null` pour « Un membre ».
  final String? Function(int userId)? voterName;

  @override
  ConsumerState<PollBubble> createState() => _PollBubbleState();
}

/// « Modifiable encore 12 min », « Réponse définitive », ou rien (pas de
/// vote). Les minutes sont arrondies AU-DESSUS : « 0 min » alors qu'on peut
/// encore changer serait faux.
String? pollAnswerStatus(L l, PollData poll, DateTime now) {
  final locksAt = poll.myLocksAt;
  if (locksAt == null || !poll.options.any((o) => o.mine)) {
    return poll.isFinalAt(now) ? l.msgFixPollFinal : null;
  }
  if (poll.isFinalAt(now)) return l.msgFixPollFinal;
  final seconds = locksAt.difference(now).inSeconds;
  return l.msgFixPollEditableFor(((seconds + 59) ~/ 60).clamp(1, 1 << 20));
}

class _PollBubbleState extends ConsumerState<PollBubble> {
  bool _voting = false;

  /// Le temps qui reste s'affiche à la minute : l'écran se redessine une
  /// fois par minute tant qu'une fenêtre est ouverte, pas davantage.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(PollBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleTick();
  }

  void _scheduleTick() {
    _tick?.cancel();
    final locksAt = widget.poll.myLocksAt;
    if (locksAt == null || !DateTime.now().isBefore(locksAt)) return;
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
      if (!DateTime.now().isBefore(locksAt)) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _toggle(PollOptionData option) async {
    if (_voting) return;
    final poll = widget.poll;
    // Réponse définitive : le serveur refuserait, l'écran ne le propose pas.
    if (poll.isFinalAt(DateTime.now())) return;
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
      final castVote = widget.castVote;
      final updated = castVote != null
          ? await castVote(wanted.toList())
          : await ref
                .read(messagingRepositoryProvider)
                .votePoll(pollId: poll.id, optionIds: wanted.toList());
      widget.onVoted(updated);
    } on ApiException catch (exc) {
      // Refus du serveur (réponse devenue définitive, choix unique) : le
      // DIRE, au lieu de laisser croire que le geste a été pris.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exc.message.isNotEmpty
                  ? exc.message
                  : L.of(context).msgFixPollVoteRefused,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).msgFixPollVoteRefused)),
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  /// « Voir les votes » : qui a choisi quoi, quand le sondage le montre.
  /// Les noms viennent du carnet de CET appareil ; un votant absent du
  /// carnet reste « Un membre » — jamais son numéro.
  Future<void> _showVoters() async {
    final l = L.of(context);
    final poll = widget.poll;
    final myId = ref.read(authControllerProvider).user?.id;
    final contacts = ref.read(contactsProvider).valueOrNull ?? const [];
    String nameOf(int userId) {
      if (userId == myId) return l.callYou;
      for (final c in contacts) {
        if (c.contactUserId == userId) return c.displayName;
      }
      return widget.voterName?.call(userId) ?? l.pollVoterUnknown;
    }

    await showPokouSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              poll.question,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            for (final option in poll.options) ...[
              const SizedBox(height: 14),
              Text(
                '${option.text} · ${option.voteCount}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final id in option.voterIds)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(nameOf(id)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final poll = widget.poll;
    final totalVoters = poll.totalVoters == 0 ? 1 : poll.totalVoters;
    final textColor = AppColors.chatTextReceived;
    final mutedColor = AppColors.chatIconMuted;
    final now = DateTime.now();
    final locked = poll.isFinalAt(now);
    final status = pollAnswerStatus(l, poll, now);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Discussions · 20 — « Sondage · un seul choix », puis la question.
          Row(
            children: [
              Icon(Icons.bar_chart, size: 14, color: mutedColor),
              const SizedBox(width: 4),
              Text(
                poll.allowsMultiple ? l.pollKindMultiple : l.pollKindSingle,
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            poll.question,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final option in poll.options) ...[
            _PollOptionRow(
              option: option,
              totalVoters: totalVoters,
              enabled: !_voting && !locked,
              onTap: () => _toggle(option),
            ),
            const SizedBox(height: 6),
          ],
          if (status != null) ...[
            Row(
              children: [
                Icon(
                  locked ? Icons.lock_outline : Icons.timer_outlined,
                  size: 12,
                  color: mutedColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    status,
                    key: const ValueKey('poll-answer-status'),
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // « 8 votes · Voir les votes » — le lien seulement quand le
          // sondage montre ses votants et qu'il y en a.
          Row(
            children: [
              Text(
                l.pollVotes(poll.totalVoters),
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
              if (poll.revealsVoters && poll.totalVoters > 0) ...[
                Text(' · ', style: TextStyle(fontSize: 11, color: mutedColor)),
                InkWell(
                  onTap: _showVoters,
                  child: Text(
                    l.pollSeeVotes,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentPrimaryDark,
                    ),
                  ),
                ),
              ],
            ],
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
