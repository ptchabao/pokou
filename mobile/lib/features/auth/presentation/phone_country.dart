import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import 'country_names.dart';

/// Un pays au sens « indicatif téléphonique ».
///
/// Les données viennent de `phone_numbers_parser`, déjà utilisé par
/// l'application pour lire le carnet d'adresses : indicatif, exemple de
/// numéro mobile et code ISO de CHAQUE pays y sont, tenus à jour avec la
/// base libphonenumber. Écrire cette liste à la main aurait garanti des
/// indicatifs faux pour les pays qu'on connaît mal — c'est-à-dire pour
/// exactement les utilisateurs que ce sélecteur doit servir.
class PhoneCountry {
  const PhoneCountry({
    required this.isoCode,
    required this.dialCode,
    required this.exampleNsn,
  });

  final IsoCode isoCode;

  /// Sans le « + » (« 228 », « 225 », « 33 »).
  final String dialCode;

  /// Exemple de numéro mobile local, utilisé comme indication de saisie :
  /// « 90 12 34 56 » au Togo, « 06 12 34 56 78 » en France. Un exemple juste
  /// pour le pays choisi vaut mieux qu'un exemple togolais montré à tout le
  /// monde.
  final String exampleNsn;

  /// Drapeau calculé depuis les deux lettres du code ISO (indicateurs
  /// régionaux Unicode) — pas de table de 250 emojis à maintenir.
  String get flag {
    const base = 0x1F1E6; // 🇦
    final letters = isoCode.name.toUpperCase();
    if (letters.length != 2) return '🏳';
    return String.fromCharCodes([
      base + letters.codeUnitAt(0) - 0x41,
      base + letters.codeUnitAt(1) - 0x41,
    ]);
  }

  /// Nom traduit quand on le connaît, code ISO sinon. Le paquet ne fournit
  /// pas de noms de pays et `intl` non plus : plutôt qu'une liste de 250
  /// traductions dont beaucoup seraient approximatives, les pays desservis
  /// par Mahizu et les principales destinations de la diaspora sont nommés
  /// (voir country_names.dart), le reste reste identifiable par son drapeau,
  /// son code et son indicatif.
  String nameIn(String languageCode) =>
      countryNameFor(languageCode, isoCode) ?? isoCode.name;

  /// Ce sur quoi porte la recherche : nom, code ISO et indicatif. Quelqu'un
  /// qui ne connaît pas le nom de son pays dans la langue de l'app le trouve
  /// par son indicatif.
  String searchIndexIn(String languageCode) =>
      '${nameIn(languageCode)} ${isoCode.name} $dialCode'.toLowerCase();
}

/// Pays classés par nom, ceux qui ont un nom connu d'abord — un « ZW » perdu
/// entre deux noms complets rend la liste illisible. L'ordre dépend donc de
/// la langue, d'où le paramètre.
List<PhoneCountry> allPhoneCountries(String languageCode) {
  final countries = <PhoneCountry>[];
  for (final entry in metadataByIsoCode.entries) {
    final examples = metadataExamplesByIsoCode[entry.key];
    countries.add(
      PhoneCountry(
        isoCode: entry.key,
        dialCode: entry.value.countryCode,
        exampleNsn: _formatExample(entry.key, examples?.mobile),
      ),
    );
  }
  final named = countryNames[languageCode] ?? countryNames['fr']!;
  countries.sort((left, right) {
    final leftNamed = named.containsKey(left.isoCode);
    final rightNamed = named.containsKey(right.isoCode);
    if (leftNamed != rightNamed) return leftNamed ? -1 : 1;
    return left.nameIn(languageCode).compareTo(right.nameIn(languageCode));
  });
  return countries;
}

String _formatExample(IsoCode isoCode, String? mobile) {
  if (mobile == null || mobile.isEmpty) return '';
  try {
    return PhoneNumber(isoCode: isoCode, nsn: mobile).formatNsn();
  } catch (_) {
    // Un exemple qui ne se formate pas reste un exemple : on le montre brut
    // plutôt que de laisser le champ sans indication.
    return mobile;
  }
}

/// Le pays correspondant à un code ISO, `null` si le paquet ne le connaît
/// pas. Public : l'écran de saisie s'en sert quand un numéro collé au format
/// international désigne un autre pays que celui sélectionné.
PhoneCountry? phoneCountryFor(IsoCode isoCode) {
  final metadata = metadataByIsoCode[isoCode];
  if (metadata == null) return null;
  return PhoneCountry(
    isoCode: isoCode,
    dialCode: metadata.countryCode,
    exampleNsn: _formatExample(
      isoCode,
      metadataExamplesByIsoCode[isoCode]?.mobile,
    ),
  );
}

/// Pays proposé par défaut, deviné dans cet ordre :
///
/// 1. le pays du dernier numéro VÉRIFIÉ sur cet appareil — il vient d'un
///    numéro que son propriétaire a confirmé par SMS, donc il ne se trompe
///    pas. Absent au premier lancement, évidemment ;
/// 2. le pays de la CARTE SIM, lu sans aucune permission (voir
///    data/sim_country.dart). C'est la bonne réponse dès la première
///    ouverture, et celle qui manquait ;
/// 3. la région de la locale de l'appareil (« fr_CI » → Côte d'Ivoire) —
///    disponible hors ligne, mais souvent fausse : un téléphone réglé en
///    `fr_FR` et utilisé à Lomé désigne la France ;
/// 4. le Togo, marché d'origine, si rien d'autre ne dit quoi que ce soit.
///
/// Ce n'est qu'une PROPOSITION : le sélecteur reste ouvert, et deviner mal
/// coûte un tap.
PhoneCountry detectPhoneCountry({String? rememberedIso, String? simIso}) {
  for (final candidate in [rememberedIso, simIso]) {
    if (candidate == null) continue;
    final iso = IsoCode.values.asNameMap()[candidate.toUpperCase()];
    final country = iso == null ? null : phoneCountryFor(iso);
    if (country != null) return country;
  }
  for (final locale in ui.PlatformDispatcher.instance.locales) {
    final region = locale.countryCode;
    if (region == null || region.length != 2) continue;
    final candidate = IsoCode.values.asNameMap()[region.toUpperCase()];
    if (candidate == null) continue;
    final country = phoneCountryFor(candidate);
    if (country != null) return country;
  }
  return phoneCountryFor(IsoCode.TG)!;
}

/// Feuille de sélection avec recherche. Renvoie `null` si on la referme sans
/// choisir — l'appelant garde alors le pays courant.
Future<PhoneCountry?> showPhoneCountryPicker(
  BuildContext context, {
  required PhoneCountry current,
}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) => _CountryPickerSheet(current: current),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.current});

  final PhoneCountry current;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();

  /// La langue courante, relue une fois : elle décide du nom des pays et de
  /// leur ordre, donc la liste se reconstruit si elle change.
  String get _languageCode => Localizations.localeOf(context).languageCode;

  late final List<PhoneCountry> _all = allPhoneCountries(_languageCode);
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PhoneCountry> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _all;
    return _all
        .where(
          (country) => country.searchIndexIn(_languageCode).contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        // Hauteur bornée : la liste fait 250 pays, une feuille qui s'ajuste à
        // son contenu occuperait tout l'écran et ferait disparaître le champ
        // de recherche sous le clavier.
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.of(context).countryDialCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: L.of(context).countrySearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        L.of(context).countryNoneFound,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final country = visible[index];
                        final selected =
                            country.isoCode == widget.current.isoCode;
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(country.nameIn(_languageCode)),
                          subtitle: Text(
                            country.isoCode.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: Text(
                            '+${country.dialCode}',
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.accentPrimaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
