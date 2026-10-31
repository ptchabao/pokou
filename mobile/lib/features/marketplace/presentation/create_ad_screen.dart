import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'marketplace_controller.dart';
import '../../../core/widgets/paid_feature_widgets.dart';

/// Créer une publicité — un écran, pas une boîte de dialogue.
///
/// C'était deux champs de saisie et la mention « 10 000 FCFA · 7 jours »,
/// sans rien dire de ce qui allait se passer. Or à ce moment précis
/// l'utilisateur s'apprête à DÉPENSER, et il ignore trois choses qu'il a
/// besoin de savoir avant : qui verra sa campagne, quand elle commencera, et
/// ce qu'il advient de son argent si elle est refusée.
///
/// L'écran répond aux trois avant de demander quoi que ce soit. Le prix est
/// affiché en permanence et se recalcule avec la durée — un montant qui
/// n'apparaît qu'au moment de payer se lit comme un piège.
class CreateAdScreen extends ConsumerStatefulWidget {
  const CreateAdScreen({super.key});

  @override
  ConsumerState<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends ConsumerState<CreateAdScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _placement = 'MARKET';
  int _durationDays = 7;
  XFile? _media;
  bool _mediaIsVideo = false;
  bool _submitting = false;
  String? _error;

  /// Durée maximale d'une vidéo publicitaire.
  ///
  /// Trente secondes, et vérifiées côté client AVANT l'envoi : laisser
  /// téléverser trois minutes de vidéo sur un forfait de données compté,
  /// pour la refuser ensuite, est la pire façon de poser une limite.
  static const _maxVideo = Duration(seconds: 30);

  static const _weeklyPrice = 10000;

  int get _price => _weeklyPrice * ((_durationDays + 6) ~/ 7);

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool video}) async {
    final picker = ImagePicker();
    final picked = video
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            // Le sélecteur coupe lui-même à 30 s quand la plateforme le
            // permet ; la vérification ci-dessous rattrape les autres.
            maxDuration: _maxVideo,
          )
        : await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    if (video) {
      final controller = VideoPlayerController.file(File(picked.path));
      try {
        await controller.initialize();
        if (controller.value.duration >
            _maxVideo + const Duration(seconds: 1)) {
          if (mounted) {
            setState(
              () => _error =
                  'La vidéo dépasse 30 secondes. Raccourcissez-la avant de l\'envoyer.',
            );
          }
          return;
        }
      } catch (_) {
        // Durée illisible : on laisse passer plutôt que de bloquer sur un
        // format que le lecteur ne sait pas ouvrir mais que le serveur
        // acceptera peut-être.
      } finally {
        await controller.dispose();
      }
    }

    setState(() {
      _media = picked;
      _mediaIsVideo = video;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = L.of(context).adNeedTitleBody);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      int? mediaId;
      final media = _media;
      if (media != null) {
        final uploaded = await ref
            .read(mediaRepositoryProvider)
            .upload(
              bytes: await media.readAsBytes(),
              filename: media.name,
              mimeType:
                  lookupMimeType(media.name) ??
                  (_mediaIsVideo ? 'video/mp4' : 'image/jpeg'),
              messageType: _mediaIsVideo ? 'VIDEO' : 'IMAGE',
            );
        mediaId = uploaded.id;
      }

      final result = await ref
          .read(marketplaceRepositoryProvider)
          .createAd(
            title: title,
            body: body,
            durationDays: _durationDays,
            placement: _placement,
            mediaAssetId: mediaId,
          );
      final url = result['payment_url'] as String?;
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: L.of(context).adCreateTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ExplainerCard(
                    steps: [
                      (
                        icon: Icons.visibility_outlined,
                        title: L.of(context).adWhoSeesTitle,
                        body: L.of(context).adWhoSeesBody,
                      ),
                      (
                        icon: Icons.fact_check_outlined,
                        title: L.of(context).adReviewTitle,
                        body: L.of(context).adReviewBody,
                      ),
                      (
                        icon: Icons.schedule,
                        title: L.of(context).adCountdownTitle,
                        body: L.of(context).adCountdownBody,
                      ),
                      (
                        icon: Icons.replay,
                        title: L.of(context).adRefundTitle,
                        body: L.of(context).adRefundBody,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(L.of(context).commonTitle),
                  TextField(
                    controller: _titleController,
                    maxLength: 120,
                    decoration: InputDecoration(
                      hintText: L.of(context).adTitleHint,
                    ),
                  ),
                  FieldLabel(L.of(context).mediaMessage),
                  TextField(
                    controller: _bodyController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: L.of(context).adBodyHint,
                    ),
                  ),
                  FieldLabel(L.of(context).adMediaLabel),
                  Text(
                    L.of(context).adMediaHint,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(video: false),
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: Text(L.of(context).mediaPhoto),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(video: true),
                          icon: const Icon(Icons.videocam_outlined, size: 18),
                          label: Text(L.of(context).adVideo30s),
                        ),
                      ),
                    ],
                  ),
                  if (_media != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(
                            _mediaIsVideo ? Icons.videocam : Icons.image,
                            size: 16,
                            color: AppColors.accentPrimaryDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _media!.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _media = null),
                            child: Text(L.of(context).actionRemove),
                          ),
                        ],
                      ),
                    ),
                  FieldLabel(L.of(context).adPlacement),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'MARKET',
                        label: Text(L.of(context).adPlacementMarket),
                      ),
                      ButtonSegment(
                        value: 'STATUS',
                        label: Text(L.of(context).adPlacementStatus),
                      ),
                    ],
                    selected: {_placement},
                    onSelectionChanged: (v) =>
                        setState(() => _placement = v.first),
                  ),
                  FieldLabel(L.of(context).adDuration),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 7,
                        label: Text(L.of(context).adOneWeek),
                      ),
                      ButtonSegment(
                        value: 14,
                        label: Text(L.of(context).adTwoWeeks),
                      ),
                      ButtonSegment(
                        value: 30,
                        label: Text(L.of(context).adOneMonth),
                      ),
                    ],
                    selected: {_durationDays},
                    onSelectionChanged: (v) =>
                        setState(() => _durationDays = v.first),
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
              price: _price,
              caption: L.of(context).adPayCaption,
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
