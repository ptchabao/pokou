import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../data/conversations_repository.dart';
import 'contacts_controller.dart';
import 'discussions_controller.dart';
import '../../../core/widgets/pokou_sheet.dart';

/// Les personnes que j'ai bloquées (GET /conversations/blocked).
final blockedContactsProvider =
    FutureProvider.autoDispose<List<BlockedContact>>(
      (ref) => ref.watch(conversationsRepositoryProvider).listBlocked(),
    );

/// Discussions · 27 — Contacts bloqués.
///
/// Écran AUTONOME : il s'ouvre depuis Réglages › Confidentialité comme
/// depuis la messagerie, sans rien attendre de qui le pousse.
///
/// Un inconnu bloqué apparaît sous son numéro MASQUÉ (« +228 9• •• •• 41 »),
/// tel que le serveur l'envoie : la messagerie n'affiche aucun numéro en
/// clair, même celui de quelqu'un qu'on a bloqué.
class BlockedContactsScreen extends ConsumerWidget {
  const BlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final blocked = ref.watch(blockedContactsProvider);
    final count = blocked.valueOrNull?.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.blockedTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (count != null)
              Text(
                l.blockedCount(count),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(blockedContactsProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    blocked.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            error is ApiException
                                ? error.message
                                : l.chatsConnectFailed,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                l.blockedEmpty,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : _BlockedCard(items: items),
                    ),
                    const SizedBox(height: 12),
                    _InfoNote(text: l.blockedInfo),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l.blockedGroupsNote,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _blockAContact(context, ref),
                  icon: const Icon(Icons.block, size: 18),
                  label: Text(l.blockedAdd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// « Bloquer un contact » : choisir dans le carnet.
  Future<void> _blockAContact(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final contacts = await ref.read(contactsProvider.future);
    final already = {
      for (final b in ref.read(blockedContactsProvider).valueOrNull ?? const [])
        b.contactUserId,
    };
    final candidates = [
      for (final c in contacts)
        if (c.contactUserId != null && !already.contains(c.contactUserId)) c,
    ];
    if (!context.mounted) return;
    final chosen = await showPokouSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l.blockedAdd,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final contact in candidates)
              ListTile(
                leading: ContactAvatar(
                  avatar: contact.avatar,
                  displayName: contact.displayName,
                  size: 40,
                ),
                title: Text(contact.displayName),
                onTap: () => Navigator.pop(sheetContext, contact.contactUserId),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await ref
          .read(conversationsRepositoryProvider)
          .setBlocked(contactUserId: chosen, blocked: true);
      ref.invalidate(blockedContactsProvider);
      ref.invalidate(discussionsProvider);
    } catch (exc) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            exc is ApiException ? exc.message : l.chatsActionFailed,
          ),
        ),
      );
    }
  }
}

class _BlockedCard extends ConsumerWidget {
  const _BlockedCard({required this.items});

  final List<BlockedContact> items;

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedContact contact,
  ) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(conversationsRepositoryProvider)
          .setBlocked(contactUserId: contact.contactUserId, blocked: false);
      ref.invalidate(blockedContactsProvider);
      ref.invalidate(discussionsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l.blockedUnblocked(contact.displayName))),
      );
    } catch (exc) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            exc is ApiException ? exc.message : l.chatsActionFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ContactAvatar(
                    avatar: items[i].avatar,
                    displayName: items[i].displayName,
                    size: 40,
                    // Un inconnu n'a pas d'initiales : une silhouette.
                    fallbackIcon: items[i].isUnknownContact
                        ? Icons.person_outline
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (items[i].blockedAt != null)
                          Text(
                            _blockedLine(l, items[i], locale),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _unblock(context, ref, items[i]),
                    child: Text(l.blockedUnblock),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _blockedLine(L l, BlockedContact contact, String locale) {
    final date = DateFormat.MMMd(locale).format(contact.blockedAt!.toLocal());
    return contact.afterReport
        ? l.blockedOnAfterReport(date)
        : l.blockedOn(date);
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: AppColors.accentPrimaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
