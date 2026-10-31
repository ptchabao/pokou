import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/sync/media_upload_progress.dart';
import 'package:pokou/features/groups/data/group_model.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';

/// Une pièce jointe composée hors ligne ne doit pas disparaître.
///
/// L'ancienne version téléversait, puis envoyait, et n'écrivait rien entre
/// les deux. Une coupure au mauvais moment effaçait le geste : ni bulle, ni
/// fichier, ni trace. Sur un réseau mobile, « au mauvais moment » arrive
/// souvent — et on renvoie, ce qui en fait deux quand le premier finit par
/// passer.
///
/// Ce fichier verrouille les deux propriétés qui rendent ça impossible :
///
/// 1. **la bulle survit au tour de disque.** Elle est écrite AVANT le
///    téléversement, avec le chemin du fichier, et se relit à l'identique au
///    lancement suivant ;
/// 2. **le chemin local ne part JAMAIS au serveur.** C'est une information
///    d'appareil ; l'envoyer serait au mieux du bruit, au pire une fuite sur
///    l'arborescence du téléphone.
void main() {
  PendingMedia fichier() => const PendingMedia(
    path: '/data/user/0/com.pokou/cache/IMG_0421.jpg',
    filename: 'IMG_0421.jpg',
    mimeType: 'image/jpeg',
    caption: 'Le camion est arrivé',
  );

  DirectMessage enAttente() => DirectMessage(
    id: 'local-42',
    senderId: 1,
    recipientId: 2,
    messageType: 'IMAGE',
    content: 'Le camion est arrivé',
    mediaAssetId: null,
    media: null,
    status: DirectMessageStatus.sent,
    createdAt: DateTime.utc(2026, 9, 28, 10, 30),
    pendingMedia: fichier(),
  );

  group('la pièce jointe survit au tour de disque', () {
    test('le chemin et la légende se relisent à l\'identique', () {
      final relu = DirectMessage.fromJson(enAttente().toJson());

      expect(relu.pendingMedia, isNotNull);
      expect(relu.pendingMedia!.path, fichier().path);
      expect(relu.pendingMedia!.filename, 'IMG_0421.jpg');
      expect(relu.pendingMedia!.mimeType, 'image/jpeg');
      expect(relu.pendingMedia!.caption, 'Le camion est arrivé');
      // Et le reste du message aussi : c'est la MÊME bulle qu'on retrouve,
      // pas une reconstruction approximative.
      expect(relu.messageType, 'IMAGE');
      expect(relu.id, 'local-42');
    });

    test('un message ordinaire n\'en porte aucune', () {
      // Le champ ne doit pas apparaître là où il n'a rien à faire : une clé
      // `pending_media: null` sur chaque message du cache le gonflerait
      // pour rien.
      final texte = DirectMessage(
        id: 'local-1',
        senderId: 1,
        recipientId: 2,
        messageType: 'TEXT',
        content: 'Bonjour',
        mediaAssetId: null,
        media: null,
        status: DirectMessageStatus.sent,
        createdAt: DateTime.utc(2026, 9, 28),
      );
      expect(texte.toJson().containsKey('pending_media'), isFalse);
      expect(DirectMessage.fromJson(texte.toJson()).pendingMedia, isNull);
    });

    test('une charge utile venue du SERVEUR n\'en porte jamais', () {
      // Le serveur ne connaît pas ce champ. S'il apparaissait un jour dans
      // une réponse, ce serait le signe qu'on le lui envoie — c'est-à-dire
      // qu'on lui révèle l'arborescence du téléphone.
      final duServeur = DirectMessage.fromJson({
        'id': 'srv-7',
        'sender_id': 1,
        'recipient_id': 2,
        'message_type': 'IMAGE',
        'content': null,
        'media_asset_id': 9,
        'status': 'sent',
        'created_at': '2026-09-28T10:30:00.000Z',
      });
      expect(duServeur.pendingMedia, isNull);
    });
  });

  group('les états d\'envoi', () {
    test('la fraction devient un pourcentage entier', () {
      const etat = MediaSendState(MediaSendPhase.envoi, fraction: 0.4237);
      expect(etat.pourcentage, 42);
    });

    test('sans fraction, aucun pourcentage à afficher', () {
      // « Envoi… » et « Envoi 0 % » ne disent pas la même chose : le second
      // laisse croire que rien n'avance.
      const etat = MediaSendState(MediaSendPhase.finalisation);
      expect(etat.pourcentage, isNull);
    });

    test('suivre puis oublier un envoi', () {
      final suivi = MediaUploadProgress();
      suivi.set('local-42', MediaSendPhase.envoi, fraction: 0.5);
      expect(suivi.state['local-42']!.pourcentage, 50);

      suivi.set('local-42', MediaSendPhase.attenteReseau);
      // La fraction disparaît avec la phase : garder « 50 % » sous
      // « En attente de connexion » mélangerait deux informations.
      expect(suivi.state['local-42']!.fraction, isNull);

      suivi.clear('local-42');
      expect(suivi.state.containsKey('local-42'), isFalse);
    });

    test('plusieurs envois se suivent séparément', () {
      // On envoie souvent trois photos d'affilée : chacune a sa propre
      // barre, et l'une ne doit pas écraser l'état de l'autre.
      final suivi = MediaUploadProgress();
      suivi.set('a', MediaSendPhase.envoi, fraction: 0.2);
      suivi.set('b', MediaSendPhase.envoi, fraction: 0.9);
      suivi.set('c', MediaSendPhase.attenteReseau);

      expect(suivi.state['a']!.pourcentage, 20);
      expect(suivi.state['b']!.pourcentage, 90);
      expect(suivi.state['c']!.phase, MediaSendPhase.attenteReseau);

      suivi.clear('b');
      expect(suivi.state.keys.toSet(), {'a', 'c'});
    });

    test('oublier un envoi inconnu ne fait rien', () {
      final suivi = MediaUploadProgress();
      final avant = suivi.state;
      suivi.clear('jamais-vu');
      expect(identical(suivi.state, avant), isTrue);
    });
  });

  group('dans un groupe', groupes);
}

/// La même chose dans un GROUPE.
///
/// Les deux conversations ne doivent pas se comporter différemment pour une
/// photo : c'est le genre d'écart qui fait dire qu'une application a été
/// faite en plusieurs fois. Ces tests existent pour que la prochaine
/// correction sur l'une atteigne l'autre.
void groupes() {
  test('un média de groupe survit aussi au tour de disque', () {
    final enAttente = GroupMessage(
      id: 'local-77',
      groupId: 12,
      senderId: 1,
      senderName: '',
      messageType: 'VIDEO',
      content: null,
      mediaAssetId: null,
      media: null,
      createdAt: DateTime.utc(2026, 9, 28, 11),
      pendingMedia: const PendingMedia(
        path: '/data/user/0/com.pokou/cache/VID_0003.mp4',
        filename: 'VID_0003.mp4',
        mimeType: 'video/mp4',
      ),
    );

    final relu = GroupMessage.fromJson(enAttente.toJson());
    expect(relu.pendingMedia!.path, enAttente.pendingMedia!.path);
    expect(relu.pendingMedia!.mimeType, 'video/mp4');
    expect(relu.groupId, 12);
    // Sans légende : la clé existe et vaut nul, elle ne se perd pas en route.
    expect(relu.pendingMedia!.caption, isNull);
  });

  test('un message de groupe venu du serveur n\'en porte pas', () {
    final duServeur = GroupMessage.fromJson({
      'id': 'srv-3',
      'group_id': 12,
      'sender_id': 1,
      'sender_name': 'Kodjo',
      'message_type': 'IMAGE',
      'content': null,
      'media_asset_id': 4,
      'created_at': '2026-09-28T11:00:00.000Z',
    });
    expect(duServeur.pendingMedia, isNull);
  });
}
