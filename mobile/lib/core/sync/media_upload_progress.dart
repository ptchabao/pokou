import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Où en est l'envoi d'un média, du point de vue de celui qui l'a composé.
///
/// ```
///     Préparation → Envoi (42 %) → Envoyé
///          ↓             ↓
///     En attente de connexion ←──┘
/// ```
///
/// Ces états ne sont pas décoratifs : ce sont les seuls moments où
/// l'utilisateur peut se demander si son geste a compté. Une photo qui
/// n'affiche rien pendant quinze secondes sur un réseau lent est
/// indistinguable d'une photo perdue — et on la renvoie, ce qui en fait
/// deux.
enum MediaSendPhase {
  /// Le fichier est écrit dans la file, rien n'est encore parti. Bref,
  /// mais visible : c'est lui qui fait apparaître la bulle IMMÉDIATEMENT,
  /// avant tout réseau.
  preparation,

  /// En cours de téléversement. [MediaSendState.fraction] est renseignée.
  envoi,

  /// Les octets sont partis, on attend la réponse du serveur. Distinct de
  /// `envoi` parce que la progression mesure ce qu'on a REMIS à la pile
  /// réseau, pas ce que le serveur a reçu : sur une connexion lente, la
  /// barre atteint 100 % quelques secondes avant la réponse.
  finalisation,

  /// Hors ligne, ou serveur injoignable. Le fichier n'est pas perdu : il
  /// repartira à la reconnexion.
  attenteReseau,

  /// Refus définitif du serveur, ou fichier disparu de l'appareil.
  /// Réessayer n'y changerait rien — l'écran propose de reprendre à la
  /// main.
  echec,
}

class MediaSendState {
  const MediaSendState(this.phase, {this.fraction});

  final MediaSendPhase phase;

  /// Entre 0 et 1, seulement pendant [MediaSendPhase.envoi].
  final double? fraction;

  int? get pourcentage => fraction == null ? null : (fraction! * 100).round();
}

/// L'avancement de chaque média en attente, par identifiant local.
///
/// Séparé du message lui-même, et c'est délibéré : la progression change
/// dix fois par seconde, le message non. Les fondre ferait réécrire la ligne
/// en base — et redessiner toute la conversation — à chaque paquet envoyé.
class MediaUploadProgress extends StateNotifier<Map<String, MediaSendState>> {
  MediaUploadProgress() : super(const {});

  void set(String localId, MediaSendPhase phase, {double? fraction}) {
    state = {...state, localId: MediaSendState(phase, fraction: fraction)};
  }

  /// Le message est parti pour de bon : on cesse de le suivre.
  void clear(String localId) {
    if (!state.containsKey(localId)) return;
    final copie = {...state}..remove(localId);
    state = copie;
  }
}

final mediaUploadProgressProvider =
    StateNotifierProvider<MediaUploadProgress, Map<String, MediaSendState>>(
      (ref) => MediaUploadProgress(),
    );
