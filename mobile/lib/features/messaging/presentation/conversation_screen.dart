import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/media/media_repository.dart'
    show MediaMeta, mediaExtension;
import '../../../core/providers.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/notifications/active_conversation.dart';
import 'composer/composer_state.dart';
import 'composer/mic_button.dart';
import 'composer/recording_bar.dart';
import 'composer/voice_recording.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/media/media_export.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_exceptions.dart';
import '../../stickers/data/sticker_models.dart';
import '../../stickers/presentation/sticker_image.dart';
import '../../stickers/presentation/sticker_suggestion_bar.dart';
import '../../stickers/presentation/trailing_emoji.dart';
import '../../stickers/presentation/sticker_providers.dart';
import 'composer/composer_input.dart';
import 'composer/composer_panel.dart';
import 'encryption_banner.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/chat_wallpaper.dart';
import '../../calls/presentation/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../marketplace/data/product_model.dart';
import '../../profile/presentation/contact_profile_screen.dart';
import '../../shield/presentation/shield_controller.dart'
    show ShieldController, shieldControllerProvider;
import '../../shield/presentation/shield_overlay.dart';
import '../data/direct_message_model.dart';
import 'bubble_widgets.dart';
import 'contact_card_bubble.dart';
import '../../presence/presentation/typing_controller.dart';
import 'conversation_search_screen.dart';
import 'bot_widgets.dart';
import 'day_separator.dart';
import 'link_preview_card.dart';
import 'location_bubble.dart';
import 'media_bubble.dart';
import 'message_appear.dart';
import 'media_composer_screen.dart';
import 'messaging_controller.dart';
import '../../../core/widgets/identity_avatar.dart';
import 'call_event_row.dart';
import 'pending_media_bubble.dart';
import 'proof_export.dart';
import 'proof_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/certified_screen.dart';
import 'poll_bubble.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../contacts/presentation/discussions_controller.dart';

List<String> _lastMessagesForShield(List<DirectMessage> messages) {
  return messages.reversed
      .take(5)
      .toList()
      .reversed
      .map((m) => m.content ?? '[${m.messageType}]')
      .toList();
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.myUserId,
    required this.contactUserId,
    required this.contactName,
    this.contactPhone,
    this.product,
  });

  final int myUserId;
  final int contactUserId;
  final String contactName;

  /// Renseigné quand on ouvre une discussion avec quelqu'un qui n'est PAS
  /// dans le carnet — depuis « Nouvelle discussion », un numéro reçu, une
  /// carte de visite. Sert de laissez-passer au premier message : voir
  /// ConversationKey.contactPhone.
  final String? contactPhone;

  /// Produit à garder visible dans le fil quand la discussion vient du
  /// marché. Null pour toutes les conversations ouvertes ailleurs.
  final MarketplaceProduct? product;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _inputController = TextEditingController();

  /// Le focus du champ de saisie, tenu explicitement : c'est lui qui permet
  /// de refermer le panneau emoji ET de revenir taper en un seul geste.
  final _inputFocus = FocusNode();

  /// Les textes traduits, lus à travers le `context` de cet État.
  ///
  /// Un raccourci et non une variable capturée : après un `await`, la
  /// variable pointerait sur la langue d'AVANT si l'utilisateur vient d'en
  /// changer, alors que le getter relit toujours la bonne.
  L get _l => L.of(context);

  late final TypingSignal _typing;
  final _scrollController = ScrollController();

  /// La barre d'écriture comme MACHINE À ÉTATS : écrire, enregistrer,
  /// s'apprêter à annuler, verrouillé. Des booléens séparés autorisaient
  /// des combinaisons qui n'ont pas de sens — verrouillé ET en train
  /// d'annuler — et c'est ainsi qu'un enregistrement continue après l'envoi.
  static const _composerMachine = ComposerMachine();
  ComposerState _composer = const ComposerState();
  late final VoiceRecordingController _voice = VoiceRecordingController();

  bool _hasText = false;
  bool _slashMode = false;
  DirectMessage? _replyingTo;

  /// Le mode preuve de la discussion, le même pour les deux côtés.
  DirectProofMode _proof = DirectProofMode.off;

  /// Préfixe de l'ANCIEN format, gardé en lecture seule.
  ///
  /// Les commandes envoyées avant la route dédiée portent encore ce
  /// marqueur dans leur texte. Ne plus savoir les lire transformerait
  /// l'historique de ces conversations en suite de lignes techniques.
  /// Plus rien ne l'ÉCRIT — voir `_sendOrderUpdate`.
  static const _legacyOrderPrefix = '[POKOU_ORDER]';

  Future<void> _sendOrderUpdate(String status) async {
    final product =
        widget.product ??
        _productFromMessages(
          ref.read(messagingControllerProvider(_key)).messages,
        );
    if (product == null) return;

    final failure = await ref
        .read(messagingControllerProvider(_key).notifier)
        .sendOrderUpdate(productId: product.id, status: status);
    if (failure != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
      return;
    }
    _scrollToBottom();
  }

  /// Où en est la commande, d'après les messages ?
  ///
  /// Déduit de l'historique et non d'un booléen local : l'ancien
  /// `_showOrderActions` repartait à `true` à chaque ouverture de l'écran,
  /// si bien qu'une commande déjà livrée réaffichait « Valider la commande ».
  /// Les trois boutons étaient d'ailleurs toujours les mêmes, quel que soit
  /// l'état — on pouvait valider une commande après l'avoir livrée.
  String? _orderStatusFrom(List<DirectMessage> messages) {
    String? status;
    for (final message in messages) {
      final order = _orderOf(message);
      if (order != null) status = order['status'] as String?;
    }
    return status;
  }

  /// L'état porté par un message, quel que soit son format.
  ///
  /// `payload` d'abord — c'est une colonne de métadonnées, jamais chiffrée,
  /// lisible sans rien déchiffrer. Le texte ensuite, pour l'historique
  /// d'avant.
  static Map<String, dynamic>? _orderOf(DirectMessage message) {
    final order = message.payload?['pokou_order'];
    if (order is Map<String, dynamic>) return order;
    final content = message.content;
    if (content != null && content.startsWith(_legacyOrderPrefix)) {
      return {'label': content.substring(_legacyOrderPrefix.length).trim()};
    }
    return null;
  }

  MarketplaceProduct? _productFromMessages(List<DirectMessage> messages) {
    for (final message in messages) {
      if (message.messageType != 'PRODUCT' || message.payload == null) continue;
      final payload = message.payload!;
      final productId = payload['product_id'];
      final sellerId = payload['seller_id'];
      if (productId is! int || sellerId is! int) continue;
      return MarketplaceProduct(
        id: productId,
        sellerId: sellerId,
        sellerName: widget.contactName,
        name: payload['name'] as String? ?? L.of(context).convProductFallback,
        description: null,
        price: payload['price']?.toString() ?? '0',
        currency: payload['currency'] as String? ?? 'XOF',
      );
    }
    return null;
  }

  // Captured in initState rather than read from `ref` in dispose() — by the
  // time dispose() runs the element may already be unmounted, and reading
  // a provider off a disposed ConsumerStatefulElement throws.
  late final ShieldController _shieldController;

  /// Capturé en même temps que le contrôleur de bouclier, et pour la même
  /// raison : au démontage, lire un provider depuis un élément déjà retiré
  /// de l'arbre lève.
  late final StateController<ActiveConversation?> _activeConversation;

  // Superposition d'événements temps réel que MessagingController n'expose
  // pas encore dans son état (réaction, modification, vue unique, vote de
  // sondage) — voir _onRichContentEvent. Clé = id du message concerné,
  // valeur = message le plus à jour connu localement.
  final Map<String, DirectMessage> _patches = {};
  StreamSubscription? _richContentSub;

  // Une clé par bulle affichée, pour le défilement "best-effort" vers un
  // message cité (voir _scrollToMessage) — ListView.builder ne garde pas les
  // bulles hors champ construites indéfiniment, donc une clé dont le contexte
  // est encore vivant est justement la définition de "encore chargé" ici.
  final Map<String, GlobalKey> _bubbleKeys = {};

  ConversationKey get _key => ConversationKey(
    myUserId: widget.myUserId,
    contactUserId: widget.contactUserId,
    contactPhone: widget.contactPhone,
  );

  /// L'état de chiffrement de CETTE conversation.
  ///
  /// `unknown` au départ, et c'est délibéré : tant que le contrôle n'a pas
  /// abouti, l'écran n'affirme rien. Afficher « chiffré » par défaut serait
  /// exactement l'affirmation qu'un attaquant voudrait nous voir faire à sa
  /// place.
  ConversationEncryption _encryption = ConversationEncryption.unknown;

  /// Le panneau (emoji ou stickers) est-il ouvert ?
  bool _emojiOpen = false;

  /// Sur QUEL onglet il s'ouvrira.
  ///
  /// Gardé ici, et non dans le panneau : quelqu'un qui envoie trois
  /// stickers de suite referme le panneau entre chaque envoi, et le
  /// rouvrir sur l'onglet emoji lui ferait refaire le même geste à chaque
  /// fois.
  ComposerPanelTab _panelTab = ComposerPanelTab.emoji;

  /// L'emoji sur lequel se termine le champ de saisie, ou ''.
  ///
  /// Recalculé à chaque frappe plutôt que lu dans `build` : le champ
  /// déclenche déjà un `setState` par caractère pour le bouton d'envoi, et
  /// parcourir le texte à chaque reconstruction de l'écran — y compris
  /// celles qu'un message reçu provoque — serait payé pour rien.
  String _trailingEmoji = '';

  /// La hauteur du clavier, mémorisée pendant qu'il était visible.
  ///
  /// Le panneau emoji la reprend, pour que l'ouvrir ne fasse pas sauter
  /// toute la conversation : sans cela, le clavier disparaît, la vue
  /// remonte, le panneau apparaît, elle redescend — deux secousses pour un
  /// geste. 280 est la hauteur moyenne d'un clavier Android, utilisée tant
  /// qu'on n'en a pas vu un vrai.
  double _keyboardHeight = 280;

  /// Bascule entre le clavier et le panneau emoji.
  ///
  /// L'un ferme l'autre : les deux à la fois occuperaient tout l'écran et
  /// la conversation disparaîtrait. Le champ garde le FOCUS quand le
  /// panneau s'ouvre — c'est ce qui permet de revenir taper d'une touche,
  /// et de garder le curseur là où il était.
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

  /// Interroge le serveur et compare la clé publiée à celle de la session en
  /// cours — le branchement qui manquait à `identityChanged`.
  ///
  /// À l'ouverture de la conversation : c'est le seul moment où l'on est sûr
  /// que quelqu'un regarde l'écran et peut décider quoi faire d'un
  /// avertissement.
  Future<void> _checkEncryption() async {
    final identity = await ref
        .read(e2eeServiceProvider)
        .checkPeerIdentity(peerUserId: widget.contactUserId);
    if (!mounted) return;
    setState(() => _encryption = encryptionFromIdentity(identity));
  }

  /// L'utilisateur affirme avoir vérifié la nouvelle identité par un autre
  /// moyen. On oublie la session qui portait l'ancienne clé ; la prochaine
  /// poignée de main repartira du trousseau publié.
  Future<void> _acceptIdentity() async {
    await ref
        .read(e2eeServiceProvider)
        .acceptPeerIdentity(peerUserId: widget.contactUserId);
    if (!mounted) return;
    setState(() => _encryption = ConversationEncryption.encrypted);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_checkEncryption());
    unawaited(_reloadProof());
    _shieldController = ref.read(shieldControllerProvider.notifier);
    _activeConversation = ref.read(activeConversationProvider.notifier);
    _typing = TypingSignal(
      ref.read(presenceRepositoryProvider),
      'contact',
      widget.contactUserId,
    );
    _inputController.addListener(_onInputChanged);
    _scrollController.addListener(_maybeLoadOlder);
    _shieldController.setActiveConversation(widget.contactUserId);
    // Se notifier soi-même pendant qu'on lit la conversation est le défaut
    // le plus visible qu'une messagerie puisse avoir. Le serveur ne peut pas
    // le savoir — il voit une socket ouverte, pas l'écran affiché.
    //
    // Après la première image : modifier un provider pendant que l'arbre se
    // construit lève « Tried to modify a provider while the widget tree was
    // building ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeConversation.state = ActiveConversation.direct(
          widget.contactUserId,
        );
      }
    });
    _richContentSub = ref
        .read(wsClientProvider)
        .events
        .listen(_onRichContentEvent);
  }

  @override
  void dispose() {
    // Avant tout le reste : sans ce « j'ai fini », le correspondant voit
    // « écrit… » jusqu'à l'expiration côté réception, soit plusieurs secondes
    // après qu'on a quitté l'écran.
    _typing.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.removeListener(_maybeLoadOlder);
    _scrollController.dispose();
    // Quitter l'écran en cours d'enregistrement laissait le micro ouvert :
    // la pastille du système restait allumée sans moyen de l'éteindre.
    _voice.dispose();
    // Le démontage se produit pendant que Flutter verrouille l'arbre :
    // modifier Riverpod ici déclenche "Tried to modify a provider while the
    // widget tree was building". Le contrôleur est persistant, on peut donc
    // faire ce nettoyage juste après la phase de démontage.
    Future<void>.delayed(Duration.zero, () {
      _shieldController.setActiveConversation(null);
      _activeConversation.state = null;
    });
    _richContentSub?.cancel();
    super.dispose();
  }

  /// La version du serveur ([server]) — statut, réactions, vue — avec le
  /// clair déjà connu sur cet appareil ([local]).
  ///
  /// Le serveur ne renvoie que le chiffré : remplacer la bulle par sa
  /// réponse faisait disparaître la légende, et une photo chiffrée devenait
  /// un fichier « pokou.bin » d'un type inconnu. Une modification
  /// (`edited_at` différent) n'est pas recouverte : son nouveau chiffré
  /// doit être ouvert.
  String _proofAuthor(DirectMessage message) =>
      message.senderId == widget.myUserId ? _l.proofExportMe : widget.contactName;

  DirectMessage _withLocalClear(DirectMessage server, DirectMessage? local) {
    if (!server.isEncrypted || local == null || local.isEncrypted) return server;
    if (local.editedAt != server.editedAt) return server;
    return server.resolvedWith(local);
  }

  GlobalKey _keyFor(String messageId) =>
      _bubbleKeys.putIfAbsent(messageId, () => GlobalKey());

  /// MessagingController ne traite que `message:new`/`message:status`/
  /// `message:deleted` (voir messaging_controller.dart::_onEvent) — hors de
  /// notre périmètre à modifier. Les événements de contenu riche (réaction,
  /// modification, vue unique, vote) sont donc écoutés ICI, en plus, pour
  /// mettre à jour l'affichage sans recharger toute la conversation.
  void _onRichContentEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    if (type == 'message:edited' ||
        type == 'message:reaction' ||
        type == 'message:viewed') {
      final raw = event['message'] as Map<String, dynamic>?;
      if (raw == null) return;
      final message = DirectMessage.fromJson(raw);
      final belongs =
          (message.senderId == widget.contactUserId &&
              message.recipientId == widget.myUserId) ||
          (message.senderId == widget.myUserId &&
              message.recipientId == widget.contactUserId);
      if (!belongs || !mounted) return;
      final previous = _findMessage(message.id);
      var merged = _withLocalClear(message, previous);
      // Mode preuve à deux : la version d'origine d'un message chiffré n'est
      // QUE sur cet appareil — on la met de côté avant qu'elle ne soit
      // recouverte.
      final original = type == 'message:edited' && message.proofMode
          ? (previous?.originalContent ??
                (previous != null && !previous.isEncrypted && previous.editedAt != message.editedAt
                    ? previous.content
                    : null))
          : null;
      if (original != null && merged.originalContent == null) {
        merged = merged.copyWith(originalContent: original);
      }
      if (merged.isEncrypted) {
        // Une modification apporte un NOUVEAU chiffré : il faut l'ouvrir.
        unawaited(
          ref
              .read(messagingRepositoryProvider)
              .decryptIncoming(merged, widget.contactUserId)
              .then((opened) {
                final kept = original != null && opened.originalContent == null
                    ? opened.copyWith(originalContent: original)
                    : opened;
                if (mounted) setState(() => _patches[kept.id] = kept);
              }),
        );
        return;
      }
      setState(() => _patches[message.id] = merged);
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

  /// Le décompte de réactions tel qu'il sera, vu d'ici.
  ///
  /// Approché, et assumé comme tel : on ne connaît pas les réactions
  /// arrivées pendant la coupure. Ce qui compte est que MON geste se voie
  /// immédiatement ; la réponse du serveur remettra les chiffres d'aplomb.
  List<MessageReactionSummary> _reactionsLocales(
    DirectMessage message,
    String emoji, {
    required bool retire,
  }) {
    final sortie = <MessageReactionSummary>[];
    var trouve = false;
    for (final r in message.reactions) {
      if (r.emoji != emoji) {
        sortie.add(r);
        continue;
      }
      trouve = true;
      final compte = retire ? r.count - 1 : r.count + 1;
      // Une réaction retombée à zéro disparaît : laisser « 👍 0 » serait
      // plus déroutant que de ne rien laisser.
      if (compte > 0) {
        sortie.add(
          MessageReactionSummary(
            emoji: emoji,
            count: compte,
            userIds: r.userIds,
            mine: !retire,
          ),
        );
      }
    }
    if (!trouve && !retire) {
      sortie.add(
        MessageReactionSummary(
          emoji: emoji,
          count: 1,
          userIds: const [],
          mine: true,
        ),
      );
    }
    return sortie;
  }

  DirectMessage? _findMessage(String messageId) {
    final patched = _patches[messageId];
    if (patched != null) return patched;
    for (final message
        in ref.read(messagingControllerProvider(_key)).messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  /// La recherche renvoie l'identifiant du message choisi et c'est ICI qu'on
  /// défile jusqu'à lui — même mécanique que le tap sur une réponse citée.
  Future<void> _openSearch() async {
    final messageId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ConversationSearchScreen(
          contactUserId: widget.contactUserId,
          contactName: widget.contactName,
        ),
      ),
    );
    if (messageId == null || !mounted) return;
    // Laisse la liste se reconstruire après le retour avant de chercher la
    // clé de la bulle : elle n'existe pas tant qu'elle n'est pas montée.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) _scrollToMessage(messageId);
  }

  /// Best-effort : ne fait rien si le message cité n'est plus construit (voir
  /// _bubbleKeys). Aucune erreur affichée — un aperçu de réponse reste utile
  /// même quand on ne peut pas y sauter.
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

  Future<void> _reactTo(DirectMessage message, String emoji) async {
    final repository = ref.read(messagingRepositoryProvider);
    final alreadyMine = message.reactions.any(
      (r) => r.emoji == emoji && r.mine,
    );
    try {
      final updated = alreadyMine
          ? await repository.removeReaction(message.id)
          : await repository.setReaction(messageId: message.id, emoji: emoji);
      if (!mounted) return;
      setState(() => _patches[message.id] = _withLocalClear(updated, message));
    } on NetworkException {
      // ── Hors ligne : le geste est GARDÉ, pas perdu ──────────────────
      //
      // Il échouait silencieusement : on voyait l'emoji apparaître, puis
      // disparaître au rechargement, sans explication et sans savoir lequel
      // des deux états était le vrai.
      //
      // La clé d'idempotence fait que réagir, retirer, puis réagir
      // autrement ne laisse qu'UNE action en file — la dernière, celle
      // qu'on voit à l'écran. Sans elle, les trois repartiraient dans un
      // ordre qu'on ne contrôle pas, pour un résultat qui n'est aucun des
      // trois.
      await ref
          .read(pokouMessageStoreProvider)
          .enqueueAction(
            kind: alreadyMine ? 'reaction:remove' : 'reaction:set',
            targetId: message.id,
            payload: alreadyMine ? null : {'emoji': emoji},
          );
      // L'écran montre le geste TOUT DE SUITE : c'est ce qui le rend
      // crédible, et la file le rendra vrai. Le décompte local n'est
      // qu'approché — il ignore les réactions des autres arrivées
      // entre-temps — mais il sera remplacé par la vérité du serveur dès
      // que la file aura rejoué le geste.
      if (mounted) {
        setState(
          () => _patches[message.id] = message.copyWith(
            reactions: _reactionsLocales(message, emoji, retire: alreadyMine),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.convReactionFailed)));
      }
    }
  }

  Future<void> _markViewOnceViewed(DirectMessage message) async {
    try {
      final updated = await ref
          .read(messagingRepositoryProvider)
          .markViewOnceViewed(message.id);
      if (!mounted) return;
      setState(() => _patches[message.id] = _withLocalClear(updated, message));
    } catch (_) {
      // Best-effort : un événement WS `message:viewed` ou un futur
      // rechargement rattraperont l'état si cet appel échoue en silence.
    }
  }

  void _onInputChanged() {
    final text = _inputController.text;
    final hasText = text.trim().isNotEmpty;
    // Prévenir qu'on écrit. `TypingSignal` limite lui-même la cadence : un
    // appel par lettre enverrait une requête par frappe.
    if (hasText) {
      _typing.onChanged();
    } else {
      _typing.stop();
    }
    final slashMode = text.startsWith('/');
    if (hasText != _hasText) {
      // Cue the mic/send action switch — the same tap target does two
      // unrelated things depending on field content, with no other
      // affordance signaling the switch just happened.
      HapticFeedback.selectionClick();
    }
    final nextComposer = _composerMachine.onTextChanged(
      _composer,
      _inputController.text,
    );
    // Les suggestions de stickers répondent au dernier emoji tapé. Comparé
    // avant de reconstruire : sans ce test, chaque lettre d'un message
    // ordinaire redessinerait l'écran alors que rien n'a changé.
    final emoji = trailingEmoji(text) ?? '';
    if (hasText != _hasText ||
        slashMode != _slashMode ||
        emoji != _trailingEmoji ||
        nextComposer != _composer) {
      setState(() {
        _hasText = hasText;
        _slashMode = slashMode;
        _trailingEmoji = emoji;
        _composer = nextComposer;
      });
    }
  }

  /// Remonter près du début charge la page précédente — et la lecture ne
  /// saute pas : la distance au BAS du fil est gardée, puisque c'est
  /// au-dessus que les messages s'ajoutent.
  Future<void> _maybeLoadOlder() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > 400) return;
    final current = ref.read(messagingControllerProvider(_key));
    if (!current.hasOlder || current.loadingOlder) return;
    final fromBottom = position.maxScrollExtent - position.pixels;
    await ref.read(messagingControllerProvider(_key).notifier).loadOlder();
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

  /// Un bouton de bot touché : son titre part en réponse citée au message
  /// qui le portait (voir BotButtonsRow).
  Future<void> _sendBotButton(DirectMessage source, String title) async {
    await ref
        .read(messagingControllerProvider(_key).notifier)
        .send(title, replyToId: source.id);
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    // Le message part : on n'écrit plus. Le dire tout de suite évite le
    // « écrit… » qui reste affiché sous un message déjà reçu.
    _typing.stop();
    _inputController.clear();
    final replyToId = _replyingTo?.id;
    setState(() => _replyingTo = null);
    try {
      await ref
          .read(messagingControllerProvider(_key).notifier)
          .send(text, replyToId: replyToId);
    } on EncryptionUnavailableException catch (exc) {
      if (!mounted) return;
      // Le texte est REMIS dans le champ. Un message refusé qu'on efface
      // quand même serait perdu, et la prudence se paierait alors d'une
      // frappe entière — de quoi donner envie de contourner la protection.
      _inputController.text = text;
      if (exc.reason == SealFailure.identityChanged) {
        setState(() => _encryption = ConversationEncryption.identityChanged);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(encryptionBlockedMessage(_l, exc.reason)),
          backgroundColor: AppColors.semanticError,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    _scrollToBottom();
  }

  void _startReply(DirectMessage message) {
    setState(() => _replyingTo = message);
    FocusScope.of(context).requestFocus();
  }

  Future<void> _sendMediaFile({
    required String path,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String messageType,
    String? caption,
    bool viewOnce = false,
  }) async {
    await ref
        .read(messagingControllerProvider(_key).notifier)
        .sendMedia(
          path: path,
          bytes: bytes,
          filename: filename,
          mimeType: mimeType,
          messageType: messageType,
          caption: caption,
          viewOnce: viewOnce,
        );
    _scrollToBottom();
  }

  /// Envoyer un sticker.
  ///
  /// Il part AU TOUCHER : pas d'aperçu, pas de confirmation. C'est le sens
  /// même d'un sticker — une réaction rapide. Une étape de plus le rendrait
  /// plus lent que d'écrire « 👍 ».
  ///
  /// Le panneau reste OUVERT après l'envoi : on en envoie souvent
  /// plusieurs d'affilée, et le refermer obligerait à le rouvrir entre
  /// chaque.
  /// Garder un sticker reçu.
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
      // 409 = le pack personnel est plein. Le dire avec le mot juste
      // plutôt qu'avec un code : la limite est une décision, pas une panne.
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

  Future<void> _sendSticker(Sticker sticker) async {
    // Les récents remontent tout de suite, sans attendre le réseau — c'est
    // un compteur d'usage, pas l'envoi lui-même.
    ref.read(stickerPanelProvider.notifier).noteSent(sticker);
    await ref
        .read(messagingControllerProvider(_key).notifier)
        .sendExistingMedia(
          mediaAssetId: sticker.mediaId,
          messageType: 'STICKER',
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

  /// Envoyer un GIF que l'on possède déjà.
  ///
  /// ── Pourquoi un chemin à part, et pas la galerie ────────────────────
  ///
  /// `ImagePicker` ré-encode ce qu'il rend (`imageQuality`), et un GIF
  /// ré-encodé devient une image FIXE : l'animation disparaît en silence.
  /// Passer par le sélecteur de fichiers rend l'original, octet pour octet.
  ///
  /// Il ne passe pas non plus par l'écran de préparation : recadrer ou
  /// annoter un GIF l'aplatirait de la même façon.
  ///
  /// ── Pourquoi PAS un fournisseur externe ─────────────────────────────
  ///
  /// GIPHY et consorts interdisent la mise en cache et exigent que les
  /// requêtes partent du client. Un GIF envoyé par leur intermédiaire
  /// voyagerait donc en clair, et le fournisseur apprendrait qui regarde
  /// quoi et quand — la fuite de métadonnées exacte que le chiffrement de
  /// bout en bout cherche à fermer.
  ///
  /// Un GIF de l'utilisateur suit donc le chemin de TOUS les médias Pokou :
  /// chiffré, déposé sur notre stockage, déchiffré chez le destinataire.
  /// Aucune clé d'API, aucune dépendance, et rien qui sorte.
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
      // Le type EXACT : envoyé en `application/octet-stream`, le GIF
      // s'afficherait comme un document à télécharger.
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

  /// Choisir une photo, puis la PRÉPARER avant de l'envoyer.
  ///
  /// Elle partait aussitôt choisie : pas d'aperçu, pas de recadrage, pas de
  /// légende. Une capture d'écran partait avec sa barre d'état, une photo de
  /// produit avec la moitié de l'atelier autour, et il ne restait qu'à
  /// supprimer et recommencer. C'est le geste le plus courant d'une
  /// messagerie, et c'était le seul qu'on ne pouvait pas rattraper.
  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await _ensurePermission(Permission.camera))
      return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null || !mounted) return;

    final prepared = await Navigator.of(context).push<PreparedMedia>(
      MaterialPageRoute(
        builder: (_) => MediaComposerScreen(
          file: File(picked.path),
          recipientName: widget.contactName,
        ),
      ),
    );
    // Revenir en arrière depuis l'écran de préparation ANNULE l'envoi : on
    // s'est trompé de photo, c'est le moment de le dire.
    if (prepared == null) return;

    await _sendMediaFile(
      path: prepared.file.path,
      bytes: await prepared.file.readAsBytes(),
      filename: picked.name,
      mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
      messageType: 'IMAGE',
      caption: prepared.caption,
      viewOnce: prepared.viewOnce,
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await _ensurePermission(Permission.camera))
      return;
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                Icons.gif_box_outlined,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.convAttachGif),
              onTap: () => Navigator.pop(sheetContext, 'gif'),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(_l.convAttachCamera),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            // DIS-2 : dire pourquoi la photo arrive plus légère.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                _l.attachCompressNote,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
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
      case 'gif':
        await _pickAndSendGif();
      case 'video_gallery':
        await _pickVideo(ImageSource.gallery);
      case 'camera':
        await _pickImage(ImageSource.camera);
    }
  }

  /// Le doigt vient de se poser sur le micro.
  Future<void> _beginRecording() async {
    if (!await _ensurePermission(Permission.microphone)) {
      if (mounted) setState(() => _composer = const ComposerState());
      return;
    }
    if (!await _voice.start() && mounted) {
      setState(() => _composer = const ComposerState());
    }
  }

  /// Le doigt s'est levé.
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
    // Une note d'une demi-seconde est un effleurement, pas un message :
    // l'envoyer encombre la conversation d'un bruit que personne n'écoutera.
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

  void _openContactProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactProfileScreen(
          contactUserId: widget.contactUserId,
          contactName: widget.contactName,
        ),
      ),
    );
  }

  Future<void> _startCall({required bool startWithVideo}) async {
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

  Future<void> _reloadProof() async {
    try {
      final proof = await ref.read(messagingRepositoryProvider).proofMode(widget.contactUserId);
      if (mounted) setState(() => _proof = proof);
    } catch (_) {
      // Hors ligne : le dernier message système dira l'état, voir build.
    }
  }

  /// Activer ou couper le mode preuve (maquettes 4b, 7 et 10).
  Future<void> _toggleProof(bool proofOn) async {
    try {
      final proof = await ref
          .read(messagingRepositoryProvider)
          .setProofMode(widget.contactUserId, !proofOn);
      if (!mounted) return;
      setState(() => _proof = proof);
      HapticFeedback.lightImpact();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403 && proofOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.proofDisableReservedDirect)),
        );
        return;
      }
      if (error.statusCode == 403) {
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
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CertifiedScreen()),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l.honamFailed)));
      }
    }
  }

  /// L'export daté, produit sur ce téléphone à partir de ce qu'il a gardé.
  Future<void> _exportProof(List<DirectMessage> messages) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = _l;
    try {
      final file = await exportDirectProof(
        contactName: widget.contactName,
        myName: ref.read(authControllerProvider).user?.fullName ?? l.proofExportMe,
        myUserId: widget.myUserId,
        since: _proof.since ?? messages.first.createdAt,
        messages: [for (final m in messages) _patches[m.id] ?? m],
        labels: ProofExportLabels(
          title: l.proofExportTitle,
          between: l.proofExportBetween,
          period: l.proofExportPeriod,
          footer: (page, pages) => l.proofExportFooter('$page', '$pages'),
          attachment: l.proofExportAttachment,
          original: l.proofOriginal,
          edited: l.proofExportEdited,
          deleted: l.proofExportDeleted,
        ),
      );
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
    }
  }

  Future<void> _openProofMenu(bool proofOn, List<DirectMessage> messages) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(proofOn ? _l.proofModeDisable : _l.proofModeEnable),
              subtitle: proofOn ? null : Text(_l.proofModeDirectHint),
              onTap: () => Navigator.pop(sheetContext, 'toggle'),
            ),
            if (proofOn && messages.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(_l.proofExport),
                onTap: () => Navigator.pop(sheetContext, 'export'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'toggle') await _toggleProof(proofOn);
    if (action == 'export') await _exportProof(messages);
  }

  /// L'état affiché : le dernier message système fait foi s'il est plus
  /// récent que ce que le serveur a répondu à l'ouverture — c'est lui qui
  /// arrive en direct quand l'autre active ou coupe le mode.
  bool _proofOn(List<DirectMessage> messages) {
    for (final m in messages.reversed) {
      if ((m.payload?['kind']) == 'proof_mode') {
        final since = _proof.since;
        if (since == null || m.createdAt.isAfter(since)) return m.payload?['enabled'] == true;
        break;
      }
    }
    return _proof.enabled;
  }

  @override
  Widget build(BuildContext context) {
    _rememberKeyboardHeight(context);
    final state = ref.watch(messagingControllerProvider(_key));
    final proofOn = _proofOn(state.messages);
    final product = widget.product ?? _productFromMessages(state.messages);
    final isSeller = product?.sellerId == widget.myUserId;
    _scrollToBottom();

    final contactAvatar = ref
        .watch(contactsProvider)
        .maybeWhen(
          data: (contacts) {
            for (final c in contacts) {
              if (c.contactUserId == widget.contactUserId) return c.avatar;
            }
            return null;
          },
          orElse: () => null,
        );

    // Le ✓ d'identité, lu là où la liste des discussions le lit déjà : le
    // carnet d'adresses, puis les discussions (un inconnu qui écrit n'est
    // pas dans le carnet mais a sa discussion).
    final isContactVerified =
        ref
            .watch(contactsProvider)
            .maybeWhen(
              data: (contacts) {
                for (final c in contacts) {
                  if (c.contactUserId == widget.contactUserId) {
                    return c.isVerified;
                  }
                }
                return false;
              },
              orElse: () => false,
            ) ||
        ref
            .watch(discussionsProvider)
            .maybeWhen(
              data: (discussions) {
                for (final d in discussions) {
                  if (d.kind == 'contact' &&
                      d.contactUserId == widget.contactUserId) {
                    return d.isVerified;
                  }
                }
                return false;
              },
              orElse: () => false,
            );

    // Le correspondant est-il le bot d'une entreprise ? Lu dans les
    // discussions, où le serveur le marque (`is_bot`).
    final isContactBot = ref
        .watch(discussionsProvider)
        .maybeWhen(
          data: (discussions) {
            for (final d in discussions) {
              if (d.kind == 'contact' &&
                  d.contactUserId == widget.contactUserId) {
                return d.isBot;
              }
            }
            return false;
          },
          orElse: () => false,
        );

    // Mode Bouclier — étape 1 : ré-évalue le score de focus de cette
    // conversation à chaque envoi/réception (voir shield_controller.dart).
    ref.listen(messagingControllerProvider(_key), (previous, next) {
      // L'autre vient d'activer ou de couper le mode preuve : on relit qui
      // peut le désactiver.
      if (previous?.messages.length != next.messages.length &&
          next.messages.isNotEmpty &&
          (next.messages.last.payload?['kind']) == 'proof_mode') {
        unawaited(_reloadProof());
      }
      if (previous?.messages.length != next.messages.length) {
        ref
            .read(shieldControllerProvider.notifier)
            .evaluateActiveConversation(_lastMessagesForShield(next.messages));
      }
    });

    final shieldActive = ref.watch(
      shieldControllerProvider.select((s) => s.active),
    );

    return ShieldOverlay(
      child: Scaffold(
        backgroundColor: AppColors.chatBackground,
        body: ChatWallpaper(
          // `top: false` : la barre du haut gère elle-même l'encoche, pour
          // que son blanc monte jusqu'en haut de l'écran. Laissé à SafeArea,
          // le motif du papier peint réapparaissait dans la bande de statut,
          // au-dessus d'une barre pourtant opaque.
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  // Barre opaque, et non plus transparente sur le papier
                  // peint : elle porte le nom du contact, son état de saisie
                  // et les boutons d'appel — de l'information qui doit rester
                  // lisible quel que soit le motif qui défile dessous.
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
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : Navigator.of(context).maybePop(),

                          tooltip: L.of(context).a11yBack,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: _openContactProfile,
                            child: Row(
                              children: [
                                _AvatarRing(
                                  size: 36,
                                  // L'en-tête montre l'anneau et le point
                                  // comme partout ailleurs : c'est le
                                  // dernier endroit où l'on devrait avoir
                                  // à deviner si quelqu'un est joignable.
                                  child: IdentityAvatar(
                                    userId: widget.contactUserId,
                                    avatar: contactAvatar,
                                    displayName: widget.contactName,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              widget.contactName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isContactVerified) ...[
                                            const SizedBox(width: 5),
                                            const VerifiedBadge(size: 15),
                                          ],
                                          if (isContactBot) ...[
                                            const SizedBox(width: 5),
                                            const BotPill(),
                                          ],
                                        ],
                                      ),
                                      // L'état du chiffrement, sous le nom.
                                      // Discret quand tout va bien, mais
                                      // TOUJOURS là : c'est ce qui rend la
                                      // garantie vérifiable par celui qui
                                      // écrit, au lieu d'être une promesse
                                      // faite ailleurs.
                                      EncryptionHeaderLabel(state: _encryption),
                                      // « écrit… » sous le nom, à la place
                                      // qu'occupe le « vu à » dans les autres
                                      // messageries. Il n'apparaît que
                                      // lorsqu'il y a quelque chose à dire :
                                      // une seconde ligne permanente et vide
                                      // décalerait le nom pour rien.
                                      if (ref
                                          .watch(typingProvider)
                                          .isTyping(
                                            'contact',
                                            widget.contactUserId,
                                          ))
                                        Text(
                                          _l.chatsTyping,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.accentPrimary,
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
                          icon: Icons.search,
                          onPressed: _openSearch,

                          tooltip: L.of(context).actionSearch,
                        ),
                        _ChatIconButton(
                          icon: Icons.call_outlined,
                          onPressed: () => _startCall(startWithVideo: false),

                          tooltip: L.of(context).a11yVoiceCall,
                        ),
                        _ChatIconButton(
                          icon: Icons.videocam_outlined,
                          onPressed: () => _startCall(startWithVideo: true),

                          tooltip: L.of(context).a11yVideoCall,
                        ),
                        if (!isContactBot)
                          _ChatIconButton(
                            icon: proofOn ? Icons.gavel : Icons.more_vert,
                            onPressed: () => _openProofMenu(proofOn, state.messages),
                            tooltip: L.of(context).proofModeTitle,
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  // Mode Bouclier "shrine" — pas de couleur, un retrait
                  // spatial : la zone de discussion se resserre vers le
                  // centre (marge noire qui grandit en haut/bas) plutôt que
                  // d'afficher un liseré coloré. Le paradoxe de l'attention :
                  // réduire l'espace visuel augmente le focus perçu.
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.slowMiddle,
                    padding: EdgeInsets.symmetric(
                      vertical: shieldActive ? 28 : 0,
                    ),
                    child: Column(
                      children: [
                        if (product != null) ...[
                          _PinnedProductCard(product: product),
                          if (isSeller)
                            _OrderActions(
                              currentStatus: _orderStatusFrom(state.messages),
                              onAction: _sendOrderUpdate,
                            ),
                        ],
                        // Au-dessus du fil, et non dans un menu : une
                        // alerte de sécurité qu'il faut aller chercher n'est
                        // pas une alerte.
                        if (isContactBot)
                          const BotConversationNotice()
                        else
                          EncryptionBanner(
                            state: _encryption,
                            peerName: widget.contactName,
                            onAcceptIdentity: _acceptIdentity,
                          ),
                        if (proofOn) const ProofModeBanner(),
                        Expanded(
                          child: !state.initialCacheLoaded
                              ? const SizedBox.shrink()
                              : state.messages.isEmpty
                              ? Center(
                                  child: Text(
                                    _l.conversationSayHello(widget.contactName),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: state.messages.length,
                                  itemBuilder: (context, index) {
                                    final messages = state.messages;
                                    final rawMessage = messages[index];
                                    // Superposition des mises à jour temps réel non
                                    // portées par MessagingController — voir
                                    // _onRichContentEvent.
                                    final message =
                                        _patches[rawMessage.id] ?? rawMessage;
                                    final isFirstInGroup =
                                        index == 0 ||
                                        messages[index - 1].senderId !=
                                            message.senderId;
                                    final isLastInGroup =
                                        index == messages.length - 1 ||
                                        messages[index + 1].senderId !=
                                            message.senderId;
                                    // Séparateur de date au changement de
                                    // journée, façon WhatsApp — inséré dans le
                                    // MÊME élément que la bulle plutôt qu'en
                                    // doublant itemCount, pour que les index de
                                    // `messages` restent ceux du fil.
                                    final needsDaySeparator =
                                        index == 0 ||
                                        isDifferentDay(
                                          messages[index - 1].createdAt,
                                          message.createdAt,
                                        );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (index == 0 && state.loadingOlder)
                                          const OlderMessagesLoader(),
                                        if (needsDaySeparator)
                                          DaySeparator(
                                            instant: message.createdAt,
                                          ),
                                        if (_orderOf(message) != null)
                                          _OrderStatusBubble(
                                            label:
                                                _orderOf(message)!['label']
                                                    as String? ??
                                                L.of(context).convOrderUpdated,
                                          )
                                        // Un appel terminé n'est pas une
                                        // bulle : les deux personnes y
                                        // étaient, donc l'aligner à droite
                                        // ou à gauche raconterait « untel
                                        // vous a dit quelque chose » là où
                                        // il s'est passé quelque chose
                                        // ENTRE les deux.
                                        else if ((message.payload?['kind']) ==
                                            'proof_mode')
                                          ProofModeNotice(
                                            text: message.payload?['enabled'] == true
                                                ? _l.proofModeOn(_proofAuthor(message))
                                                : _l.proofModeOff(_proofAuthor(message)),
                                          )
                                        else if (message.deletedAt != null ||
                                            message.originalContent != null)
                                          ProofKeptMessage(
                                            key: _keyFor(message.id),
                                            author: _proofAuthor(message),
                                            content: message.content,
                                            original: message.deletedAt == null
                                                ? message.originalContent
                                                : null,
                                            editedAt: message.editedAt,
                                            isMine: message.senderId == widget.myUserId,
                                          )
                                        else if (message.messageType ==
                                                'CALL' &&
                                            message.payload != null)
                                          CallEventRow(
                                            payload: message.payload!,
                                            isMine:
                                                message.senderId ==
                                                widget.myUserId,
                                            onCallBack: ({required video}) =>
                                                _startCall(
                                                  startWithVideo: video,
                                                ),
                                          )
                                        else
                                          KeyedSubtree(
                                            key: _keyFor(message.id),
                                            child: MessageAppear(
                                              messageId: message.id,
                                              isMine:
                                                  message.senderId ==
                                                  widget.myUserId,
                                              isLast:
                                                  index ==
                                                  messages.length - 1,
                                              child: _Bubble(
                                              message: message,
                                              onBotButton: isContactBot
                                                  ? (title) => _sendBotButton(
                                                      message,
                                                      title,
                                                    )
                                                  : null,
                                              isMine:
                                                  message.senderId ==
                                                  widget.myUserId,
                                              contactName: widget.contactName,
                                              isFirstInGroup: isFirstInGroup,
                                              isLastInGroup: isLastInGroup,
                                              isPending: state.pendingIds
                                                  .contains(message.id),
                                              isFailed: state.failedIds
                                                  .contains(message.id),
                                              onSwipeReply: () =>
                                                  _startReply(message),
                                              onLongPress: () =>
                                                  _showMessageActions(message),
                                              onRetry: () => ref
                                                  .read(
                                                    messagingControllerProvider(
                                                      _key,
                                                    ).notifier,
                                                  )
                                                  .retry(message.id),
                                              onTapReply:
                                                  message.replyToId == null
                                                  ? null
                                                  : () => _scrollToMessage(
                                                      message.replyToId!,
                                                    ),
                                              onReactionPick: (emoji) =>
                                                  _reactTo(message, emoji),
                                              onViewOnceReveal: () =>
                                                  _markViewOnceViewed(message),
                                              onPollVoted: (updated) {
                                                setState(
                                                  () => _patches[message.id] =
                                                      message.copyWith(
                                                        poll: updated,
                                                      ),
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_replyingTo != null)
                                _ReplyingToBar(
                                  message: _replyingTo!,
                                  onClose: () =>
                                      setState(() => _replyingTo = null),
                                ),
                              // Le cadenas n'apparaît QUE pendant un
                              // enregistrement non verrouillé : un cadenas
                              // affiché en permanence n'apprend rien, et le
                              // garder après verrouillage répéterait ce que
                              // la barre dit déjà.
                              if (_composer.mode == ComposerMode.recording ||
                                  _composer.mode == ComposerMode.cancelling)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: 8,
                                      bottom: 8,
                                    ),
                                    child: LockAffordance(
                                      progress: _composer.lockProgress,
                                    ),
                                  ),
                                ),
                              _composerRow(state),
                              // Le panneau emoji, SOUS la barre — à la place
                              // exacte du clavier, dont il reprend la
                              // hauteur. Le mettre ailleurs ferait sauter la
                              // conversation à chaque ouverture.
                              // Les suggestions, SOUS la barre de saisie.
                              // Jamais en même temps que le panneau : il
                              // montre déjà des stickers, et les deux
                              // feraient deux grilles superposées.
                              if (!_emojiOpen)
                                StickerSuggestionBar(
                                  emoji: _trailingEmoji,
                                  onSelected: _sendSticker,
                                ),
                              if (_emojiOpen)
                                ComposerPanel(
                                  controller: _inputController,
                                  height: _keyboardHeight,
                                  onBackspace: _emojiBackspace,
                                  tab: _panelTab,
                                  onTabChanged: (tab) =>
                                      setState(() => _panelTab = tab),
                                  onStickerSelected: _sendSticker,
                                  // Le panneau se referme : le sélecteur de
                                  // fichiers prend l'écran, et le retrouver
                                  // ouvert derrière au retour ferait un
                                  // empilement que personne n'a demandé.
                                  onGifRequested: () {
                                    setState(() => _emojiOpen = false);
                                    _pickAndSendGif();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Corriger un message déjà parti.
  ///
  /// Le champ est pré-rempli avec le texte actuel : on corrige une faute de
  /// frappe, on ne réécrit pas de zéro. Un refus du serveur est AFFICHÉ —
  /// il peut arriver alors que l'écran proposait le geste (horloge du
  /// téléphone décalée, message envoyé il y a juste trois minutes), et
  /// laisser le texte revenir en silence à sa version d'avant est
  /// incompréhensible pour qui vient de taper une correction.
  Future<void> _editMessage(DirectMessage message) async {
    final controller = TextEditingController(text: message.content ?? '');
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.convEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: InputDecoration(hintText: _l.convEditHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_l.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || !mounted) return;
    if (edited.trim() == (message.content ?? '').trim()) return;

    final failure = await ref
        .read(messagingControllerProvider(_key).notifier)
        .editMessage(message.id, edited);
    if (failure != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// Sort un média du stockage privé de Pokou.
  ///
  /// Deux destinations, et il ne faut pas les confondre : photos et vidéos
  /// vont dans la GALERIE, où on les cherchera ; tout le reste passe par la
  /// feuille de partage du système, qui propose « Enregistrer dans
  /// Fichiers » — la galerie refuserait un PDF de toute façon.
  Future<void> _saveMedia(DirectMessage message) async {
    final media = message.media;
    if (media == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final export = MediaExport(repository: ref.read(mediaRepositoryProvider));
    final estVideo = message.messageType == 'VIDEO';
    final versGalerie = estVideo || message.messageType == 'IMAGE';

    final resultat = versGalerie
        ? await export.saveToGallery(
            mediaAssetId: media.id,
            extension: mediaExtension(media),
            isVideo: estVideo,
          )
        : await export.exportFile(
            mediaAssetId: media.id,
            extension: mediaExtension(media),
            suggestedName: media.originalFilename,
          );

    if (!mounted) return;
    // Un message par issue : « refusé », « pas de place » et « échec »
    // appellent trois conduites différentes, et les fondre en un seul « ça
    // n'a pas marché » laisserait sans recours.
    final texte = switch (resultat) {
      MediaExportResult.saved => _l.mediaSaved,
      MediaExportResult.shared => _l.mediaExported,
      MediaExportResult.permissionDenied => _l.mediaSavePermission,
      MediaExportResult.noSpace => _l.mediaSaveNoSpace,
      MediaExportResult.downloadFailed => _l.mediaSaveFailed,
      MediaExportResult.failed => _l.mediaSaveFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _showMessageActions(DirectMessage message) async {
    final controller = ref.read(messagingControllerProvider(_key).notifier);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
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
            const Divider(height: 1),
            // « Répondre » EN PREMIER, et il manquait.
            //
            // Le geste existait — glisser vers la droite — mais il n'était
            // écrit nulle part. Quelqu'un qui ne l'a pas découvert par
            // hasard n'avait aucun moyen de citer un message, y compris le
            // sien. Un geste sans équivalent dans un menu est une
            // fonctionnalité réservée à ceux qui la connaissent déjà.
            //
            // Aucune restriction d'expéditeur : citer son propre message
            // sert à revenir sur ce qu'on a dit, et c'est un usage courant
            // dans une conversation de travail.
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(_l.conversationReply),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            // « Enregistrer sur le téléphone » — seulement pour un média.
            //
            // Un fichier reçu vivait UNIQUEMENT dans le cache de
            // l'application, c'est-à-dire le répertoire temporaire : Android
            // le vide quand l'espace manque, sans prévenir. On pouvait
            // ouvrir et partager une photo reçue ; on ne pouvait pas la
            // garder.
            // Un sticker, lui, se GARDE — dans ses stickers, pas dans la
            // galerie. C'est le geste qu'on attend en touchant celui que
            // quelqu'un vient d'envoyer.
            if (message.messageType == 'STICKER' && message.media != null)
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: Text(_l.stickerSaveToMine),
                onTap: () => Navigator.pop(sheetContext, 'save_sticker'),
              ),
            //
            // SAUF un sticker : il ne se télécharge pas dans la galerie.
            // Il appartient à un pack, pas à la conversation — le proposer
            // reviendrait à remplir les photos de l'utilisateur de
            // vignettes de 50 Ko qu'il n'a jamais demandé à garder.
            if (message.media != null &&
                message.messageType != 'STICKER' &&
                !message.isEncrypted)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(_l.mediaSaveToPhone),
                onTap: () => Navigator.pop(sheetContext, 'save'),
              ),
            // Un message resté chiffré n'a rien à transférer : on ne le lit
            // pas soi-même.
            if (!message.isEncrypted)
              ListTile(
                leading: const Icon(Icons.forward),
                title: Text(_l.conversationForward),
                onTap: () => Navigator.pop(sheetContext, 'forward'),
              ),
            // « Modifier » n'apparaît que tant que c'est possible : proposer
            // un geste que le serveur refusera est pire que ne pas le
            // proposer du tout. La fenêtre est courte par conception — elle
            // couvre la faute de frappe qu'on voit juste après l'envoi, pas
            // la réécriture après coup d'un engagement que l'autre a déjà lu.
            if (controller.canEdit(message))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(_l.conversationEdit),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (message.senderId == widget.myUserId)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(_l.actionDelete),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') {
      _startReply(message);
      return;
    }
    if (action == 'save') {
      await _saveMedia(message);
      return;
    }
    if (action == 'save_sticker') {
      await _saveSticker(message.media!.id);
      return;
    }
    if (action == 'edit') {
      await _editMessage(message);
      return;
    }
    if (action == 'delete') {
      // Mode preuve : l'auteur est prévenu AVANT que le message restera,
      // barré, chez l'autre (maquette 6).
      if (message.proofMode && !PokouMessageStore.isLocalId(message.id)) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_l.deleteForAll),
            content: Text(_l.deleteProofWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_l.actionCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.feedbackDanger),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_l.actionDelete),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
      }
      await ref
          .read(messagingControllerProvider(_key).notifier)
          .deleteMessage(message.id);
      return;
    }
    final contacts = await ref.read(contactsProvider.future);
    if (!mounted) return;
    final target = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final contact in contacts.where(
              (contact) =>
                  contact.isRegistered &&
                  contact.contactUserId != widget.contactUserId,
            ))
              ListTile(
                title: Text(contact.displayName),
                onTap: () => Navigator.pop(sheetContext, contact.contactUserId),
              ),
          ],
        ),
      ),
    );
    if (target != null && mounted) {
      final ok = await ref
          .read(messagingControllerProvider(_key).notifier)
          .forwardMessage(message.id, target);
      // La copie transférée vit dans l'autre conversation : sans ce retour,
      // rien ne bouge à l'écran et le transfert semble avoir échoué.
      if (!mounted) return;
      final name = contacts
          .firstWhere((contact) => contact.contactUserId == target)
          .displayName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? _l.convForwarded(name) : _l.convForwardFailed),
        ),
      );
    }
  }

  /// Retient la hauteur du clavier tant qu'il est visible.
  ///
  /// Appelé depuis `build` : c'est le seul endroit où `MediaQuery` donne
  /// l'encart du bas, et il ne vaut que pendant que le clavier est ouvert.
  void _rememberKeyboardHeight(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 120 && inset != _keyboardHeight) {
      _keyboardHeight = inset;
    }
  }

  Widget _composerRow(MessagingState state) {
    final busy = state.sending || state.uploading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // SEULE la pilule change pendant l'enregistrement. Le bouton de
        // droite reste monté, et c'est indispensable : c'est lui qui porte
        // le `GestureDetector` de l'appui long. En remplaçant toute la
        // rangée, on le démontait en plein geste — plus aucun mouvement ne
        // lui parvenait, donc ni annulation par glissement ni
        // verrouillage, et la corbeille restait éteinte faute de pouvoir
        // verrouiller.
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
            // Trombone, emoji, champ, appareil photo — la même pilule qu'en
            // groupe, voir composer_input.dart.
            child: ComposerInputPill(
              controller: _inputController,
              focusNode: _inputFocus,
              // « Message chiffré… » seulement si la conversation l'est
              // vraiment : l'écrire sur une conversation en clair serait un
              // mensonge.
              hintText: _encryption == ConversationEncryption.encrypted
                  ? _l.convEncryptedHint
                  : _l.conversationMessageHint,
              emojiOpen: _emojiOpen,
              enabled: !busy,
              highlighted: _slashMode,
              glow: _slashMode,
              // Toucher le champ referme le panneau : on ne peut pas taper
              // derrière un panneau qui couvre le clavier.
              onFieldTap: () {
                if (_emojiOpen) _closePanelForKeyboard();
              },
              onSubmitted: (_) => _send(),
              onAttach: _showAttachmentSheet,
              onToggleEmoji: _toggleEmoji,
              onCamera: () => _pickImage(ImageSource.camera),
              attachTooltip: L.of(context).a11yAttach,
              emojiTooltip: _l.composerEmoji,
              cameraTooltip: _l.convAttachCamera,
            ),
          ),
        const SizedBox(width: 10),
        // Un seul bouton à droite, dont la fonction dépend du contenu —
        // et qui porte les trois gestes de l'enregistrement (maintenir,
        // glisser à gauche pour annuler, glisser en haut pour verrouiller).
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

class _PinnedProductCard extends ConsumerWidget {
  const _PinnedProductCard({required this.product});

  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = product.image;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 54,
              height: 54,
              child: image == null
                  ? ColoredBox(
                      color: AppColors.accentPrimaryLight,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                      ),
                    )
                  : MediaImage.meta(
                      image,
                      decodeWidth: 56,
                      placeholder: ColoredBox(color: AppColors.surfaceElevated),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).orderProductDiscussed,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${product.price} ${product.currency}',
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.push_pin_outlined, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Les actions du vendeur sur une commande en cours.
///
/// Deux corrections, et la seconde n'était pas cosmétique :
///
/// - **une seule étape à la fois.** Les trois boutons s'affichaient
///   toujours, quel que soit l'avancement : on pouvait « valider » une
///   commande déjà livrée, ou l'expédier deux fois. Une commande suit un
///   ordre, et proposer les trois revient à demander au vendeur de se
///   souvenir lui-même de où il en est — alors que la conversation le dit.
/// - **un fond opaque.** La barre n'avait aucun conteneur : les boutons
///   flottaient directement sur le papier peint griffonné de la
///   conversation, contours pâles sur motif chargé. C'est exactement la
///   panne qu'avait la barre d'enregistrement vocal, et pour la même
///   raison : un élément d'interface posé sans surface.
class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.currentStatus, required this.onAction});

  /// `null` tant qu'aucune étape n'a été franchie.
  final String? currentStatus;
  final Future<void> Function(String status) onAction;

  /// L'étape qui SUIT celle où l'on est. `null` quand c'est terminé.
  static ({String status, String label, IconData icon})? _next(
    L l,
    String? current,
  ) {
    switch (current) {
      case null:
        return (
          status: 'VALIDATED',
          label: l.orderValidate,
          icon: Icons.check_circle_outline,
        );
      case 'VALIDATED':
        return (
          status: 'SHIPPED',
          label: l.orderMarkShipped,
          icon: Icons.local_shipping_outlined,
        );
      case 'SHIPPED':
        return (
          status: 'DELIVERED',
          label: l.orderMarkDelivered,
          icon: Icons.flag_outlined,
        );
      default:
        // Livrée — ou un état inconnu venu d'une version plus récente. Dans
        // les deux cas, il n'y a rien à proposer.
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _next(L.of(context), currentStatus);
    if (step == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              currentStatus == null
                  ? L.of(context).orderBuyerWaiting
                  : L.of(context).orderNextStep,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => onAction(step.status),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimaryDark,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: Icon(step.icon, size: 16),
            label: Text(step.label),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusBubble extends StatelessWidget {
  const _OrderStatusBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_alt, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône minimaliste de l'en-tête et de la barre de saisie.
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
        splashColor: AppColors.chatActionGreen.withValues(alpha: 0.3),
        highlightColor: AppColors.chatActionGreen.withValues(alpha: 0.15),
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

/// Anneau monochrome autour de l'avatar, marqueur visuel de la clé vérifiée.
class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.child, required this.size});

  final Widget child;
  final double size;

  static const _ringWidth = 2.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + (_ringWidth + _gap) * 2,
      height: size + (_ringWidth + _gap) * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Anneau plein, pas dégradé : c'est l'anneau de statut, un signal
        // d'état binaire (vu / non vu), et un signal ne se nuance pas.
        color: AppColors.chatAvatarRingStart,
      ),
      child: Center(
        child: Container(
          width: size + _gap * 2,
          height: size + _gap * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Bouton "A" (Baba) — ouvre l'assistant général épinglé (monitorId 0)
class _ReplyingToBar extends StatelessWidget {
  const _ReplyingToBar({required this.message, required this.onClose});

  final DirectMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: AppColors.chatActionGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content?.trim().isNotEmpty == true
                  ? message.content!
                  : switch (message.messageType) {
                      'IMAGE' => L.of(context).mediaPhoto,
                      'VIDEO' => L.of(context).mediaVideo,
                      'AUDIO' => L.of(context).mediaVoiceNote,
                      'DOCUMENT' => L.of(context).convAttachDocument,
                      'STICKER' => L.of(context).stickerLabel,
                      _ => L.of(context).mediaMessage,
                    },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,

            tooltip: L.of(context).actionClose,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.contactName,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onLongPress,
    required this.onRetry,
    required this.onReactionPick,
    required this.onViewOnceReveal,
    required this.onPollVoted,
    required this.onSwipeReply,
    this.onTapReply,
    this.onBotButton,
    this.isPending = false,
    this.isFailed = false,
  });

  final DirectMessage message;
  final bool isMine;

  /// Nom affiché du contact — sert à étiqueter l'auteur d'un message cité
  /// (« Vous » vs le contact) dans le bandeau de réponse.
  final String contactName;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onLongPress;

  /// Écrit sur cet appareil, pas encore accepté par le serveur — part tout
  /// seul au retour du réseau (voir core/sync/outbox_service.dart).
  final bool isPending;

  /// Refusé par le serveur : n'attend plus rien, il faut le renvoyer.
  final bool isFailed;

  /// Renvoi manuel d'un message en échec.
  final VoidCallback onRetry;

  /// Tap sur une pastille de réaction déjà posée — bascule cette réaction
  /// pour moi (même geste que la barre rapide de l'appui long).
  final void Function(String emoji) onReactionPick;

  /// Défilement best-effort vers le message cité — `null` s'il n'y a pas de
  /// citation (le bandeau ne s'affiche alors pas non plus).
  final VoidCallback? onTapReply;

  /// Vue unique révélée par SON DESTINATAIRE — appelle
  /// `POST /messages/{id}/viewed` côté écran, sans savoir comment.
  final VoidCallback onViewOnceReveal;

  /// Sondage voté/changé — remonté à l'écran pour fusionner le sondage à
  /// jour dans le message affiché.
  final void Function(PollData updated) onPollVoted;
  final VoidCallback onSwipeReply;

  /// Bouton d'un message de bot touché — null hors conversation de bot.
  final void Function(String title)? onBotButton;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  // L'heure est visible en permanence sous chaque bulle, comme dans
  // WhatsApp : demandé explicitement, et c'est ce qui permet de situer un
  // message sans geste quand un séparateur de date est loin au-dessus.
  static const _showTimestamp = true;

  DirectMessage get message => widget.message;
  bool get isMine => widget.isMine;

  /// Identifiant de "moi" déduit du sens de CE message : `_Bubble` ne connaît
  /// pas myUserId directement, mais isMine dit déjà de quel côté on est.
  int get _myUserId => isMine ? message.senderId : message.recipientId;

  IconData? get _statusIcon {
    if (!isMine) return null;
    if (widget.isFailed) return Icons.error_outline;
    if (widget.isPending) return Icons.schedule;
    switch (message.status) {
      case DirectMessageStatus.read:
        return Icons.done_all;
      case DirectMessageStatus.delivered:
        return Icons.done_all;
      case DirectMessageStatus.sent:
        return Icons.done;
    }
  }

  /// L'horodatage et les coches ne se révèlent qu'au tap, mais « en attente »
  /// et « échec » doivent se voir SANS geste : ce sont les deux seuls états
  /// où l'expéditeur doit savoir que son message n'est pas parti.
  Widget? _persistentStateBadge() {
    if (!isMine || (!widget.isPending && !widget.isFailed)) return null;
    final failed = widget.isFailed;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
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

  // Photos/vidéos sans légende s'affichent à nu (pas de bulle colorée
  // derrière) — seuls les messages texte, notes vocales, documents, et
  // médias AVEC légende gardent le traitement "bulle".
  /// 128 points : assez grand pour se lire d'un coup d'œil dans le fil,
  /// assez petit pour qu'une rafale de stickers ne pousse pas le reste de
  /// la conversation hors de l'écran. C'est la taille retenue par toutes
  /// les messageries, et un sticker plus gros qu'une photo paraîtrait
  /// disproportionné.
  static const double _stickerSize = 128;

  bool get _isFlushMedia {
    final media = message.media;
    if (media == null) return false;
    if (message.messageType != 'IMAGE' && message.messageType != 'VIDEO')
      return false;
    return message.content == null || message.content!.trim().isEmpty;
  }

  /// Un sticker : ni bulle, ni cadre, ni fond.
  ///
  /// C'est ce qui le distingue d'une image, et ce n'est pas cosmétique —
  /// un sticker est découpé, sa transparence FAIT PARTIE du dessin.
  /// L'enfermer dans le cadre des médias (`_isFlushMedia` plus bas) le
  /// poserait sur un rectangle de couleur aux coins arrondis, et le
  /// découpage n'aurait servi à rien.
  bool get _isSticker =>
      message.messageType == 'STICKER' && message.media != null;

  Widget _mediaWidget(MediaMeta media) {
    final base = switch (message.messageType) {
      'STICKER' => StickerImage(mediaId: media.id, size: _stickerSize),
      'AUDIO' => AudioMessageBubble(media: media, isMine: isMine),
      'IMAGE' => ImageMessageBubble(media: media),
      'VIDEO' => VideoMessageBubble(media: media),
      _ => DocumentMessageBubble(media: media, isMine: isMine),
    };
    final isViewOnceCapable =
        message.viewOnce &&
        (message.messageType == 'IMAGE' || message.messageType == 'VIDEO');
    if (!isViewOnceCapable) return base;
    return ViewOnceGate(
      viewed: message.isViewed,
      isMine: isMine,
      onReveal: widget.onViewOnceReveal,
      builder: (_) => base,
    );
  }

  /// POLL/LOCATION/CONTACT n'ont pas de pièce jointe — leur rendu vient de
  /// `payload`/`poll`, pas de `message.media`. `null` si le type ne concerne
  /// pas cette bulle (texte ordinaire ou média classique), auquel cas
  /// `_content()` continue sur son chemin habituel.
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
    final textStyle = TextStyle(
      color: AppColors.chatTextReceived,
      height: 1.5, // air entre les lignes — aide la lecture sur fond noir
    );

    final richContent = _richContentWidget(L.of(context), textStyle);
    if (richContent != null) return richContent;

    // Pièce jointe pas encore partie : l'aperçu vient du fichier LOCAL, et
    // la bulle dit où en est l'envoi. Elle existe AVANT tout réseau — c'est
    // ce qui empêche de croire son geste perdu, et donc de le refaire.
    if (message.pendingMedia != null) {
      return PendingMediaBubble(message: message, onRetry: widget.onRetry);
    }

    final media = message.media;
    if (media == null) {
      // Un numéro plausible dans un message ordinaire est tappable comme sur
      // la carte de visite — même geste, même fonction (voir
      // contact_card_bubble.dart::handlePhoneTap).
      final content = message.content ?? '';
      final firstUrl = extractFirstUrl(content);
      if (firstUrl == null)
        return LinkifiedText(text: content, style: textStyle);
      // Aperçu seulement pour un message TEXTE pur : avec une pièce jointe,
      // c'est déjà elle le contenu visuel, une deuxième carte en dessous
      // ferait doublon.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinkifiedText(text: content, style: textStyle),
          LinkPreviewCard(url: firstUrl),
        ],
      );
    }

    // Pièce jointe restée chiffrée (sa clé n'a pas pu être ouverte) : le
    // fichier n'est qu'un bloc opaque. Le dire, plutôt que d'afficher une
    // image cassée ou un document « pokou.bin ».
    if (message.isEncrypted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              L.of(context).mediaUndecryptable,
              style: textStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
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
        LinkifiedText(text: message.content!, style: textStyle),
      ],
    );
  }

  Widget _timestampRow() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
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
                      fontSize: 11,
                    ),
                  ),
                  if (message.isEdited)
                    EditedLabel(color: AppColors.chatTimestamp),
                  if (_statusIcon != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _statusIcon,
                      size: 14,
                      // BLEU pour « lu », gris pour « envoyé » et « remis ».
                      // C'est le signal le plus universellement compris d'une
                      // messagerie : la double coche qui passe au bleu dit
                      // que la personne a ouvert le message. Cette couleur ne
                      // sert QUE à ça dans toute l'application.
                      color: message.status == DirectMessageStatus.read
                          ? AppColors.readReceiptBlue
                          : AppColors.deliveredGray,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// Bandeau de réponse citée, au-dessus du texte — `null` si ce message n'en
  /// cite pas un autre. Le nom affiché distingue "Vous" du nom du contact :
  /// messages.py ne renvoie pas `sender_name` pour un aperçu 1:1 (contrairement
  /// à groups.py), ce widget le déduit donc lui-même.
  Widget? _replyBanner() {
    final preview = message.replyTo;
    if (preview == null) return null;
    return ReplyPreviewBanner(
      preview: preview,
      senderLabel: preview.senderId == _myUserId
          ? L.of(context).callYou
          : widget.contactName,
      isMine: isMine,
      onTap: widget.onTapReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8;
    // Groupement façon iMessage : un bloc de messages consécutifs du même
    // expéditeur se lit comme une seule pensée plutôt que des bulles
    // séparées — libère l'espace vertical, surtout utile pour les rafales
    // de messages courts typiques d'un échange business.
    final marginTop = widget.isFirstInGroup ? 16.0 : 8.0;

    if (_isSticker) {
      return GestureDetector(
        onLongPress: widget.onLongPress,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) widget.onSwipeReply();
        },
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(top: marginTop),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Rien autour : pas de Container, pas de décoration, pas de
                // ClipRRect. Toute enveloppe reviendrait à remettre le
                // cadre qu'on vient d'enlever.
                StickerImage(mediaId: message.media!.id, size: _stickerSize),
                _timestampRow(),
                ?_persistentStateBadge(),
              ],
            ),
          ),
        ),
      );
    }

    if (_isFlushMedia) {
      return GestureDetector(
        // L'appui long ouvre les actions (répondre, transférer, supprimer).
        // Plus rien sur le tap simple depuis que l'heure est permanente.
        onLongPress: widget.onLongPress,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) widget.onSwipeReply();
        },
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(top: marginTop),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
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
                ),
                _timestampRow(),
                ?_persistentStateBadge(),
              ],
            ),
          ),
        ),
      );
    }

    // Coins arrondis partout, SAUF le coin qui pointe vers l'émetteur sur la
    // PREMIÈRE bulle d'un groupe de messages consécutifs — c'est la "tail" de
    // WhatsApp réduite à un simple aplatissement de coin (pas de forme
    // triangulaire dessinée à part). Les bulles suivantes du même bloc n'ont
    // plus besoin de tail : le groupement serré (marginTop) suffit à dire
    // qu'elles viennent de la même personne.
    // 12 points partout, 0 sur le coin de la tail : c'est l'asymétrie qui
    // fait la forme, pas la courbure. Un coin franc pointe vers l'émetteur
    // et remplace la petite queue triangulaire.
    const fullRadius = Radius.circular(12);
    // 2 points, et non zéro : un coin franc coupait la bulle net. Le
    // système demande un arrondi RÉDUIT — assez pour que le coin pointe
    // vers son émetteur, assez peu pour ne pas se confondre avec les trois
    // autres.
    const tailRadius = Radius.circular(2);
    // Le coin réduit est EN HAUT, du côté de l'émetteur.
    //
    // Il était en bas. Le code de la maquette le met en haut
    // (`rounded-tl-none` / `rounded-tr-none`), et c'est aussi la convention
    // de toutes les messageries : la « queue » part de l'épaule du message,
    // là où l'avatar se trouve, pas de son pied.
    //
    // À noter : le DESIGN.md du même dossier dit l'inverse (« reduced
    // bottom-right radius »). Les deux se contredisent ; l'écran fait foi.
    final radius = widget.isFirstInGroup
        ? BorderRadius.only(
            topLeft: isMine ? fullRadius : tailRadius,
            topRight: isMine ? tailRadius : fullRadius,
            bottomLeft: fullRadius,
            bottomRight: fullRadius,
          )
        : const BorderRadius.all(fullRadius);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 300) widget.onSwipeReply();
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(top: marginTop),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                constraints: BoxConstraints(maxWidth: maxWidth),
                decoration: BoxDecoration(
                  // Aplat : ce système est plat, sans dégradé sur le chrome.
                  color: isMine
                      ? AppColors.chatBubbleSent
                      : AppColors.chatBubbleReceived,
                  borderRadius: radius,
                  // Une BORDURE, et plus une ombre.
                  //
                  // L'ombre décollait la bulle du papier peint crème. Ce
                  // papier peint a disparu : le canevas est presque blanc,
                  // et une bulle blanche sans contour y flotterait sans
                  // limite. C'est désormais le trait d'un point qui la
                  // délimite — et le système supprime de toute façon les
                  // ombres diffuses, pour tenir la fréquence d'images sur
                  // les appareils d'entrée de gamme.
                  border: Border.all(
                    color: isMine
                        ? AppColors.chatBubbleSentBorder
                        : AppColors.chatBubbleReceivedBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [?_replyBanner(), _content()],
                ),
              ),
              if (!isMine &&
                  widget.onBotButton != null &&
                  BotButtonsRow.titlesOf(message.payload).isNotEmpty)
                BotButtonsRow(
                  titles: BotButtonsRow.titlesOf(message.payload),
                  onPressed: widget.onBotButton!,
                ),
              // Pastille de réaction superposée au coin inférieur de la
              // bulle — translation picturale plutôt qu'un Stack/Positioned :
              // simple à garder correct dans une ListView qui virtualise ses
              // éléments, et le résultat visuel reste un léger chevauchement.
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
