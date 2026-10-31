import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import 'conversation_screen.dart';
import 'messaging_controller.dart' show messagingRepositoryProvider;

/// Motif reconnaissant un numéro plausible dans du texte libre : un `+`
/// optionnel, un chiffre, puis une suite de chiffres/espaces/tirets/points/
/// parenthèses. Le filtre sur le nombre de chiffres (voir [findPhoneMatches])
/// écarte ensuite les fausses correspondances (dates, codes courts).
final RegExp _phonePattern = RegExp(r'(\+?\d[\d\s().-]{5,}\d)');
final RegExp _urlPattern = RegExp(
  r'(https?://[^\s]+|www\.[^\s]+)',
  caseSensitive: false,
);

/// Mise en forme façon WhatsApp — `*gras*`, `_italique_`, `~barré~`. Un seul
/// niveau (pas de gras-dans-l'italique) : WhatsApp lui-même ne va pas plus
/// loin dans un champ texte brut, et le combiner ajouterait un vrai
/// analyseur récursif pour un besoin marginal. Le délimiteur doit coller à
/// son contenu (`* texte*` ne compte pas) — sinon une simple astérisque de
/// ponctuation ("2 * 3") se transformerait en mise en forme.
final RegExp _markdownPattern = RegExp(
  r'\*(\S(?:[^\n*]*\S)?)\*|_(\S(?:[^\n_]*\S)?)_|~(\S(?:[^\n~]*\S)?)~',
);

/// Premier lien plausible dans `text`, normalisé en URL complète (un lien en
/// `www.` sans schéma devient `https://…`) — sert à choisir QUEL lien
/// prévisualiser dans LinkPreviewCard quand un message en contient un.
/// Volontairement le PREMIER seulement : prévisualiser chaque lien d'un
/// message qui en cite plusieurs ferait une pile de cartes, jamais ce que
/// WhatsApp/Telegram/iMessage font.
String? extractFirstUrl(String text) {
  final match = _urlPattern.firstMatch(text);
  if (match == null) return null;
  final raw = match.group(0)!;
  return raw.startsWith('www.') ? 'https://$raw' : raw;
}

/// Correspondances plausibles pour un numéro de téléphone dans `text` — un
/// même motif sert à la fois au texte libre d'un message ordinaire et à la
/// carte de visite, d'où le partage ici plutôt qu'une regex par appelant.
Iterable<RegExpMatch> findPhoneMatches(String text) {
  return _phonePattern.allMatches(text).where((match) {
    final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
    // Sous 7 chiffres : trop court pour un numéro (année, code postal…).
    // Au-delà de 15 : la borne E.164 elle-même, donc sûrement autre chose.
    return digits.length >= 7 && digits.length <= 15;
  });
}

/// Texte avec ses numéros de téléphone rendus tappables — utilisé pour le
/// contenu libre d'un message ordinaire. Widget à état (et non une simple
/// fonction) parce que les `TapGestureRecognizer` doivent être explicitement
/// libérés ; les recréer à chaque `build` sans les disposer fuirait.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
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

  /// Numéros/liens tappables dans une portion de texte SANS mise en forme —
  /// exactement l'ancienne logique de ce widget, extraite pour s'appliquer
  /// aussi bien au texte hors mise en forme qu'à l'intérieur d'un `*gras*`.
  List<InlineSpan> _linkify(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final matches = <({int start, int end, String value, bool isUrl})>[];
    for (final match in _urlPattern.allMatches(text)) {
      matches.add((
        start: match.start,
        end: match.end,
        value: match.group(0)!,
        isUrl: true,
      ));
    }
    for (final match in findPhoneMatches(text)) {
      if (!matches.any(
        (item) => item.start < match.end && match.start < item.end,
      )) {
        matches.add((
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          isUrl: false,
        ));
      }
    }
    matches.sort((left, right) => left.start.compareTo(right.start));
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        // `style:` explicite et non hérité de l'ambiant : cette fonction
        // reçoit aussi un style de mise en forme (*gras*/_italique_/~barré~)
        // DIFFÉRENT du style de base du message — un enfant TextSpan sans
        // style hériterait du PARENT du widget, pas de CE style-ci.
        spans.add(
          TextSpan(text: text.substring(lastEnd, match.start), style: style),
        );
      }
      final raw = match.value;
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          if (match.isUrl) {
            final url = raw.startsWith('www.') ? 'https://$raw' : raw;
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } else {
            await handlePhoneTap(context, raw);
          }
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: raw,
          style: style.copyWith(
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w700,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length)
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    return spans;
  }

  /// Découpe `text` en runs mis en forme (`*gras*`/`_italique_`/`~barré~`) et
  /// runs ordinaires, en linkifiant chacun — la mise en forme et les liens
  /// coexistent (un numéro cité en gras reste tappable).
  List<InlineSpan> _formatAndLinkify(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _markdownPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.addAll(_linkify(text.substring(lastEnd, match.start), style));
      }
      final TextStyle formatted;
      final String inner;
      if (match.group(1) != null) {
        inner = match.group(1)!;
        formatted = style.copyWith(fontWeight: FontWeight.w700);
      } else if (match.group(2) != null) {
        inner = match.group(2)!;
        formatted = style.copyWith(fontStyle: FontStyle.italic);
      } else {
        inner = match.group(3)!;
        formatted = style.copyWith(decoration: TextDecoration.lineThrough);
      }
      spans.addAll(_linkify(inner, formatted));
      lastEnd = match.end;
    }
    if (lastEnd < text.length)
      spans.addAll(_linkify(text.substring(lastEnd), style));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = _formatAndLinkify(widget.text, widget.style);
    if (spans.isEmpty) spans.add(TextSpan(text: widget.text));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Ce qui se passe au tap d'un numéro — texte libre ou carte de visite,
/// c'est pourquoi c'est une fonction à part plutôt qu'un geste dupliqué dans
/// chaque widget. Consulte `GET /contacts/lookup` (ne crée rien) puis ouvre
/// directement la conversation si le numéro est inscrit, ou propose
/// d'inviter par WhatsApp sinon.
///
/// Prend un `BuildContext` plutôt qu'un `WidgetRef` : `LinkifiedText` (texte
/// libre) est un `StatefulWidget` ordinaire, tandis que `ContactCardBubble`
/// est un `ConsumerWidget` — `ProviderScope.containerOf` atteint les mêmes
/// providers dans les deux cas sans dupliquer cette fonction.
Future<void> handlePhoneTap(BuildContext context, String rawPhone) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    final result = await container
        .read(messagingRepositoryProvider)
        .lookupPhone(rawPhone);
    if (!context.mounted) return;

    if (result.registered && result.userId != null) {
      final myUserId = container.read(authControllerProvider).user?.id;
      if (myUserId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            myUserId: myUserId,
            contactUserId: result.userId!,
            contactName: result.displayName ?? result.phone,
            // Le numéro qu'on vient de chercher, transmis à la conversation.
            //
            // Sans lui, le PREMIER message part en 403 : le serveur
            // n'autorise à écrire que si l'on peut DÉSIGNER la personne
            // autrement qu'en devinant un identifiant — fiche au carnet,
            // conversation existante, groupe commun, ou justement ce numéro
            // (voir messages.py::_require_reachable). Ici aucun des trois
            // premiers n'est vrai par construction : on vient de toucher un
            // numéro qui n'est pas dans le carnet.
            contactPhone: result.phone,
          ),
        ),
      );
      return;
    }

    await _showInviteSheet(context, result.phone);
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text(L.of(context).phoneLookupFailed)),
    );
  }
}

Future<void> _showInviteSheet(BuildContext context, String phone) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.person_off_outlined,
              color: AppColors.textMuted,
            ),
            title: Text(phone),
            subtitle: Text(L.of(context).phoneNotOnPokou),
          ),
          ListTile(
            leading: Icon(
              Icons.chat_outlined,
              color: AppColors.accentPrimaryDark,
            ),
            title: Text(L.of(context).phoneInviteWhatsApp),
            onTap: () => Navigator.pop(sheetContext, 'invite'),
          ),
        ],
      ),
    ),
  );
  if (action != 'invite') return;
  // wa.me attend le numéro SANS le "+" — voir la documentation du lien
  // d'ouverture directe de conversation WhatsApp.
  final withoutPlus = phone.replaceFirst('+', '');
  final text = Uri.encodeComponent(L.of(context).phoneInviteText);
  await launchUrl(
    Uri.parse('https://wa.me/$withoutPlus?text=$text'),
    mode: LaunchMode.externalApplication,
  );
}

/// Rendu d'un message de type CONTACT (carte de visite partagée) — une carte
/// par contact partagé, nom + numéro tappable comme n'importe quel numéro
/// détecté dans un texte libre (voir [handlePhoneTap]).
class ContactCardBubble extends StatelessWidget {
  const ContactCardBubble({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final contacts = (payload['contacts'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final textColor = AppColors.chatTextReceived;
    final mutedColor = AppColors.chatIconMuted;

    if (contacts.isEmpty) {
      return Text(
        L.of(context).contactCardTitle,
        style: TextStyle(color: textColor),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in contacts) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.chatActionGreen.withValues(
                    alpha: 0.2,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.chatActionGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry['display_name'] as String? ??
                            L.of(context).mediaContact,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      InkWell(
                        onTap: () => handlePhoneTap(
                          context,
                          entry['phone'] as String? ?? '',
                        ),
                        child: Text(
                          entry['phone'] as String? ?? '',
                          style: TextStyle(
                            color: mutedColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry != contacts.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
