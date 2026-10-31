import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import 'shield_controller.dart';

/// Enveloppe un écran de conversation avec l'indicateur du Mode Bouclier et
/// le geste "swipe to override" (glisser vers la droite n'importe où pour
/// révéler immédiatement les messages en attente sans désactiver le
/// bouclier — edge case #1 du cahier des charges).
///
/// Pas de couleur pour signaler l'activation (voir aussi le retrait spatial
/// "shrine" dans conversation_screen.dart) : un "tiroir silencieux" — un
/// simple filet blanc de 1px qui glisse en place au-dessus de la barre de
/// saisie — indique juste qu'il y a des messages en attente ; glisser
/// doucement vers le bas dessus les révèle.
class ShieldOverlay extends ConsumerStatefulWidget {
  const ShieldOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShieldOverlay> createState() => _ShieldOverlayState();
}

class _ShieldOverlayState extends ConsumerState<ShieldOverlay> {
  void _override() {
    final deferred = ref
        .read(shieldControllerProvider.notifier)
        .revealDeferredMessages();
    if (deferred.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.of(context).shieldPendingMessages,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final message in deferred)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentPrimaryLight,
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(message.senderName),
                subtitle: Text(
                  message.count > 1
                      ? '${message.count} messages — ${message.lastPreview}'
                      : message.lastPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shieldControllerProvider);

    ref.listen(shieldControllerProvider.select((s) => s.lastFlushSummary), (
      previous,
      next,
    ) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
      ref.read(shieldControllerProvider.notifier).consumeFlushSummary();
    });

    if (!state.active) return widget.child;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) _override();
      },
      child: Stack(
        children: [
          widget.child,
          if (state.deferredMessages.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: SafeArea(
                top: false,
                child: _SilentDrawerHandle(
                  count: state.totalDeferredCount,
                  onReveal: _override,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filet blanc de 1px qui glisse en place (pas de couleur) — glisser vers
/// le bas dessus révèle le tiroir des messages en attente ; un tap fait de
/// même, pour rester accessible sans dépendre uniquement du geste.
class _SilentDrawerHandle extends StatefulWidget {
  const _SilentDrawerHandle({required this.count, required this.onReveal});

  final int count;
  final VoidCallback onReveal;

  @override
  State<_SilentDrawerHandle> createState() => _SilentDrawerHandleState();
}

class _SilentDrawerHandleState extends State<_SilentDrawerHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _slideIn = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _settleController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideIn,
      child: GestureDetector(
        onTap: widget.onReveal,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 150) widget.onReveal();
        },
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: L.of(context).shieldHandleSemantic(widget.count),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Container(
              height: 1,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
