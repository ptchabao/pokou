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

/// Le paiement vient d'être SIMULÉ par le serveur (pays de test) : déjà
/// confirmé, sans page de passerelle à ouvrir.
bool isTestPayment(Object? payment) =>
    payment is Map &&
    payment['test_mode'] == true &&
    payment['status'] == 'confirmed';

/// Ouvre ce que le serveur a renvoyé pour un paiement : la passerelle
/// Mobile Money, ou — dans un pays de test — rien du tout, avec un message
/// qui dit clairement que le paiement a été simulé.
///
/// Renvoie `true` quand l'effet est DÉJÀ acquis (paiement simulé) : l'écran
/// peut se rafraîchir tout de suite.
Future<bool> openPaymentResponse(
  BuildContext context,
  Map<String, dynamic> payment, {
  required String pendingMessage,
}) async {
  if (isTestPayment(payment)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).hnxTestPaymentDone)));
    return true;
  }
  await openPaymentGateway(
    context,
    payment['payment_url'] as String?,
    pendingMessage: pendingMessage,
  );
  return false;
}
