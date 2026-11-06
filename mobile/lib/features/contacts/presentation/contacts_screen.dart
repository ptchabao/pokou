import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../groups/presentation/group_invitation_card.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/minou_repository.dart';
import '../../chat/presentation/chat_controller.dart'
    show kNoMonitor, minouStatusProvider;
import '../../chat/presentation/daily_digest_service.dart';
import '../../communities/presentation/community_detail_screen.dart';
import '../../presence/presentation/typing_controller.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import 'add_contact_screen.dart';
import 'contacts_controller.dart';
import '../../broadcasts/presentation/broadcast_lists_screen.dart';
import '../../modules/presentation/modules_screen.dart';
import 'discovery_strip.dart';
import 'new_chat_screen.dart';
import '../../status/presentation/status_controller.dart';
import 'discussions_controller.dart';
import '../data/conversation_summary.dart';
import '../../channels/presentation/channel_search_screen.dart';
import '../../../core/sharing/invite_sharing.dart';

const _kPriorityTags = ['BUSINESS', 'FOURNISSEUR', 'CLIENT', 'BOSS', 'AMI'];

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Le filtre de la liste. Local à l'écran, et non dans un provider : il ne
  /// doit pas survivre à la fermeture de l'onglet. Revenir aux discussions
  /// doit TOUT montrer — un filtre oublié fait croire à une conversation
  /// disparue, et c'est la panne la plus difficile à décrire au support.
  ChatFilter _filter = ChatFilter.all;

  /// La liste montre-t-elle les archivées ? Replié par défaut, et remis à
  /// plat à chaque ouverture de l'onglet — on n'atterrit jamais dans les
  /// archives sans l'avoir demandé.
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    // La synchronisation du répertoire n'est plus déclenchée ici : elle vit
    // au niveau de l'application (contactSyncProvider), pour qu'une arrivée
    // soit enregistrée même quand cet onglet n'est pas affiché.
    // Récap de fin de journée dans le chat Mahizu — best-effort, voir
    // daily_digest_service.dart (au plus une fois par jour).
    ref.read(dailyDigestServiceProvider).maybeShowDigest();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Appui long sur un contact — Mode Bouclier : marque ce contact comme
  /// prioritaire (BUSINESS/FOURNISSEUR/CLIENT/BOSS) ou "AMI", pour la
  /// matrice de décision côté API (voir shield_service.py).
  Future<void> _pickPriorityTag({
    required int contactId,
    required String displayName,
    String? currentTag,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.of(context).chatsTagNamed(displayName),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final tag in _kPriorityTags)
              ListTile(
                title: Text(tag),
                trailing: currentTag == tag
                    ? Icon(Icons.check, color: AppColors.accentPrimaryDark)
                    : null,
                onTap: () => Navigator.pop(sheetContext, tag),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    try {
      await ref
          .read(contactsRepositoryProvider)
          .setPriorityTag(contactId, chosen);
      ref.invalidate(contactsProvider);
      ref.invalidate(discussionsProvider);
      ref.invalidate(archivedDiscussionsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).contactsTagFailed)),
        );
      }
    }
  }

  /// Menu long-press d'une ligne de discussion — épingler/archiver/muter
  /// pour un contact ou un groupe déjà connus, étiqueter (Mode Bouclier) et
  /// bloquer réservés aux contacts. Un inconnu qui m'a écrit (`id == null`)
  /// n'a pas de ligne Contact/GroupMember à régler : menu réduit à
  /// « Ajouter aux contacts » et « Bloquer », qui créent cette ligne au
  /// passage côté serveur.
  Future<void> _openDiscussionMenu(ConversationSummary discussion) async {
    if (discussion.isUnknownContact) {
      await _openUnknownContactMenu(discussion);
      return;
    }

    final id = discussion.id;
    if (id == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                discussion.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(
                discussion.isPinned
                    ? L.of(context).chatsUnpin
                    : L.of(context).chatsPin,
              ),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: Icon(
                discussion.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(
                discussion.isArchived
                    ? L.of(context).chatsUnarchive
                    : L.of(context).chatsArchive,
              ),
              onTap: () => Navigator.pop(sheetContext, 'archive'),
            ),
            ListTile(
              leading: Icon(
                discussion.isMuted
                    ? Icons.notifications_off
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                discussion.isMuted
                    ? L.of(context).chatsUnmute
                    : L.of(context).chatsMute,
              ),
              onTap: () => Navigator.pop(sheetContext, 'mute'),
            ),
            if (discussion.kind == 'contact') ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(L.of(context).contactsTag),
                onTap: () => Navigator.pop(sheetContext, 'tag'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block,
                  color: AppColors.semanticError,
                ),
                title: Text(
                  L.of(context).chatsBlock,
                  style: const TextStyle(color: AppColors.semanticError),
                ),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
            ],
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'pin':
        await _applyConversationAction(
          () => ref
              .read(conversationsRepositoryProvider)
              .setPinned(
                kind: discussion.kind,
                id: id,
                pinned: !discussion.isPinned,
              ),
          // La limite de 3 épingles (voir conversations.py) répond 409 —
          // seul cas où ce menu doit rendre l'erreur EXPLICITE plutôt que
          // la formule générique : sinon rien ne dit pourquoi ça ne marche pas.
          conflictMessage: L.of(context).chatsPinLimit,
          whenQueued: () => _showQueued(
            discussion.kind,
            id,
            fields: {'is_pinned': !discussion.isPinned},
          ),
        );
      case 'archive':
        await _applyConversationAction(
          () => ref
              .read(conversationsRepositoryProvider)
              .setArchived(
                kind: discussion.kind,
                id: id,
                archived: !discussion.isArchived,
              ),
          // Désarchiver hors ligne n'a rien à montrer ici : la liste des
          // archives n'est pas gardée sur l'appareil.
          whenQueued: discussion.isArchived
              ? null
              : () => _showQueued(discussion.kind, id, remove: true),
        );
      case 'mute':
        if (discussion.isMuted) {
          await _applyConversationAction(
            () => ref
                .read(conversationsRepositoryProvider)
                .mute(kind: discussion.kind, id: id, durationSeconds: null),
            whenQueued: () =>
                _showQueued(discussion.kind, id, fields: {'is_muted': false}),
          );
        } else {
          await _pickMuteDuration(discussion.kind, id);
        }
      case 'tag':
        await _pickPriorityTag(contactId: id, displayName: discussion.name);
      case 'block':
        await _confirmBlock(discussion);
    }
  }

  /// Durées de WhatsApp : 8h, 1 semaine, toujours (~100 ans, voir
  /// MUTE_FOREVER_SECONDS côté API — pas de colonne booléenne séparée,
  /// `muted_until` étant déjà une date).
  Future<void> _pickMuteDuration(String kind, int id) async {
    final seconds = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(L.of(context).chatsMute8h),
              onTap: () => Navigator.pop(sheetContext, 28800),
            ),
            ListTile(
              title: Text(L.of(context).chatsMute1w),
              onTap: () => Navigator.pop(sheetContext, 604800),
            ),
            ListTile(
              title: Text(L.of(context).chatsMuteAlways),
              onTap: () => Navigator.pop(sheetContext, 3155760000),
            ),
          ],
        ),
      ),
    );
    if (seconds == null) return;
    await _applyConversationAction(
      () => ref
          .read(conversationsRepositoryProvider)
          .mute(kind: kind, id: id, durationSeconds: seconds),
      whenQueued: () => _showQueued(kind, id, fields: {'is_muted': true}),
    );
  }

  Future<void> _confirmBlock(ConversationSummary discussion) async {
    final contactUserId = discussion.contactUserId;
    if (contactUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).chatsBlockTitle(discussion.name)),
        content: Text(L.of(context).chatsBlockBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).chatsBlock),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _applyConversationAction(() async {
      await ref
          .read(conversationsRepositoryProvider)
          .setBlocked(contactUserId: contactUserId, blocked: true);
      return false;
    });
  }

  /// Inconnu qui m'a écrit : pas de ligne Contact tant qu'on n'a pas choisi
  /// de l'ajouter, donc pas d'épingle/archive/sourdine à proposer — juste de
  /// quoi le faire entrer dans le carnet, ou couper court.
  Future<void> _openUnknownContactMenu(ConversationSummary discussion) async {
    final contactUserId = discussion.contactUserId;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Un bot n'a pas de numéro : rien à mettre dans un carnet.
            if (!discussion.isBot)
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined),
                title: Text(L.of(context).chatsAddContact),
                onTap: () => Navigator.pop(sheetContext, 'add'),
              ),
            if (contactUserId != null)
              ListTile(
                leading: const Icon(
                  Icons.block,
                  color: AppColors.semanticError,
                ),
                title: Text(
                  L.of(context).chatsBlock,
                  style: const TextStyle(color: AppColors.semanticError),
                ),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'add') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddContactScreen()));
      ref.invalidate(contactsProvider);
      ref.invalidate(discussionsProvider);
      return;
    }
    if (action == 'block' && contactUserId != null) {
      await _applyConversationAction(() async {
        await ref
            .read(conversationsRepositoryProvider)
            .setBlocked(contactUserId: contactUserId, blocked: true);
        return false;
      });
    }
  }

  /// Un réglage hors ligne attend la reconnexion (voir
  /// core/sync/queued_mutation.dart) : on le reporte sur la liste gardée pour
  /// que le geste se voie tout de suite.
  Future<void> _showQueued(
    String kind,
    int id, {
    Map<String, dynamic> fields = const {},
    bool remove = false,
  }) => applyQueuedDiscussionSetting(
    ref.read(pokouMessageStoreProvider),
    kind: kind,
    id: id,
    fields: fields,
    remove: remove,
  );

  /// [action] renvoie `true` quand le geste attend le réseau ; [whenQueued]
  /// l'affiche alors sans attendre le serveur.
  Future<void> _applyConversationAction(
    Future<bool> Function() action, {
    String? conflictMessage,
    Future<void> Function()? whenQueued,
  }) async {
    try {
      final queued = await action();
      if (queued) await whenQueued?.call();
      // ── LES DEUX listes, pas seulement la principale ─────────────────
      //
      // Seule `discussionsProvider` était invalidée. Archiver faisait donc
      // bien disparaître la conversation de la liste courante, mais la
      // ligne « Archivées (N) » gardait son ancien compte et l'ancien
      // contenu : il fallait quitter l'onglet et y revenir pour que
      // l'`autoDispose` relâche le provider et le relise. Le geste
      // semblait n'avoir qu'à moitié pris.
      //
      // Les deux listes sont invalidées pour TOUTES les actions du menu, et
      // pas seulement pour « archiver » : épingler, mettre en sourdine ou
      // bloquer une conversation DÉJÀ archivée change aussi ce que cette
      // seconde liste affiche. Le coût est d'une requête sur un geste rare,
      // et de toute façon la liste des archives est courte.
      ref.invalidate(discussionsProvider);
      ref.invalidate(archivedDiscussionsProvider);
    } on ApiException catch (exc) {
      if (!mounted) return;
      final message = exc.statusCode == 409 && conflictMessage != null
          ? conflictMessage
          : exc.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).chatsActionFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussionsAsync = ref.watch(discussionsProvider);
    final myUserId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Écrire à un numéro sans l'enregistrer d'abord. Le geste manquait
      // entièrement : on ne pouvait ouvrir une discussion que depuis une
      // fiche du carnet, donc jamais avec un numéro qu'on vient de lire.
      // Relevé au-dessus de la barre de navigation, qui est pleine largeur
      // et collée au bord. Posé à sa hauteur par défaut, le bouton venait
      // se confondre avec elle et se lisait comme un sixième onglet mal
      // aligné. La marge se CALCULE — hauteur standard de la barre plus la
      // zone sûre du bas — au lieu d'être un nombre écrit à la main : la
      // zone sûre vaut 0 sur un appareil à bouton physique et une trentaine
      // de points sur un écran à encoche, et une constante serait juste sur
      // l'un des deux.
      body: RefreshIndicator(
        onRefresh: () async {
          await forceContactSync(ref);
          ref.invalidate(contactsProvider);
          ref.invalidate(discussionsProvider);
          // Les archives aussi : quand la vue affiche les archivées, c'est
          // précisément celles-là qu'on demande à relire en tirant.
          ref.invalidate(archivedDiscussionsProvider);
          ref.invalidate(statusFeedProvider);
          ref.invalidate(discoveryProductsProvider);
          await ref.read(discussionsProvider.future);
        },
        child: Column(
          children: [
            // L'en-tête partagé : titre en Outfit et ligne de statut. Il
            // remplace un titre posé à même le canevas, qui ne disait rien
            // de l'état de la connexion — l'information la plus utile à
            // afficher en permanence sur ce marché.
            PokouAppBar(
              title: L.of(context).contactsTitle,
              actions: [
                // Les modules AVANT les listes de diffusion : c'est la
                // porte d'entrée de tout ce que l'application peut
                // devenir, alors que la diffusion est un outil parmi
                // d'autres. L'ordre de gauche à droite dit lequel compte.
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ModulesScreen()),
                  ),
                  icon: Icon(
                    Icons.apps_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: L.of(context).navModules,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BroadcastListsScreen(),
                    ),
                  ),
                  icon: Icon(
                    Icons.campaign_outlined,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: L.of(context).navBroadcasts,
                ),
                // L'avatar mène au PROFIL. Il n'était que décoratif, et le
                // profil avait son propre onglet. Sans ce geste, l'écran
                // deviendrait INATTEIGNABLE.
                Semantics(
                  button: true,
                  label: L.of(context).navProfile,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: ContactAvatar(
                      avatar: ref.watch(authControllerProvider).user?.avatar,
                      displayName:
                          ref.watch(authControllerProvider).user?.displayName ??
                          L.of(context).callYou,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
            // Maquette « Discussions » : recherche en pastille blanche et
            // « + » terracotta (nouvelle discussion), PUIS la bande des
            // statuts, puis les filtres.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppElevation.subtle,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: L.of(context).chatsSearchHint,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: L.of(context).newChatTitle,
                    child: Material(
                      color: AppColors.accentPrimary,
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: const Color(0x1A1A1615),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewChatScreen(),
                          ),
                        ),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const DiscoveryStrip(),
            _ChatFilterRow(
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  MediaQuery.paddingOf(context).bottom + 96,
                ),
                children: [
                  const _PinnedMahizuTile(),
                  const SizedBox(height: 12),
                  // Plus de sections « Communautés » et « Groupes » au-dessus
                  // de la liste : les deux sont désormais des LIGNES de cette
                  // liste, triées avec le reste par activité. Les garder en
                  // haut faisait figurer les mêmes conversations deux fois,
                  // et poussait la liste — l'écran principal — sous la ligne
                  // de flottaison.
                  //
                  // Ce qu'elles portaient d'irremplaçable a suivi : créer un
                  // groupe ou une communauté, et rejoindre par lien, vivent
                  // maintenant en tête de « Nouvelle discussion ».
                  discussionsAsync.when(
                    // Pendant l'attente du serveur, on montre la liste
                    // telle qu'on l'a laissée. C'est ce qui rend
                    // l'ouverture souple : les conversations sont sur
                    // l'appareil depuis le lancement précédent, les lire
                    // prend quelques millisecondes, et rien ne justifie de
                    // faire regarder un rond qui tourne pendant tout un
                    // aller-retour réseau — plusieurs secondes sur un
                    // mauvais réseau. Le rond ne reste que pour la toute
                    // première ouverture, quand il n'y a effectivement
                    // rien à montrer.
                    loading: () => ref
                        .watch(cachedDiscussionsProvider)
                        .maybeWhen(
                          data: (cached) => cached.isEmpty
                              ? const _DiscussionsSpinner()
                              : _discussionList(cached, myUserId),
                          orElse: () => const _DiscussionsSpinner(),
                        ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          error is ApiException
                              ? error.message
                              : L.of(context).chatsConnectFailed,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    data: (allDiscussions) => allDiscussions.isEmpty
                        ? _ChatsEmptyState(myUserId: myUserId)
                        : _discussionList(allDiscussions, myUserId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La liste elle-même, tirée de la même fonction que les données soient
  /// fraîches ou issues du cache : deux rendus séparés finiraient par
  /// diverger, et l'écran d'attente cesserait de ressembler à l'écran final
  /// — ce qui produirait exactement le saut qu'on cherche à supprimer.
  Widget _discussionList(
    List<ConversationSummary> allDiscussions,
    int? myUserId,
  ) {
    // Filtre par nom : le seul champ qu'on a systématiquement pour un
    // inconnu qui a écrit (pas de `phone` exposé côté liste pour lui,
    // contrairement à un PokouContact).
    // ARCHIVER doit se voir.
    //
    // La liste principale ne contient AUCUNE archivée : `GET /conversations`
    // filtre par `archived`, qui vaut `false` par défaut. Les filtrer ici
    // ne servait donc à rien — elles n'y sont jamais. Elles viennent d'un
    // provider dédié, et se rangent derrière une ligne repliée qui les
    // compte, comme dans toutes les messageries.
    final archivees =
        ref.watch(archivedDiscussionsProvider).valueOrNull ?? const [];
    final filtrees = _filter.apply(_showArchived ? archivees : allDiscussions);
    final discussions = _query.isEmpty
        ? filtrees
        : filtrees.where((d) => d.name.toLowerCase().contains(_query)).toList();
    if (discussions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            L.of(context).chatsNoResult,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: [
        // La ligne des archivées, en tête et repliée. Absente quand il n'y
        // a rien à ranger — une ligne qui annonce zéro élément occupe de la
        // place pour dire qu'il ne se passe rien.
        // Les invitations de groupe en tête : elles n'ont que 72 heures, et
        // rangées derrière un onglet elles seraient vues le quatrième jour —
        // c'est-à-dire jamais. La section s'efface d'elle-même quand il n'y
        // a plus rien à décider.
        const GroupInvitationsSection(),
        if (archivees.isNotEmpty)
          _ArchivedRow(
            count: archivees.length,
            open: _showArchived,
            onTap: () => setState(() => _showArchived = !_showArchived),
          ),
        for (final discussion in discussions) ...[
          _DiscussionTile(
            discussion: discussion,
            myUserId: myUserId,
            onLongPress: () => _openDiscussionMenu(discussion),
          ),

          // Filet fin plutôt qu'un blanc de 10px : deux conversations
          // restent distinctes en occupant moins de place. En retrait des
          // bords (comme les séparateurs de listes groupées) et absent
          // après la dernière ligne, où il ne séparerait rien.
        ],
        // Le pied de liste rappelle le chiffrement.
        //
        // Il ne parle QUE des conversations à deux, parce que ce sont les
        // seules qui le sont. La maquette ajoute « Serveurs décentralisés
        // Ouest-Africains » : je ne l'ai pas repris — l'infrastructure n'est
        // pas décentralisée, et l'écrire serait une affirmation fausse sur
        // le point où le produit se juge.
        const SizedBox(height: 22),
        _EncryptionFooter(),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Le rappel de chiffrement, en bas de la liste.
class _EncryptionFooter extends StatelessWidget {
  const _EncryptionFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.enhanced_encryption_outlined,
            size: 14,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              L.of(context).chatsEncryptionFooter,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'avatar d'une conversation, avec la pastille qui dit SON TYPE.
///
/// ── Ce que la pastille montre, et ce qu'elle ne montre pas ───────────
///
/// La maquette pose un CADENAS sur les conversations à deux, pour dire
/// qu'elles sont chiffrées. Je ne l'ai pas repris : la liste ne sait pas si
/// une conversation l'est. Le chiffrement dépend du trousseau du
/// correspondant, que seul l'écran de conversation vérifie — et
/// `ConversationSummary` ne porte pas l'information.
///
/// Dessiner un cadenas sans le savoir serait affirmer la promesse centrale
/// du produit sur la foi d'un type de ligne. C'est exactement ce que le
/// reste du code refuse de faire : `encryption_banner.dart` n'affiche rien
/// tant que le contrôle n'a pas abouti.
///
/// Restent le GROUPE et la COMMUNAUTÉ, qui se lisent dans `kind` et qui
/// sont vrais.
class _AvatarWithKind extends StatelessWidget {
  const _AvatarWithKind({required this.discussion});

  final ConversationSummary discussion;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = switch (discussion.kind) {
      'group' => (Icons.groups, AppColors.chatAiLinkColor),
      'community' => (Icons.diversity_3, AppColors.chatAiLinkColor),
      _ => (null, AppColors.textMuted),
    };

    // `IdentityAvatar` et non `ContactAvatar` : c'est lui qui porte
    // l'anneau « statut non vu » et le point de présence, à partir des
    // mêmes sources que partout ailleurs (voir core/identity/).
    //
    // `userId` reste nul pour un groupe ou une communauté : ce ne sont pas
    // des personnes, elles n'ont ni statut ni présence.
    final avatar = IdentityAvatar(
      userId: discussion.kind == 'contact' ? discussion.contactUserId : null,
      avatar: discussion.avatar,
      displayName: discussion.displayName,
      size: 48,
    );
    if (icone == null) return avatar;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icone, size: 11, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le rond qui tourne — réservé à la toute première ouverture, quand
/// l'appareil n'a encore rien à montrer.
class _DiscussionsSpinner extends StatelessWidget {
  const _DiscussionsSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Une ligne de l'écran d'accueil — contact ou groupe, avec aperçu du
/// dernier message, façon WhatsApp. Widget à part (et non inline dans le
/// ListView) : la logique de tap diffère selon `kind`/`isUnknownContact`,
/// et l'isoler évite un `itemBuilder` illisible.
/// Ce qu'on montre quand la liste est vide — et ce n'est pas une phrase.
///
/// Un nouvel arrivant ne doit jamais se retrouver devant un écran qui ne
/// propose rien. Mais « vide » recouvre deux situations très différentes,
/// et les traiter pareil rate la moitié des gens :
///
/// - **son réseau est déjà là**, il n'a simplement jamais écrit. Lui dire
///   « invitez vos amis » est absurde : ils y sont. Ce qu'il faut, c'est
///   raccourcir le chemin jusqu'au premier message — voir un nom, toucher,
///   écrire ;
/// - **personne de son carnet n'est sur Pokou**. Lui montrer une liste
///   vide de contacts ne l'avance pas ; il lui faut inviter, ou trouver
///   autre chose à lire en attendant qu'on lui réponde.
///
/// Le seuil à franchir est court et il est toujours le même : voir
/// quelqu'un → ouvrir → envoyer. Tout ce qui s'intercale coûte un
/// utilisateur.
class _ChatsEmptyState extends ConsumerWidget {
  const _ChatsEmptyState({required this.myUserId});

  final int? myUserId;

  /// Combien de contacts proposer avant de renvoyer vers la liste complète.
  ///
  /// Assez pour reconnaître quelqu'un, pas assez pour avoir à choisir : une
  /// liste de trente noms redevient un annuaire, c'est-à-dire le problème
  /// qu'on essaie d'éviter.
  static const _shortlist = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final contacts = ref.watch(contactsProvider);

    return contacts.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      // Le carnet n'a pas pu être lu : on retombe sur l'invitation, qui
      // reste vraie dans tous les cas.
      error: (_, _) => _NoNetworkYet(),
      data: (all) {
        final reachable = all
            .where((contact) => contact.contactUserId != null)
            .take(_shortlist)
            .toList();
        if (reachable.isEmpty) return _NoNetworkYet();

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.chatsStartTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.chatsStartBody,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final contact in reachable)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  leading: IdentityAvatar(
                    userId: contact.contactUserId,
                    avatar: contact.avatar,
                    displayName: contact.displayName,
                    size: 44,
                  ),
                  title: VerifiedName(
                    name: contact.displayName,
                    isVerified: contact.isVerified,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  // Un tap, une conversation. Pas de feuille intermédiaire,
                  // pas de confirmation : c'est le seuil qu'on veut le plus
                  // court possible.
                  onTap: myUserId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              myUserId: myUserId!,
                              contactUserId: contact.contactUserId!,
                              contactName: contact.displayName,
                            ),
                          ),
                        ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NewChatScreen()),
                  ),
                  child: Text(l.chatsSeeAllContacts),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Personne du carnet n'est encore sur Pokou.
///
/// Deux portes, et pas une seule : inviter demande d'attendre une réponse
/// qui peut ne jamais venir, et un compte qui ne sert à rien le jour de son
/// installation ne se rouvre pas. Suivre une chaîne donne une raison de
/// revenir entre-temps.
class _NoNetworkYet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(Icons.group_add_outlined, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            l.chatsNoNetworkTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l.chatsNoNetworkBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => InviteSharing.share(context),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: Text(l.chatsInviteContacts),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChannelSearchScreen()),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: Text(l.chatsDiscoverChannels),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussionTile extends ConsumerWidget {
  const _DiscussionTile({
    required this.discussion,
    required this.myUserId,
    required this.onLongPress,
  });

  final ConversationSummary discussion;
  final int? myUserId;
  final VoidCallback onLongPress;

  /// Ouvre la conversation touchée.
  ///
  /// Le `return` muet sur `myUserId == null` était le symptôme signalé :
  /// toucher une ligne ne produisait RIEN — ni écran, ni requête, ni
  /// message. On retente donc de charger le profil, et si ça ne suffit pas,
  /// on le dit. Un geste sans réponse laisse croire que l'application est
  /// figée.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var userId = myUserId;
    if (userId == null) {
      final messenger = ScaffoldMessenger.of(context);
      final failed = L.of(context).chatsProfileMissing;
      userId =
          (await ref.read(authControllerProvider.notifier).ensureProfile())?.id;
      if (userId == null) {
        messenger.showSnackBar(SnackBar(content: Text(failed)));
        return;
      }
      if (!context.mounted) return;
    }
    _openWith(context, userId);
  }

  void _openWith(BuildContext context, int myUserId) {
    // Une communauté s'OUVRE sur ses groupes : elle n'a pas de fil à elle.
    // C'est ce qui justifie que ses groupes n'apparaissent pas séparément
    // dans la liste — ils sont ici, et nulle part ailleurs.
    if (discussion.isCommunity) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: discussion.id!,
            myUserId: myUserId,
          ),
        ),
      );
      return;
    }
    if (discussion.kind == 'group') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupConversationScreen(
            myUserId: myUserId,
            groupId: discussion.id!,
            groupName: discussion.name,
          ),
        ),
      );
      return;
    }
    final contactUserId = discussion.contactUserId;
    if (contactUserId == null) {
      // Deuxième `return` muet du même genre : une ligne de contact sans
      // `contact_user_id` ne peut pas s'ouvrir, et ne disait rien non plus.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).chatsProfileMissing)),
      );
      return;
    }
    // Fonctionne aussi pour un inconnu (`id == null`) : GET /messages/{id}
    // n'exige que d'être authentifié, pas d'avoir cette personne en contact
    // (voir api/app/routes/messages.py::get_conversation).
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: myUserId,
          contactUserId: contactUserId,
          contactName: discussion.name,
        ),
      ),
    );
  }

  /// Motifs numériques uniquement — le reste de l'app ne charge pas les
  /// données de locale (`initializeDateFormatting`), un motif à mois nommé
  /// lèverait une exception à l'exécution (voir devices_screen.dart pour la
  /// même contrainte).
  String _timeLabel(BuildContext context, DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final jour = DateTime(local.year, local.month, local.day);
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final ecart = aujourdhui.difference(jour).inDays;

    // AUJOURD'HUI : l'heure. HIER : le mot. CETTE SEMAINE : le jour.
    // AU-DELÀ : la date.
    //
    // La liste n'affichait que deux formes — l'heure, ou `12/9/2026`. Or
    // « 24/9 » ne dit rien : il faut compter pour savoir si c'était hier.
    // Le mot et le jour de la semaine se lisent sans calcul, et c'est
    // exactement la fenêtre où l'on cherche une conversation récente.
    if (ecart == 0) return DateFormat.Hm().format(local);
    if (ecart == 1) return L.of(context).dayYesterday;
    if (ecart < 7) {
      final locale = Localizations.localeOf(context).toString();
      // `E` rend le jour abrégé DANS LA LANGUE COURANTE. Un motif écrit à
      // la main aurait figé le français.
      return DateFormat.E(locale).format(local);
    }
    return DateFormat('d/M/y').format(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(typingProvider);
    final last = discussion.lastMessage;
    final groupWord = discussion.groupCount > 1 ? 'groupes' : 'groupe';
    // « écrit… » remplace l'aperçu tant que quelqu'un tape : c'est
    // l'information la plus récente de cette ligne, et la seule qui périme.
    final typingName = discussion.kind == 'contact'
        ? (discussion.contactUserId == null
              ? null
              : typing.nameFor('contact', discussion.contactUserId!))
        : typing.nameFor(discussion.kind, discussion.id ?? -1);
    final preview = typingName != null
        // En groupe on nomme qui écrit, en 1:1 c'est inutile : on sait déjà
        // de qui il s'agit, c'est le titre de la ligne.
        ? (discussion.kind == 'contact'
              ? L.of(context).contactsTyping
              : L.of(context).contactsTypingNamed(typingName))
        : last == null
        ? (discussion.isCommunity
              // Une communauté sans message dit ce qu'elle CONTIENT : c'est
              // la seule information utile tant que personne n'y a écrit.
              ? '${discussion.groupCount} $groupWord'
              : discussion.kind == 'group'
              ? 'Aucun message pour l\'instant'
              : '')
        : (discussion.kind == 'group' || discussion.isCommunity) && !last.isMine
        // En groupe, l'auteur précède le message (comme WhatsApp) — en
        // 1:1 ce serait redondant, on sait déjà qui parle.
        ? L
              .of(context)
              .contactsPreviewSender(
                last.senderName ?? L.of(context).convSomeone,
                last.displayTextOf(L.of(context)),
              )
        : last.isMine
        ? L.of(context).contactsPreviewMine(last.displayTextOf(L.of(context)))
        : last.displayTextOf(L.of(context));

    // Maquette Stitch « Discussions » : chaque fil est une carte blanche
    // (rounded-xl, p-3.5, ombre d'un point) posée sur le fond crème.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        shadowColor: AppColors.shadowTint,
        elevation: 0.6,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () => _open(context, ref),
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarWithKind(discussion: discussion),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            // `VerifiedName` et non `Text` : le badge se pose
                            // ici, avec le nom, pour qu'un nom trop long perde
                            // ses dernières lettres et JAMAIS son badge — sinon
                            // la certification disparaîtrait précisément pour
                            // les noms longs, sans que rien ne l'explique.
                            child: VerifiedName(
                              name: discussion.displayName,
                              isVerified: discussion.isVerified,
                              isBot: discussion.isBot,
                              maxLines: 1,
                              // Outfit 15,5/700.
                              //
                              // Le système dit 18, et c'était trop : à cette
                              // taille, les noms écrasaient les aperçus et la
                              // liste devenait un empilement de titres. La
                              // maquette a des noms courts dans une colonne
                              // large ; une vraie liste a « Coopérative des
                              // Maraîchers de Tsévié » et l'heure sur la même
                              // ligne.
                              //
                              // La hiérarchie avec l'aperçu se joue de toute
                              // façon sur la POLICE autant que sur la taille :
                              // Outfit pour le nom, Inter pour ce qui suit.
                              // Jeton « title » des maquettes : Inter 17/600.
                              style: TextStyle(
                                fontSize: 17,
                                height: 24 / 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (discussion.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.push_pin,
                              size: 15,
                              color: AppColors.accentPrimary,
                            ),
                          ],
                          if (last != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _timeLabel(context, last.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.2,
                                // Vert quand il reste des non-lus : l'heure
                                // devient alors un signal d'état, pas une simple
                                // métadonnée — c'est le même vert que la pastille
                                // juste en dessous.
                                color: discussion.unreadCount > 0
                                    ? AppColors.accentPrimary
                                    : AppColors.textSecondary,
                                fontWeight: discussion.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (discussion.isMuted) ...[
                            Icon(
                              Icons.notifications_off,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              // Un bot n'est pas « pas dans vos contacts » : on
                              // ne l'ajoute pas à un carnet, il n'a pas de numéro.
                              discussion.isUnknownContact && !discussion.isBot
                                  ? L.of(context).contactsNotInContacts(preview)
                                  : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                // Vert pendant la frappe : c'est un état vivant,
                                // pas un aperçu de plus. Le même vert que la
                                // pastille de non-lus, pour la même raison — il
                                // signale que quelque chose bouge maintenant.
                                // body-sm : 14/20 ; encre pleine quand il reste
                                // des non-lus, taupe sinon (maquette).
                                color: typingName != null
                                    ? AppColors.accentPrimary
                                    : discussion.unreadCount > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight:
                                    typingName != null ||
                                        discussion.unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (discussion.unreadCount > 0)
                            _UnreadBadge(count: discussion.unreadCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      margin: const EdgeInsets.only(left: 6),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        // Pastille de non-lus : vert d'action. Elle ne décore pas, elle
        // réclame — c'est le même vert que le bouton d'envoi, et c'est
        // voulu.
        color: AppColors.accentPrimary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Épinglé en haut de l'onglet Contacts — donne accès au(x) moniteur(s)
/// (Smart Contacts) liés au numéro de l'utilisateur, sans dédier un onglet
/// "IA" séparé pour y accéder. S'il y a plusieurs moniteurs connectés, un
/// petit tiroir permet de choisir lequel ouvrir.
class _PinnedMahizuTile extends ConsumerWidget {
  const _PinnedMahizuTile();

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    MinouStatus status;
    try {
      // /minou/status et non la liste des moniteurs POSSÉDÉS : on peut être
      // destinataire des alertes d'un moniteur sans en posséder aucun (le
      // cas de l'employé dont le numéro est déclaré). Interroger la
      // propriété seule l'aurait renvoyé vers la messagerie de Baba alors
      // qu'il a des alertes à lire.
      status = await ref.read(minouStatusProvider.future);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).chatsConnectFailed)),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final monitors = status.monitors;
    if (status.mode == MinouMode.messaging || monitors.isEmpty) {
      // Numéro rattaché à aucun moniteur : c'est la vraie messagerie de Baba
      // qui s'ouvre (kNoMonitor = sentinelle locale « aucun moniteur », voir
      // ChatController).
      context.push('/chat/$kNoMonitor', extra: L.of(context).navBaba);
      return;
    }

    if (monitors.length == 1) {
      context.push('/chat/${monitors.first.id}', extra: monitors.first.name);
      return;
    }

    final chosen = await showModalBottomSheet<MinouMonitor>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.of(context).profileChooseMonitor,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final monitor in monitors)
              ListTile(
                leading: const AssistantOrb(size: 32),
                title: Text(monitor.name),
                subtitle: Text(
                  monitor.intention,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, monitor),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      context.push('/chat/${chosen.id}', extra: chosen.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: AppRadius.card,
      onTap: () => _open(context, ref),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.accentPrimaryLight.withValues(alpha: 0.18),
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: [
            const AssistantOrb(size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baba porte TOUJOURS son badge : c'est l'assistant de
                  // Pokou, pas un contact qu'on pourrait confondre.
                  Row(
                    children: [
                      Text(
                        L.of(context).navBaba,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 15),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L.of(context).contactsAssistantSub,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.push_pin, size: 16, color: AppColors.accentPrimaryDark),
          ],
        ),
      ),
    );
  }
}

/// Les trois filtres de la liste des discussions.
///
/// Chacun s'appuie sur une donnée qui EXISTE déjà — `unreadCount`, `kind` —
/// et aucun n'a demandé de champ nouveau. La maquette en propose un
/// quatrième, « Commandes Marché », qui supposerait de relier une
/// conversation à une commande : il n'y a rien côté serveur pour ça, et un
/// filtre qui ne rend jamais rien est pire que pas de filtre.
enum ChatFilter {
  all,
  unread,
  favorites,
  groups;

  List<ConversationSummary> apply(List<ConversationSummary> items) =>
      switch (this) {
        ChatFilter.all => items,
        ChatFilter.unread => items.where((d) => d.unreadCount > 0).toList(),
        ChatFilter.favorites => items.where((d) => d.isPinned).toList(),
        // Les communautés comptent comme des groupes : pour qui filtre, la
        // distinction entre « groupe » et « communauté » n'existe pas — il
        // cherche ce qui n'est pas une conversation à deux.
        ChatFilter.groups => items.where((d) => d.kind != 'contact').toList(),
      };

  String labelOf(L l) => switch (this) {
    ChatFilter.all => l.chatsFilterAll,
    ChatFilter.unread => l.chatsFilterUnread,
    ChatFilter.favorites => l.assimeFavorites,
    ChatFilter.groups => l.chatsFilterGroups,
  };
}

class _ChatFilterRow extends ConsumerWidget {
  const _ChatFilterRow({required this.current, required this.onChanged});

  final ChatFilter current;
  final ValueChanged<ChatFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Le compte des non-lues s'affiche DANS la puce, comme la maquette le
    // montre. Il vient de la liste réelle, pas d'un compteur à part : deux
    // sources donneraient deux chiffres différents un jour ou l'autre.
    final nonLues =
        ref
            .watch(discussionsProvider)
            .valueOrNull
            ?.where((d) => d.unreadCount > 0)
            .length ??
        0;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        children: [
          for (final f in ChatFilter.values) ...[
            _FilterChip(
              label: f == ChatFilter.unread && nonLues > 0
                  ? '${f.labelOf(l)} ($nonLues)'
                  : f.labelOf(l),
              selected: f == current,
              onTap: () => onChanged(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        // Maquette : h-8, pastille ; active terracotta-100 / -700, inactive
        // beige-100 / taupe-600.
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.terracottaTint
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? AppElevation.subtle : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppColors.onTerracottaTint
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// La ligne « Discussions archivées », en tête de liste.
///
/// Une CARTE et non une ligne de liste : elle n'est pas une conversation,
/// et lui donner la même apparence la ferait toucher par erreur. Le compte
/// est à droite, dans une pastille — c'est la seule information utile avant
/// de l'ouvrir.
class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        borderRadius: AppRadius.chip,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.chip,
            boxShadow: AppElevation.subtle,
          ),
          child: Row(
            children: [
              Icon(
                open ? Icons.unarchive_outlined : Icons.archive_outlined,
                size: 21,
                color: AppColors.accentPrimaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  L.of(context).chatsArchivedSection,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    // Chiffres alignés : deux lignes voisines ne doivent pas
                    // décaler leur pastille selon le chiffre affiché.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
