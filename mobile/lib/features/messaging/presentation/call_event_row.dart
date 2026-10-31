import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Un appel terminé, dans le fil de la conversation.
///
/// ── Pourquoi ce n'est pas une bulle ──────────────────────────────────
///
/// Un appel n'a pas d'auteur au sens d'un message : les deux personnes y
/// étaient. L'aligner à droite ou à gauche selon qui a composé le numéro
/// raconterait « untel vous a dit quelque chose », alors qu'il s'est passé
/// quelque chose ENTRE les deux. D'où une pastille centrée, du même genre
/// que le séparateur de date, et non une bulle de message.
///
/// ── Ce que la pastille dit, et ce qu'elle ne dit pas ─────────────────
///
/// La durée se compte depuis le premier décroché, pas depuis la création de
/// l'appel — les quarante secondes de sonnerie ne sont pas du temps passé à
/// se parler (voir api/app/services/call_thread_service.py).
///
/// Un appel manqué est en rouge, mais seulement pour celui qui l'a manqué.
/// Marquer en rouge l'appel qu'on a soi-même passé et que l'autre n'a pas
/// pris transformerait un fait banal en reproche.
class CallEventRow extends StatelessWidget {
  const CallEventRow({
    super.key,
    required this.payload,
    required this.isMine,
    this.onCallBack,
  });

  /// `DirectMessage.payload` / `GroupMessage.payload` d'un message `CALL`.
  final Map<String, dynamic> payload;

  /// Vrai si c'est moi qui ai lancé l'appel.
  final bool isMine;

  /// Rappeler. `null` masque l'action — rien ne doit proposer un geste qui
  /// ne marchera pas.
  final void Function({required bool video})? onCallBack;

  bool get _isVideo => payload['is_video'] as bool? ?? false;
  bool get _isGroup => payload['call_type'] == 'group';
  String get _status => payload['status'] as String? ?? 'ended';
  int? get _duree => (payload['duration_seconds'] as num?)?.toInt();
  int get _participants => (payload['participant_count'] as num?)?.toInt() ?? 0;

  /// Manqué DE MON POINT DE VUE : je n'ai pas décroché un appel qu'on
  /// m'adressait. Un appel que j'ai passé et qui n'a pas abouti n'est pas
  /// une alerte, c'est une information.
  bool get _manqueParMoi =>
      !isMine && (_status == 'missed' || _status == 'declined');

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final teinte = _manqueParMoi
        ? AppColors.semanticError
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: Semantics(
          button: onCallBack != null,
          label: '${_titre(l)} — ${_detail(l)}',
          child: InkWell(
            onTap: onCallBack == null
                ? null
                : () => onCallBack!(video: _isVideo),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icone, size: 15, color: teinte),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _titre(l),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: teinte,
                            ),
                          ),
                          TextSpan(
                            text: '  ·  ${_detail(l)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (onCallBack != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.refresh,
                      size: 14,
                      color: AppColors.accentPrimaryDark,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icone {
    if (_manqueParMoi) {
      return _isVideo ? Icons.missed_video_call_outlined : Icons.call_missed;
    }
    if (_isGroup) return Icons.groups_outlined;
    if (_isVideo) return Icons.videocam_outlined;
    return isMine ? Icons.call_made : Icons.call_received;
  }

  String _titre(L l) {
    if (_isGroup) return l.callEventGroup;
    return _isVideo ? l.callEventVideo : l.callEventAudio;
  }

  String _detail(L l) {
    if (_status == 'missed') {
      return isMine ? l.callEventNoAnswer : l.callEventMissed;
    }
    if (_status == 'declined') {
      return isMine ? l.callEventDeclined : l.callEventYouDeclined;
    }
    final duree = _duree;
    final parts = <String>[
      if (duree != null) formatCallDuration(l, duree) else l.callEventEnded,
      // Le nombre de participants n'a de sens qu'à plus de deux : « 2
      // participants » sur un appel de groupe à deux dit une évidence.
      if (_isGroup && _participants > 2) l.callEventParticipants(_participants),
    ];
    return parts.join('  ·  ');
  }
}

/// Durée lisible d'un appel — « 45 s », « 12 min », « 1 h 05 ».
///
/// Pas le `12m03s` du journal d'appels : là-bas les durées s'alignent en
/// colonne et la seconde près aide à comparer. Ici la pastille se lit au fil
/// de la conversation, où « 12 min » suffit et se lit plus vite.
String formatCallDuration(L l, int secondes) {
  if (secondes < 60) return l.callEventSeconds(secondes);
  final minutes = secondes ~/ 60;
  if (minutes < 60) return l.callEventMinutes(minutes);
  final heures = minutes ~/ 60;
  final reste = minutes % 60;
  return l.callEventHours(heures, reste.toString().padLeft(2, '0'));
}
