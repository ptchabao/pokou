import 'package:flutter/services.dart';

/// Le pays de la carte SIM, quand l'appareil veut bien le dire.
///
/// La source la plus fiable pour préremplir un indicatif, et de loin : elle
/// désigne le pays de l'ABONNEMENT, donc celui du numéro que l'utilisateur
/// s'apprête à saisir. La locale, elle, désigne la langue de l'interface —
/// un téléphone réglé en `fr_FR` et utilisé à Lomé proposait la France à
/// chaque connexion.
///
/// Aucune permission : `getSimCountryIso()` ne révèle ni le numéro ni
/// l'identité de l'abonné, seulement le pays de l'opérateur. C'est ce qui
/// rend cette source acceptable là où demander la localisation, pour le même
/// résultat, ne le serait pas.
///
/// Renvoie `null` sur iOS, sur un émulateur, sur un appareil sans module
/// radio, ou quand le constructeur restreint l'accès — l'appelant retombe
/// alors sur la locale puis sur le Togo (voir phone_country.dart).
class SimCountry {
  const SimCountry({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.pokou.pokou/sim');

  final MethodChannel _channel;

  Future<String?> isoCode() async {
    try {
      final value = await _channel.invokeMethod<String>('countryIso');
      final iso = value?.trim();
      // Deux lettres exactement : un code vide ou tronqué ne doit pas
      // écarter la locale, qui reste un indice valable.
      return iso != null && iso.length == 2 ? iso.toUpperCase() : null;
    } on MissingPluginException {
      // Plateforme sans ce canal (iOS, tests widget) : ce n'est pas une
      // erreur, simplement une source indisponible.
      return null;
    } catch (_) {
      return null;
    }
  }
}
