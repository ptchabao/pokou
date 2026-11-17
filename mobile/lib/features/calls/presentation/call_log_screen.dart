import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../data/call_repository.dart';
import 'call_controller.dart';
import 'call_screen.dart';
import 'ongoing_calls_section.dart';
import '../../../core/widgets/skeleton.dart';

/// Journal d'appels — historique des appels passés/reçus, façon WhatsApp.
/// Les entrées viennent de GET /calls/log (voir app/routes/calls.py) ; le
/// statut affiché reflète la perspective du spectateur (voir CallLogEntry).
class CallLogScreen extends ConsumerStatefulWidget {
  const CallLogScreen({super.key});

  @override
  ConsumerState<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends ConsumerState<CallLogScreen> {
  /// Le filtre vit dans l'écran et non dans un provider : il ne survit
  /// volontairement pas à la fermeture de l'onglet. Revenir au journal doit
  /// montrer TOUT l'historique — un filtre oublié fait croire à un appel
  /// disparu.
  CallFilter _filter = CallFilter.all;

  /// La loupe de l'en-tête (Discussions · 21) : un champ qui filtre par nom.
  bool _searching = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(callLogProvider);
    final missedCount = CallFilter.missed
        .apply(logAsync.valueOrNull ?? const [])
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      // La barre verte remplace le titre posé à même le canevas : elle donne
      // à l'application un bord haut identifiable d'un coup d'œil, y compris
      // en plein soleil où les nuances pâles disparaissent.
      appBar: PokouAppBar(
        title: L.of(context).navCalls,
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: L.of(context).actionSearch,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: L.of(context).callsSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            _CallFilters(
              current: _filter,
              missedCount: missedCount,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  ref.invalidate(ongoingGroupCallsProvider);
                  return ref.refresh(callLogProvider.future);
                },
                child: logAsync.when(
                  loading: () => const SkeletonList(avatarSize: 44),
                  error: (error, _) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          error is ApiException
                              ? error.message
                              : L.of(context).contactConnectFailed,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  data: (allEntries) {
                    final entries = _filter
                        .apply(allEntries)
                        .where(
                          (e) =>
                              _query.isEmpty ||
                              _CallLogTile.titleOf(
                                e,
                                L.of(context),
                              ).toLowerCase().contains(_query),
                        )
                        .toList();
                    if (entries.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        children: [
                          const OngoingCallsSection(),
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              L.of(context).callLogEmpty,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      );
                    }
                    // Des CARTES séparées, et non une liste à filets.
                    //
                    // Chaque appel porte désormais trois informations
                    // empilées — qui, quel type, quand et combien de temps.
                    // Un filet ne les sépare plus assez : à trois lignes, la
                    // frontière entre deux entrées devient ambiguë, et on
                    // rappelle le mauvais correspondant.
                    // Rangés par jour : « AUJOURD'HUI », « HIER », puis la
                    // date (Discussions · 21).
                    final l = L.of(context);
                    // Les appels de groupe en cours d'abord, comme WhatsApp.
                    final children = <Widget>[const OngoingCallsSection()];
                    String? currentDay;
                    for (final entry in entries) {
                      final day = _dayLabel(entry.createdAt, l, context);
                      if (day != currentDay) {
                        currentDay = day;
                        children.add(_DaySection(day));
                      }
                      children.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CallLogTile(entry: entry),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      children: children,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallLogTile extends ConsumerWidget {
  const _CallLogTile({required this.entry});

  final CallLogEntry entry;

  String _titleOf(L l) => titleOf(entry, l);

  static String titleOf(CallLogEntry entry, L l) {
    // Un appel de groupe s'intitule par son groupe : énumérer 8 participants
    // ne dit pas de quel appel il s'agit.
    final groupName = entry.groupName;
    if (groupName != null) return groupName;
    if (entry.others.isEmpty) return l.callLogUnknownUser;
    if (entry.others.length == 1) return entry.others.first.displayName;
    return entry.others.map((o) => o.displayName).join(', ');
  }

  (String, Color) _statusLabel(L l) {
    final incoming = entry.direction == 'incoming';
    switch (entry.status) {
      case 'missed':
        return incoming
            ? (l.callStatusMissed, AppColors.securityCritical)
            : (l.callStatusNoAnswer, AppColors.textMuted);
      case 'declined':
        return incoming
            ? (l.callStatusDeclined, AppColors.textMuted)
            : (l.callStatusDeclined, AppColors.securityCritical);
      case 'ended':
        final duration = entry.durationSeconds;
        if (duration == null) {
          return (
            incoming ? l.callStatusReceived : l.callStatusEnded,
            AppColors.textSecondary,
          );
        }
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        final length = minutes == 0
            ? l.callsDurationSeconds(seconds)
            : seconds == 0
            ? l.callsDurationMinutes(minutes)
            : l.callsDurationMinSec(
                minutes,
                seconds.toString().padLeft(2, '0'),
              );
        final kind = entry.callType != '1:1'
            ? (entry.isVideo ? l.callsGroupVideo : l.callsGroupAudio)
            : (incoming ? l.callsIncoming : l.callsOutgoing);
        final people = entry.callType != '1:1'
            ? ' · ${l.callsPeople(entry.others.length + 1)}'
            : '';
        return ('$kind$people · $length', AppColors.textSecondary);
      case 'ongoing':
        return (l.callStatusOngoing, AppColors.securityVerified);
      default:
        return (
          incoming ? l.callStatusReceived : l.callStatusOutgoing,
          AppColors.textSecondary,
        );
    }
  }

  Future<void> _redial(BuildContext context, WidgetRef ref) async {
    final otherIds = entry.others.map((o) => o.id).toList();
    if (otherIds.isEmpty) return;

    // Rappel en UN geste, sans confirmation (Discussions · 21) : la ligne
    // touchée dit déjà qui et comment — audio ou vidéo, comme l'appel
    // d'origine.
    try {
      final token = await ref
          .read(callRepositoryProvider)
          .startCall(otherIds, isVideo: entry.isVideo);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: otherIds,
            startWithVideo: entry.isVideo,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).contactCallFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusText, statusColor) = _statusLabel(L.of(context));
    final directionIcon = entry.direction == 'incoming'
        ? Icons.call_received
        : Icons.call_made;

    // Un appel MANQUÉ appelle une action, pas seulement une lecture. Son
    // bouton est donc plein ; les autres restent en teinte pâle. C'est la
    // couleur qui dit l'urgence, pas un libellé de plus.
    final manque = entry.isMissedOrDeclined && entry.direction == 'incoming';

    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: () => _redial(context, ref),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.chip,
          // Un trait, pas une ombre : le système supprime les ombres
          // diffuses pour tenir la fréquence d'images sur les appareils
          // d'entrée de gamme.
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _AvatarWithDirection(entry: entry, manque: manque),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _titleOf(L.of(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            // Un appel manqué se lit en rouge dès le nom :
                            // c'est la seule ligne du journal qui demande
                            // quelque chose.
                            color: manque
                                ? AppColors.semanticError
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Le ✓ suit le nom quand la ligne désigne UNE
                      // personne. Un appel de groupe s'intitule par son
                      // groupe : un badge y dirait que le groupe est
                      // certifié.
                      if (entry.groupName == null &&
                          entry.others.length == 1 &&
                          entry.others.first.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 15),
                      ],
                      if (entry.callType != '1:1') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            entry.others.isEmpty
                                ? L.of(context).callsGroupChip
                                : '${L.of(context).callsGroupChip} (${entry.others.length})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(directionIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: statusColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // L'heure à droite : le jour est déjà dans la section.
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                DateFormat.Hm().format(entry.createdAt.toLocal()),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            _CallAction(
              icon: entry.isVideo ? Icons.videocam : Icons.call,
              filled: manque,
              tooltip: manque
                  ? L.of(context).callsCallBack
                  : L.of(context).productCallAction,
              onPressed: () => _redial(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bouton rond au bout d'une ligne d'appel.
///
/// Plein pour un appel manqué, pâle sinon. C'est la seule différence, et
/// elle porte tout : sur un journal de vingt lignes, l'œil trouve d'abord
/// ce qui demande une action.
///
/// Glyphe blanc sur `#A65527` : 5,3:1. Glyphe brun sur le fond pâle :
/// au-dessus du seuil également, les deux états restent lisibles dehors.
class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.filled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool filled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled
                  ? AppColors.accentPrimary
                  : AppColors.accentPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: filled ? Colors.white : AppColors.accentPrimaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Les trois filtres du journal.
///
/// Chacun s'appuie sur une donnée qui EXISTE — `status`, `direction`,
/// `callType`. Aucun n'a demandé de champ nouveau.
///
/// Le troisième s'appelait « Chiffrés 1:1 », avec un cadenas. Il filtre
/// `callType == '1:1'` : des appels à DEUX, et rien d'autre. Or les appels de
/// Pokou passent par LiveKit et ne sont pas chiffrés de bout en bout — ni à
/// deux, ni en groupe. L'étiquette promettait donc une propriété que le
/// produit n'a pas, au seul endroit où l'utilisateur pouvait la vérifier.
/// Elle dit maintenant ce que le filtre fait vraiment.
enum CallFilter {
  all,
  missed;

  List<CallLogEntry> apply(List<CallLogEntry> entries) => switch (this) {
    CallFilter.all => entries,
    CallFilter.missed =>
      entries
          .where((e) => e.isMissedOrDeclined && e.direction == 'incoming')
          .toList(),
  };

  String labelOf(L l) => switch (this) {
    CallFilter.all => l.callsFilterAll,
    CallFilter.missed => l.callsFilterMissed,
  };
}

class _CallFilters extends StatelessWidget {
  const _CallFilters({
    required this.current,
    required this.missedCount,
    required this.onChanged,
  });

  final CallFilter current;

  /// « Manqués · N » : combien d'appels attendent un rappel.
  final int missedCount;
  final ValueChanged<CallFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        children: [
          for (final f in CallFilter.values) ...[
            _Chip(
              label: f == CallFilter.missed && missedCount > 0
                  ? '${f.labelOf(l)} · $missedCount'
                  : f.labelOf(l),
              selected: f == current,
              onTap: () => onChanged(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final encre = selected ? Colors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentPrimary
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'avatar d'une ligne d'appel, avec la pastille qui dit LE SENS.
///
/// Entrant, sortant, manqué : trois flèches, trois couleurs. C'était une
/// icône posée dans la ligne de texte, à côté du statut ; elle se perdait
/// parmi les mots. Sur l'avatar, elle se lit avant même le nom.
///
/// La maquette met aussi une puce « 1:1 Chiffré ». Je ne l'ai pas reprise :
/// les appels de Pokou ne sont PAS chiffrés de bout en bout — le média
/// passe par LiveKit, et rien dans le code ne l'en empêche. L'écrire serait
/// la fausse affirmation la plus grave que ce produit puisse faire.
class _AvatarWithDirection extends StatelessWidget {
  const _AvatarWithDirection({required this.entry, required this.manque});

  final CallLogEntry entry;
  final bool manque;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = manque
        ? (Icons.call_missed, AppColors.semanticError)
        : entry.direction == 'incoming'
        ? (Icons.call_received, AppColors.accentPrimaryDark)
        : (Icons.call_made, AppColors.accentPrimaryDark);

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Présence OUI, anneau NON : on vient chercher un appel, pas une
          // actualité. Savoir si la personne est joignable là, maintenant,
          // est exactement ce qui manque dans un journal d'appels.
          IdentityAvatar(
            userId: entry.others.isNotEmpty ? entry.others.first.id : null,
            avatar: entry.others.isNotEmpty ? entry.others.first.avatar : null,
            displayName: entry.groupName ?? '',
            size: 48,
            showStatusRing: false,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icone, size: 11, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Aujourd'hui », « Hier », ou la date — en capitales dans la section.
String _dayLabel(DateTime at, L l, BuildContext context) {
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.dayToday;
  if (diff == 1) return l.dayYesterday;
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(local);
}

class _DaySection extends StatelessWidget {
  const _DaySection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    ),
  );
}
