import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/server_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

// ── ANN-18 · Marquer comme vendue ──────────────────────────────────────

class AssimeMarkSoldScreen extends ConsumerStatefulWidget {
  const AssimeMarkSoldScreen({super.key, required this.product});

  final MarketplaceProduct product;

  @override
  ConsumerState<AssimeMarkSoldScreen> createState() =>
      _AssimeMarkSoldScreenState();
}

class _AssimeMarkSoldScreenState extends ConsumerState<AssimeMarkSoldScreen> {
  /// `-1` : quelqu'un hors de Pokou.
  int _buyer = -1;
  List<Map<String, dynamic>>? _candidates;
  late final TextEditingController _price;
  final _code = TextEditingController();
  bool _busy = false;

  /// La remise en main propre en cours : le vendeur attend le code que
  /// l'acheteur vient de recevoir.
  Map<String, dynamic>? _handover;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: (double.tryParse(widget.product.price)?.round() ?? '').toString(),
    );
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(marketplaceRepositoryProvider);
    try {
      final items = await repository.buyerCandidates(widget.product.id);
      if (!mounted) return;
      setState(() {
        _candidates = items;
        if (items.isNotEmpty) _buyer = items.first['user_id'] as int;
      });
    } catch (_) {
      if (mounted) setState(() => _candidates = const []);
    }
    // Une remise déjà lancée (l'écran a été quitté entre-temps) reprend.
    try {
      final current = await repository.handover(widget.product.id);
      if (mounted && current['status'] == 'PENDING') {
        setState(() => _handover = current);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _price.dispose();
    _code.dispose();
    super.dispose();
  }

  int? get _finalPrice => int.tryParse(_price.text.replaceAll(' ', ''));

  /// Acheteur hors de Pokou : pas de code possible, l'annonce est marquée
  /// vendue comme avant.
  Future<void> _confirmOutside() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .markSold(widget.product.id, finalPrice: _finalPrice);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.annSoldDone)));
      Navigator.of(context).pop(true);
    } catch (_) {
      _failed();
    }
  }

  /// « Commande validée et livrée » : en face de l'acheteur.
  Future<void> _startHandover() async {
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final handover = await ref
          .read(marketplaceRepositoryProvider)
          .startHandover(
            widget.product.id,
            buyerId: _buyer,
            finalPrice: _finalPrice,
          );
      if (!mounted) return;
      _code.clear();
      setState(() {
        _handover = handover;
        _busy = false;
      });
    } on ApiException catch (error) {
      _failed(error.message);
    } catch (_) {
      _failed();
    }
  }

  /// « Clôturer la vente » avec le code de l'acheteur.
  Future<void> _closeSale() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .confirmHandover(widget.product.id, _code.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.assXSaleClosed(_handover?['buyer_name'] as String? ?? ''),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeError = error.code == 'handover_wrong_code'
            ? l.assXWrongCode(error.attemptsLeft ?? 0)
            : error.message;
      });
    } catch (_) {
      _failed();
    }
  }

  Future<void> _cancelHandover() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .cancelHandover(widget.product.id);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _busy = false;
        _handover = null;
        _codeError = null;
      });
    }
  }

  void _failed([String? message]) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? L.of(context).koryActionFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final candidates = _candidates;
    final handover = _handover;
    final Widget body;
    final Widget action;
    if (candidates == null) {
      body = const Center(child: CircularProgressIndicator());
      action = ModuleActionButton(label: l.annSoldConfirm, onPressed: null);
    } else if (handover != null) {
      body = _codeStep(l, handover);
      action = ModuleActionButton(
        label: l.assXCloseSale,
        busy: _busy,
        onPressed: _busy || _code.text.trim().length < 6 ? null : _closeSale,
      );
    } else {
      body = _buyerStep(l, candidates);
      action = ModuleActionButton(
        label: _buyer < 0 ? l.annSoldConfirm : l.assXDelivered,
        busy: _busy,
        onPressed: _busy
            ? null
            : (_buyer < 0 ? _confirmOutside : _startHandover),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.annSoldTitle),
            Text(
              widget.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: action,
        ),
      ),
    );
  }

  Widget _buyerStep(L l, List<Map<String, dynamic>> candidates) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ModuleCallout(
          tone: CalloutTone.blue,
          title: l.assXInPersonTitle,
          text: l.assXInPersonInfo,
        ),
        const SizedBox(height: 16),
        Text(l.annSoldWho),
        const SizedBox(height: 12),
        ModuleCard(
          // Un Material à elle : les RadioListTile peignent leur effet de
          // toucher sur le Material le plus proche, que la carte cachait.
          child: Material(
            type: MaterialType.transparency,
            child: RadioGroup<int>(
              groupValue: _buyer,
              onChanged: (v) => setState(() => _buyer = v ?? -1),
              child: Column(
                children: [
                  for (final c in candidates)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: c['user_id'] as int,
                      title: Text(c['name'] as String? ?? ''),
                      subtitle: Text(
                        l.annSoldDiscussionOf(
                          DateFormat.MMMd(locale).format(
                            parseServerTime(
                              c['last_message_at'] as String,
                            ).toLocal(),
                          ),
                        ),
                      ),
                    ),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: -1,
                    title: Text(l.annSoldOutside),
                    subtitle: Text(l.annSoldOutsideSub),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_buyer < 0) ...[
          const SizedBox(height: 8),
          Text(
            l.assXOutsideNoCode,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.annSoldFinalPrice,
            suffixText: 'FCFA',
            helperText: l.annSoldPriceHelp,
          ),
        ),
      ],
    );
  }

  Widget _codeStep(L l, Map<String, dynamic> handover) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      ModuleCallout(
        tone: CalloutTone.blue,
        title: l.assXInPersonTitle,
        text: l.assXAskCode(
          handover['buyer_name'] as String? ?? '',
          '${handover['ttl_minutes'] ?? 15}',
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey('assime-handover-code'),
        contextMenuBuilder: pokouContextMenuBuilder,
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _codeError = null),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          labelText: l.assXCodeLabel,
          errorText: _codeError,
          counterText: '',
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: _busy ? null : _startHandover,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.assXNewCode),
          ),
          TextButton(
            onPressed: _busy ? null : _cancelHandover,
            child: Text(l.assXCancelHandover),
          ),
        ],
      ),
    ],
  );
}

/// Ce que l'ACHETEUR voit : le code de remise à donner au vendeur, une fois
/// l'article en main (ouvert depuis la notification ou la discussion).
class AssimeHandoverCodeScreen extends ConsumerStatefulWidget {
  const AssimeHandoverCodeScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<AssimeHandoverCodeScreen> createState() =>
      _AssimeHandoverCodeScreenState();
}

class _AssimeHandoverCodeScreenState
    extends ConsumerState<AssimeHandoverCodeScreen> {
  Map<String, dynamic>? _handover;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final handover = await ref
          .read(marketplaceRepositoryProvider)
          .handover(widget.productId);
      if (mounted) setState(() => _handover = handover);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final handover = _handover;
    final status = handover?['status'] as String?;
    final code = handover?['code'] as String?;
    final Widget body;
    if (_failed) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.assXNoHandover, textAlign: TextAlign.center),
        ),
      );
    } else if (handover == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final expires = parseServerTime(handover['expires_at'] as String);
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              handover['product_name'] as String? ?? '',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (status == 'PENDING' && code != null) ...[
              Text(l.assXCodeBody(handover['seller_name'] as String? ?? '')),
              const SizedBox(height: 20),
              Center(
                child: SelectableText(
                  code,
                  key: const ValueKey('assime-buyer-code'),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l.assXCodeUntil(DateFormat.Hm().format(expires.toLocal())),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              ModuleCallout(tone: CalloutTone.beige, text: l.assimeTipNoCode),
            ] else if (status == 'DONE') ...[
              Text(l.assXCodeDone),
              const SizedBox(height: 16),
              ModuleActionButton(
                label: l.annRateTitle,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        AssimeRateSaleScreen(productId: widget.productId),
                  ),
                ),
              ),
            ] else
              ModuleCallout(tone: CalloutTone.amber, text: l.assXCodeExpired),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.assXCodeTitle)),
      body: body,
    );
  }
}

// ── ANN-19 · Noter la transaction ──────────────────────────────────────

class AssimeRateSaleScreen extends ConsumerStatefulWidget {
  const AssimeRateSaleScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<AssimeRateSaleScreen> createState() =>
      _AssimeRateSaleScreenState();
}

class _AssimeRateSaleScreenState extends ConsumerState<AssimeRateSaleScreen> {
  static const _tags = [
    'as_described',
    'punctual',
    'fair_price',
    'friendly',
    'good_communication',
  ];
  Map<String, dynamic>? _sale;
  bool _failed = false;
  int _rating = 0;
  final Set<String> _selected = {};
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(marketplaceRepositoryProvider)
        .sale(widget.productId)
        .then((sale) {
          if (mounted) setState(() => _sale = sale);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String _tagLabel(L l, String tag) => switch (tag) {
    'as_described' => l.annTagAsDescribed,
    'punctual' => l.annTagPunctual,
    'fair_price' => l.annTagFairPrice,
    'friendly' => l.annTagFriendly,
    _ => l.annTagCommunication,
  };

  String _ratingLabel(L l) => switch (_rating) {
    1 => l.annRate1,
    2 => l.annRate2,
    3 => l.annRate3,
    4 => l.annRate4,
    5 => l.annRate5,
    _ => '',
  };

  Future<void> _publish() async {
    final l = L.of(context);
    final sale = _sale!;
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .reviewSeller(
            sellerId: sale['seller_id'] as int,
            rating: _rating,
            comment: _comment.text,
            tags: _selected.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.annRatePublished)));
      Navigator.of(context).pop(true);
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
    final sale = _sale;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.annRateTitle),
            if (sale != null)
              Text(
                l.annRateSubtitle(
                  sale['seller_name'] as String,
                  sale['product_name'] as String,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: _failed
          ? Center(
              child: Text(
                l.modulesCheckNetwork,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : sale == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (sale['reviewed'] == true) ...[
                  ModuleCallout(tone: CalloutTone.blue, text: l.annRateAlready),
                  const SizedBox(height: 12),
                ],
                ModuleCard(
                  child: Column(
                    children: [
                      Text(
                        l.annRateHow,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: l.annRateStars(_rating),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              IconButton(
                                tooltip: l.annRateStars(i),
                                iconSize: 36,
                                onPressed: () => setState(() => _rating = i),
                                icon: Icon(
                                  i <= _rating ? Icons.star : Icons.star_border,
                                  color: AppColors.brandOr,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _ratingLabel(l),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.annRateWentWell,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      FilterChip(
                        label: Text(_tagLabel(l, tag)),
                        selected: _selected.contains(tag),
                        onSelected: (on) => setState(
                          () => on ? _selected.add(tag) : _selected.remove(tag),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _comment,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(labelText: l.annRateComment),
                ),
                const SizedBox(height: 8),
                ModuleCallout(tone: CalloutTone.beige, text: l.annRateNotice),
              ],
            ),
      bottomNavigationBar: sale == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ModuleActionButton(
                  label: l.annRatePublish,
                  busy: _busy,
                  onPressed: _busy || _rating == 0 ? null : _publish,
                ),
              ),
            ),
    );
  }
}
