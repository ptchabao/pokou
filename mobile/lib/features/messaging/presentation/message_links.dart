import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'contact_card_bubble.dart' show findPhoneMatches, handlePhoneTap;

/// Ce qu'un message peut contenir de « touchable ».
enum MessageLinkKind { url, email, ussd, phone }

class MessageLink {
  const MessageLink(this.start, this.end, this.kind, this.value);

  final int start;
  final int end;
  final MessageLinkKind kind;
  final String value;
}

final RegExp _url = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);
final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');

/// Un code USSD : `*144#`, `*155*1*1#`, `#100#`. C'est ainsi qu'on paie,
/// qu'on consulte son solde ou qu'on recharge en Afrique de l'Ouest — un
/// code reçu dans un message doit se composer d'un geste.
final RegExp _ussd = RegExp(r'(?<![\w*#])[*#]\d{1,4}(?:\*\d{1,12})*#');

/// La ponctuation qui suit souvent un lien sans en faire partie.
final RegExp _trailing = RegExp(r'[.,;:!?)\]]+$');

/// Tous les éléments touchables d'un texte, sans chevauchement, dans
/// l'ordre. Un lien l'emporte sur ce qu'il contient (un numéro dans une
/// adresse web reste dans le lien).
List<MessageLink> findMessageLinks(String text) {
  final found = <MessageLink>[];
  bool free(int start, int end) =>
      !found.any((l) => start < l.end && l.start < end);

  for (final m in _url.allMatches(text)) {
    var value = m.group(0)!;
    final cut = _trailing.firstMatch(value);
    if (cut != null) value = value.substring(0, cut.start);
    if (value.isEmpty) continue;
    found.add(
      MessageLink(m.start, m.start + value.length, MessageLinkKind.url, value),
    );
  }
  for (final m in _email.allMatches(text)) {
    if (free(m.start, m.end)) {
      found.add(
        MessageLink(m.start, m.end, MessageLinkKind.email, m.group(0)!),
      );
    }
  }
  for (final m in _ussd.allMatches(text)) {
    if (free(m.start, m.end)) {
      found.add(MessageLink(m.start, m.end, MessageLinkKind.ussd, m.group(0)!));
    }
  }
  for (final m in findPhoneMatches(text)) {
    if (free(m.start, m.end)) {
      found.add(
        MessageLink(m.start, m.end, MessageLinkKind.phone, m.group(0)!),
      );
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  return found;
}

/// Le style d'un élément touchable : souligné, en gras, de la couleur du
/// texte — lisible sur les deux couleurs de bulle.
TextStyle messageLinkStyle(TextStyle base) => base.copyWith(
  decoration: TextDecoration.underline,
  decorationColor: base.color,
  fontWeight: FontWeight.w700,
);

/// Le span d'un élément touchable. Le reconnaisseur est rendu à
/// l'appelant, qui le libère.
TextSpan messageLinkSpan(
  BuildContext context,
  MessageLink link,
  TextStyle base,
  List<GestureRecognizer> recognizers,
) {
  final recognizer = TapGestureRecognizer()
    ..onTap = () => openMessageLink(context, link);
  recognizers.add(recognizer);
  return TextSpan(
    text: link.value,
    style: messageLinkStyle(base),
    recognizer: recognizer,
  );
}

Future<void> _copy(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = L.of(context).linkCopied;
  await Clipboard.setData(ClipboardData(text: value));
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}

Future<bool> _launch(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = L.of(context).linkOpenFailed;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  return ok;
}

/// Le numéro tel que le composeur l'attend : chiffres et « + ».
String _dialable(String raw) => raw.replaceAll(RegExp(r'[^\d+]'), '');

/// Un code USSD dans un lien `tel:` : `#` doit être encodé, sinon il est
/// lu comme le début d'un fragment et le code est tronqué.
Uri ussdUri(String code) => Uri.parse('tel:${code.replaceAll('#', '%23')}');

/// Ce que fait un toucher : un lien s'ouvre ; un numéro, un code USSD ou
/// une adresse e-mail proposent leurs gestes (appeler, composer, copier…).
Future<void> openMessageLink(BuildContext context, MessageLink link) async {
  switch (link.kind) {
    case MessageLinkKind.url:
      final raw = link.value;
      final url = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
      final uri = Uri.tryParse(url);
      if (uri != null) await _launch(context, uri);
    case MessageLinkKind.email:
      await _sheet(context, link.value, [
        (
          Icons.mail_outline,
          L.of(context).linkSendEmail,
          () => _launch(context, Uri(scheme: 'mailto', path: link.value)),
        ),
      ]);
    case MessageLinkKind.ussd:
      await _sheet(context, link.value, [
        (
          Icons.dialpad,
          L.of(context).linkDial,
          () => _launch(context, ussdUri(link.value)),
        ),
      ]);
    case MessageLinkKind.phone:
      await _sheet(context, link.value, [
        (
          Icons.call_outlined,
          L.of(context).linkCall,
          () =>
              _launch(context, Uri(scheme: 'tel', path: _dialable(link.value))),
        ),
        (
          Icons.chat_bubble_outline,
          L.of(context).linkWriteOnPokou,
          () => handlePhoneTap(context, link.value),
        ),
      ]);
  }
}

/// La feuille des gestes d'un numéro, d'un code ou d'une adresse : chacun
/// d'eux, puis « Copier », toujours présent.
Future<void> _sheet(
  BuildContext context,
  String value,
  List<(IconData, String, Future<Object?> Function())> actions,
) async {
  final l = L.of(context);
  final chosen = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final (i, (icon, label, _)) in actions.indexed)
            ListTile(
              leading: Icon(icon, color: AppColors.accentPrimaryDark),
              title: Text(label),
              onTap: () => Navigator.pop(sheetContext, i),
            ),
          ListTile(
            leading: Icon(
              Icons.copy_rounded,
              color: AppColors.accentPrimaryDark,
            ),
            title: Text(l.linkCopy),
            onTap: () => Navigator.pop(sheetContext, -1),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == -1) {
    await _copy(context, value);
    return;
  }
  await actions[chosen].$3();
}

/// Un numéro de téléphone affiché sur une fiche : un toucher propose
/// d'appeler, d'écrire ou de copier ; un appui long le copie aussitôt.
///
/// Un simple `Text` ne réagissait à rien : sur le profil de quelqu'un, on
/// ne pouvait ni copier son numéro ni l'appeler hors de Pokou.
class CopyablePhone extends StatelessWidget {
  const CopyablePhone({
    super.key,
    required this.phone,
    this.style,
    this.textAlign,
  });

  final String phone;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Semantics(
      button: true,
      hint: l.linkCopy,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openMessageLink(
          context,
          MessageLink(0, phone.length, MessageLinkKind.phone, phone),
        ),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _copy(context, phone);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(phone, textAlign: textAlign, style: style),
        ),
      ),
    );
  }
}
