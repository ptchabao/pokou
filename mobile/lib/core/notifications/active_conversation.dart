import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La conversation actuellement À L'ÉCRAN, s'il y en a une.
///
/// C'est la seule information que le serveur ne peut pas avoir : il sait
/// qu'une socket est ouverte, pas ce que l'écran affiche. Or c'est elle qui
/// décide de la règle la plus visible d'une messagerie — recevoir un message
/// dans la conversation qu'on est en train de lire ne doit PAS faire sonner
/// le téléphone. Sans elle, l'application se notifie elle-même pendant
/// qu'on tape une réponse.
///
/// Séparée du Mode Bouclier, qui suivait déjà une notion voisine pour son
/// propre usage : la sienne ne couvre que le tête-à-tête et se remet à zéro
/// selon ses règles à lui. Les mélanger ferait dépendre le silence des
/// notifications d'un module qu'on peut désactiver.
class ActiveConversation {
  const ActiveConversation.direct(this.contactUserId)
      : groupId = null;
  const ActiveConversation.group(this.groupId) : contactUserId = null;

  final int? contactUserId;
  final int? groupId;

  /// Cette notification concerne-t-elle l'écran ouvert ?
  ///
  /// Les identifiants arrivent de FCM en chaînes de caractères : la
  /// comparaison se fait sur des entiers analysés, pas sur du texte, pour
  /// qu'un « 8 » et un « 08 » ne passent pas pour deux conversations.
  bool matches({int? contactUserId, int? groupId}) {
    if (groupId != null) return this.groupId == groupId;
    if (contactUserId != null) return this.contactUserId == contactUserId;
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is ActiveConversation &&
      other.contactUserId == contactUserId &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(contactUserId, groupId);
}

/// `null` quand aucune conversation n'est ouverte — liste d'accueil, marché,
/// réglages, ou application en arrière-plan (les écrans la remettent à zéro
/// en se démontant).
final activeConversationProvider =
    StateProvider<ActiveConversation?>((ref) => null);
