import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/country/country_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/server_time.dart';
import '../../../core/widgets/pokou_bottom_nav.dart' show isLot1;
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../honam/presentation/honam_controller.dart' show openPayment;
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';

final _proProvider =
    FutureProvider.autoDispose<
      ({
        Map<String, dynamic> application,
        Map<String, dynamic> profile,
        Map<String, dynamic>? plan,
      })
    >((ref) async {
      final api = ref.watch(apiClientProvider);
      final me = ref.watch(authControllerProvider).user?.id;
      final results = await Future.wait([
        api.get('/certified/pro/me'),
        api.get('/certified/offer'),
        if (me != null) api.get('/certified/profile/$me'),
      ]);
      final plans = ((results[1] as Map<String, dynamic>)['plans'] as List)
          .cast<Map<String, dynamic>>();
      return (
        application: results[0] as Map<String, dynamic>,
        // Le prix Pro vient de l'API, jamais d'une constante de l'app.
        plan: plans.where((p) => (p['code'] as String).startsWith('PRO')).firstOrNull,
        profile: results.length > 2
            ? results[2] as Map<String, dynamic>
            : const <String, dynamic>{},
      );
    });

/// Pokou certifié Pro (maquettes Pro 1 à 6).
///
/// Le justificatif d'abord ; le support vérifie sous 48 h ; on ne paie
/// qu'après la validation. Un ROUTEUR, comme CertifiedScreen : chaque état du
/// dossier est un écran à part dans les maquettes.
class CertifiedProScreen extends ConsumerWidget {
  const CertifiedProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final data = ref.watch(_proProvider);
    void refresh() => ref.invalidate(_proProvider);

    return data.when(
      loading: () => ModuleScaffold(title: l.proTitle, child: const SkeletonCards()),
      error: (_, _) => ModuleScaffold(
        title: l.proTitle,
        child: ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
      ),
      data: (data) {
        final application = data.application;
        final status = application['status'] as String? ?? 'NONE';
        if (data.profile['badge'] == 'PRO') {
          return _ProActiveScreen(profile: data.profile);
        }
        return switch (status) {
          'PENDING' => _ProPendingScreen(application: application),
          'CORRECTION' => _ProCorrectionScreen(application: application, onSent: refresh),
          'APPROVED' => _ProValidatedScreen(
            application: application,
            plan: data.plan,
            replacesCertified: data.profile['badge'] == 'CERTIFIED',
            onPaid: refresh,
          ),
          _ => _ProOfferScreen(application: application, plan: data.plan, onSent: refresh),
        };
      },
    );
  }
}

String _proDate(BuildContext context, String? iso) => iso == null
    ? ''
    : DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag())
          .add_Hm()
          .format(parseServerTime(iso));

/// « Pro · 1. Offre » (maquette 30, lot 1 p. 69).
class _ProOfferScreen extends ConsumerWidget {
  const _ProOfferScreen({required this.application, required this.plan, required this.onSent});

  final Map<String, dynamic> application;
  final Map<String, dynamic>? plan;
  final VoidCallback onSent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Lot 1 : pas d'Assimé, le badge Pro vit sur le profil et les statuts.
    final lot1 = isLot1(ref.watch(currentCountryConfigProvider).modules);
    final hours = '${application['review_hours'] ?? 48}';
    return ModuleScaffold(
      title: l.proTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VerifiedBadge(size: 36, pro: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.proOfferTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(l.proOfferAudience, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in [
            l.proOfferPointName,
            l.proOfferPointProfile,
            lot1 ? l.proOfferPointBadgeLot1 : l.proOfferPointBadge,
            l.proOfferPointProof,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.feedbackSuccess),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          if (plan != null) ...[
            const SizedBox(height: 8),
            _ProPriceCard(plan: plan!),
          ],
          ModuleSectionTitle(l.proHowItWorks),
          _ProStep(number: 1, title: l.proStepSendTitle, subtitle: l.proStepSendBody),
          _ProStep(number: 2, title: l.proStepCheckTitle(hours), subtitle: l.proStepCheckBody),
          _ProStep(number: 3, title: l.proStepPayTitle, subtitle: l.proStepPayBody),
          const SizedBox(height: 20),
          ModuleActionButton(
            label: l.proStart,
            onPressed: () async {
              final sent = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ProActivityScreen(initial: application)),
              );
              if (sent == true) onSent();
            },
          ),
        ],
      ),
    );
  }
}

class _ProPriceCard extends StatelessWidget {
  const _ProPriceCard({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${formatFcfa(plan['price_ht'] as int)} HT',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' ${l.proPerMonth}', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            l.proPriceTtcCancel(formatFcfa(plan['price_ttc'] as int)),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProStep extends StatelessWidget {
  const _ProStep({this.number, this.done = false, this.waiting = false, required this.title, this.subtitle});

  final int? number;
  final bool done;
  final bool waiting;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final Widget leading = done
        ? const CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.feedbackSuccess,
            child: Icon(Icons.check, size: 16, color: Colors.white),
          )
        : waiting
        ? CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.terracottaTint,
            child: const Icon(Icons.schedule, size: 16, color: AppColors.accentPrimary),
          )
        : CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.surfaceElevated,
            child: Text('${number ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Pro · 2. Ton activité » (maquette 30) : étape 1 sur 3, sur un écran
/// à part. Renvoie `true` une fois le dossier envoyé.
class ProActivityScreen extends ConsumerStatefulWidget {
  const ProActivityScreen({super.key, required this.initial});

  final Map<String, dynamic> initial;

  @override
  ConsumerState<ProActivityScreen> createState() => _ProActivityScreenState();
}

class _ProActivityScreenState extends ConsumerState<ProActivityScreen> {
  late final _business = TextEditingController(text: widget.initial['business_name'] as String? ?? '');
  late final _activity = TextEditingController(text: widget.initial['activity'] as String? ?? '');
  late final _address = TextEditingController(text: widget.initial['address'] as String? ?? '');
  late String _documentType = widget.initial['document_type'] as String? ?? 'RCCM';
  XFile? _document;
  int _documentBytes = 0;
  bool _busy = false;

  @override
  void dispose() {
    _business.dispose();
    _activity.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
    if (photo == null || !mounted) return;
    final size = await File(photo.path).length();
    if (mounted) {
      setState(() {
        _document = photo;
        _documentBytes = size;
      });
    }
  }

  Future<void> _send() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      final upload = await ref.read(mediaRepositoryProvider).upload(
            bytes: await File(_document!.path).readAsBytes(),
            filename: 'justificatif.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
            memoriser: false,
          );
      await ref.read(apiClientProvider).post(
        '/certified/pro/apply',
        body: {
          'business_name': _business.text.trim(),
          'activity': _activity.text.trim(),
          if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
          'document_type': _documentType,
          'document_media_id': upload.id,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ready = _business.text.trim().length >= 2 && _activity.text.trim().length >= 2 && _document != null;
    final types = {'RCCM': l.proDocRccm, 'NIF': l.proDocNif, 'RECEPISSE': l.proDocRecepisse};
    Widget field(String label, TextEditingController controller) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
    return ModuleScaffold(
      title: l.proActivity,
      subtitle: l.proStepOf('1'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          field(l.proBusinessName, _business),
          field(l.proActivityLabel, _activity),
          field(l.proAddressLabel, _address),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(l.proDocumentLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          SegmentedButton<String>(
            segments: [
              for (final entry in types.entries) ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: {_documentType},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _documentType = value.first),
          ),
          const SizedBox(height: 10),
          ModuleCard(
            onTap: _pick,
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: _document == null
                      ? Text(l.proDocument)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_document!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(l.proDocumentSize((_documentBytes / (1024 * 1024)).toStringAsFixed(1)),
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                ),
                if (_document != null) TextButton(onPressed: _pick, child: Text(l.proChange)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ModuleCallout(tone: CalloutTone.beige, text: l.proDocumentNameNote),
          const SizedBox(height: 20),
          ModuleActionButton(label: l.proSend, busy: _busy, onPressed: ready && !_busy ? _send : null),
        ],
      ),
    );
  }
}

/// « Pro · 3. Vérification en cours » (maquette 30) : étape 2 sur 3.
class _ProPendingScreen extends StatelessWidget {
  const _ProPendingScreen({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleScaffold(
      title: l.proPendingTitle,
      subtitle: l.proStepOf('2'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Align(alignment: Alignment.centerLeft, child: Icon(Icons.history, size: 40, color: AppColors.accentPrimary)),
          const SizedBox(height: 10),
          Text(l.proPendingBody('${application['review_hours'] ?? 48}')),
          const SizedBox(height: 14),
          ModuleCard(
            child: Column(
              children: [
                _ProStep(done: true, title: l.proStepSent, subtitle: _proDate(context, application['submitted_at'] as String?)),
                _ProStep(waiting: true, title: l.proStepSupport,
                    subtitle: l.proAtTheLatest(_proDate(context, application['review_due_at'] as String?))),
                _ProStep(number: 3, title: l.proStepPayBadge, subtitle: l.proAfterValidation),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModuleCallout(tone: CalloutTone.beige, text: l.proPendingKeep),
          const SizedBox(height: 20),
          ModuleActionButton(label: l.actionDone, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// « Pro · 4. Justificatif à corriger » (maquette 30).
class _ProCorrectionScreen extends ConsumerStatefulWidget {
  const _ProCorrectionScreen({required this.application, required this.onSent});

  final Map<String, dynamic> application;
  final VoidCallback onSent;

  @override
  ConsumerState<_ProCorrectionScreen> createState() => _ProCorrectionScreenState();
}

class _ProCorrectionScreenState extends ConsumerState<_ProCorrectionScreen> {
  late bool _useDocumentName = widget.application['document_name'] != null;
  bool _busy = false;

  Future<void> _resend() async {
    final l = L.of(context);
    final application = widget.application;
    if (!_useDocumentName) {
      final sent = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ProActivityScreen(initial: application)),
      );
      if (sent == true) widget.onSent();
      return;
    }
    setState(() => _busy = true);
    try {
      // Même justificatif, le nom qu'il porte : le serveur garde le fichier.
      await ref.read(apiClientProvider).post('/certified/pro/apply', body: {
        'business_name': application['document_name'],
        'activity': application['activity'],
        if (application['address'] != null) 'address': application['address'],
        if (application['document_type'] != null) 'document_type': application['document_type'],
      });
      widget.onSent();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final application = widget.application;
    final documentName = application['document_name'] as String?;
    final documentType = application['document_type'] as String? ?? 'RCCM';
    return ModuleScaffold(
      title: l.proCorrection,
      subtitle: l.proTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ModuleCallout(
            tone: CalloutTone.red,
            title: documentName != null ? l.proNameMismatchTitle : l.proCorrection,
            text: application['review_note'] as String? ?? '',
          ),
          ModuleSectionTitle(l.proWhatToDo),
          if (documentName != null)
            ModuleCard(
              onTap: () => setState(() => _useDocumentName = true),
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: _useDocumentName,
                onChanged: (_) => setState(() => _useDocumentName = true),
                title: Text(l.proUseDocumentName(documentName)),
                subtitle: Text(l.proNameOnDocument(documentType)),
              ),
            ),
          const SizedBox(height: 8),
          ModuleCard(
            onTap: () => setState(() => _useDocumentName = false),
            child: RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              value: false,
              groupValue: _useDocumentName,
              onChanged: (_) => setState(() => _useDocumentName = false),
              title: Text(l.proSendOtherDocument),
            ),
          ),
          const SizedBox(height: 12),
          ModuleCallout(tone: CalloutTone.beige, text: l.proNoPaymentTaken),
          const SizedBox(height: 20),
          ModuleActionButton(label: l.proCorrectAndResend, busy: _busy, onPressed: _busy ? null : _resend),
          // Le support : par la même file que les signalements, faute d'un
          // canal dédié — à brancher sur le contact support quand il existera.
          Center(
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.proSupportHint)),
              ),
              child: Text(l.proContactSupport),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Pro · 6. Validé : payer » (maquette 105) : étape 3 sur 3.
class _ProValidatedScreen extends ConsumerWidget {
  const _ProValidatedScreen({
    required this.application,
    required this.plan,
    required this.replacesCertified,
    required this.onPaid,
  });

  final Map<String, dynamic> application;
  final Map<String, dynamic>? plan;
  final bool replacesCertified;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final documentType = application['document_type'] as String? ?? 'RCCM';
    return ModuleScaffold(
      title: l.proTitle,
      subtitle: l.proStepOf('3'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Color(0x2216A34A),
              child: Icon(Icons.check, color: AppColors.feedbackSuccess),
            ),
          ),
          const SizedBox(height: 10),
          Text(l.proGoodNews(application['business_name'] as String? ?? '')),
          const SizedBox(height: 14),
          ModuleCard(
            child: Column(
              children: [
                _ProStep(done: true, title: l.proStepSent, subtitle: _proDate(context, application['submitted_at'] as String?)),
                _ProStep(done: true, title: l.proDocumentVerifiedBySupport(documentType),
                    subtitle: _proDate(context, application['reviewed_at'] as String?)),
                _ProStep(waiting: true, title: l.proStepPayBadge, subtitle: l.proNameShownAfterPayment),
              ],
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 10),
            _ProPriceCard(plan: plan!),
          ],
          if (replacesCertified) ...[
            const SizedBox(height: 10),
            ModuleCallout(tone: CalloutTone.beige, text: l.proReplacesCertified),
          ],
          const SizedBox(height: 20),
          if (plan != null)
            ModuleActionButton(
              label: l.proPayTtc(formatFcfa(plan!['price_ttc'] as int)),
              onPressed: () async {
                await openPayment(
                  context,
                  ref
                      .read(apiClientProvider)
                      .post('/certified/subscribe', body: {'plan': plan!['code']})
                      .then((json) => (json as Map<String, dynamic>)['payment_url'] as String?),
                );
                onPaid();
              },
            ),
        ],
      ),
    );
  }
}

/// Le badge Pro est actif : un rappel de ce que les autres voient (le
/// profil complet est dans pro_profile_view.dart).
class _ProActiveScreen extends StatelessWidget {
  const _ProActiveScreen({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleScaffold(
      title: l.proTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(profile['display_name'] as String? ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    const VerifiedBadge(size: 20, pro: true),
                  ],
                ),
                if (profile['managed_by'] != null)
                  Text(l.proManagedByVerified(profile['managed_by'] as String),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                if (profile['activity'] != null) ...[
                  const SizedBox(height: 4),
                  Text(profile['activity'] as String),
                ],
                const SizedBox(height: 8),
                Text(l.proProfileNote, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
