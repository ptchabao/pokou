import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Une demande de code secret, repérée SUR LE TÉLÉPHONE.
///
/// Le texte ne quitte pas l'appareil pour cette vérification : Pokou ne lit
/// pas les messages (chiffrés de bout en bout), c'est l'application qui
/// regarde le message qu'elle vient elle-même de déchiffrer. Une liste de
/// formulations courantes, en français et en anglais — « code secret »,
/// « code PIN », « mot de passe », « OTP », « code de confirmation »… —
/// suffit à couvrir l'arnaque au faux agent Mobile Money, la plus répandue.
final _secretCodeRequest = RegExp(
  r"code\s*(secret|pin|otp|confidentiel|de\s+(confirmation|validation|retrait|vérification|verification|sécurité|securite))"
  r"|mot\s+de\s+passe|\botp\b|\bpin\b|secret\s+code|password|verification\s+code",
  caseSensitive: false,
);

/// Vrai si [text] demande un code secret.
bool asksForSecretCode(String? text) =>
    text != null && _secretCodeRequest.hasMatch(text);

/// Discussions · 15 — le premier message d'un numéro qui n'est pas dans le
/// carnet : un avertissement et trois actions, avant même de répondre.
///
/// Le nom affiché est celui que l'EXPÉDITEUR s'est choisi : rien ne le
/// vérifie, et c'est précisément ce qu'exploite le faux « Agent Mobile
/// Money ». La carte le dit, et rappelle que Pokou ne demande jamais de
/// code secret ni d'argent.
class UnknownSenderCard extends StatelessWidget {
  const UnknownSenderCard({
    super.key,
    required this.onBlock,
    required this.onReport,
    required this.onAdd,
  });

  final VoidCallback onBlock;
  final VoidCallback onReport;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.accentPrimaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.unknownSenderTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.unknownSenderBody,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CardAction(label: l.unknownSenderBlock, onTap: onBlock),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  label: l.unknownSenderReport,
                  onTap: onReport,
                ),
              ),
              if (onAdd != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _CardAction(label: l.unknownSenderAdd, onTap: onAdd!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accentPrimaryDark,
      side: BorderSide(color: AppColors.accentPrimaryDark),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: const StadiumBorder(),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

/// L'alerte rouge sous un message qui demande un code secret.
class SecretCodeAlert extends StatelessWidget {
  const SecretCodeAlert({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.semanticError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.semanticError.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.semanticError,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l.secretCodeAlertTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' ${l.secretCodeAlertBody}'),
                ],
              ),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.semanticError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
