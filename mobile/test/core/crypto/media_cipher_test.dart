import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/crypto/call_keys.dart';
import 'package:pokou/core/crypto/media_cipher.dart';

/// Le chiffrement des pièces jointes : ce qui part du téléphone est un bloc
/// que seul le détenteur de la clé peut relire — et qu'on refuse s'il a été
/// touché en route.
void main() {
  final photo = utf8.encode('octets d\'une photo de la caisse');

  test('le bloc chiffré se relit avec sa clé, et ne contient pas le clair', () async {
    final sealed = await MediaCipher.encrypt(
      photo,
      mimeType: 'image/jpeg',
      filename: 'caisse.jpg',
      caption: 'fin de journée',
    );

    expect(utf8.decode(sealed.blob, allowMalformed: true), isNot(contains('caisse')));
    expect(sealed.blob.length, photo.length + 16, reason: 'chiffré + étiquette GCM');
    expect(await MediaCipher.decrypt(sealed.blob, sealed.key), photo);
  });

  test('un bloc altéré est refusé avant tout affichage', () async {
    final sealed = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    final tampered = List<int>.of(sealed.blob)..[3] ^= 0x01;

    await expectLater(
      MediaCipher.decrypt(tampered, sealed.key),
      throwsA(isA<MediaIntegrityException>()),
    );
  });

  test('la clé d\'un autre fichier n\'ouvre pas ce bloc', () async {
    final a = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    final b = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'b.jpg');

    await expectLater(
      MediaCipher.decrypt(a.blob, b.key),
      throwsA(isA<MediaIntegrityException>()),
    );
  });

  test('deux envois du même fichier ne produisent pas le même bloc', () async {
    final a = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    final b = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    expect(a.blob, isNot(b.blob));
  });

  test('la clé scellée transporte le nom, le type, la taille et la légende', () async {
    final sealed = await MediaCipher.encrypt(
      photo,
      mimeType: 'application/pdf',
      filename: 'facture.pdf',
      caption: 'à payer',
    );
    final reread = MediaKey.tryParse(sealed.key.seal())!;

    expect(reread.mimeType, 'application/pdf');
    expect(reread.filename, 'facture.pdf');
    expect(reread.size, photo.length);
    expect(reread.caption, 'à payer');
    expect(await MediaCipher.decrypt(sealed.blob, reread), photo);

    final meta = reread.toMeta(42);
    expect(meta.id, 42);
    expect(meta.originalFilename, 'facture.pdf');
  });

  test('un texte ordinaire n\'est jamais pris pour une clé', () {
    expect(MediaKey.tryParse('Bonjour'), isNull);
    expect(MediaKey.tryParse('{"a": 1}'), isNull);
    expect(MediaKey.tryParse('{"pokou": "pokou-media-v1", "k": "court"}'), isNull);
  });

  test('le trousseau de session retrouve la clé par identifiant de média', () async {
    final sealed = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    MediaKeyRing.remember(7, sealed.key);
    expect(MediaKeyRing.of(7), same(sealed.key));
    MediaKeyRing.clear();
    expect(MediaKeyRing.of(7), isNull);
  });

  group('clé d\'appel', () {
    test('se relit après scellement, pour celui à qui elle est destinée', () {
      final key = CallKey.generate();
      expect(CallKey.tryParse(key.seal(from: 1, to: 2), from: 1, to: 2)!.bytes, key.bytes);
    });

    test('une clé scellée pour un autre, ou par un autre, est refusée', () {
      final sealed = CallKey.generate().seal(from: 1, to: 2);
      expect(CallKey.tryParse(sealed, from: 3, to: 2), isNull,
          reason: 'resservie par un autre invitant');
      expect(CallKey.tryParse(sealed, from: 1, to: 4), isNull,
          reason: 'scellée pour quelqu\'un d\'autre');
    });

    test('deux appels n\'ont jamais la même clé', () {
      expect(CallKey.generate().bytes, isNot(CallKey.generate().bytes));
    });

    test('une clé de pièce jointe n\'est pas une clé d\'appel', () async {
      final sealed = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
      expect(CallKey.tryParse(sealed.key.seal(), from: 1, to: 2), isNull);
      expect(CallKey.tryParse('{"pokou": "pokou-call-v1", "k": "AAAA", "f": 1, "t": 2}', from: 1, to: 2), isNull);
    });
  });

  test('le trousseau garde la première clé connue pour un fichier', () async {
    final a = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'a.jpg');
    final b = await MediaCipher.encrypt(photo, mimeType: 'image/jpeg', filename: 'b.jpg');
    MediaKeyRing.remember(8, a.key);
    MediaKeyRing.remember(8, b.key);
    expect(MediaKeyRing.of(8), same(a.key), reason: 'une substitution ne passe pas');
    MediaKeyRing.clear();
  });
}
