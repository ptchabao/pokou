import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';

import '../../../core/providers.dart';
import '../data/module_model.dart';
import '../data/module_repository.dart';
import '../verses/verse_controller.dart';

final moduleRepositoryProvider = Provider<ModuleRepository>((ref) {
  return ModuleRepository(apiClient: ref.watch(apiClientProvider));
});

final moduleCatalogueProvider = FutureProvider.autoDispose<ModuleCatalogue>((
  ref,
) async {
  final catalogue = await ref.watch(moduleRepositoryProvider).catalogue();
  // Chaque lecture du catalogue — dont celle qui suit un interrupteur —
  // aligne les versets planifiés sur ce qui est activé.
  unawaited(
    ref
        .read(verseSchedulerProvider)
        .reconcile(activatedModuleSlugs(catalogue), ref.read(appL10nProvider)),
  );
  return catalogue;
});
