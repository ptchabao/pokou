import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_back_button.dart';
import 'broadcast_controller.dart';
import 'broadcast_editor_screen.dart';
import 'broadcast_screen.dart';

/// Les listes de diffusion de l'utilisateur — les siennes, forcément : une
/// liste n'existe que pour son auteur, personne d'autre n'en connaît
/// l'existence.
class BroadcastListsScreen extends ConsumerWidget {
  const BroadcastListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(broadcastListsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BroadcastEditorScreen()),
          );
        },
        // Bouton à libellé : l'encre foncée (7,2:1), pas le bleu d'action.
        backgroundColor: AppColors.accentPrimaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: Text(L.of(context).bcastNewList),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 4),
                  Text(
                    L.of(context).bcastListsTitle,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: listsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    Center(child: Text(L.of(context).bcastListsUnavailable)),
                data: (lists) => lists.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 12, bottom: 88),
                        itemCount: lists.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: AppColors.border,
                          indent: 72,
                        ),
                        itemBuilder: (context, index) {
                          final broadcast = lists[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceElevated,
                              child: Icon(
                                Icons.campaign_outlined,
                                color: AppColors.accentPrimaryDark,
                              ),
                            ),
                            title: Text(broadcast.name),
                            subtitle: Text(
                              '${broadcast.memberCount} destinataire${broadcast.memberCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BroadcastScreen(broadcast: broadcast),
                              ),
                            ),
                            onLongPress: () => _confirmDelete(
                              context,
                              ref,
                              broadcast.id,
                              broadcast.name,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int listId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).bcastDeleteTitle(name)),
        // Le point qui compte : supprimer le carnet de copie ne retire rien
        // de ce qui est déjà arrivé chez les destinataires.
        content: Text(L.of(context).bcastDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              L.of(context).actionDelete,
              style: const TextStyle(color: AppColors.semanticError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(broadcastRepositoryProvider).delete(listId);
    ref.invalidate(broadcastListsProvider);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              L.of(context).bcastEmptyTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              L.of(context).bcastEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
