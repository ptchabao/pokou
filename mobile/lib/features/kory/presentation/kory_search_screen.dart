import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_home_widgets.dart';
import 'kory_pot_screen.dart';
import 'kory_screen.dart';
import 'kory_ui.dart';

/// « mariage » trouve « Mariage », « bapteme » trouve « Baptême » : la
/// recherche ignore la casse et les accents courants.
String koryFold(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final lower = text.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

/// Ranger une collecte finie dans MES archives, ou l'en sortir — avec
/// « Annuler » dans le message, parce qu'un geste qui fait disparaître une
/// carte doit pouvoir se défaire.
Future<void> koryToggleArchive(
  BuildContext context,
  WidgetRef ref,
  KoryPot pot,
) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(koryRepositoryProvider);
  final archive = !pot.archived;
  try {
    await repo.setArchived(pot.id, archived: archive);
  } catch (_) {
    if (context.mounted) koryFailed(context);
    return;
  }
  refreshKory(ref, potId: pot.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(archive ? l.koryTArchivedToast : l.koryTUnarchivedToast),
        action: SnackBarAction(
          label: l.koryTUndo,
          onPressed: () async {
            try {
              await repo.setArchived(pot.id, archived: !archive);
              refreshKory(ref, potId: pot.id);
            } catch (_) {
              // L'état affiché reste celui du serveur.
            }
          },
        ),
      ),
    );
}

/// La loupe de l'en-tête Kory : une recherche plein écran sur toutes mes
/// collectes, archives comprises, et l'entrée de la boîte « Archives ».
class KorySearchScreen extends ConsumerStatefulWidget {
  const KorySearchScreen({super.key});

  @override
  ConsumerState<KorySearchScreen> createState() => _KorySearchScreenState();
}

class _KorySearchScreenState extends ConsumerState<KorySearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<KoryPot> _match(List<KoryPot>? pots, String query) => [
    for (final pot in pots ?? const <KoryPot>[])
      if (koryFold(pot.title).contains(query)) pot,
  ];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = koryFold(_query.text);
    final active = ref.watch(koryPotsProvider).valueOrNull;
    final archived = ref.watch(koryArchivedPotsProvider).valueOrNull;
    final found = query.isEmpty ? const <KoryPot>[] : _match(active, query);
    final foundArchived = query.isEmpty
        ? const <KoryPot>[]
        : _match(archived, query);
    return KoryPage(
      title: l.koryTSearch,
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          KoryHomeSearchField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_query.clear),
          ),
          const SizedBox(height: 14),
          KoryActionRow(
            icon: Icons.inventory_2_outlined,
            title: l.koryTArchives,
            subtitle: l.koryTArchivesHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KoryArchivesScreen()),
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.koryTSearchPrompt,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else if (found.isEmpty && foundArchived.isEmpty)
            KoryHomeMessage(
              illustration: PokouIllustrations.searchEmpty,
              illustrationHeight: 120,
              title: l.koryHomeNoMatch,
              message: l.koryHomeNoMatchBody,
              actions: const [],
            )
          else ...[
            const SizedBox(height: 8),
            for (final pot in found)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: KoryPotCard(pot: pot),
              ),
            if (foundArchived.isNotEmpty) ...[
              KorySection(l.koryTSearchInArchives),
              for (final pot in foundArchived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KoryPotCard(pot: pot),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// « Archives » : les collectes terminées ou expirées que J'AI rangées.
/// Chacune reste consultable et peut revenir dans la liste.
class KoryArchivesScreen extends ConsumerWidget {
  const KoryArchivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final archived = ref.watch(koryArchivedPotsProvider);
    return KoryPage(
      title: l.koryTArchives,
      subtitle: l.koryTArchivesHint,
      loading: archived.isLoading && !archived.hasValue,
      body: RefreshIndicator(
        color: AppColors.accentPrimary,
        onRefresh: () async {
          ref.invalidate(koryArchivedPotsProvider);
          await ref.read(koryArchivedPotsProvider.future);
        },
        child: archived.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => ListView(
            children: [
              KoryHomeMessage(
                illustration: PokouIllustrations.offline,
                title: l.koryUnavailable,
                message: l.modulesCheckNetwork,
                actions: [
                  KoryHomePillButton(
                    icon: Icons.refresh,
                    label: l.actionRetry,
                    onPressed: () => ref.invalidate(koryArchivedPotsProvider),
                  ),
                ],
              ),
            ],
          ),
          data: (pots) => pots.isEmpty
              ? ListView(
                  children: [
                    KoryHomeMessage(
                      illustration: PokouIllustrations.kory,
                      illustrationHeight: 140,
                      title: l.koryTArchivesEmptyTitle,
                      message: l.koryTArchivesEmptyBody,
                      actions: const [],
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: pots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => KoryPotCard(pot: pots[index]),
                ),
        ),
      ),
    );
  }
}
