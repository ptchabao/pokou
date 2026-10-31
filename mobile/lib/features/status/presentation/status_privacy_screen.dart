import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../data/status_model.dart';
import 'status_controller.dart';

/// Profil > Statuts : qui peut voir les miens.
///
/// L'audience est décidée par l'auteur — ajouter quelqu'un à son carnet ne
/// donne pas accès à ses statuts (voir status_privacy_service.py côté API).
class StatusPrivacyScreen extends ConsumerStatefulWidget {
  const StatusPrivacyScreen({super.key});

  @override
  ConsumerState<StatusPrivacyScreen> createState() =>
      _StatusPrivacyScreenState();
}

class _StatusPrivacyScreenState extends ConsumerState<StatusPrivacyScreen> {
  StatusAudience? _audience;
  Set<int> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final privacy = await ref.read(statusRepositoryProvider).getPrivacy();
      if (mounted) {
        setState(() {
          _audience = privacy.audience;
          _selected = privacy.userIds.toSet();
        });
      }
    } catch (_) {
      // Faute de réglage lisible, on n'invente rien : on affiche le défaut
      // du serveur et l'utilisateur peut le confirmer.
      if (mounted) setState(() => _audience = StatusAudience.contacts);
    }
  }

  Future<void> _save() async {
    final audience = _audience;
    if (audience == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(statusRepositoryProvider)
          .setPrivacy(audience: audience, userIds: _selected.toList());
      // Le fil dépend de ce réglage pour les statuts des autres… et le mien
      // pour ce qu'ils voient : on le refait charger.
      ref.invalidate(statusFeedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).statusPrivacySaved)),
        );
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = L.of(context).statusPrivacySaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audience = _audience;
    if (audience == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.maybeWhen(
      data: (items) => items
          .where((c) => c.isRegistered && c.contactUserId != null)
          .toList(),
      orElse: () => const <PokouContact>[],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          L.of(context).statusPrivacyTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textMuted,
                    ),
                  )
                : Text(
                    L.of(context).actionSave,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            // RadioGroup et non `groupValue` par bouton : Flutter a déprécié
            // la seconde forme après la 3.32.
            RadioGroup<StatusAudience>(
              groupValue: audience,
              onChanged: (value) => setState(() => _audience = value),
              child: SettingsCard(
                children: [
                  for (final option in StatusAudience.values)
                    SettingsRow(
                      label: option.labelOf(L.of(context)),
                      subtitle: option.descriptionOf(L.of(context)),
                      trailing: Radio<StatusAudience>(
                        value: option,
                        activeColor: AppColors.accentPrimary,
                      ),
                      onTap: () => setState(() => _audience = option),
                    ),
                ],
              ),
            ),
            if (audience.needsList) ...[
              SettingsSectionTitle(
                audience == StatusAudience.except
                    ? L.of(context).statusExcludePeople
                    : L.of(context).statusAllowedPeople,
              ),
              if (contacts.isEmpty)
                SettingsFootnote(L.of(context).statusNoContactToOffer)
              else
                SettingsCard(
                  children: [
                    for (final contact in contacts)
                      _ContactCheck(
                        contact: contact,
                        checked: _selected.contains(contact.contactUserId),
                        onChanged: (checked) => setState(() {
                          if (checked) {
                            _selected.add(contact.contactUserId!);
                          } else {
                            _selected.remove(contact.contactUserId);
                          }
                        }),
                      ),
                  ],
                ),
              SettingsFootnote(
                audience == StatusAudience.except
                    ? L.of(context).statusExceptFootnote
                    : L.of(context).statusOnlyFootnote,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.semanticError,
                    fontSize: 12,
                  ),
                ),
              ),
            SettingsFootnote(L.of(context).status24hFootnote),
          ],
        ),
      ),
    );
  }
}

class _ContactCheck extends StatelessWidget {
  const _ContactCheck({
    required this.contact,
    required this.checked,
    required this.onChanged,
  });

  final PokouContact contact;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ContactAvatar(
              avatar: contact.avatar,
              displayName: contact.displayName,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                contact.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            Checkbox(
              value: checked,
              activeColor: AppColors.accentPrimary,
              onChanged: (value) => onChanged(value ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
