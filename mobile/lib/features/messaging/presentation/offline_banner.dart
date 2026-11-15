import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart' show wsOnlineProvider;
import '../../../l10n/app_localizations.dart';

/// Discussions · 19 — « Pas de connexion. Tes messages partiront dès le
/// retour du réseau. »
///
/// Lu sur la connexion temps réel (`wsOnlineProvider`), la même source que
/// l'en-tête des écrans principaux. Rien ne s'affiche tant qu'on ne sait
/// pas : au tout premier rendu le flux n'a encore rien émis, et un bandeau
/// qui clignote à chaque ouverture serait une fausse alerte.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(wsOnlineProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              L.of(context).offlineMessagesWillSend,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
