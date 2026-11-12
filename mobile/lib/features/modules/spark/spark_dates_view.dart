import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_model.dart';
import 'spark_safety_view.dart';
import '../../../core/widgets/skeleton.dart';

/// Mes sorties — celles à venir, et ce qu'elles sont devenues.
class SparkDatesView extends ConsumerWidget {
  const SparkDatesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(sparkDatesProvider);

    return datesAsync.when(
      loading: () => const SkeletonCards(),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).datesUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (dates) {
        if (dates.isEmpty) {
          return ModuleEmptyState(
            icon: Icons.restaurant_outlined,
            title: L.of(context).datesNone,
            message: L.of(context).datesNoneBody,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sparkDatesProvider);
            await ref.read(sparkDatesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const SparkCheckinBanner(),
              for (final date in dates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DateCard(date: date),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DateCard extends ConsumerStatefulWidget {
  const _DateCard({required this.date});

  final SparkDate date;

  @override
  ConsumerState<_DateCard> createState() => _DateCardState();
}

class _DateCardState extends ConsumerState<_DateCard> {
  bool _busy = false;

  Future<void> _run(Future<SparkDate> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(sparkDatesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).datesNotNow)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final date = widget.date;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(dialogContext).datesCancelTitle),
        content: Text(
          date.canCancelFree
              ? L.of(dialogContext).datesCancelFree
              // Dit AVANT, pas découvert après : c'est la seule mauvaise
              // surprise que ce module pourrait réserver.
              : L.of(dialogContext).datesCancelLate,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(dialogContext).datesKeep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(dialogContext).datesCancelAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref.read(sparkRepositoryProvider).cancelDate(date.id));
    }
  }

  ({String label, Color color}) get _state {
    return switch (widget.date.status) {
      'PENDING' => (
        label: L.of(context).datesAwaitingPayment,
        color: AppColors.textMuted,
      ),
      'HELD' => (
        label: L.of(context).datesPaidToConfirm,
        color: AppColors.accentPrimaryLight,
      ),
      'RELEASED' => (
        label: L.of(context).datesDone,
        color: AppColors.accentPrimaryLight,
      ),
      'REFUNDED' => (
        label: L.of(context).datesRefunded,
        color: AppColors.textSecondary,
      ),
      'PENALIZED' => (
        label: L.of(context).datesNoShow,
        color: const Color(0xFFE11D48),
      ),
      _ => (label: L.of(context).datesCancelled, color: AppColors.textMuted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final state = _state;
    final when = date.scheduledAt.toLocal();

    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: Icons.restaurant,
                color: AppColors.accentPrimaryDark,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.pack?.title ?? L.of(context).datesOne,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      L
                          .of(context)
                          .datesWithPeer(
                            date.pack?.venueName ?? '',
                            date.peerName ?? L.of(context).datesYourMatch,
                          ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: state.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  state.label,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                L
                    .of(context)
                    .dateAtTime(
                      '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}',
                      '${when.hour.toString().padLeft(2, '0')}h${when.minute.toString().padLeft(2, '0')}',
                    ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${date.amount} FCFA',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (date.voucherCode != null) ...[
            const SizedBox(height: 12),
            _VoucherBox(code: date.voucherCode!),
          ],
          if (date.settlement?.penaltyToMe == true) ...[
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.account_balance_wallet_outlined,
              title: L
                  .of(context)
                  .commonDueToYou(date.settlement!.penaltyAmount ?? 0),
              body: L.of(context).commonManualPayout,
            ),
          ],
          if (date.isHeld) ...[
            const SizedBox(height: 14),
            if (date.canValidate && !date.iValidated)
              ModuleActionButton(
                label: L.of(context).datesWentWell,
                icon: Icons.check_circle_outline,
                busy: _busy,
                onPressed: () => _run(
                  () => ref.read(sparkRepositoryProvider).validateDate(date.id),
                ),
              )
            else if (date.iValidated)
              Text(
                // L'argent ne bouge qu'une fois les DEUX d'accord : le dire
                // évite la question « j'ai validé, où est passé mon argent ? ».
                L.of(context).datesYouConfirmed,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ModuleQuietButton(
                    label: L.of(context).actionCancel,
                    onPressed: _busy ? null : _confirmCancel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ModuleQuietButton(
                    label: L.of(context).datesNoShowAction,
                    // Le serveur revérifie : on ne peut signaler QUE
                    // l'autre, et c'est lui qui en déduit le rôle.
                    onPressed: _busy || date.peerId == 0
                        ? null
                        : () => _run(
                            () => ref
                                .read(sparkRepositoryProvider)
                                .reportNoShow(date.id, date.peerId),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherBox extends StatelessWidget {
  const _VoucherBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.of(context).datesVoucher,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accentPrimaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
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

/// Proposer une sortie : choisir une formule, puis une date.
Future<void> showBookDateSheet(
  BuildContext context, {
  required int matchId,
}) async {
  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => _BookDateSheet(matchId: matchId),
  );
}

class _BookDateSheet extends ConsumerStatefulWidget {
  const _BookDateSheet({required this.matchId});

  final int matchId;

  @override
  ConsumerState<_BookDateSheet> createState() => _BookDateSheetState();
}

class _BookDateSheetState extends ConsumerState<_BookDateSheet> {
  SparkPack? _pack;
  DateTime? _when;
  bool _busy = false;

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    });
  }

  Future<void> _book() async {
    final pack = _pack;
    final when = _when;
    if (pack == null || when == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).datesPickBoth)));
      return;
    }
    setState(() => _busy = true);
    try {
      final booking = await ref
          .read(sparkRepositoryProvider)
          .bookDate(
            matchId: widget.matchId,
            packId: pack.id,
            scheduledAt: when,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      await openPaymentGateway(
        context,
        booking.paymentUrl,
        pendingMessage: L.of(context).datesVoucherPending,
      );
      ref.invalidate(sparkDatesProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).datesBookingFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(sparkPacksProvider);
    final when = _when;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(L.of(context).datesWhereTo),
          const SizedBox(height: 14),
          ExplainerCard(
            steps: [
              (
                icon: Icons.lock_clock,
                title: L.of(context).datesStepPayTitle,
                body: L.of(context).datesStepPayBody,
              ),
              (
                icon: Icons.event_available_outlined,
                title: L.of(context).datesStepCancelTitle,
                body: L.of(context).datesStepCancelBody,
              ),
              (
                icon: Icons.person_off_outlined,
                title: L.of(context).datesStepNoShowTitle,
                body: L.of(context).datesStepNoShowBody,
              ),
            ],
          ),
          FieldLabel(L.of(context).datesThePackage),
          packsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              L.of(context).datesPacksUnavailable,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            data: (packs) {
              if (packs.isEmpty) {
                return Text(
                  L.of(context).datesNoPackNearby,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                children: [
                  for (final pack in packs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ModuleCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        onTap: () => setState(() => _pack = pack),
                        child: Row(
                          children: [
                            Icon(
                              _pack?.id == pack.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: _pack?.id == pack.id
                                  ? AppColors.accentPrimaryDark
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pack.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    pack.venueName,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${pack.price} F',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          FieldLabel(L.of(context).datesWhen),
          ModuleCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: _pickWhen,
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Text(
                  when == null
                      ? L.of(context).datesPickWhen
                      : L
                            .of(context)
                            .dateAtTime(
                              '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}',
                              '${when.hour.toString().padLeft(2, '0')}h${when.minute.toString().padLeft(2, '0')}',
                            ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: when == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ModuleActionButton(
            label: _pack == null
                ? L.of(context).datesBook
                : L.of(context).datesBookAmount(_pack!.price),
            busy: _busy,
            onPressed: _book,
          ),
        ],
      ),
    );
  }
}
