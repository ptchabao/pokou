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
  /// Fond d'application : listes, réglages, profils. Blanc, pas gris — le
  /// gris est réservé aux surfaces groupées.
  static Color get background => _pick(const Color(0xFFF8FAFC), const Color(0xFF131B2E));
  static Color get surface => _pick(const Color(0xFFFFFFFF), const Color(0xFF1B2438));
  /// Surface groupée (sections de réglages, barre de recherche).
  static Color get surfaceElevated => _pick(const Color(0xFFF1F5F9), const Color(0xFF283044));
  /// Filet entre deux lignes de liste — un cheveu, pas un trait.
  static Color get border => _pick(const Color(0xFFE2E8F0), const Color(0xFF334155));
  /// Remplissage des formes d'attente (voir core/widgets/skeleton.dart).
  /// Un cran plus soutenu que `border` : un squelette doit se lire comme
  /// un bloc de contenu à venir, pas comme une séparation.
  static Color get skeletonFill => _pick(const Color(0xFFE2E8F0), const Color(0xFF334155));

  // ── Encre ──────────────────────────────────────────────────────────────
  /// Texte des bulles, noms de contacts, titres. 15,8:1 sur blanc.
  static Color get textPrimary => _pick(const Color(0xFF0F172A), const Color(0xFFEEF0FF));
  /// Aperçu de message, horodatage, sous-titres. 4,9:1 sur blanc.
  static Color get textSecondary => _pick(const Color(0xFF475569), const Color(0xFFA8B4C8));
  /// Indication de saisie, libellés désactivés, icônes au repos.
  static Color get textMuted => _pick(const Color(0xFF64748B), const Color(0xFF8492A8));

  // ── Marque ─────────────────────────────────────────────────────────────
  /// LA couleur d'action, terre cuite. Bouton d'envoi, décrocher,
  /// enregistrement vocal, anneau de statut non vu, pastille de non-lus.
  /// Un glyphe ou un libellé blanc dessus tient 5,3:1, et elle tient 5,3:1
  /// comme encre sur blanc.
  static const accentPrimary = Color(0xFFA65527);
  /// État pressé de la couleur d'action (7,1:1 sur blanc).
  static const accentPressed = Color(0xFF8A4520);
  /// Teal secondaire — icônes et libellés teintés de second rang (4,6:1).
  static Color get accentPrimaryLight => _pick(const Color(0xFF93491F), const Color(0xFFE39A6B));
  /// Teal de marque — l'encre teintée : liens, libellés d'action textuels,
  /// icônes sur fond clair. C'est le jeton à prendre quand on écrit, pas
  /// quand on remplit.
  static Color get accentPrimaryDark => _pick(const Color(0xFF7A3A18), const Color(0xFFE39A6B));

  /// Anneau de focus des champs de formulaire.
  static const focusRing = Color(0xFFA65527);

  static Color get securityCritical => _pick(const Color(0xFF0F172A), const Color(0xFFEEF0FF));
  static const securityVerified = Color(0xFFA65527);
  static const certifiedBadgeBlue = Color(0xFF1688C7);
  static Color get securityWarning => _pick(const Color(0xFFB45309), const Color(0xFFFBBF24));
  static Color get securityWarningSolid => _pick(const Color(0xFF92400E), const Color(0xFFD97706));
  static const warning = Color(0xFFD97706);


  /// Ombre neutre — voir app_elevation.dart. Extrêmement retenue : ce
  /// système est plat, une bulle ne se décolle que d'un ou deux points.
  static Color get shadowTint => _pick(const Color(0x14000000), const Color(0x33000000));

  /// Accents de badge — déclinaisons de la marque.
  static const badgeGreen = Color(0xFFA65527);
  static Color get badgeCyan => _pick(const Color(0xFF93491F), const Color(0xFFE39A6B));
  static Color get badgePink => _pick(const Color(0xFFB45309), const Color(0xFFFBBF24));

  // ── Barre de navigation basse ──────────────────────────────────────────
  // Fond blanc translucide, onglet actif en vert de marque, inactif en gris
  // froid. Le vert est ici un signal d'état, pas un ornement.
  static Color get navBackground => _pick(const Color(0xFFFFFFFF), const Color(0xFF1B2438));
  static const navPillBackground = Color(0x14A65527);
  static const navPillForeground = accentPrimary;
  static const navIconInactive = Color(0xFF64748B);

  // ── Écran de discussion ────────────────────────────────────────────────
  /// Papier peint de conversation — crème. DIFFÉRENT du fond d'application :
  /// c'est ce contraste de surface qui détache une bulle blanche sans
  /// bordure, et qui rend une conversation chargée chaleureuse plutôt
  /// qu'administrative.
  static Color get chatBackground => _pick(const Color(0xFFF8FAFC), const Color(0xFF131B2E));
  static Color get chatGlowCenter => _pick(const Color(0xFFF8FAFC), const Color(0xFF131B2E));

  /// Bulle REÇUE — blanc pur sur le papier peint crème.
  static Color get chatBubbleReceived => _pick(const Color(0xFFFFFFFF), const Color(0xFF283044));
  static Color get chatBubbleReceivedBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF3A4459));

  /// La couleur du NOM d'un auteur dans un groupe, stable par personne.
  ///
  /// Le nom s'écrivait en gris clair, 11 points : on ne voyait pas qui
  /// parlait. Une couleur par personne se lit d'un coup d'œil, et la même
  /// personne garde la sienne d'un message à l'autre. Teintes foncées sur le
  /// fond clair, éclaircies sur le fond sombre.
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
  static Color get chatTextReceived => _pick(const Color(0xFF0F172A), const Color(0xFFEEF0FF));

  /// Bulle ENVOYÉE — un sable très clair, accordé à la terre cuite d'action
  /// (elle a été vert menthe, puis bleu ciel). C'est le pixel signature de la messagerie :
  /// reconnaissable isolé, hors de tout contexte. Encre sombre dessus :
  /// 15,6:1. Assez clair pour porter de l'encre sombre, ce qui garde les
  /// longs messages lisibles (un aplat saturé imposerait du blanc, moins
  /// confortable à lire).
  static Color get chatBubbleSent => _pick(const Color(0xFFFBEDE4), const Color(0xFF5C2E14));
  static Color get chatBubbleSentBorder => _pick(const Color(0xFFF3D3BE), const Color(0xFF7A3A18));

  /// Ombre d'une bulle : 8 % de noir, un point de décalage. Juste de quoi
  /// décoller du papier peint.
  /// PLUS D'OMBRE — transparent dans les deux thèmes.
  ///
  /// Le système de design supprime les ombres diffuses et les flous pour
  /// tenir la fréquence d'images et ménager la batterie sur des appareils
  /// d'entrée de gamme. La profondeur se lit désormais par un trait d'un
  /// point, et rien d'autre.
  ///
  /// Le jeton est conservé plutôt que retiré : il est lu à une dizaine
  /// d'endroits, et une ombre transparente les laisse tous intacts sans
  /// rien dessiner. Le jour où une ombre redevient souhaitable, elle se
  /// repose ici, à un seul endroit.
  static Color get chatBubbleShadow => const Color(0x00000000);

  /// Vert d'action dans la conversation — bouton d'envoi, micro, barres de
  /// progression. Les deux jetons restent distincts pour l'état pressé.
  static const chatActionGreen = Color(0xFFA65527);
  static const chatActionGreenDeep = Color(0xFF8A4520);

  /// Horodatage dans une bulle et dans la liste.
  ///
  /// Écart assumé au système de référence, qui donne `#667781` : sur la bulle
  /// menthe, cette valeur tombe à 4,19:1 de contraste, sous le seuil AA de
  /// 4,5 pour un texte de 11 points. `#54636D` — déjà présent dans la même
  /// palette — remonte à 5,6:1 sur menthe et 6,2:1 sur blanc, pour un
  /// assombrissement invisible à l'œil. Ça compte ici plus qu'ailleurs : ces
  /// écrans se lisent dehors, en plein soleil, sur des dalles bon marché.
  ///
  /// Même arbitrage en SOMBRE, et il a fallu aller plus loin que
  /// l'application de référence : le gris habituel (`#8696A0`) tombe à
  /// 2,61:1 sur la bulle vert foncé, très en dessous du seuil. `#BFCCC8`
  /// remonte à 4,82:1 sur la bulle envoyée et 8,63:1 sur la reçue. C'est un
  /// horodatage plus présent qu'ailleurs, et c'est le prix d'un chiffre
  /// lisible.
  /// Écart assumé au système de référence, qui donne `#059669`.
  ///
  /// Valeur actuelle : `#6B3415`, 8,6:1 sur la bulle envoyée `#FBEDE4` et
  /// 9,9:1 sur blanc. Historique, du temps de la bulle verte : mesuré sur
  /// `#DCFCE7`, `#059669` tombait à **3,43:1** —
  /// sous le seuil AA de 4,5 pour un texte de 11 points. C'est précisément
  /// la valeur que le système lui-même exige ailleurs : il annonce des
  /// contrastes « surpassing 7:1 », et cet horodatage n'y arrivait pas.
  ///
  /// `#065F46`, déjà dans la même famille, donne 7,00:1 sur la bulle
  /// envoyée et 7,68:1 sur la reçue, pour un assombrissement invisible à
  /// l'œil. Ça compte plus ici qu'ailleurs : ces écrans se lisent dehors,
  /// en plein soleil, sur des dalles bon marché — c'est la contrainte
  /// fondatrice de tout ce système de design.
  static Color get chatTimestamp =>
      _pick(const Color(0xFF6B3415), const Color(0xFFF6E3D6));
  static Color get chatComposerBg => _pick(const Color(0xFFFFFFFF), const Color(0xFF1B2438));
  static Color get chatComposerBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF334155));
  /// Icônes au repos de la barre de saisie (trombone, appareil photo, emoji).
  static const chatIconMuted = Color(0xFF64748B);
  /// Anneau autour d'un avatar portant des statuts — cuivre tant qu'ils ne
  /// sont pas vus, gris ensuite.
  static const chatAvatarRingStart = Color(0xFFA65527);
  static const chatAvatarRingEnd = Color(0xFF93491F);
  static const statusRingViewed = Color(0xFF94A3B8);

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
  static Color get chatMediaFrame => _pick(const Color(0xFFFFFFFF), const Color(0xFF283044));
  static Color get chatMediaFrameBorder => _pick(const Color(0xFFE2E8F0), const Color(0xFF3A4459));
  static Color get chatAiCardBg => _pick(const Color(0xFFFEF3C7), const Color(0xFF3A2E12));
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
