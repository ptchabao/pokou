import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Échelle typographique de Pokou, alignée sur le système de design WhatsApp
/// (iOS).
///
/// **Aucune police embarquée.** Ce fichier utilisait Space Grotesk et
/// JetBrains Mono via `google_fonts` ; les deux sont retirées au profit de la
/// police SYSTÈME — SF Pro sur iOS, Roboto sur Android, choisie par Flutter
/// selon la plateforme dès lors qu'aucune `fontFamily` n'est imposée.
///
/// Ce n'est pas une économie de dépendance, c'est le cœur du parti pris : une
/// messagerie utilisée quotidiennement par des gens de toutes générations
/// d'appareils doit s'effacer derrière le système. Elle hérite alors
/// gratuitement du rendu natif, du crénage attendu, de la substitution
/// automatique pour les écritures non latines, et surtout de la TAILLE DE
/// TEXTE choisie par l'utilisateur dans ses réglages d'accessibilité — ce
/// qu'une police embarquée à taille fixe ne respecte jamais complètement.
///
/// Les graisses se limitent à 400 (corps), 500 (libellés), 600 (noms et
/// titres) et 700 (grands titres). Ni 300 ni 800 : au-delà, la hiérarchie se
/// joue sur la COULEUR (encre primaire contre secondaire), pas sur le poids.
class AppTextStyles {
  AppTextStyles._();

  /// Grand titre d'écran, façon « large title » iOS.
  static final display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 0.37,
    color: AppColors.textPrimary,
  );

  static final title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  /// Nom de contact dans une liste de discussions.
  static final subtitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  /// Texte d'une bulle de message.
  static final body = TextStyle(
    fontSize: 17,
    height: 1.29,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  /// Aperçu du dernier message sous un nom de contact.
  static final bodySecondary = TextStyle(
    fontSize: 15,
    height: 1.33,
    letterSpacing: -0.2,
    color: AppColors.textSecondary,
  );

  static final label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Horodatage. Taille FIXE, volontairement : ces deux lignes doivent tenir
  /// côte à côte dans une bulle à toutes les tailles d'affichage, et un
  /// horodatage agrandi casserait la mise en page qu'il accompagne.
  static final caption = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  /// Numéros de téléphone, durées d'appel.
  ///
  /// Plus de police à chasse fixe embarquée : les chiffres passent en
  /// `FontFeature.tabularFigures()`, une fonctionnalité des polices système
  /// qui donne à chaque chiffre la même largeur. On garde donc l'alignement
  /// des colonnes de nombres — la seule raison d'être du mono ici — sans
  /// changer de famille au milieu d'une phrase.
  static final mono = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  /// Saisie d'un code à usage unique — grand et espacé.
  static final monoLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 6,
    color: AppColors.textPrimary,
  );
}
