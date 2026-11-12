import 'package:url_launcher/url_launcher.dart';

import '../data/kory_model.dart';

/// Le wallet d'un collecteur, tel qu'on le reconnaît à son numéro.
///
/// Pokou ne parle à aucun opérateur : il n'y a ni solde ni transfert ici.
/// On devine seulement l'opérateur par le préfixe du numéro, pour afficher
/// « Flooz · 96 •• •• 12 » et proposer son code USSD — que l'utilisateur
/// compose lui-même, sur son téléphone, depuis son propre wallet.
class KoryWallet {
  const KoryWallet._({
    required this.phone,
    required this.masked,
    required this.last2,
    this.operator,
    this.ussd,
  });

  /// Le numéro complet, tel que le serveur le donne aux participants.
  final String phone;

  /// « 96 •• •• 12 » : assez pour reconnaître le destinataire.
  final String masked;

  /// « •• 12 »
  final String last2;

  /// Le nom commercial du wallet (« Flooz », « Mixx by Yas »…), s'il est
  /// reconnu. Un nom de marque : il ne se traduit pas.
  final String? operator;

  /// Le code du menu de l'opérateur (« *155# »), s'il est connu.
  final String? ussd;

  static KoryWallet? of(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    var local = digits;
    String? country;
    for (final code in const ['+228', '+225', '+229']) {
      if (digits.startsWith(code)) {
        country = code;
        local = digits.substring(code.length);
      }
    }
    final prefix = local.length >= 2 ? local.substring(0, 2) : '';
    String? operator;
    String? ussd;
    if (country == '+228') {
      // Togo : Moov Africa (Flooz) et Togocom (Mixx by Yas).
      if (const ['96', '97', '98', '99', '79', '78'].contains(prefix)) {
        operator = 'Flooz';
        ussd = '*155#';
      } else if (const [
        '90',
        '91',
        '92',
        '93',
        '70',
        '71',
        '72',
      ].contains(prefix)) {
        operator = 'Mixx by Yas';
        ussd = '*145#';
      }
    } else if (country == '+225') {
      // Côte d'Ivoire : 07 Orange, 05 MTN, 01 Moov.
      switch (prefix) {
        case '07':
          operator = 'Orange Money';
          ussd = '#144#';
        case '05':
          operator = 'MTN MoMo';
          ussd = '*133#';
        case '01':
          operator = 'Moov Money';
          ussd = '*155#';
      }
    }
    final tail = local.length >= 2 ? local.substring(local.length - 2) : local;
    // Espaces insécables : le numéro masqué ne se coupe jamais en deux.
    final masked = local.length >= 6
        ? '$prefix\u00A0••\u00A0••\u00A0$tail'
        : '••\u00A0$tail';
    return KoryWallet._(
      phone: digits,
      masked: masked,
      last2: '••\u00A0$tail',
      operator: operator,
      ussd: ussd,
    );
  }

  /// « Flooz · 96 •• •• 12 », ou le seul numéro masqué.
  String get label => operator == null ? masked : '$operator · $masked';

  /// « Flooz •• 12 »
  String get shortLabel => operator == null ? last2 : '$operator\u00A0$last2';

  /// Ouvre le composeur sur le code USSD de l'opérateur. Rien n'est envoyé
  /// par Pokou : c'est l'utilisateur qui valide sur son téléphone.
  Future<bool> dialUssd() async {
    final code = ussd;
    if (code == null) return false;
    return launchUrl(Uri(scheme: 'tel', path: code));
  }
}

/// La référence à indiquer dans le transfert, qui aide le collecteur à
/// rapprocher l'envoi de la collecte (« KRY-4F7QK2MD »).
String koryReference(KoryPot pot) =>
    'KRY-${pot.joinCode.isEmpty ? pot.id : pot.joinCode}';
