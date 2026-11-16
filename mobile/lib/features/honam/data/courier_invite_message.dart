import '../../../core/deeplink/invite_link_parser.dart' show pokouLinkBaseUrl;
import '../../../l10n/app_localizations.dart';

/// Invitation coursier Honam envoyée à un ami (maquette Coursiers 23 et 24).
///
/// ── Le format ─────────────────────────────────────────────────────────
///
/// Comme la réponse à un statut (messaging/presentation/status_reply.dart),
/// l'invitation part comme un message à deux ORDINAIRE, chiffré de bout en
/// bout : le serveur n'y voit qu'un texte, aucun type ni canal nouveau.
/// Première ligne : un marqueur invisible suivi de « 🛵 », du titre de la
/// carte et du code du parrain ; puis le message du coursier ; puis le
/// lien `/honam/coursier/{code}`.
///
/// Une application qui ne connaît pas ce format affiche « 🛵 Invitation
/// coursier Honam · KODJO-7Q2 », le message et un lien qui ouvre l'offre :
/// lisible partout, sans rien casser.
const _marker = '\u2063🛵 ';
const _separator = ' · ';

/// Un code de parrainage : lettres, chiffres et tirets (« KODJO-7Q2 »).
final _codePattern = RegExp(r'^[A-Za-z0-9-]{3,32}$');

/// Le lien d'invitation d'un coursier : il ouvre l'offre avec son code.
String courierInviteLink(String code) =>
    '$pokouLinkBaseUrl/honam/coursier/$code';

/// Le texte à envoyer dans la discussion : la carte [title] (« Invitation
/// coursier Honam »), le message [text] du coursier et son lien.
String encodeCourierInvite({
  required String title,
  required String code,
  required String text,
}) {
  final header = title.replaceAll('\n', ' ').trim();
  return '$_marker$header$_separator$code\n${text.trim()}\n'
      '${courierInviteLink(code)}';
}

/// Le code du parrain et le message, si [content] est une invitation
/// coursier — `null` sinon. Le lien final n'est pas rendu : la carte et
/// son bouton « Voir l'offre » en tiennent lieu.
({String code, String text})? decodeCourierInvite(String? content) {
  if (content == null || !content.startsWith(_marker)) return null;
  final newline = content.indexOf('\n');
  final first = newline < 0 ? content : content.substring(0, newline);
  final cut = first.lastIndexOf(_separator);
  if (cut < 0) return null;
  final code = first.substring(cut + _separator.length).trim();
  if (!_codePattern.hasMatch(code)) return null;
  var text = newline < 0 ? '' : content.substring(newline + 1).trimRight();
  final link = courierInviteLink(code);
  if (text.endsWith(link)) {
    text = text.substring(0, text.length - link.length).trimRight();
  }
  return (code: code, text: text);
}

/// L'aperçu d'une invitation coursier dans la liste des discussions et
/// dans les notifications (« 🛵 Invitation coursier Honam »), ou `null`
/// si [content] n'en est pas une.
String? courierInvitePreviewOf(L l, String? content) =>
    decodeCourierInvite(content) == null
    ? null
    : '🛵 ${l.courierInviteCardLabel}';
