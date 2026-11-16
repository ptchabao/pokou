import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../providers.dart';

/// Ce que Pokou ouvre dans le pays de la personne connectée (NAV-01).
///
/// La décision vient du serveur (`/config/country`) : chaque module, Kory et
/// HONAM compris, s'ouvre pays par pays depuis la console. Un pays sans
/// module de service se présente en Lot 1 (messagerie seule).
class CountryConfig {
  const CountryConfig({
    required this.country,
    required this.modules,
    this.currency = 'XOF',
    this.vatRate = 0,
    this.deliveryPrice,
    this.emergencyNumbers = const {},
    this.koryPlusFeeHt,
  });

  /// Kory Plus : les frais d'ouverture d'une tontine, HT, par membre
  /// (`null` si le serveur ne les a pas donnés).
  final int? koryPlusFeeHt;

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
    koryPlusFeeHt: json['kory_plus_fee_ht'] as int?,
    emergencyNumbers: {
      for (final e in ((json['emergency_numbers'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    },
  );

  /// Ce qu'on suppose quand le serveur ne répond pas : les mêmes valeurs par
  /// défaut que le serveur (backend/app/core/countries.py). La même
  /// application partout : un autre indicatif a aussi Kory, Honam et Assimé,
  /// comme un pays que la console n'a pas encore configuré.
  factory CountryConfig.guessFromPhone(String? phone) {
    if (phone != null && phone.startsWith('+228')) {
      return const CountryConfig(
        country: 'TG',
        modules: {
          'discussions',
          'kory',
          'kory_plus',
          'honam',
          'assime',
          'certified',
        },
        vatRate: 0.18,
        deliveryPrice: 1000,
      );
    }
    if (phone != null && phone.startsWith('+225')) {
      return const CountryConfig(
        country: 'CI',
        modules: {'discussions', 'kory', 'kory_plus', 'honam', 'assime'},
        vatRate: 0.18,
        deliveryPrice: 1500,
      );
    }
    return const CountryConfig(
      country: null,
      modules: {'discussions', 'kory', 'kory_plus', 'honam', 'assime'},
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
