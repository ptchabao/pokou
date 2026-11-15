import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/conversation_summary.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../groups/presentation/group_controller.dart';
import '../../modules/shared/module_ui.dart';
import 'messaging_controller.dart' show messagingRepositoryProvider;
import 'proof_sheets.dart';

/// « Activer le mode preuve · Choisis une discussion » (maquette 27/66) :
/// le mode preuve se porte sur un point d'entrée unique une fois le badge
/// actif — on choisit où l'allumer, à deux ou en groupe, sans avoir à
/// retrouver la discussion depuis la liste des Discussions.
class ProofChooseDiscussionScreen extends ConsumerStatefulWidget {
  const ProofChooseDiscussionScreen({super.key});

  @override
  ConsumerState<ProofChooseDiscussionScreen> createState() => _ProofChooseDiscussionScreenState();
}

class _ProofChooseDiscussionScreenState extends ConsumerState<ProofChooseDiscussionScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _activate(ConversationSummary discussion) async {
    final l = L.of(context);
    final isGroup = discussion.kind == 'group';
    final confirmed = await showProofActivationSheet(
      context,
      isGroup: isGroup,
      scopeName: discussion.displayName,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      if (isGroup) {
        await ref.read(groupRepositoryProvider).setProofMode(discussion.id!, enabled: true);
      } else {
        await ref.read(messagingRepositoryProvider).setProofMode(discussion.contactUserId!, true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.proofActivatedFor(discussion.displayName))));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final discussions = ref.watch(discussionsProvider);
    return ModuleScaffold(
      title: l.proofModeEnable,
      subtitle: l.proofChooseDiscussion,
      child: discussions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
        data: (all) {
          final items = all
              .where((d) => d.kind == 'contact' || d.kind == 'group')
              .where((d) => !d.isBot)
              .where((d) => _query.isEmpty || d.displayName.toLowerCase().contains(_query.toLowerCase()))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModuleCallout(tone: CalloutTone.beige, text: l.proofChooseDiscussionNote),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.proofSearchDiscussion,
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final d = items[index];
                      return ListTile(
                        leading: ContactAvatar(avatar: d.avatar, displayName: d.displayName, size: 40),
                        title: Text(d.displayName),
                        subtitle: Text(d.kind == 'group' ? l.proofGroupSubtitle : l.proofDirectSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _activate(d),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.certLater),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
