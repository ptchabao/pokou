import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvrir la passerelle Mobile Money, sans jamais se réjouir trop tôt.
///
/// Les cinq modules payants font exactement la même chose à cet endroit, et
/// c'est l'endroit où une inattention se voit : rien n'est accordé tant que
/// le serveur n'a pas reçu la confirmation. Un écran qui afficherait le
/// succès dès l'ouverture de la page de paiement mentirait à tous ceux qui
/// abandonnent ensuite — et ils sont nombreux.
///
/// Renvoie `true` si la passerelle s'est bien ouverte.
Future<bool> openPaymentGateway(
  BuildContext context,
  String? paymentUrl, {
  required String pendingMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  // Le libellé est lu AVANT le `launchUrl` : au retour, ce contexte peut ne
  // plus être monté, comme le messager capturé juste au-dessus.
  final failed = L.of(context).modulePaymentFailed;
  if (paymentUrl == null || paymentUrl.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return false;
  }
  final opened = await launchUrl(
    Uri.parse(paymentUrl),
    mode: LaunchMode.externalApplication,
  );
  messenger.showSnackBar(
    SnackBar(content: Text(opened ? pendingMessage : failed)),
  );
  return opened;
}
