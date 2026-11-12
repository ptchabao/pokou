import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'hype_train_controller.dart';
import 'hype_train_model.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';

/// La couleur du module — pastilles et barre d'avancement.
const _rocket = Color(0xFFDC2626);

const _contributionAmounts = [100, 500, 1000, 2000, 5000];

String _remaining(BuildContext context, int seconds) {
  if (seconds <= 0) return L.of(context).hypeFinished;
  final hours = seconds ~/ 3600;
  if (hours >= 1) return L.of(context).sparkHoursLeft(hours);
  return L.of(context).sparkMinutesLeft(seconds ~/ 60);
}

/// Hype Train — les objectifs en cours, et les miens.
class HypeTrainScreen extends ConsumerStatefulWidget {
  const HypeTrainScreen({super.key});

  @override
  ConsumerState<HypeTrainScreen> createState() => _HypeTrainScreenState();
}

class _HypeTrainScreenState extends ConsumerState<HypeTrainScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Hype Train',
      subtitle: L.of(context).hypeSubtitle,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentPrimaryDark,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(L.of(context).hypeLaunch),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          ModuleSegmented(
            labels: [L.of(context).hypeOngoing, L.of(context).hypeMine],
            index: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _tab == 0
                ? _TrainList(
                    provider: liveHypeTrainsProvider,
                    emptyTitle: L.of(context).hypeNoneTitle,
                    emptyMessage: L.of(context).hypeNoneBody,
                  )
                : _TrainList(
                    provider: myHypeTrainsProvider,
                    emptyTitle: L.of(context).hypeMineEmpty,
                    emptyMessage: L.of(context).hypeMineEmptyBody,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrainList extends ConsumerWidget {
  const _TrainList({
    required this.provider,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AutoDisposeFutureProvider<List<HypeTrain>> provider;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const SkeletonCards(),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).hypeUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (trains) {
        if (trains.isEmpty) {
          return ModuleEmptyState(
            icon: Icons.rocket_launch_outlined,
            title: emptyTitle,
            message: emptyMessage,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: trains.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _TrainCard(train: trains[index]),
          ),
        );
      },
    );
  }
}

class _TrainCard extends StatelessWidget {
  const _TrainCard({required this.train});

  final HypeTrain train;

  @override
  Widget build(BuildContext context) {
    final expired = !train.isLive && !train.isUnlocked;
    return ModuleCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HypeTrainDetailScreen(trainId: train.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: Icons.rocket_launch,
                color: _rocket,
                muted: expired,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      train.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      train.ownerName ??
                          (train.isOwner
                              ? L.of(context).navYou
                              : L.of(context).hypeCreator),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _TrainStateChip(train: train),
            ],
          ),
          const SizedBox(height: 14),
          ModuleProgressBar(
            value: train.progress,
            color: _rocket,
            done: train.isUnlocked,
          ),
          const SizedBox(height: 6),
          Text(
            '${train.collectedAmount} / ${train.goalAmount} FCFA',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrainStateChip extends StatelessWidget {
  const _TrainStateChip({required this.train});

  final HypeTrain train;

  @override
  Widget build(BuildContext context) {
    if (train.isUnlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          // Le vert du succès, le même que partout dans l'application.
          color: AppColors.accentPrimary.withValues(alpha: 0.14),
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          L.of(context).hypeTierReached,
          style: TextStyle(
            color: AppColors.accentPrimaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Text(
      _remaining(context, train.secondsLeft),
      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
    );
  }
}

/// Le détail d'un objectif : la promesse, la barre, et ceux qui la poussent.
class HypeTrainDetailScreen extends ConsumerWidget {
  const HypeTrainDetailScreen({super.key, required this.trainId});

  final int trainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hypeTrainDetailProvider(trainId));

    return ModuleScaffold(
      title: L.of(context).hypeGoal,
      child: async.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.search_off,
          title: L.of(context).hypeNotFound,
          message: L.of(context).hypeMaybeRemoved,
        ),
        data: (train) => ListView(
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
                        icon: Icons.rocket_launch,
                        color: _rocket,
                        size: 46,
                        muted: !train.isLive && !train.isUnlocked,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              train.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              train.ownerName ??
                                  (train.isOwner
                                      ? L.of(context).navYou
                                      : L.of(context).hypeCreator),
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
                  const SizedBox(height: 14),
                  Text(
                    // La promesse est visible AVANT de payer. L'inverse
                    // serait vendre à l'aveugle.
                    train.promise,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  ModuleProgressBar(
                    value: train.progress,
                    color: _rocket,
                    done: train.isUnlocked,
                    height: 12,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${train.collectedAmount} / ${train.goalAmount} FCFA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    train.isUnlocked
                        // Un palier atteint reste atteint : le dire ainsi
                        // évite la question « et si quelqu'un annule ? ».
                        ? L.of(context).hypeUnlocked
                        : _remaining(context, train.secondsLeft),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (train.isOwner && train.due != null) ...[
              const SizedBox(height: 12),
              _PayoutNotice(amount: train.due!),
            ],
            if (train.isLive && !train.isOwner) ...[
              const SizedBox(height: 16),
              ModuleActionButton(
                label: L.of(context).hypeContribute,
                icon: Icons.local_activity_outlined,
                onPressed: () => _showContributeSheet(context, ref, train),
              ),
            ],
            ModuleSectionTitle(L.of(context).hypePushers),
            if (train.contributors.isEmpty)
              Text(
                L.of(context).hypeBeFirst,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else
              ...train.contributors.map(
                (contributor) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ModuleCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                            Icons.person_outline,
                            size: 17,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            contributor.name ?? L.of(context).hypeContributor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: contributor.isMine
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${contributor.amount} F',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ce qui revient au créateur — « dû », jamais « versé ».
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
  final promiseController = TextEditingController();
  final goalController = TextEditingController(text: '10000');
  var hours = 24;
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSheetTitle(L.of(innerContext).hypeLaunch),
            const SizedBox(height: 14),
            ExplainerCard(
              steps: [
                (
                  icon: Icons.groups_outlined,
                  title: L.of(innerContext).hypeStepTogetherTitle,
                  body: L.of(innerContext).hypeStepTogetherBody,
                ),
                (
                  icon: Icons.lock_open_outlined,
                  title: L.of(innerContext).hypeStepPromiseTitle,
                  body: L.of(innerContext).hypeStepPromiseBody,
                ),
                (
                  icon: Icons.schedule,
                  title: L.of(innerContext).hypeStepOneTitle,
                  body: L.of(innerContext).hypeStepOneBody,
                ),
              ],
            ),
            FieldLabel(L.of(innerContext).commonTitle),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: titleController,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: L.of(innerContext).hypeTitleExample,
              ),
            ),
            FieldLabel(L.of(innerContext).hypePromiseLabel),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: promiseController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: L.of(innerContext).hypePromiseHint,
              ),
            ),
            FieldLabel(L.of(innerContext).hypeGoalAmount),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '10000'),
            ),
            FieldLabel(L.of(innerContext).commonDuration),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [6, 12, 24, 48].map((value) {
                final selected = hours == value;
                return ChoiceChip(
                  label: Text('${value}h'),
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
                  onSelected: (_) => setSheetState(() => hours = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            ModuleActionButton(
              label: L.of(innerContext).hypeLaunchAction,
              busy: busy,
              onPressed: () async {
                final goal = int.tryParse(goalController.text.trim());
                if (goal == null ||
                    titleController.text.trim().length < 3 ||
                    promiseController.text.trim().length < 10) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                    SnackBar(
                      content: Text(L.of(innerContext).hypeFieldsNeeded),
                    ),
                  );
                  return;
                }
                setSheetState(() => busy = true);
                try {
                  await ref
                      .read(hypeTrainRepositoryProvider)
                      .create(
                        title: titleController.text.trim(),
                        promise: promiseController.text.trim(),
                        goalAmount: goal,
                        hours: hours,
                      );
                  ref.invalidate(liveHypeTrainsProvider);
                  ref.invalidate(myHypeTrainsProvider);
                  if (innerContext.mounted) Navigator.of(innerContext).pop();
                } catch (_) {
                  setSheetState(() => busy = false);
                  if (innerContext.mounted) {
                    ScaffoldMessenger.of(innerContext).showSnackBar(
                      SnackBar(
                        content: Text(L.of(innerContext).hypeAlreadyRunning),
                      ),
                    );
                  }
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
  HypeTrain train,
) async {
  var amount = 500;
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(
            train.title,
            // Ce qui est acheté est un contenu, jamais de l'argent rendu. Le
            // dire ici évite la confusion avec une cagnotte.
            subtitle: L.of(innerContext).hypeContributeNote,
          ),
          FieldLabel(L.of(innerContext).commonAmount),
          ModuleAmountPicker(
            amounts: _contributionAmounts,
            selected: amount,
            onChanged: (value) => setSheetState(() => amount = value),
          ),
          const SizedBox(height: 18),
          ModuleActionButton(
            label: L.of(innerContext).hypeJoinForAmount(amount),
            busy: busy,
            onPressed: () async {
              setSheetState(() => busy = true);
              try {
                final url = await ref
                    .read(hypeTrainRepositoryProvider)
                    .contribute(train.id, amount);
                if (!innerContext.mounted) return;
                Navigator.of(innerContext).pop();
                if (!context.mounted) return;
                await openPaymentGateway(
                  context,
                  url,
                  pendingMessage: L.of(context).hypePaymentPending,
                );
                ref.invalidate(hypeTrainDetailProvider(train.id));
                ref.invalidate(liveHypeTrainsProvider);
              } catch (_) {
                setSheetState(() => busy = false);
              }
            },
          ),
        ],
      ),
    ),
  );
}
