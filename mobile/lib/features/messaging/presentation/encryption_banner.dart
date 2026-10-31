import 'package:flutter/material.dart';

import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Ce que l'écran de conversation dit du chiffrement.
///
/// Sans lui, la garantie n'est pas vérifiable : une conversation chiffrée et
/// une conversation en clair avaient exactement la même apparence. Un
/// serveur n'avait donc qu'à répondre « cette personne n'a pas de clé » pour
/// tout lire, sans qu'un seul utilisateur puisse le remarquer.
///
/// Trois états, trois traitements, et c'est volontairement asymétrique :
///
/// - chiffré : une mention DISCRÈTE sous le nom. C'est l'état normal, il ne
///   doit pas encombrer ;
/// - non chiffré : une bande visible. C'est l'exception, et elle doit se
///   voir sans qu'on la cherche ;
/// - identité changée : une bande d'alerte qui demande une DÉCISION. C'est
///   le seul moment où le chiffrement de bout en bout s'adresse vraiment à
///   l'utilisateur.
enum ConversationEncryption {
  /// On n'a pas encore pu établir l'état — au chargement.
  unknown,

  /// Les messages partent chiffrés.
  encrypted,

  /// Le correspondant n'a pas publié de trousseau (404).
  peerHasNoKeys,

  /// La clé d'identité du correspondant a changé.
  identityChanged,
}

/// Traduit l'état d'identité renvoyé par le service en état d'écran.
///
/// `noSessionYet` et `unchanged` donnent tous deux « chiffré » : n'avoir
/// jamais échangé n'est pas un problème, la première poignée de main
/// établira la référence. `unknown` ne devient pas « non chiffré » — on ne
/// dégrade pas un affichage sur un contrôle raté, c'est [seal] qui tranche
/// au moment d'envoyer.
ConversationEncryption encryptionFromIdentity(PeerIdentity identity) =>
    switch (identity) {
      PeerIdentity.changed => ConversationEncryption.identityChanged,
      PeerIdentity.noSessionYet ||
      PeerIdentity.unchanged => ConversationEncryption.encrypted,
      PeerIdentity.unknown => ConversationEncryption.unknown,
    };

/// La bande affichée en haut du fil, quand il y a quelque chose à dire.
///
/// Renvoie une boîte vide dans les deux cas où il n'y a rien à signaler :
/// une bande « tout va bien » permanente serait ignorée en trois jours, et
/// perdrait alors sa valeur pour les cas où elle compte.
class EncryptionBanner extends StatelessWidget {
  const EncryptionBanner({
    super.key,
    required this.state,
    required this.peerName,
    required this.onAcceptIdentity,
  });

  final ConversationEncryption state;
  final String peerName;
  final VoidCallback onAcceptIdentity;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return switch (state) {
      // `unknown` : on n'affirme RIEN tant que le contrôle n'a pas abouti.
      // Afficher « chiffré » par défaut serait exactement l'affirmation
      // qu'un attaquant voudrait nous voir faire à sa place.
      ConversationEncryption.unknown => const SizedBox.shrink(),

      // Chiffré : on le DIT.
      //
      // Ce cas ne rendait rien. La logique était défendable — n'alerter
      // qu'en cas de problème, ne pas encombrer — mais elle avait un coût :
      // la promesse centrale du produit n'était visible nulle part, et son
      // absence ne se distinguait pas d'un écran ordinaire.
      //
      // Le bandeau est dans le FIL, au-dessus du premier message, et non
      // épinglé en haut : il se lit une fois à l'ouverture d'une
      // conversation, puis il s'en va en défilant. Une affirmation
      // permanente finit par ne plus être lue.
      ConversationEncryption.encrypted => _Reassurance(text: l.e2eeReassurance),
      ConversationEncryption.peerHasNoKeys => _Band(
        icon: Icons.lock_open_outlined,
        color: AppColors.textSecondary,
        title: l.e2eeNotEncrypted,
        body: l.e2eeNotEncryptedBody,
      ),
      ConversationEncryption.identityChanged => _Band(
        icon: Icons.warning_amber_rounded,
        color: AppColors.semanticError,
        title: l.e2eeIdentityChangedTitle,
        body: l.e2eeIdentityChangedBody(peerName),
        action: l.e2eeIdentityAccept,
        onAction: onAcceptIdentity,
      ),
    };
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = action;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(label, style: TextStyle(color: color)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La mention sous le nom, dans l'en-tête — discrète, mais toujours là.
class EncryptionHeaderLabel extends StatelessWidget {
  const EncryptionHeaderLabel({super.key, required this.state});

  final ConversationEncryption state;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (icon, text, color) = switch (state) {
      ConversationEncryption.encrypted => (
        Icons.lock_outline,
        l.e2eeEncrypted,
        AppColors.textSecondary,
      ),
      ConversationEncryption.peerHasNoKeys => (
        Icons.lock_open_outlined,
        l.e2eeNotEncrypted,
        AppColors.textSecondary,
      ),
      ConversationEncryption.identityChanged => (
        Icons.warning_amber_rounded,
        l.e2eeNotEncrypted,
        AppColors.semanticError,
      ),
      // Tant qu'on ne sait pas, on n'affirme RIEN. Afficher « chiffré » par
      // défaut serait la pire des options : c'est précisément l'affirmation
      // qu'un attaquant voudrait nous voir faire à sa place.
      ConversationEncryption.unknown => (null, null, null),
    };
    if (icon == null || text == null || color == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        // L'en-tête est étroit (nom, boutons d'appel) : « Non chiffré » ou
        // une traduction plus longue doit s'abréger, pas déborder.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}

/// Le message à montrer quand un envoi a été REFUSÉ faute de chiffrement.
///
/// Chaque motif a sa phrase : « échec de l'envoi » ne dirait pas que le
/// message n'est PAS parti, ni pourquoi, ni s'il faut réessayer ou vérifier
/// quelque chose.
String encryptionBlockedMessage(L l, SealFailure reason) => switch (reason) {
  SealFailure.keyLookupFailed => l.e2eeBlockedLookup,
  SealFailure.invalidBundle => l.e2eeBlockedInvalid,
  SealFailure.identityChanged => l.e2eeBlockedIdentity,
  SealFailure.cryptoFailure => l.e2eeBlockedCrypto,
};

/// Le bandeau qui dit que la conversation est chiffrée.
///
/// Brun sur sable — `#6B3415` sur `#FBEDE4`, soit 8,6:1 (autrefois vert
/// forêt sur vert pâle, 9,1:1 ; la couleur a suivi la marque, pas le
/// contraste). C'est
/// beaucoup pour un texte secondaire, et c'est voulu : il se lit en plein
/// soleil, sur un écran bon marché, par quelqu'un qui hésite à envoyer un
/// montant.
class _Reassurance extends StatelessWidget {
  const _Reassurance({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEDE4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 16, color: AppColors.accentPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF6B3415),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
