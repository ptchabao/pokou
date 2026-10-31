import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_feed_view.dart';
import 'spark_model.dart';
import 'spark_safety_view.dart';
import 'spark_screen.dart';
import 'spark_wingman_view.dart';

/// « Moi » — ma fiche, mon Street Cred, mes achats, ma sécurité.
class SparkMeView extends ConsumerStatefulWidget {
  const SparkMeView({super.key, required this.profile});

  final SparkProfile profile;

  @override
  ConsumerState<SparkMeView> createState() => _SparkMeViewState();
}

class _SparkMeViewState extends ConsumerState<SparkMeView> {
  bool _busy = false;

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: picked.name,
            mimeType: picked.mimeType ?? 'image/jpeg',
            messageType: 'IMAGE',
          );
      await ref.read(sparkRepositoryProvider).addPhoto(upload.id);
      ref.invalidate(sparkProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).sparkPhotoFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Future<String?> Function() open, String pending) async {
    final url = await open();
    if (!mounted) return;
    await openPaymentGateway(context, url, pendingMessage: pending);
    ref.invalidate(sparkProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final shopAsync = ref.watch(sparkShopProvider);
    final likersAsync = ref.watch(sparkLikersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _ProfileCard(profile: profile, busy: _busy, onAddPhoto: _addPhoto),
        const SizedBox(height: 12),
        _KarmaCard(profile: profile),
        const SizedBox(height: 12),
        likersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (likers) => _LikersCard(
            count: likers.count,
            locked: likers.locked,
            onUnlock: () => _pay(
              ref.read(sparkRepositoryProvider).unlockLikers,
              L.of(context).sparkPaymentPendingLikers,
            ),
          ),
        ),
        ModuleSectionTitle(L.of(context).sparkGoFaster),
        shopAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (shop) => Column(
            children: [
              if (!profile.likesAreUnlimited)
                for (final pack in shop.likePacks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ShopRow(
                      icon: Icons.favorite_border,
                      title: '${pack.size} likes',
                      subtitle: L.of(context).sparkNoExpiry,
                      price: pack.price,
                      onTap: () => _pay(
                        () => ref
                            .read(sparkRepositoryProvider)
                            .buyLikes(pack.size),
                        L.of(context).sparkPaymentPendingLikes,
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ShopRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Spark+',
                  subtitle: profile.hasPlus
                      ? L.of(context).sparkPlusActive
                      : L.of(context).sparkPlusPitch,
                  price: shop.plusMonthly,
                  onTap: () => _pay(
                    ref.read(sparkRepositoryProvider).subscribePlus,
                    L.of(context).sparkPaymentPendingPlus,
                  ),
                ),
              ),
              _ShopRow(
                icon: Icons.rocket_launch_outlined,
                title: L.of(context).sparkBoost,
                subtitle: L.of(context).sparkBoostPitch,
                price: shop.boostHour,
                onTap: () => _pay(
                  ref.read(sparkRepositoryProvider).buyBoost,
                  L.of(context).sparkPaymentPendingBoost,
                ),
              ),
            ],
          ),
        ),
        ModuleSectionTitle(L.of(context).sparkAroundMe),
        _LinkRow(
          icon: Icons.shield_outlined,
          title: L.of(context).sparkSafety,
          subtitle: L.of(context).sparkSafetyPitch,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SparkSafetyScreen())),
        ),
        const SizedBox(height: 8),
        _LinkRow(
          icon: Icons.groups_outlined,
          title: L.of(context).sparkWingman,
          subtitle: L.of(context).sparkWingmanPitch,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SparkWingmanScreen())),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.busy,
    required this.onAddPhoto,
  });

  final SparkProfile profile;
  final bool busy;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: SparkPhotoView(
                    photo: profile.photos.isEmpty ? null : profile.photos.first,
                    height: 64,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.displayName}, ${profile.age}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      profile.photos.isEmpty
                          // Une fiche sans photo n'obtient rien, et il vaut
                          // mieux le dire que de laisser quelqu'un attendre.
                          ? L.of(context).sparkNoPhotoWarning
                          : '${profile.photos.length} photo${profile.photos.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ModuleQuietButton(
            label: busy
                ? L.of(context).sparkUploading
                : L.of(context).sparkAddPhoto,
            onPressed: busy ? null : onAddPhoto,
          ),
        ],
      ),
    );
  }
}

class _KarmaCard extends StatelessWidget {
  const _KarmaCard({required this.profile});

  final SparkProfile profile;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: Icons.verified_user,
                color: AppColors.accentPrimaryDark,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.of(context).sparkKarma,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      profile.canInvite
                          ? L.of(context).sparkCanInvite
                          // Dit en clair : découvrir au moment de réserver
                          // qu'on ne peut plus inviter serait incompréhensible.
                          : L.of(context).sparkCannotInvite,
                      style: TextStyle(
                        color: profile.canInvite
                            ? AppColors.textSecondary
                            : sparkAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${profile.karma}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ModuleProgressBar(
            value: profile.karma / 200,
            color: AppColors.accentPrimaryDark,
            done: profile.karma >= 150,
            height: 6,
          ),
        ],
      ),
    );
  }
}

class _LikersCard extends StatelessWidget {
  const _LikersCard({
    required this.count,
    required this.locked,
    required this.onUnlock,
  });

  final int count;
  final bool locked;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Le nombre est donné même verrouillé : payer sans savoir s'il y
            // a quelque chose à voir serait un marché de dupes.
            L.of(context).sparkLikersCount(count),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (locked) ...[
            const SizedBox(height: 10),
            ModuleActionButton(
              label: L.of(context).sparkSeeWho,
              onPressed: onUnlock,
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              L.of(context).sparkFindInDiscover,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          ModuleBadge(icon: icon, color: AppColors.accentPrimaryDark, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$price F',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          ModuleBadge(icon: icon, color: AppColors.accentPrimaryDark, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
