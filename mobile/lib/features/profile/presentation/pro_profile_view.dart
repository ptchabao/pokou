import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/time/server_time.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/data/conversations_repository.dart' show ReportedMessage;
import '../../messaging/presentation/report_sheet.dart';
import '../data/contact_profile_model.dart';

/// Le profil Pro (maquette Pro 5), tel que les autres le voient : le nom
/// commercial en grand, « Géré par » le nom vérifié, l'activité, l'adresse
/// déclarée et les horaires, et depuis quand le badge est là.
///
/// Dans son propre fichier : c'est la seule partie du profil de contact qui
/// relève de Pokou certifié Pro, et l'agent Messagerie modifie le reste de
/// `contact_profile_screen.dart` en parallèle.
class ProProfileView extends ConsumerWidget {
  const ProProfileView({
    super.key,
    required this.userId,
    required this.badge,
    required this.profile,
    required this.onMessage,
    required this.onCall,
  });

  final int userId;

  /// La réponse de GET /certified/profile/{id} (display_name, managed_by,
  /// activity, address, hours, pro_since, document_type…).
  final Map<String, dynamic> badge;
  final ContactProfile profile;
  final VoidCallback onMessage;
  final void Function({required bool video}) onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final displayName = badge['display_name'] as String? ?? profile.displayName;
    final hours = badge['hours'] as Map<String, dynamic>?;
    final proSince = badge['pro_since'] as String?;
    final documentType = badge['document_type'] as String?;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(children: [const PokouBackButton(), const SizedBox(width: 6), Text(l.proProfileTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 16),
          Center(
            child: IdentityAvatar(
              userId: userId,
              avatar: profile.avatar,
              displayName: displayName,
              size: 88,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              const VerifiedBadge(size: 20, pro: true),
            ],
          ),
          if (badge['managed_by'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.proManagedByVerified(badge['managed_by'] as String),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          if (badge['activity'] != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge['activity'] as String, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProAction(icon: Icons.arrow_forward, label: l.mediaMessage, onTap: onMessage),
              const SizedBox(width: 24),
              _ProAction(icon: Icons.call_outlined, label: l.contactCall, onTap: () => onCall(video: false)),
              const SizedBox(width: 24),
              _ProAction(
                icon: Icons.share_outlined,
                label: l.actionShare,
                onTap: () => Share.share('$displayName — ${profile.phone ?? ''}'.trim()),
              ),
            ],
          ),
          if ((badge['address'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _ProCard(
              icon: Icons.location_on_outlined,
              title: badge['address'] as String,
              subtitle: l.proDeclaredAddress,
            ),
          ],
          if (hours != null) ...[
            const SizedBox(height: 10),
            _ProCard(
              icon: Icons.schedule,
              title: _hoursLabel(l, locale, hours),
              trailing: _OpenPill(hours: hours, l: l),
            ),
          ],
          if (proSince != null) ...[
            const SizedBox(height: 10),
            _ProCard(
              icon: Icons.verified_outlined,
              title: l.proSinceDate(DateFormat.yMMMM(locale).format(parseServerTime(proSince))),
              subtitle: documentType != null ? l.proDocumentVerifiedBySupport(documentType) : null,
            ),
          ],
          const SizedBox(height: 18),
          _ReportRow(userId: userId, name: displayName),
        ],
      ),
    );
  }

  static String _hoursLabel(L l, String locale, Map<String, dynamic> hours) {
    final days = (hours['days'] as List).cast<num>().map((d) => d.toInt()).toList()..sort();
    const names = ['', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    final span = days.isEmpty
        ? ''
        : days.length > 1 && _isConsecutive(days)
            ? '${names[days.first]} au ${names[days.last]}'
            : days.map((d) => names[d]).join(', ');
    return l.proHoursLine(span, hours['open'] as String, hours['close'] as String);
  }

  static bool _isConsecutive(List<int> days) {
    for (var i = 1; i < days.length; i++) {
      if (days[i] != days[i - 1] + 1) return false;
    }
    return true;
  }
}

class _ProAction extends StatelessWidget {
  const _ProAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceElevated),
            child: Icon(icon, color: AppColors.accentPrimaryDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.icon, required this.title, this.subtitle, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.card, border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// « Ouvert » / « Fermé », calculé sur l'heure de CE téléphone.
class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.hours, required this.l});

  final Map<String, dynamic> hours;
  final L l;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = (hours['days'] as List).cast<num>().map((d) => d.toInt()).toSet();
    final weekday = now.weekday; // 1 = lundi … 7 = dimanche, même convention
    final open = _parse(hours['open'] as String);
    final close = _parse(hours['close'] as String);
    final minutesNow = now.hour * 60 + now.minute;
    final isOpen = days.contains(weekday) && minutesNow >= open && minutesNow < close;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.feedbackSuccess.withValues(alpha: 0.15) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? l.proOpenNow : l.proClosedNow,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOpen ? AppColors.feedbackSuccess : AppColors.textSecondary,
        ),
      ),
    );
  }

  static int _parse(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

/// « Signaler {nom} » : envoie POST /conversations/report avec un motif.
class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.userId, required this.name});

  final int userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return TextButton.icon(
      onPressed: () => _report(context, ref),
      icon: const Icon(Icons.flag_outlined, color: AppColors.feedbackDanger, size: 18),
      label: Text(l.contactReport(name), style: const TextStyle(color: AppColors.feedbackDanger)),
    );
  }

  /// La même feuille « Signaler » que partout : motifs, « Bloquer aussi »,
  /// et la case de consentement (décochée) pour joindre les messages.
  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final myUserId = ref.read(authControllerProvider).user?.id;
    final recent = myUserId == null
        ? const <ReportedMessage>[]
        : await recentDirectForReport(
            ref,
            myUserId: myUserId,
            contactUserId: userId,
            contactName: name,
          );
    if (!context.mounted) return;
    await showReportSheet(
      context,
      ref,
      title: L.of(context).reportTitle(name),
      contactUserId: userId,
      recentMessages: recent,
    );
  }
}
