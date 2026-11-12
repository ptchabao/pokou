import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../honam/presentation/honam_controller.dart' show openPayment;
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_screen.dart' show KoryStatusPill;
import '../../modules/shared/module_ui.dart';
import 'certified_pro_screen.dart';
import '../../../core/time/server_time.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/skeleton.dart';

final _certifiedProvider =
    FutureProvider.autoDispose<
      ({Map<String, dynamic> status, Map<String, dynamic> offer})
    >((ref) async {
      final api = ref.watch(apiClientProvider);
      final results = await Future.wait([
        api.get('/certified/me'),
        api.get('/certified/offer'),
      ]);
      return (
        status: results[0] as Map<String, dynamic>,
        offer: results[1] as Map<String, dynamic>,
      );
    });

/// Pokou certifié (section 9.5) : l'offre, l'essai, le paiement, et l'écran
/// « noms différents » quand le wallet n'est pas au nom affiché.
class CertifiedScreen extends ConsumerWidget {
  const CertifiedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final data = ref.watch(_certifiedProvider);
    final api = ref.read(apiClientProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(String? iso) => iso == null
        ? ''
        : DateFormat.yMMMd(locale).format(parseServerTime(iso));

    Future<void> post(String path, [Map<String, dynamic>? body]) async {
      try {
        await api.post(path, body: body ?? const {});
        ref.invalidate(_certifiedProvider);
        await ref.read(authControllerProvider.notifier).reloadProfile();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    }

    return ModuleScaffold(
      title: l.certTitle,
      child: data.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
        data: (data) {
          final status = data.status;
          final state = status['status'] as String;
          // La formule Pro a son propre parcours : justificatif d'abord,
          // paiement après validation (maquettes Pro).
          final plans = [
            for (final plan
                in (data.offer['plans'] as List).cast<Map<String, dynamic>>())
              if (!(plan['code'] as String).startsWith('PRO')) plan,
          ];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_certifiedProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: AppColors.feedbackInfo,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.certTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (status['badge_visible'] == true)
                            KoryStatusPill(
                              icon: Icons.check_circle,
                              label: l.certActive,
                              color: AppColors.feedbackSuccess,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(l.certPitch),
                      const SizedBox(height: 8),
                      Text(
                        l.certHowItWorks,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state == 'TRIAL')
                        Text(
                          l.certTrialUntil(
                            date(status['trial_ends_at'] as String?),
                          ),
                        ),
                      if (state == 'ACTIVE')
                        Text(
                          l.certActiveUntil(
                            date(status['current_period_end'] as String?),
                          ),
                        ),
                      if (state == 'EXPIRED')
                        Text(
                          l.certExpired,
                          style: const TextStyle(
                            color: AppColors.feedbackDanger,
                          ),
                        ),
                    ],
                  ),
                ),
                // CRT-5 · Badge en pause : expliquer sans inquiéter, et
                // réafficher le badge en un paiement.
                if (state == 'PAUSED') ...[
                  const SizedBox(height: 12),
                  _BadgePaused(
                    status: status,
                    plans: plans,
                    date: date,
                    onPay: (code) => openPayment(
                      context,
                      api
                          .post('/certified/subscribe', body: {'plan': code})
                          .then(
                            (json) =>
                                (json as Map<String, dynamic>)['payment_url']
                                    as String?,
                          ),
                    ),
                  ),
                ],
                if (state == 'NAME_MISMATCH') ...[
                  const SizedBox(height: 12),
                  _NameMismatch(
                    onResolved: () {
                      ref.invalidate(_certifiedProvider);
                      ref.read(authControllerProvider.notifier).reloadProfile();
                    },
                  ),
                ],
                if (status['trial_available'] == true) ...[
                  const SizedBox(height: 12),
                  ModuleActionButton(
                    label: l.certStartTrial('${data.offer['trial_days']}'),
                    onPressed: () => post('/certified/trial'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.certTrialNote,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ModuleCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan['label'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l.certPlanPrice(
                                    formatFcfa(plan['price_ht'] as int),
                                    formatFcfa(plan['price_ttc'] as int),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ModuleActionButton(
                            label: l.certSubscribe,
                            expanded: false,
                            onPressed: () => openPayment(
                              context,
                              api
                                  .post(
                                    '/certified/subscribe',
                                    body: {'plan': plan['code']},
                                  )
                                  .then(
                                    (json) =>
                                        (json
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['payment_url']
                                            as String?,
                                  ),
                            ),
                          ),
                        ],
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
                const SizedBox(height: 16),
                ModuleCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.hexagon_outlined,
                      color: AppColors.accentPrimary,
                    ),
                    title: Text(l.proTitle),
                    subtitle: Text(l.proTeaser),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CertifiedProScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// « Noms différents » (maquette 2b) : on demande de corriger le nom saisi,
/// sans jamais montrer celui du titulaire du wallet.
class _NameMismatch extends ConsumerStatefulWidget {
  const _NameMismatch({required this.onResolved});

  final VoidCallback onResolved;

  @override
  ConsumerState<_NameMismatch> createState() => _NameMismatchState();
}

class _NameMismatchState extends ConsumerState<_NameMismatch> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/certified/resolve-name',
            body: {'full_name': _name.text.trim()},
          );
      widget.onResolved();
    } catch (_) {
      if (mounted) setState(() => _error = l.certStillMismatch);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.certMismatchTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(l.certMismatchBody),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l.certCorrectName,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          ModuleActionButton(
            label: l.certRetryName,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _BadgePaused extends StatelessWidget {
  const _BadgePaused({
    required this.status,
    required this.plans,
    required this.date,
    required this.onPay,
  });

  final Map<String, dynamic> status;
  final List<Map<String, dynamic>> plans;
  final String Function(String?) date;
  final void Function(String planCode) onPay;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final code = status['plan'] as String?;
    final plan =
        plans.where((p) => p['code'] == code).firstOrNull ?? plans.firstOrNull;
    Widget list(String title, List<String> items) => ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.certPausedTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          l.certPausedBody(
            date(status['current_period_end'] as String?),
            date(status['paused_since'] as String?),
            '${status['grace_days'] ?? 7}',
          ),
        ),
        const SizedBox(height: 12),
        list(l.certWhatRemains, [l.certRemainsChats, l.certRemainsTraces]),
        const SizedBox(height: 8),
        list(l.certWhatPaused, [l.certPausedBadge, l.certPausedProof]),
        const SizedBox(height: 8),
        ModuleCallout(tone: CalloutTone.beige, text: l.certPausedWallet),
        if (plan != null) ...[
          const SizedBox(height: 12),
          ModuleActionButton(
            label: l.certPausedPay(formatFcfa(plan['price_ttc'] as int)),
            onPressed: () => onPay(plan['code'] as String),
          ),
          Center(
            child: Text(
              l.certChangePlan,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}
