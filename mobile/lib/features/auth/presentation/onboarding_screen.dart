import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/new_chat_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'auth_controller.dart';
import 'auth_progress_bar.dart';
import '../../../core/widgets/pokou_context_menu.dart';

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
///
/// Profil (maquette 3) → Baba propose les contacts (4) → contacts retrouvés
/// (5). Les écrans 4 et 5 prennent la forme de la discussion avec Baba,
/// comme dans la maquette.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { profile, contacts, found }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).user?.fullName ?? '',
  );
  _Step _step = _Step.profile;
  bool _analytics = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

  /// Mes contacts déjà inscrits sur Pokou, retrouvés après l'accord.
  List<PokouContact> _found = const [];

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
    var found = const <PokouContact>[];
    try {
      if (await ref.read(deviceContactsServiceProvider).hasPermission()) {
        await forceContactSync(ref);
        found = [
          for (final c in await ref.read(contactsProvider.future))
            if (c.isRegistered && c.contactUserId != null) c,
        ];
      }
    } catch (_) {
      // Le répertoire se relira à la prochaine ouverture des Discussions.
    }
    if (!mounted) return;
    // Personne de retrouvé (ou accès refusé) : rien à montrer, on entre.
    if (found.isEmpty) return _toInbox();
    setState(() {
      _busy = false;
      _found = found;
      _step = _Step.found;
    });
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

  Future<void> _write(PokouContact contact) async {
    final me = ref.read(authControllerProvider).user?.id;
    final other = contact.contactUserId;
    if (me == null || other == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: me,
          contactUserId: other,
          contactName: contact.displayName,
        ),
      ),
    );
  }

  void _openNewChat() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const NewChatScreen()));

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
            child: _step == _Step.profile ? _profile(l) : _babaChat(l),
          ),
        ),
      ),
    );
  }

  Widget _errorLine() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
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
        );

  /// Maquette 3 · le profil, accueilli par Baba.
  Widget _profile(L l) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              l.onbStep('3'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const AuthProgressBar(step: 3),
            const SizedBox(height: 20),
            _BabaBubble(text: l.onbBabaWelcome, withOrb: true),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // La photo est facultative et s'ajoute depuis le profil : le
                // cercle annonce sa place sans la réclamer ici.
                Tooltip(message: l.onbPhotoLater, child: const _AvatarSlot()),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    contextMenuBuilder: pokouContextMenuBuilder,
                    controller: _name,
                    autofocus: true,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.onbDisplayName,
                      counterText: '',
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.onbProfileBody,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            _errorLine(),
            const SizedBox(height: 20),
            // Consentements FACULTATIFS, désactivés par défaut (AUTH-09).
            // Séparés l'un de l'autre : un consentement groupé ne vaut pas
            // consentement.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.onbOptional.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _analytics,
                    onChanged: (v) => setState(() => _analytics = v),
                    title: Text(l.onbAnalytics),
                    subtitle: Text(l.onbAnalyticsSub),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _marketing,
                    onChanged: (v) => setState(() => _marketing = v),
                    title: Text(l.onbMarketing),
                    subtitle: Text(l.onbMarketingSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ModuleActionButton(
          label: l.onbStart,
          expanded: true,
          busy: _busy,
          onPressed: _busy ? null : _saveName,
        ),
      ),
    ],
  );

  /// Maquettes 4 et 5 : la discussion épinglée de Baba, qui propose de
  /// retrouver les proches, puis montre qui est déjà sur Pokou.
  Widget _babaChat(L l) {
    final firstName = (ref.watch(authControllerProvider).user?.fullName ?? '')
        .split(' ')
        .first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const AssistantOrb(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l.navBaba,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const _AiTag(),
                      ],
                    ),
                    Text(
                      l.onbBabaRole,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Le rappel que Baba est une IA, comme dans sa discussion.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.onbBabaAiNotice,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BabaBubble(text: l.onbBabaReady(firstName)),
              const SizedBox(height: 8),
              _BabaBubble(title: l.onbContactsTitle, text: l.onbContactsBody),
              if (_step == _Step.found) ...[
                const SizedBox(height: 8),
                // Ma réponse, côté droit, comme un message envoyé.
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      l.onbContactsAllow,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _FoundCard(
                  contacts: _found,
                  onWrite: _write,
                  onSeeAll: _openNewChat,
                ),
                const SizedBox(height: 8),
                _BabaBubble(text: l.onbInviteOthers),
              ],
              _errorLine(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _step == _Step.contacts
                ? [
                    FilledButton(
                      onPressed: _busy ? null : _allowContacts,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.onbContactsAllow),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _toInbox,
                      child: Text(l.onbLater),
                    ),
                  ]
                : [
                    OutlinedButton(
                      onPressed: _openNewChat,
                      child: Text(l.onbInviteMine),
                    ),
                    FilledButton(
                      onPressed: _toInbox,
                      child: Text(l.onbGoToChats),
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}

/// La place de la photo : un cercle et un petit appareil photo.
class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.terracottaTint,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(Icons.person_outline, color: AppColors.accentPrimaryDark),
      ),
      Positioned(
        right: -2,
        bottom: -2,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppColors.accentPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

/// L'étiquette « IA » à côté du nom de Baba.
class _AiTag extends StatelessWidget {
  const _AiTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.terracottaTint,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      L.of(context).onbAiTag,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.accentPrimaryDark,
      ),
    ),
  );
}

/// Une bulle de Baba. Avec `withOrb`, son orbe et l'étiquette « Baba IA »
/// (maquette 3) ; sinon une bulle de discussion (maquettes 4 et 5).
class _BabaBubble extends StatelessWidget {
  const _BabaBubble({required this.text, this.title, this.withOrb = false});

  final String text;
  final String? title;
  final bool withOrb;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withOrb) ...[
            Row(
              children: [
                Text(
                  L.of(context).navBaba,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                const _AiTag(),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (title != null) ...[
            Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(text),
        ],
      ),
    );
    if (!withOrb) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: 0.88, child: bubble),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const AssistantOrb(size: 32),
        const SizedBox(width: 8),
        Expanded(child: bubble),
      ],
    );
  }
}

/// Maquette 5 · « C'est fait ! N de tes contacts sont déjà sur Pokou » :
/// les trois premiers avec « Écrire », puis le lien vers tous.
class _FoundCard extends StatelessWidget {
  const _FoundCard({
    required this.contacts,
    required this.onWrite,
    required this.onSeeAll,
  });

  final List<PokouContact> contacts;
  final ValueChanged<PokouContact> onWrite;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.onbFoundCount(contacts.length)),
              const SizedBox(height: 8),
              for (final contact in contacts.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ContactAvatar(
                        avatar: contact.avatar,
                        displayName: contact.displayName,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          contact.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => onWrite(contact),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l.onbWrite),
                      ),
                    ],
                  ),
                ),
              if (contacts.length > 3)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(l.onbSeeAllFound(contacts.length)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
