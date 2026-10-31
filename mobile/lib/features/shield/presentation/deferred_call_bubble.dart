import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/incoming_call_screen.dart';
import 'shield_controller.dart';

/// Petite bulle flottante pour un appel mis en attente par le Mode Bouclier
/// ("Appel de X — En attente", voir le cahier des charges) — affichée par
/// dessus l'écran courant, quel qu'il soit (montée dans MaterialApp.builder,
/// voir main.dart), donc jamais liée à une navigation précise.
class DeferredCallBubble extends ConsumerWidget {
  const DeferredCallBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deferredCall = ref.watch(
      shieldControllerProvider.select((s) => s.deferredCall),
    );
    if (deferredCall == null) return const SizedBox.shrink();

    return Positioned(
      top: 56,
      right: 16,
      left: 16,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: AppColors.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              ref.read(shieldControllerProvider.notifier).dismissDeferredCall();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncomingCallScreen(
                    room: deferredCall.room,
                    fromUserId: deferredCall.fromUserId,
                    callType: deferredCall.callType,
                    isVideo: deferredCall.isVideo,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    deferredCall.isVideo ? Icons.videocam : Icons.call,
                    color: AppColors.accentPrimaryDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          L.of(context).shieldCallFrom(deferredCall.fromName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          L.of(context).shieldCallHeld,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      ref
                          .read(shieldControllerProvider.notifier)
                          .dismissDeferredCall();
                      await ref
                          .read(callRepositoryProvider)
                          .signal(
                            room: deferredCall.room,
                            targetUserId: deferredCall.fromUserId,
                            event: 'decline',
                          );
                    },

                    tooltip: L.of(context).actionClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
