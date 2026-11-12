import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_home_widgets.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Ce qu'un écran Kory demande à l'écran de la cagnotte en se refermant :
/// ouvrir la déclaration d'un versement (KOR-2 / KOR-3).
enum KoryNextStep { pay }

String _day(BuildContext context, DateTime date) => DateFormat.MMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date.toLocal());

String _hm(DateTime date) => DateFormat.Hm().format(date.toLocal());

void _writeTo(BuildContext context, WidgetRef ref, KoryPot pot) {
  final me = ref.read(authControllerProvider).user?.id;
  final collector = pot.collectorId;
  if (me == null || collector == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ConversationScreen(
        myUserId: me,
        contactUserId: collector,
        contactName: pot.collectorName ?? '',
        contactPhone: pot.collectorPhone,
      ),
    ),
  );
}

// ── KOR-12 · Je m'engage ────────────────────────────────────────────────

class KoryPledgeScreen extends ConsumerStatefulWidget {
  const KoryPledgeScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<KoryPledgeScreen> createState() => _KoryPledgeScreenState();
}

class _KoryPledgeScreenState extends ConsumerState<KoryPledgeScreen> {
  static const _presets = [5000, 10000, 15000, 20000];
  late final TextEditingController _base;
  late final TextEditingController _daily;
  late bool _withDaily;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final mine = widget.pot.myPledge;
    _base = TextEditingController(text: '${mine?.base ?? 10000}');
    _daily = TextEditingController(text: '${mine?.daily ?? 500}');
    _withDaily = (mine?.daily ?? 0) > 0;
  }

  @override
  void dispose() {
    _base.dispose();
    _daily.dispose();
    super.dispose();
  }

  int get _baseValue => int.tryParse(_base.text.replaceAll(' ', '')) ?? 0;
  int get _dailyValue =>
      _withDaily ? (int.tryParse(_daily.text.replaceAll(' ', '')) ?? 0) : 0;

  /// Les jours où le montant journalier s'ajoute, jusqu'à la date de fin —
  /// le serveur fait le même calcul, à partir de la date d'engagement.
  int get _days {
    final due = widget.pot.dueAt;
    if (due == null) return 0;
    final from = (widget.pot.myPledge?.pledgedAt ?? DateTime.now()).toLocal();
    final start = DateTime(from.year, from.month, from.day);
    final end = due.toLocal();
    final diff = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(start).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _submit() async {
    final l = L.of(context);
    if (_baseValue < 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryNeedAmount)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(koryRepositoryProvider)
          .pledge(widget.pot.id, base: _baseValue, daily: _dailyValue);
      refreshKory(ref, potId: widget.pot.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final due = pot.dueAt;
    final total = _baseValue + _dailyValue * _days;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryPledgeTitle),
            Text(
              due == null
                  ? pot.title
                  : l.koryPledgeSubtitleDue(_day(context, due), pot.title),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _base,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.koryPledgeStart,
              suffixText: 'FCFA',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _presets)
                ChoiceChip(
                  label: Text(formatFcfa(value)),
                  selected: value == _baseValue,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _base.text = '$value'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          KoryCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.koryPledgeDailyToggle),
              subtitle: Text(
                due == null ? l.koryPledgeNeedDue : l.koryPledgeDailyToggleSub,
              ),
              value: _withDaily && due != null,
              onChanged: due == null
                  ? null
                  : (v) => setState(() => _withDaily = v),
            ),
          ),
          if (_withDaily && due != null) ...[
            const SizedBox(height: 12),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _daily,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.koryPledgePerDay,
                suffixText: 'FCFA',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          KoryCard(
            child: Column(
              children: [
                KoryLine(l.koryPledgeStartRow, formatFcfa(_baseValue)),
                if (_dailyValue > 0)
                  KoryLine(
                    l.koryPledgeDailyRow(formatFcfa(_dailyValue), '$_days'),
                    formatFcfa(_dailyValue * _days),
                  ),
                const Divider(height: 16),
                KoryLine(
                  due == null
                      ? l.koryEngaged
                      : l.koryPledgeTotalAt(_day(context, due)),
                  formatFcfa(total),
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KoryNotice(tone: KoryTone.warning, text: l.koryPledgeEditableNotice),
        ],
      ),
      bottomNavigationBar: KoryFooter(
        children: [
          KoryButton(
            label: l.koryPledgeConfirm,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── KOR-13 · Engagement modifiable / KOR-14 · Engagement ferme ─────────

class KoryMyPledgeScreen extends ConsumerStatefulWidget {
  const KoryMyPledgeScreen({super.key, required this.potId});

  final int potId;

  @override
  ConsumerState<KoryMyPledgeScreen> createState() => _KoryMyPledgeScreenState();
}

class _KoryMyPledgeScreenState extends ConsumerState<KoryMyPledgeScreen> {
  Timer? _tick;

  /// Écart entre l'horloge du serveur et celle du téléphone, mesuré à
  /// chaque réponse : le compte à rebours suit le SERVEUR (KORY-13).
  Duration _skew = Duration.zero;
  KoryPot? _measured;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  DateTime get _now => DateTime.now().add(_skew);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = ref.watch(koryPotProvider(widget.potId)).valueOrNull;
    if (pot != null && !identical(pot, _measured)) {
      _measured = pot;
      final server = pot.serverNow;
      if (server != null) _skew = server.difference(DateTime.now());
    }
    final pledge = pot?.myPledge;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryMyPledgeTitle),
            if (pot != null)
              Text(
                pot.title,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: pot == null || pledge == null
          ? const KoryPageSkeleton()
          : (pledge.isFirm || !_now.isBefore(pledge.firmAt))
          ? _firm(context, pot, pledge)
          : _editable(context, pot, pledge),
      bottomNavigationBar: pot == null || pledge == null
          ? null
          : KoryFooter(
              children: [
                if (pledge.remaining > 0 || !pledge.isFirm)
                  KoryButton(
                    label: pledge.isFirm
                        ? l.koryPayAmount(formatFcfa(pledge.remaining))
                        : l.koryPayNow,
                    onPressed: () =>
                        Navigator.of(context).pop(KoryNextStep.pay),
                  ),
                if (pledge.isFirm && pot.collectorName != null)
                  TextButton(
                    onPressed: () => _writeTo(context, ref, pot),
                    child: Text(l.koryWriteTo(pot.collectorName!)),
                  ),
              ],
            ),
    );
  }

  Widget _editable(BuildContext context, KoryPot pot, KoryPledge pledge) {
    final l = L.of(context);
    final left = pledge.firmAt.difference(_now);
    final duration =
        '${left.inHours} h ${(left.inMinutes % 60).toString().padLeft(2, '0')}';
    final firmLocal = pledge.firmAt.toLocal();
    final today = DateUtils.isSameDay(firmLocal, DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        KoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KoryLine(l.koryMyPledgeTitle, l.koryEditableFor(duration)),
              Text(
                formatFcfa(pledge.total),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              KoryProgressBar(
                value: pledge.total == 0
                    ? 0
                    : (pledge.confirmed / pledge.total).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 6),
              Text(
                today
                    ? l.koryFirmToday(_hm(firmLocal))
                    : l.koryFirmOn(_day(context, firmLocal), _hm(firmLocal)),
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Divider(height: 20),
              KoryLine(l.koryPledgeStartRow, formatFcfa(pledge.base)),
              if ((pledge.daily ?? 0) > 0)
                KoryLine(
                  l.koryDailyRow,
                  l.koryPerDay(formatFcfa(pledge.daily!)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KoryButton(
          quiet: true,
          label: l.koryPledgeEdit,
          icon: Icons.edit_outlined,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => KoryPledgeScreen(pot: pot))),
        ),
        const SizedBox(height: 16),
        KoryCard(
          child: Column(
            children: [
              _Step(
                done: true,
                title: l.koryTimelineSaved,
                subtitle:
                    '${_day(context, pledge.pledgedAt)}, '
                    '${_hm(pledge.pledgedAt)}',
              ),
              _Step(
                done: true,
                title: l.koryTimelineEditable,
                subtitle: l.koryTimelineUntil(_hm(firmLocal)),
              ),
              _Step(
                done: false,
                title: l.koryTimelineFirm,
                subtitle: l.koryTimelineFirmSub,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KoryNotice(tone: KoryTone.neutral, text: l.koryPayNowOrLater),
      ],
    );
  }

  Widget _firm(BuildContext context, KoryPot pot, KoryPledge pledge) {
    final l = L.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        KoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KoryLine(
                l.koryMyPledgeTitle,
                l.koryFirmSince(_day(context, pledge.firmAt)),
              ),
              Text(
                formatFcfa(pledge.total),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Divider(height: 20),
              KoryLine(l.koryPledgeStartRow, formatFcfa(pledge.base)),
              if ((pledge.daily ?? 0) > 0)
                KoryLine(
                  l.koryDailyRow,
                  l.koryPerDay(formatFcfa(pledge.daily!)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KoryLine(l.koryPaidConfirmed, formatFcfa(pledge.confirmed)),
              const SizedBox(height: 6),
              KoryProgressBar(
                value: pledge.total == 0
                    ? 0
                    : (pledge.confirmed / pledge.total).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 6),
              KoryLine(
                l.koryRemainingToPay,
                formatFcfa(pledge.remaining),
                strong: true,
              ),
              if (pledge.nextDailyAdd != null && (pledge.daily ?? 0) > 0)
                Text(
                  l.koryNextDailyAdd(formatFcfa(pledge.daily!)),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KoryNotice(tone: KoryTone.neutral, text: l.koryFirmNotice),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.subtitle,
    this.last = false,
  });

  final bool done;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: done ? AppColors.feedbackSuccess : AppColors.textMuted,
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KOR-5 · Contribution contestée ──────────────────────────────────────

class KoryContestedScreen extends ConsumerStatefulWidget {
  const KoryContestedScreen({
    super.key,
    required this.pot,
    required this.entry,
  });

  final KoryPot pot;
  final KoryEntry entry;

  @override
  ConsumerState<KoryContestedScreen> createState() =>
      _KoryContestedScreenState();
}

class _KoryContestedScreenState extends ConsumerState<KoryContestedScreen> {
  bool _busy = false;

  Future<void> _resubmit({String? reference, int? proofMediaId}) async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(koryRepositoryProvider)
          .resubmit(
            widget.pot.id,
            widget.entry.id,
            walletReference: reference,
            proofMediaId: proofMediaId,
          );
      refreshKory(ref, potId: widget.pot.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryResubmitted)));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  Future<void> _checkReference() async {
    final l = L.of(context);
    final controller = TextEditingController(
      text: widget.entry.walletReference ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.koryCheckReference),
        content: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.koryWalletRef,
            helperText: l.koryWalletRefHelp,
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l.koryDeclare),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await _resubmit(reference: value.trim());
  }

  Future<void> _addCapture() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await photo.readAsBytes();
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: 'kory-preuve.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
          );
      if (!mounted) return;
      await _resubmit(proofMediaId: uploaded.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final entry = widget.entry;
    final collector = pot.collectorName ?? '—';
    final declared = [
      l.koryContestedDeclared(formatFcfa(entry.amount), _hm(entry.declaredAt)),
      if (entry.walletReference != null)
        l.koryXRefShort(entry.walletReference!),
    ].join(' · ');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryContestedTitle),
            Text(
              pot.title,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            KoryNotice(
              tone: KoryTone.danger,
              title: l.koryContestedHead(collector),
              text: declared,
              children: [
                if (entry.reviewReason != null) ...[
                  const SizedBox(height: 6),
                  Text(l.koryContestedReason(entry.reviewReason!)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            KoryCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tag),
                    title: Text(l.koryCheckReference),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _checkReference,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_photo_alternate_outlined),
                    title: Text(l.koryAddSmsCapture),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _addCapture,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(l.koryWriteTo(collector)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _writeTo(context, ref, pot),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KoryNotice(
              tone: KoryTone.warning,
              text: l.koryContestedOperatorNotice,
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

// ── KOR-15 · Fin de la collecte ────────────────────────────────────────

class KoryFinishScreen extends ConsumerStatefulWidget {
  const KoryFinishScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<KoryFinishScreen> createState() => _KoryFinishScreenState();
}

class _KoryFinishScreenState extends ConsumerState<KoryFinishScreen> {
  bool _extend = false;
  late DateTime _newDue;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final base =
        widget.pot.dueAt != null && widget.pot.dueAt!.isAfter(DateTime.now())
        ? widget.pot.dueAt!
        : DateTime.now();
    _newDue = base.add(const Duration(days: 7));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDue,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _newDue = DateTime(picked.year, picked.month, picked.day, 23, 59);
        _extend = true;
      });
    }
  }

  Future<void> _submit() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      final repo = ref.read(koryRepositoryProvider);
      if (_extend) {
        await repo.extend(widget.pot.id, _newDue);
      } else {
        await repo.close(widget.pot.id);
      }
      refreshKory(ref, potId: widget.pot.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final s = pot.pledgeSummary;
    final participants = s?.engagedCount ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryFinishTitle),
            Text(
              l.koryFinishSubtitle(pot.title),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (pot.isDue) ...[
            KoryNotice(tone: KoryTone.warning, text: l.koryFinishDueNotice),
            const SizedBox(height: 16),
          ],
          KoryCard(
            child: Column(
              children: [
                KoryLine(
                  l.koryEngaged,
                  formatFcfa(s?.engagedTotal ?? 0),
                  caption: l.koryParticipantsCount(participants),
                ),
                KoryLine(
                  l.koryConfirmedLabel,
                  formatFcfa(pot.confirmedTotal),
                  caption: pot.goalAmount == null
                      ? null
                      : l.koryOnGoal(formatFcfa(pot.goalAmount!)),
                ),
                KoryLine(
                  l.koryToConfirmLabel,
                  formatFcfa(s?.toConfirmTotal ?? 0),
                  caption: l.koryDeclarationsCount(s?.toConfirmCount ?? 0),
                ),
                KoryLine(
                  l.koryRemainingToPay,
                  formatFcfa(s?.remainingTotal ?? 0),
                  caption: l.koryParticipantsCount(s?.remainingCount ?? 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.koryWhatDoYouDo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          KoryCard(
            child: RadioGroup<bool>(
              groupValue: _extend,
              onChanged: (v) => setState(() => _extend = v ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    title: Text(l.koryCloseCollect),
                    subtitle: Text(l.koryCloseCollectSub),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    title: Text(l.koryExtend),
                    subtitle: Text(l.koryExtendSub(_day(context, _newDue))),
                    secondary: IconButton(
                      tooltip: l.koryFieldDue,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: _pickDate,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.koryFinishJournalNote,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: KoryFooter(
        children: [
          KoryButton(
            label: _extend
                ? l.koryExtendTo(_day(context, _newDue))
                : l.koryCloseAndNotify(participants),
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── KOR-16 · Collecte clôturée ──────────────────────────────────────────

class KoryClosedScreen extends ConsumerWidget {
  const KoryClosedScreen({super.key, required this.pot});

  final KoryPot pot;

  /// La référence à indiquer dans le transfert : elle aide le collecteur à
  /// rapprocher l'envoi de la cagnotte.
  String get reference => koryReference(pot);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pledge = pot.myPledge;
    final collector = pot.collectorName ?? '—';
    final initials = collector
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.koryClosedTitle),
            Text(
              l.koryClosedSubtitle(pot.title),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l.koryClosedBody(
              _day(context, pot.closedAt ?? DateTime.now()),
              collector,
            ),
          ),
          const SizedBox(height: 16),
          if (pledge != null)
            KoryCard(
              child: Column(
                children: [
                  KoryLine(l.koryEngaged, formatFcfa(pledge.total)),
                  KoryLine(
                    l.koryAlreadyConfirmed,
                    formatFcfa(pledge.confirmed),
                  ),
                  const Divider(height: 16),
                  KoryLine(
                    l.koryToPay,
                    formatFcfa(pledge.remaining),
                    strong: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.korySendTo,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.terracottaTint,
                      foregroundColor: AppColors.onTerracottaTint,
                      child: Text(initials),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collector,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (pot.collectorPhone != null)
                            Text(
                              pot.collectorPhone!,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(l.koryReferenceToGive(reference))),
                    IconButton(
                      tooltip: l.koryCopyReference,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reference));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.koryCopied)));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: pledge == null || pledge.remaining == 0
          ? null
          : KoryFooter(
              children: [
                KoryButton(
                  label: l.koryPayFromWallet(formatFcfa(pledge.remaining)),
                  onPressed: () => Navigator.of(context).pop(KoryNextStep.pay),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(KoryNextStep.pay),
                  child: Text(l.koryAlreadySent),
                ),
              ],
            ),
    );
  }
}
