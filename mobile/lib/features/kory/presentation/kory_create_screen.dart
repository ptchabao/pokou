import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import 'kory_controller.dart';
import 'kory_pot_screen.dart';

/// Ouvre la création, puis la cagnotte créée. `groupId` la rattache au
/// groupe d'où l'on vient (NAV-03).
Future<void> openKoryCreate(
  BuildContext context,
  WidgetRef ref, {
  int? groupId,
}) async {
  final potId = await Navigator.of(context).push<int>(
    MaterialPageRoute(builder: (_) => KoryCreateScreen(groupId: groupId)),
  );
  if (potId == null || !context.mounted) return;
  refreshKory(ref);
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => KoryPotScreen(potId: potId)),
  );
}

class KoryCreateScreen extends ConsumerStatefulWidget {
  const KoryCreateScreen({super.key, this.groupId});

  final int? groupId;

  @override
  ConsumerState<KoryCreateScreen> createState() => _KoryCreateScreenState();
}

class _KoryCreateScreenState extends ConsumerState<KoryCreateScreen> {
  static const _kinds = ['CAGNOTTE', 'COTISATION'];
  static const _periods = ['MONTHLY', 'WEEKLY'];

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _kind = 'CAGNOTTE';
  String _period = 'MONTHLY';
  DateTime? _dueAt;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueAt ?? now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _submit() async {
    final l = L.of(context);
    final title = _title.text.trim();
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));
    if (title.length < 3) {
      setState(() => _error = l.koryNeedTitle);
      return;
    }
    final amountRequired = _kind == 'COTISATION';
    if ((amountRequired || _amount.text.isNotEmpty) &&
        (amount == null || amount < 100)) {
      setState(() => _error = l.koryNeedAmount);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final pot = await ref
          .read(koryRepositoryProvider)
          .create(
            kind: _kind,
            title: title,
            description: _description.text.trim(),
            groupId: widget.groupId,
            goalAmount: _kind == 'CAGNOTTE' ? amount : null,
            amountPerMember: _kind == 'COTISATION' ? amount : null,
            period: _kind == 'COTISATION' ? _period : null,
            dueAt: _dueAt,
          );
      if (mounted) Navigator.of(context).pop(pot.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.koryActionFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ModuleScaffold(
      title: l.koryCreateTitle,
      subtitle: l.korySubtitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ModuleSegmented(
            labels: [l.koryKindCagnotte, l.koryKindCotisation],
            index: _kinds.indexOf(_kind),
            onChanged: (i) => setState(() => _kind = _kinds[i]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.koryFieldTitle),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: l.koryFieldDescription),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _kind == 'COTISATION'
                  ? l.koryFieldPerMember
                  : l.koryFieldGoal,
            ),
          ),
          if (_kind == 'COTISATION') ...[
            const SizedBox(height: 16),
            ModuleSegmented(
              labels: [l.koryPeriodMonthly, l.koryPeriodWeekly],
              index: _periods.indexOf(_period),
              onChanged: (i) => setState(() => _period = _periods[i]),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(
              _dueAt == null
                  ? l.koryFieldDue
                  : l.koryDue(DateFormat.yMMMd(locale).format(_dueAt!)),
            ),
            onTap: _pickDue,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.feedbackInfo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.koryCollectorIsYou,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppColors.feedbackDanger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.feedbackDanger),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          ModuleActionButton(
            label: l.koryCreate,
            expanded: true,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
