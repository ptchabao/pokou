import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';
import 'package:pokou/core/sharing/invite_sharing.dart';

/// Le message d'invitation.
///
/// Il vivait recopié dans les écrans qui invitent, et avait déjà divergé —
/// l'écart entre deux invitations ne se voit jamais : elles partent chez des
/// gens différents, personne ne les compare.
void main() {
  // Le texte vient des traductions : on lit le français, la langue de ces
  // assertions.
  final l = LFr();
  test('le lien Play Store porte le bon identifiant de paquet', () {
    // Il doit correspondre à `applicationId` dans build.gradle.kts. Un lien
    // vers un paquet inexistant mène à une page d'erreur du Play Store —
    // et celui qui invite ne le saura jamais, c'est son contact qui tombe
    // dessus.
    expect(
      InviteSharing.playStoreUrl,
      'https://play.google.com/store/apps/details?id=com.pokou.pokou',
    );
  });

  test('le message porte toujours le lien', () {
    // C'est la seule partie qui compte : un message sans lien demande à
    // quelqu'un de chercher l'application par lui-même.
    expect(InviteSharing.message(l), contains(InviteSharing.playStoreUrl));
    expect(
      InviteSharing.message(l, recipientName: 'Awa'),
      contains(InviteSharing.playStoreUrl),
    );
  });

  test('le nom du destinataire est utilisé quand il existe', () {
    expect(InviteSharing.message(l, recipientName: 'Awa'), startsWith('Awa, rejoins-moi'));
  });

  test('un nom vide ou blanc ne produit pas une phrase bancale', () {
    // « , rejoins-moi sur Pokou Messenger » : le genre de détail qui donne
    // l'air d'un message automatique mal fait, exactement au moment où l'on
    // demande à quelqu'un de faire confiance à l'application.
    for (final name in ['', '   ']) {
      expect(InviteSharing.message(l, recipientName: name), startsWith('Rejoins-moi'));
    }
    expect(InviteSharing.message(l), startsWith('Rejoins-moi'));
  });
}
