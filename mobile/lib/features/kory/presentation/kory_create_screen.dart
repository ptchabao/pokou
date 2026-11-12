import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/group_model.dart';
import '../../groups/presentation/group_controller.dart';
import 'kory_controller.dart';
import 'kory_cotisation_screens.dart';
import 'kory_draft.dart';
import 'kory_participants_screen.dart';
import 'kory_pot_screen.dart';
import 'kory_tontine_screens.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';

/// Ouvre la création, puis la collecte créée. `groupId` la rattache au
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
  try {
    final pot = await ref.read(koryRepositoryProvider).pot(potId);
    if (!context.mounted) return;
    // KOR-11 : les participants — sauf pour une collecte rattachée à un
    // groupe, dont les membres participent déjà, et pour une tontine, dont
    // les membres sont choisis à l'étape 2.
    if (pot.groupId == null && !pot.isTontine) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              KoryParticipantsScreen(potId: potId, title: pot.title),
        ),
      );
      if (!context.mounted) return;
    }
  } catch (_) {
    // La collecte existe : on l'ouvre quand même.
  }
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: potId)));
}

/// La dernière étape de toute création : envoyer le brouillon au serveur.
/// Renvoie l'identifiant de la collecte, ou `null` après avoir dit l'échec.
Future<int?> koryCreateFromDraft(
  BuildContext context,
  WidgetRef ref,
  KoryDraft draft,
) async {
  final cotisation = draft.kind == 'COTISATION';
  final tontine = draft.kind == 'TONTINE';
  try {
    final pot = await ref
        .read(koryRepositoryProvider)
        .create(
          kind: draft.kind,
          title: draft.title,
          description: draft.description,
          groupId: draft.group?.id,
          goalAmount: draft.kind == 'CAGNOTTE' ? draft.amount : null,
          amountPerMember: draft.kind == 'CAGNOTTE' ? null : draft.amount,
          period: draft.kind == 'CAGNOTTE' ? null : draft.period,
          dueAt: draft.dueAt,
          endsAt: cotisation ? draft.endsAt : null,
          beneficiaryName: draft.kind == 'CAGNOTTE' ? draft.beneficiary : null,
          amountsVisible: draft.amountsVisible,
          memberIds: cotisation && draft.group != null ? draft.memberIds : null,
          rotation: tontine ? draft.memberIds : null,
          deputyId: draft.deputyId,
          drawMode: tontine ? draft.drawMode : null,
        );
    refreshKory(ref);
    return pot.id;
  } catch (_) {
    if (context.mounted) koryFailed(context);
    return null;
  }
}

// ── KOR-6 · Nouvelle collecte / KOR-17 · 23 : paramètres ─────────────────

class KoryCreateScreen extends ConsumerStatefulWidget {
  const KoryCreateScreen({super.key, this.groupId});

  final int? groupId;

  @override
  ConsumerState<KoryCreateScreen> createState() => _KoryCreateScreenState();
}

class _KoryCreateScreenState extends ConsumerState<KoryCreateScreen> {
  final _draft = KoryDraft(kind: 'CAGNOTTE');
  final _title = TextEditingController();
  final _beneficiary = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  bool _withEnd = false;
  bool _busy = false;
  bool _loadingGroup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final id = widget.groupId;
    if (id != null) _loadGroup(id);
  }

  @override
  void dispose() {
    _title.dispose();
    _beneficiary.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadGroup(int id) async {
    setState(() => _loadingGroup = true);
    try {
      final group = await ref.read(groupRepositoryProvider).getGroup(id);
      if (mounted) setState(() => _draft.group = group);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _loadingGroup = false);
    }
  }

  Future<void> _pickGroup() async {
    final l = L.of(context);
    final groups = ref.read(myGroupsProvider).valueOrNull ?? const <Group>[];
    final picked = await showModalBottomSheet<(Group?,)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              KorySection(l.koryXLinkedChat),
              if (_draft.kind != 'TONTINE')
                KoryPersonRow(
                  name: l.koryXNoLinkedChat,
                  muted: true,
                  onTap: () => Navigator.pop(sheetContext, (null,)),
                ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l.koryXNoGroups,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final g in groups)
                KoryPersonRow(
                  name: g.name,
                  subtitle: l.koryXPeople(g.memberCount),
                  onTap: () => Navigator.pop(sheetContext, (g,)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final group = picked.$1;
    if (group == null) {
      setState(() => _draft.group = null);
    } else {
      await _loadGroup(group.id);
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: initial ?? now.add(const Duration(days: 30)),
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day, 12);
  }

  bool _validate() {
    final l = L.of(context);
    final d = _draft;
    d.title = _title.text.trim();
    d.beneficiary = _beneficiary.text.trim();
    d.description = _description.text.trim();
    d.amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));
    String? error;
    if (d.title.length < 3) {
      error = l.koryNeedTitle;
    } else if ((d.kind != 'CAGNOTTE' || _amount.text.isNotEmpty) &&
        (d.amount == null || d.amount! < 100)) {
      error = l.koryNeedAmount;
    } else if (d.kind == 'COTISATION' && d.dueAt == null) {
      error = l.koryXNeedFirstDue;
    } else if (d.kind == 'TONTINE' && d.group == null) {
      error = l.koryXNeedGroup;
    }
    if (!_withEnd || d.kind != 'COTISATION') d.endsAt = null;
    setState(() => _error = error);
    return error == null;
  }

  Future<void> _continue() async {
    if (!_validate()) return;
    final d = _draft;
    int? potId;
    if (d.kind == 'CAGNOTTE') {
      setState(() => _busy = true);
      potId = await koryCreateFromDraft(context, ref, d);
      if (mounted) setState(() => _busy = false);
    } else if (d.kind == 'COTISATION') {
      potId = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => d.group == null
              ? KoryCotisationRecapScreen(draft: d)
              : KoryCotisationMembersScreen(draft: d),
        ),
      );
    } else {
      potId = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => KoryTontineMembersScreen(draft: d)),
      );
    }
    if (potId != null && mounted) Navigator.of(context).pop(potId);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final d = _draft;
    final me = ref.watch(authControllerProvider).user;
    final wallet = KoryWallet.of(me?.phone);
    // Kory Plus (BM-13) : la tontine ne se propose que dans un pays qui l'a
    // ouverte.
    final tontineOpen = ref
        .watch(currentCountryConfigProvider)
        .has('kory_plus');
    final kinds = [
      ('CAGNOTTE', l.koryKindCagnotte),
      ('COTISATION', l.koryKindCotisation),
      if (tontineOpen) ('TONTINE', l.koryXTontinePlus),
    ];
    final periods = d.kind == 'TONTINE'
        ? [
            ('WEEKLY', l.koryXEveryWeek),
            ('BIWEEKLY', l.koryXEveryFortnight),
            ('MONTHLY', l.koryXEveryMonth),
          ]
        : [
            ('WEEKLY', l.koryXEveryWeek),
            ('MONTHLY', l.koryXEveryMonth),
            ('QUARTERLY', l.koryXEveryQuarter),
          ];
    if (!periods.any((p) => p.$1 == d.period)) d.period = 'MONTHLY';
    final (title, subtitle) = switch (d.kind) {
      'COTISATION' => (l.koryXNewCotisation, l.koryXStepParams),
      'TONTINE' => (l.koryXNewTontine, l.koryXTontineStep('1')),
      _ => (l.koryCreateTitle, null),
    };
    final stake = int.tryParse(_amount.text) ?? 0;
    final size = d.group?.members.length ?? 0;
    return KoryPage(
      title: title,
      subtitle: subtitle,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: d.kind == 'CAGNOTTE'
                ? l.koryXCreateCagnotte
                : l.koryXContinue,
            busy: _busy,
            onPressed: _continue,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Semantics(
            label: l.koryXCollectType,
            child: Wrap(
              spacing: 8,
              children: [
                for (final (kind, label) in kinds)
                  ChoiceChip(
                    label: Text(label),
                    selected: d.kind == kind,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      d.kind = kind;
                      _error = null;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: d.kind == 'TONTINE' ? l.koryXName : l.koryFieldTitle,
            ),
          ),
          if (d.kind == 'CAGNOTTE')
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _beneficiary,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.koryXBeneficiaryField),
            ),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: switch (d.kind) {
                'CAGNOTTE' => l.koryFieldGoal,
                'TONTINE' => l.koryXStakePerMember,
                _ => l.koryFieldPerMember,
              },
              suffixText: 'FCFA',
            ),
          ),
          if (d.kind != 'CAGNOTTE') ...[
            KorySection(l.koryXPeriodicity),
            Semantics(
              label: l.koryXPeriodicity,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (period, label) in periods)
                    ChoiceChip(
                      label: Text(label),
                      selected: d.period == period,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => d.period = period),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _DateRow(
                  label: switch (d.kind) {
                    'COTISATION' => l.koryXFirstDue,
                    'TONTINE' => l.koryXFirstRound,
                    _ => l.koryXClosing,
                  },
                  value: d.dueAt == null
                      ? l.koryXChoose
                      : koryDate(context, d.dueAt!),
                  onTap: () async {
                    final date = await _pickDate(d.dueAt);
                    if (date != null) setState(() => d.dueAt = date);
                  },
                ),
                if (d.kind == 'COTISATION')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.koryXEnd),
                    subtitle: Text(
                      !_withEnd || d.endsAt == null
                          ? l.koryXNoEnd
                          : koryDate(context, d.endsAt!),
                    ),
                    value: _withEnd,
                    onChanged: (v) async {
                      if (!v) {
                        setState(() => _withEnd = false);
                        return;
                      }
                      final date = await _pickDate(d.endsAt ?? d.dueAt);
                      if (date != null) {
                        setState(() {
                          _withEnd = true;
                          d.endsAt = date;
                        });
                      }
                    },
                  ),
                if (d.kind == 'TONTINE' && stake > 0 && size > 1)
                  KoryLine(
                    l.koryXLeveePerRound,
                    formatFcfa(stake * (size - 1)),
                    caption: l.koryXLeveeCaption(size - 1, formatFcfa(stake)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                if (d.kind != 'TONTINE')
                  KoryLine(
                    l.koryXCollectorLabel,
                    [l.koryYou, ?wallet?.shortLabel].join(' · '),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.koryXIndividualAmounts),
                  subtitle: Text(
                    d.amountsVisible
                        ? l.koryXVisibleToAll
                        : l.koryXVisibleToCollector,
                  ),
                  value: d.amountsVisible,
                  onChanged: (v) => setState(() => d.amountsVisible = v),
                ),
                _DateRow(
                  label: l.koryXLinkedChat,
                  value: _loadingGroup
                      ? '…'
                      : (d.group?.name ?? l.koryXNoLinkedChat),
                  icon: Icons.forum_outlined,
                  onTap: widget.groupId != null ? null : _pickGroup,
                ),
              ],
            ),
          ),
          if (d.kind == 'CAGNOTTE') ...[
            const SizedBox(height: 10),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _description,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: l.koryFieldDescription),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            KoryNotice(tone: KoryTone.danger, text: _error!),
          ],
          const SizedBox(height: 12),
          KoryNotice(
            text: d.kind == 'TONTINE' ? l.koryTontineNote : l.koryXFreeNotice,
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.event_outlined,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.textPrimary)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}
