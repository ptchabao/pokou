import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/sharing/invite_sharing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../communities/presentation/communities_section.dart';
import '../../groups/presentation/create_group_screen.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../data/contact_model.dart';
import '../data/device_contacts_service.dart';
import 'contacts_controller.dart';
import 'join_by_link.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Ouvrir une discussion, ou créer un groupe.
///
/// L'écran répond à une seule intention — « je veux parler à quelqu'un » —
/// et lui donne trois réponses, dans l'ordre où on les cherche :
///
/// 1. **chercher**, en tête, parce qu'un répertoire de plusieurs milliers
///    d'entrées ne se parcourt pas au doigt. Le champ filtre les deux listes
///    en dessous, par nom comme par numéro ;
/// 2. **créer** un groupe ou une communauté — une autre façon de répondre à
///    la même intention, et qui n'avait sa place nulle part d'évident ;
/// 3. **ses contacts**, déjà sur Pokou ou à inviter. Le serveur ne peut PAS
///    répondre à la seconde question : il n'enregistre jamais un numéro non
///    inscrit. La liste se construit donc sur l'appareil, en retirant du
///    répertoire tout ce que le carnet Pokou connaît déjà.
///
/// La recherche par NUMÉRO a été retirée de cet écran. Écrire à quelqu'un
/// hors carnet reste possible côté serveur — `_require_reachable` accepte un
/// numéro prouvé (voir api/app/routes/messages.py) — mais plus aucun chemin
/// n'y mène ici.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _filterController = TextEditingController();

  /// Le filtre des listes, en minuscules et sans accents approximatifs.
  ///
  /// Un répertoire de plusieurs milliers d'entrées ne se parcourt pas au
  /// doigt : sans champ de recherche, la liste est techniquement présente et
  /// pratiquement inutilisable.
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  bool _matches(String name, String phone) {
    if (_filter.isEmpty) return true;
    return name.toLowerCase().contains(_filter) ||
        phone.replaceAll(RegExp(r'[^0-9+]'), '').contains(_filter);
  }

  void _openConversation({
    required int userId,
    required String name,
    String? phone,
  }) {
    final me = ref.read(authControllerProvider).user;
    if (me == null) return;
    if (userId == me.id) {
      // Ne devrait plus arriver depuis cet écran — on ne se liste pas
      // soi-même dans son propre carnet — mais l'ouverture reste refusée
      // plutôt que de laisser une conversation avec soi-même se créer.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).newChatOwnNumber)));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: me.id,
          contactUserId: userId,
          contactName: name,
          // Laissez-passer du premier message pour quelqu'un hors carnet :
          // sans lui, le serveur refuse d'écrire à un identifiant qu'on
          // pourrait avoir deviné.
          contactPhone: phone,
        ),
      ),
    );
  }

  /// Ouvre la feuille de partage du SYSTÈME, au lieu d'imposer WhatsApp.
  ///
  /// L'invitation partait par `wa.me`. Pour une application dont l'argument
  /// est précisément de ne plus dépendre de WhatsApp, exiger WhatsApp pour
  /// recruter était gênant — et ça excluait quiconque préfère Telegram, un
  /// SMS, Messenger ou un e-mail. Le système connaît les applications
  /// réellement installées bien mieux que nous.
  Future<void> _invite(String recipientName) =>
      InviteSharing.share(context, recipientName: recipientName);

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final invitableAsync = ref.watch(invitableContactsProvider);
    final me = ref.watch(authControllerProvider).user;

    final reachable = contactsAsync.maybeWhen(
      data: (contacts) => contacts
          .where(
            (c) => c.contactUserId != null && _matches(c.displayName, c.phone),
          )
          .toList(),
      orElse: () => const <PokouContact>[],
    );
    final invitable = invitableAsync.maybeWhen(
      data: (entries) =>
          entries.where((e) => _matches(e.name, e.phone)).toList(),
      orElse: () => const <DeviceContactEntry>[],
    );

    // `CustomScrollView` et des `SliverList.builder`, au lieu d'un `ListView`
    // dont les enfants étaient tous construits d'avance. Avec un répertoire
    // de plusieurs milliers d'entrées — le cas de nos utilisateurs
    // commerçants — l'ancienne forme instanciait des milliers de widgets à
    // chaque reconstruction, et l'écran se figeait à l'ouverture comme à
    // chaque frappe. Ici, seules les lignes visibles existent.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 20, 0),
                child: Row(
                  children: [
                    PokouBackButton(),
                    SizedBox(width: 4),
                    Text(
                      L.of(context).newChatTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Chercher dans ses contacts ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _filterController,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) =>
                      setState(() => _filter = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    hintText: L.of(context).newChatSearchHint,
                    hintStyle: const TextStyle(fontSize: 14),
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                            },

                            tooltip: L.of(context).actionClose,
                          ),
                  ),
                ),
              ),
            ),

            // ── Créer ─────────────────────────────────────────────────────
            if (me != null)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _CreateRow(
                      icon: Icons.group_add_outlined,
                      label: L.of(context).newChatNewGroup,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateGroupScreen(myUserId: me.id),
                        ),
                      ),
                    ),
                    _CreateRow(
                      icon: Icons.groups_outlined,
                      label: L.of(context).newChatNewCommunity,
                      onTap: () => showCreateCommunitySheet(
                        context,
                        ref,
                        myUserId: me.id,
                      ),
                    ),
                    // Une seule porte pour les deux : personne ne sait, en
                    // collant un lien, s'il mène à un groupe ou à une
                    // communauté. C'est le lien qui le dit.
                    _CreateRow(
                      icon: Icons.link,
                      label: L.of(context).newChatJoinByLink,
                      onTap: () =>
                          showJoinByLinkSheet(context, ref, myUserId: me.id),
                    ),
                  ],
                ),
              ),

            // ── Déjà sur Pokou ────────────────────────────────────────────
            if (contactsAsync.isLoading)
              const SliverToBoxAdapter(child: _SectionLoader())
            else if (reachable.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionLabel(
                  L.of(context).newChatOnPokou,
                  count: reachable.length,
                ),
              ),
              SliverList.builder(
                itemCount: reachable.length,
                itemBuilder: (_, index) {
                  final contact = reachable[index];
                  return _ContactRow(
                    name: contact.displayName,
                    subtitle: contact.phone,
                    avatar: contact.avatar,
                    onTap: () => _openConversation(
                      userId: contact.contactUserId!,
                      name: contact.displayName,
                      // Le numéro est déjà là, affiché juste en dessous.
                      // L'omettre faisait échouer le premier message quand
                      // la fiche existe sur le TÉLÉPHONE sans avoir de
                      // contrepartie côté serveur — ce qui est le cas tant
                      // que la synchronisation du carnet n'a pas eu lieu.
                      phone: contact.phone,
                    ),
                  );
                },
              ),
            ],

            // ── À inviter ─────────────────────────────────────────────────
            if (invitableAsync.isLoading)
              const SliverToBoxAdapter(child: _SectionLoader())
            else if (invitable.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionLabel(
                  L.of(context).newChatInvite,
                  count: invitable.length,
                ),
              ),
              SliverList.builder(
                itemCount: invitable.length,
                itemBuilder: (_, index) => _InvitableRow(
                  entry: invitable[index],
                  onInvite: () => _invite(invitable[index].name),
                ),
              ),
            ],

            if (_filter.isNotEmpty && reachable.isEmpty && invitable.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Text(
                    L.of(context).newChatNoMatch,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// Une entrée « créer » en tête de liste.
///
/// Ici plutôt que dans l'onglet Contacts : c'est l'écran qu'on ouvre quand
/// on veut parler à quelqu'un, et créer un groupe ou une communauté est une
/// autre réponse à la même intention.
class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le champ par numéro — volontairement discret.
///
/// Il était l'élément dominant de l'écran alors qu'il sert au cas RARE :
/// écrire à quelqu'un qu'on n'a pas dans son répertoire. Le cas courant, ce
/// sont les listes en dessous, qui ne demandent aucune saisie.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final MediaMeta? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: ContactAvatar(avatar: avatar, displayName: name, size: 40),
      title: Text(
        name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

/// Une personne du répertoire qui n'a pas encore Pokou.
///
/// « Inviter » est en VERT et non en gris : c'est une action, et la seule
/// possible sur cette ligne. Un gris la ferait lire comme un libellé d'état
/// — « non inscrit » — au lieu de quelque chose à toucher.
class _InvitableRow extends StatelessWidget {
  const _InvitableRow({required this.entry, required this.onInvite});

  final DeviceContactEntry entry;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onInvite,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: ContactAvatar(avatar: null, displayName: entry.name, size: 40),
      title: Text(
        entry.name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        entry.phone,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        L.of(context).newChatInviteAction,
        style: TextStyle(
          color: AppColors.accentPrimaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
