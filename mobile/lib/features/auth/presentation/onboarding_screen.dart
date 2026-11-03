import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'auth_controller.dart';
import 'legal_screen.dart';

/// Après le code : faut-il encore le profil ou les conditions ?
///
/// Lu sur `/auth/me` plutôt que sur le profil en cache : `needs_onboarding`
/// est calculé par le serveur, qui seul sait quelle version des conditions
/// est en vigueur.
Future<String> routeAfterSignIn(WidgetRef ref) async {
  try {
    final me = await ref.read(apiClientProvider).get('/auth/me');
    final needs = (me as Map<String, dynamic>)['needs_onboarding'] as bool?;
    return needs == true ? '/onboarding' : '/inbox';
  } catch (_) {
    // Hors ligne juste après une connexion réussie : on n'enferme pas la
    // personne dehors. L'étape reviendra à la prochaine connexion.
    return '/inbox';
  }
}

/// Après le code (maquettes 3 à 5) : le nom affiché, seul champ
/// obligatoire, accueilli par Baba ; puis Baba propose de retrouver les
/// proches. Les conditions et l'âge se cochent ici, pour un compte qui ne
/// les a jamais acceptés : la connexion et l'inscription partagent le même
/// écran du numéro, et seul un compte nouveau arrive jusqu'ici.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { profile, consents, contacts }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).user?.fullName ?? '',
  );
  _Step _step = _Step.profile;
  /// Vrai tant que le serveur n'a pas dit le contraire : un compte nouveau
  /// ne doit jamais sauter les conditions parce que la réponse de
  /// `/auth/me` arrive après qu'il a tapé « Continuer ».
  bool _needsTerms = true;
  bool _terms = false;
  bool _age = false;
  bool _analytics = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(apiClientProvider).get('/auth/me').then((me) {
      if (!mounted) return;
      setState(() => _needsTerms = (me as Map<String, dynamic>)['terms_accepted_at'] == null);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toInbox() => context.go('/inbox');

  /// Baba propose de retrouver les proches (maquette 4). L'accord reste un
  /// geste explicite ; refusé, il se redemandera plus tard.
  Future<void> _allowContacts() async {
    setState(() => _busy = true);
    try {
      if (await ref.read(deviceContactsServiceProvider).hasPermission()) {
        await forceContactSync(ref);
      }
    } catch (_) {
      // Le répertoire se relira à la prochaine ouverture des Discussions.
    }
    if (mounted) _toInbox();
  }

  Future<void> _saveName() async {
    final l = L.of(context);
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = l.onbNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateMine(fullName: name);
      await ref.read(authControllerProvider.notifier).reloadProfile();
      setState(() {
        _busy = false;
        _step = _needsTerms ? _Step.consents : _Step.contacts;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = l.onbFailed;
      });
    }
  }

  Future<void> _finish() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post(
        '/auth/me/consents',
        body: {
          'accept_terms': true,
          'age_confirmed': true,
          'consent_analytics': _analytics,
          'consent_marketing': _marketing,
        },
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _step = _Step.contacts;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.onbFailed;
        });
      }
    }
  }

  void _open(String name) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => LegalScreen(name: name)),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return PopScope(
      // Ni retour vers le code déjà utilisé, ni sortie sans conditions.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PokouBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                if (_step == _Step.profile) ...[
                  Text(l.onbStep('3'), style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                ],
                ...switch (_step) {
                  _Step.profile => _profile(l),
                  _Step.consents => _consents(l),
                  _Step.contacts => _contacts(l),
                },
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppColors.feedbackDanger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.feedbackDanger),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                ModuleActionButton(
                  label: switch (_step) {
                    _Step.profile => l.onbContinue,
                    _Step.consents => l.onbFinish,
                    _Step.contacts => l.onbContactsAllow,
                  },
                  expanded: true,
                  busy: _busy,
                  onPressed: _busy
                      ? null
                      : switch (_step) {
                          _Step.profile => _saveName,
                          _Step.consents => _terms && _age ? _finish : null,
                          _Step.contacts => _allowContacts,
                        },
                ),
                if (_step == _Step.contacts)
                  TextButton(onPressed: _toInbox, child: Text(l.onbLater)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baba, l'assistant, accueille le profil (maquette 3).
  Widget _baba(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantOrb(size: 44),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(text),
        ),
      ),
    ],
  );

  List<Widget> _contacts(L l) => [
    Text(
      l.onbContactsTitle,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 16),
    _baba(l.onbContactsBody),
  ];

  List<Widget> _profile(L l) => [
    Text(
      l.onbProfileTitle,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    _baba(l.onbBabaWelcome),
    const SizedBox(height: 4),
    Text(l.onbProfileBody, style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    TextField(
      controller: _name,
      autofocus: true,
      maxLength: 60,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: l.onbDisplayName),
      onSubmitted: (_) => _saveName(),
    ),
    Text(
      l.onbPhotoLater,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
  ];

  List<Widget> _consents(L l) => [
    Text(
      l.onbTermsTitle,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        TextButton(onPressed: () => _open('conditions'), child: Text(l.legalTerms)),
        TextButton(
          onPressed: () => _open('confidentialite'),
          child: Text(l.legalPrivacy),
        ),
      ],
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _terms,
      onChanged: (v) => setState(() => _terms = v ?? false),
      title: Text(l.onbAcceptTerms),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _age,
      onChanged: (v) => setState(() => _age = v ?? false),
      title: Text(l.onbAge),
    ),
    const Divider(height: 32),
    Text(l.onbOptional, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _analytics,
      onChanged: (v) => setState(() => _analytics = v),
      title: Text(l.onbAnalytics),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _marketing,
      onChanged: (v) => setState(() => _marketing = v),
      title: Text(l.onbMarketing),
    ),
  ];
}
