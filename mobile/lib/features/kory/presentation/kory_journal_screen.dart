import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_export.dart';
import 'kory_home_widgets.dart';
import 'kory_ui.dart';

/// Une ligne du journal : quand, quoi, et à quel filtre elle répond.
class KoryJournalEvent {
  const KoryJournalEvent(this.at, this.text, this.kind, {this.entry});

  final DateTime at;
  final String text;

  /// `confirmed`, `contested` ou `other`.
  final String kind;
  final KoryEntry? entry;
}

/// Le journal se lit à partir de ce que le serveur garde : la création, les
/// déclarations, les confirmations et contestations, les prolongations, la
/// clôture, le tirage, les échanges et la dissolution. Rien n'est inventé,
/// et rien ne s'efface.
List<KoryJournalEvent> koryJournalEvents(L l, KoryPot pot) {
  final events = <KoryJournalEvent>[];
  String amount(KoryEntry e) =>
      e.amountHidden ? l.koryXAmountHidden : formatFcfa(e.amount);
  // « Toi » en complément (« … de Toi »), le nom en sujet (« Afi a déclaré »).
  String who(KoryEntry e) => e.isMine ? l.koryYou : (e.contributorName ?? '—');
  String author(KoryEntry e) => e.contributorName ?? l.koryYou;
  if (pot.createdAt != null) {
    events.add(
      KoryJournalEvent(
        pot.createdAt!,
        l.koryXEvtCreated(pot.organizerName ?? '—', koryKindLabel(l, pot)),
        'other',
      ),
    );
  }
  if (pot.drawnAt != null) {
    events.add(
      KoryJournalEvent(
        pot.drawnAt!,
        pot.drawMode == 'DRAW'
            ? l.koryXEvtDrawn(pot.drawSeal ?? '—')
            : l.koryXEvtOrderFixed,
        'other',
      ),
    );
  }
  for (final e in pot.entries) {
    events.add(
      KoryJournalEvent(
        e.declaredAt,
        e.walletReference == null
            ? l.koryXEvtDeclared(author(e), amount(e))
            : l.koryXEvtDeclaredRef(author(e), amount(e), e.walletReference!),
        'other',
        entry: e,
      ),
    );
    final reviewed = e.reviewedAt;
    if (reviewed != null && e.status == 'CONFIRMED') {
      events.add(
        KoryJournalEvent(
          reviewed,
          l.koryXEvtConfirmed(e.reviewerName ?? '—', amount(e), who(e)),
          'confirmed',
          entry: e,
        ),
      );
    } else if (reviewed != null && e.status == 'REJECTED') {
      events.add(
        KoryJournalEvent(
          reviewed,
          e.reviewReason == null
              ? l.koryXEvtContested(e.reviewerName ?? '—', amount(e), who(e))
              : l.koryXEvtContestedReason(
                  e.reviewerName ?? '—',
                  amount(e),
                  who(e),
                  e.reviewReason!,
                ),
          'contested',
          entry: e,
        ),
      );
    }
  }
  for (final s in pot.swaps.where((s) => s.status == 'DONE')) {
    events.add(
      KoryJournalEvent(
        s.decidedAt ?? s.createdAt,
        l.koryXEvtSwap(s.requesterName ?? '—', s.targetName ?? '—'),
        'other',
      ),
    );
  }
  if (pot.extendedAt != null && pot.dueAt != null) {
    events.add(
      KoryJournalEvent(
        pot.extendedAt!,
        l.koryXEvtExtended(
          DateFormat.yMMMd(l.localeName).format(pot.dueAt!.toLocal()),
        ),
        'other',
      ),
    );
  }
  if (pot.dissolvedAt != null) {
    events.add(
      KoryJournalEvent(
        pot.dissolvedAt!,
        l.koryXEvtDissolved(pot.dissolveReason ?? '—'),
        'other',
      ),
    );
  } else if (pot.closedAt != null) {
    events.add(KoryJournalEvent(pot.closedAt!, l.koryXEvtClosed, 'other'));
  }
  events.sort((a, b) => b.at.compareTo(a.at));
  return events;
}

enum _Filter { all, confirmed, contested }

// ── KOR-9 · Journal des contributions ───────────────────────────────────

class KoryJournalScreen extends ConsumerStatefulWidget {
  const KoryJournalScreen({super.key, required this.potId});

  final int potId;

  @override
  ConsumerState<KoryJournalScreen> createState() => _KoryJournalScreenState();
}

class _KoryJournalScreenState extends ConsumerState<KoryJournalScreen> {
  _Filter _filter = _Filter.all;
  bool _exporting = false;

  Future<void> _export(
    KoryPot pot,
    List<KoryJournalEvent> events,
    bool pdf,
  ) async {
    final l = L.of(context);
    setState(() => _exporting = true);
    try {
      final lines = [
        for (final e in events)
          KoryExportLine(
            e.at,
            e.text,
            columns: [
              e.text,
              if (e.entry != null) ...[
                e.entry!.contributorName ?? '',
                e.entry!.amountHidden ? '' : '${e.entry!.amount}',
                e.entry!.status,
                e.entry!.walletReference ?? '',
              ] else ...[
                '',
                '',
                '',
                '',
              ],
            ],
          ),
      ];
      if (pdf) {
        await korySharePdf(
          title: l.koryJournal,
          subtitle: pot.title,
          footer: l.koryXJournalLocked,
          lines: lines,
        );
      } else {
        await koryShareCsv(
          title: '${pot.title}-journal',
          header: [
            l.koryXCsvDate,
            l.koryXCsvEvent,
            l.koryXCsvPerson,
            l.koryXCsvAmount,
            l.koryXCsvStatus,
            l.koryXCsvReference,
          ],
          lines: lines,
        );
      }
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(widget.potId));
    final pot = async.valueOrNull;
    if (pot == null) {
      return KoryPage(
        title: l.koryJournal,
        loading: async.isLoading,
        body: Center(child: Text(l.koryUnavailable)),
      );
    }
    final all = koryJournalEvents(l, pot);
    final shown = [
      for (final e in all)
        if (_filter == _Filter.all ||
            (_filter == _Filter.confirmed && e.kind == 'confirmed') ||
            (_filter == _Filter.contested && e.kind == 'contested'))
          e,
    ];
    return KoryPage(
      title: l.koryJournal,
      subtitle: pot.title,
      footer: KoryFooter(
        children: [
          Row(
            children: [
              Expanded(
                child: KoryButton(
                  quiet: true,
                  icon: Icons.table_chart_outlined,
                  label: l.koryXExportCsv,
                  busy: _exporting,
                  onPressed: all.isEmpty
                      ? null
                      : () => _export(pot, all, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KoryButton(
                  quiet: true,
                  icon: Icons.picture_as_pdf_outlined,
                  label: l.koryXExportPdf,
                  busy: _exporting,
                  onPressed: all.isEmpty ? null : () => _export(pot, all, true),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref, potId: widget.potId);
          await ref.read(koryPotProvider(widget.potId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final (filter, label) in [
                  (_Filter.all, l.koryXFilterAll),
                  (_Filter.confirmed, l.koryXFilterConfirmed),
                  (_Filter.contested, l.koryXFilterContested),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == filter,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.koryJournalEmpty,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              for (final (i, e) in shown.indexed)
                _EventRow(event: e, last: i == shown.length - 1),
            const SizedBox(height: 16),
            KoryNotice(icon: Icons.lock_outline, text: l.koryXJournalLocked),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.last});

  final KoryJournalEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.kind) {
      'confirmed' => AppColors.feedbackSuccess,
      'contested' => AppColors.securityCritical,
      _ => AppColors.textMuted,
    };
    final day = koryDay(context, event.at);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.text,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  Text(
                    '$day · ${koryTime(event.at)}',
                    style: TextStyle(
                      fontSize: 12.5,
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
