import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_ui.dart';

/// L'offre coursier, lue à l'ouverture ; avec le code d'un parrain, elle
/// dit qui invite (maquette Coursiers 25).
final courierOfferProvider = FutureProvider.autoDispose
    .family<CourierOffer, String?>(
      (ref, code) =>
          ref.watch(honamRepositoryProvider).courierOffer(code: code),
    );

/// Où l'offre apparaît (maquette Coursiers 0) : le bandeau de l'onglet
/// Honam et l'encart après une livraison reçue. Seulement à qui n'est pas
/// coursier, là où Honam est ouvert, et jamais après « Ne plus me
/// proposer ».
class CourierOfferPrompt extends ConsumerWidget {
  const CourierOfferPrompt({super.key, this.deliveredBy});

  /// Après une livraison : « Livrée par Kodjo à 10 h 31 ».
  final String? deliveredBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final courier = ref.watch(courierStatusProvider);
    final offer = ref.watch(courierOfferProvider(null)).valueOrNull;
    if (!courier.hasValue ||
        courier.value != null ||
        offer == null ||
        !offer.honamOpen ||
        offer.servedCities.isEmpty ||
        offer.dismissed) {
      return const SizedBox.shrink();
    }
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CourierOfferScreen()));
    if (deliveredBy == null) {
      return KoryCard(
        padding: EdgeInsets.zero,
        child: HonamLinkRow(
          icon: Icons.two_wheeler,
          title: l.courierBannerTitle,
          onTap: open,
          trailing: Text(
            l.courierDiscover,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.accentPrimaryDark,
            ),
          ),
        ),
      );
    }
    return KoryNotice(
      tone: KoryTone.success,
      icon: Icons.two_wheeler,
      text: l.courierAfterDelivery(deliveredBy!),
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: open, child: Text(l.courierLearnMore)),
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(honamRepositoryProvider).dismissCourierOffer();
                  ref.invalidate(courierOfferProvider(null));
                } catch (_) {
                  if (context.mounted) koryFailed(context);
                }
              },
              child: Text(l.courierDontPropose),
            ),
          ],
        ),
      ],
    );
  }
}

/// « Livre pour Honam » (maquettes Coursiers 1 et 25) : ce qu'une course
/// rapporte, un simulateur, ce que ça coûte et ce qu'il faut. Avec un code
/// de parrainage, le parrain est nommé en tête et le code appliqué.
class CourierOfferScreen extends ConsumerStatefulWidget {
  const CourierOfferScreen({super.key, this.referralCode});

  final String? referralCode;

  @override
  ConsumerState<CourierOfferScreen> createState() => _CourierOfferScreenState();
}

class _CourierOfferScreenState extends ConsumerState<CourierOfferScreen> {
  double _ridesPerMonth = 20;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(courierOfferProvider(widget.referralCode));
    final offer = async.valueOrNull;
    final city = offer?.servedCities.firstOrNull;
    return KoryPage(
      title: l.courierOfferTitle,
      subtitle: city == null ? null : l.courierOfferCityOpen(city),
      loading: offer == null && !async.hasError,
      footer: offer == null
          ? null
          : KoryFooter(
              children: [
                KoryButton(
                  label: l.courierBecome,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CourierJoinScreen(
                        offer: offer,
                        referralCode: offer.inviterCode,
                      ),
                    ),
                  ),
                ),
                if (widget.referralCode != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l.courierNotNow),
                  ),
              ],
            ),
      body: offer == null
          ? KoryNotice(tone: KoryTone.danger, text: l.honamFailed)
          : _body(l, offer),
    );
  }

  Widget _body(L l, CourierOffer offer) {
    // Prix inconnu : on ne montre ni « 0 FCFA » ni une estimation fausse.
    final knownPrice = offer.deliveryPrice;
    final price = knownPrice ?? 0;
    final rides = _ridesPerMonth.round();
    // Le pack qui couvre ce rythme : le premier qui a assez de courses.
    final pack =
        offer.packs
            .where((p) => p.rides == null || p.rides! >= rides)
            .firstOrNull ??
        offer.packs.lastOrNull;
    final cost = offer.launchPeriod || pack == null
        ? 0
        : offer.membershipPriceTtc + pack.priceTtc;
    final green = AppColors.feedbackSuccess;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (offer.inviterName != null) ...[
          KoryCard(
            color: green.withValues(alpha: AppColors.isDark ? 0.18 : 0.08),
            borderColor: Colors.transparent,
            child: KoryPersonRow(
              name: l.courierInvitedBy(offer.inviterName!),
              subtitle: offer.inviterVerified
                  ? l.courierInviterCodeApplied(offer.inviterCode ?? '')
                  : l.courierInviteCodeApplied(offer.inviterCode ?? ''),
              trailing: Icon(Icons.check, color: green),
            ),
          ),
          const SizedBox(height: 12),
        ],
        KoryCard(
          color: green.withValues(alpha: AppColors.isDark ? 0.18 : 0.08),
          borderColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.courierYouEarn,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                knownPrice == null ? '—' : l.courierPerRide(formatFcfa(price)),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
              Text(
                l.courierPaidByPharmacy,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Coursiers 25 · L'ami invité : les trois avantages, ce qu'il faut,
        // puis ce que le mode coursier coûte après l'essai.
        if (offer.inviterName != null) ...[
          _InvitedPerks(offer: offer),
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.courierInviteNeeds),
          KorySection(l.courierWhatItCosts),
          _costs(l, offer),
        ] else if (knownPrice != null) ...[
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.courierHowMuch,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      l.courierRidesPerMonth(rides),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _ridesPerMonth,
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '$rides',
                  onChanged: (v) => setState(() => _ridesPerMonth = v),
                ),
                KoryLine(l.courierRides, formatFcfa(price * rides)),
                if (pack != null && !offer.launchPeriod)
                  KoryLine(
                    l.courierMembershipAndPack(pack.label),
                    '−${formatFcfa(cost)}',
                  ),
                KoryLine(
                  l.courierNetForYou,
                  formatFcfa(price * rides - cost),
                  strong: true,
                ),
              ],
            ),
          ),
          KorySection(l.courierWhatItCosts),
          _costs(l, offer),
          KorySection(l.courierYouNeed),
          for (final need in [
            l.courierNeedAge,
            l.courierNeedVehicle,
            l.courierNeedPhone,
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      need,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// L'essai, Win Pokou ensuite, et la période de lancement.
  Widget _costs(L l, CourierOffer offer) => KoryCard(
    child: Column(
      children: [
        KoryLine(
          l.courierTrial,
          l.courierTrialRides(offer.trialRides),
          caption: l.courierTrialCaption,
        ),
        KoryLine(
          l.courierThenWinPokou,
          l.courierFromPerMonth(formatFcfa(offer.membershipPriceTtc)),
          caption: l.courierThenWinPokouCaption,
        ),
        KoryLine(
          l.courierLaunchLine,
          l.courierFree,
          caption: l.courierLaunchCaption,
        ),
      ],
    ),
  );
}

/// Les trois avantages de l'ami invité (maquette Coursiers 25) : les
/// courses d'essai, des premières courses simples, et la recommandation
/// du parrain, qui reçoit des courses offertes.
class _InvitedPerks extends StatelessWidget {
  const _InvitedPerks({required this.offer});

  final CourierOffer offer;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final inviter = offer.inviterName!.trim().split(RegExp(r'\s+')).first;
    return KoryCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          _Perk(
            icon: Icons.check,
            title: l.courierTrialOffered(offer.trialRides),
            caption: l.courierInviteTrialCaption,
          ),
          _Perk(
            icon: Icons.two_wheeler,
            title: l.courierInviteSimpleRides,
            caption: l.courierInviteSimpleRidesCaption,
          ),
          _Perk(
            icon: Icons.group_outlined,
            title: l.courierInviteRecommended(inviter),
            caption: l.courierInviteRecommendedCaption(offer.giftRides),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.title, required this.caption});

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.terracottaTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.onTerracottaTint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// « Honam n'est pas encore à {ville} » (maquette Coursiers 16).
class CourierWaitlistScreen extends ConsumerStatefulWidget {
  const CourierWaitlistScreen({super.key, required this.city});

  final String city;

  @override
  ConsumerState<CourierWaitlistScreen> createState() =>
      _CourierWaitlistScreenState();
}

class _CourierWaitlistScreenState extends ConsumerState<CourierWaitlistScreen> {
  int? _count;
  bool _joined = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(honamRepositoryProvider).waitlistCount(widget.city).then((count) {
      if (mounted) setState(() => _count = count);
    }, onError: (_) {});
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).joinWaitlist(widget.city);
      final count = await ref
          .read(honamRepositoryProvider)
          .waitlistCount(widget.city);
      if (mounted) {
        setState(() {
          _joined = true;
          _count = count;
        });
      }
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryPage(
      title: l.courierOfferTitle,
      subtitle: widget.city,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: _joined ? l.courierWaitlistJoined : l.courierNotifyMe,
            busy: _busy,
            onPressed: _joined ? null : _join,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HonamRoundIcon(
            icon: Icons.location_on_outlined,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(height: 12),
          Text(
            l.courierNotYetIn(widget.city),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.courierNotYetBody(widget.city),
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          if (_count != null) ...[
            const SizedBox(height: 16),
            KoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_count',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    l.courierPeopleWaiting(widget.city),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.courierWaitlistHelps),
        ],
      ),
    );
  }
}

/// L'inscription coursier en 6 étapes (maquettes Coursiers 2 à 7).
class CourierJoinScreen extends ConsumerStatefulWidget {
  const CourierJoinScreen({super.key, required this.offer, this.referralCode});

  final CourierOffer offer;
  final String? referralCode;

  @override
  ConsumerState<CourierJoinScreen> createState() => _CourierJoinScreenState();
}

class _CourierJoinScreenState extends ConsumerState<CourierJoinScreen> {
  static const _steps = 6;
  int _step = 1;
  bool _busy = false;

  // 1. Avant de commencer
  DateTime? _birth;
  String? _city;
  String _transport = 'MOTO';
  // 2. Identité
  String _docType = 'CNI';
  int? _front;
  int? _back;
  int? _selfie;
  // 3. Zones et créneaux
  final _zoneField = TextEditingController();
  final List<String> _zones = [];
  final Set<String> _days = {};
  final Set<String> _moments = {};
  // 4. Wallet
  late final _wallet = TextEditingController(
    text: ref.read(authControllerProvider).user?.phone ?? '',
  );
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _walletVerified = false;
  // 5. Règles d'or : le quiz
  int _question = 0;
  int? _answer;
  bool _quizDone = false;

  @override
  void initState() {
    super.initState();
    _city = widget.offer.servedCities.firstOrNull;
  }

  @override
  void dispose() {
    _zoneField.dispose();
    _wallet.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _adult {
    final birth = _birth;
    if (birth == null) return false;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age >= 18;
  }

  bool get _canContinue => switch (_step) {
    1 => _adult && _city != null,
    2 =>
      _front != null &&
          (_docType == 'PASSPORT' || _back != null) &&
          _selfie != null,
    3 => _zones.isNotEmpty && _days.isNotEmpty && _moments.isNotEmpty,
    4 => _walletVerified,
    5 => _quizDone,
    _ => true,
  };

  Future<int?> _shoot({bool selfie = false}) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (photo == null) return null;
    setState(() => _busy = true);
    try {
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: await photo.readAsBytes(),
            filename: selfie ? 'selfie.jpg' : 'piece.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
            memoriser: false,
          );
      return upload.id;
    } catch (_) {
      if (mounted) koryFailed(context);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .walletSendCode(_wallet.text.trim());
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (error) {
      if (mounted) koryToast(context, error.message);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode(String code) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .walletVerify(_wallet.text.trim(), code);
      if (mounted) setState(() => _walletVerified = true);
    } on ApiException catch (error) {
      _code.clear();
      if (mounted) koryToast(context, error.message);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .courierJoin(
            walletPhone: _wallet.text.trim(),
            zones: _zones,
            city: _city,
            referralCode: widget.referralCode,
            birthDate: _birth,
            transport: _transport,
            idDocType: _docType,
            idFrontMediaId: _front,
            idBackMediaId: _back,
            selfieMediaId: _selfie,
            days: [
              for (final d in _dayCodes)
                if (_days.contains(d)) d,
            ],
            moments: [
              for (final m in _momentCodes)
                if (_moments.contains(m)) m,
            ],
            quizPassed: _quizDone,
          );
      ref.invalidate(courierStatusProvider);
      if (mounted) setState(() => _step = _steps);
    } on ApiException catch (error) {
      if (mounted) koryToast(context, error.message);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _momentCodes = ['MORNING', 'NOON', 'AFTERNOON', 'EVENING'];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final titles = [
      l.courierStepBefore,
      l.courierStepIdentity,
      l.courierStepZones,
      l.courierStepWallet,
      l.courierStepRules,
      l.courierStepSent,
    ];
    final last = _step == _steps;
    return PopScope(
      canPop: _step == 1 || last,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: KoryPage(
        title: titles[_step - 1],
        subtitle: l.courierStepOf(_step, _steps),
        footer: KoryFooter(
          children: [
            KoryButton(
              label: last
                  ? l.courierDone
                  : _step == 5
                  ? l.courierAcceptConditions
                  : l.courierContinue,
              busy: _busy,
              onPressed: last
                  ? () => Navigator.of(context).maybePop()
                  : _canContinue
                  ? _next
                  : null,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            HonamWizardBar(step: _step, total: _steps),
            const SizedBox(height: 16),
            ...switch (_step) {
              1 => _before(l),
              2 => _identity(l),
              3 => _zonesStep(l),
              4 => _walletStep(l),
              5 => _rules(l),
              _ => courierApplicationSteps(context, null, widget.offer),
            },
          ],
        ),
      ),
    );
  }

  // ── 2. Avant de commencer ──

  List<Widget> _before(L l) {
    final birth = _birth;
    return [
      KorySection(l.courierBirthDate),
      KoryCard(
        padding: EdgeInsets.zero,
        child: HonamLinkRow(
          icon: Icons.cake_outlined,
          title: birth == null
              ? l.courierChooseDate
              : MaterialLocalizations.of(context).formatCompactDate(birth),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: birth ?? DateTime(now.year - 25),
              firstDate: DateTime(now.year - 80),
              lastDate: now,
            );
            if (picked != null) setState(() => _birth = picked);
          },
        ),
      ),
      if (birth != null && !_adult) ...[
        const SizedBox(height: 8),
        KoryNotice(tone: KoryTone.danger, text: l.courierTooYoung),
      ],
      KorySection(l.honamCity),
      for (final city in widget.offer.servedCities)
        KoryChoice(
          selected: _city == city,
          title: city,
          subtitle: l.courierHonamOpen,
          onTap: () => setState(() => _city = city),
        ),
      KoryCard(
        padding: EdgeInsets.zero,
        child: HonamLinkRow(
          icon: Icons.add_location_alt_outlined,
          title: l.honamOtherCity,
          onTap: _otherCity,
        ),
      ),
      KorySection(l.courierHowDoYouDeliver),
      Row(
        children: [
          for (final (code, icon, label) in [
            ('MOTO', Icons.two_wheeler, l.courierTransportMotoTitle),
            ('VELO', Icons.pedal_bike, l.courierTransportBikeTitle),
            ('PIED', Icons.directions_walk, l.courierTransportWalkTitle),
          ]) ...[
            if (code != 'MOTO') const SizedBox(width: 8),
            Expanded(
              child: KoryCard(
                onTap: () => setState(() => _transport = code),
                borderColor: _transport == code
                    ? AppColors.accentPrimary
                    : null,
                color: _transport == code ? AppColors.terracottaTint : null,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                child: Column(
                  children: [
                    Icon(icon, color: AppColors.accentPrimaryDark),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.offer.transports[code] != null)
                      Text(
                        l.courierUpToKm(
                          widget.offer.transports[code]!.toStringAsFixed(
                            widget.offer.transports[code]! % 1 == 0 ? 0 : 1,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      KoryNotice(icon: Icons.info_outline, text: l.courierTransportNote),
    ];
  }

  Future<void> _otherCity() async {
    final l = L.of(context);
    final controller = TextEditingController();
    final city = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.honamYourCity),
        content: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: Text(l.courierContinue),
          ),
        ],
      ),
    );
    controller.dispose();
    if (city == null || city.length < 2 || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CourierWaitlistScreen(city: city)),
    );
  }

  // ── 3. Identité ──

  List<Widget> _identity(L l) {
    Widget shot(String label, int? id, VoidCallback onTap) => Expanded(
      child: KoryCard(
        onTap: onTap,
        color: id != null
            ? AppColors.feedbackSuccess.withValues(alpha: 0.10)
            : null,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(
              id != null ? Icons.badge_outlined : Icons.photo_camera_outlined,
              color: id != null
                  ? AppColors.feedbackSuccess
                  : AppColors.accentPrimaryDark,
            ),
            const SizedBox(height: 4),
            Text(
              id != null ? l.courierShotDone(label) : l.courierShoot(label),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
    return [
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'CNI', label: Text(l.courierDocCni)),
          ButtonSegment(value: 'PASSPORT', label: Text(l.courierDocPassport)),
          ButtonSegment(value: 'VOTER', label: Text(l.courierDocVoter)),
        ],
        selected: {_docType},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _docType = s.first),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          shot(l.courierFront, _front, () async {
            final id = await _shoot();
            if (id != null) setState(() => _front = id);
          }),
          if (_docType != 'PASSPORT') ...[
            const SizedBox(width: 10),
            shot(l.courierBack, _back, () async {
              final id = await _shoot();
              if (id != null) setState(() => _back = id);
            }),
          ],
        ],
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                final id = await _shoot(selfie: true);
                if (id != null) setState(() => _selfie = id);
              },
        icon: Icon(_selfie != null ? Icons.check : Icons.photo_camera_outlined),
        label: Text(
          _selfie != null ? l.courierSelfieDone : l.courierTakeSelfie,
        ),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
      const SizedBox(height: 12),
      KoryNotice(icon: Icons.info_outline, text: l.courierIdNameNotice),
      const SizedBox(height: 8),
      KoryNotice(icon: Icons.lock_outline, text: l.courierIdPrivacy),
    ];
  }

  // ── 4. Zones et créneaux ──

  List<Widget> _zonesStep(L l) {
    Widget chip(String label, bool selected, VoidCallback onTap) => FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.accentPrimaryDark,
      labelStyle: TextStyle(
        color: selected
            ? AppColors.actionButtonForeground
            : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
    final dayLabels = [
      l.courierMon,
      l.courierTue,
      l.courierWed,
      l.courierThu,
      l.courierFri,
      l.courierSat,
      l.courierSun,
    ];
    final momentLabels = [
      l.courierMorning,
      l.courierNoon,
      l.courierAfternoon,
      l.courierEvening,
    ];
    void addZone() {
      final zone = _zoneField.text.trim();
      if (zone.length >= 2 && !_zones.contains(zone)) {
        setState(() => _zones.add(zone));
      }
      _zoneField.clear();
    }

    return [
      KorySection(l.courierZonesTitle),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final zone in _zones)
            InputChip(
              label: Text(zone),
              onDeleted: () => setState(() => _zones.remove(zone)),
            ),
        ],
      ),
      TextField(
        contextMenuBuilder: pokouContextMenuBuilder,
        controller: _zoneField,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: l.courierAddZone,
          counterText: '',
          suffixIcon: IconButton(
            tooltip: l.courierAddZone,
            icon: const Icon(Icons.add),
            onPressed: addZone,
          ),
        ),
        onSubmitted: (_) => addZone(),
      ),
      KorySection(l.courierWhenAvailable),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, code) in _dayCodes.indexed)
            chip(dayLabels[i], _days.contains(code), () {
              setState(
                () =>
                    _days.contains(code) ? _days.remove(code) : _days.add(code),
              );
            }),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, code) in _momentCodes.indexed)
            chip(momentLabels[i], _moments.contains(code), () {
              setState(
                () => _moments.contains(code)
                    ? _moments.remove(code)
                    : _moments.add(code),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      KoryNotice(icon: Icons.info_outline, text: l.courierZonesNotice),
    ];
  }

  // ── 5. Wallet ──

  List<Widget> _walletStep(L l) => [
    TextField(
      contextMenuBuilder: pokouContextMenuBuilder,
      controller: _wallet,
      enabled: !_walletVerified,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(labelText: l.courierWalletNumber),
      onChanged: (_) => setState(() {
        _codeSent = false;
        _code.clear();
      }),
    ),
    const SizedBox(height: 10),
    if (!_walletVerified)
      OutlinedButton(
        onPressed: _busy || _wallet.text.trim().length < 8 ? null : _sendCode,
        child: Text(_codeSent ? l.courierResendCode : l.courierSendCode),
      ),
    if (_codeSent && !_walletVerified) ...[
      KorySection(l.courierSmsCode),
      HonamCodeBoxes(
        controller: _code,
        autofocus: true,
        onCompleted: _verifyCode,
      ),
    ],
    if (_walletVerified) ...[
      const SizedBox(height: 12),
      KoryNotice(tone: KoryTone.success, text: l.courierWalletVerified),
    ],
    const SizedBox(height: 12),
    KoryNotice(icon: Icons.info_outline, text: l.courierWalletNotice),
  ];

  // ── 6. Règles d'or ──

  List<Widget> _rules(L l) {
    final rules = [
      (Icons.lock_outline, l.courierRule1, l.courierRule1Body),
      (Icons.payments_outlined, l.courierRule2, l.courierRule2Body),
      (Icons.pin_outlined, l.courierRule3, l.courierRule3Body),
      (Icons.warning_amber_rounded, l.courierRule4, l.courierRule4Body),
    ];
    final quiz = [
      (l.courierQuiz1, [l.courierQuiz1Wrong, l.courierQuiz1Right]),
      (l.courierQuiz2, [l.courierQuiz2Wrong, l.courierQuiz2Right]),
      (l.courierQuiz3, [l.courierQuiz3Wrong, l.courierQuiz3Right]),
    ];
    // La bonne réponse est toujours la seconde, affichée dans cet ordre.
    const right = 1;
    final (question, answers) = quiz[_question];
    return [
      for (final (icon, title, body) in rules)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 6),
      KoryCard(
        child: _quizDone
            ? Text(
                l.courierQuizPassed,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.feedbackSuccess,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.courierQuestionOf(_question + 1, quiz.length),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    question,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final (index, answer) in answers.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KoryCard(
                        onTap: () {
                          setState(() => _answer = index);
                          if (index != right) return;
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (!mounted) return;
                            setState(() {
                              _answer = null;
                              if (_question + 1 < quiz.length) {
                                _question++;
                              } else {
                                _quizDone = true;
                              }
                            });
                          });
                        },
                        padding: const EdgeInsets.all(12),
                        borderColor: _answer == index
                            ? (index == right
                                  ? AppColors.feedbackSuccess
                                  : AppColors.securityCritical)
                            : null,
                        child: Row(
                          children: [
                            if (_answer == index)
                              Icon(
                                index == right ? Icons.check : Icons.close,
                                size: 18,
                                color: index == right
                                    ? AppColors.feedbackSuccess
                                    : AppColors.securityCritical,
                              ),
                            if (_answer == index) const SizedBox(width: 6),
                            Expanded(child: Text(answer)),
                          ],
                        ),
                      ),
                    ),
                  if (_answer != null && _answer != right)
                    Text(
                      l.courierQuizRetry,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.securityCritical,
                      ),
                    ),
                ],
              ),
      ),
    ];
  }
}

/// « Candidature envoyée » (maquette Coursiers 7) : le délai, la frise en
/// trois temps et l'encart des courses d'essai. Sert aussi à l'écran du
/// mode coursier tant que la candidature attend.
List<Widget> courierApplicationSteps(
  BuildContext context,
  CourierStatus? status,
  CourierOffer? offer,
) {
  final l = L.of(context);
  final applied = status?.appliedAt ?? DateTime.now();
  final steps = [
    (l.courierSentStep1, honamWhen(context, applied), true),
    (
      l.courierSentStep2,
      l.courierAtTheLatest(
        honamWhen(context, applied.add(const Duration(hours: 48))),
      ),
      false,
    ),
    (l.courierSentStep3, l.courierSentStep3Body, false),
  ];
  final launch = offer?.launchPeriod ?? false;
  return [
    HonamRoundIcon(icon: Icons.check, color: AppColors.feedbackSuccess),
    const SizedBox(height: 12),
    Text(
      l.courierSentBody,
      style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary),
    ),
    const SizedBox(height: 12),
    KoryCard(
      child: Column(
        children: [
          for (final (index, (title, subtitle, done)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.feedbackSuccess
                          : index == 1
                          ? AppColors.securityWarning.withValues(alpha: 0.18)
                          : AppColors.surfaceElevated,
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : index == 1
                        ? Icon(
                            Icons.history,
                            size: 16,
                            color: AppColors.securityWarning,
                          )
                        : Text('${index + 1}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
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
      text: launch
          ? l.honamLaunch
          : l.courierTrialWaiting(offer?.trialRides ?? status?.trialRides ?? 5),
    ),
  ];
}
