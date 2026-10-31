import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class DeviceContactEntry {
  const DeviceContactEntry({required this.phone, required this.name});

  final String phone;
  final String name;
}

/// Reads the device address book and normalizes each number to E.164,
/// using the signed-in user's own number to guess the default region for
/// numbers stored in local format (no country code) — the same approach
/// WhatsApp/Telegram use. Numbers that still can't be parsed are dropped
/// rather than sent malformed; the backend would reject them anyway.
class DeviceContactsService {
  Future<bool> hasPermission() =>
      FlutterContacts.requestPermission(readonly: true);

  Future<List<DeviceContactEntry>> readAll({
    required String myPhoneE164,
  }) async {
    IsoCode? myIsoCode;
    try {
      myIsoCode = PhoneNumber.parse(myPhoneE164).isoCode;
    } catch (_) {
      myIsoCode = null;
    }

    // La lecture du répertoire passe par le canal de plateforme : elle doit
    // rester ici.
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    // La NORMALISATION, elle, part dans un autre isolat.
    //
    // C'est du Dart pur, mais `PhoneNumber.parse` coûte cher et tournait une
    // fois par numéro, sur le fil d'affichage. Avec un répertoire de
    // plusieurs milliers d'entrées — le cas des commerçants, c'est-à-dire
    // exactement notre public — l'écran « Nouvelle discussion » se figeait
    // le temps de tout analyser. Rien de tout cela ne touche à l'interface :
    // ça n'a aucune raison de bloquer une image.
    final raw = <({String name, List<String> numbers})>[
      for (final contact in deviceContacts)
        if (contact.displayName.trim().isNotEmpty)
          (
            name: contact.displayName.trim(),
            numbers: [
              for (final phone in contact.phones)
                if (phone.number.trim().isNotEmpty) phone.number.trim(),
            ],
          ),
    ];

    return compute(_normalize, (entries: raw, isoCode: myIsoCode));
  }
}

/// Exécuté dans un isolat — ne doit toucher ni au contexte, ni aux plugins.
List<DeviceContactEntry> _normalize(
  ({List<({String name, List<String> numbers})> entries, IsoCode? isoCode})
  input,
) {
  final normalized = <DeviceContactEntry>[];
  for (final contact in input.entries) {
    for (final number in contact.numbers) {
      final phone = normalizeDevicePhone(number, input.isoCode);
      if (phone != null) {
        normalized.add(DeviceContactEntry(phone: phone, name: contact.name));
      }
    }
  }
  return normalized;
}

/// Un numéro du répertoire en E.164, ou `null` s'il ne désigne aucune ligne
/// plausible.
///
/// Ici, les numéros s'enregistrent comme on les dicte : sans indicatif
/// (`90 12 34 56`), avec l'indicatif mais sans `+` (`228 90…`, `229 01…`
/// pour un contact du Bénin), avec un `0` de tête hérité d'autres pays.
/// La lecture « numéro local du pays de l'utilisateur » couvre le premier
/// cas ; les deux autres en donnaient une version FAUSSE (`+228 229…`),
/// envoyée telle quelle et donc jamais retrouvée — le contact restait
/// invisible sans que rien ne le dise.
///
/// On essaie donc plusieurs lectures et on garde la première VALIDE pour le
/// plan de numérotation de son pays. Aucune ne l'est : on retombe sur la
/// lecture locale, comme avant — une tranche de numéros ouverte après la
/// publication de la bibliothèque serait sinon écartée à tort.
@visibleForTesting
String? normalizeDevicePhone(String raw, IsoCode? myIsoCode) {
  final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;
  final bare = digits.replaceAll('+', '');
  final candidates = <PhoneNumber Function()>[
    () => PhoneNumber.parse(raw, callerCountry: myIsoCode),
    if (!digits.startsWith('+')) ...[
      // `229 01 97…` : l'indicatif sans le `+`.
      () => PhoneNumber.parse('+$bare'),
      // `0 90 12…` : un zéro de tête que le plan local ne connaît pas.
      if (bare.startsWith('0') && !bare.startsWith('00'))
        () => PhoneNumber.parse(bare.substring(1), callerCountry: myIsoCode),
    ],
  ];
  String? fallback;
  for (final candidate in candidates) {
    try {
      final parsed = candidate();
      if (parsed.isValid()) return parsed.international;
      fallback ??= parsed.international;
    } catch (_) {
      // Lecture suivante.
    }
  }
  // Le serveur exige au moins 7 chiffres après l'indicatif.
  if (fallback == null || fallback.length < 9) return null;
  return fallback;
}
