import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pokou_sync_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../data/group_invitation_model.dart';
import 'group_controller.dart';

/// Les invitations en attente, en tête de la liste des discussions.
///
/// ── Pourquoi ici, et pas dans un écran à part ─────────────────────────
///
/// Une invitation a 72 heures. Rangée derrière un onglet, elle serait vue
/// le quatrième jour — c'est-à-dire jamais. La liste des discussions est
/// l'écran qu'on ouvre sans y penser ; c'est là qu'une décision à prendre
/// doit se trouver.
///
/// Elle disparaît d'elle-même dès qu'il n'y a plus rien à décider : une
/// section permanente qui annonce zéro invitation occupe de la place pour
/// dire qu'il ne se passe rien.
final pendingInvitationsProvider =
    FutureProvider.autoDispose<List<GroupInvitation>>((ref) async {
      // Temps réel : le serveur pousse `group:invitation` à l'invité dès
      // qu'on l'ajoute. Sans cette écoute, la carte n'apparaissait qu'au
      // prochain rechargement de la liste — sur 72 heures de validité.
      // `listenDurableEventTypes` couvre aussi le rattrapage après une
      // coupure réseau.
      listenDurableEventTypes(ref, (type) {
        if (type == 'group:invitation' ||
            type == 'group:member:added' ||
            type == 'group:member:removed') {
          ref.invalidateSelf();
        }
      });
      try {
        return await ref.watch(groupRepositoryProvider).myInvitations();
      } catch (_) {
        // Hors ligne, ou serveur plus ancien que cette version : pas de
        // carte plutôt qu'un bandeau d'erreur en tête d'écran. Une
        // invitation manquée se rattrape ; un message d'erreur permanent au
        // premier coup d'œil, non.
        return const <GroupInvitation>[];
      }
    });

class GroupInvitationsSection extends ConsumerStatefulWidget {
  const GroupInvitationsSection({super.key});

  @override
  ConsumerState<GroupInvitationsSection> createState() =>
      _GroupInvitationsSectionState();
}

class _GroupInvitationsSectionState
    extends ConsumerState<GroupInvitationsSection> {
  /// Les invitations dont la décision est en cours d'envoi — pour désarmer
  /// LEURS boutons sans figer les autres cartes.
  final Set<String> _enCours = {};

  Future<void> _decider(
    GroupInvitation invitation, {
    required bool accepte,
  }) async {
    if (_enCours.contains(invitation.id)) return;
    setState(() => _enCours.add(invitation.id));
    final depot = ref.read(groupRepositoryProvider);
    try {
      if (accepte) {
        await depot.acceptInvitation(invitation.id);
        ref.invalidate(myGroupsProvider);
      } else {
        await depot.rejectInvitation(invitation.id);
      }
      ref.invalidate(pendingInvitationsProvider);
    } catch (_) {
      if (!mounted) return;
      // Le plus souvent : les 72 heures sont passées entre l'affichage et le
      // geste. On le dit, et on relit la liste plutôt que de laisser une
      // carte qui ne mène plus nulle part.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).groupInvitationFailed)),
      );
      ref.invalidate(pendingInvitationsProvider);
    } finally {
      if (mounted) setState(() => _enCours.remove(invitation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitations =
        ref.watch(pendingInvitationsProvider).valueOrNull ?? const [];
    // Le filtre côté appareil complète celui du serveur : entre le chargement
    // de la liste et le regard qu'on y porte, une invitation peut expirer.
    final vivantes = invitations.where((i) => !i.expiree).toList();
    if (vivantes.isEmpty) return const SizedBox.shrink();

    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            l.groupInvitationsHeader(vivantes.length),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final invitation in vivantes)
          _Carte(
            invitation: invitation,
            occupe: _enCours.contains(invitation.id),
            onAccepter: () => _decider(invitation, accepte: true),
            onRefuser: () => _decider(invitation, accepte: false),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.invitation,
    required this.occupe,
    required this.onAccepter,
    required this.onRefuser,
  });

  final GroupInvitation invitation;
  final bool occupe;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.accentPrimaryDark.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentPrimaryLight,
                child: Icon(Icons.groups, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (invitation.invitedByName != null)
                          l.groupInvitationFrom(invitation.invitedByName!),
                        l.groupInvitationMembers(invitation.memberCount),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _echeance(l),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: occupe ? null : onRefuser,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    l.groupInvitationReject,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: occupe ? null : onAccepter,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: occupe
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.groupInvitationAccept),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// « Expire dans 12 h », ou « Expire bientôt » sous l'heure.
  ///
  /// Pas de compte à rebours à la minute : il faudrait un minuteur qui
  /// redessine la liste des discussions toutes les soixante secondes, pour
  /// une information qui ne change pas de décision.
  String _echeance(L l) {
    final heures = invitation.restant.inHours;
    if (heures < 1) return l.groupInvitationExpiresSoon;
    return l.groupInvitationExpires(heures);
  }
}
