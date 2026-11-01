import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../groups/presentation/group_conversation_screen.dart';
import '../../marketplace/data/product_model.dart';
import '../../marketplace/presentation/product_detail_screen.dart';
import '../data/contact_profile_model.dart';
import 'profile_screen.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/verified_badge.dart';

/// Fiche contact, façon WhatsApp Business — accessible en tapant le nom ou
/// l'avatar dans l'en-tête d'une conversation : ce qu'on a échangé (médias,
/// documents, liens), ce qu'on a en commun (groupes), son catalogue, et les
/// actions qui le concernent (appeler, bloquer).
class ContactProfileScreen extends ConsumerStatefulWidget {
  const ContactProfileScreen({
    super.key,
    required this.contactUserId,
    required this.contactName,
  });

  final int contactUserId;
  final String contactName;

  @override
  ConsumerState<ContactProfileScreen> createState() =>
      _ContactProfileScreenState();
}

class _ContactProfileScreenState extends ConsumerState<ContactProfileScreen> {
  bool _loading = true;
  String? _error;
  ContactProfile? _profile;
  bool _togglingBlock = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getContactProfile(widget.contactUserId);
      if (mounted) setState(() => _profile = profile);
    } on ApiException catch (exc) {
      if (mounted) setState(() => _error = exc.message);
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).contactConnectFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call({required bool startWithVideo}) async {
    try {
      final token = await ref.read(callRepositoryProvider).startCall([
        widget.contactUserId,
      ], isVideo: startWithVideo);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: [widget.contactUserId],
            startWithVideo: startWithVideo,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).contactCallFailed)),
        );
      }
    }
  }

  Future<void> _toggleBlock() async {
    final profile = _profile;
    if (profile == null) return;
    final blocking = !profile.isBlocked;

    if (blocking) {
      // Confirmation seulement pour BLOQUER : débloquer est un geste sans
      // conséquence, le faire confirmer serait du bruit.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(L.of(context).contactBlockTitle(profile.displayName)),
          content: Text(L.of(context).contactBlockBody),
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
    }

    setState(() => _togglingBlock = true);
    try {
      await ref
          .read(conversationsRepositoryProvider)
          .setBlocked(contactUserId: widget.contactUserId, blocked: blocking);
      if (mounted) {
        setState(() => _profile = _copyWithBlocked(profile, blocking));
        // La liste de discussions masque les conversations bloquées : sans
        // cette invalidation, elle garderait celle-ci jusqu'au prochain
        // rafraîchissement manuel.
        ref.invalidate(discussionsProvider);
        ref.invalidate(contactsProvider);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).contactActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingBlock = false);
    }
  }

  ContactProfile _copyWithBlocked(ContactProfile profile, bool blocked) {
    return ContactProfile(
      userId: profile.userId,
      displayName: profile.displayName,
      phone: profile.phone,
      about: profile.about,
      avatar: profile.avatar,
      isBlocked: blocked,
      isContact: profile.isContact,
      isVerified: profile.isVerified,
      sharedMedia: profile.sharedMedia,
      sharedDocuments: profile.sharedDocuments,
      sharedLinks: profile.sharedLinks,
      commonGroups: profile.commonGroups,
      products: profile.products,
    );
  }

  /// Enregistrer depuis la fiche quelqu'un qui m'a écrit sans être dans mon
  /// carnet — typiquement un numéro gardé sans indicatif de part ou d'autre,
  /// que la synchronisation du répertoire n'a pas su rapprocher.
  Future<void> _saveContact() async {
    final profile = _profile;
    final phone = profile?.phone;
    if (profile == null || phone == null) return;
    final l = L.of(context);
    final controller = TextEditingController(text: profile.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.addContactTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(phone, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.addContactName),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l.addContactAction),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    try {
      await ref
          .read(contactsRepositoryProvider)
          .add(phone: phone, displayName: trimmed);
      if (!mounted) return;
      ref.invalidate(contactsProvider);
      ref.invalidate(discussionsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.contactSavedToast)));
      await _load();
    } on ApiException catch (exc) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exc.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.contactActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName = profile?.displayName ?? widget.contactName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(children: const [PokouBackButton(), Spacer()]),
                    const SizedBox(height: 8),
                    Center(
                      child: IdentityAvatar(
                        userId: widget.contactUserId,
                        avatar: profile?.avatar,
                        displayName: displayName,
                        size: 88,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (profile?.isVerified == true) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(size: 20),
                        ],
                      ],
                    ),
                    _ProLine(userId: widget.contactUserId),
                    if (profile?.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile!.phone!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.semanticError),
                      ),
                    ],
                    if (profile != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CircleAction(
                            icon: Icons.chat_bubble_outline,
                            label: L.of(context).mediaMessage,
                            // On REVIENT à la conversation d'où l'on vient
                            // plutôt que d'en empiler une seconde copie.
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 24),
                          _CircleAction(
                            icon: Icons.call_outlined,
                            label: L.of(context).contactCall,
                            onTap: () => _call(startWithVideo: false),
                          ),
                          const SizedBox(width: 24),
                          _CircleAction(
                            icon: Icons.videocam_outlined,
                            label: L.of(context).mediaVideo,
                            onTap: () => _call(startWithVideo: true),
                          ),
                          if (!profile.isContact && profile.phone != null) ...[
                            const SizedBox(width: 24),
                            _CircleAction(
                              icon: Icons.person_add_alt_1_outlined,
                              label: L.of(context).addContactAction,
                              onTap: _saveContact,
                            ),
                          ],
                        ],
                      ),
                      if (profile.about != null &&
                          profile.about!.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _Section(
                          title: L.of(context).profileAbout,
                          child: Text(
                            profile.about!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                      if (profile.hasSharedContent) ...[
                        const SizedBox(height: 16),
                        _SharedContentSection(profile: profile),
                      ],
                      if (profile.commonGroups.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CommonGroupsSection(groups: profile.commonGroups),
                      ],
                      if (profile.products.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ProductsSection(
                          products: profile.products,
                          sellerId: profile.userId,
                          sellerName: profile.displayName,
                        ),
                      ],
                      // Le blocage s'inscrit sur MA ligne de carnet
                      // (routes/conversations.py::set_blocked) : sans
                      // elle, le bouton n'aboutirait qu'à une erreur.
                      if (profile.isContact) ...[
                        const SizedBox(height: 16),
                        _BlockRow(
                          name: profile.displayName,
                          isBlocked: profile.isBlocked,
                          busy: _togglingBlock,
                          onToggle: _toggleBlock,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevated,
            ),
            child: Icon(icon, color: AppColors.accentPrimaryDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Médias / documents / liens échangés. Trois onglets comme dans WhatsApp :
/// les visuels se parcourent en grille, les documents et les liens en liste —
/// un seul tableau mélangé rendrait chaque recherche pénible.
class _SharedContentSection extends StatefulWidget {
  const _SharedContentSection({required this.profile});

  final ContactProfile profile;

  @override
  State<_SharedContentSection> createState() => _SharedContentSectionState();
}

class _SharedContentSectionState extends State<_SharedContentSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final tabs = [
      (L.of(context).contactSharedMedia, profile.sharedMedia.length),
      (L.of(context).contactSharedDocuments, profile.sharedDocuments.length),
      (L.of(context).contactSharedLinks, profile.sharedLinks.length),
    ];

    return _Section(
      title: L.of(context).contactSharedTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                _TabChip(
                  label: '${tabs[index].$1} (${tabs[index].$2})',
                  active: _tab == index,
                  onTap: () => setState(() => _tab = index),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          switch (_tab) {
            0 => _MediaGrid(items: profile.sharedMedia),
            1 => _DocumentList(items: profile.sharedDocuments),
            _ => _LinkList(links: profile.sharedLinks),
          },
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.accentPrimary : AppColors.surfaceElevated,
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<SharedAttachment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _EmptyHint(L.of(context).contactNoMedia);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (final item in items.take(12))
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AttachmentThumbnail(media: item.media),
                if (item.messageType == 'VIDEO')
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.items});

  final List<SharedAttachment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _EmptyHint(L.of(context).contactNoDocuments);
    return Column(
      children: [
        for (final item in items.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  item.messageType == 'AUDIO'
                      ? Icons.mic_none
                      : Icons.description_outlined,
                  size: 18,
                  color: AppColors.accentPrimaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.media.originalFilename ?? L.of(context).mediaDocument,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  formatBytes(item.media.sizeBytes),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkList extends StatelessWidget {
  const _LinkList({required this.links});

  final List<SharedLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return _EmptyHint(L.of(context).contactNoLinks);
    return Column(
      children: [
        for (final link in links.take(10))
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(link.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 18,
                    color: AppColors.accentPrimaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.host,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          link.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CommonGroupsSection extends ConsumerWidget {
  const _CommonGroupsSection({required this.groups});

  final List<CommonGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(authControllerProvider).user?.id;
    return _Section(
      title: L.of(context).contactCommonGroups(groups.length),
      child: Column(
        children: [
          for (final group in groups)
            InkWell(
              // Sans identité de session, on ne peut pas ouvrir la
              // conversation (elle a besoin de savoir qui « je » suis pour
              // distinguer mes bulles) — la ligne reste alors inerte.
              onTap: myUserId == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupConversationScreen(
                          myUserId: myUserId,
                          groupId: group.id,
                          groupName: group.name,
                        ),
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: AppColors.accentPrimaryDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${group.memberCount} membres',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({
    required this.products,
    required this.sellerId,
    required this.sellerName,
  });

  final List<ContactProduct> products;
  final int sellerId;
  final String sellerName;

  /// Le catalogue de la fiche contact est une vue allégée (ContactProduct) :
  /// elle n'a ni galerie ni réputation. On reconstruit donc l'objet complet
  /// attendu par la fiche produit à partir de ce qu'on sait, plutôt que de
  /// faire porter deux formes au même écran.
  MarketplaceProduct _toMarketplaceProduct(ContactProduct product) {
    return MarketplaceProduct(
      id: product.id,
      sellerId: sellerId,
      sellerName: sellerName,
      name: product.name,
      description: null,
      price: product.price,
      currency: product.currency,
      image: product.image,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: L.of(context).contactCatalog(products.length),
      child: Column(
        children: [
          for (final product in products)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: _toMarketplaceProduct(product),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (product.image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: _AttachmentThumbnail(media: product.image!),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: AppColors.accentPrimaryDark,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${product.price} ${product.currency}',
                      style: TextStyle(
                        color: AppColors.accentPrimaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.name,
    required this.isBlocked,
    required this.busy,
    required this.onToggle,
  });

  final String name;
  final bool isBlocked;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        leading: Icon(
          isBlocked ? Icons.lock_open_outlined : Icons.block,
          color: isBlocked ? AppColors.textSecondary : AppColors.semanticError,
        ),
        title: Text(
          isBlocked
              ? L.of(context).contactUnblockName(name)
              : L.of(context).contactBlockName(name),
          style: TextStyle(
            color: isBlocked ? AppColors.textPrimary : AppColors.semanticError,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isBlocked
              ? L.of(context).contactUnblockHint
              : L.of(context).contactBlockHint,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: busy ? null : onToggle,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
    );
  }
}

/// Pièce jointe servie par l'API authentifiée (pas d'URL publique), donc
/// résolue en fichier local par MediaRepository comme dans les bulles.
class _AttachmentThumbnail extends ConsumerWidget {
  const _AttachmentThumbnail({required this.media});

  final MediaMeta media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaImage.meta(
      media,
      // Pleine largeur : le palier 1080 suffit, l'original pèse dix fois plus.
      decodeWidth: 420,
      placeholder: ColoredBox(color: AppColors.surfaceElevated),
    );
  }
}


final _proBadgeProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, userId) async {
  try {
    return await ref.watch(apiClientProvider).get('/certified/profile/$userId') as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

/// Profil Pro (maquette Pro 5) : le nom commercial, puis « Géré par » et
/// le nom vérifié. Rien pour un profil qui n'est pas Pro.
class _ProLine extends ConsumerWidget {
  const _ProLine({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(_proBadgeProvider(userId)).valueOrNull;
    if (badge == null || badge['badge'] != 'PRO') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hexagon, size: 16, color: AppColors.accentPrimary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  badge['display_name'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (badge['managed_by'] != null)
            Text(
              L.of(context).proManagedBy(badge['managed_by'] as String),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
