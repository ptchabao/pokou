import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/calls/native_call_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import 'call_controller.dart';
import 'call_session.dart';
import 'ringtone_player.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../contacts/presentation/discussions_controller.dart';

/// Écran d'appel — audio/vidéo 1:1 ou de groupe selon le nombre de
/// participants réellement connectés au salon LiveKit. `startWithVideo`
/// distingue un appel vocal (caméra désactivée à l'entrée, activable) d'un
/// appel vidéo. `otherParticipantIds` sert uniquement à notifier
/// explicitement chaque autre participant au raccroché (voir _hangUp) —
/// LiveKit ne fait que la voix/vidéo, la fin d'appel est signalée par
/// /calls/signal comme accept/decline, pour que le journal d'appels
/// (CallLog côté API) sache que l'appel est terminé.
///
/// `groupId` est renseigné pour un appel lancé depuis une conversation de
/// groupe : les membres du groupe deviennent alors invitables sans passer par
/// le carnet d'adresses (même règle que côté API, voir calls.py::invite).

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.livekitUrl,
    required this.token,
    required this.room,
    required this.otherParticipantIds,
    this.startWithVideo = true,
    this.groupId,
    this.groupMembers = const [],
    this.joiningExistingCall = false,
    @visibleForTesting this.ringtonePlayer,
  });

  final String livekitUrl;
  final String token;
  final String room;
  final List<int> otherParticipantIds;
  final bool startWithVideo;
  final int? groupId;

  /// Membres du groupe (id → nom), pour proposer d'ajouter quelqu'un du
  /// groupe qui n'est pas (ou plus) dans l'appel.
  final List<({int userId, String displayName})> groupMembers;

  /// Vrai quand cet écran sert à REJOINDRE un appel déjà engagé — une
  /// invitation qu'on vient d'accepter (voir IncomingCallScreen._accept, le
  /// correspondant est déjà connecté au salon), ou un appel de groupe déjà en
  /// cours renvoyé par le serveur au lieu d'un nouveau (voir
  /// CallToken.joinedExisting côté call_repository.dart) — plutôt qu'à en
  /// lancer un nouveau. Dans ce cas, jouer un ringback n'aurait aucun sens
  /// (l'appel est déjà décroché/en cours), donc on ne le joue jamais. Cet
  /// écran étant aussi utilisé pour rejoindre un appel de groupe déjà actif
  /// depuis un point d'entrée qu'on ne maîtrise pas ici (GroupConversationScreen,
  /// PushService en notification), l'état initial des participants distants
  /// du salon LiveKit (voir _connect) sert de filet de sécurité quand ce
  /// paramètre n'a pas pu être renseigné à `true`.
  final bool joiningExistingCall;

  /// Injectable pour les tests (faux lecteur, sans son réel) — `null` en
  /// production, où l'écran crée son propre RingtonePlayer.
  final RingtonePlayer? ringtonePlayer;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  /// La session de cet appel — qui survit à cet écran (voir CallSession).
  late final CallSession _s;
  StreamSubscription<CallNotice>? _noticeSubscription;
  StreamSubscription<CallReaction>? _reactionSubscription;
  Timer? _reactionTimer;
  String? _visibleReaction;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final existing = activeCall.value;
    if (existing != null &&
        !existing.ended &&
        existing.roomName == widget.room) {
      // On REVIENT à l'appel (bandeau, ou même salon rouvert) : on s'y
      // rattache au lieu d'en ouvrir un second.
      _s = existing;
    } else {
      // Un nouvel appel remplace l'ancien : on ne parle pas dans deux salons
      // à la fois.
      if (existing != null && !existing.ended) unawaited(existing.hangUp());
      _s = CallSession(
        livekitUrl: widget.livekitUrl,
        token: widget.token,
        roomName: widget.room,
        otherParticipantIds: widget.otherParticipantIds,
        startWithVideo: widget.startWithVideo,
        groupId: widget.groupId,
        groupMembers: widget.groupMembers,
        joiningExistingCall: widget.joiningExistingCall,
        repository: ref.read(callRepositoryProvider),
        ws: ref.read(wsClientProvider),
        ringtonePlayer: widget.ringtonePlayer,
        nativeBridge: ref.read(nativeCallBridgeProvider),
      );
      activeCall.value = _s;
      _s.start();
    }
    _s.attachScreen();
    _s.addListener(_onSessionChanged);
    _noticeSubscription = _s.notices.listen(_onNotice);
    _reactionSubscription = _s.reactions.listen(_showReaction);
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_s.ended) {
      if (!_closing) {
        _closing = true;
        Navigator.of(context).maybePop();
      }
      return;
    }
    setState(() {});
  }

  void _onNotice(CallNotice notice) {
    if (!mounted) return;
    final l = L.of(context);
    final text = switch (notice) {
      CallNotice.noAnswer => l.callNoAnswer,
      CallNotice.flipFailed => l.callFlipCameraFailed,
      CallNotice.inviteFailed => l.callAddFailed,
      CallNotice.reactionFailed => l.callReactionFailed,
    };
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleMic() => _s.toggleMic();
  Future<void> _toggleCamera() => _s.toggleCamera();
  Future<void> _toggleSpeaker() => _s.toggleSpeaker();
  Future<void> _flipCamera() => _s.flipCamera();

  void _showReaction(CallReaction reaction) {
    if (!mounted) return;
    setState(() => _visibleReaction = reaction.emoji);
    _reactionTimer?.cancel();
    _reactionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visibleReaction = null);
    });
  }

  Future<void> _sendReaction(String emoji) async {
    _showReaction(CallReaction(emoji: emoji, senderId: null));
    await _s.sendReaction(emoji);
  }

  Future<void> _openParticipantConversation(
    Participant participant,
    String displayName,
  ) async {
    final participantId = int.tryParse(participant.identity);
    final myUserId = ref.read(authControllerProvider).user?.id;
    if (participantId == null ||
        myUserId == null ||
        participantId == myUserId) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: myUserId,
          contactUserId: participantId,
          contactName: displayName,
        ),
      ),
    );
  }

  Future<void> _confirmHangUp() async {
    final shouldHangUp = await confirmCallHangUp(context);
    if (shouldHangUp == true && mounted) await _s.hangUp();
  }

  /// Ajoute quelqu'un à l'appel EN COURS : le salon ne change pas, personne
  /// ne se reconnecte, l'invité reçoit un `call:invite` sur le salon existant.
  /// Un appel à deux devient un appel de groupe (comportement WhatsApp).
  Future<void> _addParticipants() async {
    final candidates = await _inviteCandidates();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).callNobodyToAdd)));
      return;
    }

    final picked = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    L.of(context).callAddToCall,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final candidate in candidates)
                      CheckboxListTile(
                        value: picked.contains(candidate.userId),
                        title: Text(candidate.displayName),
                        onChanged: (checked) => setSheetState(() {
                          checked == true
                              ? picked.add(candidate.userId)
                              : picked.remove(candidate.userId);
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: picked.isEmpty
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                    child: Text(L.of(context).callAdd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || picked.isEmpty || !mounted) return;

    await _s.invite(picked.toList());
  }

  /// Membres du groupe d'abord (joignables sans être dans le carnet), sinon
  /// les contacts Pokou — dans les deux cas, moins ceux déjà dans l'appel.
  Future<List<({int userId, String displayName})>> _inviteCandidates() async {
    if (widget.groupId != null) {
      return widget.groupMembers
          .where((member) => _s.canInvite(member.userId))
          .toList();
    }
    try {
      final contacts = await ref.read(contactsProvider.future);
      return contacts
          .where(
            (contact) =>
                contact.isRegistered &&
                contact.contactUserId != null &&
                _s.canInvite(contact.contactUserId!),
          )
          .map(
            (contact) => (
              userId: contact.contactUserId!,
              displayName: contact.displayName,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    // Fermer l'écran ne coupe PLUS l'appel : on le quitte pour lire un
    // message, le bandeau « Appel en cours » ramène ici. Seul le raccroché
    // (ou celui de l'autre) termine la session.
    _noticeSubscription?.cancel();
    _reactionSubscription?.cancel();
    _reactionTimer?.cancel();
    _s.removeListener(_onSessionChanged);
    _s.detachScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_s.connecting) {
      final currentUser = ref.watch(authControllerProvider).user;
      final contacts = ref
          .watch(contactsProvider)
          .maybeWhen(data: (items) => items, orElse: () => const []);
      final remoteId = widget.otherParticipantIds.firstOrNull;
      final remote = remoteId == null
          ? null
          : contacts.cast<dynamic>().firstWhere(
              (contact) => contact.contactUserId == remoteId,
              orElse: () => null,
            );
      return Scaffold(
        backgroundColor: AppColors.neutralBeige,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ContactAvatar(
                    avatar: currentUser?.avatar,
                    displayName:
                        currentUser?.displayName ?? L.of(context).callYou,
                    size: 88,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Icon(Icons.call, color: Colors.white54, size: 22),
                  ),
                  ContactAvatar(
                    avatar: remote?.avatar,
                    displayName:
                        remote?.displayName ?? L.of(context).callContact,
                    size: 88,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                L.of(context).callConnecting,
                style: const TextStyle(
                  color: AppColors.brandEbene,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.of(context).callPreparing,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _CallActionButton(
                  icon: Icons.call_end,
                  background: AppColors.accentPrimary,
                  onTap: _confirmHangUp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_s.joinFailed) {
      return Scaffold(
        backgroundColor: AppColors.neutralBeige,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L.of(context).callJoinFailed,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              const PokouBackButton(),
            ],
          ),
        ),
      );
    }

    final local = _s.lkRoom.localParticipant;
    final remotes = _s.lkRoom.remoteParticipants.values.toList();
    final contacts = ref
        .watch(contactsProvider)
        .maybeWhen(data: (items) => items, orElse: () => const []);
    final currentUser = ref.watch(authControllerProvider).user;
    final localName = currentUser?.displayName ?? L.of(context).callYou;
    final localAvatar = currentUser?.avatar;
    MediaMeta? avatarForParticipant(Participant participant) {
      final userId = int.tryParse(participant.identity);
      if (userId == null) return null;
      for (final contact in contacts) {
        if (contact.contactUserId == userId) return contact.avatar;
      }
      return null;
    }

    // Le ✓ d'identité, lu dans le carnet puis dans les discussions — même
    // source que la liste des discussions, où il s'affichait déjà.
    final discussions = ref
        .watch(discussionsProvider)
        .maybeWhen(data: (items) => items, orElse: () => const []);
    bool verifiedParticipant(Participant participant) {
      final userId = int.tryParse(participant.identity);
      if (userId == null) return false;
      for (final contact in contacts) {
        if (contact.contactUserId == userId) return contact.isVerified;
      }
      for (final discussion in discussions) {
        if (discussion.kind == 'contact' &&
            discussion.contactUserId == userId) {
          return discussion.isVerified;
        }
      }
      return false;
    }

    String nameForParticipant(Participant participant) {
      final userId = int.tryParse(participant.identity);
      if (userId != null) {
        for (final contact in contacts) {
          if (contact.contactUserId == userId) return contact.displayName;
        }
      }
      return participant.name.isNotEmpty
          ? participant.name
          : participant.identity;
    }

    return Scaffold(
      backgroundColor: AppColors.neutralBeige,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: remotes.isEmpty
                      ? Stack(
                          children: [
                            Center(
                              child: Text(
                                L.of(context).callWaiting,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (local != null)
                              Positioned(
                                top: 16,
                                right: 16,
                                width: 110,
                                height: 150,
                                child: _ParticipantTile(
                                  participant: local,
                                  displayName: localName,
                                  avatar: localAvatar,
                                  onFlipCamera: _s.cameraEnabled
                                      ? _flipCamera
                                      : null,
                                ),
                              ),
                          ],
                        )
                      : remotes.length == 1
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: _ParticipantTile(
                                participant: remotes.first,
                                displayName: nameForParticipant(remotes.first),
                                isVerified: verifiedParticipant(remotes.first),
                                avatar: avatarForParticipant(remotes.first),
                                onTap: () => _openParticipantConversation(
                                  remotes.first,
                                  nameForParticipant(remotes.first),
                                ),
                              ),
                            ),
                            if (_s.encrypted || _s.encryptionDowngraded)
                              Positioned(
                                top: 16,
                                left: 16,
                                child: _EncryptedCallLabel(
                                  encrypted: _s.encrypted,
                                ),
                              ),
                            if (local != null)
                              Positioned(
                                top: 16,
                                right: 16,
                                width: 110,
                                height: 150,
                                child: _ParticipantTile(
                                  participant: local,
                                  displayName: localName,
                                  avatar: localAvatar,
                                  onFlipCamera: _s.cameraEnabled
                                      ? _flipCamera
                                      : null,
                                ),
                              ),
                          ],
                        )
                      : _WithSecurityNote(
                          encrypted: _s.encrypted,
                          child: GridView.count(
                            crossAxisCount: 2,
                            // Gouttière de 12 points, comme le système de design
                            // le fixe pour les grilles. Les tuiles se touchaient.
                            padding: const EdgeInsets.all(12),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                            children: [
                              if (local != null)
                                _ParticipantTile(
                                  participant: local,
                                  displayName: localName,
                                  avatar: localAvatar,
                                  isMe: true,
                                  onFlipCamera: _s.cameraEnabled
                                      ? _flipCamera
                                      : null,
                                ),
                              for (final p in remotes)
                                _ParticipantTile(
                                  participant: p,
                                  displayName: nameForParticipant(p),
                                  isVerified: verifiedParticipant(p),
                                  avatar: avatarForParticipant(p),
                                  showMuteButton: true,
                                  onTap: () => _openParticipantConversation(
                                    p,
                                    nameForParticipant(p),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                // ── La barre de contrôle ─────────────────────────────────
                //
                // Des boutons ÉTIQUETÉS, et non quatre ronds muets. Sur un
                // appel de groupe, couper son micro et quitter l'appel sont
                // deux gestes très différents et voisins d'un centimètre : un
                // pictogramme seul se confond, surtout dans l'urgence.
                //
                // Et « raccrocher » sort de cette rangée. Il était un rond
                // VERT au milieu des autres, de la même taille — la seule
                // action irréversible de l'écran avait l'apparence de ses
                // voisines et leur couleur d'accord. Il devient une barre
                // rouge, pleine largeur, sous les autres.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final emoji in callReactionEmojis)
                            IconButton(
                              tooltip: emoji,
                              onPressed: () => _sendReaction(emoji),
                              icon: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _CallControl(
                              icon: _s.micEnabled ? Icons.mic : Icons.mic_off,
                              label: L.of(context).callMuteLabel,
                              active: !_s.micEnabled,
                              onTap: _toggleMic,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CallControl(
                              icon: _s.cameraEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              label: L.of(context).callCameraLabel,
                              active: !_s.cameraEnabled,
                              onTap: _toggleCamera,
                            ),
                          ),
                          if (_s.canSwitchSpeaker) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CallControl(
                                icon: _s.speakerOn
                                    ? Icons.volume_up
                                    : Icons.volume_down_outlined,
                                label: L.of(context).callSpeakerLabel,
                                active: _s.speakerOn,
                                onTap: _toggleSpeaker,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CallControl(
                              icon: Icons.person_add_alt,
                              label: L.of(context).callInviteLabel,
                              active: false,
                              onTap: _s.inviting ? null : _addParticipants,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _confirmHangUp,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.semanticError,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.chip,
                            ),
                          ),
                          icon: const Icon(Icons.call_end, size: 20),
                          label: Text(
                            L.of(context).callLeaveConference,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_visibleReaction != null)
            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    _visibleReaction!,
                    style: const TextStyle(fontSize: 72),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool?> confirmCallHangUp(BuildContext context) {
  final l = L.of(context);
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.callLeaveConfirmTitle),
      content: Text(l.callLeaveConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.callHangUp),
        ),
      ],
    ),
  );
}

class _ParticipantTile extends StatefulWidget {
  const _ParticipantTile({
    required this.participant,
    required this.displayName,
    this.avatar,
    this.showMuteButton = false,
    this.isMe = false,
    this.isVerified = false,
    this.onFlipCamera,
    this.onTap,
  });

  final Participant participant;
  final String displayName;
  final MediaMeta? avatar;
  final bool showMuteButton;

  /// Ma propre tuile. Elle prend un fond teinté : dans une grille de quatre
  /// visages, savoir où l'on est soi-même est la première chose qu'on
  /// cherche, et le nom ne suffit pas quand on lit vite.
  final bool isMe;

  /// Le ✓ d'identité, à côté du nom.
  final bool isVerified;

  /// Bascule avant/arrière, posée sur MA tuile quand ma caméra filme : c'est
  /// là qu'on regarde ce qu'on montre, et la barre du bas n'a plus la place
  /// d'un cinquième libellé lisible.
  final VoidCallback? onFlipCamera;
  final VoidCallback? onTap;

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile>
    with SingleTickerProviderStateMixin {
  bool _locallyMuted = false;

  /// L'animation de l'anneau de parole.
  ///
  /// Une PULSATION lente, et non un clignotement : ce qu'on veut dire,
  /// c'est « cette personne parle en ce moment », pas « attention ». Un
  /// clignotement rapide dans une grille de quatre tuiles rendrait l'écran
  /// illisible dès que deux personnes se répondent.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onChanged);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onChanged);
      widget.participant.addListener(_onChanged);
      _locallyMuted = false;
    }
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _syncPulse();
  }

  /// L'animation ne tourne QUE pendant que la personne parle.
  ///
  /// Un contrôleur laissé en boucle repeint sa tuile soixante fois par
  /// seconde même quand personne ne dit rien — sur un appareil d'entrée de
  /// gamme, en appel, c'est de la batterie prise au média.
  void _syncPulse() {
    final parle = widget.participant.isSpeaking;
    if (parle && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!parle && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  /// Coupe le son de CE participant pour moi seulement (appel de groupe) —
  /// désactive localement sa piste audio reçue, sans le notifier ni
  /// affecter ce que les autres l'entendent.
  Future<void> _toggleLocalMute() async {
    final pub = widget.participant.audioTrackPublications.firstOrNull;
    final track = pub?.track;
    if (track == null) return;
    final next = !_locallyMuted;
    if (next) {
      await track.disable();
    } else {
      await track.enable();
    }
    if (mounted) setState(() => _locallyMuted = next);
  }

  /// Le micro de cette personne est-il coupé À LA SOURCE ?
  ///
  /// Distinct de `_locallyMuted`, qui est MON choix de ne pas l'entendre.
  /// Les confondre afficherait « coupé » à tout le monde parce qu'une seule
  /// personne a baissé le volume de son côté.
  bool get _sourceMuted {
    final pub = widget.participant.audioTrackPublications.firstOrNull;
    return pub == null || pub.muted;
  }

  (String, Color) _quality(L l) =>
      switch (widget.participant.connectionQuality) {
        ConnectionQuality.excellent => (
          l.callQualityExcellent,
          AppColors.accentPrimaryDark,
        ),
        ConnectionQuality.good => (l.callQualityGood, AppColors.textSecondary),
        ConnectionQuality.poor => (
          l.callQualityPoor,
          AppColors.chatAiLinkColor,
        ),
        _ => ('', AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final videoPubs = widget.participant.videoTrackPublications;
    final track = videoPubs.isEmpty
        ? null
        : videoPubs.first.track as VideoTrack?;
    final video = track != null && !track.muted;
    final parle = widget.participant.isSpeaking;
    final (qualite, couleurQualite) = _quality(l);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: AppRadius.chip,
      child: Container(
        decoration: BoxDecoration(
          // Ma tuile est teintée ; celles des autres sont blanches.
          color: widget.isMe
              ? AppColors.accentPrimary.withValues(alpha: 0.07)
              : AppColors.surface,
          borderRadius: AppRadius.chip,
          border: Border.all(
            // L'anneau de parole passe aussi par la BORDURE de la tuile :
            // dans une grille, on repère une tuite entière avant un détail
            // à l'intérieur.
            color: parle ? AppColors.accentPrimary : AppColors.border,
            width: parle ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.chip,
          child: Stack(
            children: [
              if (video)
                Positioned.fill(child: VideoTrackRenderer(track))
              else
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SpeakingRing(
                        pulse: _pulse,
                        speaking: parle,
                        child: ContactAvatar(
                          avatar: widget.avatar,
                          displayName: widget.displayName,
                          size: 66,
                          fallbackBackgroundColor: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.isMe
                                    ? l.callYouShort
                                    : widget.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (widget.isVerified && !widget.isMe) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 15),
                            ],
                          ],
                        ),
                      ),
                      if (qualite.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            qualite,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: couleurQualite,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // ── Le micro à la source, en haut à droite ────────────────
              //
              // La maquette pose ici une pastille de réseau (4G, LTE, Fibre).
              // Le TYPE de réseau n'est pas connu de l'application — seule la
              // QUALITÉ l'est, et elle est déjà écrite sous le nom. Inventer
              // « 4G » aurait donné une tuile qui affirme ce qu'elle ignore.
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _sourceMuted
                        ? AppColors.semanticError.withValues(alpha: 0.12)
                        : AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _sourceMuted ? Icons.mic_off : Icons.mic,
                    size: 15,
                    color: _sourceMuted
                        ? AppColors.semanticError
                        : Colors.white,
                  ),
                ),
              ),

              if (widget.showMuteButton)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Semantics(
                    button: true,
                    label: l.callMutedShort,
                    child: InkWell(
                      onTap: _toggleLocalMute,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceElevated,
                        ),
                        child: Icon(
                          _locallyMuted ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                          color: _locallyMuted
                              ? AppColors.semanticError
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

              // En bas à droite, la place que le bouton « couper le son »
              // occupe sur les tuiles des autres : ma tuile ne l'a pas.
              if (video && widget.onFlipCamera != null)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Semantics(
                    button: true,
                    label: l.callFlipCamera,
                    child: Tooltip(
                      message: l.callFlipCamera,
                      child: InkWell(
                        onTap: widget.onFlipCamera,
                        customBorder: const CircleBorder(),
                        // 44 points de cible pour un rond de 34 : la tuile
                        // incrustée ne fait que 110 points de large.
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                              child: const Icon(
                                Icons.flip_camera_ios_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'anneau qui pulse autour de qui parle.
///
/// Il grandit et s'estompe, il ne clignote pas. Et il n'existe QUE pendant
/// la parole : hors de ce moment, `RepaintBoundary` n'a rien à redessiner.
///
/// `prefers-reduced-motion` est respecté : quand l'utilisateur a demandé
/// moins d'animations, l'anneau reste posé, à taille fixe. L'information —
/// qui parle — passe alors par la seule couleur, sans mouvement.
class _SpeakingRing extends StatelessWidget {
  const _SpeakingRing({
    required this.pulse,
    required this.speaking,
    required this.child,
  });

  final AnimationController pulse;
  final bool speaking;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduit = MediaQuery.disableAnimationsOf(context);

    if (!speaking) return child;

    final anneau = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentPrimary.withValues(alpha: 0.16),
          ),
          child: child,
        ),
        // La pastille d'onde, en bas à droite.
        //
        // Elle double l'anneau, et ce n'est pas redondant : l'anneau se
        // perçoit par le mouvement, la pastille par la forme. Quelqu'un qui
        // a désactivé les animations garde le second, et quelqu'un qui
        // regarde du coin de l'œil garde le premier.
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: const Icon(Icons.graphic_eq, size: 11, color: Colors.white),
          ),
        ),
      ],
    );

    if (reduit) return anneau;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, enfant) {
          // 1,0 → 1,06 : assez pour se voir du coin de l'œil, assez peu
          // pour ne pas faire bouger la grille autour.
          final t = Curves.easeInOut.transform(pulse.value);
          return Transform.scale(scale: 1 + t * 0.06, child: enfant);
        },
        child: anneau,
      ),
    );
  }
}

/// Un contrôle d'appel — pictogramme ET libellé, dans une carte.
///
/// `active` veut dire « cet état est EN COURS » : micro coupé, caméra
/// éteinte. La carte se remplit alors de vert, parce que c'est un état
/// qu'on a choisi et qu'on doit pouvoir vérifier d'un coup d'œil — pas une
/// erreur.
class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final encre = active ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        borderRadius: AppRadius.chip,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.accentPrimary : AppColors.surface,
            borderRadius: AppRadius.chip,
            border: Border.all(
              color: active ? AppColors.accentPrimary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: encre),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

/// La grille des participants, précédée de la note de sécurité.
///
/// ── Pourquoi cette ligne existe ────────────────────────────────────
///
/// Un appel de groupe Pokou n'est PAS chiffré de bout en bout : le média
/// passe par LiveKit, qui peut donc l'entendre. Un appel à deux l'est dès
/// que les deux applications le savent (voir CallRepository.startCall).
///
/// La maquette dit exactement cela, et c'est ce qui la rend juste :
/// « Appel de groupe standard (non chiffré 1:1) ». Une messagerie qui écrit
/// « chiffré » sur ses conversations doit dire où ça s'arrête, sinon la
/// mention ne vaut plus rien là où elle est vraie.
///
/// Cadenas OUVERT et gris, pas rouge : ce n'est pas une alerte, c'est un
/// fait. L'utilisateur choisit en connaissance de cause.
///
/// Un appel à deux CHIFFRÉ qui s'ouvre à un tiers reste chiffré (chaque
/// invité reçoit la clé, voir CallRepository.inviteToCall) : la note dit
/// alors l'inverse, cadenas fermé.
class _WithSecurityNote extends StatelessWidget {
  const _WithSecurityNote({required this.child, this.encrypted = false});

  final Widget child;
  final bool encrypted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                encrypted ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  encrypted
                      ? L.of(context).e2eeEncrypted
                      : L.of(context).callGroupNotEncrypted,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// « Chiffré de bout en bout », discret, en haut d'un appel à deux — la
/// même mention que sous le nom d'une conversation chiffrée. Absente d'un
/// appel standard : on n'affirme que ce qui est vrai. « Non chiffré »
/// quand un appel censé l'être reçoit des pistes en clair.
class _EncryptedCallLabel extends StatelessWidget {
  const _EncryptedCallLabel({required this.encrypted});

  final bool encrypted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              encrypted ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 12,
              color: Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              encrypted
                  ? L.of(context).e2eeEncrypted
                  : L.of(context).e2eeNotEncrypted,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
