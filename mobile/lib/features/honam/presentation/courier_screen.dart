import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barcode/barcode.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/deeplink/invite_link_parser.dart' show pokouLinkBaseUrl;
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../../kory/presentation/kory_wallet.dart';
import '../data/honam_models.dart';
import 'courier_join_screen.dart';
import 'courier_ride_screens.dart';
import 'honam_controller.dart';
import 'honam_tracking.dart' show honamTransportLabel;
import 'honam_ui.dart';

export 'courier_ride_screens.dart' show CourierIncomingRideScreen, openInMaps;

/// Le lien de parrainage d'un coursier, à partager (maquettes 15 et 23).
String courierInviteLink(String code) => '$pokouLinkBaseUrl/honam/coursier/$code';

/// Le mode coursier Win Pokou (BM-08) : un mode de l'application, pas une
/// application à part. L'écran prend la forme de l'état du coursier :
/// offre, candidature envoyée ou à compléter, bienvenue, suspendu, et le
/// mode coursier lui-même (maquettes Coursiers 1, 7, 8, 17, 18, 21).
class CourierScreen extends ConsumerWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(courierStatusProvider);
    if (!async.hasValue) {
      return KoryPage(title: l.honamCourierMode, loading: true, body: const SizedBox());
    }
    final status = async.requireValue;
    if (status == null) return const CourierOfferScreen();
    return switch (status.status) {
      'PENDING' => _ApplicationSent(status: status),
      'INCOMPLETE' => _ApplicationIncomplete(status: status),
      'REJECTED' => KoryPage(
        title: l.courierStatusRejected,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [KoryNotice(tone: KoryTone.danger, text: l.courierRejectedBody)],
        ),
      ),
      'SUSPENDED' => _Suspended(status: status),
      _ when !status.welcomed => _Welcome(status: status),
      _ => _CourierMode(status: status),
    };
  }
}

// ── 7. Candidature envoyée ──

class _ApplicationSent extends StatelessWidget {
  const _ApplicationSent({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryPage(
      title: l.courierStepSent,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.courierDone,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: courierApplicationSteps(context, status, null),
      ),
    );
  }
}

// ── 18. Candidature à compléter ──

class _ApplicationIncomplete extends ConsumerStatefulWidget {
  const _ApplicationIncomplete({required this.status});

  final CourierStatus status;

  @override
  ConsumerState<_ApplicationIncomplete> createState() =>
      _ApplicationIncompleteState();
}

class _ApplicationIncompleteState extends ConsumerState<_ApplicationIncomplete> {
  bool _busy = false;

  Future<void> _retake() async {
    final item = widget.status.incompleteItem ?? 'SELFIE';
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: item == 'SELFIE' ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (photo == null) return;
    setState(() => _busy = true);
    try {
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: await photo.readAsBytes(),
            filename: 'piece.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
            memoriser: false,
          );
      await ref
          .read(honamRepositoryProvider)
          .courierIdentity(
            selfie: item == 'SELFIE' ? upload.id : null,
            front: item == 'ID_FRONT' ? upload.id : null,
            back: item == 'ID_BACK' ? upload.id : null,
          );
      ref.invalidate(courierStatusProvider);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final status = widget.status;
    final item = status.incompleteItem ?? 'SELFIE';
    final itemLabel = switch (item) {
      'ID_FRONT' => l.courierItemFront,
      'ID_BACK' => l.courierItemBack,
      'WALLET' => l.courierItemWallet,
      _ => l.courierItemSelfie,
    };
    final wallet = KoryWallet.of(status.walletPhone);
    final validated = [
      if (item != 'ID_FRONT' && item != 'ID_BACK') l.courierIdDocument,
      l.courierZonesAndSlots,
      if (item != 'WALLET' && wallet != null) l.courierWalletLabel(wallet.shortLabel),
      l.courierRulesAccepted,
    ];
    return KoryPage(
      title: l.courierToComplete,
      footer: KoryFooter(
        children: [
          if (item != 'WALLET')
            KoryButton(
              icon: Icons.photo_camera_outlined,
              label: l.courierRetake(itemLabel),
              busy: _busy,
              onPressed: _retake,
            ),
          TextButton(
            onPressed: () => launchUrl(Uri.parse('mailto:support@pokou.app')),
            child: Text(l.courierContactSupport),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HonamRoundIcon(
            icon: Icons.warning_amber_rounded,
            color: AppColors.securityWarning,
          ),
          const SizedBox(height: 12),
          Text(l.courierCouldNotVerify, style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.courierToRedo,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                Text(
                  itemLabel,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (status.incompleteReason != null)
                  Text(
                    status.incompleteReason!,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          KorySection(l.courierAlreadyValidated),
          KoryCard(
            child: Column(
              children: [
                for (final line in validated)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 18, color: AppColors.feedbackSuccess),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.courierApplicationOpen30,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 17. Candidature acceptée ──

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final name = ref.watch(authControllerProvider).user?.fullName?.split(' ').first ?? '';
    final wallet = KoryWallet.of(status.walletPhone);
    return KoryPage(
      title: l.courierWelcomeTitle,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.courierGoToMode,
            onPressed: () async {
              await ref.read(honamRepositoryProvider).courierPost('welcomed');
              ref.invalidate(courierStatusProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HonamRoundIcon(icon: Icons.check, color: AppColors.feedbackSuccess),
          const SizedBox(height: 12),
          Text(l.courierWelcomeBody(name), style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          KoryNotice(
            tone: KoryTone.warning,
            title: status.launchPeriod ? null : l.courierTrialOffered(status.trialRides),
            icon: Icons.card_giftcard_outlined,
            text: status.launchPeriod ? l.honamLaunch : l.courierTrialOfferedBody,
          ),
          const SizedBox(height: 12),
          _ProfileCard(status: status, wallet: wallet),
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.courierReminder),
        ],
      ),
    );
  }
}

/// Zones, créneaux et wallet du coursier.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.status, required this.wallet});

  final CourierStatus status;
  final KoryWallet? wallet;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final days = courierDaysLabel(l, status.days);
    return KoryCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          HonamLinkRow(
            icon: Icons.map_outlined,
            title: l.courierZones,
            trailing: Flexible(child: _Value(status.zonesList.join(', '))),
          ),
          Divider(height: 1, color: AppColors.border),
          HonamLinkRow(
            icon: Icons.schedule,
            title: l.courierSlots,
            trailing: Flexible(child: _Value(days)),
          ),
          Divider(height: 1, color: AppColors.border),
          HonamLinkRow(
            icon: Icons.account_balance_wallet_outlined,
            title: l.courierWallet,
            trailing: Flexible(child: _Value(wallet?.shortLabel ?? '')),
          ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.end,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
  );
}

/// « Lun.–sam. » : les jours choisis, en abrégé.
String courierDaysLabel(L l, List<String> days) {
  final labels = {
    'MON': l.courierMon,
    'TUE': l.courierTue,
    'WED': l.courierWed,
    'THU': l.courierThu,
    'FRI': l.courierFri,
    'SAT': l.courierSat,
    'SUN': l.courierSun,
  };
  return days.map((d) => labels[d] ?? d).join(' ');
}

// ── 21. Compte coursier suspendu ──

final _defaultsProvider = FutureProvider.autoDispose<List<CourierDefault>>(
  (ref) => ref.watch(honamRepositoryProvider).defaults(),
);

class _Suspended extends ConsumerStatefulWidget {
  const _Suspended({required this.status});

  final CourierStatus status;

  @override
  ConsumerState<_Suspended> createState() => _SuspendedState();
}

class _SuspendedState extends ConsumerState<_Suspended> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final defaults = ref.watch(_defaultsProvider).valueOrNull ?? const [];
    final requested = widget.status.reviewRequested;
    return KoryPage(
      title: l.courierSuspendedTitle,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: requested ? l.courierReviewRequested : l.courierRequestReview,
            busy: _busy,
            onPressed: requested
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref.read(honamRepositoryProvider).courierPost('review-request');
                      ref.invalidate(courierStatusProvider);
                    } catch (_) {
                      if (context.mounted) koryFailed(context);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.courierBackToPokou),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HonamRoundIcon(icon: Icons.block, color: AppColors.securityCritical),
          const SizedBox(height: 12),
          Text(
            l.courierSuspendedLead(widget.status.defaultsCount),
            style: TextStyle(color: AppColors.textPrimary),
          ),
          if (defaults.isNotEmpty) ...[
            const SizedBox(height: 12),
            KoryCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, d) in defaults.indexed) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              koryDay(context, d.createdAt),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.securityCritical,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              [d.reason, if (d.pharmacyName != null) d.pharmacyName!].join(' · '),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.courierReviewNotice),
          const SizedBox(height: 10),
          Text(
            l.courierSuspensionScope,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 8. Mode coursier ──

class _CourierMode extends ConsumerStatefulWidget {
  const _CourierMode({required this.status});

  final CourierStatus status;

  @override
  ConsumerState<_CourierMode> createState() => _CourierModeState();
}

class _CourierModeState extends ConsumerState<_CourierMode> {
  bool _busy = false;

  Future<void> _setAvailable(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .courierPost('availability', body: {'available': value});
      ref.invalidate(courierStatusProvider);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(courierStatusProvider);
    ref.invalidate(courierRidesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final status = widget.status;
    final name = ref.watch(authControllerProvider).user?.fullName ?? '';
    final rides = ref.watch(courierRidesProvider).valueOrNull;
    final green = AppColors.feedbackSuccess;
    final subtitle = [
      if (name.isNotEmpty) name,
      if (status.transport != null) honamTransportLabel(l, status.transport),
      if (status.zonesList.isNotEmpty) status.zonesList.join(', '),
    ].join(' · ');
    final mine = [
      for (final o in rides?.mine ?? const <HonamOrder>[])
        if (o.status != 'DELIVERED' || !o.courierPaid) o,
    ];
    final active = [
      for (final o in mine)
        if (o.status == 'READY' || o.status == 'IN_DELIVERY') o.id,
    ];
    final ended = status.status == 'ENDED' && !status.launchPeriod;
    return KoryPage(
      title: l.honamCourierMode,
      subtitle: subtitle,
      actions: [
        IconButton(
          tooltip: status.available ? l.courierGoOffline : l.courierGoOnline,
          icon: Icon(
            Icons.power_settings_new,
            color: status.available ? green : AppColors.textMuted,
          ),
          onPressed: _busy || ended ? null : () => _setAvailable(!status.available),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            CourierLocationBeacon(orderIds: active),
            if (status.unacknowledgedDefault case final d?) ...[
              KoryNotice(
                tone: KoryTone.danger,
                title: l.courierDefaultTitle,
                text: d.reason,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourierDefaultScreen(
                          item: d,
                          count: status.defaultsCount,
                          max: status.maxDefaults,
                        ),
                      ),
                    ),
                    child: Text(l.courierSeeDefault),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (ended)
              _TrialEndCard(status: status)
            else
              KoryCard(
                color: status.available
                    ? green.withValues(alpha: AppColors.isDark ? 0.18 : 0.10)
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.available ? l.courierAvailable : l.courierUnavailable,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: status.available ? green : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            status.available
                                ? l.courierAvailableBody
                                : l.courierUnavailableBody,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: status.available,
                      activeTrackColor: green,
                      onChanged: _busy ? null : _setAvailable,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (status.launchPeriod)
              KoryNotice(tone: KoryTone.success, text: l.honamLaunch)
            else if (status.unlimited)
              KoryNotice(tone: KoryTone.success, text: l.honamUnlimited)
            else if (status.packRides != null)
              _PackBar(status: status),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CourierEarningsScreen()),
                    ),
                    child: CourierTile(
                      label: l.courierMonthEarnings,
                      value: formatFcfa(status.monthEarnings),
                      caption: l.courierPaidRides(status.monthPaidRides),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CourierTile(
                    label: l.courierDefaults,
                    value: l.courierCountOf(status.defaultsCount, status.maxDefaults),
                  ),
                ),
              ],
            ),
            for (final original in status.originalsToReturn) ...[
              const SizedBox(height: 10),
              KoryCard(
                child: KoryPersonRow(
                  name: l.courierOriginalToReturn,
                  subtitle: [
                    if (original.pharmacy != null) original.pharmacy!,
                    if (original.dueAt != null)
                      l.courierBefore(honamWhen(context, original.dueAt!)),
                  ].join(' · '),
                  trailing: Icon(Icons.description_outlined, color: AppColors.textSecondary),
                ),
              ),
            ],
            if (status.referralCode != null) ...[
              const SizedBox(height: 10),
              KoryCard(
                padding: EdgeInsets.zero,
                child: HonamLinkRow(
                  icon: Icons.card_giftcard_outlined,
                  title: l.courierInviteTitle,
                  subtitle: l.courierInviteSubtitle(status.referralGiftRides),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CourierReferralScreen(status: status)),
                  ),
                ),
              ),
            ],
            if (status.status == 'MEMBER' || status.status == 'TRIAL') ...[
              const SizedBox(height: 10),
              KoryCard(
                padding: EdgeInsets.zero,
                child: HonamLinkRow(
                  icon: Icons.inventory_2_outlined,
                  title: l.honamPacks,
                  subtitle: status.currentPack == null
                      ? null
                      : status.packs.where((p) => p.code == status.currentPack).firstOrNull?.label,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CourierPacksScreen(status: status)),
                  ),
                ),
              ),
            ],
            if (mine.isNotEmpty) ...[
              KorySection(l.honamMyRides),
              for (final order in mine) _MyRideRow(order: order, onChanged: _refresh),
            ],
            if (!ended && (rides?.available.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              for (final order in rides!.available)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.accentPrimaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                      title: Text(
                        l.courierNewRideNearby,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${order.pharmacy?.name ?? ''} · ${formatFcfa(order.deliveryPrice ?? 0)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourierIncomingRideScreen(order: order),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// « Essai : 3 courses restantes sur 5 · jusqu'au 30 nov. »
class _PackBar extends StatelessWidget {
  const _PackBar({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = status.packRides ?? 1;
    final until = status.status == 'TRIAL' ? status.trialEndsAt : status.packUntil;
    final label = status.status == 'TRIAL'
        ? l.courierTrialLeft(status.ridesLeft, total)
        : l.courierPackLeft(
            status.packs.where((p) => p.code == status.currentPack).firstOrNull?.label ?? '',
            status.ridesLeft,
            total,
          );
    return KoryCard(
      color: AppColors.securityWarning.withValues(alpha: 0.10),
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (until != null)
                Text(
                  l.courierUntil(koryDay(context, until)),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (status.ridesLeft / total).clamp(0.0, 1.0),
            color: AppColors.accentPrimaryDark,
            backgroundColor: AppColors.surfaceElevated,
          ),
        ],
      ),
    );
  }
}

class _MyRideRow extends ConsumerWidget {
  const _MyRideRow({required this.order, required this.onChanged});

  final HonamOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final paidPending = order.status == 'DELIVERED' && !order.courierPaid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KoryCard(
        padding: EdgeInsets.zero,
        child: HonamLinkRow(
          icon: Icons.delivery_dining_outlined,
          title: '${order.pharmacy?.name ?? ''} › ${order.deliveryAddress}',
          subtitle: paidPending ? l.courierAwaitingPayment : honamStatusLabel(l, order.status),
          trailing: paidPending
              ? TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(honamRepositoryProvider).rideAction(order.id, 'paid');
                      HapticFeedback.lightImpact();
                      onChanged();
                    } catch (_) {
                      if (context.mounted) koryFailed(context);
                    }
                  },
                  child: Text(l.honamCoursePaid),
                )
              : null,
          onTap: paidPending
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CourierDeliveryScreen(orderId: order.id)),
                ),
        ),
      ),
    );
  }
}

// ── 12. Fin de l'essai ──

class _TrialEndCard extends StatelessWidget {
  const _TrialEndCard({required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryCard(
      padding: EdgeInsets.zero,
      child: HonamLinkRow(
        icon: Icons.flag_outlined,
        title: l.honamTrialEnded,
        subtitle: l.courierChooseYourPack,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CourierTrialEndScreen(status: status)),
        ),
      ),
    );
  }
}

class CourierTrialEndScreen extends ConsumerWidget {
  const CourierTrialEndScreen({super.key, required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final earnings = ref.watch(_earningsProvider(null)).valueOrNull;
    final recommended = status.packs.where((p) => p.code == status.recommendedPack).firstOrNull;
    final others = [
      for (final p in status.packs)
        if (p.code != status.recommendedPack) p,
    ];
    int ttc(int ht) => (ht * (1 + status.vatRate)).round();
    final membershipTtc = ttc(status.membershipPriceHt);
    return KoryPage(
      title: l.courierTrialEndTitle,
      footer: KoryFooter(
        children: [
          if (recommended != null)
            KoryButton(
              label: l.courierChoosePack(recommended.label),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourierPacksScreen(status: status, preselect: recommended.code),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CourierPacksScreen(status: status)),
            ),
            child: Text(l.courierSeeAllPacks),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (earnings != null)
            KoryCard(
              color: AppColors.feedbackSuccess.withValues(alpha: 0.10),
              borderColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.courierThisMonth, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    l.courierEarned(formatFcfa(earnings.earnings)),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.feedbackSuccess,
                    ),
                  ),
                  Text(
                    l.courierRidesAndDefaults(earnings.rides, earnings.defaults),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          if (recommended != null) ...[
            KorySection(l.courierPackForYou),
            KoryCard(
              borderColor: AppColors.accentPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.courierPackRides(recommended.label, recommended.rides ?? 0),
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                      HonamPill(l.courierRecommended),
                    ],
                  ),
                  Text(
                    l.courierMembershipAndPackTtc(formatFcfa(membershipTtc + ttc(recommended.priceHt))),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KoryCard(
                child: KoryLine(
                  p.rides == null ? '${p.label} · ${l.honamUnlimited}' : l.courierPackRides(p.label, p.rides!),
                  l.courierTtc(formatFcfa(ttc(p.priceHt))),
                  caption: p.code == 'QUEEN' && !status.queenUnlocked ? l.honamQueenLocked : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 13. Adhésion et pack ──

class CourierPacksScreen extends ConsumerStatefulWidget {
  const CourierPacksScreen({super.key, required this.status, this.preselect});

  final CourierStatus status;
  final String? preselect;

  @override
  ConsumerState<CourierPacksScreen> createState() => _CourierPacksScreenState();
}

class _CourierPacksScreenState extends ConsumerState<CourierPacksScreen> {
  late String? _pack = widget.preselect ?? widget.status.recommendedPack;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final status = widget.status;
    int ttc(int ht) => (ht * (1 + status.vatRate)).round();
    final member = status.status == 'MEMBER';
    final pack = status.packs.where((p) => p.code == _pack).firstOrNull;
    final membership = member ? 0 : ttc(status.membershipPriceHt);
    final packTtc = pack == null ? 0 : ttc(member ? pack.upgradePriceHt : pack.priceHt);
    final repository = ref.read(honamRepositoryProvider);
    return KoryPage(
      title: 'Win Pokou',
      subtitle: l.courierMembershipAndPackOf(koryMonth(context, DateTime.now())),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: member
                ? l.courierPayByCashPay(formatFcfa(packTtc))
                : l.honamPayMembership,
            onPressed: member
                ? (pack == null || pack.code == status.currentPack
                      ? null
                      : () => openPayment(
                          context,
                          repository.pay('/honam/courier/pack', body: {'pack': pack.code}),
                        ))
                : () => openPayment(context, repository.pay('/honam/courier/membership')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final p in status.packs)
            KoryChoice(
              selected: _pack == p.code,
              title: p.rides == null
                  ? '${p.label} · ${l.honamUnlimited}'
                  : l.courierPackRides(p.label, p.rides!),
              subtitle: [
                l.courierHt(formatFcfa(member ? p.upgradePriceHt : p.priceHt)),
                l.courierTtc(formatFcfa(ttc(member ? p.upgradePriceHt : p.priceHt))),
                if (p.code == 'QUEEN')
                  status.queenUnlocked ? l.courierQueenUnlocked : l.honamQueenLocked,
              ].join(' · '),
              onTap: p.code == 'QUEEN' && !status.queenUnlocked
                  ? () {}
                  : () => setState(() => _pack = p.code),
            ),
          KoryCard(
            child: Column(
              children: [
                if (!member)
                  KoryLine(l.courierMembershipLine, l.courierTtc(formatFcfa(membership))),
                if (pack != null) KoryLine(l.courierPackLine(pack.label), l.courierTtc(formatFcfa(packTtc))),
                KoryLine(l.honamPTotalToPay, l.courierTtc(formatFcfa(membership + packTtc)), strong: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.honamPriceNote),
          if (!member) ...[
            const SizedBox(height: 8),
            KoryNotice(icon: Icons.info_outline, text: l.courierMembershipFirst),
          ],
        ],
      ),
    );
  }
}

// ── 22. Mes courses et gains ──

final _earningsProvider = FutureProvider.autoDispose.family<CourierEarnings, String?>(
  (ref, month) => ref.watch(honamRepositoryProvider).earnings(month: month),
);

class CourierEarningsScreen extends ConsumerStatefulWidget {
  const CourierEarningsScreen({super.key});

  @override
  ConsumerState<CourierEarningsScreen> createState() => _CourierEarningsScreenState();
}

class _CourierEarningsScreenState extends ConsumerState<CourierEarningsScreen> {
  String? _month;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(_earningsProvider(_month));
    final data = async.valueOrNull;
    final wallet = KoryWallet.of(data?.walletPhone);
    return KoryPage(
      title: l.courierEarningsTitle,
      loading: data == null && !async.hasError,
      body: data == null
          ? KoryNotice(tone: KoryTone.danger, text: l.honamFailed)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (data.months.length > 1)
                  SegmentedButton<String>(
                    segments: [
                      for (final m in data.months.take(3))
                        ButtonSegment(
                          value: m,
                          label: Text(koryMonth(context, DateTime.parse('$m-01'))),
                        ),
                    ],
                    selected: {data.month},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _month = s.first),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: CourierTile(label: l.courierRides, value: '${data.rides}')),
                    const SizedBox(width: 8),
                    Expanded(child: CourierTile(label: l.courierGains, value: formatFcfa(data.earnings))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CourierTile(
                        label: l.courierDefaults,
                        value: l.courierCountOf(data.defaults, data.maxDefaults),
                      ),
                    ),
                  ],
                ),
                if (data.packRides != null) ...[
                  const SizedBox(height: 10),
                  KoryCard(
                    color: AppColors.securityWarning.withValues(alpha: 0.10),
                    borderColor: Colors.transparent,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        KoryLine(
                          data.currentPack == 'TRIAL' ? l.courierTrial : l.courierPackLine(data.currentPack ?? ''),
                          l.courierRidesLeftOf(data.ridesLeft, data.packRides!),
                        ),
                        LinearProgressIndicator(
                          value: (data.ridesLeft / data.packRides!).clamp(0.0, 1.0),
                          color: AppColors.accentPrimaryDark,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (data.items.isEmpty)
                  KoryNotice(text: l.honamNoRides)
                else
                  KoryCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, item) in data.items.indexed) ...[
                          if (i > 0) Divider(height: 1, color: AppColors.border),
                          ListTile(
                            title: Text(
                              '${item.pharmacy ?? ''} › ${item.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(honamWhen(context, item.deliveredAt)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatFcfa(item.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                                HonamPill(
                                  item.paid ? l.courierPaid : l.courierPending,
                                  background: (item.paid ? AppColors.feedbackSuccess : AppColors.securityWarning)
                                      .withValues(alpha: 0.14),
                                  ink: AppColors.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  l.courierEarningsNote(wallet?.label ?? ''),
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}

// ── 15. Parrainage ──

final _referralsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(honamRepositoryProvider).referrals(),
);

class CourierReferralScreen extends ConsumerWidget {
  const CourierReferralScreen({super.key, required this.status});

  final CourierStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final code = status.referralCode ?? '';
    final link = courierInviteLink(code);
    final friends = ref.watch(_referralsProvider).valueOrNull?.items ?? const [];
    final qr = Barcode.qrCode().toSvg(link, width: 140, height: 140);
    return KoryPage(
      title: l.courierInviteTitle,
      footer: KoryFooter(
        children: [
          KoryButton(
            icon: Icons.person_add_alt_1_outlined,
            label: l.courierProposeToFriend,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CourierInviteFriendScreen(code: code)),
            ),
          ),
          TextButton.icon(
            onPressed: () => Share.share(l.courierInviteMessage(code, link)),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(l.courierShareLink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryCard(
            child: Row(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(6),
                  child: SvgPicture.string(qr, width: 120, height: 120),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.courierYourCode, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      SelectableText(
                        code,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(l.courierShowOrShare, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(
            tone: KoryTone.warning,
            icon: Icons.card_giftcard_outlined,
            text: l.courierGiftNotice(status.referralGiftRides),
          ),
          KorySection(l.courierYourReferrals),
          if (friends.isEmpty)
            KoryNotice(text: l.courierNoReferrals)
          else
            KoryCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final f in friends)
                    KoryPersonRow(
                      name: f.name ?? '—',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            f.gift == null ? '—' : l.courierPlusRides(f.gift!),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          HonamPill(switch (f.state) {
                            'FIRST_DELIVERY' => l.courierFirstDeliveryDone,
                            'ACTIVE' => l.courierFriendActive,
                            'DECLINED' => l.courierFriendDeclined,
                            _ => l.courierFriendApplying,
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 23. Proposer à un ami ──

/// Le coursier écrit son message et l'envoie par le partage du téléphone
/// (SMS, Pokou, WhatsApp…). La carte « Devenir coursier Honam » dans la
/// messagerie Pokou n'est pas encore faite : le lien en tient lieu.
class CourierInviteFriendScreen extends StatefulWidget {
  const CourierInviteFriendScreen({super.key, required this.code});

  final String code;

  @override
  State<CourierInviteFriendScreen> createState() => _CourierInviteFriendScreenState();
}

class _CourierInviteFriendScreenState extends State<CourierInviteFriendScreen> {
  TextEditingController? _controller;

  /// Le texte de départ, posé une seule fois ; le coursier le modifie.
  TextEditingController get _message => _controller ??=
      TextEditingController(text: L.of(context).courierFriendMessage(widget.code));

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final link = courierInviteLink(widget.code);
    return KoryPage(
      title: l.courierProposeToFriend,
      subtitle: l.courierYourCodeIs(widget.code),
      footer: KoryFooter(
        children: [
          KoryButton(
            icon: Icons.send_outlined,
            label: l.courierSendInvite,
            onPressed: () => Share.share('${_message.text.trim()}\n$link'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) koryToast(context, l.koryCopied);
            },
            icon: const Icon(Icons.link, size: 18),
            label: Text(l.courierCopyLink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KorySection(l.courierYourMessage),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          KoryNotice(icon: Icons.info_outline, text: l.courierFriendNotice),
        ],
      ),
    );
  }
}
