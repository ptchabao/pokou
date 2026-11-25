import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/sync/media_sender.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/conversation_summary.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../groups/data/group_model.dart';
import '../../groups/presentation/group_controller.dart';
import '../data/direct_message_model.dart';
import 'messaging_controller.dart';

/// Discussions · 23 — Transférer à… (jusqu'à 5 discussions).
///
/// ── Pourquoi 5 ────────────────────────────────────────────────────────
///
/// La limite freine la rumeur qui se propage par transferts en chaîne,
/// comme chez WhatsApp. Le message transféré porte la mention « Transféré »,
/// puis « Transféré plusieurs fois » au-delà de 5 transferts de proche en
/// proche (`forward_score`, compté par le serveur ou, pour un message
/// chiffré, annoncé par l'appareil).
const kMaxForwardTargets = 5;

/// Ce qu'on transfère : le message tel que CET appareil le voit (déchiffré).
class ForwardPayload {
  const ForwardPayload({
    required this.messageType,
    this.text,
    this.media,
    this.forwardScore = 0,
    this.serverMessageId,
    this.viewOnce = false,
  });

  /// Depuis une discussion à deux.
  factory ForwardPayload.fromDirect(DirectMessage message) => ForwardPayload(
    messageType: message.messageType,
    text: message.content,
    media: message.media,
    forwardScore: message.forwardScore,
    // Un message EN CLAIR se recopie côté serveur (il garde le fichier et
    // compte le transfert lui-même). Un message chiffré, non : le serveur
    // n'a que le chiffré, scellé pour le destinataire d'origine.
    serverMessageId: message.isEncrypted || message.encryption != null
        ? null
        : message.id,
    viewOnce: message.viewOnce,
  );

  /// Depuis un groupe : toujours chiffré, toujours renvoyé par l'appareil.
  factory ForwardPayload.fromGroup(GroupMessage message) => ForwardPayload(
    messageType: message.messageType,
    text: message.content,
    media: message.media,
    forwardScore: message.forwardScore,
    viewOnce: message.viewOnce,
  );

  /// Une vue unique ne se transfère jamais (le serveur refuse aussi).
  final bool viewOnce;

  final String messageType;
  final String? text;
  final MediaMeta? media;
  final int forwardScore;
  final String? serverMessageId;

  /// L'aperçu de la citation, en tête de l'écran.
  String previewOf(L l) {
    final value = text?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return switch (messageType) {
      'IMAGE' => l.mediaPhoto,
      'VIDEO' => l.mediaVideo,
      'AUDIO' => l.mediaVoiceNote,
      'DOCUMENT' => l.mediaDocument,
      _ => l.mediaMessage,
    };
  }
}

/// Une destination : une personne ou un groupe.
class ForwardTarget {
  const ForwardTarget.contact(this.id, this.name, {this.avatar, this.subtitle})
    : isGroup = false;
  const ForwardTarget.group(this.id, this.name, {this.avatar, this.subtitle})
    : isGroup = true;

  /// L'identifiant de la PERSONNE (contact_user_id), ou du groupe.
  final int id;
  final String name;
  final MediaMeta? avatar;
  final String? subtitle;
  final bool isGroup;

  String get key => '${isGroup ? 'g' : 'c'}$id';
}

/// Ouvre l'écran et transfère. Rend le nombre de discussions atteintes.
Future<void> openForwardScreen(
  BuildContext context, {
  required ForwardPayload payload,
  required int myUserId,
}) async {
  // Dernier verrou, quel que soit le bouton qui a mené ici.
  if (payload.viewOnce) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  final result = await Navigator.of(context).push<({int sent, int failed})>(
    MaterialPageRoute(
      builder: (_) => ForwardScreen(payload: payload, myUserId: myUserId),
    ),
  );
  if (result == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result.failed == 0
            ? l.forwardDone(result.sent)
            : l.forwardPartial(result.failed),
      ),
    ),
  );
}

class ForwardScreen extends ConsumerStatefulWidget {
  const ForwardScreen({
    super.key,
    required this.payload,
    required this.myUserId,
  });

  final ForwardPayload payload;
  final int myUserId;

  @override
  ConsumerState<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends ConsumerState<ForwardScreen> {
  final _search = TextEditingController();
  String _query = '';
  final Map<String, ForwardTarget> _chosen = {};
  bool _sending = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(ForwardTarget target) {
    setState(() {
      if (_chosen.remove(target.key) != null) return;
      if (_chosen.length >= kMaxForwardTargets) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).forwardMaxReached)),
        );
        return;
      }
      _chosen[target.key] = target;
    });
  }

  Future<void> _send() async {
    if (_chosen.isEmpty || _sending) return;
    setState(() => _sending = true);
    final forwarder = MessageForwarder(ref, myUserId: widget.myUserId);
    var sent = 0;
    var failed = 0;
    for (final target in _chosen.values) {
      if (await forwarder.forward(widget.payload, target)) {
        sent++;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop((sent: sent, failed: failed));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final recents =
        ref.watch(discussionsProvider).valueOrNull ?? const <ConversationSummary>[];
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];
    final aboutByUser = {
      for (final contact in contacts)
        if (contact.contactUserId != null) contact.contactUserId!: contact.about,
    };

    // Récentes : les discussions de la liste, sans inconnus ni bots — on
    // ne fait pas suivre un message à qui on n'a pas choisi d'écrire.
    final recentTargets = <ForwardTarget>[
      for (final d in recents)
        if (d.kind == 'group' && d.id != null)
          ForwardTarget.group(d.id!, d.name, avatar: d.avatar, subtitle: l.forwardGroup)
        else if (d.kind == 'contact' &&
            !d.isUnknownContact &&
            !d.isBot &&
            d.contactUserId != null)
          ForwardTarget.contact(
            d.contactUserId!,
            d.name,
            avatar: d.avatar,
            subtitle: _stateOf(aboutByUser[d.contactUserId], l),
          ),
    ];
    final known = {for (final t in recentTargets) t.key};
    final otherContacts = <ForwardTarget>[
      for (final c in contacts)
        if (c.isRegistered &&
            c.contactUserId != null &&
            !known.contains('c${c.contactUserId}'))
          ForwardTarget.contact(
            c.contactUserId!,
            c.displayName,
            avatar: c.avatar,
            subtitle: _stateOf(c.about, l),
          ),
    ];

    bool matches(ForwardTarget t) =>
        _query.isEmpty || t.name.toLowerCase().contains(_query);
    final shownRecents = recentTargets.where(matches).toList();
    final shownContacts = otherContacts.where(matches).toList();

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
              l.forwardTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              l.forwardLimit,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  TextField(
                    contextMenuBuilder: pokouContextMenuBuilder,
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: l.forwardSearch,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // La citation : on voit ce qu'on s'apprête à faire suivre.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.forward,
                          size: 18,
                          color: AppColors.accentPrimaryDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '« ${widget.payload.previewOf(l)} »',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (shownRecents.isNotEmpty) ...[
                    _SectionLabel(l.forwardRecent),
                    _TargetCard(
                      targets: shownRecents,
                      chosen: _chosen,
                      onToggle: _toggle,
                    ),
                  ],
                  if (shownContacts.isNotEmpty) ...[
                    _SectionLabel(l.forwardContacts),
                    _TargetCard(
                      targets: shownContacts,
                      chosen: _chosen,
                      onToggle: _toggle,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l.forwardNote,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
                height: 50,
                child: FilledButton.icon(
                  onPressed: _chosen.isEmpty || _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(l.forwardSendTo(_chosen.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// L'état sous le nom — jamais le numéro.
  static String _stateOf(String? about, L l) {
    final value = about?.trim() ?? '';
    return value.isEmpty ? l.contactAvailable : value;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.targets,
    required this.chosen,
    required this.onToggle,
  });

  final List<ForwardTarget> targets;
  final Map<String, ForwardTarget> chosen;
  final ValueChanged<ForwardTarget> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final target in targets)
            CheckboxListTile(
              value: chosen.containsKey(target.key),
              onChanged: (_) => onToggle(target),
              activeColor: AppColors.accentPrimary,
              secondary: IdentityAvatar(
                userId: target.isGroup ? null : target.id,
                avatar: target.avatar,
                displayName: target.name,
                size: 40,
                showPresence: false,
                showStatusRing: false,
                fallbackIcon: target.isGroup ? Icons.group : null,
              ),
              title: Text(
                target.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: target.subtitle == null
                  ? null
                  : Text(
                      target.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Fait suivre un message à UNE destination, depuis ce que l'appareil en a.
///
/// Même chemin qu'un envoi ordinaire : un texte repart scellé pour son
/// nouveau destinataire, un fichier repart du fichier déchiffré local (clé
/// neuve, téléversement en file si le réseau manque). Seul un message EN
/// CLAIR d'une discussion à deux passe par la route serveur de transfert.
class MessageForwarder {
  MessageForwarder(this._ref, {required this.myUserId});

  final WidgetRef _ref;
  final int myUserId;

  Future<bool> forward(ForwardPayload payload, ForwardTarget target) async {
    try {
      return target.isGroup
          ? await _toGroup(payload, target.id)
          : await _toContact(payload, target.id);
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _toContact(ForwardPayload payload, int recipientId) async {
    final repository = _ref.read(messagingRepositoryProvider);
    final store = _ref.read(pokouMessageStoreProvider);
    final score = payload.forwardScore + 1;

    final serverId = payload.serverMessageId;
    if (serverId != null) {
      try {
        final copy = await repository.forward(
          messageId: serverId,
          recipientId: recipientId,
        );
        await store.saveDirect([copy]);
        return true;
      } on ApiException catch (exc) {
        // 409 : chiffré après tout — on repasse par l'appareil.
        if (exc.statusCode != 409) rethrow;
      }
    }

    final media = payload.media;
    if (media != null) {
      final file = await _ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(media.id, extension: mediaExtension(media));
      final copy = DirectMessage(
        id: store.newLocalId(),
        senderId: myUserId,
        recipientId: recipientId,
        messageType: payload.messageType,
        content: payload.text,
        mediaAssetId: null,
        media: null,
        status: DirectMessageStatus.sent,
        createdAt: DateTime.now(),
        forwardScore: score,
        pendingMedia: PendingMedia(
          path: file.path,
          filename: media.originalFilename ?? file.uri.pathSegments.last,
          mimeType: media.mimeType,
          caption: payload.text,
        ),
      );
      await store.saveDirect([copy], pending: true);
      await _ref.read(mediaSenderProvider).envoyer(copy);
      return !await store.isDirectFailed(copy.id);
    }

    final text = payload.text?.trim() ?? '';
    if (text.isEmpty) return false;
    final sent = await repository.send(
      recipientId: recipientId,
      content: payload.text!,
      forwardScore: score,
    );
    await store.saveDirect([sent]);
    return true;
  }

  Future<bool> _toGroup(ForwardPayload payload, int groupId) async {
    final groups = _ref.read(groupRepositoryProvider);
    final store = _ref.read(pokouMessageStoreProvider);
    final score = payload.forwardScore + 1;

    final media = payload.media;
    if (media != null) {
      final file = await _ref
          .read(mediaRepositoryProvider)
          .resolveLocalFile(media.id, extension: mediaExtension(media));
      final copy = GroupMessage(
        id: store.newLocalId(),
        groupId: groupId,
        senderId: myUserId,
        senderName: '',
        messageType: payload.messageType,
        content: payload.text,
        mediaAssetId: null,
        media: null,
        createdAt: DateTime.now(),
        forwardScore: score,
        pendingMedia: PendingMedia(
          path: file.path,
          filename: media.originalFilename ?? file.uri.pathSegments.last,
          mimeType: media.mimeType,
          caption: payload.text,
        ),
      );
      await store.saveGroup([copy], pending: true);
      // Parti, ou resté en file faute de réseau (il repartira) : le geste
      // est gardé dans les deux cas.
      await _ref.read(mediaSenderProvider).envoyerGroupe(copy);
      return true;
    }

    final text = payload.text?.trim() ?? '';
    if (text.isEmpty) return false;
    final sent = await groups.send(
      group: await groups.getGroup(groupId),
      senderId: myUserId,
      content: payload.text!,
      messageType: 'TEXT',
      forwardScore: score,
    );
    await store.saveGroup([sent]);
    return true;
  }
}
