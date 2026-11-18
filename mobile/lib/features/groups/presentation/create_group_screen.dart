import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/media/image_cropper.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'group_controller.dart';
import 'group_conversation_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_sheet.dart';

/// Discussions · 6 — Nouveau groupe.
///
/// Photo, nom, membres en puces (✕ pour retirer, « + Ajouter » pour en
/// choisir), deux réglages de départ, et « Créer le groupe » en bas. Un seul
/// écran plutôt que l'assistant en deux étapes de WhatsApp : la liste des
/// contacts Pokou reste courte.
///
/// Seuls les contacts déjà inscrits sur Pokou sont proposés — le serveur
/// refuse d'ajouter un membre absent du carnet d'adresses
/// (`_require_contact` dans api/app/routes/groups.py), et un non-inscrit n'a
/// pas de user_id à envoyer.
///
/// La photo et les deux réglages s'appliquent JUSTE APRÈS la création (le
/// serveur ne les prend pas à la création) : s'ils échouent, le groupe
/// existe quand même, et on le dit sans annuler.
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

  /// La photo choisie, déjà recadrée en carré (PNG).
  Uint8List? _photo;

  /// « Seuls les administrateurs modifient le groupe » — activé par défaut.
  bool _adminsOnlyEdit = true;

  /// « Lien d'invitation » — désactivé par défaut : un lien est une
  /// autorisation à lui seul.
  bool _inviteLink = false;

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

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await cropSquareImage(context, bytes);
    if (cropped != null && mounted) setState(() => _photo = cropped);
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _creating = true);
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(groupRepositoryProvider);
      final group = await repository.createGroup(
        name: _nameController.text.trim(),
        memberUserIds: _selected.toList(),
      );
      // Les réglages de départ : un échec ne défait pas le groupe.
      var settingsFailed = false;
      try {
        final photo = _photo;
        if (photo != null) {
          final uploaded = await ref
              .read(mediaRepositoryProvider)
              .upload(
                bytes: photo,
                filename: 'groupe.png',
                mimeType: 'image/png',
                messageType: 'IMAGE',
              );
          await repository.updateGroup(
            groupId: group.id,
            avatarMediaId: uploaded.id,
          );
        }
        if (!_adminsOnlyEdit) {
          await repository.updateSettings(
            groupId: group.id,
            membersCanEditInfo: true,
          );
        }
        if (_inviteLink) await repository.createInviteLink(group.id);
      } catch (_) {
        settingsFailed = true;
      }
      // La liste des groupes est un FutureProvider : sans invalidation, le
      // groupe tout juste créé n'apparaîtrait qu'au prochain démarrage.
      ref.invalidate(myGroupsProvider);
      if (settingsFailed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.groupCreateSettingsFailed)),
        );
      }
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : l.groupCreateFailed,
          ),
        ),
      );
    }
  }

  /// « + Ajouter » : les contacts Pokou, à cocher.
  Future<void> _pickMembers(List<PokouContact> contacts) async {
    final picked = {..._selected};
    final done = await showPokouSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, controller) => Column(
            children: [
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            L.of(context).groupNoPokouContacts,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView(
                        controller: controller,
                        children: [
                          for (final contact in contacts)
                            CheckboxListTile(
                              value: picked.contains(contact.contactUserId),
                              activeColor: AppColors.accentPrimary,
                              onChanged: (value) => setSheetState(() {
                                value == true
                                    ? picked.add(contact.contactUserId!)
                                    : picked.remove(contact.contactUserId);
                              }),
                              secondary: ContactAvatar(
                                avatar: contact.avatar,
                                displayName: contact.displayName,
                                size: 38,
                              ),
                              title: Text(contact.displayName),
                              // L'état, jamais le numéro.
                              subtitle: Text(
                                contact.about?.trim().isNotEmpty == true
                                    ? contact.about!
                                    : L.of(context).contactAvailable,
                              ),
                            ),
                        ],
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text(
                        L.of(context).groupSelectedCount(picked.length),
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
    if (done == true && mounted) {
      setState(() {
        _selected
          ..clear()
          ..addAll(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final contacts = (ref.watch(contactsProvider).valueOrNull ?? const [])
        .where((c) => c.isRegistered && c.contactUserId != null)
        .toList();
    final chosen = contacts
        .where((c) => _selected.contains(c.contactUserId))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.groupNewTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              l.groupMembersChosen(_selected.length),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Semantics(
                        button: true,
                        label: l.groupAddPhoto,
                        child: InkWell(
                          onTap: _pickPhoto,
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.surfaceElevated,
                            backgroundImage: _photo == null
                                ? null
                                : MemoryImage(_photo!),
                            child: _photo == null
                                ? Icon(
                                    Icons.photo_camera_outlined,
                                    color: AppColors.textSecondary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.groupName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              contextMenuBuilder: pokouContextMenuBuilder,
                              controller: _nameController,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 255,
                              decoration: InputDecoration(
                                hintText: l.groupNameHint,
                                counterText: '',
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l.groupMembersSection(_selected.length),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final contact in chosen)
                        InputChip(
                          avatar: ContactAvatar(
                            avatar: contact.avatar,
                            displayName: contact.displayName,
                            size: 22,
                          ),
                          label: Text(contact.displayName),
                          onDeleted: () => setState(
                            () => _selected.remove(contact.contactUserId),
                          ),
                          deleteButtonTooltipMessage: l.actionDelete,
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(l.groupInfoAdd),
                        onPressed: () => _pickMembers(contacts),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _adminsOnlyEdit,
                          onChanged: (v) => setState(() => _adminsOnlyEdit = v),
                          activeTrackColor: AppColors.accentPrimary,
                          title: Text(l.groupNewAdminsOnly),
                          subtitle: Text(l.groupNewAdminsOnlyHint),
                        ),
                        SwitchListTile(
                          value: _inviteLink,
                          onChanged: (v) => setState(() => _inviteLink = v),
                          activeTrackColor: AppColors.accentPrimary,
                          title: Text(l.groupInviteLink),
                          subtitle: Text(l.groupNewInviteHint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.groupNewFootnote,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _canCreate ? _create : null,
                  child: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.groupNewCreate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
