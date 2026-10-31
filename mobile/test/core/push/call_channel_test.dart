import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/push/push_service.dart';

/// Le canal de notification des appels.
///
/// La sonnerie était jouée par Flutter, depuis `CallScreen` : elle ne
/// démarrait donc qu'après le réveil du moteur Dart, l'ouverture de
/// l'activité et la navigation. Sur un téléphone en veille, ce délai est
/// long et entièrement à la charge de l'application. Un son porté par le
/// CANAL est joué par le système à la publication de la notification, sans
/// que Flutter existe.
///
/// Ces tests portent sur ce qui peut se vérifier sans appareil : que le
/// fichier existe à l'endroit qu'Android ira chercher, et que l'identifiant
/// de canal a bien changé — sans quoi le nouveau son ne serait jamais
/// appliqué sur les téléphones déjà équipés.
void main() {
  test('la sonnerie est une ressource Android, pas seulement un asset', () {
    // `RawResourceAndroidNotificationSound('pokou_ringtone')` cherche
    // res/raw/pokou_ringtone.*. Un asset Flutter ne convient pas : le
    // système lit ce fichier sans passer par le moteur Dart.
    final raw = Directory('android/app/src/main/res/raw');

    expect(raw.existsSync(), isTrue, reason: 'res/raw doit exister');
    expect(
      raw.listSync().map((f) => f.uri.pathSegments.last),
      contains('pokou_ringtone.wav'),
    );
  });

  test('le nom de la ressource respecte les règles d\'Android', () {
    // Minuscules, chiffres et tirets bas uniquement : un nom invalide fait
    // échouer la compilation des ressources, pas l'exécution — donc tard.
    const nom = 'pokou_ringtone';

    expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(nom), isTrue);
  });

  test('l\'identifiant du canal a changé avec ses réglages', () {
    // Android FIGE les réglages d'un canal à sa création. Rappeler
    // `createNotificationChannel` avec le même identifiant ne change rien
    // sur un téléphone où l'application est déjà installée : le nouveau son
    // ne serait jamais entendu par ceux qui l'ont déjà.
    expect(callsChannelId, isNot('pokou_calls'));
  });

  test('l\'ancien canal est explicitement retiré', () {
    // Sans ménage, l'écran « Notifications » de Pokou finit par lister
    // « Appels », « Appels », « Appels »… sans dire lequel est actif.
    final source = File('lib/core/push/push_service.dart').readAsStringSync();

    expect(source, contains('deleteNotificationChannel'));
    expect(source, contains("'pokou_calls'"));
  });

  test('le canal d\'appel utilise le flux SONNERIE', () {
    // Et non le flux notification : c'est le flux sonnerie que porte le
    // volume de sonnerie du téléphone, et que « Ne pas déranger » traite
    // comme un appel.
    final source = File('lib/core/push/push_service.dart').readAsStringSync();

    expect(source, contains('AudioAttributesUsage.notificationRingtone'));
  });
}
