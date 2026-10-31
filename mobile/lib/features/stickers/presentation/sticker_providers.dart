import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sticker_models.dart';
import '../data/sticker_repository.dart';

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  return StickerRepository(apiClient: ref.watch(apiClientProvider));
});

/// Ce que le panneau affiche : les packs installés, les récents et les
/// favoris, chargés ENSEMBLE.
///
/// ── Pourquoi un seul état, et pas trois providers ──────────────────────
///
/// Les trois listes se répondent. Mettre un sticker en favori doit le voir
/// apparaître dans l'onglet ★ sans recharger ; l'envoyer doit le faire
/// remonter dans les récents. Avec trois providers indépendants, chaque
/// geste aurait demandé d'invalider les autres à la main — et c'est
/// exactement le genre d'oubli qui produit un panneau qui « ne se met pas
/// à jour » une fois sur trois.
class StickerPanelState {
  const StickerPanelState({
    this.packs = const [],
    this.recents = const [],
    this.favorites = const [],
    this.loading = true,
    this.error,
  });

  final List<StickerPack> packs;
  final List<Sticker> recents;
  final List<Sticker> favorites;
  final bool loading;
  final String? error;

  /// Les identifiants des favoris, pour dessiner l'étoile pleine ou vide
  /// sans parcourir la liste à chaque vignette.
  Set<int> get favoriteIds => favorites.map((s) => s.id).toSet();

  /// Rien à montrer du tout : ni pack installé, ni récent, ni favori. Le
  /// panneau propose alors le catalogue, au lieu d'une page blanche.
  bool get isEmpty =>
      packs.isEmpty && recents.isEmpty && favorites.isEmpty && !loading;

  StickerPanelState copyWith({
    List<StickerPack>? packs,
    List<Sticker>? recents,
    List<Sticker>? favorites,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return StickerPanelState(
      packs: packs ?? this.packs,
      recents: recents ?? this.recents,
      favorites: favorites ?? this.favorites,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StickerPanelController extends StateNotifier<StickerPanelState> {
  StickerPanelController(this._repo) : super(const StickerPanelState()) {
    load();
  }

  final StickerRepository _repo;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      // En parallèle : trois allers-retours en série feraient attendre
      // l'ouverture du panneau pour rien.
      final results = await Future.wait([
        _repo.myPacks(),
        _repo.recents(),
        _repo.favorites(),
      ]);
      if (!mounted) return;
      state = StickerPanelState(
        packs: results[0] as List<StickerPack>,
        recents: results[1] as List<Sticker>,
        favorites: results[2] as List<Sticker>,
        loading: false,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  /// Après un envoi : le sticker remonte en tête des récents,
  /// IMMÉDIATEMENT, sans attendre le serveur.
  ///
  /// L'appel réseau part quand même (`markUsed`), mais en arrière-plan :
  /// un envoi qui attendrait la confirmation d'un compteur d'usage pour
  /// se dessiner serait lent pour une raison que personne ne peut deviner.
  void noteSent(Sticker sticker) {
    final recents = [
      sticker,
      ...state.recents.where((s) => s.id != sticker.id),
    ];
    state = state.copyWith(recents: recents);
    _repo.markUsed(sticker.id).catchError((_) {
      // Sans conséquence visible : la prochaine ouverture du panneau
      // relira la liste du serveur.
    });
  }

  /// Favori : bascule optimiste, annulée si le serveur refuse.
  ///
  /// Les FAVORIS ne sont pas les RÉCENTS. Un favori reste tant qu'on ne
  /// l'a pas retiré, même sans l'avoir envoyé depuis des mois ; un récent
  /// se fait chasser par les suivants. Les mélanger ferait disparaître un
  /// sticker qu'on a explicitement mis de côté.
  Future<void> toggleFavorite(Sticker sticker) async {
    final etaitFavori = state.favoriteIds.contains(sticker.id);
    state = state.copyWith(
      favorites: etaitFavori
          ? state.favorites.where((s) => s.id != sticker.id).toList()
          : [sticker, ...state.favorites],
    );
    try {
      final estFavori = await _repo.toggleFavorite(sticker.id);
      if (!mounted || estFavori != etaitFavori) return;
      // Le serveur dit le contraire de ce qu'on a affiché : on se range à
      // son avis plutôt que de laisser deux vérités à l'écran.
      await load();
    } catch (_) {
      if (mounted) await load();
    }
  }

  /// Changer l'ordre des packs.
  ///
  /// Appliqué localement D'ABORD : une liste qu'on réordonne au doigt doit
  /// suivre le doigt. Attendre le serveur ferait revenir la ligne à sa
  /// place le temps de l'aller-retour, puis sauter à la bonne — deux
  /// mouvements pour un geste.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final packs = [...state.packs];
    // `ReorderableListView` rend un index calculé AVANT le retrait de
    // l'élément : sans cette correction, tout déplacement vers le bas
    // atterrit une position trop loin.
    final cible = newIndex > oldIndex ? newIndex - 1 : newIndex;
    packs.insert(cible, packs.removeAt(oldIndex));
    state = state.copyWith(packs: packs);
    try {
      await _repo.reorder(packs.map((p) => p.id).toList());
    } catch (_) {
      // Le serveur n'a pas pris : on se range à ce qu'il dit plutôt que de
      // laisser un ordre que la prochaine ouverture démentira.
      await load();
    }
  }

  /// Garder un sticker reçu, et le voir apparaître tout de suite.
  ///
  /// Rend `true` si c'est fait. L'écran appelant affiche le message ; ce
  /// contrôleur ne connaît ni `BuildContext` ni traductions.
  Future<bool> saveReceived(int mediaAssetId) async {
    await _repo.saveReceived(mediaAssetId);
    await load();
    return true;
  }

  Future<void> install(int packId) async {
    await _repo.install(packId);
    await load();
  }

  Future<void> uninstall(int packId) async {
    await _repo.uninstall(packId);
    await load();
  }

  Future<void> deletePack(int packId) async {
    await _repo.deletePack(packId);
    await load();
  }
}

/// Gardé en vie pour toute la session (pas `.autoDispose`) : le panneau
/// s'ouvre et se ferme à chaque message, et le recharger à chaque ouverture
/// rendrait le geste visiblement lent alors que rien n'a changé.
///
/// ── Mais il est lié au COMPTE ──────────────────────────────────────────
///
/// Vivre aussi longtemps que l'application veut dire survivre à une
/// déconnexion. Sur un téléphone partagé — la norme dans beaucoup de
/// commerces —, le compte suivant aurait vu les favoris et les récents du
/// précédent. C'est la raison pour laquelle le cache des conversations est
/// effacé à la déconnexion (voir `AuthController.logout`) ; la même règle
/// vaut ici.
///
/// `select` sur le seul identifiant, et non sur tout l'état : autrement,
/// la moindre mise à jour du profil (un avatar changé) jetterait le
/// panneau et le ferait recharger sans raison.
final stickerPanelProvider =
    StateNotifierProvider<StickerPanelController, StickerPanelState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return StickerPanelController(ref.watch(stickerRepositoryProvider));
    });

/// Le catalogue — chargé seulement quand on ouvre la gestion des packs.
final stickerStoreProvider = FutureProvider.autoDispose<List<StickerPack>>((
  ref,
) {
  return ref.watch(stickerRepositoryProvider).store();
});

final stickerSearchProvider = FutureProvider.autoDispose
    .family<List<Sticker>, String>((ref, query) {
      if (query.trim().isEmpty) return Future.value(const []);
      return ref.watch(stickerRepositoryProvider).search(query.trim());
    });

/// Les suggestions sous la barre de saisie, pour l'emoji qui vient d'être
/// tapé. `autoDispose` : elles ne survivent pas au message envoyé.
final stickerSuggestionProvider = FutureProvider.autoDispose
    .family<List<Sticker>, String>((ref, emoji) {
      if (emoji.isEmpty) return Future.value(const []);
      return ref.watch(stickerRepositoryProvider).suggest(emoji);
    });
