import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'kory_search_screen.dart' show koryFold;
import 'kory_ui.dart';

/// Une personne qu'on peut ajouter à une collecte : un compte Pokou
/// ([userId]) ou un numéro du carnet qui n'est pas encore sur Pokou
/// ([phone], invité par SMS).
class KoryPickable {
  const KoryPickable({
    required this.name,
    this.userId,
    this.phone,
    this.subtitle,
    this.already = false,
  });

  final String name;
  final int? userId;
  final String? phone;
  final String? subtitle;

  /// Déjà dans la collecte : visible, mais pas cochable.
  final bool already;

  String get key => userId != null ? 'u$userId' : 'p$phone';
  bool get onPokou => userId != null;
}

/// Le choix de plusieurs personnes, avec une recherche par nom ou numéro.
/// Renvoie la sélection, ou `null` si l'on revient sans choisir.
class KoryPeoplePicker extends StatefulWidget {
  const KoryPeoplePicker({
    super.key,
    required this.title,
    required this.people,
    this.loading = false,
  });

  final String title;
  final List<KoryPickable> people;
  final bool loading;

  @override
  State<KoryPeoplePicker> createState() => _KoryPeoplePickerState();
}

class _KoryPeoplePickerState extends State<KoryPeoplePicker> {
  final _query = TextEditingController();
  final Set<String> _chosen = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = koryFold(_query.text);
    final digits = _query.text.replaceAll(RegExp(r'\D'), '');
    final shown = [
      for (final p in widget.people)
        if (query.isEmpty ||
            koryFold(p.name).contains(query) ||
            (digits.length >= 3 &&
                (p.phone ?? '').replaceAll(RegExp(r'\D'), '').contains(digits)))
          p,
    ];
    final picked = [
      for (final p in widget.people)
        if (_chosen.contains(p.key)) p,
    ];
    return KoryPage(
      title: widget.title,
      loading: widget.loading,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryTPickConfirm('${picked.length}'),
            onPressed: picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(picked),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.koryTPickSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.koryHomeSearchClear,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.people.isEmpty
                          ? l.koryTPickEmpty
                          : l.koryTPickNoMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: shown.length,
                    itemBuilder: (_, index) {
                      final p = shown[index];
                      final selected = _chosen.contains(p.key);
                      return CheckboxListTile(
                        value: p.already || selected,
                        onChanged: p.already
                            ? null
                            : (v) => setState(
                                () => v == true
                                    ? _chosen.add(p.key)
                                    : _chosen.remove(p.key),
                              ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        activeColor: AppColors.accentPrimary,
                        secondary: KoryAvatar(p.name, muted: !p.onPokou),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          p.already
                              ? l.koryTPickAlready
                              : p.subtitle ??
                                    (p.onPokou
                                        ? l.koryTPickOnPokou
                                        : l.koryTPickBySms),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Le carnet de l'utilisateur : ses contacts Pokou, et les numéros qui ne
/// sont pas encore sur Pokou (ils recevront un SMS d'invitation).
///
/// Le carnet est REGARDÉ ici, pas lu au passage : lu sans être écouté, ce
/// fournisseur se libère aussitôt et rendait une liste vide — c'est pour
/// cela qu'« Ajouter depuis mes contacts » ne proposait personne.
class KoryContactsPicker extends ConsumerWidget {
  const KoryContactsPicker({
    super.key,
    this.alreadyUserIds = const {},
    this.alreadyPhones = const {},
  });

  final Set<int> alreadyUserIds;
  final Set<String> alreadyPhones;

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final contacts = ref.watch(contactsProvider);
    final phones = {for (final p in alreadyPhones) _digits(p)};
    final list = [...?contacts.valueOrNull]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    final people = [
      for (final PokouContact c in list)
        if (c.contactUserId != null)
          KoryPickable(
            name: c.displayName,
            userId: c.contactUserId,
            already: alreadyUserIds.contains(c.contactUserId),
          )
        else if (c.phone.isNotEmpty)
          KoryPickable(
            name: c.displayName.isEmpty ? c.phone : c.displayName,
            phone: c.phone,
            already: phones.contains(_digits(c.phone)),
          ),
    ];
    return KoryPeoplePicker(
      title: l.koryTPickContacts,
      people: people,
      loading: contacts.isLoading && !contacts.hasValue,
    );
  }
}
