/// Ce que le chiffrement a pu faire d'un message — et ce qu'il faut en
/// conclure.
///
/// La règle tient en une phrase : **si Pokou ne peut pas garantir le
/// chiffrement, Pokou n'envoie pas le message.**
///
/// L'ancienne version renvoyait `null` partout pour dire « envoie en clair »,
/// et ce `null` recouvrait deux choses qui n'ont rien à voir : « cette
/// personne n'a pas d'application qui chiffre » et « je n'ai pas réussi à
/// récupérer sa clé ». Le second cas — un 500, un délai dépassé, un
/// trousseau illisible — faisait donc partir le message en clair, sans que
/// rien ne l'indique. Un serveur n'avait qu'à cesser de servir les
/// trousseaux pour tout lire.
///
/// Trois issues, et une seule laisse passer du clair :
///
/// - [SealEncrypted] : le message est chiffré, il part ;
/// - [SealPeerHasNoKeys] : 404, une réponse DÉFINITIVE du serveur — cette
///   personne n'a jamais publié de trousseau. Le message peut partir en
///   clair, mais l'écran doit le dire ;
/// - [SealRefused] : tout le reste. Le message NE PART PAS.
sealed class SealOutcome {
  const SealOutcome();
}

/// Chiffré. Les trois champs vont tels quels au serveur.
final class SealEncrypted extends SealOutcome {
  const SealEncrypted({
    required this.encryption,
    required this.ciphertext,
    required this.envelope,
  });

  final String encryption;
  final String ciphertext;
  final Map<String, dynamic> envelope;
}

/// Le correspondant n'a pas publié de trousseau.
///
/// C'est le SEUL cas où du clair peut encore partir, et il est distinct des
/// autres pour une raison précise : un 404 est une réponse, pas une panne.
/// Refuser d'écrire à quelqu'un dont l'application n'a pas encore été mise à
/// jour couperait la messagerie en deux.
///
/// La contrepartie n'est pas négociable : la conversation doit être
/// VISIBLEMENT marquée comme non chiffrée (voir
/// features/messaging/presentation/encryption_banner.dart). Sans ce signal,
/// un serveur malveillant se contenterait de répondre 404 pour obtenir
/// exactement ce que la refonte cherche à empêcher.
final class SealPeerHasNoKeys extends SealOutcome {
  const SealPeerHasNoKeys();
}

/// Le chiffrement n'a pas pu être garanti. Le message ne part pas.
final class SealRefused extends SealOutcome {
  const SealRefused(this.reason);

  final SealFailure reason;
}

/// Pourquoi le chiffrement n'a pas pu être garanti.
///
/// Distinguées et non fondues en une seule : elles n'appellent pas la même
/// conduite. Une panne réseau se retente, un changement d'identité demande
/// une décision humaine, et un trousseau invalide est le signe qu'il se
/// passe quelque chose d'anormal.
enum SealFailure {
  /// Le serveur n'a pas répondu, ou a répondu une erreur (500, délai
  /// dépassé, coupure). On ne sait pas si la clé existe : on ne devine pas.
  keyLookupFailed,

  /// Le trousseau reçu est inexploitable — champ manquant, base64 invalide,
  /// signature qui ne correspond pas. Ce n'est pas une panne : c'est une
  /// réponse ANORMALE, et c'est précisément la forme qu'aurait une tentative
  /// d'interposition maladroite.
  invalidBundle,

  /// La clé d'identité du correspondant n'est plus celle de la session en
  /// cours. Réinstallation, changement de téléphone — ou quelqu'un au
  /// milieu. Rien ne permet de trancher depuis le code, donc on s'arrête et
  /// on demande à l'utilisateur.
  identityChanged,

  /// Le chiffrement lui-même a échoué (poignée de main, dérivation, scellage).
  cryptoFailure,
}

/// Levée par le dépôt de messagerie quand l'envoi est refusé faute de
/// chiffrement garanti.
///
/// Une exception et non un retour silencieux : l'écran DOIT s'arrêter, et un
/// code de retour ignoré par mégarde ferait revenir exactement le défaut
/// qu'on corrige.
class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException(this.reason);

  final SealFailure reason;

  @override
  String toString() => 'EncryptionUnavailableException($reason)';
}
