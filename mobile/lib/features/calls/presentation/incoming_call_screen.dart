import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/crypto/call_keys.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'call_controller.dart';
import 'call_screen.dart';
import 'ringtone_player.dart';
import '../../../core/widgets/verified_badge.dart';

/// Plein écran "appel entrant" — poussé par [callSignalingProvider] dès
/// qu'un événement `call:invite` arrive, quel que soit l'écran affiché.
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.room,
    required this.fromUserId,
    required this.callType,
    required this.isVideo,
    this.groupId,
    this.groupName,
    this.callerName,
    this.callerIsVerified = false,
    @visibleForTesting this.ringtonePlayer,
  });

  final String room;
  final int fromUserId;
  final String callType; // 1:1 | group
  final bool isVideo;

  /// Renseignés quand l'appel vient d'une conversation de groupe : on annonce
  /// le groupe, pas seulement celui qui appelle.
  final int? groupId;
  final String? groupName;

  /// Le nom à annoncer quand il est connu d'avance : celui d'un compte
  /// CERTIFIÉ (qui l'emporte sur le carnet), ou celui que le serveur a déjà
  /// résolu dans le push. Sinon, le carnet de cet appareil.
  final String? callerName;

  /// Le ✓ d'identité — il manquait sur l'écran qui demande justement
  /// « décrocher ? », c'est-à-dire là où savoir qui appelle compte le plus.
  final bool callerIsVerified;

  /// Injectable pour les tests (faux lecteur, sans son réel) — `null` en
  /// production, où l'écran crée son propre RingtonePlayer.
  final RingtonePlayer? ringtonePlayer;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _responding = false;
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;

  /// Filet si `call:end` n'arrive jamais (appelant tombé, socket coupé) :
  /// l'écran sonnait alors sans fin. Plus long que le délai de l'appelant
  /// (kNoAnswerTimeout) pour ne jamais couper un appel encore vivant.
  Timer? _giveUpTimer;
  late final RingtonePlayer _ringtonePlayer =
      widget.ringtonePlayer ?? RingtonePlayer();

  @override
  void initState() {
    super.initState();
    _listenForCancellation();
    _giveUpTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || _responding) return;
      unawaited(_ringtonePlayer.stop());
      Navigator.of(context).maybePop();
    });
    // Sonnerie d'appel entrant, tant que rien n'a encore été décidé — arrêtée
    // dans dispose() et dès la réponse (voir _accept/_decline), avant même
    // la navigation qui en découle.
    unawaited(_ringtonePlayer.playRingtone());
  }

  /// L'appelant a renoncé avant qu'on décroche : le serveur pousse
  /// `call:end` (voir api/app/routes/calls.py::signal_call). Sans cette
  /// écoute, l'écran continuait de sonner indéfiniment.
  void _listenForCancellation() {
    _signalSubscription = ref.read(wsClientProvider).events.listen((event) {
      if (event['type'] != 'call:end') return;
      if (event['room'] != widget.room) return;
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _giveUpTimer?.cancel();
    _signalSubscription?.cancel();
    unawaited(_ringtonePlayer.stop());
    // Ne libère le lecteur natif que s'il a été créé ici — une instance
    // injectée depuis un test n'est pas la nôtre.
    if (widget.ringtonePlayer == null) unawaited(_ringtonePlayer.dispose());
    super.dispose();
  }

  Future<void> _decline() async {
    // Arrêt immédiat, avant même l'appel réseau : dès que l'utilisateur a
    // répondu, plus une seconde de sonnerie.
    unawaited(_ringtonePlayer.stop());
    setState(() => _responding = true);
    try {
      await ref
          .read(callRepositoryProvider)
          .signal(
            room: widget.room,
            targetUserId: widget.fromUserId,
            event: 'decline',
          );
    } finally {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _accept() async {
    // Idem : coupée avant même de savoir si la connexion à l'appel va
    // réussir — une fois qu'on a décroché, on ne veut plus l'entendre.
    unawaited(_ringtonePlayer.stop());
    setState(() => _responding = true);
    try {
      final token = await ref
          .read(callRepositoryProvider)
          .joinCall(widget.room, inviter: widget.fromUserId);
      await ref
          .read(callRepositoryProvider)
          .signal(
            room: widget.room,
            targetUserId: widget.fromUserId,
            event: 'accept',
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            // Dans un appel de groupe, raccrocher doit se signaler à TOUS les
            // participants, pas seulement à celui qui a appelé — le serveur
            // renvoie la liste à jour en rejoignant.
            otherParticipantIds: token.participantIds.isEmpty
                ? [widget.fromUserId]
                : token.participantIds,
            startWithVideo: widget.isVideo,
            groupId: widget.groupId,
            // On vient d'accepter : le correspondant est déjà connecté (ou en
            // train de l'être) au salon, ce n'est pas un nouvel appel sortant
            // qui sonne — jamais de ringback ici (voir CallScreen.joiningExistingCall).
            joiningExistingCall: true,
          ),
        ),
      );
    } on CallEncryptionException {
      // La clé ne s'ouvre pas ici : on le dit à l'appelant, qui sinon
      // sonnerait dans le vide jusqu'au délai de non-réponse.
      unawaited(
        ref
            .read(callRepositoryProvider)
            .signal(
              room: widget.room,
              targetUserId: widget.fromUserId,
              event: 'decline',
            )
            .catchError((_) {}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).callEncryptedJoinFailed)),
        );
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _responding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).callJoinImpossible)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final PokouContact? contact = contactsAsync.maybeWhen(
      data: (contacts) {
        for (final c in contacts) {
          if (c.contactUserId == widget.fromUserId) return c;
        }
        return null;
      },
      orElse: () => null,
    );
    final callerName =
        widget.callerName ?? contact?.displayName ?? L.of(context).callIncoming;
    final callerVerified =
        widget.callerIsVerified || (contact?.isVerified ?? false);
    final isGroup = widget.groupId != null || widget.callType == 'group';
    final displayName = widget.groupName ?? callerName;

    return Scaffold(
      backgroundColor: AppColors.accentPrimaryDark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            if (widget.groupName != null)
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: const Icon(Icons.groups, size: 44, color: Colors.white),
              )
            else
              ContactAvatar(
                avatar: contact?.avatar,
                displayName: displayName,
                size: 96,
                fallbackBackgroundColor: Colors.white24,
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Sur le nom de l'APPELANT seulement : sous un nom de
                // groupe, le ✓ dirait que le groupe est certifié.
                if (callerVerified && widget.groupName == null) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 20),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isGroup
                  ? (widget.groupName != null
                        // Dans un groupe, savoir QUI appelle compte autant que
                        // le nom du groupe affiché juste au-dessus.
                        ? L.of(context).callIncomingFrom(callerName)
                        : L.of(context).callIncomingGroup)
                  : L.of(context).callIncoming,
              style: const TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ResponseButton(
                    icon: Icons.call_end,
                    color: Colors.black,
                    onTap: _responding ? null : _decline,
                  ),
                  _ResponseButton(
                    icon: Icons.call,
                    color: AppColors.accentPrimary,
                    onTap: _responding ? null : _accept,
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

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
