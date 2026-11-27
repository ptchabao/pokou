// Les tests de la spécification exécutable Pokoumoji V1.3
// (03_Integration/reference/pokoumoji_reference.test.mjs), transposés.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/pokoumoji/data/pokoumoji_pack_verifier.dart';
import 'package:pokou/features/pokoumoji/data/pokoumoji_runtime.dart';
import 'package:pokou/features/pokoumoji/domain/pokoumoji.dart';
import 'package:pokou/features/pokoumoji/presentation/pokoumoji_text_controller.dart';

PokoumojiCatalogue _load({required bool dev}) =>
    PokoumojiRuntime.parseCatalogue(
      catalogueJson: File('assets/pokoumoji/catalogue.json').readAsStringSync(),
      aliasesJson: File('assets/pokoumoji/aliases.json').readAsStringSync(),
      collectionsJson: File(
        'assets/pokoumoji/collections.json',
      ).readAsStringSync(),
      includeUnapproved: dev,
    );

List<String> ids(List<PokoumojiEntry> l) => [for (final e in l) e.id];

void main() {
  final dev = _load(dev: true);
  final prod = _load(dev: false);
  final example = {
    'schema_version': 1,
    'type': 'rich_text',
    'segments': [
      {'type': 'text', 'text': 'Tu me fais trop rire '},
      {'type': 'emoji', 'id': 'kimia_mdr', 'fallback': '😂'},
      {'type': 'text', 'text': ' !'},
    ],
  };
  final sticker = {
    'schema_version': 1,
    'type': 'sticker',
    'asset_id': 'expressions_on_est_ensemble_komi',
    'fallback': '[On est ensemble !]',
  };

  test('catalogue V1.3 complet', () {
    expect(dev.size, 1163);
  });

  test('normalisation : accents, œ, apostrophes', () {
    expect(pokoumojiNormalize('Côte d’Ivoire'), 'cote divoire');
    expect(pokoumojiNormalize("CÔTE D'IVOIRE"), 'cote divoire');
    expect(pokoumojiNormalize('Cœur brisé'), 'coeur brise');
  });

  test('T05 — « mdr » renvoie les quatre personnages et Original', () {
    final r = ids(dev.search('mdr', type: PokoumojiType.inlineEmoji));
    for (final c in [
      'kimia',
      'komi',
      'nana_ohene',
      'nana_ohemaa',
      'original',
    ]) {
      expect(r, contains('${c}_mdr'));
    }
  });

  test('T06 — recherche insensible aux accents', () {
    expect(ids(dev.search('colere')), ids(dev.search('Colère')));
    expect(ids(dev.search('reflexion')), contains('komi_reflexion'));
  });

  test('T18 — synonymes : « rire » trouve MDR et PTDR', () {
    final r = ids(dev.search('rire', character: 'kimia'));
    expect(r, containsAll(['kimia_mdr', 'kimia_ptdr']));
  });

  test('T19 — drapeaux en français, sans accents et par code ISO', () {
    expect(dev.search('cote divoire').first.id, 'flag_ci');
    expect(dev.search('Côte d’Ivoire').first.id, 'flag_ci');
    expect(ids(dev.search('ci', category: 'flags')), contains('flag_ci'));
    expect(dev.search('Togo').first.id, 'flag_tg');
  });

  test('T16 — catalogue non approuvé masqué en production', () {
    expect(prod.search('mdr'), isEmpty);
    expect(prod.hasVisible, isFalse);
  });

  test('T17 — anciens identifiants résolus vers le nouvel identifiant', () {
    expect(dev.resolve('kimia_clin_dil')!.id, 'kimia_clin_doeil');
    expect(dev.resolve('symboles_cur_rouge')!.id, 'symboles_coeur_rouge');
    expect(
      dev.resolve('expressions_na_lingui_yo')!.id,
      'expressions_nalingi_yo',
    );
    expect(
      dev.resolve('expressions_mama_n_a_ngai_kimia')!.labelFr,
      'mama na ngaï (Kimia)',
    );
    expect(dev.resolve('expressions_moni_fere')!.labelFr, 'mo nífẹ̀ẹ́ rẹ');
    expect(
      dev.resolve('expressions_dama_na_lop_komi')!.id,
      'expressions_dama_la_begg_komi',
    );
  });

  test("T36 — « je t'aime » et graphies sans signes diacritiques", () {
    final r = ids(dev.search("je t'aime", type: PokoumojiType.sticker));
    for (final id in [
      'expressions_nalingi_yo',
      'expressions_moulonwo',
      'expressions_mo_nifee_re',
      'expressions_dama_la_begg',
      'expressions_nakupenda',
    ]) {
      expect(r, contains(id));
    }
    expect(
      dev.search('mo nifee re', type: PokoumojiType.sticker).first.id,
      'expressions_mo_nifee_re',
    );
    expect(ids(dev.search('melɔ̃ wò')), contains('expressions_moulonwo'));
  });

  test('T33 — la recherche ne montre que les entrées de base', () {
    expect(ids(dev.search('salut', category: 'gestes')), ['gestes_salut']);
    expect(
      dev.search('salut', category: 'gestes', includeVariants: true).length,
      5,
    );
  });

  test('T31 — carnation : 5 teintes, préférence locale, brun chaud', () {
    expect(dev.variantsOf('gestes_salut').length, 5);
    expect(dev.applyPreferences('gestes_salut')!.id, 'gestes_salut');
    expect(
      dev
          .applyPreferences(
            'gestes_salut',
            const PokoumojiPrefs(skinTone: '1'),
          )!
          .id,
      'gestes_salut_t1',
    );
    expect(dev.resolve('gestes_salut_t1')!.fallback, '👋🏻');
  });

  test('T32 — métiers : 10 variantes, aucun genre imposé', () {
    expect(dev.variantsOf('metiers_medecin').length, 10);
    expect(
      dev
          .applyPreferences(
            'metiers_medecin',
            const PokoumojiPrefs(skinTone: '1'),
          )!
          .id,
      'metiers_medecin_homme_t1',
    );
    expect(
      dev
          .applyPreferences(
            'metiers_medecin',
            const PokoumojiPrefs(
              skinTone: '3',
              genderByBase: {'metiers_medecin': 'femme'},
            ),
          )!
          .id,
      'metiers_medecin_femme_t3',
    );
    expect(dev.applyPreferences('metiers_infirmier')!.gender, 'femme');
    expect(
      dev
          .applyPreferences('kimia_joie', const PokoumojiPrefs(skinTone: '1'))!
          .id,
      'kimia_joie',
    );
  });

  test('T10 — identifiant inconnu : aucun plantage, fallback', () {
    final msg = {
      'schema_version': 1,
      'type': 'rich_text',
      'segments': [
        {'type': 'emoji', 'id': 'inconnu_xyz', 'fallback': '🙂'},
      ],
    };
    final plan = pokoumojiRenderPlan(msg, dev);
    expect(plan.single, isA<PokoumojiFallbackPiece>());
    expect((plan.single as PokoumojiFallbackPiece).text, '🙂');
    expect(dev.resolve('../etc/passwd'), isNull);
  });

  test('T03/T11 — texte de repli', () {
    expect(pokoumojiPlainText(example), 'Tu me fais trop rire 😂 !');
    expect(pokoumojiPlainText(sticker), '[On est ensemble !]');
  });

  test('validation : exemples valides', () {
    expect(validatePokoumojiMessage(example, catalogue: dev), isEmpty);
    expect(validatePokoumojiMessage(sticker, catalogue: dev), isEmpty);
  });

  test('validation : limites et propriétés interdites', () {
    final many = pokoumojiRichText([
      for (var i = 0; i < 51; i++)
        {'type': 'emoji', 'id': 'kimia_joie', 'fallback': '😀'},
    ]);
    expect(validatePokoumojiMessage(many), isNotEmpty);
    final url = pokoumojiRichText([
      {
        'type': 'emoji',
        'id': 'kimia_joie',
        'fallback': '😀',
        'url': 'https://x',
      },
    ]);
    expect(validatePokoumojiMessage(url), isNotEmpty);
    final html = pokoumojiRichText([
      {'type': 'html', 'html': '<b>x</b>'},
    ]);
    expect(validatePokoumojiMessage(html), isNotEmpty);
    final long = pokoumojiRichText([
      {'type': 'text', 'text': 'a' * 4001},
    ]);
    expect(validatePokoumojiMessage(long), isNotEmpty);
  });

  test('T20 — sticker jamais inline, emoji inline jamais sticker', () {
    final bad1 = pokoumojiRichText([
      {'type': 'emoji', 'id': 'expressions_yako_komi', 'fallback': '[Yako]'},
    ]);
    expect(validatePokoumojiMessage(bad1, catalogue: dev), isNotEmpty);
    final bad2 = {
      'schema_version': 1,
      'type': 'sticker',
      'asset_id': 'kimia_joie',
      'fallback': '😀',
    };
    expect(validatePokoumojiMessage(bad2, catalogue: dev), isNotEmpty);
  });

  test('T20/T35 — chaque expression existe pour les quatre personnages', () {
    final bulles = dev.entries
        .where((e) => e.category == 'expressions' && e.character.isEmpty)
        .toList();
    expect(bulles.length, 24);
    for (final b in bulles) {
      for (final c in ['kimia', 'komi', 'nana_ohene', 'nana_ohemaa']) {
        expect(dev.resolve('${b.id}_$c'), isNotNull, reason: '${b.id}_$c');
      }
    }
  });

  test('T24 — choix de la taille', () {
    expect(pokoumojiPickSize(PokoumojiSizeContext.inline, 2), 64);
    expect(pokoumojiPickSize(PokoumojiSizeContext.grid, 2), 128);
    expect(pokoumojiPickSize(PokoumojiSizeContext.single, 2), 256);
    expect(
      pokoumojiPackPath(dev.resolve('kimia_joie')!, 128),
      '128/assets/kimia/kimia_joie.webp',
    );
  });

  group('pack signé', () {
    final dir = Directory('../backend/app/data/pokoumoji_packs/dev');
    final manifestBytes = File('${dir.path}/manifest.json').readAsBytesSync();
    final sig = File('${dir.path}/manifest.sig').readAsStringSync();

    test('pack de développement : signature et empreintes valides', () async {
      final check = await PokoumojiPackVerifier.checkManifest(
        manifestBytes: manifestBytes,
        signatureBase64: sig,
        publicKeys: [PokoumojiKeys.development],
        allowPlaceholder: true,
      );
      expect(check, isA<ManifestAccepted>());
      final m = (check as ManifestAccepted).manifest;
      expect(m.files.length, dev.size * 3);
      var bad = 0;
      for (final f in m.files.values) {
        final data = File('${dir.path}/${f.path}').readAsBytesSync();
        if (PokoumojiPackVerifier.checkFile(f, data) != null) bad++;
      }
      expect(bad, 0);
    });

    test('T25 — placeholder refusé hors build de développement', () async {
      final check = await PokoumojiPackVerifier.checkManifest(
        manifestBytes: manifestBytes,
        signatureBase64: sig,
        publicKeys: [PokoumojiKeys.development],
        allowPlaceholder: false,
      );
      expect(check, isA<ManifestRefused>());
    });

    test('clé de production : le pack de développement ne passe pas', () async {
      final check = await PokoumojiPackVerifier.checkManifest(
        manifestBytes: manifestBytes,
        signatureBase64: sig,
        publicKeys: [PokoumojiKeys.production],
        allowPlaceholder: true,
      );
      expect((check as ManifestRefused).reason, contains('signature'));
    });

    test(
      'T09/T22/T23 — fichier altéré rejeté, manifeste altéré refusé',
      () async {
        final check =
            await PokoumojiPackVerifier.checkManifest(
                  manifestBytes: manifestBytes,
                  signatureBase64: sig,
                  publicKeys: [PokoumojiKeys.development],
                  allowPlaceholder: true,
                )
                as ManifestAccepted;
        final f = check.manifest.files['128/assets/kimia/kimia_joie.webp']!;
        expect(
          PokoumojiPackVerifier.checkFile(
            f,
            Uint8List.fromList(utf8.encode('RIFF....WEBPVP8 corrompu')),
          ),
          isNotNull,
        );
        final altered = Uint8List.fromList(
          utf8.encode(
            utf8
                .decode(manifestBytes)
                .replaceFirst('"placeholder"', '"production"'),
          ),
        );
        final refused = await PokoumojiPackVerifier.checkManifest(
          manifestBytes: altered,
          signatureBase64: sig,
          publicKeys: [PokoumojiKeys.development, PokoumojiKeys.production],
          allowPlaceholder: false,
        );
        expect((refused as ManifestRefused).reason, contains('signature'));
      },
    );
  });

  group('champ de saisie', () {
    test('un caractère par emoji, encodé en segments à l’envoi', () {
      final joie = dev.resolve('kimia_joie')!;
      final mdr = dev.resolve('komi_mdr')!;
      final draft =
          'Salut ${PokoumojiComposer.charFor(dev, joie)}'
          '${PokoumojiComposer.charFor(dev, mdr)} !';
      expect(draft.length, 'Salut  !'.length + 2);
      final rich = PokoumojiComposer.encode(draft, dev)!;
      expect(rich.errors, isEmpty);
      expect(rich.message['segments'], [
        {'type': 'text', 'text': 'Salut '},
        {'type': 'emoji', 'id': 'kimia_joie', 'fallback': joie.fallback},
        {'type': 'emoji', 'id': 'komi_mdr', 'fallback': mdr.fallback},
        {'type': 'text', 'text': ' !'},
      ]);
      expect(rich.plainText, 'Salut ${joie.fallback}${mdr.fallback} !');
      expect(PokoumojiComposer.draftOf(rich.message, dev), draft);
    });

    test('un texte sans Pokoumoji reste un texte ordinaire', () {
      expect(PokoumojiComposer.encode('Bonjour 😀', dev), isNull);
    });

    test('un sticker ne se pose jamais dans le champ', () {
      final s = dev.resolve('expressions_yako')!;
      final ch = PokoumojiComposer.charFor(dev, s);
      expect(PokoumojiComposer.encode('a$ch', dev), isNull);
    });
  });

  group('transport', () {
    test('seule une charge utile valide est lue', () {
      expect(pokoumojiOf({pokoumojiPayloadKey: example}), example);
      expect(
        pokoumojiOf({
          pokoumojiPayloadKey: {'type': 'html'},
        }),
        isNull,
      );
      expect(pokoumojiOf(null), isNull);
      expect(pokoumojiOf({'latitude': 1}), isNull);
    });
  });
}
