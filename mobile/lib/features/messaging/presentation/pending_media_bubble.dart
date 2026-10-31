import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/media_upload_progress.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/data/group_model.dart';
import '../data/direct_message_model.dart';

/// Une pièce jointe qui n'est pas encore partie.
///
/// ── Ce que cette bulle remplace ───────────────────────────────────────
///
/// Rien. Envoyer une photo téléversait d'abord et n'affichait rien avant la
/// réponse : quinze secondes de vide sur un réseau lent, impossibles à
/// distinguer d'un envoi perdu. On renvoyait, et le destinataire recevait
/// deux fois la même photo quand le premier finissait par passer.
///
/// L'aperçu vient du fichier LOCAL — il est déjà sur l'appareil, il n'y a
/// aucune raison d'attendre le réseau pour le montrer.
///
/// ── Les états, et pourquoi ils sont distincts ─────────────────────────
///
/// « Envoi 42 % » et « Envoi… » ne disent pas la même chose : la fraction
/// mesure les octets remis à la pile réseau, pas ceux que le serveur a
/// acceptés. Sur une connexion lente, la barre atteint 100 % quelques
/// secondes avant la réponse — et une barre pleine qui ne bouge plus
/// ressemble à un blocage. D'où l'état « finalisation », qui dit la vérité :
/// c'est parti, on attend la confirmation.
///
/// « En attente de connexion » n'est pas une erreur, et n'en a donc pas la
/// couleur. Le fichier n'est pas perdu ; il repartira. Le dire évite le
/// renvoi, qui est la vraie conséquence d'un doute.
class PendingMediaBubble extends ConsumerWidget {
  PendingMediaBubble({
    super.key,
    required DirectMessage message,
    required this.onRetry,
  }) : localId = message.id,
       messageType = message.messageType,
       fichier = message.pendingMedia;

  /// La même bulle pour un message de GROUPE.
  ///
  /// Un constructeur nommé plutôt qu'un widget jumeau : les deux types de
  /// message ne partagent pas d'interface commune, mais cette bulle n'a
  /// besoin que de trois choses — l'identifiant local qui porte la
  /// progression, le type, et le fichier. Dupliquer le widget aurait garanti
  /// qu'une correction n'atteigne qu'une des deux conversations.
  PendingMediaBubble.group({
    super.key,
    required GroupMessage message,
    required this.onRetry,
  }) : localId = message.id,
       messageType = message.messageType,
       fichier = message.pendingMedia;

  final String localId;
  final String messageType;
  final PendingMedia? fichier;

  /// Reprendre à la main, après un échec définitif.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final fichier = this.fichier!;
    final etat =
        ref.watch(mediaUploadProgressProvider)[localId] ??
        const MediaSendState(MediaSendPhase.preparation);

    final estImage = messageType == 'IMAGE' || messageType == 'VIDEO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (estImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Le fichier est LOCAL : l'aperçu n'attend pas le réseau.
                Image.file(
                  File(fichier.path),
                  width: 220,
                  fit: BoxFit.cover,
                  cacheWidth: (220 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (_, _, _) => _CadreAbsent(l: l),
                ),
                // Voile sombre tant que ce n'est pas parti : l'image reste
                // reconnaissable, mais on voit qu'elle n'est pas encore
                // chez l'autre.
                if (etat.phase != MediaSendPhase.echec)
                  Container(
                    width: 220,
                    height: 120,
                    color: Colors.black.withValues(alpha: 0.28),
                    alignment: Alignment.center,
                    child: _Indicateur(etat: etat),
                  ),
              ],
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fichier.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _libelle(l, etat),
              style: TextStyle(
                fontSize: 11.5,
                color: etat.phase == MediaSendPhase.echec
                    ? AppColors.semanticError
                    : AppColors.textMuted,
              ),
            ),
            if (etat.phase == MediaSendPhase.echec) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onRetry,
                child: Text(
                  l.actionRetry,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimaryDark,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (fichier.caption != null && fichier.caption!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            fichier.caption!,
            style: TextStyle(color: AppColors.chatTextReceived, height: 1.4),
          ),
        ],
      ],
    );
  }

  String _libelle(L l, MediaSendState etat) => switch (etat.phase) {
    MediaSendPhase.preparation => l.mediaStatePreparing,
    MediaSendPhase.envoi =>
      etat.pourcentage == null
          ? l.mediaStateSending
          : l.mediaStateSendingPercent(etat.pourcentage!),
    MediaSendPhase.finalisation => l.mediaStateSending,
    MediaSendPhase.attenteReseau => l.mediaStateWaitingNetwork,
    MediaSendPhase.echec => l.mediaStateFailed,
  };
}

class _Indicateur extends StatelessWidget {
  const _Indicateur({required this.etat});

  final MediaSendState etat;

  @override
  Widget build(BuildContext context) {
    if (etat.phase == MediaSendPhase.attenteReseau) {
      return Icon(Icons.cloud_off_outlined, color: Colors.white, size: 26);
    }
    return SizedBox(
      width: 34,
      height: 34,
      child: CircularProgressIndicator(
        // Déterminé pendant l'envoi, indéterminé avant et après : une barre
        // figée à 100 % pendant qu'on attend la réponse ferait croire à un
        // blocage.
        value: etat.phase == MediaSendPhase.envoi ? etat.fraction : null,
        strokeWidth: 3,
        color: Colors.white,
        backgroundColor: Colors.white24,
      ),
    );
  }
}

class _CadreAbsent extends StatelessWidget {
  const _CadreAbsent({required this.l});

  final L l;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 120,
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        l.mediaStateFileGone,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
