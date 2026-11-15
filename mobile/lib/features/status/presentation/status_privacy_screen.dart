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

/// Qui voit mes statuts (STA-4) : qui peut voir les miens, enregistré au geste.
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

  /// Enregistrement DIRECT, à chaque geste — pas de bouton « Enregistrer »
  /// (maquette Statuts 4). Un geste pendant un envoi en cours n'est pas
  /// perdu : on renvoie l'état le plus récent dès que le premier revient.
  bool _dirty = false;

  Future<void> _save() async {
    final audience = _audience;
    if (audience == null) return;
    if (_saving) {
      _dirty = true;
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      do {
        _dirty = false;
        await ref
            .read(statusRepositoryProvider)
            .setPrivacy(
              audience: _audience ?? audience,
              userIds: (_audience ?? audience).needsList
                  ? _selected.toList()
                  : const [],
            );
      } while (_dirty && mounted);
      // Le fil dépend de ce réglage pour ce que les autres voient.
      ref.invalidate(statusFeedProvider);
      ref.invalidate(statusPrivacyProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = L.of(context).statusPrivacySaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _choose(StatusAudience? value) {
    if (value == null || value == _audience) return;
    setState(() {
      // « Sauf » et « seulement avec » ne veulent pas dire la même chose
      // d'une même liste : on ne la transporte pas de l'un à l'autre.
      if (value.needsList && (_audience?.needsList ?? false)) {
        _selected = {};
      }
      _audience = value;
    });
    _save();
  }

  /// Le sous-titre de chaque option : la description, ou le compte de la
  /// liste pour l'option en cours (« 2 contacts exclus »).
  String _subtitleOf(L l, StatusAudience option) {
    if (option == _audience && option == StatusAudience.except) {
      return l.statusExcludedCount(_selected.length);
    }
    if (option == _audience && option == StatusAudience.only) {
      return l.statusAllowedCount(_selected.length);
    }
    return option == StatusAudience.contacts
        ? option.descriptionOf(l)
        : (option == StatusAudience.except
              ? l.statusExcludedCount(0)
              : option.descriptionOf(l));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final audience = _audience;
    if (audience == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.maybeWhen(
      data: (items) => items
          .where((c) => c.isRegistered && c.contactUserId != null)
          .toList(),
      orElse: () => const <PokouContact>[],
    );
    // « Personne » n'est plus proposé (maquette) ; un compte qui l'avait
    // choisi le garde et le voit, plutôt qu'aucun bouton coché.
    final options = [
      StatusAudience.contacts,
      StatusAudience.except,
      StatusAudience.only,
      if (audience == StatusAudience.nobody) StatusAudience.nobody,
    ];

    return SettingsScaffold(
      title: l.statusPrivacyTitle,
      children: [
        RadioGroup<StatusAudience>(
          groupValue: audience,
          onChanged: _choose,
          child: SettingsCard(
            children: [
              for (final option in options)
                InkWell(
                  onTap: () => _choose(option),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
                    child: Row(
                      children: [
                        Radio<StatusAudience>(
                          value: option,
                          activeColor: AppColors.accentPrimary,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.labelOf(l),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (option != StatusAudience.only ||
                                  option == audience)
                                Text(
                                  _subtitleOf(l, option),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_saving && option == audience)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (audience.needsList) ...[
          SettingsSectionTitle(
            audience == StatusAudience.except
                ? l.statusExcludePeople
                : l.statusAllowedPeople,
          ),
          if (contacts.isEmpty)
            SettingsFootnote(l.statusNoContactToOffer)
          else
            SettingsCard(
              children: [
                for (final contact in contacts)
                  _ContactCheck(
                    contact: contact,
                    checked: _selected.contains(contact.contactUserId),
                    onChanged: (checked) {
                      setState(() {
                        if (checked) {
                          _selected.add(contact.contactUserId!);
                        } else {
                          _selected.remove(contact.contactUserId);
                        }
                      });
                      _save();
                    },
                  ),
              ],
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
        const SizedBox(height: 12),
        // Les quatre règles d'un statut, dites avant qu'on publie.
        SettingsCard(
          children: [
            SettingsRow(icon: Icons.history, label: l.statusRule24h),
            SettingsRow(
              icon: Icons.visibility_outlined,
              label: l.statusRuleViewers,
              subtitle: l.statusRuleViewersSub,
            ),
            SettingsRow(
              icon: Icons.reply,
              label: l.statusRuleReply,
              subtitle: l.statusRuleReplySub,
            ),
            SettingsRow(icon: Icons.flag_outlined, label: l.statusRuleReport),
          ],
        ),
        const SizedBox(height: 12),
        SettingsNote(text: l.statusProofNote),
      ],
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
