import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';

/// La période choisie sur « 8. Exporter la discussion ».
enum ProofExportPeriod { sinceActivation, all, custom }

class ProofExportOptions {
  const ProofExportOptions({
    required this.period,
    this.customFrom,
    this.customTo,
    required this.includeMedia,
  });

  final ProofExportPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool includeMedia;
}

/// « 8. Exporter la discussion » (maquette 28/68) : la période, le choix
/// d'inclure les photos et documents, ce que le PDF contient, et la note
/// juridique — commune à une discussion à deux et à un groupe.
class ProofExportOptionsScreen extends StatefulWidget {
  const ProofExportOptionsScreen({
    super.key,
    required this.scopeName,
    required this.since,
    required this.onCreate,
  });

  final String scopeName;

  /// Date d'activation du mode preuve — période par défaut.
  final DateTime since;

  /// Produit le PDF (fichier local pour une discussion à deux, octets reçus
  /// du serveur pour un groupe) à partir des options choisies.
  final Future<File> Function(ProofExportOptions options) onCreate;

  @override
  State<ProofExportOptionsScreen> createState() => _ProofExportOptionsScreenState();
}

class _ProofExportOptionsScreenState extends State<ProofExportOptionsScreen> {
  ProofExportPeriod _period = ProofExportPeriod.sinceActivation;
  DateTime? _from;
  DateTime? _to;
  bool _includeMedia = true;
  bool _busy = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from ?? widget.since, end: _to ?? now),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  Future<void> _create() async {
    final l = L.of(context);
    if (_period == ProofExportPeriod.custom && (_from == null || _to == null)) {
      await _pickRange();
      if (_from == null || _to == null) return;
    }
    setState(() => _busy = true);
    try {
      final file = await widget.onCreate(ProofExportOptions(
        period: _period,
        customFrom: _from,
        customTo: _to,
        includeMedia: _includeMedia,
      ));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProofReadyScreen(scopeName: widget.scopeName, file: file)),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final stamp = DateFormat.yMMMd(locale).add_Hm();

    return ModuleScaffold(
      title: l.proofExportOptionsTitle,
      subtitle: widget.scopeName,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ModuleSectionTitle(l.proofExportPeriodLabel),
          _radio(ProofExportPeriod.sinceActivation, l.proofExportSinceActivation, stamp.format(widget.since)),
          _radio(ProofExportPeriod.all, l.proofExportAllDiscussion, null),
          _radio(
            ProofExportPeriod.custom,
            l.proofExportCustomDates,
            _from != null && _to != null
                ? '${DateFormat.yMMMd(locale).format(_from!)} → ${DateFormat.yMMMd(locale).format(_to!)}'
                : null,
          ),
          const SizedBox(height: 16),
          ModuleCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeMedia,
              onChanged: (v) => setState(() => _includeMedia = v),
              title: Text(l.proofIncludeMedia),
              subtitle: Text(l.proofIncludeMediaNote),
            ),
          ),
          const SizedBox(height: 16),
          ModuleSectionTitle(l.proofExportContains),
          _contains(Icons.schedule, l.proofExportContainsDates),
          _contains(Icons.delete_outline, l.proofExportContainsDeleted),
          _contains(Icons.lock_outline, l.proofExportContainsHash),
          const SizedBox(height: 16),
          ModuleCallout(tone: CalloutTone.beige, text: l.proofExportLegalNote),
          const SizedBox(height: 20),
          ModuleActionButton(label: l.proofCreatePdf, busy: _busy, onPressed: _busy ? null : _create),
        ],
      ),
    );
  }

  Widget _radio(ProofExportPeriod value, String label, String? subtitle) => ModuleCard(
        onTap: () {
          setState(() => _period = value);
          if (value == ProofExportPeriod.custom) _pickRange();
        },
        child: Row(
          children: [
            Radio<ProofExportPeriod>(value: value, groupValue: _period, onChanged: (v) => setState(() => _period = v!)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _contains(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

/// « 9. PDF prêt » (maquette 28/68) : l'aperçu, l'empreinte SHA-256 du
/// fichier produit, et « Enregistrer »/« Partager ».
///
/// L'empreinte se calcule ICI, sur le fichier reçu — pour un export de
/// groupe, c'est le PDF du SERVEUR qu'on empreint, pas une promesse faite
/// à l'écran d'avant : la moindre différence de rendu changerait le hachage.
class ProofReadyScreen extends StatefulWidget {
  const ProofReadyScreen({super.key, required this.scopeName, required this.file});

  final String scopeName;
  final File file;

  @override
  State<ProofReadyScreen> createState() => _ProofReadyScreenState();
}

class _ProofReadyScreenState extends State<ProofReadyScreen> {
  String? _hash;
  int _sizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _computeHash();
  }

  Future<void> _computeHash() async {
    final bytes = await widget.file.readAsBytes();
    final digest = sha256.convert(bytes);
    if (mounted) {
      setState(() {
        _hash = digest.toString();
        _sizeBytes = bytes.length;
      });
    }
  }

  String get _formattedHash {
    final hash = _hash;
    if (hash == null) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < hash.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(hash.substring(i, (i + 4).clamp(0, hash.length)));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ko = (_sizeBytes / 1024).round();

    return ModuleScaffold(
      title: l.proofReadyTitle,
      subtitle: l.proofReadySubtitle(widget.scopeName, '$ko'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 40, color: AppColors.accentPrimary),
                const SizedBox(height: 8),
                Text(l.proofReadyPreviewNote, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ModuleSectionTitle(l.proofIntegrityHash),
          ModuleCard(
            child: SelectableText(
              _hash == null ? '…' : _formattedHash,
              contextMenuBuilder: pokouContextMenuBuilder,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 10),
          ModuleCallout(tone: CalloutTone.beige, text: l.proofIntegrityNote),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ModuleQuietButton(
                  icon: Icons.download_outlined,
                  label: l.actionSave,
                  onPressed: () => Share.shareXFiles([XFile(widget.file.path, mimeType: 'application/pdf')]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModuleActionButton(
                  icon: Icons.ios_share,
                  label: l.actionShare,
                  onPressed: () => Share.shareXFiles([XFile(widget.file.path, mimeType: 'application/pdf')]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
