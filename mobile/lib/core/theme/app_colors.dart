import 'package:flutter/material.dart';

/// Palette Pokou, alignée sur le système de design WhatsApp (iOS).
///
/// Trois règles gouvernent tout ce fichier, et expliquent chaque valeur :
///
/// 1. **La terre cuite Pokou est un VERBE, pas une décoration.** `#A65527`
///    sert aux actions — envoyer, décrocher, enregistrer — et aux signaux
///    d'état (anneau de statut non vu, pastille de non-lus). Elle tient
///    5,3:1 sur blanc et 5,3:1 sous un libellé blanc : elle peut porter du
///    texte, ce que le bleu `#129CF5` (2,96:1) ne pouvait pas.
/// 2. **Le brun profond est l'encre de marque.** `#7A3A18` (et `#93491F` en
///    secondaire) porte les libellés, icônes et liens teintés (8,6:1 sur
///    blanc). Historique : vert `#008069`, puis bleu `#129CF5`, puis cette
///    terre cuite.
/// 3. **Le bleu des accusés de lecture est porteur de sens.** `#53BDEB` ne
///    désigne QUE « lu ». Le réutiliser ailleurs détruirait le signal le plus
///    universellement compris de toute l'application.
///
/// Le fond de conversation (`chatBackground`) est volontairement DIFFÉRENT du
/// fond d'application (`background`) : crème contre blanc. C'est ce qui fait
/// qu'une bulle blanche se détache sans avoir besoin de bordure.
class AppColors {
  AppColors._();

  // ── Clair ou sombre ────────────────────────────────────────────────────
  //
  // Pokou s'affichait en clair quoi qu'il arrive : `themeMode: ThemeMode.light`
  // et, plus révélateur, `darkTheme: AppTheme.light` — le thème sombre ÉTAIT
  // le thème clair. Pour une messagerie, dont l'usage est largement nocturne,
  // c'était le manque le plus visible de toute l'application.
  //
  // Les jetons basculent ici plutôt que dans un `ThemeExtension` lu par
  // `Theme.of(context)`. Ce n'est pas le choix le plus idiomatique, et il se
  // justifie par un chiffre : 952 usages de `AppColors.x` répartis dans 86
  // fichiers. Les convertir tous en lectures contextuelles serait une refonte
  // à haut risque pour un bénéfice invisible, là où un sélecteur global rend
  // les 952 sensibles au thème d'un coup.
  //
  // Le prix à payer, et il est réel : ces jetons ne sont plus `const`. Un
  // widget qui les capture dans un champ à la construction ne suivrait pas un
  // changement de thème — c'est pour cela que `const` a dû être retiré
  // partout où ils apparaissent, ce qui est aussi ce qui garantit la
  // reconstruction.
  static bool _dark = false;

  /// Le mode en vigueur. Posé par `PokouApp.build` AVANT de construire
  /// l'arbre : `MaterialApp` se reconstruit quand la luminosité du système
  /// change, et toute la descendance avec.
  static void applyBrightness(Brightness brightness) {
    _dark = brightness == Brightness.dark;
  }

  /// Vrai quand l'application s'affiche en sombre. Lu par les rares endroits
  /// qui ont besoin de la nuance elle-même (une image à inverser, un dégradé
  /// à retourner) plutôt que d'une couleur.
  static bool get isDark => _dark;

  static Color _pick(Color light, Color dark) => _dark ? dark : light;

  // ── Canevas et surfaces ────────────────────────────────────────────────
  /// Fond d'application : listes, réglages, profils.
  /// v3.4 Section 7.2 neutral.creme-50 #FFF7EC / Section 7.8 mode sombre #1A1615 (brand.ebene-900).
  static Color get background => _pick(const Color(0xFFF8FAFC), const Color(0xFF1A1615));
  /// Surface : cartes, feuilles modales, dialogue.
  /// v3.4 Section 7.8 mode sombre #2A2320 (surface sombre chaude).
  static Color get surface => _pick(const Color(0xFFFFFFFF), const Color(0xFF2A2320));
  /// Surface groupée (sections de réglages, barre de recherche).
  static Color get surfaceElevated => _pick(const Color(0xFFF1F5F9), const Color(0xFF352C28));
  /// Filet entre deux lignes de liste — un cheveu, pas un trait.
  static Color get border => _pick(const Color(0xFFE2E8F0), const Color(0xFF3D332E));
  /// Remplissage des formes d'attente (voir core/widgets/skeleton.dart).
  static Color get skeletonFill => _pick(const Color(0xFFE2E8F0), const Color(0xFF3D332E));

  // ── Encre ──────────────────────────────────────────────────────────────
  /// Texte des bulles, noms de contacts, titres.
  /// v3.4 Section 7.2 brand.ebene-900 #1A1615 / Section 7.8 mode sombre #FFF7EC (14,54:1 sur surface).
  static Color get textPrimary => _pick(const Color(0xFF1A1615), const Color(0xFFFFF7EC));
  /// Aperçu de message, horodatage, sous-titres.
  /// v3.4 Section 7.2 neutral.taupe-600 #6B5E57 / Section 7.8 mode sombre #B8AAA0 (6,84:1 sur surface).
  static Color get textSecondary => _pick(const Color(0xFF6B5E57), const Color(0xFFB8AAA0));
  /// Indication de saisie, libellés désactivés, icônes au repos.
  /// v3.4 Section 7.2 neutral.taupe-500 #8C7D73.
  static Color get textMuted => _pick(const Color(0xFF8C7D73), const Color(0xFF8C7D73));

  // ── Marque & Jetons de charte v3.4 (Section 7.2 & 7.8) ─────────────────
  /// LA couleur d'action, terre cuite terracotta-500 (#A65527).
  static const accentPrimary = Color(0xFFA65527);
  /// État pressé de la couleur d'action terracotta-700 (#8A4520).
  static const accentPressed = Color(0xFF8A4520);
  /// Puce sélectionnée terracotta-100 (#F5DCCB).
  static const brandTerracotta100 = Color(0xFFF5DCCB);
  /// Cuivre brand.cuivre-500 (#B86D3B).
  static const brandCuivre = Color(0xFFB86D3B);
  /// Or brand.or-500 (#D4AF37). Lisible sur sombre (7,34:1 sur surface).
  static const brandOr = Color(0xFFD4AF37);
  /// Ébène brand.ebene-900 (#1A1615).
  static const brandEbene = Color(0xFF1A1615);
  /// Crème neutral.creme-50 (#FFF7EC).
  static const neutralCreme = Color(0xFFFFF7EC);
  /// Beige neutral.beige-100 (#F2E5D5).
  static const neutralBeige = Color(0xFFF2E5D5);
  /// Sable neutral.sable-200 (#E4D3BF).
  static const neutralSable = Color(0xFFE4D3BF);

  /// Verbe / Action selon thème :
  /// v3.4 Section 7.8 : action #E8A57C avec libellé ébène #1A1615 (8,64:1).
  static Color get actionButtonBackground => _pick(const Color(0xFF7A3A18), const Color(0xFFE8A57C));
  static Color get actionButtonForeground => _pick(Colors.white, const Color(0xFF1A1615));

  /// Teal / Terre cuite secondaire — icônes et libellés teintés.
  static Color get accentPrimaryLight => _pick(const Color(0xFF93491F), const Color(0xFFE8A57C));
  /// L'encre teintée de marque : liens, libellés d'action textuels, icônes.
  static Color get accentPrimaryDark => _pick(const Color(0xFF7A3A18), const Color(0xFFE8A57C));

  /// Anneau de focus des champs de formulaire.
  static const focusRing = Color(0xFFA65527);

  static Color get securityCritical => _pick(const Color(0xFFB3261E), const Color(0xFFEF5350));
  static const securityVerified = Color(0xFFA65527);
  static const certifiedBadgeBlue = Color(0xFF1688C7);
  static Color get securityWarning => _pick(const Color(0xFF8A5A00), const Color(0xFFFBBF24));
  static Color get securityWarningSolid => _pick(const Color(0xFF8A5A00), const Color(0xFFD97706));
  static const warning = Color(0xFF8A5A00);


  /// Ombre neutre — voir app_elevation.dart. Extrêmement retenue : ce
  /// système est plat, une bulle ne se décolle que d'un ou deux points.
  static Color get shadowTint => _pick(const Color(0x14000000), const Color(0x33000000));

  /// Accents de badge — déclinaisons de la marque.
  static const badgeGreen = Color(0xFFA65527);
  static Color get badgeCyan => _pick(const Color(0xFF93491F), const Color(0xFFE39A6B));
  static Color get badgePink => _pick(const Color(0xFFB45309), const Color(0xFFFBBF24));

  // ── Barre de navigation basse ──────────────────────────────────────────
  // Fond blanc translucide en clair, surface sombre #2A2320 en sombre.
  static Color get navBackground => _pick(const Color(0xFFFFFFFF), const Color(0xFF2A2320));
  static const navPillBackground = Color(0x14A65527);
  static const navPillForeground = accentPrimary;
  static Color get navIconInactive => _pick(const Color(0xFF8C7D73), const Color(0xFFB8AAA0));

  // ── Écran de discussion ────────────────────────────────────────────────
  /// Papier peint de conversation — crème / ébène.
  static Color get chatBackground => _pick(const Color(0xFFF8FAFC), const Color(0xFF1A1615));
  static Color get chatGlowCenter => _pick(const Color(0xFFF8FAFC), const Color(0xFF1A1615));

  /// Bulle REÇUE — blanc pur sur fond clair, surface chaude #2A2320 en sombre.
  static Color get chatBubbleReceived => _pick(const Color(0xFFFFFFFF), const Color(0xFF2A2320));
  static Color get chatBubbleReceivedBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF3D332E));

  /// La couleur du NOM d'un auteur dans un groupe, stable par personne.
  static Color authorName(int userId) {
    const light = [
      Color(0xFF1565C0), Color(0xFF7B1FA2), Color(0xFFC62828), Color(0xFF00796B),
      Color(0xFFD84315), Color(0xFF283593), Color(0xFFAD1457), Color(0xFF5D4037),
    ];
    const dark = [
      Color(0xFF64B5F6), Color(0xFFCE93D8), Color(0xFFEF9A9A), Color(0xFF4DB6AC),
      Color(0xFFFFAB91), Color(0xFF9FA8DA), Color(0xFFF48FB1), Color(0xFFBCAAA4),
    ];
    final i = userId.abs() % light.length;
    return _pick(light[i], dark[i]);
  }
  static Color get chatTextReceived => _pick(const Color(0xFF1A1615), const Color(0xFFFFF7EC));

  /// Bulle ENVOYÉE — un sable très clair en clair, terracotta profond en sombre.
  static Color get chatBubbleSent => _pick(const Color(0xFFFBEDE4), const Color(0xFF5C2E14));
  static Color get chatBubbleSentBorder => _pick(const Color(0xFFF3D3BE), const Color(0xFF7A3A18));

  static Color get chatBubbleShadow => const Color(0x00000000);

  /// Couleur d'action dans la conversation.
  static const chatActionGreen = Color(0xFFA65527);
  static const chatActionGreenDeep = Color(0xFF8A4520);

  static Color get chatTimestamp =>
      _pick(const Color(0xFF6B3415), const Color(0xFFF6E3D6));
  static Color get chatComposerBg => _pick(const Color(0xFFFFFFFF), const Color(0xFF2A2320));
  static Color get chatComposerBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF3D332E));
  /// Icônes au repos de la barre de saisie (neutral.taupe-500).
  static const chatIconMuted = Color(0xFF8C7D73);
  /// Anneau autour d'un avatar portant des statuts.
  static const chatAvatarRingStart = Color(0xFFA65527);
  static const chatAvatarRingEnd = Color(0xFF93491F);
  static Color get statusRingViewed => _pick(const Color(0xFF94A3B8), const Color(0xFF6B5E57));

  /// L'auréole cuivrée des statuts non vus. Un dégradé balayé, et non un
  /// aplat : c'est le reflet qui fait lire « cuivre » plutôt que « brun » —
  /// clair en haut à gauche, sombre en face, et refermé sur lui-même pour
  /// ne laisser aucune couture.
  ///
  /// Un dégradé par fond : le reflet clair `#E8A672` de la première version
  /// ne tenait que 2,1:1 sur blanc, et l'anneau disparaissait par endroits.
  /// Chaque arrêt tient désormais au moins 3,6:1 sur le fond qu'il borde —
  /// le seuil des éléments graphiques est 3:1.
  static SweepGradient get statusRingCopper =>
      _dark ? statusRingCopperOnDark : _statusRingCopperOnLight;

  static const _statusRingCopperOnLight = SweepGradient(
    colors: [
      Color(0xFFC8702F),
      Color(0xFFA9551D),
      Color(0xFF7A3A12),
      Color(0xFFA9551D),
      Color(0xFFC8702F),
    ],
    transform: GradientRotation(-2.36),
  );

  /// Aussi pour le lecteur de statuts, noir dans les deux thèmes.
  static const statusRingCopperOnDark = SweepGradient(
    colors: [
      Color(0xFFF0B07A),
      Color(0xFFE08A48),
      Color(0xFFC46A2B),
      Color(0xFFE08A48),
      Color(0xFFF0B07A),
    ],
    transform: GradientRotation(-2.36),
  );

  /// Cadre des médias dans une bulle.
  static Color get chatMediaFrame => _pick(const Color(0xFFFFFFFF), const Color(0xFF2A2320));
  static Color get chatMediaFrameBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF3D332E));
  static Color get chatAiCardBg => _pick(const Color(0xFFFEF3C7), const Color(0xFF352C28));
  static Color get chatAiIconColor => _pick(const Color(0xFFD97706), const Color(0xFFFBBF24));
  static Color get chatAiLinkColor => _pick(const Color(0xFFB45309), const Color(0xFFFBBF24));
  /// Corps de texte d'une réponse d'assistant — gris distinct, pour qu'une
  /// réponse automatique se reconnaisse d'un coup d'œil.
  static Color get aiText => _pick(const Color(0xFF78350F), const Color(0xFFFDE68A));

  // ── Signaux ────────────────────────────────────────────────────────────
  /// Double coche BLEUE — « lu ». Le signal le plus chargé de sens de toute
  /// l'application, et le seul usage autorisé de cette couleur.
  static const readReceiptBlue = Color(0xFF53BDEB);
  /// Coche simple ou double grise — envoyé, puis remis.
  static const deliveredGray = Color(0xFF64748B);
  /// Échec d'envoi, suppression, refuser un appel.
  // ── Retours d'état du cahier des charges (section 7.2) ─────────────────
  // Chacun tient au moins 5:1 sur crème. Ils accompagnent TOUJOURS une
  // icône et un libellé : un état ne se dit jamais par la couleur seule
  // (DS-06).
  static const feedbackSuccess = Color(0xFF1E7A46);
  static const feedbackWarning = Color(0xFF8A5A00);
  static const feedbackDanger = Color(0xFFB3261E);
  static const feedbackInfo = Color(0xFF245C9E);
  static const semanticError = Color(0xFFBA1A1A);
  /// Conservé pour les états confirmés non liés à la lecture.
  static const semanticSuccess = Color(0xFFA65527);
}
