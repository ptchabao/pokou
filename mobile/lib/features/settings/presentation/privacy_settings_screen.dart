import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/privacy_repository.dart';
import 'settings_widgets.dart';

/// Profil → Confidentialité.
///
/// ── Ce que cet écran n'est pas ────────────────────────────────────────
///
/// Ce ne sont pas des préférences d'affichage. Chaque ligne est une règle
/// que le SERVEUR applique : une photo réservée à ses contacts n'est pas
/// « cachée dans l'application », elle n'est pas envoyée. Un champ masqué
/// côté client se retrouve tôt ou tard dans un cache, une capture de
/// requête, ou un écran qui a oublié la règle.
///
/// ── Pourquoi « En ligne » et « Dernière activité » sont séparés ───────
///
/// Elles ne disent pas la même chose. « En ligne maintenant » sert à savoir
/// si on peut appeler ; « vu à 23 h 14 » raconte une journée. Beaucoup de
/// gens veulent la première et pas la seconde, et les fondre aurait obligé à
/// renoncer aux deux pour en cacher une.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  /// Ce qui est en cours d'enregistrement, pour désarmer la ligne concernée
  /// sans figer tout l'écran — on peut régler la ligne d'à côté pendant ce
  /// temps.
  final Set<String> _enCours = {};

  Future<void> _enregistrer(
    String cle,
    Future<PrivacySettings> Function(PrivacyRepository) action,
  ) async {
    if (_enCours.contains(cle)) return;
    setState(() => _enCours.add(cle));
    try {
      await action(ref.read(privacyRepositoryProvider));
      ref.invalidate(privacySettingsProvider);
    } catch (_) {
      if (mounted) {
        // Le réglage n'a PAS été pris : le dire, et relire l'état réel
        // plutôt que de laisser l'écran afficher un choix que le serveur
        // ignore. Une règle de confidentialité qu'on croit posée et qui ne
        // l'est pas est pire que pas de réglage du tout.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).privacySaveFailed)),
        );
        ref.invalidate(privacySettingsProvider);
      }
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final etat = ref.watch(privacySettingsProvider);

    return SettingsScaffold(
      title: l.privacyTitle,
      onRefresh: () async {
        ref.invalidate(privacySettingsProvider);
        await ref.read(privacySettingsProvider.future);
      },
      children: etat.when(
        loading: () => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (_, _) => [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            child: Center(
              child: Text(
                l.privacyUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
        data: (reglages) => _contenu(l, reglages),
      ),
    );
  }

  List<Widget> _contenu(L l, PrivacySettings r) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Text(
        l.privacyIntro,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    ),

    SettingsSectionTitle(l.privacySectionWhoSees),
    SettingsCard(
      children: [
        _LigneAudience(
          icone: Icons.schedule,
          label: l.privacyLastSeen,
          description: l.privacyLastSeenBody,
          valeur: r.lastSeen,
          occupe: _enCours.contains('last_seen'),
          onChoix: (v) =>
              _enregistrer('last_seen', (depot) => depot.update(lastSeen: v)),
        ),
        _LigneAudience(
          icone: Icons.circle,
          label: l.privacyOnline,
          description: l.privacyOnlineBody,
          valeur: r.online,
          occupe: _enCours.contains('online'),
          onChoix: (v) =>
              _enregistrer('online', (depot) => depot.update(online: v)),
        ),
        _LigneAudience(
          icone: Icons.account_circle_outlined,
          label: l.privacyProfilePhoto,
          description: l.privacyProfilePhotoBody,
          valeur: r.profilePhoto,
          occupe: _enCours.contains('profile_photo'),
          onChoix: (v) => _enregistrer(
            'profile_photo',
            (depot) => depot.update(profilePhoto: v),
          ),
        ),
        _LigneAudience(
          icone: Icons.info_outline,
          label: l.privacyProfileInfo,
          description: l.privacyProfileInfoBody,
          valeur: r.profileInfo,
          occupe: _enCours.contains('profile_info'),
          onChoix: (v) => _enregistrer(
            'profile_info',
            (depot) => depot.update(profileInfo: v),
          ),
        ),
      ],
    ),

    SettingsSectionTitle(l.privacySectionMessages),
    SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.done_all,
          label: l.privacyReadReceipts,
          // La réciprocité est dite ICI, avant le geste. La découvrir après
          // coup — « je ne vois plus les accusés des autres, pourquoi ? » —
          // donnerait l'impression d'un défaut.
          subtitle: l.privacyReadReceiptsBody,
          trailing: SettingsSwitch(
            value: r.readReceipts,
            semanticLabel: l.privacyReadReceipts,
            onChanged: _enCours.contains('read_receipts')
                ? (_) {}
                : (v) => _enregistrer(
                    'read_receipts',
                    (depot) => depot.update(readReceipts: v),
                  ),
          ),
        ),
      ],
    ),

    SettingsSectionTitle(l.privacySectionGroups),
    SettingsCard(
      children: [
        _LigneAudience(
          icone: Icons.group_add_outlined,
          label: l.privacyGroupInvites,
          description: l.privacyGroupInvitesBody,
          valeur: r.groupInvites,
          occupe: _enCours.contains('group_invites'),
          onChoix: (v) => _enregistrer(
            'group_invites',
            (depot) => depot.update(groupInvites: v),
          ),
        ),
        _LigneAudience(
          icone: Icons.groups_outlined,
          label: l.privacyGroupMembership,
          description: l.privacyGroupMembershipBody,
          valeur: r.groupMembership,
          occupe: _enCours.contains('group_membership'),
          onChoix: (v) => _enregistrer(
            'group_membership',
            (depot) => depot.update(groupMembership: v),
          ),
        ),
      ],
    ),

    Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        l.privacyStatusesNote,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
      ),
    ),
  ];
}

/// Une ligne qui ouvre le choix des trois audiences.
///
/// La valeur courante s'affiche à droite, comme dans tous les écrans de
/// réglages mobiles : on doit pouvoir lire l'état de ses six règles en
/// balayant la page, sans en ouvrir une seule.
class _LigneAudience extends StatelessWidget {
  const _LigneAudience({
    required this.icone,
    required this.label,
    required this.description,
    required this.valeur,
    required this.onChoix,
    required this.occupe,
  });

  final IconData icone;
  final String label;
  final String description;
  final PrivacyAudience valeur;
  final ValueChanged<PrivacyAudience> onChoix;
  final bool occupe;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SettingsRow(
      icon: icone,
      label: label,
      subtitle: description,
      trailing: occupe
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  libelleAudience(l, valeur),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
              ],
            ),
      onTap: occupe ? null : () => _choisir(context, l),
    );
  }

  Future<void> _choisir(BuildContext context, L l) async {
    final choix = await showModalBottomSheet<PrivacyAudience>(
      context: context,
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            for (final option in PrivacyAudience.values)
              RadioListTile<PrivacyAudience>(
                value: option,
                groupValue: valeur,
                title: Text(libelleAudience(l, option)),
                onChanged: (v) => Navigator.pop(feuille, v),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix != null && choix != valeur) onChoix(choix);
  }
}

String libelleAudience(L l, PrivacyAudience a) => switch (a) {
  PrivacyAudience.everyone => l.privacyEveryone,
  PrivacyAudience.contacts => l.privacyMyContacts,
  PrivacyAudience.nobody => l.privacyNobody,
};
