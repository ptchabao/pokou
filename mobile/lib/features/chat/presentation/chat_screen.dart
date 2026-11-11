import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mahizu/mahizu_connect_panel.dart';
import '../../../core/mahizu/mahizu_session.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_message_model.dart';
import 'ai_style.dart';
import 'chat_controller.dart';
import 'voice_mode_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

class _Suggestion {
  const _Suggestion(this.label, this.subtitle, this.prompt);

  final String label;
  final String subtitle;
  final String prompt;
}

List<_Suggestion> _monitorSuggestions(L l) => [
  _Suggestion(
    l.aiSuggestSummary,
    l.aiSuggestSummarySub,
    l.aiSuggestSummaryPrompt,
  ),
  _Suggestion(l.aiSuggestTrend, l.aiSuggestTrendSub, l.aiSuggestTrendPrompt),
  _Suggestion(l.aiSuggestAlerts, l.aiSuggestAlertsSub, l.aiSuggestAlertsPrompt),
];

// Chat général (monitorId == 0, aucune source de données connectée) — les
// suggestions ci-dessus n'ont pas de sens sans données à interroger.
List<_Suggestion> _generalSuggestions(L l) => [
  _Suggestion(l.aiSuggestAdvice, l.aiSuggestAdviceSub, l.aiSuggestAdvicePrompt),
  _Suggestion(l.aiSuggestWrite, l.aiSuggestWriteSub, l.aiSuggestWritePrompt),
  _Suggestion(
    l.aiSuggestQuestion,
    l.aiSuggestQuestionSub,
    l.aiSuggestQuestionPrompt,
  ),
];

/// L'assistant : un accueil, une conversation, et un mode écoute.
///
/// ── La direction ───────────────────────────────────────────────────────
///
/// Moins d'éléments, mais chacun très lisible et très tactile : fond gris
/// très clair, surfaces blanches, un seul accent vert (voir [AiStyle]),
/// des rayons larges, beaucoup d'espace. La réponse de l'assistant domine
/// la conversation — c'est elle qu'on vient lire.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.monitorId,
    required this.contactName,
    this.showBack = true,
  });

  final int monitorId;
  final String contactName;

  /// Afficher la flèche de retour.
  ///
  /// `false` quand cet écran est un ONGLET et non une page empilée : il n'y
  /// a alors rien à quitter, et la flèche ne mènerait nulle part.
  final bool showBack;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _send([String? text]) async {
    final message = text ?? _inputController.text;
    if (message.trim().isEmpty) return;
    if (text == null) _inputController.clear();
    await ref
        .read(chatControllerProvider(widget.monitorId).notifier)
        .send(message);
    _scrollToBottom();
  }

  Future<void> _speak() async {
    final said = await VoiceModeScreen.open(context);
    if (said != null && said.trim().isNotEmpty) await _send(said);
  }

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    // L'assistant est un service Mahizu : tant qu'aucun compte n'est
    // rattaché, l'écran propose de le faire au lieu d'échouer à chaque envoi.
    // Baba (kNoMonitor) répond via l'API Pokou ; seuls les moniteurs
    // Mahizu demandent encore un compte Mahizu.
    if (widget.monitorId != kNoMonitor &&
        !ref.watch(mahizuSessionProvider).isConnected) {
      return Scaffold(
        backgroundColor: style.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(showBack: widget.showBack, onNewChat: null),
              const Expanded(child: MahizuConnectPanel()),
            ],
          ),
        ),
      );
    }

    final state = ref.watch(chatControllerProvider(widget.monitorId));
    _scrollToBottom();

    return Scaffold(
      backgroundColor: style.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              showBack: widget.showBack,
              onNewChat: state.messages.isEmpty
                  ? null
                  : () => ref
                        .read(chatControllerProvider(widget.monitorId).notifier)
                        .clearHistory(),
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _Welcome(
                      monitorName: widget.contactName,
                      isGeneral: widget.monitorId == 0,
                      onSuggestionTap: _send,
                    )
                  : _MessageList(
                      scrollController: _scrollController,
                      messages: state.messages,
                      thinking: state.sending,
                      onRegenerate: () => ref
                          .read(
                            chatControllerProvider(widget.monitorId).notifier,
                          )
                          .regenerate(),
                    ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AiStyle.screenPadding,
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                    color: Color(0xFFD93025),
                    fontSize: 12,
                  ),
                ),
              ),
            _Composer(
              controller: _inputController,
              sending: state.sending,
              onSend: () => _send(),
              onSpeak: _speak,
            ),
          ],
        ),
      ),
    );
  }
}

/// L'en-tête : qui parle (soi), un mot d'accueil, et « Nouvelle
/// discussion » en pilule verte quand il y a quelque chose à effacer.
class _Header extends ConsumerWidget {
  const _Header({required this.showBack, required this.onNewChat});

  final bool showBack;
  final VoidCallback? onNewChat;

  String _greeting(L l) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l.aiGreetMorning;
    if (hour < 18) return l.aiGreetAfternoon;
    return l.aiGreetEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AiStyle.of(context);
    final l = L.of(context);
    final me = ref.watch(authControllerProvider).user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AiStyle.screenPadding - 8,
        10,
        AiStyle.screenPadding,
        6,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, color: style.text),
              tooltip: l.a11yBack,
            )
          else
            const SizedBox(width: 8),
          ContactAvatar(
            avatar: me?.avatar,
            displayName: me?.displayName ?? '',
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  me?.displayName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
                Text(
                  _greeting(l),
                  style: TextStyle(fontSize: 13, color: style.textSecondary),
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: onNewChat == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: AiStyle.accent,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onNewChat,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AiStyle.onAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.aiNewChat,
                        style: const TextStyle(
                          color: AiStyle.onAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'accueil : l'assistant au centre, et trois actions rapides.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.monitorName,
    required this.isGeneral,
    required this.onSuggestionTap,
  });

  /// Le moniteur dont Baba lit les données — vide en conversation libre.
  final String monitorName;
  final bool isGeneral;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    final l = L.of(context);
    final suggestions = isGeneral
        ? _generalSuggestions(l)
        : _monitorSuggestions(l);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AiStyle.screenPadding,
        28,
        AiStyle.screenPadding,
        16,
      ),
      child: Column(
        children: [
          const AssistantOrb(size: 116),
          const SizedBox(height: 24),
          // Toujours BABA, avec son badge : c'est lui qui parle, quel que
          // soit le moniteur ouvert. Le nom du moniteur arrivait ici à sa
          // place — « Bonjour, je suis Changement global ».
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.aiHelloIm(l.navBaba)),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: VerifiedBadge(size: 24),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: style.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGeneral ? l.aiPartner : l.aiAskAboutData,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: style.textSecondary),
          ),
          // Le moniteur interrogé, à part : ce sont SES données que Baba lit.
          if (!isGeneral && monitorName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: style.surface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: style.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 16,
                    color: AiStyle.accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      monitorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: style.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          for (final s in suggestions) ...[
            _SuggestionCard(
              suggestion: s,
              onTap: () => onSuggestionTap(s.prompt),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Une action suggérée : un titre, une ligne d'explication, une flèche
/// dans un rond — une action, pas un bouton de formulaire.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: style.softShadow,
      ),
      child: Material(
        color: style.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: style.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        suggestion.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: style.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.background,
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 19,
                    color: style.text,
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

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.thinking,
    required this.onRegenerate,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool thinking;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final lastAssistantIndex = messages.lastIndexWhere(
      (m) => m.role == ChatRole.assistant,
    );

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AiStyle.screenPadding - 4,
        8,
        AiStyle.screenPadding - 4,
        12,
      ),
      itemCount: messages.length + (thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const _ThinkingIndicator();
        final message = messages[index];
        return message.role == ChatRole.user
            ? _UserBubble(message: message)
            : _AssistantReply(
                message: message,
                onRegenerate: !thinking && index == lastAssistantIndex
                    ? onRegenerate
                    : null,
              );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: style.userBubble,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(22),
            topEnd: Radius.circular(22),
            bottomStart: Radius.circular(22),
            bottomEnd: Radius.circular(6),
          ).resolve(Directionality.of(context)),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(color: style.text, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

/// La réponse de l'assistant : une surface blanche, large, aérée — c'est
/// elle qu'on vient lire. Les blocs de code y sont posés dans un cadre
/// sombre avec leur bouton « Copier ».
class _AssistantReply extends StatelessWidget {
  const _AssistantReply({required this.message, this.onRegenerate});

  final ChatMessage message;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: style.surface,
              borderRadius: BorderRadius.circular(AiStyle.radiusLarge),
              boxShadow: style.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final part in splitCodeBlocks(message.content))
                  part.isCode
                      ? _CodeBlock(code: part.text)
                      : SelectableText(
                          part.text,
                          style: TextStyle(
                            color: style.text,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Row(
              children: [
                _ActionIcon(
                  icon: Icons.copy_rounded,
                  tooltip: l.aiCopy,
                  onPressed: () => _copy(context, message.content),
                ),
                if (onRegenerate != null)
                  _ActionIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: l.a11yRefresh,
                    onPressed: onRegenerate!,
                  ),
                const SizedBox(width: 6),
                Text(
                  l.aiGenerated,
                  style: TextStyle(fontSize: 11, color: style.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(L.of(context).aiCopied),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: AiStyle.of(context).textSecondary,
      icon: Icon(icon),
    );
  }
}

/// Un morceau de réponse : du texte, ou un bloc de code.
typedef ReplyPart = ({String text, bool isCode});

/// Découpe une réponse sur ses blocs de code (entre ```). La langue
/// annoncée après les accents (```dart) est retirée : elle n'apprend rien
/// à qui lit.
List<ReplyPart> splitCodeBlocks(String content) {
  final parts = <ReplyPart>[];
  final fence = RegExp(r'```[^\n`]*\n?([\s\S]*?)```');
  var last = 0;
  for (final match in fence.allMatches(content)) {
    final before = content.substring(last, match.start).trim();
    if (before.isNotEmpty) parts.add((text: before, isCode: false));
    final code = match.group(1)!.trimRight();
    if (code.isNotEmpty) parts.add((text: code, isCode: true));
    last = match.end;
  }
  final rest = content.substring(last).trim();
  if (rest.isNotEmpty || parts.isEmpty) parts.add((text: rest, isCode: false));
  return parts;
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: style.codeBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: style.codeText,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _copy(context, code),
              style: TextButton.styleFrom(
                foregroundColor: AiStyle.accentOnDark,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text(L.of(context).aiCopy),
            ),
          ),
        ],
      ),
    );
  }
}

// L'Orb en lui-même communique "je réfléchis" (assombri, pulsation rapide,
// voir assistant_orb.dart) — pas de "…" ni de spinner texte à côté. Le
// Semantics garde l'information pour les lecteurs d'écran.
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Semantics(
            label: L.of(context).aiThinking,
            child: const AssistantOrb(size: 30, thinking: true),
          ),
        ],
      ),
    );
  }
}

/// La barre de saisie, flottante : une pilule blanche, et à droite un seul
/// bouton rond — le micro tant qu'on n'a rien écrit (le mode écoute),
/// l'envoi dès qu'il y a du texte.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onSpeak,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AiStyle.screenPadding - 6,
        6,
        AiStyle.screenPadding - 6,
        14,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: style.softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: TextStyle(color: style.text, fontSize: 15),
                  cursorColor: style.text,
                  decoration: InputDecoration(
                    hintText: l.aiMessageHint,
                    hintStyle: TextStyle(color: style.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final (icon, tooltip, action) = sending
                    ? (null, l.aiThinking, null)
                    : hasText
                    ? (Icons.arrow_upward_rounded, l.aiVoiceSend, onSend)
                    : (Icons.mic_rounded, l.aiVoiceSpeak, onSpeak);
                return Tooltip(
                  message: tooltip,
                  child: GestureDetector(
                    onTap: action,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Le vert pour envoyer ; un rond neutre pour parler,
                        // qui ne promet pas d'envoi.
                        color: hasText || sending
                            ? AiStyle.accent
                            : style.background,
                      ),
                      child: icon == null
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AiStyle.onAccent,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                icon,
                                key: ValueKey(icon),
                                color: hasText ? AiStyle.onAccent : style.text,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
