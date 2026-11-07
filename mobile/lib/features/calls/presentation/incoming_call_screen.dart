import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/crypto/call_keys.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/call_repository.dart';
import 'call_controller.dart';
import 'call_screen.dart';
import 'call_session.dart';
import 'ringtone_player.dart';
import '../../../core/widgets/verified_badge.dart';

/// Plein écran "appel entrant" — poussé par [callSignalingProvider] dès
/// qu'un événement `call:invite` arrive, quel que soit l'écran affiché.
class IncomingCallScreen extends ConsumerStatefulWidget {
  /// Tests uniquement : remplace l'écran d'appel ouvert en décrochant, pour
  /// ne pas démarrer un vrai moteur LiveKit dans un test d'interface.
  @visibleForTesting
  static Widget Function(Future<CallToken> pending)? debugCallScreenOverride;

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
  Timer? _waitingVibration;

  /// Déjà en appel dans un AUTRE salon : c'est un double appel. Accepter
  /// terminera l'appel en cours (jamais deux communications à la fois) ;
  /// refuser le laisse intact.
  bool get _busy {
    final current = activeCall.value;
    return current != null && !current.ended && current.roomName != widget.room;
  }

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
    //
    // Double appel : déjà en communication, la sonnerie couvrirait la voix
    // de l'autre. Vibration seule — l'écran dit le reste.
    if (_busy) {
      _waitingVibration = Timer.periodic(
        const Duration(seconds: 2),
        (_) => HapticFeedback.heavyImpact(),
      );
      HapticFeedback.heavyImpact();
    } else {
      unawaited(_ringtonePlayer.playRingtone());
    }
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
    _waitingVibration?.cancel();
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
    _waitingVibration?.cancel();
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
    _waitingVibration?.cancel();
    setState(() => _responding = true);
    // Double appel : l'appel en cours sera terminé, PROPREMENT et AVANT
    // d'entrer dans le nouveau — jamais deux salons ouverts à la fois.
    final previous = activeCall.value;
    final switching =
        previous != null && !previous.ended && previous.roomName != widget.room;
    try {
      final calls = ref.read(callRepositoryProvider);
      // Le jeton est DEMANDÉ ici mais pas attendu : l'écran d'appel s'ouvre
      // tout de suite (« Connexion… ») au lieu de laisser l'écran de
      // sonnerie figé pendant l'aller-retour serveur et l'ouverture de la
      // clé. CallSession attend ce jeton avant d'entrer dans le salon.
      // Future.sync : une erreur levée tout de suite passe par le même
      // chemin qu'une erreur réseau (l'écran d'appel l'affiche).
      final pending = Future.sync(
        () => calls.joinCall(widget.room, inviter: widget.fromUserId),
      );
      unawaited(
        pending.then(
          (_) => calls
              .signal(
                room: widget.room,
                targetUserId: widget.fromUserId,
                event: 'accept',
              )
              .catchError((Object error) {
                debugPrint('[Calls] accept signal failed: $error');
              }),
          onError: (Object error) {
            // Clé illisible ici : l'appelant doit l'apprendre, sinon il
            // sonnerait dans le vide jusqu'au délai de non-réponse.
            if (error is CallEncryptionException) {
              unawaited(
                calls
                    .signal(
                      room: widget.room,
                      targetUserId: widget.fromUserId,
                      event: 'decline',
                    )
                    .catchError((_) {}),
              );
            }
          },
        ),
      );
      final navigator = Navigator.of(context);
      if (switching) {
        // 1. Retirer l'écran de l'ancien appel (il ne doit plus réagir).
        for (final route in CallScreen.openRoutes.toList()) {
          if (route.isActive) navigator.removeRoute(route);
        }
        // 2. Terminer l'ancien appel et attendre sa libération (micro,
        //    caméra, salon) avant d'ouvrir le nouveau.
        try {
          await previous.hangUp();
        } catch (_) {}
        if (!mounted) return;
      }
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              IncomingCallScreen.debugCallScreenOverride?.call(pending) ??
              CallScreen(
                livekitUrl: '',
                token: '',
                room: widget.room,
                pendingJoin: pending,
                // Mis à jour par la session quand le serveur renvoie la liste
                // complète (appel de groupe).
                otherParticipantIds: [widget.fromUserId],
                startWithVideo: widget.isVideo,
                groupId: widget.groupId,
                // On vient d'accepter : jamais de ringback ici (voir
                // CallScreen.joiningExistingCall).
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
            if (_busy) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  L.of(context).callWaitingNotice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
            const Spacer(),
            if (_responding)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 52),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 40,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ResponseButton(
                      icon: Icons.call_end,
                      color: Colors.black,
                      onTap: _decline,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ResponseButton(
                          icon: _busy ? Icons.phone_forwarded : Icons.call,
                          color: AppColors.accentPrimary,
                          onTap: _accept,
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 8),
                          Text(
                            L.of(context).callEndAndAccept,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
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
