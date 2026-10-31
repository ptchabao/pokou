import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/data/product_model.dart';

/// Catégories, devises et formules réglées depuis l'administration.
///
/// Elles étaient écrites en dur dans l'application : ajouter une catégorie
/// demandait une publication Play Store, et la devise était un champ de
/// texte libre où « XOF », « FCFA » et « fcfa » cohabitaient sans jamais se
/// comparer.
///
/// Ce que ce fichier protège avant tout, c'est le REPLI. Le marché doit
/// rester utilisable hors ligne, pendant que la requête est en vol, et face
/// à un serveur trop ancien pour connaître cette route. Des filtres vides
/// seraient pires que des filtres figés : l'écran n'aurait plus rien à
/// montrer, et le formulaire d'annonce plus rien à proposer.
void main() {
  group('le repli', () {
    test('une réponse vide garde les listes historiques', () {
      final config = MarketplaceConfig.fromJson({
        'categories': <dynamic>[],
        'currencies': <dynamic>[],
        'verification_plans': <dynamic>[],
      });

      expect(
        config.categories.map((c) => c.slug),
        ['TELEPHONES', 'MODE', 'MAISON', 'SERVICES', 'AUTRE'],
      );
      expect(config.currencies.single.code, 'XOF');
      expect(config.verificationPlans.single.amount, 5000);
    });

    test('des clés absentes ne cassent rien', () {
      // Un serveur antérieur à cette fonctionnalité répond sans ces champs.
      final config = MarketplaceConfig.fromJson(const {});
      expect(config.categories, isNotEmpty);
      expect(config.currencies, isNotEmpty);
      expect(config.verificationPlans, isNotEmpty);
    });

    test('le tarif de repli est celui qui existe déjà', () {
      // 5 000 FCFA : `VERIFICATION_AMOUNT` côté serveur. Aucun tarif n'est
      // inventé par l'application.
      expect(MarketplaceConfig.fallback.defaultVerificationPlan.amount, 5000);
    });
  });

  group('ce que le serveur dicte', () {
    final config = MarketplaceConfig.fromJson(const {
      'categories': [
        {'slug': 'MOTOS', 'label': 'Motos'},
        {'slug': 'GROSSISTE', 'label': 'Grossistes'},
      ],
      'currencies': [
        {'code': 'XOF', 'label': 'FCFA', 'default': false},
        {'code': 'GHS', 'label': 'GH₵', 'default': true},
      ],
      'verification_plans': [
        {
          'code': 'ANNUAL',
          'label': '1 an',
          'description': 'Badge un an',
          'amount': 5000,
          'default': true,
        },
      ],
    });

    test('les filtres montrent « TOUT » puis les catégories du serveur', () {
      expect(config.filterSlugs, ['TOUT', 'MOTOS', 'GROSSISTE']);
    });

    test('le libellé vient de l\'admin, pas de l\'identifiant', () {
      // La barre affichait « TELEPHONES » en capitales parce qu'elle montrait
      // le code enregistré en base.
      expect(config.labelOf('MOTOS'), 'Motos');
    });

    test('une catégorie inconnue retombe sur son code', () {
      // Une annonce publiée sous une catégorie depuis retirée garde la
      // sienne : mieux vaut montrer le code que rien.
      expect(config.labelOf('ANCIENNE'), 'ANCIENNE');
    });

    test('la devise par défaut est celle que le serveur désigne', () {
      expect(config.defaultCurrency.code, 'GHS');
    });

    test('sans devise par défaut, la première fait l\'affaire', () {
      final sansDefaut = MarketplaceConfig.fromJson(const {
        'currencies': [
          {'code': 'XOF', 'label': 'FCFA'},
          {'code': 'GHS', 'label': 'GH₵'},
        ],
      });
      // Le formulaire d'annonce doit toujours pouvoir pré-remplir quelque
      // chose : un champ devise vide bloque la publication.
      expect(sansDefaut.defaultCurrency.code, 'XOF');
    });

    test('une formule porte son prix et sa description', () {
      final formule = config.defaultVerificationPlan;
      expect(formule.code, 'ANNUAL');
      expect(formule.amount, 5000);
      expect(formule.description, 'Badge un an');
    });
  });
}
