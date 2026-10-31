import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';

/// L'invitation à rejoindre Pokou Messenger — un seul endroit.
///
/// Le texte et le lien vivaient recopiés dans les écrans qui invitent. Ils
/// avaient déjà divergé, et c'est le genre d'écart qu'on ne voit jamais :
/// deux invitations légèrement différentes partent, personne ne les compare.
///
/// Surtout, l'envoi passait par `wa.me`, c'est-à-dire par WhatsApp
/// EXCLUSIVEMENT. Pour une application dont l'argument est précisément de ne
/// plus dépendre de WhatsApp, imposer WhatsApp pour recruter était gênant —
/// et ça excluait purement et simplement quiconque utilise Telegram, un SMS,
/// Messenger ou un e-mail. La feuille de partage du système laisse le choix,
/// et connaît les applications réellement installées bien mieux que nous.
class InviteSharing {
  InviteSharing._();

  /// Lien Play Store de l'application.
  ///
  /// L'identifiant de paquet vient de `android/app/build.gradle.kts`
  /// (`applicationId`) : s'il change un jour, ce lien doit changer avec, et
  /// il vaut mieux qu'il n'y en ait qu'un à corriger.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.pokou.pokou';

  /// Le message partagé. Court à dessein : il est recopié dans un champ de
  /// saisie d'une autre application, souvent tronqué à l'aperçu, et c'est le
  /// LIEN qui doit rester visible.
  static String message(L l, {String? recipientName}) {
    final greeting = recipientName == null || recipientName.trim().isEmpty
        ? l.inviteJoinMe
        : l.inviteJoinMeNamed(recipientName.trim());
    return '$greeting : $playStoreUrl';
  }

  /// Ouvre la feuille de partage du système.
  ///
  /// `sharePositionOrigin` n'est pas facultatif sur iPad : sans lui, la
  /// feuille n'a pas d'ancre et l'application se ferme. On le calcule depuis
  /// le widget qui a déclenché le partage, et on retombe sur le centre de
  /// l'écran si ce contexte a disparu entre-temps.
  static Future<void> share(BuildContext context, {String? recipientName}) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 1,
            height: 1,
          );

    final l = L.of(context);
    await Share.share(
      message(l, recipientName: recipientName),
      subject: l.inviteJoinMe,
      sharePositionOrigin: origin,
    );
  }
}
