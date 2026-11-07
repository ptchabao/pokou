import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/time/server_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: (double.tryParse(widget.product.price)?.round() ?? '').toString(),
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref
          .read(marketplaceRepositoryProvider)
          .buyerCandidates(widget.product.id);
      if (!mounted) return;
      setState(() {
        _candidates = items;
        if (items.isNotEmpty) _buyer = items.first['user_id'] as int;
      });
    } catch (_) {
      if (mounted) setState(() => _candidates = const []);
    }
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .markSold(
            widget.product.id,
            buyerId: _buyer < 0 ? null : _buyer,
            finalPrice: int.tryParse(_price.text.replaceAll(' ', '')),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.annSoldDone)));
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final candidates = _candidates;
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
      body: candidates == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(l.annSoldWho),
                const SizedBox(height: 12),
                ModuleCard(
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
                const SizedBox(height: 16),
                TextField(
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
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.annSoldConfirm,
            busy: _busy,
            onPressed: _busy || candidates == null ? null : _confirm,
          ),
        ),
      ),
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
