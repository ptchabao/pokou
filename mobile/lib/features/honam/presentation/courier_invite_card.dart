import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import 'courier_join_screen.dart';

/// Coursiers 24 · La carte « Invitation coursier Honam », en tête de la
/// bulle d'une invitation (voir data/courier_invite_message.dart) :
/// « {Nom} t'invite à livrer pour Honam », le prix d'une course, la ville
/// et le code, puis « Voir l'offre », qui ouvre l'offre avec le code du
/// parrain (Coursiers 25).
///
/// Le prix et la ville sont ceux de l'ami qui reçoit : l'offre est lue
/// dans SON pays. Tant qu'elle n'est pas là, la carte montre le code seul.
class CourierInviteCard extends ConsumerWidget {
  const CourierInviteCard({
    super.key,
    required this.code,
    required this.contactName,
    required this.isMine,
  });

  final String code;

  /// L'autre personne de la discussion : le parrain quand on m'invite,
  /// l'ami invité quand c'est moi qui ai envoyé la carte.
  final String contactName;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Mon propre envoi n'a pas besoin de l'offre : pas de bouton, pas de
    // requête pour chaque carte que j'ai envoyée.
    final offer = isMine
        ? null
        : ref.watch(courierOfferProvider(code)).valueOrNull;
    final price = offer?.deliveryPrice;
    final city = offer?.servedCities.firstOrNull;
    final details = [
      if (price != null) l.courierPerRide(formatFcfa(price)),
      ?city,
      l.courierInviteCardCode(code),
    ].join(' · ');
    final ink = AppColors.chatTextReceived;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.two_wheeler,
                size: 15,
                color: AppColors.accentPrimaryDark,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l.courierInviteCardLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isMine
                ? l.courierInviteCardTitleMine(contactName)
                : l.courierInviteCardTitle(contactName),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            details,
            style: TextStyle(fontSize: 12, color: ink.withValues(alpha: 0.75)),
          ),
          if (!isMine) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourierOfferScreen(referralCode: code),
                ),
              ),
              child: Text(l.courierInviteSeeOffer),
            ),
          ],
        ],
      ),
    );
  }
}
