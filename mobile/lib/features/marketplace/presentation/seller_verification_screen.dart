import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';

/// Devenir vendeur vérifié — un écran, pas un sélecteur de photos surgissant.
///
/// L'ancienne version ouvrait DIRECTEMENT la galerie, sans un mot. La
/// personne se retrouvait devant ses photos sans savoir laquelle choisir, ni
/// ce qu'on allait en faire, ni que ça coûtait 5 000 FCFA — le prix
/// n'apparaissait qu'ensuite, sur une page de paiement.
///
/// Demander une pièce d'IDENTITÉ sans rien expliquer est le meilleur moyen
/// de se faire prendre pour une escroquerie. Cet écran dit d'abord pourquoi,
/// ce qu'on en fait, ce que ça rapporte, et ce que ça coûte.
class SellerVerificationScreen extends ConsumerStatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  ConsumerState<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState
    extends ConsumerState<SellerVerificationScreen> {
  XFile? _document;
  bool _submitting = false;
  String? _error;

  /// La formule choisie. `null` tant que rien n'est coché : la formule par
  /// défaut du serveur s'applique alors, comme avant l'arrivée des formules.
  String? _plan;

  VerificationPlan _formuleActive(MarketplaceConfig config) {
    final code = _plan;
    if (code == null) return config.defaultVerificationPlan;
    return config.verificationPlans.firstWhere(
      (p) => p.code == code,
      orElse: () => config.defaultVerificationPlan,
    );
  }

  Future<void> _pickDocument() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _document = picked;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final document = _document;
    if (document == null) {
      setState(() => _error = L.of(context).verifNeedDocument);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: await document.readAsBytes(),
            filename: document.name,
            mimeType: lookupMimeType(document.name) ?? 'image/jpeg',
            messageType: 'DOCUMENT',
          );
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .requestVerification(identityMediaId: uploaded.id, plan: _plan);
      final url = result['payment_url'] as String?;
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      ref.read(authControllerProvider.notifier).setCertificationStatus(
            isCertificationPending: true,
          );
      ref.invalidate(mySellerCertificationProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = L.of(context).adSendFailed);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(marketplaceConfigProvider);
    final formule = _formuleActive(config);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: L.of(context).verifTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ExplainerCard(
                    steps: <ExplainerStep>[
                      (
                        icon: Icons.verified_outlined,
                        title: L.of(context).verifBadgeTitle,
                        body: L.of(context).verifBadgeBody,
                      ),
                      (
                        icon: Icons.handshake_outlined,
                        title: L.of(context).verifWhyTitle,
                        body: L.of(context).verifWhyBody,
                      ),
                      (
                        icon: Icons.badge_outlined,
                        title: L.of(context).verifNeedTitle,
                        body: L.of(context).verifNeedBody,
                      ),
                      (
                        icon: Icons.lock_outline,
                        title: L.of(context).verifUseTitle,
                        body: L.of(context).verifUseBody,
                      ),
                      (
                        icon: Icons.event_available_outlined,
                        title: L.of(context).verifOneYearTitle,
                        body: L.of(context).verifOneYearBody,
                      ),
                    ],
                  ),
                  // ── Les formules ────────────────────────────────────
                  //
                  // L'écran n'en proposait qu'une, écrite en dur à 5 000
                  // FCFA. Elles viennent maintenant du serveur et se règlent
                  // depuis l'administration : ouvrir une nouvelle formule ne
                  // demande plus une publication Play Store.
                  //
                  // Le bloc disparaît s'il n'y a qu'une formule — un choix
                  // unique n'est pas un choix, et l'afficher ferait croire
                  // qu'on hésite. Le prix reste annoncé par la barre du bas.
                  if (config.verificationPlans.length > 1) ...[
                    const SizedBox(height: 22),
                    Text(
                      L.of(context).verifPlanLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final p in config.verificationPlans) ...[
                      _PlanTile(
                        plan: p,
                        selected: p.code == formule.code,
                        onTap: () => setState(() => _plan = p.code),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 22),
                  Text(
                    L.of(context).verifDocumentLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DocumentPicker(
                    document: _document,
                    onPick: _pickDocument,
                    onClear: () => setState(() => _document = null),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.semanticError,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PayBar(
              // Le montant vient du serveur, qui reste seul à facturer.
              price: formule.amount,
              caption: L.of(context).verifPayCaption,
              actionLabel: L.of(context).adPayAction,
              busy: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.document,
    required this.onPick,
    required this.onClear,
  });

  final XFile? document;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (document == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: Text(L.of(context).verifChoosePhoto),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 18,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              document!.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text(L.of(context).verifChange),
          ),
        ],
      ),
    );
  }
}

/// Une formule proposée — libellé, ce qu'elle apporte, et son prix.
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final VerificationPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentPrimaryLight.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentPrimaryDark : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? AppColors.accentPrimaryDark
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plan.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        plan.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${plan.amount} FCFA',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
