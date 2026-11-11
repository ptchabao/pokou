import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'group_controller.dart';
import 'group_conversation_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Création d'un groupe — nom + sélection multiple de contacts sur un seul
/// écran (plutôt que l'assistant en deux étapes de WhatsApp) : la liste des
/// contacts Pokou reste courte, un aller-retour de navigation n'apporterait
/// rien ici.
///
/// Seuls les contacts déjà inscrits sur Pokou sont sélectionnables — le
/// serveur refuse d'ajouter un membre absent du carnet d'adresses
/// (`_require_contact` dans api/app/routes/groups.py), et un non-inscrit n'a
/// pas de user_id à envoyer.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, required this.myUserId});

  final int myUserId;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _selected = <int>{};
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_creating &&
      _nameController.text.trim().isNotEmpty &&
      _selected.isNotEmpty;

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _creating = true);
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .createGroup(
            name: _nameController.text.trim(),
            memberUserIds: _selected.toList(),
          );
      // La liste des groupes est un FutureProvider : sans invalidation, le
      // groupe tout juste créé n'apparaîtrait qu'au prochain démarrage.
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      // pushReplacement : revenir en arrière depuis la conversation doit
      // ramener aux contacts, pas au formulaire de création déjà consommé.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupConversationScreen(
            myUserId: widget.myUserId,
            groupId: group.id,
            groupName: group.name,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : L.of(context).groupCreateFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(L.of(context).groupNewTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canCreate ? _create : null,
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(L.of(context).groupCreateAction),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 255,
              decoration: InputDecoration(
                hintText: L.of(context).groupNameHint,
                prefixIcon: Icon(
                  Icons.groups_outlined,
                  color: AppColors.textMuted,
                ),
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selected.isEmpty
                    ? L.of(context).groupPickParticipants
                    : L.of(context).groupSelectedCount(_selected.length),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  error is ApiException
                      ? error.message
                      : L.of(context).contactConnectFailed,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              data: (allContacts) {
                final contacts = allContacts
                    .where(
                      (contact) =>
                          contact.isRegistered && contact.contactUserId != null,
                    )
                    .toList();
                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "Aucun de tes contacts n'est encore sur Pokou.\nInvite-les pour créer un groupe.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final userId = contact.contactUserId!;
                    final checked = _selected.contains(userId);
                    return InkWell(
                      borderRadius: AppRadius.card,
                      onTap: () => setState(() {
                        checked
                            ? _selected.remove(userId)
                            : _selected.add(userId);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.card,
                          border: Border.all(
                            color: checked
                                ? AppColors.accentPrimaryDark
                                : AppColors.border,
                            width: checked ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            ContactAvatar(
                              avatar: contact.avatar,
                              displayName: contact.displayName,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contact.phone,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              checked
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 22,
                              color: checked
                                  ? AppColors.accentPrimaryDark
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
