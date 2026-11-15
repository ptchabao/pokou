import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../kory/presentation/kory_export.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_order_screen.dart';
import 'officine_shell.dart';
import 'officine_ui.dart';

/// Officine · 12. Historique : les commandes closes du mois, ses chiffres,
/// et l'export CSV pour la comptabilité (feuille de partage du système).
class OfficineHistoryTab extends ConsumerStatefulWidget {
  const OfficineHistoryTab({super.key, required this.me});

  final OfficineMe me;

  @override
  ConsumerState<OfficineHistoryTab> createState() => _OfficineHistoryTabState();
}

class _OfficineHistoryTabState extends ConsumerState<OfficineHistoryTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _filter = 0;
  bool _exporting = false;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  String _statusLabel(L l, OfficineOrder order) => switch (order.status) {
    'DELIVERED' => l.offiTagDelivered,
    'REJECTED' => l.offiTagRejected,
    'EXPIRED' => l.offiTagExpired,
    _ when order.refundDue > 0 => l.offiTagRefunded,
    _ => l.offiTagCancelled,
  };

  Future<void> _export(OfficineHistory history, String monthLabel) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      await koryShareCsv(
        title: '${widget.me.pharmacy.name} $monthLabel',
        header: [
          l.offiCsvDate,
          l.offiCsvOrder,
          l.offiCsvPatient,
          l.offiCsvStatus,
          l.offiCsvMedicines,
          l.offiCsvCourse,
          l.offiCsvTotal,
          l.offiCsvRefunded,
          l.offiCsvCourier,
        ],
        lines: [
          for (final order in history.items)
            KoryExportLine(
              order.deliveredAt ?? order.updatedAt ?? order.createdAt,
              '',
              columns: [
                '${order.id}',
                order.patientLabel,
                _statusLabel(l, order),
                '${order.medicinesTotal ?? 0}',
                '${order.deliveryPrice ?? 0}',
                '${order.status == 'DELIVERED' ? order.collected : 0}',
                '${order.refundDue}',
                order.courierName ?? '',
              ],
            ),
        ],
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = toBeginningOfSentenceCase(
      DateFormat.yMMMM(locale).format(_month),
    );
    final async = ref.watch(officineHistoryProvider(_month));
    final history = async.valueOrNull;
    final items = (history?.items ?? const <OfficineOrder>[])
        .where(
          (o) => switch (_filter) {
            1 => o.status == 'DELIVERED',
            2 => o.status != 'DELIVERED',
            _ => true,
          },
        )
        .toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(officineHistoryProvider(_month)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OfficineTabHeader(
            me: widget.me,
            title: l.offiHistoryTitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.offiPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: l.offiNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _Stat(
                  label: l.offiStatDelivered,
                  value: '${history?.delivered ?? '—'}',
                ),
                const SizedBox(width: 8),
                _Stat(
                  label: l.offiStatCollected,
                  value: history == null ? '—' : fcfa(history.collected),
                  caption: l.offiStatCollectedHint,
                ),
                const SizedBox(width: 8),
                _Stat(
                  label: l.offiStatCancelled,
                  value: '${history?.cancelled ?? '—'}',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: OfficineSegments(
              labels: [
                l.offiFilterAll,
                l.offiFilterDelivered,
                l.offiFilterCancelled,
              ],
              index: _filter,
              onChanged: (i) => setState(() => _filter = i),
            ),
          ),
          if (history == null && async.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history == null)
            ModuleEmptyState(
              icon: Icons.cloud_off,
              title: l.honamFailed,
              message: l.modulesCheckNetwork,
            )
          else if (items.isEmpty)
            ModuleEmptyState(
              icon: Icons.hourglass_empty,
              title: l.offiHistoryEmpty,
              message: l.offiHistoryEmptyBody,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ModuleCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, order) in items.indexed) ...[
                      if (i > 0) const HonamHairline(indent: 12),
                      _HistoryRow(order: order, status: _statusLabel(l, order)),
                    ],
                  ],
                ),
              ),
            ),
          if (history != null && history.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OfficineTextAction(
                  label: l.offiExportMonth,
                  icon: Icons.download_outlined,
                  onPressed: _exporting
                      ? null
                      : () => _export(history, monthLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Expanded(
    child: ModuleCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (caption != null)
            Text(
              caption!,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
        ],
      ),
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order, required this.status});

  final OfficineOrder order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final at = order.deliveredAt ?? order.updatedAt ?? order.createdAt;
    final delivered = order.status == 'DELIVERED';
    final detail = [
      officineDate(context, at),
      if (delivered)
        l.offiDeliveredAtShort(officineTime(context, at))
      else if (order.rejectionReason != null)
        order.rejectionReason!
      else if (order.missingReason != null)
        order.missingReason!,
      if (delivered && order.courierName != null) order.courierName!,
    ].join(' · ');
    return InkWell(
      onTap: () => openOfficineOrder(context, order.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officinePatient(context, order),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    detail,
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  order.total == null ? '—' : fcfa(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                OfficineTag(
                  status,
                  tone: delivered
                      ? OfficineTone.success
                      : order.refundDue > 0
                      ? OfficineTone.warning
                      : OfficineTone.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
