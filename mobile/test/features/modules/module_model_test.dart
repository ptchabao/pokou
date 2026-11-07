import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/modules/data/module_model.dart';

/// Le modèle des modules.
///
/// Deux choses s'y cassent sans bruit : une icône résolue dynamiquement, qui
/// disparaît en release seulement, et une couleur mal décodée, qui donne du
/// noir au lieu d'une erreur.
void main() {
  group('Icônes', () {
    test('chaque module semé en base a son icône dans la table', () {
      // Le serveur envoie un NOM. La table qui le résout est explicite parce
      // qu'une icône construite dynamiquement — IconData(codePoint, …) — est
      // supprimée par l'élagage de Flutter en release : elle n'est citée
      // nulle part dans le code, donc son glyphe n'est pas conservé. Le
      // résultat est un carré vide, en production seulement.
      // La liste DOIT suivre le catalogue semé en migration. C'est ce test
      // qui l'impose : sans lui, ajouter un module en base donnerait une
      // icône générique en production, et rien ne le signalerait.
      const semees = [
        'emoji_events', 'card_giftcard', 'savings', 'workspace_premium',
        'help_center', 'local_fire_department', 'groups', 'rocket_launch',
      ];
      for (final nom in semees) {
        expect(
          moduleIcon(nom),
          isNot(Icons.extension),
          reason: "« $nom » retombe sur l'icône générique — ajoutez-la à la table",
        );
      }
    });

    test('une icône inconnue retombe sur le générique, sans planter', () {
      // Un module ajouté en base par l'équipe, dont l'icône n'est pas encore
      // dans cette version de l'application, doit rester utilisable.
      expect(moduleIcon('pas_encore_connue'), Icons.extension);
      expect(moduleIcon(null), Icons.extension);
    });
  });

  group('Couleurs', () {
    test('une couleur hexadécimale est lue, opaque', () {
      final color = moduleColor('#E0245E');
      expect(color.toARGB32(), 0xFFE0245E);
    });

    test('une valeur invalide retombe sur la terre cuite de marque', () {
      // Sans repli, une couleur illisible donnerait du NOIR — une carte noire
      // au milieu de la galerie, sans que rien n'indique pourquoi.
      for (final invalide in [null, '', '#ZZZZZZ', 'rouge']) {
        expect(moduleColor(invalide).toARGB32(), 0xFF7F3D1E);
      }
    });
  });

  group('Catalogue', () {
    Map<String, dynamic> module(String slug, {bool activated = false}) => {
          'slug': slug,
          'name': slug,
          'tagline': 'accroche',
          'description': 'description',
          'icon': 'favorite',
          'accent_color': '#E0245E',
          'category': 'SOCIAL',
          'is_recommended': false,
          'is_activated': activated,
          'user_count': 3,
        };

    test('les trois rayons sont lus séparément', () {
      final catalogue = ModuleCatalogue.fromJson({
        'mine': [module('a', activated: true)],
        'recommended': [module('b')],
        'popular': [module('c'), module('d')],
      });
      expect(catalogue.mine.single.slug, 'a');
      expect(catalogue.recommended.single.slug, 'b');
      expect(catalogue.popular.length, 2);
      expect(catalogue.isEmpty, isFalse);
    });

    test('un catalogue vide se reconnaît', () {
      // Le cas du tout premier lancement, et celui où l'équipe a tout fermé.
      // L'écran doit pouvoir le dire au lieu d'afficher trois titres de
      // section sans rien dessous.
      expect(
        ModuleCatalogue.fromJson({'mine': [], 'recommended': [], 'popular': []}).isEmpty,
        isTrue,
      );
      expect(ModuleCatalogue.fromJson(const {}).isEmpty, isTrue);
    });
  });
}
