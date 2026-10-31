import 'package:flutter/material.dart';

import '../heart_league/heart_league_screen.dart';
import '../hype_train/hype_train_screen.dart';
import '../social_tax/social_tax_screen.dart';
import '../spark/spark_screen.dart';
import '../streak_lock/streak_lock_screen.dart';
import '../truth_market/truth_market_screen.dart';
import '../verses/verse_data.dart';
import '../verses/verse_screen.dart';
import '../vip_room/vip_room_screen.dart';

/// Où mène un module une fois activé.
///
/// Cette table est le chaînon qui manquait : les modules étaient activables
/// mais ne conduisaient NULLE PART. Un interrupteur qui n'allume rien est
/// pire qu'une absence de fonctionnalité — il donne l'impression que
/// l'application est cassée.
///
/// Explicite, comme la table d'icônes, et pour la même raison : le slug vient
/// du serveur, et une résolution dynamique ne survivrait pas à l'élagage de
/// code en release.
///
/// Un slug ABSENT de cette table est un module dont l'écran n'est pas encore
/// écrit. L'appelant doit alors le dire, plutôt que d'ouvrir une page vide —
/// voir `ModulesScreen`. C'est ce qui permet à l'équipe d'ouvrir un module
/// dans l'administration sans qu'un utilisateur tombe dans le vide.
WidgetBuilder? moduleScreenFor(String slug) {
  return switch (slug) {
    'heart_league' => (_) => const HeartLeagueScreen(),
    'streak_lock' => (_) => const StreakLockScreen(),
    'truth_market' => (_) => const TruthMarketScreen(),
    'social_tax' => (_) => const SocialTaxScreen(),
    'vip_room' => (_) => const VipRoomScreen(),
    'hype_train' => (_) => const HypeTrainScreen(),
    'spark' => (_) => const SparkScreen(),
    'bible_verses' => (_) => const VerseScreen(kind: VerseKind.bible),
    'quran_verses' => (_) => const VerseScreen(kind: VerseKind.quran),
    _ => null,
  };
}

/// Le module a-t-il un écran dans CETTE version de l'application ?
bool moduleHasScreen(String slug) => moduleScreenFor(slug) != null;
