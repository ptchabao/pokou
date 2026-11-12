import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'social_tax_controller.dart';
import 'social_tax_model.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';

/// La couleur du module — pastilles et barre d'avancement.
final _fundColor = AppColors.accentPrimaryDark;

/// Les quatre occasions, traduites.
///
/// Une fonction et non une constante : un libellé traduit dépend de la
/// langue courante, et la carte `const` précédente était figée en français à
/// la compilation.
Map<String, String> _kindLabelsOf(BuildContext context) {
  final l = L.of(context);
  return {
    'MARIAGE': l.ceremonyWedding,
    'BAPTEME': l.ceremonyBaptism,
    'DEUIL': l.ceremonyFuneral,
    'AUTRE': l.ceremonyOther,
  };
}

IconData _kindIcon(String kind) => switch (kind) {
  'MARIAGE' => Icons.favorite_outline,
  'BAPTEME' => Icons.child_care_outlined,
  'DEUIL' => Icons.spa_outlined,
  _ => Icons.groups_outlined,
};

/// Les montants d'une somme qui se donne, pas d'un prix affiché.
const _contributionAmounts = [500, 1000, 2000, 5000, 10000];

/// Social Tax — mes cagnottes de cérémonie.
class SocialTaxScreen extends ConsumerWidget {
  const SocialTaxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ceremonyFundsProvider);

    return ModuleScaffold(
      title: L.of(context).ceremonyTitle,
      subtitle: L.of(context).ceremonySubtitle,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentPrimaryDark,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(L.of(context).ceremonyNew),
      ),
      child: async.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: L.of(context).ceremonyUnavailable,
          message: L.of(context).modulesCheckNetwork,
        ),
        data: (funds) {
          if (funds.isEmpty) {
            return ModuleEmptyState(
              icon: Icons.groups_outlined,
              title: L.of(context).ceremonyNone,
              message: L.of(context).ceremonyNoneBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ceremonyFundsProvider);
              await ref.read(ceremonyFundsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: funds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _FundCard(fund: funds[index]),
            ),
          );
        },
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  const _FundCard({required this.fund});

  final CeremonyFund fund;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CeremonyFundScreen(fundId: fund.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: _kindIcon(fund.kind),
                color: _fundColor,
                muted: fund.isClosed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_kindLabelsOf(context)[fund.kind] ?? L.of(context).ceremonyOne} • '
                      '${fund.isOrganizer ? L.of(context).ceremonyYouOrganize : fund.organizerName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (fund.isClosed)
                Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${fund.collectedAmount} FCFA',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            L.of(context).ceremonyCollected,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          if (fund.goalAmount != null) ...[
            const SizedBox(height: 10),
            ModuleProgressBar(
              value: fund.progress,
              color: _fundColor,
              done: fund.collectedAmount >= (fund.goalAmount ?? 0),
              height: 6,
            ),
            const SizedBox(height: 5),
            Text(
              // « Objectif », jamais « plafond » : la cagnotte continue
              // d'accepter au-delà.
              L.of(context).ceremonyGoalHint(fund.goalAmount ?? 0),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le détail d'une cagnotte : le mur des contributeurs, et le bouton donner.
class CeremonyFundScreen extends ConsumerWidget {
  const CeremonyFundScreen({super.key, required this.fundId});

  final int fundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ceremonyFundProvider(fundId));

    // Pas de bouton « partager » ici, volontairement : Pokou n'a pas encore
    // de lien profond vers une cagnotte, et un partage qui ouvre seulement
    // la fiche du Play Store laisserait le destinataire sans moyen de
    // retrouver CETTE cagnotte. À rétablir le jour où `/cagnotte/{id}`
    // existe dans le manifeste Android.
    return ModuleScaffold(
      title: L.of(context).ceremonyOne,
      child: async.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.search_off,
          title: L.of(context).ceremonyNotFound,
          message: L.of(context).ceremonyMaybeClosed,
        ),
        data: (fund) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            ModuleCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ModuleBadge(
                        icon: _kindIcon(fund.kind),
                        color: _fundColor,
                        size: 46,
                        muted: fund.isClosed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fund.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _kindLabelsOf(context)[fund.kind] ??
                                  L.of(context).ceremonyOne,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (fund.description != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      fund.description!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '${fund.collectedAmount} FCFA',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${fund.contributorCount} participation'
                    '${fund.contributorCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (fund.goalAmount != null) ...[
                    const SizedBox(height: 12),
                    ModuleProgressBar(
                      value: fund.progress,
                      color: _fundColor,
                      done: fund.collectedAmount >= (fund.goalAmount ?? 0),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      L.of(context).ceremonyGoalHint(fund.goalAmount ?? 0),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fund.isOrganizer && fund.dueToOrganizer != null) ...[
              const SizedBox(height: 12),
              _PayoutNotice(amount: fund.dueToOrganizer!),
            ],
            const SizedBox(height: 18),
            if (!fund.isClosed)
              ModuleActionButton(
                label: L.of(context).ceremonyJoin,
                icon: Icons.volunteer_activism_outlined,
                onPressed: () => _showContributeSheet(context, ref, fund),
              ),
            if (fund.isOrganizer && !fund.isClosed) ...[
              const SizedBox(height: 10),
              ModuleQuietButton(
                label: L.of(context).ceremonyClose,
                onPressed: () async {
                  await ref.read(socialTaxRepositoryProvider).close(fund.id);
                  ref.invalidate(ceremonyFundProvider(fund.id));
                  ref.invalidate(ceremonyFundsProvider);
                },
              ),
            ],
            ModuleSectionTitle(L.of(context).ceremonyContributions),
            if (fund.contributors.isEmpty)
              Text(
                L.of(context).ceremonyNobodyYet,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else
              ...fund.contributors.map(
                (contribution) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ContributionTile(contribution: contribution),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({required this.contribution});

  final Contribution contribution;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              contribution.isAnonymous
                  ? Icons.visibility_off_outlined
                  : Icons.person_outline,
              size: 17,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.isAnonymous
                      ? L.of(context).ceremonyAnonGift
                      : contribution.name ?? L.of(context).ceremonyContributor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: contribution.isMine
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
                if (contribution.message != null)
                  Text(
                    contribution.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${contribution.amount} F',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Ce qui revient à l'organisateur, et comment il l'obtient.
///
/// Dit d'emblée : découvrir au moment de récupérer l'argent que le virement
/// n'est pas automatique est la meilleure façon de perdre quelqu'un.
class _PayoutNotice extends StatelessWidget {
  const _PayoutNotice({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).commonDueToYou(amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L.of(context).commonManualPayout,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final goalController = TextEditingController();
  var kind = 'MARIAGE';
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSheetTitle(
              L.of(innerContext).ceremonyNew,
              subtitle: L.of(innerContext).ceremonyNewSubtitle,
            ),
            FieldLabel(L.of(innerContext).ceremonyOccasion),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kindLabelsOf(innerContext).entries.map((entry) {
                final selected = kind == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: AppColors.surfaceElevated,
                  selectedColor: AppColors.accentPrimaryLight,
                  side: BorderSide(
                    color: selected
                        ? AppColors.accentPrimaryDark
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setSheetState(() => kind = entry.key),
                );
              }).toList(),
            ),
            FieldLabel(L.of(innerContext).commonTitle),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: titleController,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: L.of(innerContext).ceremonyTitleExample,
              ),
            ),
            FieldLabel(L.of(innerContext).ceremonyFewWords),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: descriptionController,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: L.of(innerContext).ceremonyFewWordsHint,
              ),
            ),
            FieldLabel(L.of(innerContext).ceremonyGoalOptional),
            Text(
              L.of(innerContext).ceremonyGoalNote,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '100000'),
            ),
            const SizedBox(height: 18),
            ModuleActionButton(
              label: L.of(innerContext).ceremonyCreate,
              busy: busy,
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.length < 3) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                    SnackBar(
                      content: Text(L.of(innerContext).ceremonyNeedTitle),
                    ),
                  );
                  return;
                }
                setSheetState(() => busy = true);
                try {
                  await ref
                      .read(socialTaxRepositoryProvider)
                      .create(
                        title: title,
                        kind: kind,
                        description: descriptionController.text.trim(),
                        goalAmount: int.tryParse(goalController.text.trim()),
                      );
                  ref.invalidate(ceremonyFundsProvider);
                  if (innerContext.mounted) Navigator.of(innerContext).pop();
                } catch (_) {
                  setSheetState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showContributeSheet(
  BuildContext context,
  WidgetRef ref,
  CeremonyFund fund,
) async {
  final messageController = TextEditingController();
  final customController = TextEditingController();
  var amount = 1000;
  var anonymous = false;
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSheetTitle(L.of(innerContext).ceremonyJoinTo(fund.title)),
            FieldLabel(L.of(innerContext).commonAmount),
            ModuleAmountPicker(
              amounts: _contributionAmounts,
              selected: amount,
              onChanged: (value) => setSheetState(() {
                amount = value;
                customController.clear();
              }),
            ),
            const SizedBox(height: 10),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: customController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: L.of(innerContext).ceremonyOtherAmount,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) setSheetState(() => amount = parsed);
              },
            ),
            FieldLabel(L.of(innerContext).ceremonyWordOptional),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: messageController,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: L.of(innerContext).ceremonyWordHint,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accentPrimary,
              value: anonymous,
              onChanged: (value) => setSheetState(() => anonymous = value),
              title: Text(
                L.of(innerContext).ceremonyAnonToggle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                // Le montant reste visible : sinon le total ne prouve plus
                // rien à l'organisateur.
                L.of(innerContext).ceremonyAnonNote,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ModuleActionButton(
              label: L.of(innerContext).ceremonyJoinAmount(amount),
              busy: busy,
              onPressed: () async {
                if (amount < 100) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                    SnackBar(content: Text(L.of(innerContext).ceremonyMinimum)),
                  );
                  return;
                }
                setSheetState(() => busy = true);
                try {
                  final url = await ref
                      .read(socialTaxRepositoryProvider)
                      .contribute(
                        fund.id,
                        amount: amount,
                        message: messageController.text.trim(),
                        isAnonymous: anonymous,
                      );
                  if (!innerContext.mounted) return;
                  Navigator.of(innerContext).pop();
                  if (!context.mounted) return;
                  await openPaymentGateway(
                    context,
                    url,
                    pendingMessage: L.of(context).ceremonyPaymentPending,
                  );
                  ref.invalidate(ceremonyFundProvider(fund.id));
                  ref.invalidate(ceremonyFundsProvider);
                } catch (_) {
                  setSheetState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
