import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/media_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../messaging/presentation/media_bubble.dart';
import '../data/ad_model.dart';
import 'marketplace_controller.dart';

/// Une publicité en diffusion, pleine largeur.
///
/// Elle était vendue — 10 000 FCFA la semaine, relue par l'équipe — et
/// aucun écran ne la montrait. « Sponsorisé » est écrit en tête : une
/// publicité qui se fait passer pour une annonce ordinaire se lit, une fois
/// découverte, comme une tromperie, et c'est la confiance dans tout le
/// marché qui en pâtit.
class AdCard extends ConsumerStatefulWidget {
  const AdCard({super.key, required this.ad});

  final MarketplaceAdItem ad;

  @override
  ConsumerState<AdCard> createState() => _AdCardState();
}

class _AdCardState extends ConsumerState<AdCard> {
  bool _contacting = false;

  Future<void> _contact() async {
    final l = L.of(context);
    setState(() => _contacting = true);
    try {
      final advertiser = await ref
          .read(marketplaceRepositoryProvider)
          .contactAdvertiser(widget.ad.id);
      final myUserId = ref.read(authControllerProvider).user?.id;
      if (!mounted || myUserId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            myUserId: myUserId,
            contactUserId: advertiser.advertiserId,
            contactName: advertiser.advertiserName.isNotEmpty
                ? advertiser.advertiserName
                : widget.ad.advertiserName,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adContactFailed)));
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ad = widget.ad;
    final media = ad.media;
    final isMine =
        ref.watch(authControllerProvider).user?.id == ad.advertiserId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.chip,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (media != null)
            ad.isVideo
                ? Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: VideoMessageBubble(media: media),
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: MediaImage(
                      mediaId: media.id,
                      semanticLabel: ad.title,
                    ),
                  ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.adSponsored,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (ad.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ad.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMine ? l.adYours : ad.advertiserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isMine)
                      FilledButton.icon(
                        onPressed: _contacting ? null : _contact,
                        icon: _contacting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(l.adContact),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
