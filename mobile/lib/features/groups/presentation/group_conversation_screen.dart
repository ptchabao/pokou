import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/gestures.dart';

import '../../../core/widgets/skeleton.dart';
import '../../../core/text/emoji_only.dart';
import '../../../core/media/image_cropper.dart';
import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/crypto/call_keys.dart' show CallEncryptionException;
import '../../../core/country/country_config.dart';
import '../../../core/providers.dart';
import '../../kory/presentation/kory_create_screen.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/notifications/active_conversation.dart';
import '../../messaging/presentation/encryption_banner.dart';
import '../../messaging/presentation/composer/composer_state.dart';
import '../../messaging/presentation/composer/mic_button.dart';
import '../../messaging/presentation/composer/recording_bar.dart';
import '../../messaging/presentation/composer/voice_recording.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/chat_wallpaper.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../messaging/data/direct_message_model.dart'
    show MessageReactionSummary, PollData;
import '../../messaging/presentation/bubble_widgets.dart';
import '../../messaging/presentation/contact_card_bubble.dart'
    show ContactCardBubble, findPhoneMatches, handlePhoneTap;
import '../../messaging/presentation/location_bubble.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../messaging/presentation/day_separator.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../home/presentation/certified_screen.dart';
import '../../messaging/presentation/media_bubble.dart';
import '../../messaging/presentation/poll_bubble.dart';
import '../../messaging/presentation/composer/composer_input.dart';
import '../../messaging/presentation/composer/composer_panel.dart';
import '../../messaging/presentation/message_appear.dart';
import '../../../core/api/api_exceptions.dart';
import '../../stickers/data/sticker_models.dart';
import '../../stickers/presentation/sticker_image.dart';
import '../../stickers/presentation/sticker_providers.dart';
import '../../stickers/presentation/sticker_suggestion_bar.dart';
import '../../stickers/presentation/trailing_emoji.dart';
import '../../messaging/presentation/call_event_row.dart';
import '../../messaging/presentation/pending_media_bubble.dart';
import '../../messaging/presentation/proof_widgets.dart';
import '../data/group_model.dart';
import '../../contacts/presentation/discussions_controller.dart';
import 'group_controller.dart';
import 'group_settings_screen.dart';
import '../../messaging/presentation/message_text_actions.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Conversation de groupe — pendant de ConversationScreen. Différences
/// assumées : pas de Mode Bouclier (il note une conversation par contact),
/// pas d'accusé de lecture (voir la docstring de GroupMessage côté API), et
/// le nom de l'auteur au-dessus des bulles reçues.
///
/// Les appels de groupe passent par un salon LiveKit éphémère rattaché au
/// groupe (`call_logs.group_id`) : deux membres qui appellent au même moment
/// convergent vers le même appel, et un membre arrivé en retard le rejoint
/// via le bandeau « Appel en cours ».
class GroupConversationScreen extends ConsumerStatefulWidget {
  const GroupConversationScreen({
    super.key,
    required this.myUserId,
    required this.groupId,
    required this.groupName,
  });

  final int myUserId;
  final int groupId;
  final String groupName;

  @override
  ConsumerState<GroupConversationScreen> createState() =>
      _GroupConversationScreenState();
}

class _GroupConversationScreenState
    extends ConsumerState<GroupConversationScreen> {
  /// Les textes traduits, relus à chaque accès.
  L get _l => L.of(context);
  final _inputController = TextEditingController();

  /// Le champ garde le FOCUS quand le panneau s'ouvre — c'est ce qui
  /// permet de revenir taper d'une touche, et de garder le curseur là où
  /// il était.
  final _inputFocus = FocusNode();

  /// Le panneau (emoji ou stickers) est-il ouvert ?
  bool _emojiOpen = false;

  /// Sur QUEL onglet il s'ouvrira — conservé entre deux ouvertures, parce
  /// qu'on envoie rarement un seul sticker.
  ComposerPanelTab _panelTab = ComposerPanelTab.emoji;

  /// L'emoji sur lequel se termine le champ, ou '' — ce qui déclenche les
  /// suggestions de stickers.
  String _trailingEmoji = '';

  /// La hauteur du clavier, mémorisée pendant qu'il était visible : le
  /// panneau la reprend, sinon l'ouvrir ferait sauter toute la
  /// conversation. 280 est la hauteur moyenne d'un clavier Android, tant
  /// qu'on n'en a pas vu un vrai.
  double _keyboardHeight = 280;
  final _scrollController = ScrollController();

  /// Même machine à états que le tête-à-tête : la barre d'écriture se
  /// comporte pareil dans les deux écrans, et c'est le même code qui le
  /// garantit plutôt que deux copies qui divergent.
  static const _composerMachine = ComposerMachine();
  ComposerState _composer = const ComposerState();
  late final VoiceRecordingController _voice = VoiceRecordingController();

  bool _hasText = false;
  bool _startingCall = false;
  GroupMessage? _replyingTo;
  StreamSubscription? _callWatch;
  Timer? _callPoll;

  // Superposition d'événements temps réel que GroupChatController n'expose
  // pas encore dans son état (réaction, modification, vote de sondage) —
  // voir _onRichContentEvent, pendant de conversation_screen.dart pour les
  // groupes.
  final Map<String, GroupMessage> _patches = {};
  StreamSubscription? _richContentSub;

  // Une clé par bulle affichée pour le défilement best-effort vers un
  // message cité — voir conversation_screen.dart::_scrollToMessage.
  final Map<String, GlobalKey> _bubbleKeys = {};

  @override
  void initState() {
    super.initState();
    _activeConversation = ref.read(activeConversationProvider.notifier);
    // Même règle qu'en tête-à-tête : pas de notification pour le groupe
    // qu'on est en train de lire. Après la première image, sinon modifier
    // un provider pendant la construction de l'arbre lève.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeConversation.state = ActiveConversation.group(widget.groupId);
      }
    });
    _inputController.addListener(_onInputChanged);
    _scrollController.addListener(_maybeLoadOlder);
    // Le bandeau « Appel en cours » doit apparaître dès qu'un membre lance un
    // appel, sans attendre une réouverture de l'écran.
    _callWatch = ref.read(wsClientProvider).events.listen((event) {
      if (event['type'] != 'call:invite') return;
      if (event['group_id'] != widget.groupId) return;
      ref.invalidate(activeGroupCallProvider(widget.groupId));
    });
    // …et disparaître quand l'appel se termine. Seuls ses participants en
    // reçoivent le signal : les autres membres gardaient le bandeau
    // « Rejoindre » sur un appel fini. Tant qu'il est affiché, on revérifie.
    _callPoll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final provider = activeGroupCallProvider(widget.groupId);
      if (ref.read(provider).valueOrNull != null) ref.invalidate(provider);
    });
    // Groupe supprimé, ou moi retiré, pendant que l'écran est ouvert : il
    // se ferme en le disant.
    ref.listenManual(
      groupChatControllerProvider(
        widget.groupId,
      ).select((state) => state.closed),
      (_, closed) {
        if (closed == null || !mounted) return;
        final l = L.of(context);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              closed == GroupClosed.deleted
                  ? l.groupClosedDeleted
                  : l.groupClosedRemoved,
            ),
          ),
        );
      },
    );
    _richContentSub = ref
        .read(wsClientProvider)
        .events
        .listen(_onRichContentEvent);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.removeListener(_maybeLoadOlder);
    _scrollController.dispose();
    _voice.dispose();
    _callWatch?.cancel();
    _callPoll?.cancel();
    _richContentSub?.cancel();
    // Après la phase de démontage : Riverpod refuse une modification
    // pendant que Flutter verrouille l'arbre.
    Future<void>.delayed(Duration.zero, () => _activeConversation.state = null);
    super.dispose();
  }

  /// Capturé à l'initialisation : au démontage, lire un provider depuis un
  /// élément déjà retiré de l'arbre lève.
  late final StateController<ActiveConversation?> _activeConversation;

  GlobalKey _keyFor(String messageId) =>
      _bubbleKeys.putIfAbsent(messageId, () => GlobalKey());

  /// Rich events are handled by GroupChatController so encrypted edits are
  /// decrypted once and saved only in the SQLCipher cache.
  void _onRichContentEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    if (type == 'group:message:reaction') {
      final eventGroupId = event['group_id'] as int?;
      final messageId = event['message_id'] as String?;
      final reactionsJson = event['reactions'] as List<dynamic>?;
      if (eventGroupId != widget.groupId ||
          messageId == null ||
          reactionsJson == null)
        return;
      final base = _findMessage(messageId);
      if (base == null || !mounted) return;
      final reactions = reactionsJson
          .map(
            (raw) =>
                MessageReactionSummary.fromJson(raw as Map<String, dynamic>),
          )
          .toList();
      setState(() => _patches[messageId] = base.copyWith(reactions: reactions));
      return;
    }

    if (type == 'poll:vote') {
      final messageId = event['message_id'] as String?;
      final pollJson = event['poll'] as Map<String, dynamic>?;
      if (messageId == null || pollJson == null) return;
      final base = _findMessage(messageId);
      if (base == null || !mounted) return;
      setState(
        () => _patches[messageId] = base.copyWith(
          poll: PollData.fromJson(pollJson),
        ),
      );
    }
  }

  GroupMessage? _findMessage(String messageId) {
    final patched = _patches[messageId];
    if (patched != null) return patched;
    for (final message
        in ref.read(groupChatControllerProvider(widget.groupId)).messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  void _scrollToMessage(String messageId) {
    final ctx = _bubbleKeys[messageId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  Future<void> _reactTo(GroupMessage message, String emoji) async {
    final repository = ref.read(groupRepositoryProvider);
    try {
      final alreadyMine = message.reactions.any(
        (r) => r.emoji == emoji && r.mine,
      );
      final reactions = alreadyMine
          ? await repository.removeReaction(
              groupId: widget.groupId,
              messageId: message.id,
            )
          : await repository.setReaction(
              groupId: widget.groupId,
              messageId: message.id,
              emoji: emoji,
            );
      if (!mounted) return;
      setState(
        () => _patches[message.id] = message.copyWith(reactions: reactions),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.convReactionFailed)));
      }
    }
  }

  Future<void> _showReactionSheet(GroupMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReactionQuickBar(
              onPick: (emoji) {
                Navigator.pop(sheetContext);
                _reactTo(message, emoji);
              },
              onMore: () async {
                Navigator.pop(sheetContext);
                final emoji = await promptCustomEmoji(context);
                if (emoji != null && emoji.isNotEmpty) _reactTo(message, emoji);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(_l.conversationReply),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _replyingTo = message);
                _inputFocus.requestFocus();
              },
            ),
            if (copyableText(
                  message.content,
                  deleted: message.deletedAt != null,
                  locked: message.isEncrypted,
                )
                case final text?)
              ...messageTextActionTiles(
                context: context,
                text: text,
                close: () => Navigator.pop(sheetContext),
              ),
            if (ref
                .read(groupChatControllerProvider(widget.groupId).notifier)
                .canEdit(message))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(_l.conversationEdit),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editMessage(message);
                },
              ),
            if (message.deletedAt == null &&
                (message.senderId == widget.myUserId ||
                    (ref
                            .read(groupChatControllerProvider(widget.groupId))
                            .group
                            ?.canManage ??
                        false)))
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.feedbackDanger,
                ),
                title: Text(_l.deleteForAll),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteForEveryone(message);
                },
              ),
            // Un sticker se GARDE — dans ses stickers, pas dans la galerie.
            // Le même geste qu'en tête-à-tête : recevoir un sticker qui
            // plaît et ne pas pouvoir le reprendre serait frustrant
            // exactement là où on en envoie le plus.
            if (message.messageType == 'STICKER' && message.media != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: Text(_l.stickerSaveToMine),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveSticker(message.media!.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(GroupMessage message) async {
    final controller = TextEditingController(text: message.content ?? '');
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.convEditTitle),
        content: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          autofocus: true,
          maxLength: 4000,
          decoration: InputDecoration(hintText: _l.convEditHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_l.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || !mounted) return;
    if (edited.trim().isEmpty || edited.trim() == message.content?.trim()) {
      return;
    }
    try {
      await ref
          .read(groupChatControllerProvider(widget.groupId).notifier)
          .editMessage(message.id, edited);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.convEditFailed)));
    }
  }

  /// Supprimer pour tous. En mode preuve, l'auteur est prévenu AVANT que
  /// le message restera visible, barré : sinon il croirait l'avoir effacé.
  Future<void> _deleteForEveryone(GroupMessage message) async {
    final proof =
        ref
            .read(groupChatControllerProvider(widget.groupId))
            .group
            ?.proofMode ??
        false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.deleteForAll),
        content: proof ? Text(_l.deleteProofWarning) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.feedbackDanger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_l.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(groupChatControllerProvider(widget.groupId).notifier)
          .deleteForEveryone(message.id);
      _patches.remove(message.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.honamFailed)));
    }
  }

  Future<void> _toggleProofMode(Group group) async {
    try {
      await ref
          .read(groupChatControllerProvider(widget.groupId).notifier)
          .setProofMode(!group.proofMode);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403 && group.proofMode) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.proofDisableReserved)));
      } else if (error.statusCode == 403) {
        final open = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_l.proofModeTitle),
            content: Text(_l.proofModeNeedsCert),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_l.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_l.certTitle),
              ),
            ],
          ),
        );
        if (open == true && mounted) {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CertifiedScreen()));
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// L'export daté, partagé comme n'importe quel fichier : la personne
  /// choisit où il part (avocat, chef de quartier, sauvegarde).
  Future<void> _exportProof() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(apiClientProvider)
          .getBytes('/groups/${widget.groupId}/proof-export');
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      final file = File(
        '${dir.path}/pokou-preuve-${widget.groupId}-$stamp.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(_l.honamFailed)));
    }
  }

  /// Garder un sticker reçu dans un groupe.
  ///
  /// L'image appartient au pack, jamais à celui qui l'enregistre : c'est le
  /// serveur qui vérifie qu'on avait le droit de la voir, et qu'il s'agit
  /// bien d'un sticker et non d'une photo quelconque.
  Future<void> _saveSticker(int mediaAssetId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(stickerPanelProvider.notifier).saveReceived(mediaAssetId);
      messenger.showSnackBar(SnackBar(content: Text(_l.stickerSaved)));
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode == 409 ? _l.stickerLimitReached : error.message,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(_l.stickerSendFailed)));
    }
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    final next = _composerMachine.onTextChanged(
      _composer,
      _inputController.text,
    );
    // Comparé avant de reconstruire : sans ce test, chaque lettre d'un
    // message ordinaire redessinerait l'écran alors que rien n'a changé.
    final emoji = trailingEmoji(_inputController.text) ?? '';
    if (hasText == _hasText && next == _composer && emoji == _trailingEmoji) {
      return;
    }
    if (hasText != _hasText) HapticFeedback.selectionClick();
    setState(() {
      _hasText = hasText;
      _composer = next;
      _trailingEmoji = emoji;
    });
  }

  /// Bascule entre le clavier et le panneau.
  ///
  /// L'un ferme l'autre : les deux à la fois occuperaient tout l'écran et
  /// la conversation disparaîtrait.
  void _toggleEmoji() {
    if (_emojiOpen) {
      _inputFocus.requestFocus();
      _closePanelForKeyboard();
      return;
    }
    _panelCloseTimer?.cancel();
    // Le clavier se retire AVANT que le panneau ne s'ouvre, sinon les deux
    // se superposent le temps de l'animation. Le panneau, lui, ne montre
    // que la place que le clavier libère (voir ComposerPanel) : la barre
    // ne bouge pas.
    FocusScope.of(context).unfocus();
    setState(() => _emojiOpen = true);
  }

  Timer? _panelCloseTimer;

  /// Retour au clavier : le panneau reste le temps que le clavier monte,
  /// en ne montrant que la place qu'il ne couvre pas encore. Le retirer
  /// tout de suite ferait tomber la barre, puis remonter avec le clavier.
  void _closePanelForKeyboard() {
    _panelCloseTimer?.cancel();
    _panelCloseTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _emojiOpen = false);
    });
  }

  /// Retire un caractère depuis le panneau — un emoji peut occuper
  /// plusieurs unités de code, et `length - 1` en couperait un en deux.
  void _emojiBackspace() {
    final value = _inputController.value;
    final offset = value.selection.baseOffset;
    if (offset <= 0) return;
    final avant = value.text.substring(0, offset);
    final apres = value.text.substring(offset);
    final caracteres = avant.characters;
    if (caracteres.isEmpty) return;
    final tronque = caracteres.skipLast(1).toString();
    _inputController.value = TextEditingValue(
      text: tronque + apres,
      selection: TextSelection.collapsed(offset: tronque.length),
    );
  }

  /// Le panneau reste OUVERT après l'envoi : on en envoie souvent
  /// plusieurs d'affilée.
  Future<void> _sendSticker(Sticker sticker) async {
    ref.read(stickerPanelProvider.notifier).noteSent(sticker);
    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .sendExistingMedia(
          mediaAssetId: sticker.mediaId,
          messageType: 'STICKER',
        );
    _scrollToBottom();
  }

  /// La hauteur du clavier pendant qu'il est visible — le panneau la
  /// reprendra une fois qu'il aura disparu.
  void _rememberKeyboardHeight(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 120 && inset != _keyboardHeight) {
      _keyboardHeight = inset;
    }
  }

  /// Le nom d'un auteur, même règle que partout (voir
  /// api/app/utils/identity.py::nom_affiche) : celui d'un compte CERTIFIÉ
  /// d'abord, puis celui de mon carnet, puis celui que le serveur donne (le
  /// nom que la personne s'est choisi, ou son numéro).
  ///
  /// Seul le dernier était affiché : quelqu'un enregistré « Tonton Kossi »
  /// apparaissait sous un nom que l'on ne reconnaissait pas.
  String _authorName(int userId, String serverName, {String? certifiedName}) {
    if (certifiedName != null && certifiedName.trim().isNotEmpty) {
      return certifiedName;
    }
    final contacts = ref.watch(contactsProvider).valueOrNull;
    if (contacts != null) {
      for (final contact in contacts) {
        if (contact.contactUserId == userId &&
            contact.displayName.trim().isNotEmpty) {
          return contact.displayName;
        }
      }
    }
    return serverName;
  }

  /// Voir ConversationScreen._maybeLoadOlder — même geste, même règle.
  Future<void> _maybeLoadOlder() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > 400) return;
    final current = ref.read(groupChatControllerProvider(widget.groupId));
    if (!current.hasOlder || current.loadingOlder) return;
    final fromBottom = position.maxScrollExtent - position.pixels;
    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .loadOlder();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final after = _scrollController.position;
      _scrollController.jumpTo(
        (after.maxScrollExtent - fromBottom).clamp(0.0, after.maxScrollExtent),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    final replyTo = _replyingTo;
    _inputController.clear();
    setState(() => _replyingTo = null);
    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .send(text, replyTo: replyTo);
    _scrollToBottom();
  }

  /// Une image ou un GIF venu du clavier : envoyé comme une photo.
  Future<void> _sendInsertedContent(KeyboardInsertedContent content) async {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return;
    final extension = content.mimeType.split('/').last;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/clavier-${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _sendMediaFile(
      path: file.path,
      bytes: bytes,
      filename: file.uri.pathSegments.last,
      mimeType: content.mimeType,
      messageType: 'IMAGE',
    );
  }

  Future<void> _sendMediaFile({
    required String path,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String messageType,
  }) async {
    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .sendMedia(
          path: path,
          bytes: bytes,
          filename: filename,
          mimeType: mimeType,
          messageType: messageType,
        );
    _scrollToBottom();
  }

  Future<bool> _ensurePermission(Permission permission) async {
    final status = await permission.request();
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.convPermissionDenied)));
    }
    return status.isGranted;
  }

  /// Un GIF, depuis les fichiers de l'appareil.
  ///
  /// Le même chemin que dans une conversation à deux : pas de catalogue en
  /// ligne, pas de clé d'API, rien qui sorte. Le bouton du panneau dit donc
  /// ce qu'il fait — ouvrir un fichier.
  Future<void> _pickAndSendGif() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
    );
    final picked = result?.files.single;
    if (picked == null || picked.path == null) return;
    await _sendMediaFile(
      path: picked.path!,
      bytes: await File(picked.path!).readAsBytes(),
      filename: picked.name,
      // Le type EXACT : en `application/octet-stream`, le GIF s'afficherait
      // comme un document à télécharger.
      mimeType: 'image/gif',
      // IMAGE et non DOCUMENT : c'est ce qui le fait rendre par
      // `Image.file`, qui anime les GIF sans rien demander.
      messageType: 'IMAGE',
    );
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    final picked = result?.files.single;
    if (picked == null || picked.path == null) return;
    final bytes = await File(picked.path!).readAsBytes();
    await _sendMediaFile(
      path: picked.path!,
      bytes: bytes,
      filename: picked.name,
      mimeType: lookupMimeType(picked.name) ?? 'application/octet-stream',
      messageType: 'DOCUMENT',
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await _ensurePermission(Permission.camera)) {
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _sendMediaFile(
      path: picked.path,
      bytes: bytes,
      filename: picked.name,
      mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
      messageType: 'IMAGE',
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _sendMediaFile(
      path: picked.path,
      bytes: bytes,
      filename: picked.name,
      mimeType: lookupMimeType(picked.name) ?? 'video/mp4',
      messageType: 'VIDEO',
    );
  }

  Future<void> _showAttachmentSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.insert_drive_file,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.convAttachDocument),
              onTap: () => Navigator.pop(sheetContext, 'document'),
            ),
            ListTile(
              leading: Icon(Icons.photo, color: AppColors.accentPrimaryDark),
              title: Text(_l.convAttachGallery),
              onTap: () => Navigator.pop(sheetContext, 'photo_gallery'),
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: AppColors.accentPrimaryDark),
              title: Text(_l.convAttachVideo),
              onTap: () => Navigator.pop(sheetContext, 'video_gallery'),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.convAttachCamera),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            // Pas de sondage dans les groupes pour l'instant : depuis le
            // chiffrement de bout en bout, le serveur ne peut plus tenir
            // les votes en clair et refuse leur création (409). L'entrée
            // restait proposée — on remplissait le sondage, puis il
            // échouait. Elle reviendra avec des sondages chiffrés.
            // Une cagnotte se crée DEPUIS le groupe, déjà rattachée à lui
            // (NAV-03) — seulement là où Kory est ouvert.
            if (ref.read(currentCountryConfigProvider).has('kory'))
              ListTile(
                leading: Icon(
                  Icons.savings_outlined,
                  color: AppColors.accentPrimaryDark,
                ),
                title: Text(_l.koryCreate),
                onTap: () => Navigator.pop(sheetContext, 'kory'),
              ),
          ],
        ),
      ),
    );

    switch (choice) {
      case 'document':
        await _pickAndSendDocument();
      case 'photo_gallery':
        await _pickImage(ImageSource.gallery);
      case 'video_gallery':
        await _pickVideo(ImageSource.gallery);
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'poll':
        await _createGroupPoll();
      case 'kory':
        if (mounted)
          await openKoryCreate(context, ref, groupId: widget.groupId);
    }
  }

  Future<void> _createGroupPoll() async {
    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    var allowsMultiple = false;

    final poll =
        await showDialog<
          ({String question, List<String> options, bool allowsMultiple})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(_l.pollOne),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        contextMenuBuilder: pokouContextMenuBuilder,
                        controller: questionController,
                        autofocus: true,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: _l.pollQuestion,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < optionControllers.length;
                        index++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            contextMenuBuilder: pokouContextMenuBuilder,
                            controller: optionControllers[index],
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: _l.pollAnswerN(index + 1),
                              border: const OutlineInputBorder(),
                              counterText: '',
                              suffixIcon: optionControllers.length > 2
                                  ? IconButton(
                                      tooltip: _l.actionDelete,
                                      onPressed: () {
                                        setDialogState(() {
                                          optionControllers
                                              .removeAt(index)
                                              .dispose();
                                        });
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if (optionControllers.length < 12)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setDialogState(
                              () => optionControllers.add(
                                TextEditingController(),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(_l.pollAddAnswer),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_l.pollMultiple),
                        value: allowsMultiple,
                        onChanged: (value) =>
                            setDialogState(() => allowsMultiple = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_l.actionCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final question = questionController.text.trim();
                    final options = optionControllers
                        .map((controller) => controller.text.trim())
                        .where((option) => option.isNotEmpty)
                        .toList();
                    if (question.isEmpty || options.length < 2) return;
                    Navigator.pop(dialogContext, (
                      question: question,
                      options: options,
                      allowsMultiple: allowsMultiple,
                    ));
                  },
                  child: Text(_l.pollOne),
                ),
              ],
            ),
          ),
        );

    questionController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    if (poll == null || !mounted) return;

    try {
      await ref
          .read(groupChatControllerProvider(widget.groupId).notifier)
          .createPoll(
            question: poll.question,
            options: poll.options,
            allowsMultiple: poll.allowsMultiple,
          );
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.convAttachmentFailed)));
      }
    }
  }

  Future<void> _beginRecording() async {
    if (!await _ensurePermission(Permission.microphone)) {
      if (mounted) setState(() => _composer = const ComposerState());
      return;
    }
    if (!await _voice.start() && mounted) {
      setState(() => _composer = const ComposerState());
    }
  }

  Future<void> _finishRecording(ComposerRelease action) async {
    switch (action) {
      case ComposerRelease.cancel:
        await _voice.cancel();
      case ComposerRelease.send:
        await _sendRecording();
      case ComposerRelease.none:
        break;
    }
  }

  Future<void> _sendRecording() async {
    final elapsed = _voice.elapsed;
    final file = await _voice.stop();
    if (file == null) return;
    // Une note d'une demi-seconde est un effleurement, pas un message.
    if (elapsed < const Duration(seconds: 1)) {
      unawaited(file.delete());
      return;
    }
    await _sendMediaFile(
      path: file.path,
      bytes: await file.readAsBytes(),
      filename: 'note_vocale.m4a',
      mimeType: 'audio/mp4',
      messageType: 'AUDIO',
    );
    unawaited(file.delete());
  }

  // ---------------------------------------------------------------- appels

  /// Lance OU rejoint l'appel du groupe : le serveur renvoie le salon de
  /// l'appel déjà en cours s'il y en a un (`joined_existing`), sinon il en
  /// ouvre un nouveau et sonne chez tous les membres. Le bandeau
  /// « Rejoindre » passe par ici aussi — jamais par le nom de salon mémorisé,
  /// qui pourrait désigner un appel terminé entre-temps.
  Future<void> _startOrJoinCall({required bool withVideo}) async {
    if (_startingCall) return;
    setState(() => _startingCall = true);
    final group = ref.read(groupChatControllerProvider(widget.groupId)).group;
    try {
      final token = await ref
          .read(callRepositoryProvider)
          .startGroupCall(
            widget.groupId,
            isVideo: withVideo,
            memberUserIds: [
              for (final member in group?.members ?? const <GroupMember>[])
                if (member.userId != widget.myUserId) member.userId,
            ],
          );
      if (!mounted) return;
      setState(() => _startingCall = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: token.participantIds,
            startWithVideo: withVideo,
            groupId: widget.groupId,
            joiningExistingCall: token.joinedExisting,
            groupMembers: [
              for (final member in group?.members ?? const <GroupMember>[])
                if (member.userId != widget.myUserId)
                  (userId: member.userId, displayName: member.displayName),
            ],
          ),
        ),
      );
      if (!mounted) return;
      ref.invalidate(activeGroupCallProvider(widget.groupId));
    } on CallEncryptionException catch (error) {
      if (!mounted) return;
      setState(() => _startingCall = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message.isEmpty ? _l.contactCallFailed : error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _startingCall = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.contactCallFailed)));
    }
  }

  // ---------------------------------------------------------------- membres

  Future<void> _showGroupSheet(Group? group) async {
    if (group == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${group.memberCount} participant${group.memberCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              // Administration réservée aux admins — le serveur tranche
              // (`can_manage`), le client ne devine pas les droits.
              // Le mode preuve : tout titulaire du badge, admin ou non.
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.gavel_outlined,
                  color: AppColors.accentPrimaryDark,
                ),
                title: Text(
                  group.proofMode ? _l.proofModeDisable : _l.proofModeEnable,
                ),
                subtitle: group.proofMode ? null : Text(_l.proofModeOnBanner),
                onTap: () => Navigator.pop(sheetContext, 'proof'),
              ),
              if (group.proofMode)
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.accentPrimaryDark,
                  ),
                  title: Text(_l.proofExport),
                  onTap: () => Navigator.pop(sheetContext, 'proof:export'),
                ),
              // Nom et photo : administrateurs, ou tous les membres si le
              // groupe l'autorise (DIS-26).
              if (group.canEditInfo) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: AppColors.accentPrimaryDark,
                  ),
                  title: Text(_l.groupEditName),
                  onTap: () => Navigator.pop(sheetContext, 'rename'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.accentPrimaryDark,
                  ),
                  title: Text(
                    group.avatarMediaId == null
                        ? _l.groupAddPhoto
                        : _l.groupChangePhoto,
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'photo'),
                ),
                if (group.avatarMediaId != null)
                  ListTile(
                    leading: Icon(
                      Icons.hide_image_outlined,
                      color: AppColors.textMuted,
                    ),
                    title: Text(_l.groupRemovePhoto),
                    onTap: () => Navigator.pop(sheetContext, 'photo:clear'),
                  ),
              ],
              if (group.canManage) ...[
                ListTile(
                  leading: Icon(Icons.tune, color: AppColors.accentPrimaryDark),
                  title: Text(_l.groupManageTitle),
                  subtitle: Text(
                    _l.groupManageSubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'manage'),
                ),
                ListTile(
                  leading: Icon(Icons.link, color: AppColors.accentPrimaryDark),
                  title: Text(_l.groupInviteLink),
                  subtitle: Text(
                    group.inviteCode == null
                        ? _l.groupNoLink
                        : _l.groupLinkActive,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'invite'),
                ),
              ],
              const Divider(height: 1),
              for (final member in group.members)
                ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color: AppColors.textMuted,
                  ),
                  title: Text(
                    member.userId == widget.myUserId
                        ? _l.navYou
                        : member.displayName,
                  ),
                  subtitle: member.canManage
                      ? Text(member.isOwner ? _l.groupCreator : _l.groupAdmin)
                      : null,
                  trailing: _memberActions(group, member, sheetContext),
                  // Toucher un membre ouvre une discussion à deux avec lui.
                  onTap: member.userId == widget.myUserId
                      ? null
                      : () =>
                            Navigator.pop(sheetContext, 'dm:${member.userId}'),
                ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.person_add_alt,
                  color: AppColors.accentPrimaryDark,
                ),
                title: Text(_l.groupAddMembers),
                onTap: () => Navigator.pop(sheetContext, 'add'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: AppColors.semanticError,
                ),
                title: Text(
                  _l.groupLeave,
                  style: TextStyle(color: AppColors.semanticError),
                ),
                onTap: () => Navigator.pop(sheetContext, 'leave'),
              ),
              if (group.isOwnedBy(widget.myUserId))
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.semanticError,
                  ),
                  title: Text(
                    _l.groupDelete,
                    style: TextStyle(color: AppColors.semanticError),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'proof') {
      await _toggleProofMode(group);
    } else if (action == 'proof:export') {
      await _exportProof();
    } else if (action == 'add') {
      await _addMembers(group);
    } else if (action == 'leave') {
      await _leave();
    } else if (action == 'delete') {
      await _deleteGroup();
    } else if (action.startsWith('dm:')) {
      final userId = int.tryParse(action.substring(3));
      final member = group.members.where((m) => m.userId == userId).firstOrNull;
      if (userId != null && member != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              myUserId: widget.myUserId,
              contactUserId: userId,
              contactName: member.displayName,
            ),
          ),
        );
      }
    } else if (action == 'manage') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupSettingsScreen(groupId: widget.groupId),
        ),
      );
      if (mounted) {
        await ref
            .read(groupChatControllerProvider(widget.groupId).notifier)
            .refreshGroup();
      }
    } else if (action == 'rename') {
      await _renameGroup(group);
    } else if (action == 'photo') {
      await _changeGroupPhoto();
    } else if (action == 'photo:clear') {
      await _clearGroupPhoto();
    } else if (action == 'invite') {
      await _manageInviteLink(group);
    } else if (action.startsWith('remove:')) {
      final userId = int.tryParse(action.substring('remove:'.length));
      if (userId != null) {
        await ref
            .read(groupChatControllerProvider(widget.groupId).notifier)
            .removeMember(userId);
      }
    } else if (action.startsWith('role:')) {
      final parts = action.split(':');
      final userId = int.tryParse(parts[1]);
      if (userId != null) {
        await ref
            .read(groupChatControllerProvider(widget.groupId).notifier)
            .setMemberRole(userId: userId, role: parts[2]);
      }
    }
  }

  /// Boutons par membre : nommer/révoquer un admin (créateur seulement) et
  /// retirer (créateur et admins). Le créateur n'est ni rétrogradable ni
  /// évinçable — sinon le groupe se retrouverait sans personne pour le gérer.
  Widget? _memberActions(
    Group group,
    GroupMember member,
    BuildContext sheetContext,
  ) {
    if (member.userId == widget.myUserId || member.isOwner) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (group.isOwner)
          IconButton(
            icon: Icon(
              member.isAdmin
                  ? Icons.remove_moderator_outlined
                  : Icons.add_moderator_outlined,
              size: 20,
            ),
            tooltip: member.isAdmin
                ? _l.groupDemoteAdmin
                : _l.groupPromoteAdmin,
            onPressed: () => Navigator.pop(
              sheetContext,
              'role:${member.userId}:${member.isAdmin ? 'MEMBER' : 'ADMIN'}',
            ),
          ),
        if (group.canManage)
          IconButton(
            icon: const Icon(Icons.person_remove_outlined, size: 20),
            tooltip: _l.marketRemove,
            onPressed: () =>
                Navigator.pop(sheetContext, 'remove:${member.userId}'),
          ),
      ],
    );
  }

  Future<void> _renameGroup(Group group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _l.groupName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: controller,
              autofocus: true,
              maxLength: 255,
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (value) => Navigator.pop(sheetContext, value),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, controller.text),
              child: Text(_l.actionSave),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .rename(newName.trim());
  }

  Future<void> _changeGroupPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.profileGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.convAttachCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await cropSquareImage(context, bytes);
    if (cropped == null || !mounted) return;

    await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .changePhoto(bytes: cropped, filename: picked.name);
  }

  Future<void> _clearGroupPhoto() => ref
      .read(groupChatControllerProvider(widget.groupId).notifier)
      .clearPhoto();

  /// Le lien est une autorisation à lui seul : on le montre, on le copie, et
  /// on peut le régénérer — seul moyen de révoquer un lien déjà diffusé.
  Future<void> _manageInviteLink(Group group) async {
    final controller = ref.read(
      groupChatControllerProvider(widget.groupId).notifier,
    );
    var code = group.inviteCode;
    code ??= await controller.createInviteLink();
    if (code == null || !mounted) return;

    final link = inviteLinkFor(code);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                _l.groupInviteLink,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                link,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                // Depuis les App Links (voir core/deeplink/), toucher ce
                // lien sur un téléphone où Pokou est installé rejoint le
                // groupe directement, sans coller le code à la main.
                _l.groupInviteLinkBody,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.actionShare),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
            ListTile(
              leading: Icon(Icons.copy, color: AppColors.accentPrimaryDark),
              title: Text(_l.groupCopyLink),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: Icon(
                Icons.autorenew,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.groupRegenLink),
              onTap: () => Navigator.pop(sheetContext, 'rotate'),
            ),
            ListTile(
              leading: const Icon(
                Icons.link_off,
                color: AppColors.semanticError,
              ),
              title: Text(
                _l.groupDisableLink,
                style: TextStyle(color: AppColors.semanticError),
              ),
              onTap: () => Navigator.pop(sheetContext, 'revoke'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'share') {
      await Share.share(
        '${widget.groupName} — Rejoignez notre groupe sur Pokou Messenger : $link',
        subject: widget.groupName,
      );
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.groupLinkCopied)));
      }
    } else if (action == 'rotate') {
      await controller.createInviteLink();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.groupNewLinkCreated)));
      }
    } else if (action == 'revoke') {
      await controller.revokeInviteLink();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.groupLinkDisabled)));
      }
    }
  }

  Future<void> _addMembers(Group group) async {
    final contacts = await ref.read(contactsProvider.future);
    final memberIds = group.members.map((member) => member.userId).toSet();
    final candidates = contacts
        .where(
          (contact) =>
              contact.isRegistered &&
              contact.contactUserId != null &&
              !memberIds.contains(contact.contactUserId),
        )
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.groupAllContactsIn)));
      return;
    }

    final picked = <int>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _l.groupAddToGroup,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final contact in candidates)
                      CheckboxListTile(
                        value: picked.contains(contact.contactUserId),
                        title: Text(contact.displayName),
                        onChanged: (checked) => setSheetState(() {
                          checked == true
                              ? picked.add(contact.contactUserId!)
                              : picked.remove(contact.contactUserId);
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: picked.isEmpty
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                    child: Text(_l.actionAdd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || picked.isEmpty || !mounted) return;
    try {
      final resultat = await ref
          .read(groupRepositoryProvider)
          .inviteMembers(groupId: widget.groupId, userIds: picked.toList());
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      // « Invitations envoyées », et non « membres ajoutés » : ils ne le sont
      // pas encore, et annoncer le contraire ferait chercher dans la liste
      // des membres des gens qui n'ont rien accepté.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l.groupInvitesSent(resultat.invited))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.groupAddFailed)));
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.groupDeleteTitle(widget.groupName)),
        content: Text(_l.groupDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _l.groupDelete,
              style: TextStyle(color: AppColors.semanticError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .deleteGroup();
    ref.invalidate(myGroupsProvider);
    ref.invalidate(discussionsProvider);
    if (!mounted || !ok) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.groupLeaveTitle),
        content: Text(_l.groupLeaveBody(widget.groupName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _l.groupLeaveAction,
              style: TextStyle(color: AppColors.semanticError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(groupChatControllerProvider(widget.groupId).notifier)
        .leave(widget.myUserId);
    ref.invalidate(myGroupsProvider);
    if (!mounted || !ok) return;
    Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------------- vue

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupChatControllerProvider(widget.groupId));
    final group = state.group;
    // Pendant que le clavier est là — c'est le seul moment où sa hauteur
    // est lisible, et le panneau en aura besoin une fois qu'il aura
    // disparu.
    _rememberKeyboardHeight(context);
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: ChatWallpaper(
        // Même traitement qu'en 1:1 : la barre gère l'encoche elle-même pour
        // que son blanc monte jusqu'en haut, sinon le motif réapparaît dans
        // la bande de statut au-dessus d'elle.
        child: SafeArea(
          top: false,
          // Panneau ouvert : il couvre lui-même le bas de l'écran.
          bottom: !_emojiOpen,
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      _ChatIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),

                        tooltip: L.of(context).a11yBack,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _showGroupSheet(group),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surfaceElevated,
                                ),
                                child: Icon(
                                  Icons.groups,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      group?.name ?? widget.groupName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (group != null)
                                      Text(
                                        group.members
                                            .map(
                                              (member) =>
                                                  member.userId ==
                                                      widget.myUserId
                                                  ? _l.navYou
                                                  : member.displayName,
                                            )
                                            .join(', '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
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
                      _ChatIconButton(
                        icon: Icons.call_outlined,
                        onPressed: _startingCall
                            ? null
                            : () => _startOrJoinCall(withVideo: false),

                        tooltip: L.of(context).a11yVoiceCall,
                      ),
                      _ChatIconButton(
                        icon: Icons.videocam_outlined,
                        onPressed: _startingCall
                            ? null
                            : () => _startOrJoinCall(withVideo: true),

                        tooltip: L.of(context).a11yVideoCall,
                      ),
                      _ChatIconButton(
                        icon: Icons.more_vert,
                        onPressed: () => _showGroupSheet(group),

                        tooltip: L.of(context).a11yMoreOptions,
                      ),
                    ],
                  ),
                ),
              ),
              if (group?.proofMode ?? false) const ProofModeBanner(),
              _ActiveCallBanner(
                groupId: widget.groupId,
                onJoin: _startingCall
                    ? null
                    : () => _startOrJoinCall(withVideo: false),
              ),
              Expanded(
                child: !state.initialCacheLoaded
                    // L'attente a la forme d'une conversation — et seulement
                    // si elle dure : le cache se lit en quelques
                    // millisecondes.
                    ? const DelayedSkeleton(child: SkeletonBubbles())
                    : state.messages.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const GroupEncryptionNotice(),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              _l.groupNoMessage,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final messages = state.messages;
                          final rawMessage = messages[index];
                          // Superposition des mises à jour temps réel non
                          // portées par GroupChatController — voir
                          // _onRichContentEvent.
                          final message = _patches[rawMessage.id] ?? rawMessage;
                          final isFirstInGroup =
                              index == 0 ||
                              messages[index - 1].senderId != message.senderId;
                          final isLastInGroup =
                              index == messages.length - 1 ||
                              messages[index + 1].senderId != message.senderId;
                          // Séparateur de date au changement de journée,
                          // même règle que dans une conversation 1:1 (voir
                          // day_separator.dart).
                          final needsDaySeparator =
                              index == 0 ||
                              isDifferentDay(
                                messages[index - 1].createdAt,
                                message.createdAt,
                              );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // En tête du fil, une seule fois : il est le
                              // début de l'historique, pas d'une page.
                              if (index == 0 && !state.hasOlder)
                                const GroupEncryptionNotice(),
                              if (index == 0 && state.loadingOlder)
                                const OlderMessagesLoader(),
                              if (needsDaySeparator)
                                DaySeparator(instant: message.createdAt),
                              // Un appel terminé se range au centre, pas en
                              // bulle : c'est un événement du groupe, pas la
                              // parole de quelqu'un. « Rappeler » relance ou
                              // rejoint l'appel en cours, exactement comme
                              // le bandeau du haut.
                              if (message.messageType == 'CALL' &&
                                  message.payload != null)
                                CallEventRow(
                                  payload: message.payload!,
                                  isMine: message.senderId == widget.myUserId,
                                  onCallBack: ({required video}) =>
                                      _startOrJoinCall(withVideo: video),
                                )
                              else if ((message.payload?['kind']) ==
                                  'proof_mode')
                                ProofModeNotice(
                                  text: message.payload?['enabled'] == true
                                      ? _l.proofModeOn(
                                          _authorName(
                                            message.senderId,
                                            message.senderName,
                                          ),
                                        )
                                      : _l.proofModeOff(
                                          _authorName(
                                            message.senderId,
                                            message.senderName,
                                          ),
                                        ),
                                )
                              else if (message.deletedAt != null)
                                ProofKeptMessage(
                                  key: _keyFor(message.id),
                                  author: _authorName(
                                    message.senderId,
                                    message.senderName,
                                    certifiedName: message.senderCertifiedName,
                                  ),
                                  content: message.content,
                                  isMine: message.senderId == widget.myUserId,
                                )
                              else if (message.originalContent != null)
                                // Modifié en mode preuve (maquette 14) : la
                                // version d'origine reste lisible de tous.
                                ProofKeptMessage(
                                  key: _keyFor(message.id),
                                  author: _authorName(
                                    message.senderId,
                                    message.senderName,
                                    certifiedName: message.senderCertifiedName,
                                  ),
                                  content: message.content,
                                  original: message.originalContent,
                                  editedAt: message.editedAt,
                                  isMine: message.senderId == widget.myUserId,
                                )
                              else
                                KeyedSubtree(
                                  key: _keyFor(message.id),
                                  child: MessageAppear(
                                    messageId: message.id,
                                    isMine: message.senderId == widget.myUserId,
                                    isLast: index == messages.length - 1,
                                    child: _GroupBubble(
                                      message: message,
                                      senderDisplayName: _authorName(
                                        message.senderId,
                                        message.senderName,
                                        certifiedName:
                                            message.senderCertifiedName,
                                      ),
                                      replySenderDisplayName:
                                          message.replyTo == null
                                          ? null
                                          : _authorName(
                                              message.replyTo!.senderId,
                                              message.replyTo!.senderName ??
                                                  _l.commonUnknownName,
                                              certifiedName: message
                                                  .replyTo!
                                                  .senderCertifiedName,
                                            ),
                                      isMine:
                                          message.senderId == widget.myUserId,
                                      isFirstInGroup: isFirstInGroup,
                                      isLastInGroup: isLastInGroup,
                                      isPending: state.pendingIds.contains(
                                        message.id,
                                      ),
                                      isFailed: state.failedIds.contains(
                                        message.id,
                                      ),
                                      onRetry: () => ref
                                          .read(
                                            groupChatControllerProvider(
                                              widget.groupId,
                                            ).notifier,
                                          )
                                          .retry(message.id),
                                      onLongPress: () =>
                                          _showReactionSheet(message),
                                      onReactionPick: (emoji) =>
                                          _reactTo(message, emoji),
                                      onTapReply: message.replyToId == null
                                          ? null
                                          : () => _scrollToMessage(
                                              message.replyToId!,
                                            ),
                                      onPollVoted: (updated) {
                                        setState(
                                          () => _patches[message.id] = message
                                              .copyWith(poll: updated),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 14,
                        color: AppColors.semanticError,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                            color: AppColors.semanticError,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, _emojiOpen ? 8 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_composer.mode == ComposerMode.recording ||
                        _composer.mode == ComposerMode.cancelling)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: LockAffordance(
                            progress: _composer.lockProgress,
                          ),
                        ),
                      ),
                    if (_replyingTo case final replyingTo?)
                      _GroupReplyComposerPreview(
                        message: replyingTo,
                        onClose: () => setState(() => _replyingTo = null),
                      ),
                    _composerRow(state),
                    // Les suggestions, SOUS la barre. Jamais en même temps
                    // que le panneau, qui montre déjà des stickers.
                    if (!_emojiOpen)
                      StickerSuggestionBar(
                        emoji: _trailingEmoji,
                        onSelected: _sendSticker,
                      ),
                  ],
                ),
              ),
              // Le panneau emoji/stickers occupe TOUTE la largeur et descend
              // jusqu'au bas de l'écran, comme le clavier qu'il remplace : il
              // flottait en retrait, avec le papier peint visible autour.
              if (_emojiOpen)
                ComposerPanel(
                  controller: _inputController,
                  height: _keyboardHeight,
                  onBackspace: _emojiBackspace,
                  tab: _panelTab,
                  onTabChanged: (tab) => setState(() => _panelTab = tab),
                  onStickerSelected: _sendSticker,
                  onGifRequested: () {
                    setState(() => _emojiOpen = false);
                    _pickAndSendGif();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composerRow(GroupChatState state) {
    // Groupe d'annonces et je ne suis pas administrateur : on le dit au lieu
    // de laisser écrire un message que le serveur refuserait (403).
    final group = state.group;
    if (group != null && !group.canPost) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_outlined,
              size: 16,
              color: AppColors.chatIconMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _l.groupAdminsOnly,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.chatIconMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final busy = state.sending || state.uploading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // SEULE la pilule change pendant l'enregistrement : le bouton de
        // droite porte le geste de l'appui long et doit rester monté, sans
        // quoi ni le glissement pour annuler ni le verrouillage ne lui
        // parviennent (voir recording_bar.dart).
        if (_composer.isRecording)
          Expanded(
            child: ListenableBuilder(
              listenable: _voice,
              builder: (context, _) => RecordingBar(
                state: _composer,
                elapsed: _voice.elapsed,
                levels: _voice.levels,
                onCancel: () {
                  setState(
                    () => _composer = _composerMachine.onCancel(_composer),
                  );
                  unawaited(_voice.cancel());
                },
              ),
            ),
          )
        else
          Expanded(
            // La même pilule qu'en conversation — voir composer_input.dart.
            child: ComposerInputPill(
              controller: _inputController,
              onContentInserted: (content) =>
                  unawaited(_sendInsertedContent(content)),
              focusNode: _inputFocus,
              hintText: _l.conversationMessageHint,
              emojiOpen: _emojiOpen,
              enabled: !busy,
              onFieldTap: () {
                if (_emojiOpen) _closePanelForKeyboard();
              },
              onSubmitted: (_) => _send(),
              onAttach: _showAttachmentSheet,
              onToggleEmoji: _toggleEmoji,
              onCamera: () => _pickImage(ImageSource.camera),
              attachTooltip: L.of(context).a11yAttach,
              emojiTooltip: L.of(context).stickerTabEmoji,
              cameraTooltip: _l.convAttachCamera,
            ),
          ),
        const SizedBox(width: 10),
        ComposerActionButton(
          state: _composer,
          machine: _composerMachine,
          enabled: !busy,
          onSendText: _send,
          onSendRecording: () {
            setState(() => _composer = _composerMachine.onSend(_composer));
            unawaited(_sendRecording());
          },
          onRecordStart: _beginRecording,
          onStateChanged: (next) => setState(() => _composer = next),
          onRelease: (action) => unawaited(_finishRecording(action)),
          busyChild: busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// « Appel en cours · Rejoindre » — visible pour un membre qui a refusé ou
/// manqué l'appel alors que les autres se parlent encore. N'occupe aucune
/// place quand il n'y a pas d'appel (et en cas d'erreur réseau : un bandeau
/// d'appel fantôme serait pire que pas de bandeau).
class _GroupReplyComposerPreview extends StatelessWidget {
  const _GroupReplyComposerPreview({
    required this.message,
    required this.onClose,
  });

  final GroupMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final preview = message.content?.trim().isNotEmpty == true
        ? message.content!.trim()
        : message.messageType;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 17,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName.isEmpty
                      ? l.conversationReply
                      : message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: L.of(context).actionClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ActiveCallBanner extends ConsumerWidget {
  const _ActiveCallBanner({required this.groupId, required this.onJoin});

  final int groupId;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref
        .watch(activeGroupCallProvider(groupId))
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (call == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.accentPrimaryDark,
        borderRadius: AppRadius.card,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onJoin,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  call.isVideo ? Icons.videocam : Icons.call,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    L.of(context).groupCallOngoing,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  L.of(context).actionJoin,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône minimaliste de l'en-tête et de la barre de saisie (copie locale de
/// celle de conversation_screen.dart, privée à ce fichier là-bas).
class _ChatIconButton extends StatelessWidget {
  const _ChatIconButton({required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;

  /// Le libellé lu par un lecteur d'écran, et affiché à l'appui long.
  ///
  /// Ces boutons enveloppent un `InkWell` nu : sans lui, TalkBack et
  /// VoiceOver annoncent « bouton » sans dire lequel. Une seule propriété
  /// couvre les deux besoins.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: Icon(icon, size: 22, color: AppColors.chatIconMuted),
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}

class _GroupBubble extends StatefulWidget {
  const _GroupBubble({
    required this.message,
    required this.senderDisplayName,
    this.replySenderDisplayName,
    required this.isMine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onRetry,
    required this.onLongPress,
    required this.onReactionPick,
    required this.onPollVoted,
    this.onTapReply,
    this.isPending = false,
    this.isFailed = false,
  });

  final GroupMessage message;

  /// Le nom à afficher au-dessus de la bulle — résolu par l'écran, qui
  /// connaît le carnet (voir `_authorName`).
  final String senderDisplayName;
  final String? replySenderDisplayName;
  final bool isMine;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// Voir _Bubble dans messaging/presentation/conversation_screen.dart —
  /// même sémantique, même affichage.
  final bool isPending;
  final bool isFailed;
  final VoidCallback onRetry;

  /// Ouvre le sélecteur de réaction rapide — pas d'actions de transfert/
  /// suppression côté groupe pour l'instant (aucune n'existait déjà avant
  /// cette bulle, hors du périmètre de cette mission).
  final VoidCallback onLongPress;

  /// Tap sur une pastille de réaction déjà posée — bascule ma réaction.
  final void Function(String emoji) onReactionPick;

  /// Défilement best-effort vers le message cité.
  final VoidCallback? onTapReply;

  /// Sondage voté/changé — remonté à l'écran.
  final void Function(PollData updated) onPollVoted;

  @override
  State<_GroupBubble> createState() => _GroupBubbleState();
}

class _GroupBubbleState extends State<_GroupBubble> {
  // Heure permanente sous chaque bulle, comme en 1:1 (voir
  // conversation_screen.dart).
  static const _showTimestamp = true;

  GroupMessage get message => widget.message;
  bool get isMine => widget.isMine;

  bool get _isFlushMedia {
    if (message.media == null) return false;
    if (message.messageType != 'IMAGE' && message.messageType != 'VIDEO')
      return false;
    return message.content == null || message.content!.trim().isEmpty;
  }

  /// Un sticker : ni bulle, ni cadre, ni fond — voir le pendant 1:1 dans
  /// conversation_screen.dart. Sa transparence fait partie du dessin ;
  /// l'enfermer dans le cadre des médias le poserait sur un rectangle de
  /// couleur, et le découpage n'aurait servi à rien.
  bool get _isSticker =>
      message.messageType == 'STICKER' && message.media != null;

  /// Même taille qu'en tête-à-tête : un sticker ne doit pas changer de
  /// dimension selon qu'on écrit à une personne ou à un groupe.
  static const double _stickerSize = 128;

  Widget _mediaWidget(MediaMeta media) => switch (message.messageType) {
    'STICKER' => StickerImage(mediaId: media.id, size: _stickerSize),
    'AUDIO' => AudioMessageBubble(
      media: media,
      isMine: isMine,
      mediaKey: message.mediaKey,
    ),
    'IMAGE' => ImageMessageBubble(media: media),
    'VIDEO' => VideoMessageBubble(media: media),
    _ => DocumentMessageBubble(media: media, isMine: isMine),
  };

  /// POLL/LOCATION/CONTACT n'ont pas de pièce jointe — voir le pendant 1:1
  /// dans conversation_screen.dart::_richContentWidget.
  Widget? _richContentWidget(L l, TextStyle textStyle) {
    switch (message.messageType) {
      case 'POLL':
        final poll = message.poll;
        if (poll == null)
          return Text(message.content ?? l.mediaPoll, style: textStyle);
        return PollBubble(poll: poll, onVoted: widget.onPollVoted);
      case 'LOCATION':
        final payload = message.payload;
        if (payload == null)
          return Text(message.content ?? l.mediaLocation, style: textStyle);
        return LocationBubble(payload: payload);
      case 'CONTACT':
        final payload = message.payload;
        if (payload == null)
          return Text(message.content ?? l.mediaContact, style: textStyle);
        return ContactCardBubble(payload: payload);
      default:
        return null;
    }
  }

  Widget _content() {
    final textStyle = TextStyle(color: AppColors.chatTextReceived, height: 1.5);

    final richContent = _richContentWidget(L.of(context), textStyle);
    if (richContent != null) return richContent;

    // Pas encore ouvert : une re-livraison a été demandée à l'expéditeur
    // (voir e2ee_retry_service.dart). Le dire, plutôt qu'une bulle vide.
    if (message.isEncrypted && message.mediaAssetId == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              L.of(context).messageWaiting,
              style: textStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    }

    // Pièce jointe pas encore partie : même bulle qu'en tête-à-tête, même
    // aperçu local, mêmes états. Les deux conversations ne doivent pas se
    // comporter différemment pour une photo.
    if (message.pendingMedia != null) {
      return PendingMediaBubble.group(
        message: message,
        onRetry: widget.onRetry,
      );
    }

    final media = message.media;
    if (media == null) {
      final emojis = emojiOnlyCount(message.content);
      if (emojis != null) {
        return Text(
          message.content!.trim(),
          style: emojiOnlyStyle(textStyle, emojis),
        );
      }
      // Mentions ET numéros de téléphone se combinent sur le même texte,
      // d'où ce widget dédié plutôt que réutiliser LinkifiedText tel quel
      // (voir _GroupMessageText).
      return _GroupMessageText(
        text: message.content ?? '',
        mentions: message.mentions,
        style: textStyle,
      );
    }

    final mediaWidget = _mediaWidget(media);
    if (message.content == null || message.content!.trim().isEmpty)
      return mediaWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        mediaWidget,
        const SizedBox(height: 6),
        _GroupMessageText(
          text: message.content!,
          mentions: message.mentions,
          style: textStyle,
        ),
      ],
    );
  }

  /// Toujours visible, contrairement à l'horodatage qui se révèle au tap :
  /// « en attente » et « échec » sont les deux états où l'expéditeur doit
  /// savoir sans geste que son message n'est pas parti.
  Widget? _persistentStateBadge() {
    if (!widget.isMine || (!widget.isPending && !widget.isFailed)) return null;
    final failed = widget.isFailed;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
      child: GestureDetector(
        onTap: failed ? widget.onRetry : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.schedule,
              size: 12,
              color: failed ? AppColors.semanticError : AppColors.chatTimestamp,
            ),
            const SizedBox(width: 4),
            Text(
              failed
                  ? L.of(context).msgNotSentRetry
                  : L.of(context).msgPendingSend,
              style: TextStyle(
                fontSize: 10,
                color: failed
                    ? AppColors.semanticError
                    : AppColors.chatTimestamp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timestampRow() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: !_showTimestamp
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.Hm().format(message.createdAt),
                    style: TextStyle(
                      color: AppColors.chatTimestamp,
                      fontSize: 10,
                    ),
                  ),
                  if (message.isEdited)
                    EditedLabel(color: AppColors.chatTimestamp),
                ],
              ),
            ),
    );
  }

  /// Voir conversation_screen.dart::_Bubble._replyBanner — même bandeau,
  /// `sender_name` est déjà fourni par groups.py (contrairement à messages.py),
  /// donc pas besoin de le déduire ici.
  Widget? _replyBanner() {
    final preview = message.replyTo;
    if (preview == null) return null;
    return ReplyPreviewBanner(
      preview: preview,
      senderLabel:
          widget.replySenderDisplayName ??
          preview.senderName ??
          L.of(context).commonUnknownName,
      isMine: isMine,
      onTap: widget.onTapReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8;
    final marginTop = widget.isFirstInGroup ? 16.0 : 8.0;
    // Le nom de l'auteur n'apparaît qu'en tête de bloc et seulement sur les
    // bulles reçues : dans un groupe, savoir qui parle est indispensable,
    // mais le répéter à chaque bulle consécutive alourdit la lecture.
    final senderLabel = !isMine && widget.isFirstInGroup
        ? Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.senderDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.authorName(message.senderId),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (message.senderIsVerified) ...[
                  const SizedBox(width: 3),
                  const VerifiedBadge(size: 13),
                ],
              ],
            ),
          )
        : null;

    // Coins arrondis partout sauf le coin qui pointe vers l'émetteur sur la
    // PREMIÈRE bulle d'un groupe de messages consécutifs — voir le pendant
    // 1:1 dans conversation_screen.dart::_BubbleState.build pour le détail.
    const fullRadius = Radius.circular(20);
    // 2 points, comme en tête-à-tête : les deux écrans doivent rendre
    // la même bulle, sinon la même conversation change de forme selon
    // qu'elle a deux ou dix participants.
    const tailRadius = Radius.circular(2);
    final radius = widget.isFirstInGroup
        // Coin réduit EN HAUT, comme en tête-à-tête — voir
        // conversation_screen.dart pour le pourquoi.
        ? BorderRadius.only(
            topLeft: isMine ? fullRadius : tailRadius,
            topRight: isMine ? tailRadius : fullRadius,
            bottomLeft: fullRadius,
            bottomRight: fullRadius,
          )
        : const BorderRadius.all(fullRadius);

    // Le sticker en premier : rien autour de lui, pas même le cadre des
    // médias « à nu ». Toute enveloppe reviendrait à remettre ce qu'on
    // vient d'enlever.
    final Widget body = _isSticker
        ? StickerImage(mediaId: message.media!.id, size: _stickerSize)
        : _isFlushMedia
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.chatMediaFrame,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.chatMediaFrameBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _content(),
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              // Maquette Figma : bulle envoyée en dégradé pêche, bulle
              // reçue blanche cerclée. À plat : aucune ombre sous les bulles.
              color: isMine
                  ? AppColors.chatBubbleSent
                  : AppColors.chatBubbleReceived,
              gradient: isMine ? AppGradients.sentBubble : null,
              borderRadius: radius,
              border: isMine
                  ? null
                  : Border.all(color: AppColors.chatBubbleReceivedBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [?_replyBanner(), _content()],
            ),
          );

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(top: marginTop),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              ?senderLabel,
              body,
              // Pastille de réaction superposée au coin inférieur de la bulle
              // — voir le pendant 1:1 pour la justification de la translation
              // plutôt qu'un Stack/Positioned dans une ListView virtualisée.
              if (message.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Align(
                    alignment: isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isMine ? 0 : 14,
                        right: isMine ? 14 : 0,
                      ),
                      child: ReactionPillRow(
                        reactions: message.reactions,
                        onTap: widget.onReactionPick,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _timestampRow(),
              ),
              ?_persistentStateBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texte d'un message de groupe avec mentions "@Nom" en surbrillance ET
/// numéros de téléphone tappables, combinés sur le même texte. L'API ne
/// donne pas d'offset de mention (voir groups.py::_serialize_mentions), la
/// correspondance se fait donc par recherche textuelle de "@Nom" — best
/// effort si le nom a changé depuis l'envoi (renommage, contact modifié).
class _GroupMessageText extends StatefulWidget {
  const _GroupMessageText({
    required this.text,
    required this.mentions,
    required this.style,
  });

  final String text;
  final List<GroupMentionRef> mentions;
  final TextStyle style;

  @override
  State<_GroupMessageText> createState() => _GroupMessageTextState();
}

class _MentionOrPhoneRange {
  _MentionOrPhoneRange(this.start, this.end, {required this.isMention});
  final int start;
  final int end;
  final bool isMention;
}

class _GroupMessageTextState extends State<_GroupMessageText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final text = widget.text;

    // Étendues des mentions : toutes les occurrences de "@Nom" par personne
    // citée — une mention peut apparaître plusieurs fois dans un long message.
    final ranges = <_MentionOrPhoneRange>[];
    for (final mention in widget.mentions) {
      final needle = '@${mention.displayName}';
      if (needle.length <= 1) continue;
      var searchFrom = 0;
      while (true) {
        final index = text.indexOf(needle, searchFrom);
        if (index == -1) break;
        ranges.add(
          _MentionOrPhoneRange(index, index + needle.length, isMention: true),
        );
        searchFrom = index + needle.length;
      }
    }

    // Étendues des numéros plausibles, hors des étendues déjà prises par une
    // mention (un numéro ne devrait jamais chevaucher un "@Nom", mais la
    // garde évite un rendu incohérent si ça arrivait).
    for (final match in findPhoneMatches(text)) {
      final overlaps = ranges.any(
        (r) => match.start < r.end && r.start < match.end,
      );
      if (!overlaps)
        ranges.add(
          _MentionOrPhoneRange(match.start, match.end, isMention: false),
        );
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final range in ranges) {
      if (range.start < lastEnd) continue;
      if (range.start > lastEnd)
        spans.add(TextSpan(text: text.substring(lastEnd, range.start)));
      final raw = text.substring(range.start, range.end);
      if (range.isMention) {
        spans.add(
          TextSpan(
            text: raw,
            style: widget.style.copyWith(
              fontWeight: FontWeight.w700,
              backgroundColor:
                  (widget.style.color ?? AppColors.chatTextReceived).withValues(
                    alpha: 0.12,
                  ),
            ),
          ),
        );
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => handlePhoneTap(context, raw);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: raw,
            style: widget.style.copyWith(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
            recognizer: recognizer,
          ),
        );
      }
      lastEnd = range.end;
    }
    if (lastEnd < text.length)
      spans.add(TextSpan(text: text.substring(lastEnd)));
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Ce que le fil d'un groupe dit du chiffrement — en tête, une fois.
///
/// Les groupes sont chiffrés de bout en bout par clés d'expéditeur (Signal
/// sender keys) : le serveur refuse tout message en clair et ne stocke que
/// du chiffré. Les clés changent à chaque arrivée ou départ (crypto_epoch).
class GroupEncryptionNotice extends StatelessWidget {
  const GroupEncryptionNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: EncryptionNotice(text: L.of(context).groupNotEncryptedNotice),
  );
}
