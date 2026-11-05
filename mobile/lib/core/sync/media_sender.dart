import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/groups/data/group_model.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/presentation/group_controller.dart';
import '../../features/messaging/data/direct_message_model.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/messaging/presentation/messaging_controller.dart';
import '../api/api_exceptions.dart';
import '../crypto/e2ee_outcome.dart';
import '../crypto/e2ee_service.dart';
import '../crypto/media_cipher.dart';
import '../media/media_repository.dart';
import '../providers.dart';
import '../storage/pokou_message_store.dart';
import 'media_upload_progress.dart';

/// Faire partir un média déjà mis en file — téléverser, puis envoyer.
///
/// ── Pourquoi un service, et pas deux chemins ─────────────────────────
///
/// Un média part de deux endroits : l'écran de conversation quand on vient
/// de le choisir, et la file d'attente quand le réseau revient. Ces deux
/// chemins doivent faire EXACTEMENT la même chose — même téléversement,
/// même message, même écriture en cache, même progression.
///
/// Les écrire deux fois, c'était garantir qu'ils divergent : l'un
/// marquerait la ligne confirmée et pas l'autre, ou l'un enverrait la
/// légende et pas l'autre. Et la divergence ne se verrait qu'après une
/// coupure réseau, c'est-à-dire chez l'utilisateur.
///
/// ── Ce que ce service garantit ───────────────────────────────────────
///
/// **Le geste n'est jamais perdu.** La bulle est écrite AVANT le
/// téléversement ; ce service ne fait que la faire aboutir. Une coupure la
/// laisse en attente, et la file reprend à la reconnexion — y compris après
/// un redémarrage de l'application.
///
/// **Rien ne part deux fois.** Le téléversement d'un même identifiant local
/// n'est jamais concurrent : `_enCours` le garantit, parce que l'écran et la
/// file peuvent très bien tenter au même instant.
class MediaSender {
  MediaSender({
    required MediaRepository media,
    required MessagingRepository messaging,
    required GroupRepository groups,
    required PokouMessageStore store,
    required MediaUploadProgress progress,
    E2EEService? e2ee,
  }) : _media = media,
       _messaging = messaging,
       _groups = groups,
       _store = store,
       _progress = progress,
       _e2ee = e2ee;

  final MediaRepository _media;
  final MessagingRepository _messaging;
  final GroupRepository _groups;
  final PokouMessageStore _store;
  final MediaUploadProgress _progress;

  /// Absent dans les tests qui ne s'occupent pas du chiffrement : le
  /// fichier part alors comme avant.
  final E2EEService? _e2ee;

  /// Les identifiants locaux en cours de traitement.
  ///
  /// L'écran tente l'envoi tout de suite ; la file d'attente tente à la
  /// reconnexion. Sans ce verrou, une reconnexion survenant pendant un
  /// téléversement en lancerait un second sur le même fichier — et le
  /// destinataire recevrait deux fois la photo.
  static final Set<String> _enCours = {};

  /// `true` si le message est parti, `false` s'il reste en attente.
  ///
  /// Ne lève PAS sur une coupure réseau : l'appelant n'a rien à décider
  /// dans ce cas, la ligne reste en file et repartira.
  Future<bool> envoyer(DirectMessage enAttente) {
    final fichier = enAttente.pendingMedia;
    if (fichier == null) return Future.value(false);
    return _faire(
      localId: enAttente.id,
      fichier: fichier,
      messageType: enAttente.messageType,
      // En conversation privée, le fichier est chiffré de bout en bout dès
      // que le correspondant sait l'ouvrir.
      chiffrer: () => _correspondantDechiffre(enAttente.recipientId),
      confirmer: (mediaId, mediaKey) async {
        final envoye = await _messaging.sendMedia(
          recipientId: enAttente.recipientId,
          messageType: enAttente.messageType,
          mediaAssetId: mediaId,
          caption: fichier.caption,
          viewOnce: enAttente.viewOnce,
          mediaKey: mediaKey,
        );
        await _store.confirmDirect(enAttente.id, envoye);
      },
      marquerEchec: () => _store.markDirectFailed(enAttente.id),
    );
  }

  /// La même chose dans un groupe.
  ///
  /// Bytes and metadata are encrypted before upload; the media key is then
  /// protected by the group's Signal Sender Key.
  Future<bool> envoyerGroupe(GroupMessage enAttente) {
    final fichier = enAttente.pendingMedia;
    if (fichier == null) return Future.value(false);
    return _faire(
      localId: enAttente.id,
      fichier: fichier,
      messageType: enAttente.messageType,
      chiffrer: () async => true,
      confirmer: (mediaId, mediaKey) async {
        final envoye = await _groups.sendMedia(
          group: await _groups.getGroup(enAttente.groupId),
          senderId: enAttente.senderId,
          messageType: enAttente.messageType,
          mediaAssetId: mediaId,
          mediaKey: mediaKey,
          caption: fichier.caption,
        );
        await _store.confirmGroup(enAttente.id, envoye);
      },
      marquerEchec: () => _store.markGroupFailed(enAttente.id),
    );
  }

  /// Le correspondant sait-il ouvrir une pièce jointe chiffrée ?
  ///
  /// Lève une NetworkException quand on ne peut pas le savoir (le fichier
  /// reste en file), et refuse quand sa session vise une autre identité que
  /// celle qu'il publie : la clé scellée dessus ne s'ouvrirait pas chez lui,
  /// et l'envoyer en clair à la place serait pire — c'est la situation
  /// même où quelqu'un pourrait s'être intercalé. Même règle qu'un texte.
  Future<bool> _correspondantDechiffre(int recipientId) async {
    final e2ee = _e2ee;
    if (e2ee == null) return false;
    final peer = await e2ee.peerCrypto(recipientId);
    if (!peer.capabilities.contains(E2EEService.mediaCapability)) return false;
    final session = await e2ee.sessionState(
      recipientId,
      publishedIdentityKey: peer.identityKey,
    );
    if (session == PeerSessionState.changed) {
      throw const EncryptionUnavailableException(SealFailure.identityChanged);
    }
    return true;
  }

  Future<bool> _faire({
    required String localId,
    required PendingMedia fichier,
    required String messageType,
    required Future<void> Function(int mediaId, MediaKey? mediaKey) confirmer,
    required Future<void> Function() marquerEchec,
    Future<bool> Function()? chiffrer,
  }) async {
    if (!_enCours.add(localId)) return false;

    try {
      final octets = await File(fichier.path).readAsBytes();

      // Chiffré AVANT de quitter l'appareil : le serveur ne reçoit qu'un
      // bloc opaque, sous un type et un nom qui ne disent rien. La légende
      // voyage dans la clé, elle aussi chiffrée.
      final chiffre = chiffrer != null && await chiffrer()
          ? await MediaCipher.encrypt(
              octets,
              mimeType: fichier.mimeType,
              filename: fichier.filename,
              caption: fichier.caption,
            )
          : null;

      _progress.set(localId, MediaSendPhase.envoi, fraction: 0);
      final televerse = await _media.upload(
        bytes: chiffre?.blob ?? octets,
        filename: chiffre != null
            ? MediaCipher.uploadFilename
            : fichier.filename,
        mimeType: chiffre != null
            ? MediaCipher.uploadMimeType
            : fichier.mimeType,
        // Le serveur n'accepte un bloc sans type reconnaissable que comme
        // document ; le VRAI type part dans le message, chiffré.
        messageType: chiffre != null ? 'DOCUMENT' : messageType,
        memoriser: chiffre == null,
        onProgress: (fraction) =>
            _progress.set(localId, MediaSendPhase.envoi, fraction: fraction),
      );

      _progress.set(localId, MediaSendPhase.finalisation);

      // Le fichier est déjà sur l'appareil : on le garde en cache sous l'ID
      // attribué pour que la bulle confirmée s'affiche immédiatement
      // sans jamais le retélécharger depuis le serveur.
      final ext = fichier.filename.contains('.')
          ? fichier.filename.split('.').last
          : fichier.mimeType.split('/').last;
      await _media.memoriserDansCache(
        televerse.id,
        sourcePath: fichier.path,
        bytes: octets,
        extension: ext,
      );

      await confirmer(televerse.id, chiffre?.key.withAssetId(televerse.id));
      _progress.clear(localId);
      return true;
    } on EncryptionUnavailableException {
      // La clé ne peut pas partir chiffrée (identité du correspondant
      // changée, trousseau disparu). Réessayer en boucle ne changerait
      // rien, et l'envoyer en clair annulerait le chiffrement du fichier.
      await marquerEchec();
      _progress.set(localId, MediaSendPhase.echec);
      return false;
    } on PathNotFoundException {
      // Le fichier a disparu de l'appareil entre la composition et l'envoi
      // — répertoire temporaire vidé, photo supprimée. Réessayer n'y
      // changera rien : c'est un échec définitif, et l'écran doit le dire
      // plutôt que de tourner indéfiniment.
      await marquerEchec();
      _progress.set(localId, MediaSendPhase.echec);
      return false;
    } on NetworkException {
      _progress.set(localId, MediaSendPhase.attenteReseau);
      return false;
    } on ApiException catch (exc) {
      // 5xx : le serveur est en peine, pas la requête — on garde en file.
      // 4xx : il refuse ce message, le retenter ne le fera jamais passer.
      if (exc.statusCode < 500) {
        await marquerEchec();
        _progress.set(localId, MediaSendPhase.echec);
      } else {
        _progress.set(localId, MediaSendPhase.attenteReseau);
      }
      return false;
    } catch (_) {
      // Délai dépassé, réponse illisible : traité comme une coupure, donc
      // réessayé plus tard. Perdre le fichier serait pire que réessayer.
      _progress.set(localId, MediaSendPhase.attenteReseau);
      return false;
    } finally {
      _enCours.remove(localId);
    }
  }
}

final mediaSenderProvider = Provider<MediaSender>(
  (ref) => MediaSender(
    media: ref.watch(mediaRepositoryProvider),
    messaging: ref.watch(messagingRepositoryProvider),
    groups: ref.watch(groupRepositoryProvider),
    store: ref.watch(pokouMessageStoreProvider),
    progress: ref.watch(mediaUploadProgressProvider.notifier),
    e2ee: ref.watch(e2eeServiceProvider),
  ),
);
