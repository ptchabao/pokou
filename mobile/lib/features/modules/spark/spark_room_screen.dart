import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_dates_view.dart';
import 'spark_model.dart';
import 'spark_screen.dart';

/// Les stickers autorisés. La liste est la MÊME que côté serveur : lui seul
/// tranche, mais proposer ici un sticker qu'il refusera ferait échouer le
/// geste sans raison visible.
const _stickers = {
  'feu': '🔥',
  'coeur': '❤️',
  'rire': '😂',
  'surprise': '😮',
  'pouce': '👍',
  'danse': '💃',
  'salut': '👋',
  'cool': '😎',
};

/// La Salle d'Entrée — dix minutes, vocaux et stickers, puis on tranche.
class SparkRoomScreen extends ConsumerStatefulWidget {
  const SparkRoomScreen({super.key, required this.matchId});

  final int matchId;

  @override
  ConsumerState<SparkRoomScreen> createState() => _SparkRoomScreenState();
}

class _SparkRoomScreenState extends ConsumerState<SparkRoomScreen> {
  final _recorder = AudioRecorder();
  Timer? _ticker;
  Timer? _poller;
  int _secondsLeft = 0;
  bool _recording = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // La salle se relit toutes les cinq secondes : le vocal de l'autre doit
    // arriver pendant qu'on est dedans, et dix minutes ne laissent pas le
    // temps d'aller tirer manuellement.
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(sparkMatchProvider(widget.matchId));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _syncCountdown(int serverSeconds) {
    // Le serveur fait autorité. On recale à chaque lecture plutôt que de
    // laisser dériver une horloge locale : c'est lui qui refermera la salle.
    _secondsLeft = serverSeconds;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 1 << 30));
    });
  }

  Future<bool> _micPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).roomNeedMic)));
    }
    return false;
  }

  Future<void> _toggleRecording() async {
    if (_recording) return _stopAndSend();
    if (!await _micPermission()) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/spark_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopAndSend() async {
    final path = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: 'spark_vocal.m4a',
            mimeType: 'audio/mp4',
            messageType: 'AUDIO',
          );
      await ref
          .read(sparkRepositoryProvider)
          .sendVoice(widget.matchId, upload.id);
      ref.invalidate(sparkMatchProvider(widget.matchId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).roomVoiceFailed)));
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _sendSticker(String sticker) async {
    await ref
        .read(sparkRepositoryProvider)
        .sendSticker(widget.matchId, sticker);
    ref.invalidate(sparkMatchProvider(widget.matchId));
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      final match = await ref
          .read(sparkRepositoryProvider)
          .continueMatch(widget.matchId);
      ref.invalidate(sparkMatchProvider(widget.matchId));
      ref.invalidate(sparkMatchesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            match.status == 'CONTINUED'
                ? L.of(context).roomBothYes
                : L.of(context).roomWaitingOther,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(SparkMatch match) async {
    final url = await ref
        .read(sparkRepositoryProvider)
        .extendRoom(widget.matchId);
    if (!mounted) return;
    await openPaymentGateway(
      context,
      url,
      pendingMessage: L.of(context).roomExtendPending,
    );
    ref.invalidate(sparkMatchProvider(widget.matchId));
  }

  String get _clock {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(sparkMatchProvider(widget.matchId));

    return matchAsync.when(
      loading: () => ModuleScaffold(
        title: L.of(context).roomTitle,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ModuleScaffold(
        title: L.of(context).roomTitle,
        child: ModuleEmptyState(
          icon: Icons.search_off,
          title: L.of(context).roomNotFound,
          message: L.of(context).roomMaybeClosed,
        ),
      ),
      data: (match) {
        if (match.isOpen) _syncCountdown(match.roomSecondsLeft);
        return ModuleScaffold(
          title: match.peer?.displayName ?? L.of(context).roomTitle,
          subtitle: match.isOpen ? L.of(context).roomVoiceOnly : null,
          child: Column(
            children: [
              if (match.isOpen)
                _Countdown(clock: _clock, seconds: _secondsLeft),
              Expanded(child: _Transcript(match: match)),
              if (match.isOpen)
                _Composer(
                  recording: _recording,
                  busy: _busy,
                  iContinued: match.iContinued,
                  canExtend: match.canExtend,
                  extensionPrice: match.extensionPrice,
                  onRecord: _toggleRecording,
                  onSticker: _sendSticker,
                  onContinue: _continue,
                  onExtend: () => _extend(match),
                )
              else
                _AfterRoom(match: match),
            ],
          ),
        );
      },
    );
  }
}

/// Le compte à rebours. Rouge sous une minute — c'est là qu'il faut trancher.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.clock, required this.seconds});

  final String clock;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 60;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgent ? sparkAccent : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            urgent ? Icons.timer : Icons.timer_outlined,
            size: 18,
            color: urgent ? sparkAccent : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              seconds <= 0
                  ? L.of(context).roomTimeUp
                  : L.of(context).roomTimeLeft(clock),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: urgent ? sparkAccent : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.match});

  final SparkMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.messages.isEmpty) {
      return ModuleEmptyState(
        icon: Icons.mic_none,
        title: L.of(context).roomSaySomething,
        message: L.of(context).roomNoTextBody,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      itemCount: match.messages.length,
      itemBuilder: (_, index) => _RoomBubble(message: match.messages[index]),
    );
  }
}

class _RoomBubble extends ConsumerStatefulWidget {
  const _RoomBubble({required this.message});

  final SparkRoomMessage message;

  @override
  ConsumerState<_RoomBubble> createState() => _RoomBubbleState();
}

class _RoomBubbleState extends ConsumerState<_RoomBubble> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final media = widget.message.media;
    if (media == null) return;
    setState(() => _playing = true);
    try {
      final file = await ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(media.id, extension: mediaExtension(media));
      await _player.setFilePath(file.path);
      await _player.play();
    } catch (_) {
      // Un vocal illisible ne doit pas figer la bulle sur « en lecture ».
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final mine = message.isMine;

    if (message.kind == 'STICKER') {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _stickers[message.sticker] ?? '✨',
            style: const TextStyle(fontSize: 44),
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? AppColors.chatBubbleSent : AppColors.surface,
            borderRadius: AppRadius.bubble,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _playing ? null : _play,
                icon: Icon(
                  _playing ? Icons.graphic_eq : Icons.play_arrow,
                  color: AppColors.accentPrimaryDark,
                ),
                visualDensity: VisualDensity.compact,

                tooltip: L.of(context).a11yAudioLevel,
              ),
              Text(
                L.of(context).roomVoice,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.recording,
    required this.busy,
    required this.iContinued,
    required this.canExtend,
    required this.extensionPrice,
    required this.onRecord,
    required this.onSticker,
    required this.onContinue,
    required this.onExtend,
  });

  final bool recording;
  final bool busy;
  final bool iContinued;
  final bool canExtend;
  final int extensionPrice;
  final VoidCallback onRecord;
  final ValueChanged<String> onSticker;
  final VoidCallback onContinue;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in _stickers.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => onSticker(entry.key),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Le micro EST le composeur. Il n'y a pas de champ de texte,
              // et il ne doit pas y en avoir : c'est l'impossibilité du
              // copier-coller qui fait le tri.
              InkWell(
                onTap: onRecord,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: recording ? sparkAccent : AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    recording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModuleActionButton(
                  label: iContinued
                      ? L.of(context).roomWaitingReply
                      : L.of(context).actionContinue,
                  busy: busy,
                  onPressed: iContinued ? null : onContinue,
                ),
              ),
            ],
          ),
          if (canExtend) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onExtend,
              child: Text(
                L.of(context).roomExtendFor(extensionPrice),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ce qui reste une fois la salle fermée.
class _AfterRoom extends StatelessWidget {
  const _AfterRoom({required this.match});

  final SparkMatch match;

  @override
  Widget build(BuildContext context) {
    final continued = match.status == 'CONTINUED' || match.status == 'SAVED';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Text(
            switch (match.status) {
              'CONTINUED' => L.of(context).roomBothSaidYes,
              'SAVED' => L.of(context).roomSaved,
              _ => L.of(context).roomClosedNoAnswer,
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (continued) ...[
            const SizedBox(height: 14),
            ModuleActionButton(
              label: L.of(context).roomSuggestDate,
              icon: Icons.restaurant_outlined,
              onPressed: () => showBookDateSheet(context, matchId: match.id),
            ),
          ],
        ],
      ),
    );
  }
}
