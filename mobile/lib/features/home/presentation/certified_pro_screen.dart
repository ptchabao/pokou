import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../honam/presentation/honam_controller.dart' show openPayment;
import '../../modules/shared/module_ui.dart';
import '../../../core/time/server_time.dart';

final _proProvider =
    FutureProvider.autoDispose<
      ({Map<String, dynamic> application, Map<String, dynamic> profile})
    >((ref) async {
      final api = ref.watch(apiClientProvider);
      final me = ref.watch(authControllerProvider).user?.id;
      final results = await Future.wait([
        api.get('/certified/pro/me'),
        if (me != null) api.get('/certified/profile/$me'),
      ]);
      return (
        application: results[0] as Map<String, dynamic>,
        profile: results.length > 1
            ? results[1] as Map<String, dynamic>
            : const <String, dynamic>{},
      );
    });

/// Pokou certifié Pro (maquettes Pro 1 à 5).
///
/// Le justificatif d'abord ; le support vérifie sous 48 h ; on ne paie
/// qu'après la validation. Le profil Pro montre le nom commercial en
/// premier, puis « Géré par » suivi du nom vérifié.
class CertifiedProScreen extends ConsumerWidget {
  const CertifiedProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final data = ref.watch(_proProvider);
    final api = ref.read(apiClientProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(String? iso) => iso == null
        ? ''
        : DateFormat.MMMEd(locale).add_Hm().format(parseServerTime(iso));

    return ModuleScaffold(
      title: l.proTitle,
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
        data: (data) {
          final application = data.application;
          final status = application['status'] as String? ?? 'NONE';
          final profile = data.profile;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_proProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (profile['badge'] == 'PRO')
                  _ProProfile(profile: profile)
                else ...[
                  ModuleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.hexagon_outlined,
                              color: AppColors.accentPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.proTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(l.proPitch),
                        const SizedBox(height: 8),
                        Text(
                          l.proSteps('${application['review_hours'] ?? 48}'),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (status == 'PENDING')
                    ModuleCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top,
                            color: AppColors.feedbackWarning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.proPending(
                                date(application['review_due_at'] as String?),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (status == 'APPROVED') ...[
                    ModuleCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.feedbackSuccess,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l.proApproved)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ModuleActionButton(
                      label: l.proPay,
                      onPressed: () => openPayment(
                        context,
                        api
                            .post(
                              '/certified/subscribe',
                              body: {'plan': 'PRO_MONTHLY'},
                            )
                            .then(
                              (json) =>
                                  (json as Map<String, dynamic>)['payment_url']
                                      as String?,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.honamPriceNote,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (status == 'CORRECTION' || status == 'REJECTED')
                    ModuleCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status == 'CORRECTION'
                                ? l.proCorrection
                                : l.proRejected,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.feedbackWarning,
                            ),
                          ),
                          if (application['review_note'] != null) ...[
                            const SizedBox(height: 4),
                            Text(application['review_note'] as String),
                          ],
                        ],
                      ),
                    ),
                  if (status == 'NONE' ||
                      status == 'CORRECTION' ||
                      status == 'REJECTED') ...[
                    const SizedBox(height: 12),
                    _ProForm(
                      initial: application,
                      onSent: () => ref.invalidate(_proProvider),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Le profil Pro tel que les autres le voient (maquette Pro 5).
class _ProProfile extends StatelessWidget {
  const _ProProfile({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hexagon, color: AppColors.accentPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile['display_name'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (profile['activity'] != null)
            Text(
              profile['activity'] as String,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (profile['managed_by'] != null) ...[
            const SizedBox(height: 6),
            Text(l.proManagedBy(profile['managed_by'] as String)),
          ],
          const SizedBox(height: 8),
          Text(
            l.proProfileNote,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// « Ton activité » (maquette Pro 2) et le justificatif, envoyés ensemble.
class _ProForm extends ConsumerStatefulWidget {
  const _ProForm({required this.initial, required this.onSent});

  final Map<String, dynamic> initial;
  final VoidCallback onSent;

  @override
  ConsumerState<_ProForm> createState() => _ProFormState();
}

class _ProFormState extends ConsumerState<_ProForm> {
  late final _business = TextEditingController(
    text: widget.initial['business_name'] as String? ?? '',
  );
  late final _activity = TextEditingController(
    text: widget.initial['activity'] as String? ?? '',
  );
  late final _city = TextEditingController(
    text: widget.initial['city'] as String? ?? '',
  );
  XFile? _document;
  bool _busy = false;

  @override
  void dispose() {
    _business.dispose();
    _activity.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (photo != null && mounted) setState(() => _document = photo);
  }

  Future<void> _send() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: await File(_document!.path).readAsBytes(),
            filename: 'justificatif.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
            memoriser: false,
          );
      await ref
          .read(apiClientProvider)
          .post(
            '/certified/pro/apply',
            body: {
              'business_name': _business.text.trim(),
              'activity': _activity.text.trim(),
              if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
              'document_media_id': upload.id,
            },
          );
      widget.onSent();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ready =
        _business.text.trim().length >= 2 &&
        _activity.text.trim().length >= 2 &&
        _document != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.proActivity,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        TextField(
          controller: _business,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.proBusinessName),
        ),
        TextField(
          controller: _activity,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.proActivityField),
        ),
        TextField(
          controller: _city,
          decoration: InputDecoration(labelText: l.honamCity),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: Icon(
            _document == null ? Icons.upload_file : Icons.check_circle_outline,
          ),
          label: Text(_document == null ? l.proDocument : l.proDocumentChosen),
        ),
        const SizedBox(height: 4),
        Text(
          l.proDocumentNote,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ModuleActionButton(
          label: l.proSend,
          busy: _busy,
          onPressed: ready && !_busy ? _send : null,
        ),
      ],
    );
  }
}
