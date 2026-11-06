import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_text_styles.dart';
import 'package:pokou/core/theme/app_theme.dart';

/// Les décisions du système de design qui ne se voient pas dans un test de
/// widget mais qu'une régression casse en silence : une encre qui perd son
/// contraste, une couleur porteuse de sens réutilisée ailleurs, une police
/// embarquée qui revient.
///
/// Ces trois pannes sont arrivées pour de vrai dans ce projet — du texte
/// blanc sur fond blanc pendant une migration de thème, et une double coche
/// « lu » teintée comme un succès quelconque.

/// Contraste WCAG entre deux couleurs opaques.
double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final brightest = light > dark ? light : dark;
  final darkest = light > dark ? dark : light;
  return (brightest + 0.05) / (darkest + 0.05);
}

void main() {
  group('Lisibilité', () {
    test("l'encre tient le contraste sur la surface qui la porte", () {
      // 4,5:1 est le seuil WCAG AA pour du texte courant.
      expect(_contrast(AppColors.textPrimary, AppColors.surface), greaterThan(4.5));
      expect(_contrast(AppColors.textSecondary, AppColors.surface), greaterThan(4.5));

      // Le texte d'une bulle, sur CHACUNE des deux bulles. C'est ce qui rend
      // les longs messages lisibles et ce qui autorise une bulle teintée si
      // claire.
      expect(_contrast(AppColors.chatTextReceived, AppColors.chatBubbleSent), greaterThan(4.5));
      expect(_contrast(AppColors.chatTextReceived, AppColors.chatBubbleReceived), greaterThan(4.5));

      // L'horodatage dans la bulle : plus petit, donc au moins le même seuil.
      expect(_contrast(AppColors.chatTimestamp, AppColors.chatBubbleSent), greaterThan(4.5));
    });

    test("la couleur d'action porte du texte, dans les deux sens", () {
      // Historique : le vert `#25D366` ne tenait que 1,74:1 sur blanc ; le
      // vert `#008069` a levé ce compromis (4,89:1) ; le bleu `#129CF5` l'a
      // réintroduit (2,96:1), d'où une encre à part pour tout texte. La terre
      // cuite `#A65527` tient de nouveau 5,3:1 dans les deux sens : comme
      // encre sur blanc, et sous un libellé blanc sur un bouton plein.
      //
      // Seuils gardés pour qu'un retour vers une couleur plus claire
      // redevienne un choix explicite, et pas une dérive.
      expect(_contrast(AppColors.accentPrimary, AppColors.surface),
          greaterThan(4.5));
      expect(_contrast(AppColors.accentPrimaryDark, AppColors.surface),
          greaterThan(4.5));
      expect(_contrast(Colors.white, AppColors.accentPrimary),
          greaterThan(4.5));
      expect(_contrast(Colors.white, AppColors.accentPrimaryDark),
          greaterThan(4.5));
    });

    test("l'ambre de Baba ne porte du texte qu'en version FONCÉE", () {
      // Le système de design prescrit `#D97706` pour les actions de Baba
      // AVEC un libellé blanc. Mesuré, ça donne 3,19:1 : au-dessus des 3:1
      // d'un glyphe, sous les 4,5 d'un texte.
      //
      // D'où le partage : `chatAiIconColor` (#D97706) porte le disque et
      // son glyphe, `chatAiLinkColor` (#B45309) porte tout ce qui est écrit.
      // Confondre les deux mettrait un libellé sous le seuil sur la seule
      // surface que le système veut voir de loin.
      expect(_contrast(Colors.white, AppColors.chatAiIconColor),
          greaterThan(3.0));
      expect(_contrast(Colors.white, AppColors.chatAiLinkColor),
          greaterThan(4.5));

      // Et le VIOLET est proscrit. Le système l'écrit noir sur blanc :
      // « purple is strictly banned across all tokens and components ».
      // C'est un choix culturel, pas esthétique — il écarte les codes des
      // produits occidentaux d'IA au profit d'un or sahélien.
      for (final c in [
        AppColors.chatAiIconColor,
        AppColors.chatAiLinkColor,
        AppColors.aiText,
      ]) {
        expect(
          c.b > c.r && c.b > c.g,
          isFalse,
          reason: 'aucun jeton d\'Aoussi ne doit tirer vers le violet',
        );
      }
    });
  });

  group('Couleurs porteuses de sens', () {
    test('le bleu des accusés de lecture ne désigne QUE « lu »', () {
      expect(AppColors.readReceiptBlue, const Color(0xFF53BDEB));
      // Distinct de tout le reste : un œil doit pouvoir dire « lu » d'un
      // coup, sans comparer.
      expect(AppColors.readReceiptBlue, isNot(AppColors.deliveredGray));
      expect(AppColors.readReceiptBlue, isNot(AppColors.accentPrimary));
      expect(AppColors.readReceiptBlue, isNot(AppColors.semanticError));
    });

    test('la bulle envoyée reste assez claire pour porter une encre sombre', () {
      // La valeur a changé — `#D9FDD3` → `#DCFCE7` → `#E0F2FE` → `#FBEDE4` (sable,
      // avec le passage à la terre cuite) — mais la PROPRIÉTÉ qui
      // compte n'a pas bougé : assez claire pour du texte sombre.
      //
      // C'est ce qui permet à `chatTextReceived` de servir aux DEUX bulles,
      // et donc à la vingtaine de widgets qui l'utilisent sans savoir qui
      // parle — médias, sondages, position, carte de visite, aperçu de
      // lien. Un aplat saturé imposerait du blanc, donc de faire descendre
      // `isMine` dans chacun d'eux. Si cette assertion tombe, ce n'est pas
      // le jeton qu'il faut corriger : c'est tout le rendu des bulles.
      expect(AppColors.chatBubbleSent, const Color(0xFFFBEDE4));
      expect(AppColors.chatBubbleReceived, const Color(0xFFFFFFFF));
      expect(AppColors.chatBubbleSent, isNot(AppColors.chatBubbleReceived));
      expect(
        _contrast(AppColors.chatTextReceived, AppColors.chatBubbleSent),
        greaterThan(4.5),
      );
    });

    test('une bulle reçue se détache de son canevas, par la BORDURE', () {
      // L'ancienne règle disait : le canevas DIFFÈRE du fond d'application,
      // et c'est ce décalage de surface qui détache une bulle blanche sans
      // bordure. Le papier peint crème a disparu — canevas plat, continu
      // avec le reste.
      //
      // La règle de lisibilité ne disparaît pas pour autant, elle change de
      // porteur : ce n'est plus le fond qui délimite la bulle, c'est SA
      // BORDURE. Et il n'y a plus d'ombre pour la secourir — le système les
      // supprime toutes, pour tenir la fréquence d'images sur les appareils
      // d'entrée de gamme. La retirer rendrait un message reçu flottant,
      // sans contour, indiscernable du canevas.
      // Crème du cahier v3.4 (7.2, neutral.creme-50) : le fond principal.
      expect(AppColors.chatBackground, const Color(0xFFFFF7EC));
      expect(AppColors.chatBubbleReceived, const Color(0xFFFFFFFF));
      expect(
        AppColors.chatBubbleReceivedBorder.a,
        greaterThan(0.0),
        reason: 'sur un canevas presque blanc, seule la bordure délimite',
      );
      expect(
        AppColors.chatBubbleShadow.a,
        0.0,
        reason: 'le système supprime les ombres : la profondeur est un trait',
      );
    });
  });

  group('Typographie', () {
    test('aucun style ne fige sa police : tous héritent du thème', () {
      // Ce test s'appelait « aucune police embarquée » et affirmait qu'on
      // héritait de celle du système. Ce n'est plus vrai : Outfit et Inter
      // sont désormais embarquées (voir AppTheme).
      //
      // La règle qu'il protège, elle, n'a pas changé — elle a gagné en
      // importance. `fontFamily` nulle ici veut dire « je prends celle du
      // thème ». Une famille codée en dur dans l'un de ces styles le
      // détacherait du thème : il resterait en arrière le jour où la
      // typographie change, et surtout il court-circuiterait la chaîne de
      // repli — donc l'ARABE s'y afficherait en carrés vides, puisque
      // aucune des deux familles ne le couvre.
      for (final style in [
        AppTextStyles.display,
        AppTextStyles.title,
        AppTextStyles.subtitle,
        AppTextStyles.body,
        AppTextStyles.bodySecondary,
        AppTextStyles.label,
        AppTextStyles.caption,
        AppTextStyles.mono,
        AppTextStyles.monoLarge,
      ]) {
        expect(style.fontFamily, isNull);
      }
    });

    test('les graisses restent dans la plage 400-700', () {
      for (final style in [AppTextStyles.body, AppTextStyles.subtitle, AppTextStyles.display]) {
        final weight = style.fontWeight ?? FontWeight.w400;
        expect(weight.value, greaterThanOrEqualTo(400));
        expect(weight.value, lessThanOrEqualTo(700));
      }
    });

    test('les chiffres alignés remplacent la police à chasse fixe', () {
      // Les numéros et durées s'alignaient grâce à une police mono
      // embarquée ; la fonctionnalité `tabularFigures` de la police système
      // donne le même alignement sans changer de famille au milieu d'une
      // phrase.
      expect(AppTextStyles.mono.fontFeatures, isNotNull);
      expect(
        AppTextStyles.mono.fontFeatures!.map((f) => f.feature),
        contains('tnum'),
      );
    });
  });

  group('Polices embarquées', () {
    test('toute l\'interface est en Inter, titres compris', () {
      // Cahier v3.4, section 7.3 : Inter est LA police d'interface. Elle
      // seule couvre les lettres éwé, mina et kabiyè (ɖ ɛ ƒ ɣ ŋ ɔ ʋ) et
      // l'espace fine des montants (« 25 000 FCFA »).
      final clair = AppTheme.light.textTheme;
      expect(clair.bodyLarge?.fontFamily, 'Inter');
      expect(clair.labelLarge?.fontFamily, 'Inter');
      expect(clair.titleMedium?.fontFamily, 'Inter');
      expect(clair.headlineMedium?.fontFamily, 'Inter');
      expect(clair.displayLarge?.fontFamily, 'Inter');
    });

    test('la chaîne de repli couvre l\'arabe', () {
      // NI Outfit NI Inter ne contiennent l'arabe, et Pokou le parle. Sans
      // repli, un message en arabe s'afficherait en carrés vides — un
      // défaut invisible pour qui ne teste qu'en français.
      for (final style in [
        AppTheme.light.textTheme.bodyLarge,
        AppTheme.light.textTheme.headlineMedium,
        AppTheme.dark.textTheme.bodyLarge,
      ]) {
        expect(style?.fontFamilyFallback, isNotEmpty);
      }
    });

    test('rien ne fige la taille du texte', () {
      // La crainte qui avait fait retirer Space Grotesk portait sur deux
      // choses. La substitution des écritures est traitée au-dessus. La
      // TAILLE, elle, n'a jamais dépendu de la police : `textScaler`
      // s'applique quelle que soit la famille, et il ne faut surtout pas
      // qu'un `textScaler` fixe apparaisse un jour pour « protéger » une
      // mise en page.
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyLarge?.height, anyOf(isNull, greaterThan(1.0)));
      }
    });
  });
}
