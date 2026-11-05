import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'call_screen.dart';
import 'call_session.dart';

/// Le cadre de toute l'application pendant un appel : un bandeau « Appel en
/// cours » au-dessus des écrans, tant que l'appel tourne et qu'aucun écran
/// d'appel ne le montre.
///
/// La STRUCTURE ne change jamais — une colonne, le bandeau (de hauteur nulle
/// quand il est caché), puis l'application. Envelopper l'application d'un
/// widget de plus seulement pendant l'appel déplacerait son `Navigator` dans
/// l'arbre, et Flutter le recréerait : toute la navigation en cours serait
/// perdue au moment même où l'on quitte l'écran d'appel.
class OngoingCallFrame extends StatelessWidget {
  const OngoingCallFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallSession?>(
      valueListenable: activeCall,
      builder: (context, session, _) => ListenableBuilder(
        listenable: session ?? const _NothingToListen(),
        builder: (context, _) {
          final visible =
              session != null && !session.ended && session.attachedScreens == 0;
          return Column(
            children: [
              if (visible) _OngoingCallBar(session: session),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  // Le bandeau occupe déjà la place de la barre d'état.
                  removeTop: visible,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NothingToListen implements Listenable {
  const _NothingToListen();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _OngoingCallBar extends StatefulWidget {
  const _OngoingCallBar({required this.session});

  final CallSession session;

  @override
  State<_OngoingCallBar> createState() => _OngoingCallBarState();
}

class _OngoingCallBarState extends State<_OngoingCallBar> {
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _return() {
    final s = widget.session;
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          livekitUrl: s.livekitUrl,
          token: s.token,
          room: s.roomName,
          otherParticipantIds: s.participantIds,
          startWithVideo: s.startWithVideo,
          groupId: s.groupId,
          groupMembers: s.groupMembers,
          joiningExistingCall: true,
        ),
      ),
    );
  }

  Future<void> _hangUp() async {
    final shouldHangUp = await confirmCallHangUp(context);
    if (shouldHangUp == true) await widget.session.hangUp();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final since = widget.session.connectedAt;
    final label = since == null
        ? l.callOngoingBannerRinging
        : l.callOngoingBanner(_duration(DateTime.now().difference(since)));
    return Material(
      color: AppColors.accentPrimary,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: _return,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.call, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _hangUp,
                  tooltip: l.callHangUp,
                  icon: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
