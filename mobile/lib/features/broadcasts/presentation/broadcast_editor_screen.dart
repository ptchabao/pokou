import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/broadcast_model.dart';
import 'broadcast_controller.dart';

/// Composer une liste — un nom, et des destinataires cochés dans son carnet.
///
/// Uniquement le carnet : c'est le garde-fou qui empêche une liste de
/// diffusion de devenir un outil d'envoi en masse (le serveur écarte de
/// toute façon tout identifiant absent du carnet, voir broadcasts.py).
class BroadcastEditorScreen extends ConsumerStatefulWidget {
  const BroadcastEditorScreen({super.key, this.existing});

  /// `null` pour une création. Renseigné, l'écran modifie la liste existante.
  final BroadcastList? existing;

  @override
  ConsumerState<BroadcastEditorScreen> createState() =>
      _BroadcastEditorScreenState();
}

class _BroadcastEditorScreenState extends ConsumerState<BroadcastEditorScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final Set<int> _selected = {
    ...?widget.existing?.members.map((m) => m.userId),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = L.of(context).bcastNeedName);
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = L.of(context).bcastNeedRecipient);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(broadcastRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        await repository.create(name: name, memberUserIds: _selected.toList());
      } else {
        await repository.update(
          listId: existing.id,
          name: name,
          memberUserIds: _selected.toList(),
        );
      }
      ref.invalidate(broadcastListsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).bcastSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? L.of(context).bcastNewTitle
                          : L.of(context).bcastEditTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: L.of(context).bcastNameHint,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                _selected.isEmpty
                    ? L.of(context).bcastNoRecipient
                    : L.of(context).bcastRecipientCount(_selected.length),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.semanticError),
                ),
              ),
            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    Center(child: Text(L.of(context).bcastContactsUnavailable)),
                data: (contacts) {
                  // Seuls les contacts RATTACHÉS à un compte : on ne peut pas
                  // écrire à un numéro qui n'a pas encore l'application.
                  final reachable = contacts
                      .where((c) => c.contactUserId != null)
                      .toList();
                  if (reachable.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          L.of(context).bcastNobodyOnPokou,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: reachable.length,
                    itemBuilder: (context, index) {
                      final contact = reachable[index];
                      final id = contact.contactUserId!;
                      return CheckboxListTile(
                        value: _selected.contains(id),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
                        secondary: ContactAvatar(
                          avatar: contact.avatar,
                          displayName: contact.displayName,
                          size: 40,
                        ),
                        title: Text(contact.displayName),
                        subtitle: Text(
                          contact.phone,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(L.of(context).actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
