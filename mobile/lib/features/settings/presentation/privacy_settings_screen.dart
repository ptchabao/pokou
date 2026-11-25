import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../status/presentation/status_controller.dart';
import '../../status/presentation/status_privacy_screen.dart';
import '../data/privacy_repository.dart';
import '../../contacts/presentation/blocked_contacts_screen.dart';
import 'settings_widgets.dart';
import 'phone_visibility_screen.dart';
import 'storage_settings_screen.dart';
import '../../../core/widgets/pokou_sheet.dart';

/// Réglages › Confidentialité (REG-1) : qui peut voir, accusés de lecture,
/// groupes et inconnus, bloqués, puis le raccourci vers le stockage.
///
/// « Présence en ligne », « Informations du profil » et « Visibilité de mon
/// appartenance » ne sont plus à l'écran (maquette 2026-11) : le serveur
/// garde leurs règles, la première suit désormais « Vu à ».
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

  List<Widget> _contenu(L l, PrivacySettings r) {
    final statusAudience = ref.watch(statusPrivacyProvider).valueOrNull;
    final blocked = ref.watch(blockedContactsProvider).valueOrNull;
    final cache = ref.watch(_cacheSizeProvider).valueOrNull;
    return [
      SettingsSectionTitle(l.privacyWhoCanSee),
      SettingsCard(
        children: [
          // « Vu à » règle À LA FOIS la dernière activité et la présence en
          // ligne : la maquette n'en montre qu'une ligne, et les laisser
          // diverger sans moyen de les voir serait pire. Le serveur garde
          // les deux règles ; l'écran les écrit ensemble.
          _LigneAudience(
            label: l.privacySeenAt,
            description: l.privacyLastSeenBody,
            valeur: r.lastSeen,
            occupe: _enCours.contains('last_seen'),
            onChoix: (v) => _enregistrer(
              'last_seen',
              (depot) => depot.update(lastSeen: v, online: v),
            ),
          ),
          _LigneAudience(
            label: l.privacyProfilePhoto,
            description: l.privacyProfilePhotoBody,
            valeur: r.profilePhoto,
            occupe: _enCours.contains('profile_photo'),
            onChoix: (v) => _enregistrer(
              'profile_photo',
              (depot) => depot.update(profilePhoto: v),
            ),
          ),
          // « Mon numéro de téléphone » : visible par mes contacts, ou
          // masqué — sauf pour les personnes que j'autorise.
          SettingsRow(
            label: l.chatXPrivacyPhone,
            subtitle: l.chatXPrivacyPhoneSub,
            trailing: _enCours.contains('phone_number')
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SettingsValue(
                    r.phoneHidden
                        ? l.chatXPrivacyPhoneHidden
                        : l.chatXPrivacyPhoneContacts,
                  ),
            onTap: _enCours.contains('phone_number')
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PhoneVisibilityScreen(),
                    ),
                  ),
          ),
          SettingsRow(
            label: l.privacyStatuses,
            trailing: SettingsValue(
              statusAudience == null ? '' : statusAudience.audience.labelOf(l),
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatusPrivacyScreen()),
              );
              ref.invalidate(statusPrivacyProvider);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      SettingsCard(
        children: [
          SettingsRow(
            label: l.privacyReadReceiptsTitle,
            // La réciprocité est dite ICI, avant le geste.
            subtitle: l.privacyReadReceiptsSub,
            trailing: SettingsSwitch(
              value: r.readReceipts,
              semanticLabel: l.privacyReadReceiptsTitle,
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
      SettingsSectionTitle(l.privacyGroupsAndStrangers),
      SettingsCard(
        children: [
          _LigneAudience(
            label: l.privacyGroupAdd,
            subtitle: l.privacyGroupAddSub,
            description: l.privacyGroupInvitesBody,
            valeur: r.groupInvites,
            occupe: _enCours.contains('group_invites'),
            onChoix: (v) => _enregistrer(
              'group_invites',
              (depot) => depot.update(groupInvites: v),
            ),
          ),
          SettingsRow(
            label: l.privacySilenceUnknown,
            subtitle: l.privacySilenceUnknownSub,
            trailing: SettingsSwitch(
              value: r.silenceUnknownCalls,
              semanticLabel: l.privacySilenceUnknown,
              onChanged: _enCours.contains('silence_unknown_calls')
                  ? (_) {}
                  : (v) => _enregistrer(
                      'silence_unknown_calls',
                      (depot) => depot.update(silenceUnknownCalls: v),
                    ),
            ),
          ),
          SettingsRow(
            label: l.privacyBlocked,
            trailing: SettingsValue(blocked == null ? '' : '${blocked.length}'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BlockedContactsScreen(),
                ),
              );
              ref.invalidate(blockedContactsProvider);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      SettingsCard(
        children: [
          SettingsRow(
            label: l.storageTitle,
            trailing: SettingsValue(cache == null ? '' : formatBytes(cache)),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageSettingsScreen(),
                ),
              );
              ref.invalidate(_cacheSizeProvider);
            },
          ),
        ],
      ),
    ];
  }
}

/// La place que Pokou occupe sur ce téléphone, pour la ligne « Stockage et
/// données ».
final _cacheSizeProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      (await ref.watch(mediaRepositoryProvider).cacheStats()).totalBytes,
);

/// Une ligne qui ouvre le choix des trois audiences.
///
/// La valeur courante s'affiche à droite, comme dans tous les écrans de
/// réglages mobiles : on doit pouvoir lire l'état de ses six règles en
/// balayant la page, sans en ouvrir une seule.
class _LigneAudience extends StatelessWidget {
  const _LigneAudience({
    required this.label,
    this.subtitle,
    required this.description,
    required this.valeur,
    required this.onChoix,
    required this.occupe,
  });

  final String label;

  /// Sous le libellé, quand la maquette en montre un.
  final String? subtitle;
  final String description;
  final PrivacyAudience valeur;
  final ValueChanged<PrivacyAudience> onChoix;
  final bool occupe;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SettingsRow(
      label: label,
      subtitle: subtitle,
      trailing: occupe
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SettingsValue(libelleAudience(l, valeur)),
      onTap: occupe ? null : () => _choisir(context, l),
    );
  }

  Future<void> _choisir(BuildContext context, L l) async {
    final choix = await showPokouSheet<PrivacyAudience>(
      scrollable: true,
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
