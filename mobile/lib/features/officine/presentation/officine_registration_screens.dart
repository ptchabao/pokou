import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_ui.dart';

/// « Référencer votre officine » en trois écrans (maquettes p.94 et p.95,
/// Officine 14, 15 et 16) : les informations et l'arrêté, la formule, puis
/// la vérification par le support. Rien n'est payé avant la validation :
/// la formule se règle ensuite par CashPay depuis l'espace officine.

/// Officine · 14. Référencer votre officine (étape 1 sur 3).
///
/// [initial] : le dossier refusé, repris pour être corrigé ; son motif
/// s'affiche en tête et son arrêté, déjà chez le support, peut resservir.
class OfficineRegistrationInfoScreen extends ConsumerStatefulWidget {
  const OfficineRegistrationInfoScreen({super.key, this.initial});

  final OfficineRegistration? initial;

  @override
  ConsumerState<OfficineRegistrationInfoScreen> createState() =>
      _OfficineRegistrationInfoScreenState();
}

class _OfficineRegistrationInfoScreenState
    extends ConsumerState<OfficineRegistrationInfoScreen> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late final _license = TextEditingController(
    text: widget.initial?.licenseNumber ?? '',
  );
  late final _wallet = TextEditingController(
    text: widget.initial?.walletPhone ?? '',
  );
  String? _filePath;
  String? _fileName;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _license.dispose();
    _wallet.dispose();
    super.dispose();
  }

  bool get _hasAuthorization =>
      _filePath != null || (widget.initial?.hasAuthorization ?? false);

  bool get _ready =>
      _name.text.trim().length >= 2 &&
      _address.text.trim().length >= 3 &&
      _license.text.trim().length >= 2 &&
      _wallet.text.replaceAll(RegExp(r'\D'), '').length >= 8 &&
      _hasAuthorization;

  /// L'arrêté : une photo de la galerie ou un PDF.
  Future<void> _pick() async {
    final l = L.of(context);
    final pdf = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(l.officineRegPickPhoto),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l.officineRegPickPdf),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (pdf == null) return;
    String? path;
    String? name;
    if (pdf) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      path = result?.files.single.path;
      name = result?.files.single.name;
    } else {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
      );
      path = photo?.path;
      name = photo?.name;
    }
    if (path == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _filePath = path;
      _fileName = name;
    });
  }

  Future<void> _continue() async {
    final draft = OfficineRegistrationDraft(
      name: _name.text.trim(),
      address: _address.text.trim(),
      licenseNumber: _license.text.trim(),
      walletPhone: _wallet.text.trim(),
      authorizationPath: _filePath,
      authorizationName: _fileName,
    );
    final sent = await Navigator.of(context).push<OfficineRegistration>(
      MaterialPageRoute(
        builder: (_) => OfficineRegistrationPlanScreen(
          draft: draft,
          initialPlan: widget.initial?.plan,
        ),
      ),
    );
    if (sent == null || !mounted) return;
    // Le dossier est parti : l'écran 3/3 prend la place du formulaire.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfficineRegistrationPendingScreen(registration: sent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final note = widget.initial?.reviewNote;
    return OfficinePage(
      title: l.officineRegInfoTitle,
      subtitle: l.officineRegStep(1),
      primary: HonamPrimaryButton(
        label: l.officineRegContinue,
        onPressed: _ready ? _continue : null,
      ),
      children: [
        if (widget.initial?.rejected ?? false)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModuleCallout(
              tone: CalloutTone.red,
              text: l.officineRegRejected(note ?? ''),
            ),
          ),
        _Field(
          label: l.officineRegName,
          controller: _name,
          onChanged: () => setState(() {}),
          maxLength: 160,
          capitalization: TextCapitalization.words,
        ),
        _Field(
          label: l.officineRegAddress,
          controller: _address,
          onChanged: () => setState(() {}),
          maxLength: 255,
          capitalization: TextCapitalization.sentences,
        ),
        _Field(
          label: l.officineRegLicense,
          hint: l.officineRegLicenseHint,
          controller: _license,
          onChanged: () => setState(() {}),
          maxLength: 64,
        ),
        _Field(
          label: l.officineRegWallet,
          hint: l.officineRegWalletHint,
          controller: _wallet,
          onChanged: () => setState(() {}),
          keyboardType: TextInputType.phone,
          maxLength: 20,
          help: l.officineRegWalletHelp,
        ),
        ModuleCard(
          onTap: _pick,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.terracottaTint,
                child: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.officineRegAuthorization,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _fileName ?? l.officineRegAuthorizationHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasAuthorization)
                OfficineTag(
                  '✓ ${l.officineRegAuthorizationAdded}',
                  tone: OfficineTone.success,
                )
              else
                const Icon(
                  Icons.upload_file_outlined,
                  color: AppColors.accentPrimary,
                ),
            ],
          ),
        ),
        OfficineNote(l.officineRegMobilePaymentNote),
      ],
    );
  }
}

/// Un champ du formulaire : son libellé en gras au-dessus, l'exemple dans
/// le champ, l'aide éventuelle dessous.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.maxLength,
    this.hint,
    this.help,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
  });

  final String label;
  final String? hint;
  final String? help;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final int maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: border(AppColors.border, 1),
              focusedBorder: border(AppColors.accentPrimary, 1.6),
            ),
          ),
          if (help != null) ...[
            const SizedBox(height: 6),
            Text(
              help!,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Officine · 15. Choisir la formule (étape 2 sur 3). Renvoie le dossier
/// une fois envoyé.
class OfficineRegistrationPlanScreen extends ConsumerStatefulWidget {
  const OfficineRegistrationPlanScreen({
    super.key,
    required this.draft,
    this.initialPlan,
  });

  final OfficineRegistrationDraft draft;
  final String? initialPlan;

  @override
  ConsumerState<OfficineRegistrationPlanScreen> createState() =>
      _OfficineRegistrationPlanScreenState();
}

class _OfficineRegistrationPlanScreenState
    extends ConsumerState<OfficineRegistrationPlanScreen> {
  // La maquette présélectionne l'ÉPÉ, la formule annuelle.
  late String _plan = widget.initialPlan ?? 'EPE';
  bool _busy = false;

  Future<void> _send() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final draft = widget.draft;
      int? mediaId;
      final path = draft.authorizationPath;
      if (path != null) {
        final name = draft.authorizationName ?? path.split('/').last;
        final mime = lookupMimeType(name) ?? 'application/octet-stream';
        final upload = await ref
            .read(mediaRepositoryProvider)
            .upload(
              bytes: await File(path).readAsBytes(),
              filename: name,
              mimeType: mime,
              messageType: mime.startsWith('image/') ? 'IMAGE' : 'DOCUMENT',
              memoriser: false,
            );
        mediaId = upload.id;
      }
      final position = await ref.read(officineRegistrationPositionProvider)();
      final sent = await ref
          .read(officineRepositoryProvider)
          .register(
            draft,
            plan: _plan,
            authorizationMediaId: mediaId,
            latitude: position?.latitude,
            longitude: position?.longitude,
          );
      HapticFeedback.lightImpact();
      ref.invalidate(officineRegistrationProvider);
      navigator.pop(sent);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final registration = ref.watch(officineRegistrationProvider).valueOrNull;
    final wetri = registration?.pricesHt['WETRI'];
    final epe = registration?.pricesHt['EPE'];
    final vat = ((registration?.vatRate ?? 0) * 100).round();
    final freeMonths = wetri != null && epe != null && wetri > 0
        ? (12 * wetri - epe) ~/ wetri
        : 0;
    int? ttc(int? ht) => ht == null ? null : registration!.ttc(ht);

    return OfficinePage(
      title: l.officineRegPlanTitle,
      subtitle: l.officineRegStep(2),
      primary: HonamPrimaryButton(
        label: l.officineRegSend,
        busy: _busy,
        onPressed: registration == null ? null : _send,
      ),
      children: [
        _PlanCard(
          selected: _plan == 'WETRI',
          onTap: () => setState(() => _plan = 'WETRI'),
          title: l.offiPlanWetri,
          trailing: Text(
            l.officineRegPerMonth,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          price: l.officineRegAmountHt(fcfa(wetri)),
          caption: l.officineRegWetriCaption(fcfa(ttc(wetri)), vat),
        ),
        _PlanCard(
          selected: _plan == 'EPE',
          onTap: () => setState(() => _plan = 'EPE'),
          title: l.offiPlanEpe,
          trailing: freeMonths > 0
              ? OfficineTag(l.offiFreeMonths(freeMonths))
              : null,
          price: l.officineRegAmountHt(fcfa(epe)),
          caption: l.officineRegEpeCaption(
            fcfa(wetri == null ? null : 12 * wetri),
            fcfa(ttc(epe)),
          ),
        ),
        ModuleCard(
          child: Column(
            children: [
              for (final benefit in [
                l.officineRegBenefitVisible,
                l.officineRegBenefitPrescriptions,
                l.officineRegBenefitCouriers,
                l.officineRegBenefitInvoices,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.feedbackSuccess,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        OfficineNote(l.officineRegNoPaymentYet),
      ],
    );
  }
}

/// Une formule : le bouton radio, son nom, son prix HT en grand et le TTC.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.price,
    required this.caption,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String price;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentPrimary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                price,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                caption,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Officine · 16. Vérification en cours (étape 3 sur 3) : là où l'on
/// revient tant que le support n'a pas décidé.
class OfficineRegistrationPendingScreen extends StatelessWidget {
  const OfficineRegistrationPendingScreen({
    super.key,
    required this.registration,
  });

  final OfficineRegistration registration;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final plan = registration.plan == 'WETRI' ? 'WETRI' : 'EPE';
    final planName = plan == 'WETRI' ? l.offiPlanWetri : l.offiPlanEpe;
    final price = registration.pricesHt[plan];
    final sent = registration.submittedAt?.toLocal();
    final due = registration.reviewDueAt?.toLocal();
    final now = DateTime.now();
    String? sentLabel;
    if (sent != null) {
      final time = officineTime(context, sent);
      sentLabel = DateUtils.isSameDay(sent, now)
          ? l.officineRegToday(time)
          : l.officineRegOn(DateFormat.MMMd(locale).format(sent), time);
    }
    return OfficinePage(
      title: l.officineRegPendingTitle,
      subtitle: l.officineRegStep(3),
      primary: HonamPrimaryButton(
        label: l.officineRegDone,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surfaceElevated,
            child: const Icon(
              Icons.history,
              size: 26,
              color: AppColors.accentPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.officineRegPendingText(registration.reviewHours),
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        ModuleCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              OfficineStepRow(
                title: l.officineRegStepSent,
                subtitle: sentLabel,
                done: true,
              ),
              OfficineStepRow(
                title: l.officineRegStepReview,
                subtitle: due == null
                    ? null
                    : l.officineRegDueBy(
                        DateFormat.MMMd(locale).format(due),
                        officineTime(context, due),
                      ),
                current: true,
              ),
              OfficineStepRow(
                title: l.officineRegStepPayment(planName),
                subtitle: price == null
                    ? null
                    : l.officineRegPaymentAmount(fcfa(registration.ttc(price))),
                number: 3,
              ),
            ],
          ),
        ),
        OfficineNote(l.officineRegPrepareNote),
      ],
    );
  }
}
