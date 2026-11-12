import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'kory_ui.dart';
import 'kory_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Un participant en attente d'ajout : quelqu'un de Pokou (par son compte)
/// ou un numéro, qui recevra un SMS d'invitation.
class _Pending {
  const _Pending.user(this.userId, this.name) : phone = null;
  const _Pending.phone(this.phone, this.name) : userId = null;

  final int? userId;
  final String? phone;
  final String name;

  bool get onPokou => userId != null;
}

/// KOR-11 · Participants — étape 2 sur 3 de la création d'une cagnotte.
class KoryParticipantsScreen extends ConsumerStatefulWidget {
  const KoryParticipantsScreen({
    super.key,
    required this.potId,
    required this.title,
  });

  final int potId;
  final String title;

  @override
  ConsumerState<KoryParticipantsScreen> createState() =>
      _KoryParticipantsScreenState();
}

class _KoryParticipantsScreenState
    extends ConsumerState<KoryParticipantsScreen> {
  final _last = TextEditingController();
  final _first = TextEditingController();
  final _phone = TextEditingController(text: '+228 ');
  final List<_Pending> _pending = [];
  bool _busy = false;

  @override
  void dispose() {
    _last.dispose();
    _first.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// « +228 91 •• •• 07 » dès l'ajout (KORY-15).
  String _mask(String phone) {
    final digits = phone.replaceAll(' ', '');
    if (digits.length < 8) return phone;
    return '${digits.substring(0, 4)} ${digits.substring(4, 6)} •• •• '
        '${digits.substring(digits.length - 2)}';
  }

  void _addByNumber() {
    final l = L.of(context);
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryInvalidPhone)));
      return;
    }
    final name = [
      _last.text.trim(),
      _first.text.trim(),
    ].where((p) => p.isNotEmpty).join(' ');
    setState(() {
      _pending.add(_Pending.phone(digits, name.isEmpty ? _mask(digits) : name));
      _last.clear();
      _first.clear();
      _phone.text = '+228 ';
    });
  }

  Future<void> _fromContacts() async {
    final contacts =
        (ref.read(contactsProvider).valueOrNull ?? const <PokouContact>[])
            .where((c) => c.contactUserId != null)
            .toList();
    final picked = await showModalBottomSheet<PokouContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: ListView(
            children: [
              for (final c in contacts)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.terracottaTint,
                    foregroundColor: AppColors.onTerracottaTint,
                    child: Text(
                      c.displayName.isEmpty
                          ? '?'
                          : c.displayName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(c.displayName),
                  onTap: () => Navigator.pop(sheetContext, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (_pending.any((p) => p.userId == picked.contactUserId)) return;
    setState(
      () => _pending.add(
        _Pending.user(picked.contactUserId!, picked.displayName),
      ),
    );
  }

  Future<void> _continue() async {
    final l = L.of(context);
    if (_pending.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(koryRepositoryProvider)
          .addParticipants(
            widget.potId,
            userIds: [
              for (final p in _pending)
                if (p.userId != null) p.userId!,
            ],
            phones: [
              for (final p in _pending)
                if (p.phone != null) (phone: p.phone!, name: p.name),
            ],
          );
      refreshKory(ref, potId: widget.potId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryParticipantsTitle),
            Text(
              l.koryStepOf('2', widget.title, '3'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          KoryCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        contextMenuBuilder: pokouContextMenuBuilder,
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(labelText: l.koryLastName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        contextMenuBuilder: pokouContextMenuBuilder,
                        controller: _first,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(labelText: l.koryFirstName),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  decoration: InputDecoration(labelText: l.koryPhoneField),
                ),
                const SizedBox(height: 12),
                KoryButton(
                  quiet: true,
                  label: l.koryAddParticipant,
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: _addByNumber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.koryAddedCount('${_pending.length}'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _fromContacts,
                child: Text(l.koryFromContacts),
              ),
            ],
          ),
          for (final p in _pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.terracottaTint,
                foregroundColor: AppColors.onTerracottaTint,
                child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
              ),
              title: Text(p.name),
              subtitle: Text(p.onPokou ? l.koryOnPokou : _mask(p.phone!)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!p.onPokou)
                    Chip(
                      label: Text(l.koryInvitedChip),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    tooltip: l.koryRemoveParticipant(p.name),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _pending.remove(p)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            l.koryInviteNote,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: KoryButton(
            label: l.koryContinueWith(_pending.length),
            busy: _busy,
            onPressed: _busy ? null : _continue,
          ),
        ),
      ),
    );
  }
}
