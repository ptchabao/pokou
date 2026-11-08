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
import '../../../core/widgets/pokou_illustration.dart';

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

/// INS-3 (cahier v3.2) : le nom affiché, seul champ obligatoire, accueilli
/// par Baba, avec les consentements FACULTATIFS (statistiques, nouveautés)
/// désactivés par défaut ; puis Baba propose de retrouver les proches.
///
/// Les conditions et l'âge ne sont plus ici : ils sont acceptés sur INS-1
/// par le bouton « Accepter et continuer » (AUTH-09).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { profile, contacts }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).user?.fullName ?? '',
  );
  _Step _step = _Step.profile;
  bool _analytics = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

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
      // Les deux consentements facultatifs partent avec le nom : ils sont
      // horodatés côté serveur et restent modifiables dans Confidentialité.
      // Les conditions et l'âge, eux, ont déjà été enregistrés à la
      // vérification du code (INS-1 / AUTH-09).
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/me/consents',
            body: {
              'consent_analytics': _analytics,
              'consent_marketing': _marketing,
            },
          );
      await ref.read(authControllerProvider.notifier).reloadProfile();
      setState(() {
        _busy = false;
        _step = _Step.contacts;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = l.onbFailed;
      });
    }
  }

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
                  Text(
                    l.onbStep('3'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                ],
                ...switch (_step) {
                  _Step.profile => _profile(l),
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
                          style: const TextStyle(
                            color: AppColors.feedbackDanger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                ModuleActionButton(
                  label: switch (_step) {
                    _Step.profile => l.onbContinue,
                    _Step.contacts => l.onbContactsAllow,
                  },
                  expanded: true,
                  busy: _busy,
                  onPressed: _busy
                      ? null
                      : switch (_step) {
                          _Step.profile => _saveName,
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
    const Center(
      child: PokouIllustration(PokouIllustrations.contactsEmpty, height: 170),
    ),
    const SizedBox(height: 20),
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
    // Consentements FACULTATIFS, désactivés par défaut (AUTH-09). Séparés
    // l'un de l'autre : un consentement groupé ne vaut pas consentement.
    const Divider(height: 32),
    Text(
      l.onbOptional,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
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
