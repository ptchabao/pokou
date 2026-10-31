import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_model.dart';
import 'spark_room_screen.dart';
import 'spark_screen.dart';
import '../../../core/widgets/media_image.dart';

/// Le flux : la Carte du Moment, puis les profils.
class SparkFeedView extends ConsumerStatefulWidget {
  const SparkFeedView({super.key});

  @override
  ConsumerState<SparkFeedView> createState() => _SparkFeedViewState();
}

class _SparkFeedViewState extends ConsumerState<SparkFeedView> {
  /// Les textes traduits, relus à chaque accès plutôt que capturés : après
  /// un `await`, une variable pointerait sur la langue d'avant.
  L get _l => L.of(context);

  bool _sharingLocation = false;

  Future<void> _shareLocation() async {
    setState(() => _sharingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _say(_l.sparkEnableLocation);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _say(_l.sparkLocationNeeded);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await ref
          .read(sparkRepositoryProvider)
          .updateLocation(position.latitude, position.longitude);
      ref.invalidate(sparkFeedProvider);
      ref.invalidate(sparkProfileProvider);
    } catch (_) {
      _say(_l.sparkLocationFailed);
    } finally {
      if (mounted) setState(() => _sharingLocation = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(sparkFeedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sparkIntentProvider);
        ref.invalidate(sparkFeedProvider);
        await ref.read(sparkFeedProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _IntentCard(),
          const SizedBox(height: 16),
          feedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => ModuleEmptyState(
              icon: Icons.cloud_off,
              title: L.of(context).sparkFeedUnavailable,
              message: L.of(context).modulesCheckNetwork,
            ),
            data: (feed) {
              if (feed.needsIntent) {
                return ModuleEmptyState(
                  icon: Icons.today_outlined,
                  title: L.of(context).sparkPickIntentTitle,
                  message: feed.message ?? L.of(context).sparkPickIntentBody,
                );
              }
              if (feed.needsLocation) {
                return ModuleEmptyState(
                  icon: Icons.location_off_outlined,
                  title: L.of(context).sparkLocationStale,
                  message: feed.message ?? L.of(context).sparkLocationStaleBody,
                  action: ModuleActionButton(
                    label: L.of(context).sparkShareLocation,
                    icon: Icons.my_location,
                    busy: _sharingLocation,
                    expanded: false,
                    onPressed: _shareLocation,
                  ),
                );
              }
              if (feed.quotaReached) {
                return ModuleEmptyState(
                  icon: Icons.hourglass_bottom,
                  title: L.of(context).sparkQuotaTitle,
                  message: feed.message ?? L.of(context).sparkQuotaBody,
                );
              }
              if (feed.items.isEmpty) {
                return ModuleEmptyState(
                  icon: Icons.person_search_outlined,
                  title: L.of(context).sparkNobodyTitle,
                  message: L.of(context).sparkNobodyBody,
                );
              }
              return Column(
                children: [
                  for (final card in feed.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SparkCardTile(card: card),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// La Carte du Moment, avec son compte à rebours.
class _IntentCard extends ConsumerWidget {
  const _IntentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentAsync = ref.watch(sparkIntentProvider);

    return intentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (intent) => ModuleCard(
        onTap: () => _showIntentSheet(context, ref),
        child: Row(
          children: [
            const ModuleBadge(icon: Icons.today, color: sparkAccent, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intent?.label ?? L.of(context).sparkPickCard,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (intent == null)
                    Text(
                      L.of(context).sparkTodayLooking,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else
                    _IntentCountdown(secondsLeft: intent.secondsLeft),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Le temps restant d'une intention.
///
/// Décompté localement pour l'AFFICHAGE, à partir de la valeur du serveur.
/// C'est lui qui fait revenir : une carte qui meurt le soir oblige à redire
/// ce qu'on veut le lendemain.
class _IntentCountdown extends StatefulWidget {
  const _IntentCountdown({required this.secondsLeft});

  final int secondsLeft;

  @override
  State<_IntentCountdown> createState() => _IntentCountdownState();
}

class _IntentCountdownState extends State<_IntentCountdown> {
  late int _left;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _left = widget.secondsLeft;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _left = (_left - 30).clamp(0, 1 << 30));
    });
  }

  @override
  void didUpdateWidget(covariant _IntentCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondsLeft != widget.secondsLeft) _left = widget.secondsLeft;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left <= 0) {
      return Text(
        L.of(context).sparkCardExpired,
        style: TextStyle(
          color: sparkAccent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final hours = _left ~/ 3600;
    final label = hours >= 1
        ? L.of(context).sparkHoursLeft(hours)
        : L.of(context).sparkMinutesLeft(_left ~/ 60);
    return Text(
      label,
      style: const TextStyle(
        color: sparkAccent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

Future<void> _showIntentSheet(BuildContext context, WidgetRef ref) async {
  final options = await ref.read(sparkIntentOptionsProvider.future);
  if (!context.mounted) return;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModuleSheetTitle(
          L.of(context).sparkIntentSheetTitle,
          subtitle: L.of(context).sparkIntentSheetBody,
        ),
        const SizedBox(height: 14),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ModuleCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () async {
                await ref.read(sparkRepositoryProvider).setIntent(option.kind);
                ref.invalidate(sparkIntentProvider);
                ref.invalidate(sparkFeedProvider);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Un profil du flux.
class _SparkCardTile extends ConsumerStatefulWidget {
  const _SparkCardTile({required this.card});

  final SparkCard card;

  @override
  ConsumerState<_SparkCardTile> createState() => _SparkCardTileState();
}

class _SparkCardTileState extends ConsumerState<_SparkCardTile> {
  /// Les textes traduits, relus à chaque accès plutôt que capturés : après
  /// un `await`, une variable pointerait sur la langue d'avant.
  L get _l => L.of(context);

  bool _busy = false;

  Future<void> _like() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(sparkRepositoryProvider)
          .like(widget.card.userId);
      ref.invalidate(sparkFeedProvider);
      ref.invalidate(sparkProfileProvider);
      if (!mounted) return;
      if (result.matched && result.matchId != null) {
        ref.invalidate(sparkMatchesProvider);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SparkRoomScreen(matchId: result.matchId!),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.sparkLikesExhausted)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pass() async {
    setState(() => _busy = true);
    try {
      await ref.read(sparkRepositoryProvider).pass(widget.card.userId);
      ref.invalidate(sparkFeedProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return ModuleCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.tile),
            ),
            child: SparkPhotoView(
              photo: card.photos.isEmpty ? null : card.photos.first,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${card.displayName}, ${card.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (card.distanceKm != null)
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${card.distanceKm} km',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (card.bio != null && card.bio!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.bio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ModuleQuietButton(
                        label: L.of(context).sparkPass,
                        onPressed: _busy ? null : _pass,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ModuleActionButton(
                        label: L.of(context).sparkLike,
                        busy: _busy,
                        onPressed: _like,
                      ),
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

/// La photo d'une fiche, téléchargée par la route authentifiée.
///
/// Comme partout ailleurs dans Pokou : une URL publique rendrait les photos
/// d'un profil de rencontres accessibles à qui connaît un identifiant.
class SparkPhotoView extends ConsumerWidget {
  const SparkPhotoView({super.key, required this.photo, this.height = 260});

  final SparkPhoto? photo;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = photo?.media;
    if (media == null) {
      return Container(
        height: height,
        width: double.infinity,
        color: AppColors.surfaceElevated,
        child: Icon(Icons.person_outline, size: 48, color: AppColors.textMuted),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: MediaImage.meta(
        media,
        // Pleine largeur : le palier 1080 suffit, l'original pèse dix fois plus.
        decodeWidth: 420,
      ),
    );
  }
}
