import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/call_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/presentation/group_controller.dart';
import '../data/call_repository.dart';
import 'call_controller.dart';
import 'call_screen.dart';

/// « En cours », en tête de l'onglet Appels — comme WhatsApp : les appels de
/// groupe où il y a du monde, avec les photos de ceux qui sont dedans, et
/// « Rejoindre ». Y compris un appel qu'on a refusé ou quitté : tant qu'il
/// y a quelqu'un, on peut y revenir sans passer par la conversation.
///
/// Relu toutes les 15 s tant que l'onglet est affiché, et à chaque signal
/// d'appel (voir live_refresh.dart) : les arrivées et départs se voient.
class OngoingCallsSection extends ConsumerStatefulWidget {
  const OngoingCallsSection({super.key});

  @override
  ConsumerState<OngoingCallsSection> createState() =>
      _OngoingCallsSectionState();
}

class _OngoingCallsSectionState extends ConsumerState<OngoingCallsSection> {
  Timer? _poll;
  String? _joining;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(ongoingGroupCallsProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _join(OngoingGroupCall call) async {
    if (_joining != null) return;
    setState(() => _joining = call.room);
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Par le salon, jamais en relançant l'appel du groupe : s'il s'est
      // terminé entre-temps, le serveur le dit (409) au lieu de faire sonner
      // tout le monde. La clé : celle gardée en quittant, ou l'enveloppe
      // jamais ouverte de celui qui avait refusé.
      final token = await ref.read(callRepositoryProvider).joinCall(call.room);
      List<({int userId, String displayName})> members = const [];
      try {
        final group = await ref
            .read(groupRepositoryProvider)
            .getGroup(call.groupId);
        members = [
          for (final m in group.members)
            (userId: m.userId, displayName: m.displayName),
        ];
      } catch (_) {}
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: token.participantIds,
            startWithVideo: call.isVideo,
            groupId: call.groupId,
            title: call.groupName,
            joiningExistingCall: token.joinedExisting,
            groupMembers: members,
          ),
        ),
      );
    } on CallEncryptionException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message.isEmpty ? l.contactCallFailed : error.message,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.contactCallFailed)));
    } finally {
      if (mounted) {
        setState(() => _joining = null);
        ref.invalidate(ongoingGroupCallsProvider);
        ref.invalidate(callLogProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calls =
        ref.watch(ongoingGroupCallsProvider).valueOrNull ??
        const <OngoingGroupCall>[];
    if (calls.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            l.callsOngoingSection,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: AppColors.feedbackSuccess,
            ),
          ),
        ),
        for (final call in calls)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OngoingCallCard(
              call: call,
              joining: _joining == call.room,
              onJoin: () => _join(call),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OngoingCallCard extends StatelessWidget {
  const _OngoingCallCard({
    required this.call,
    required this.joining,
    required this.onJoin,
  });

  final OngoingGroupCall call;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final names = call.inCall.map((p) => p.displayName).take(3).join(', ');
    return Material(
      color: AppColors.feedbackSuccess.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(
          color: AppColors.feedbackSuccess.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        call.isVideo ? Icons.videocam : Icons.call,
                        size: 16,
                        color: AppColors.feedbackSuccess,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          call.groupName ?? l.groupCallOngoing,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FacePile(people: call.inCall),
                  const SizedBox(height: 6),
                  Text(
                    call.iAmIn
                        ? l.callsYouAreIn
                        : '${l.callsInCallCount(call.inCall.length)} · $names',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: joining ? null : onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.feedbackSuccess,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.actionJoin),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les photos de ceux qui sont dans l'appel, qui se chevauchent — au plus
/// cinq, puis « +N ».
class _FacePile extends StatelessWidget {
  const _FacePile({required this.people});

  final List<CallLogOther> people;

  static const _size = 38.0;
  static const _step = 27.0;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(5).toList();
    final extra = people.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: people.map((p) => p.displayName).join(', '),
      child: SizedBox(
        height: _size,
        width: count == 0 ? 0 : _size + (count - 1) * _step,
        child: Stack(
          children: [
            for (final (i, person) in shown.indexed)
              Positioned(
                left: i * _step,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: ContactAvatar(
                    avatar: person.avatar,
                    displayName: person.displayName,
                    size: _size - 4,
                  ),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * _step,
                child: Container(
                  width: _size,
                  height: _size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceElevated,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
