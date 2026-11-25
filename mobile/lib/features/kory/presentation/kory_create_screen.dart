import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../../core/widgets/pokou_sheet.dart';

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
    final picked = await showPokouSheet<(Group?,)>(
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

  /// « le 5 du mois » : le jour de l'échéance (cotisation) ou de la levée
  /// (tontine). C'est le jour de la première date : le choisir ici la
  /// déplace au prochain mois qui l'a encore devant lui.
  Future<void> _pickDay() async {
    final d = _draft;
    if (d.period == 'WEEKLY' || d.period == 'BIWEEKLY') {
      final date = await _pickDate(d.dueAt);
      if (date != null) setState(() => d.dueAt = date);
      return;
    }
    final day = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          d.kind == 'TONTINE'
              ? L.of(dialogContext).koryMqLeveeDay
              : L.of(dialogContext).koryMqDueDay,
        ),
        content: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // Jusqu'au 28 : chaque mois l'a.
            for (var i = 1; i <= 28; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: d.dueAt?.day == i,
                showCheckmark: false,
                onSelected: (_) => Navigator.pop(dialogContext, i),
              ),
          ],
        ),
      ),
    );
    if (day == null || !mounted) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final base = d.dueAt ?? today;
    var next = DateTime(base.year, base.month, day, 12);
    if (next.isBefore(today)) {
      next = DateTime(base.year, base.month + 1, day, 12);
    }
    setState(() => d.dueAt = next);
  }

  /// « le 5 du mois », « chaque lundi » — d'après la première date.
  String _dayLabel(L l, KoryDraft d) {
    final due = d.dueAt;
    if (due == null) return l.koryXChoose;
    if (d.period == 'WEEKLY' || d.period == 'BIWEEKLY') {
      return l.koryMqEveryWeekday(
        DateFormat.EEEE(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(due),
      );
    }
    return l.koryMqDayOfMonth('${due.day}');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final d = _draft;
    final me = ref.watch(authControllerProvider).user;
    final wallet = KoryWallet.of(me?.phone);
    final country = ref.watch(currentCountryConfigProvider);
    // Kory Plus (BM-13) : la tontine ne se propose que dans un pays qui l'a
    // ouverte.
    final tontineOpen = country.has('kory_plus');
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
    final tontine = d.kind == 'TONTINE';
    final cotisation = d.kind == 'COTISATION';
    final feeHt = country.koryPlusFeeHt;
    final linkedChat = _DateRow(
      label: l.koryXLinkedChat,
      value: _loadingGroup ? '…' : (d.group?.name ?? l.koryXNoLinkedChat),
      onTap: widget.groupId != null ? null : _pickGroup,
    );
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
            child: _Segmented(
              options: kinds,
              value: d.kind,
              onChanged: (kind) => setState(() {
                d.kind = kind;
                _error = null;
              }),
            ),
          ),
          // Ce qu'est le type choisi, et ce qu'il coûte : rien pour une
          // cagnotte ou une cotisation, des frais Kory Plus pour la tontine.
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: KoryNotice(
              tone: tontine ? KoryTone.warning : KoryTone.neutral,
              text: switch (d.kind) {
                'COTISATION' => l.koryTDescCotisation,
                'TONTINE' => l.koryTDescTontine,
                _ => l.koryTDescCagnotte,
              },
            ),
          ),
          _Field(
            label: tontine ? l.koryXName : l.koryFieldTitle,
            child: TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          if (d.kind == 'CAGNOTTE')
            _Field(
              label: l.koryMqBeneficiary,
              child: TextField(
                contextMenuBuilder: pokouContextMenuBuilder,
                controller: _beneficiary,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          // Le montant, et à côté sa date : clôture, jour d'échéance ou
          // nombre de membres.
          _FieldPair(
            first: _Field(
              label: switch (d.kind) {
                'CAGNOTTE' => l.koryMqGoalOptional,
                'TONTINE' => l.koryXStakePerMember,
                _ => l.koryMqAmountPerMember,
              },
              child: TextField(
                contextMenuBuilder: pokouContextMenuBuilder,
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(suffixText: 'FCFA'),
              ),
            ),
            second: switch (d.kind) {
              'CAGNOTTE' => _Field(
                label: l.koryXClosing,
                child: _TapField(
                  value: d.dueAt == null
                      ? l.koryXChoose
                      : koryDate(context, d.dueAt!),
                  onTap: () async {
                    final date = await _pickDate(d.dueAt);
                    if (date != null) setState(() => d.dueAt = date);
                  },
                ),
              ),
              'TONTINE' => _Field(
                label: l.koryMqMembers,
                // Les membres viennent de la discussion liée ; on les
                // choisit à l'étape 2.
                child: _TapField(
                  value: size > 0 ? '$size' : l.koryXChoose,
                  onTap: widget.groupId != null ? null : _pickGroup,
                ),
              ),
              _ => _Field(
                label: l.koryMqDue,
                child: _TapField(value: _dayLabel(l, d), onTap: _pickDay),
              ),
            },
          ),
          if (d.kind != 'CAGNOTTE')
            _Field(
              label: l.koryXPeriodicity,
              child: _Segmented(
                options: periods,
                value: d.period,
                onChanged: (period) => setState(() => d.period = period),
              ),
            ),
          if (cotisation)
            _FieldPair(
              first: _Field(
                label: l.koryXFirstDue,
                child: _TapField(
                  value: d.dueAt == null
                      ? l.koryXChoose
                      : koryDate(context, d.dueAt!),
                  onTap: () async {
                    final date = await _pickDate(d.dueAt);
                    if (date != null) setState(() => d.dueAt = date);
                  },
                ),
              ),
              second: _Field(
                label: l.koryXEnd,
                child: _TapField(
                  value: !_withEnd || d.endsAt == null
                      ? l.koryXNoEnd
                      : koryDate(context, d.endsAt!),
                  onTap: () async {
                    final date = await _pickDate(d.endsAt ?? d.dueAt);
                    setState(() {
                      // Fermer le calendrier sans choisir : sans date de fin.
                      _withEnd = date != null;
                      d.endsAt = date;
                    });
                  },
                ),
              ),
            ),
          if (tontine)
            _FieldPair(
              first: _Field(
                label: l.koryMqLeveeDay,
                child: _TapField(value: _dayLabel(l, d), onTap: _pickDay),
              ),
              second: _Field(
                label: l.koryXFirstRound,
                child: _TapField(
                  value: d.dueAt == null
                      ? l.koryXChoose
                      : koryMonth(context, d.dueAt!, year: true),
                  onTap: () async {
                    final date = await _pickDate(d.dueAt);
                    if (date != null) setState(() => d.dueAt = date);
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          KoryRowsCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              if (tontine) ...[
                if (size > 1 && d.dueAt != null)
                  KoryLine(
                    l.koryMqRounds,
                    l.koryXRoundsSpan(
                      size,
                      koryMonth(context, d.dueAt!).toLowerCase(),
                      koryMonth(
                        context,
                        koryAddPeriod(d.dueAt!, d.period, size - 1),
                      ).toLowerCase(),
                    ),
                  ),
                if (stake > 0 && size > 1)
                  KoryLine(
                    l.koryXLeveePerRound,
                    formatFcfa(stake * size),
                    caption: l.koryXLeveeCaption(size, formatFcfa(stake)),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.koryXCollectorLabel,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          [l.koryYou, ?wallet?.shortLabel].join(' · '),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const KoryVerifiedPill(),
                    ],
                  ),
                ),
              if (!tontine)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    l.koryXIndividualAmounts,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    d.amountsVisible
                        ? l.koryXVisibleToAll
                        : l.koryXVisibleToCollector,
                  ),
                  value: d.amountsVisible,
                  onChanged: (v) => setState(() => d.amountsVisible = v),
                ),
              linkedChat,
            ],
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
          // La tontine : le montant exact des frais, et qui reçoit. Pour
          // la cagnotte et la cotisation, l'encadré du haut a tout dit.
          if (tontine) ...[
            const SizedBox(height: 12),
            KoryNotice(
              text: feeHt != null && feeHt > 0
                  ? l.koryMqPlusFeeNotice(
                      formatFcfa(feeHt),
                      formatFcfa((feeHt * (1 + country.vatRate)).round()),
                    )
                  : l.koryTontineNote,
            ),
          ],
        ],
      ),
    );
  }
}

/// Un champ et son libellé au-dessus, comme la maquette.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

/// Deux champs côte à côte.
class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 10),
      Expanded(child: second),
    ],
  );
}

/// Un champ qu'on touche pour choisir (une date, un jour).
class _TapField extends StatelessWidget {
  const _TapField({required this.value, required this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(28),
    // Le décor des champs du thème : on ne distingue pas un champ à choisir
    // d'un champ à taper.
    child: InputDecorator(
      decoration: const InputDecoration(),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textPrimary),
      ),
    ),
  );
}

/// Des onglets côte à côte : le choix retenu est plein.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (key, label)) in options.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            selected: key == value,
            button: true,
            child: Material(
              color: key == value
                  ? AppColors.actionButtonBackground
                  : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: key == value
                      ? AppColors.actionButtonBackground
                      : AppColors.border,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 11,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: key == value
                          ? AppColors.actionButtonForeground
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
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
