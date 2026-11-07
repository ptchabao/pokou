import 'package:flutter/material.dart';

/// Shared corner-radius scale — replaces 8 different inline radius literals
/// (20, 24, 16, 14, 12, 18, 10, 8, 4) used for what was functionally one
/// repeated "card" pattern across the app.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  // Maquette Figma « Design professionnel complet » : cartes 18, tuiles
  // internes 13, actions et filtres en pastille.
  static const double tile = 18; // dominant card/list-tile radius
  static const double inner = 13; // tuile dans une carte (mini-fil, devis)
  static const double sheet = 24; // bottom sheets, buttons, inputs

  static const chip = BorderRadius.all(Radius.circular(sm));
  static const bubble = BorderRadius.all(Radius.circular(lg));
  static const card = BorderRadius.all(Radius.circular(tile));
  static const bottomSheet = BorderRadius.vertical(top: Radius.circular(sheet));
}
