import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'kory_controller.dart' show formatFcfa;
import 'kory_pot_screen.dart';

/// La marque des messages de groupe écrits par Kory (voir
/// backend/app/services/kory/activity.py).
const koryActivityKind = 'kory_activity';

bool isKoryActivity(Map<String, dynamic>? payload) =>
    payload != null && payload['kind'] == koryActivityKind;

/// La phrase d'un évènement Kory, dans la langue de l'appareil. Le serveur
/// n'envoie que des faits (qui, quoi, combien) : le texte se fait ici.
String koryActivityText(L l, Map<String, dynamic> payload) {
  String name(String key) {
    final value = (payload[key] as String?)?.trim();
    return value == null || value.isEmpty ? l.koryTActSomeone : value;
  }

  final title = payload['title'] as String? ?? '';
  final amount = payload['amount'] as int?;
  return switch (payload['event']) {
    'created' => switch (payload['pot_kind']) {
      'COTISATION' => l.koryTActCreatedCotisation(name('actor_name'), title),
      'TONTINE' => l.koryTActCreatedTontine(name('actor_name'), title),
      _ => l.koryTActCreatedCagnotte(name('actor_name'), title),
    },
    // Montants masqués : le serveur n'a pas mis le montant, on dit qui.
    'contribution' =>
      amount == null
          ? l.koryTActContribution(name('contributor_name'))
          : l.koryTActContributionAmount(
              name('contributor_name'),
              formatFcfa(amount),
            ),
    'started' => l.koryTActStarted(name('beneficiary_name')),
    'round' => l.koryTActRound(
      '${payload['round'] ?? ''}',
      '${payload['rounds'] ?? ''}',
      name('beneficiary_name'),
    ),
    'closed' => l.koryTActClosed(title),
    'dissolved' => l.koryTActDissolved(title),
    'reminder' => l.koryTActReminder(name('actor_name'), title),
    _ => title,
  };
}

/// Un évènement Kory dans le fil d'un groupe : une carte discrète au
/// centre — c'est la vie de la collecte, pas la parole de quelqu'un.
/// Toucher la carte ouvre la collecte.
class KoryActivityRow extends StatelessWidget {
  const KoryActivityRow({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final potId = payload['pot_id'] as int?;
    final total = payload['total'] as int?;
    final event = payload['event'];
    final icon = switch (event) {
      'contribution' => Icons.check_circle_outline,
      'round' || 'started' => Icons.autorenew,
      'closed' || 'dissolved' => Icons.lock_outline,
      'reminder' => Icons.notifications_none,
      _ => Icons.savings_outlined,
    };
    // Le rappel « wallet à wallet » là où il est question d'argent versé.
    final details = [
      if (total != null && (event == 'contribution' || event == 'closed'))
        l.koryTActTotal(formatFcfa(total)),
      if (event == 'contribution') l.koryTActNoMoney,
    ].join(' · ');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Material(
            color: AppColors.terracottaTint,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: potId == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KoryPotScreen(potId: potId),
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.onTerracottaTint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            koryActivityText(l, payload),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: AppColors.onTerracottaTint,
                            ),
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              details,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.onTerracottaTint.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (potId != null) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: l.koryTActOpen,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.onTerracottaTint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
