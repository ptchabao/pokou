import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/providers.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/presentation/contacts_controller.dart';
import 'settings_widgets.dart';

/// Une personne bloquée, telle que `GET /conversations/blocked` la rend.
class BlockedContact {
  const BlockedContact({
    required this.contactUserId,
    required this.displayName,
    this.phone,
    this.avatar,
  });

  final int? contactUserId;
  final String displayName;
  final String? phone;
  final MediaMeta? avatar;

  factory BlockedContact.fromJson(Map<String, dynamic> json) => BlockedContact(
    contactUserId: json['contact_user_id'] as int?,
    displayName: json['display_name'] as String? ?? '',
    phone: json['phone'] as String?,
    avatar: json['avatar'] == null
        ? null
        : MediaMeta.fromJson(json['avatar'] as Map<String, dynamic>),
  );
}

/// Les personnes bloquées — le compteur « Bloqués (n) » de Confidentialité
/// et la liste de cet écran.
final blockedContactsProvider =
    FutureProvider.autoDispose<List<BlockedContact>>((ref) async {
      final json =
          await ref.watch(apiClientProvider).get('/conversations/blocked')
              as Map<String, dynamic>;
      return ((json['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BlockedContact.fromJson)
          .toList();
    });

/// Réglages › Confidentialité › Bloqués : la liste, et de quoi débloquer.
///
/// Une personne bloquée n'apparaît plus dans les discussions (voir
/// conversations.py::list_blocked) : sans cet écran, il n'y aurait aucun
/// chemin pour revenir sur un blocage.
class BlockedContactsScreen extends ConsumerWidget {
  const BlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final blocked = ref.watch(blockedContactsProvider);

    Future<void> unblock(BlockedContact contact) async {
      final id = contact.contactUserId;
      if (id == null) return;
      try {
        await ref
            .read(conversationsRepositoryProvider)
            .setBlocked(contactUserId: id, blocked: false);
        ref.invalidate(blockedContactsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.contactUnblockHint)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.privacySaveFailed)));
        }
      }
    }

    return SettingsScaffold(
      title: l.privacyBlocked,
      onRefresh: () async {
        ref.invalidate(blockedContactsProvider);
        await ref.read(blockedContactsProvider.future);
      },
      children: blocked.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (_, _) => [SettingsFootnote(l.errorNetwork)],
        data: (items) => items.isEmpty
            ? [SettingsFootnote(l.privacyBlockedEmpty)]
            : [
                SettingsCard(
                  children: [
                    for (final contact in items)
                      ListTile(
                        leading: ContactAvatar(
                          avatar: contact.avatar,
                          displayName: contact.displayName,
                          size: 36,
                        ),
                        title: Text(contact.displayName),
                        subtitle: contact.phone == null
                            ? null
                            : Text(contact.phone!),
                        trailing: TextButton(
                          onPressed: contact.contactUserId == null
                              ? null
                              : () => unblock(contact),
                          child: Text(l.privacyUnblock),
                        ),
                      ),
                  ],
                ),
                SettingsFootnote(l.privacyBlockedNote),
              ],
      ),
    );
  }
}

