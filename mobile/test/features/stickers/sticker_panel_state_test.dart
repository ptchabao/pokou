import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/stickers/data/sticker_models.dart';
import 'package:pokou/features/stickers/presentation/sticker_providers.dart';

/// Ce que ces tests protègent tient à une distinction qui ne se lit pas
/// dans les signatures : un FAVORI n'est pas un RÉCENT.
///
/// Un récent se remplit tout seul et se fait chasser par les suivants. Un
/// favori est choisi, et reste tant qu'on ne le retire pas. Les fondre
/// ferait disparaître un sticker qu'on avait explicitement mis de côté, le
/// jour où on en envoie trente autres.
Sticker _sticker(int id) => Sticker(id: id, packId: 1, mediaId: 100 + id);

void main() {
  group('StickerPanelState', () {
    test('les favoris ne sont pas les récents', () {
      final state = StickerPanelState(
        recents: [_sticker(1), _sticker(2)],
        favorites: [_sticker(3)],
        loading: false,
      );

      expect(state.favoriteIds, {3});
      expect(state.recents.map((s) => s.id), [1, 2]);
    });

    test('un panneau vide se reconnaît, mais pas pendant le chargement', () {
      // Sans la condition sur `loading`, le panneau afficherait « aucun
      // sticker » pendant la fraction de seconde où il interroge le
      // serveur — et proposerait d'aller au catalogue alors que la
      // réponse arrive.
      expect(const StickerPanelState().isEmpty, isFalse);
      expect(const StickerPanelState(loading: false).isEmpty, isTrue);
    });

    test('un pack sans couverture retombe sur son premier sticker', () {
      // Un onglet sans vignette serait indistinguable des autres dans la
      // barre : impossible de savoir lequel on ouvre.
      final pack = StickerPack(
        id: 1,
        slug: 'p',
        name: 'Pack',
        stickers: [_sticker(7)],
      );

      expect(pack.thumbnailMediaId, 107);
    });

    test('une couverture explicite prime sur le premier sticker', () {
      final pack = StickerPack(
        id: 1,
        slug: 'p',
        name: 'Pack',
        coverMediaId: 999,
        stickers: [_sticker(7)],
      );

      expect(pack.thumbnailMediaId, 999);
    });

    test('un pack vide n\'a pas de vignette, et ne plante pas', () {
      // C'est l'état exact d'un pack personnel qu'on vient de créer.
      const pack = StickerPack(id: 1, slug: 'p', name: 'Pack');

      expect(pack.thumbnailMediaId, isNull);
    });
  });

  group('Sticker.fromJson', () {
    test('sépare les étiquettes emoji des mots-clés', () {
      // Deux chemins de recherche distincts : les emojis servent aux
      // SUGGESTIONS, les mots-clés à la recherche écrite. Les fondre
      // rendrait impossible de suggérer sans aussi chercher.
      final sticker = Sticker.fromJson(const {
        'id': 1,
        'pack_id': 2,
        'media_id': 3,
        'emoji_tags': ['😂', '🤣'],
        'keywords': 'rire drole',
      });

      expect(sticker.emojiTags, ['😂', '🤣']);
      expect(sticker.keywords, 'rire drole');
    });

    test('supporte une charge utile minimale', () {
      // Le serveur rend `emoji_tags: []` et `keywords: ''` pour un sticker
      // créé depuis une photo — sans valeurs par défaut, le panneau
      // plantait sur le premier sticker personnel.
      final sticker = Sticker.fromJson(const {
        'id': 1,
        'pack_id': 2,
        'media_id': 3,
      });

      expect(sticker.emojiTags, isEmpty);
      expect(sticker.keywords, '');
    });
  });

  group('réordonnancement', () {
    // `ReorderableListView` rend un `newIndex` calculé AVANT le retrait de
    // l'élément déplacé. Appliquer ce nombre tel quel fait atterrir tout
    // déplacement vers le bas une position trop loin — le défaut classique
    // de ce widget, et il ne se voit qu'à l'usage.
    List<int> deplacer(List<int> ids, int oldIndex, int newIndex) {
      final liste = [...ids];
      final cible = newIndex > oldIndex ? newIndex - 1 : newIndex;
      liste.insert(cible, liste.removeAt(oldIndex));
      return liste;
    }

    test('descendre un pack le pose au bon rang', () {
      // Déplacer le 1er en 3e position : Flutter annonce newIndex = 3.
      expect(deplacer([1, 2, 3, 4], 0, 3), [2, 3, 1, 4]);
    });

    test('remonter un pack ne subit pas la correction', () {
      // Vers le haut, l'index annoncé est déjà le bon.
      expect(deplacer([1, 2, 3, 4], 3, 0), [4, 1, 2, 3]);
    });

    test('un déplacement d\'une seule place fonctionne aussi', () {
      expect(deplacer([1, 2, 3], 0, 2), [2, 1, 3]);
    });
  });
}
