import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers.dart';

/// Ce que Pokou ouvre dans le pays de la personne connectée (NAV-01).
///
/// La décision vient du serveur (`/config/country`) : ouvrir HONAM à Lomé
/// ou Kory à Abidjan ne demande pas de nouvelle version de l'application.
class CountryConfig {
  const CountryConfig({
    required this.country,
    required this.modules,
    this.currency = 'XOF',
    this.vatRate = 0,
    this.deliveryPrice,
    this.emergencyNumbers = const {},
  });

  final String? country;
  final Set<String> modules;
  final String currency;
  final double vatRate;
  final int? deliveryPrice;
  final Map<String, String> emergencyNumbers;

  bool has(String module) => modules.contains(module);

  factory CountryConfig.fromJson(Map<String, dynamic> json) => CountryConfig(
    country: json['country'] as String?,
    modules: {
      for (final m in (json['modules'] as List? ?? const [])) m as String,
    },
    currency: json['currency'] as String? ?? 'XOF',
    vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 0,
    deliveryPrice: json['delivery_price'] as int?,
    emergencyNumbers: {
      for (final e
          in ((json['emergency_numbers'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    },
  );

  /// Ce qu'on suppose quand le serveur ne répond pas : le même découpage
  /// que ses valeurs par défaut, déduit de l'indicatif. Sans ce repli, un
  /// démarrage hors ligne ferait disparaître l'onglet Kory, puis le ferait
  /// revenir à la reconnexion.
  factory CountryConfig.guessFromPhone(String? phone) {
    if (phone != null && phone.startsWith('+228')) {
      return const CountryConfig(
        country: 'TG',
        modules: {'discussions', 'kory', 'honam', 'certified'},
        vatRate: 0.18,
        deliveryPrice: 1000,
      );
    }
    if (phone != null && phone.startsWith('+225')) {
      return const CountryConfig(
        country: 'CI',
        modules: {'discussions', 'honam'},
        vatRate: 0.18,
        deliveryPrice: 1500,
      );
    }
    return const CountryConfig(
      country: null,
      modules: {'discussions', 'honam'},
    );
  }
}

final countryConfigProvider = FutureProvider<CountryConfig>((ref) async {
  final phone = ref.watch(
    authControllerProvider.select((state) => state.user?.phone),
  );
  try {
    final json = await ref.watch(apiClientProvider).get('/config/country');
    return CountryConfig.fromJson(json as Map<String, dynamic>);
  } catch (_) {
    return CountryConfig.guessFromPhone(phone);
  }
});

/// La configuration à afficher MAINTENANT, sans attendre : la dernière
/// connue, ou la déduction par l'indicatif pendant le premier chargement.
final currentCountryConfigProvider = Provider<CountryConfig>((ref) {
  final phone = ref.watch(
    authControllerProvider.select((state) => state.user?.phone),
  );
  return ref.watch(countryConfigProvider).valueOrNull ??
      CountryConfig.guessFromPhone(phone);
});
