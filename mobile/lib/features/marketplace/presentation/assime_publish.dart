import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../honam/presentation/honam_screen.dart';
import '../../modules/shared/module_ui.dart';
import 'assime_sheets.dart';
import 'product_editor.dart';

/// Les trois traits de l'en-tête « étape N sur 3 » (Assimé 5 à 7).
class AssimeStepBar extends StatelessWidget {
  const AssimeStepBar({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.accentPrimary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Assimé 7 · Publier : aperçu ──────────────────────────────────────────

/// La dernière étape : la carte telle que les acheteurs la verront,
/// l'engagement sur les produits interdits, puis « Publier l'annonce ».
///
/// Rend `true` quand l'annonce est publiée. Un refus « médicament » ouvre
/// l'écran Produit interdit (Assimé 8) à sa place.
class AssimePreviewScreen extends ConsumerStatefulWidget {
  const AssimePreviewScreen({
    super.key,
    required this.draft,
    required this.cover,
    required this.onPublish,
  });

  final ProductDraft draft;
  final MediaMeta? cover;
  final Future<void> Function(ProductDraft draft) onPublish;

  @override
  ConsumerState<AssimePreviewScreen> createState() =>
      _AssimePreviewScreenState();
}

class _AssimePreviewScreenState extends ConsumerState<AssimePreviewScreen> {
  bool _pledged = false;
  bool _busy = false;

  Future<void> _publish() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await widget.onPublish(widget.draft);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (error.code == 'use_honam') {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AssimeForbiddenScreen(title: widget.draft.name),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode < 500 ? error.message : l.marketPublishFailed,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.marketPublishFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final draft = widget.draft;
    final cover = widget.cover;
    final seller = ref.watch(authControllerProvider).user?.fullName ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.assimePreviewTitle),
            Text(
              l.assimePublishStep(3),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const AssimeStepBar(step: 3),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: ModuleCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: cover == null
                              ? ColoredBox(
                                  color: AppColors.surfaceElevated,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              : MediaImage.meta(cover, decodeWidth: 150),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${draft.price} FCFA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              draft.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (draft.condition != null)
                              Text(
                                assimeConditionLabel(l, draft.condition!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (draft.location != null)
                              Text(
                                draft.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Text(
                              seller,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.assimePreviewWhat,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.assimePreviewExpiry,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModuleCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _pledged,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _pledged = v ?? false),
                title: Text(
                  l.assimePreviewPledge,
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // La mise en avant se paie APRÈS la publication, depuis « Mes
          // annonces » : la maquette montre une bascule ici, mais le
          // paiement porte sur une annonce qui doit déjà exister.
          ModuleCallout(
            tone: CalloutTone.beige,
            title: l.assimePreviewBoost,
            text: l.assimePreviewBoostSub,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.assimePublishListing,
            busy: _busy,
            onPressed: _pledged && !_busy ? _publish : null,
          ),
        ),
      ),
    );
  }
}

// ── Assimé 8 · Produit interdit ──────────────────────────────────────────

/// Un médicament ne se vend pas sur Assimé : l'écran le dit, renvoie vers
/// Honam et rappelle les autres interdits.
class AssimeForbiddenScreen extends StatelessWidget {
  const AssimeForbiddenScreen({super.key, required this.title});

  /// Le titre saisi, rappelé tel quel.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget item(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.block, color: AppColors.feedbackDanger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.feedbackDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.assimeReportForbidden)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ModuleCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(title, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 12),
          ModuleCallout(
            tone: CalloutTone.red,
            title: l.assimeForbiddenTitle,
            text: l.assimeForbiddenBody,
          ),
          const SizedBox(height: 12),
          ModuleQuietButton(
            label: l.assimeGoHonam,
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HonamScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.assimeAlsoForbidden,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ModuleCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Une liste, pas des boutons : rien n'y est touchable.
                item(l.assimeForbiddenWeapons),
                item(l.assimeForbiddenCounterfeit),
                item(l.assimeForbiddenAnimals),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.assimeChangeItem,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
