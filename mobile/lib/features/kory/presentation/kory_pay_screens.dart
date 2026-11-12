import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';

/// Ouvre « Contribuer » (KOR-2), puis « J'ai envoyé » (KOR-3). Au retour,
/// relit la collecte et dit que la contribution est déclarée.
Future<void> openKoryContribute(
  BuildContext context,
  WidgetRef ref,
  KoryPot pot, {
  int? amount,
}) async {
  final declared = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => KoryContributeScreen(pot: pot, amount: amount),
    ),
  );
  if (declared == true && context.mounted) {
    refreshKory(ref, potId: pot.id);
    koryToast(context, L.of(context).koryDeclared);
  }
}

/// Le montant proposé : ce que l'échéance, le tour ou l'engagement attend.
int _suggested(KoryPot pot) {
  final next = pot.cotisation?.myNext;
  if (next != null) return next.amount;
  if (pot.amountPerMember != null) return pot.amountPerMember!;
  final remaining = pot.myPledge?.remaining ?? 0;
  return remaining > 0 ? remaining : 10000;
}

/// À qui l'on envoie : le collecteur, ou le bénéficiaire du tour.
String _recipient(KoryPot pot) => pot.collectorName ?? '—';

// ── KOR-2 · Contribuer ───────────────────────────────────────────────────

class KoryContributeScreen extends StatefulWidget {
  const KoryContributeScreen({super.key, required this.pot, this.amount});

  final KoryPot pot;
  final int? amount;

  @override
  State<KoryContributeScreen> createState() => _KoryContributeScreenState();
}

class _KoryContributeScreenState extends State<KoryContributeScreen> {
  static const _presets = [5000, 10000, 20000];
  late final _amount = TextEditingController(
    text: '${widget.amount ?? _suggested(widget.pot)}',
  );

  int get _value => int.tryParse(_amount.text.replaceAll(' ', '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) koryToast(context, L.of(context).koryCopied);
  }

  Future<void> _next() async {
    final l = L.of(context);
    if (_value < 1) {
      koryToast(context, l.koryNeedAmount);
      return;
    }
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KoryDeclareScreen(pot: widget.pot, amount: _value),
      ),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final wallet = KoryWallet.of(pot.collectorPhone);
    final reference = koryReference(pot);
    final presets = {..._presets, _suggested(pot)}.toList()..sort();
    return KoryPage(
      title: l.koryHomeContribute,
      subtitle: pot.title,
      footer: KoryFooter(
        children: [KoryButton(label: l.koryXISent, onPressed: _next)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.koryXAmount,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextField(
                  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    suffixText: 'FCFA',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in presets)
                      ChoiceChip(
                        label: Text(formatFcfa(value)),
                        selected: value == _value,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _amount.text = '$value'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          KorySection(l.korySendTo),
          KoryCard(
            child: Column(
              children: [
                KoryPersonRow(
                  name: _recipient(pot),
                  subtitle: pot.isCollector && !pot.isTontine
                      ? l.koryCollectorIsYou
                      : wallet?.label,
                ),
                Divider(height: 20, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.koryXReferenceLabel,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            reference,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l.koryCopyReference,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _copy(reference),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(tone: KoryTone.warning, text: l.koryXNoTransferNotice),
          const SizedBox(height: 16),
          if (wallet?.ussd != null) ...[
            KoryButton(
              quiet: true,
              icon: Icons.dialpad,
              label: l.koryXDialUssd(wallet!.operator ?? ''),
              onPressed: () async {
                final ok = await wallet.dialUssd();
                if (!ok && context.mounted) koryFailed(context);
              },
            ),
            const SizedBox(height: 10),
          ],
          if (wallet != null)
            KoryButton(
              quiet: true,
              icon: Icons.copy,
              label: l.koryCopyPhone,
              onPressed: () => _copy(wallet.phone),
            ),
        ],
      ),
    );
  }
}

// ── KOR-3 · J'ai envoyé ──────────────────────────────────────────────────

class KoryDeclareScreen extends ConsumerStatefulWidget {
  const KoryDeclareScreen({super.key, required this.pot, required this.amount});

  final KoryPot pot;
  final int amount;

  @override
  ConsumerState<KoryDeclareScreen> createState() => _KoryDeclareScreenState();
}

class _KoryDeclareScreenState extends ConsumerState<KoryDeclareScreen> {
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final _sentAt = DateTime.now();
  Uint8List? _capture;
  bool _busy = false;

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCapture() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (mounted) setState(() => _capture = bytes);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      int? proof;
      final capture = _capture;
      if (capture != null) {
        final uploaded = await ref
            .read(mediaRepositoryProvider)
            .upload(
              bytes: capture,
              filename: 'kory-preuve.jpg',
              mimeType: 'image/jpeg',
              messageType: 'IMAGE',
            );
        proof = uploaded.id;
      }
      await ref
          .read(koryRepositoryProvider)
          .declare(
            widget.pot.id,
            amount: widget.amount,
            walletReference: _reference.text.trim(),
            periodLabel: widget.pot.cotisation?.myNext?.label,
            note: _note.text.trim(),
            proofMediaId: proof,
          );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      koryFailed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final wallet = KoryWallet.of(pot.collectorPhone);
    final recipient = _recipient(pot);
    final selfCollected = pot.isCollector && !pot.isTontine;
    return KoryPage(
      title: l.koryXISent,
      subtitle: [
        l.koryXAmountTo(formatFcfa(widget.amount), recipient),
        if (wallet?.operator != null) wallet!.operator!,
      ].join(' · '),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryDeclareTitle,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _reference,
              maxLength: 64,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.koryXTransactionRef,
                helperText: l.koryXTransactionRefHelp,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            KoryCard(
              onTap: _pickCapture,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (_capture != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _capture!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.accentPrimary,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _capture == null
                          ? l.koryAddSmsCapture
                          : l.koryXCaptureAdded,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_capture != null)
                    IconButton(
                      tooltip: l.koryXRemoveCapture,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _capture = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _note,
              maxLength: 280,
              decoration: InputDecoration(labelText: l.koryNote),
            ),
            KoryCard(
              child: Column(
                children: [
                  KoryLine(l.koryXSentAt, l.koryXTodayAt(koryTime(_sentAt))),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.koryXStatusAfter,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      koryStatusPill(
                        l,
                        selfCollected ? 'CONFIRMED' : 'DECLARED',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            KoryNotice(
              text: selfCollected
                  ? l.koryCollectorIsYou
                  : l.koryXDeclaredUntil(recipient),
            ),
          ],
        ),
      ),
    );
  }
}
