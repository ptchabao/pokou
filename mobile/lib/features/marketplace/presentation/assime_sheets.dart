import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/sharing/invite_sharing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../data/marketplace_repository.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';

/// Le libellé traduit d'un état d'article (Assimé 2, 3 et 6).
String assimeConditionLabel(L l, String condition) => switch (condition) {
  'NEW' => l.assimeConditionNew,
  'VERY_GOOD' => l.assimeConditionVeryGood,
  'GOOD' => l.assimeConditionGood,
  _ => l.assimeConditionToRepair,
};

/// Une puce de sélection, à la manière de la barre de catégories.
class AssimeChoiceChip extends StatelessWidget {
  const AssimeChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accentPrimary,
      side: BorderSide(
        color: selected ? AppColors.accentPrimary : AppColors.border,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      onSelected: onSelected,
    );
  }
}

// ── Assimé 2 · Filtres ───────────────────────────────────────────────────

/// La feuille « Filtres » : catégorie, prix, état, date de publication et
/// vendeurs certifiés. Rien ne s'applique avant « Voir les annonces ».
Future<void> showAssimeFilters(BuildContext context) => showModuleSheet<void>(
  context: context,
  builder: (_) => const _FiltersSheet(),
);

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late String _category;
  late bool _certified;
  late Set<String> _conditions;
  int? _days;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late String _sort;

  static const _dayChoices = [1, 7, 30];

  @override
  void initState() {
    super.initState();
    final filters = ref.read(marketplaceFiltersProvider);
    _category = ref.read(marketplaceCategoryProvider);
    _certified = ref.read(marketplaceCertifiedOnlyProvider);
    _conditions = {...filters.conditions};
    _days = filters.publishedDays;
    _sort = filters.sort;
    _min = TextEditingController(text: filters.minPrice?.toString() ?? '');
    _max = TextEditingController(text: filters.maxPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _category = 'TOUT';
    _certified = false;
    _conditions = {};
    _days = null;
    _min.clear();
    _max.clear();
  });

  void _apply() {
    ref.read(marketplaceCategoryProvider.notifier).state = _category;
    ref.read(marketplaceCertifiedOnlyProvider.notifier).state = _certified;
    ref.read(marketplaceFiltersProvider.notifier).state = MarketFilters(
      minPrice: int.tryParse(_min.text),
      maxPrice: int.tryParse(_max.text),
      conditions: _conditions,
      publishedDays: _days,
      sort: _sort,
    );
    Navigator.of(context).pop();
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );

  Widget _priceField(TextEditingController controller, String label) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 4),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '—'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final config = ref.watch(marketplaceConfigProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ModuleSheetTitle(l.assimeFilters)),
              TextButton(onPressed: _clear, child: Text(l.assimeFiltersClear)),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(l.assimeFilterCategory),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in config.categories)
                        AssimeChoiceChip(
                          label: category.label,
                          selected: _category == category.slug,
                          onSelected: (on) => setState(
                            () => _category = on ? category.slug : 'TOUT',
                          ),
                        ),
                    ],
                  ),
                  _label(l.assimeFilterPrice),
                  Row(
                    children: [
                      _priceField(_min, l.assimeFilterMin),
                      const SizedBox(width: 10),
                      _priceField(_max, l.assimeFilterMax),
                    ],
                  ),
                  _label(l.assimeFilterCondition),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final condition in assimeConditions)
                        AssimeChoiceChip(
                          label: assimeConditionLabel(l, condition),
                          selected: _conditions.contains(condition),
                          onSelected: (on) => setState(
                            () => on
                                ? _conditions.add(condition)
                                : _conditions.remove(condition),
                          ),
                        ),
                    ],
                  ),
                  _label(l.assimeFilterPublished),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AssimeChoiceChip(
                        label: l.assimeFilterPublishedAny,
                        selected: _days == null,
                        onSelected: (_) => setState(() => _days = null),
                      ),
                      for (final days in _dayChoices)
                        AssimeChoiceChip(
                          label: l.assimeFilterPublishedDays(days),
                          selected: _days == days,
                          onSelected: (_) => setState(() => _days = days),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ModuleCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _certified,
                        onChanged: (v) => setState(() => _certified = v),
                        title: Text(
                          l.assimeFilterCertified,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(l.assimeFilterCertifiedSub),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ModuleActionButton(label: l.assimeFilterApply, onPressed: _apply),
        ],
      ),
    );
  }
}

// ── Assimé 11 · Signaler ─────────────────────────────────────────────────

/// Signaler une annonce. Le vendeur n'en sait rien ; le serveur masque
/// l'annonce si plusieurs personnes la signalent.
Future<void> showReportListing(
  BuildContext context,
  WidgetRef ref,
  int productId,
) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final reason = await showModuleSheet<String>(
    context: context,
    builder: (_) => const _ReportSheet(),
  );
  if (reason == null) return;
  try {
    await ref.read(marketplaceRepositoryProvider).reportProduct(productId, reason);
    messenger.showSnackBar(SnackBar(content: Text(l.assimeReportSent)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = 'scam';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final reasons = <(String, String, String?)>[
      ('scam', l.assimeReportScam, null),
      ('forbidden', l.assimeReportForbidden, l.assimeReportForbiddenSub),
      ('counterfeit', l.assimeReportCounterfeit, null),
      ('misleading', l.assimeReportMisleading, null),
      ('other', l.assimeReportOther, null),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSheetTitle(l.assimeReportListing),
        const SizedBox(height: 12),
        ModuleCard(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final (value, title, subtitle) in reasons)
                    RadioListTile<String>(
                      value: value,
                      title: Text(title),
                      subtitle: subtitle == null ? null : Text(subtitle),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ModuleCallout(tone: CalloutTone.beige, text: l.assimeReportNote),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.feedbackDanger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(context).pop(_reason),
          child: Text(l.assimeReportSend),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
      ],
    );
  }
}

// ── Assimé 13 · Partager ─────────────────────────────────────────────────

/// Partager une annonce : dans une discussion Pokou (la fiche y est
/// épinglée), en copiant le texte, ou vers une autre application.
///
/// Écart assumé : la maquette propose aussi « Mon statut » et un lien qui
/// ouvre un aperçu hors de Pokou. Le serveur n'a ni page d'aperçu publique
/// ni statut-annonce : le texte partagé renvoie donc vers l'application.
Future<void> showShareListing(
  BuildContext context,
  WidgetRef ref,
  MarketplaceProduct product,
) => showModuleSheet<void>(
  context: context,
  builder: (_) => _ShareSheet(product: product),
);

class _ShareSheet extends ConsumerWidget {
  const _ShareSheet({required this.product});

  final MarketplaceProduct product;

  String _text(L l) => l.assimeShareText(
    product.name,
    '${product.price} ${product.currency}',
    InviteSharing.playStoreUrl,
  );

  Future<void> _toChat(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final contacts = (ref.read(contactsProvider).valueOrNull ?? const [])
        .where((c) => c.contactUserId != null)
        .toList();
    final picked = await showModuleSheet<(int, String)>(
      context: context,
      builder: (sheetContext) => contacts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.assimeShareNoContact),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ModuleSheetTitle(l.assimeShareChat),
                  for (final c in contacts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.displayName),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop((c.contactUserId!, c.displayName)),
                    ),
                ],
              ),
            ),
    );
    if (picked == null) return;
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .shareProduct(productId: product.id, recipientId: picked.$1);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l.assimeShareSent(picked.$2))),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final image = product.coverImage;
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.terracottaTint,
                child: Icon(icon, color: AppColors.accentPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSheetTitle(l.assimeShareTitle),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            action(Icons.arrow_forward, l.assimeShareChat, () {
              _toChat(context, ref);
            }),
            action(Icons.link, l.assimeShareCopy, () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: _text(l)));
              messenger.showSnackBar(
                SnackBar(content: Text(l.assimeShareCopied)),
              );
            }),
            action(Icons.share_outlined, l.assimeShareOther, () {
              Share.share(_text(l), subject: product.name);
            }),
          ],
        ),
        const SizedBox(height: 14),
        ModuleCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: image == null
                      ? ColoredBox(color: AppColors.surfaceElevated)
                      : MediaImage.meta(image, decodeWidth: 48),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${product.name} · ${product.price} ${product.currency}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        // « Hors de Pokou, le lien ouvre un aperçu limité » (maquette) n'est
        // pas affiché : cette page d'aperçu n'existe pas encore côté serveur.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }
}
