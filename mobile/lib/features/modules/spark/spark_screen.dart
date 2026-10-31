import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_dates_view.dart';
import 'spark_feed_view.dart';
import 'spark_matches_view.dart';
import 'spark_me_view.dart';
import 'spark_onboarding_view.dart';

/// La couleur de Spark. Réservée à ce qui COMPTE le temps — le compte à
/// rebours d'une intention, celui d'une salle. Ailleurs, l'application garde
/// son vert : les verbes sont verts partout dans Pokou, et Spark n'est pas
/// une application à part.
const sparkAccent = Color(0xFFE11D48);

/// Spark — la coquille.
///
/// Tant qu'il n'y a pas de fiche, il n'y a rien à montrer : l'écran commence
/// donc par la créer. Poser des onglets vides autour d'un flux qui ne peut
/// pas exister ferait croire à une panne.
class SparkScreen extends ConsumerStatefulWidget {
  const SparkScreen({super.key});

  @override
  ConsumerState<SparkScreen> createState() => _SparkScreenState();
}

class _SparkScreenState extends ConsumerState<SparkScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(sparkProfileProvider);

    return profileAsync.when(
      loading: () => const ModuleScaffold(
        title: 'Spark',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ModuleScaffold(
        title: 'Spark',
        child: ModuleEmptyState(
          icon: Icons.cloud_off,
          title: L.of(context).sparkUnavailable,
          message: L.of(context).streakCheckConnection,
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return const SparkOnboardingView();
        }
        return ModuleScaffold(
          title: 'Spark',
          subtitle: L.of(context).sparkTodaysDate,
          child: Column(
            children: [
              const SizedBox(height: 4),
              ModuleSegmented(
                labels: [
                  L.of(context).sparkTabDiscover,
                  L.of(context).sparkTabMatches,
                  L.of(context).sparkTabOutings,
                  L.of(context).sparkTabMe,
                ],
                index: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: switch (_tab) {
                  0 => const SparkFeedView(),
                  1 => const SparkMatchesView(),
                  2 => const SparkDatesView(),
                  _ => SparkMeView(profile: profile),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
