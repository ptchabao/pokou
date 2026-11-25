import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/data/direct_message_model.dart' show PollData;
import '../../messaging/presentation/poll_bubble.dart';
import '../data/group_poll.dart';
import 'group_controller.dart';

/// Un sondage de groupe dans le fil : la même bulle qu'en discussion à deux
/// (PollBubble), alimentée par des votes chiffrés que CE téléphone ouvre et
/// compte (voir group_poll.dart).
///
/// Les votes se chargent à l'affichage de la bulle, puis suivent en direct
/// l'événement `group:poll:vote` — chaque bulle n'écoute que son sondage.
class GroupPollBubble extends ConsumerStatefulWidget {
  const GroupPollBubble({
    super.key,
    required this.groupId,
    required this.messageId,
    required this.poll,
  });

  final int groupId;
  final String messageId;
  final GroupPollDefinition poll;

  @override
  ConsumerState<GroupPollBubble> createState() => _GroupPollBubbleState();
}

class _GroupPollBubbleState extends ConsumerState<GroupPollBubble> {
  Map<int, List<int>> _votes = const {};

  /// Quand MA réponse devient définitive (serveur) — voir PollData.myLocksAt.
  DateTime? _locksAt;
  StreamSubscription<Map<String, dynamic>>? _events;

  int? get _myUserId => ref.read(authControllerProvider).user?.id;

  @override
  void initState() {
    super.initState();
    _events = ref.read(wsClientProvider).events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await ref
          .read(groupRepositoryProvider)
          .pollVoteState(
            groupId: widget.groupId,
            messageId: widget.messageId,
            poll: widget.poll,
          );
      if (mounted) {
        setState(() {
          _votes = state.votes;
          _locksAt = state.locksAt;
        });
      }
    } catch (_) {
      // Hors ligne : le sondage s'affiche sans votes, l'événement suivant
      // ou la prochaine ouverture les rattrapera.
    }
  }

  Future<void> _onEvent(Map<String, dynamic> event) async {
    if (event['type'] != 'group:poll:vote' ||
        event['group_id'] != widget.groupId ||
        event['message_id'] != widget.messageId) {
      return;
    }
    final vote = event['vote'];
    if (vote is! Map<String, dynamic> || vote['voter_id'] is! int) return;
    final voterId = vote['voter_id'] as int;
    final choices = vote['ciphertext'] == null
        ? null
        : await ref
              .read(groupRepositoryProvider)
              .openPollVote(
                groupId: widget.groupId,
                messageId: widget.messageId,
                poll: widget.poll,
                vote: vote,
              );
    if (!mounted) return;
    setState(() {
      final next = Map<int, List<int>>.of(_votes);
      choices == null || choices.isEmpty
          ? next.remove(voterId)
          : next[voterId] = choices;
      _votes = next;
    });
  }

  PollData _tally() => widget.poll
      .tally(messageId: widget.messageId, votes: _votes, myUserId: _myUserId)
      .withLocksAt(_locksAt);

  Future<PollData> _castVote(List<int> optionIds) async {
    final myUserId = _myUserId;
    if (myUserId == null) return _tally();
    final locksAt = await ref
        .read(groupRepositoryProvider)
        .setPollVote(
          groupId: widget.groupId,
          messageId: widget.messageId,
          voterId: myUserId,
          poll: widget.poll,
          optionIds: optionIds,
        );
    if (mounted) {
      setState(() {
        final next = Map<int, List<int>>.of(_votes);
        optionIds.isEmpty ? next.remove(myUserId) : next[myUserId] = optionIds;
        _votes = next;
        _locksAt = locksAt ?? _locksAt;
      });
    }
    return _tally();
  }

  /// Un votant hors du carnet : le nom qu'il porte dans le groupe.
  String? _memberName(int userId) {
    final group = ref.read(groupChatControllerProvider(widget.groupId)).group;
    for (final member in group?.members ?? const []) {
      if (member.userId == userId && member.displayName.trim().isNotEmpty) {
        return member.displayName;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PollBubble(
    poll: _tally(),
    // L'état vit ici : rien à remonter à l'écran.
    onVoted: (_) {},
    castVote: _castVote,
    voterName: _memberName,
  );
}
