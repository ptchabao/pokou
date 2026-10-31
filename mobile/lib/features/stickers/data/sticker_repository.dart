import '../../../core/api/api_client.dart';
import 'sticker_models.dart';

/// L'accès aux stickers : packs installés, catalogue, favoris, récents,
/// recherche et suggestions.
///
/// ── Pourquoi tout passe par le serveur, y compris les récents ──────────
///
/// Les garder seulement sur l'appareil serait plus simple, et faux : on
/// change de téléphone, on réinstalle, et on retrouve alors un panneau
/// vide alors qu'on envoie les mêmes cinq stickers depuis des mois. Les
/// récents et les favoris SUIVENT le compte.
class StickerRepository {
  StickerRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static List<Sticker> _stickers(dynamic response) =>
      ((response as Map<String, dynamic>)['items'] as List<dynamic>? ??
              const [])
          .map((e) => Sticker.fromJson(e as Map<String, dynamic>))
          .toList();

  static List<StickerPack> _packs(dynamic response) =>
      ((response as Map<String, dynamic>)['items'] as List<dynamic>? ??
              const [])
          .map((e) => StickerPack.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<List<StickerPack>> myPacks() async =>
      _packs(await _api.get('/stickers'));

  Future<List<StickerPack>> store() async =>
      _packs(await _api.get('/stickers/store'));

  Future<List<Sticker>> recents() async =>
      _stickers(await _api.get('/stickers/recents'));

  Future<List<Sticker>> favorites() async =>
      _stickers(await _api.get('/stickers/favorites'));

  Future<List<Sticker>> search(String query) async => _stickers(
    await _api.get('/stickers/search?q=${Uri.encodeQueryComponent(query)}'),
  );

  /// Les stickers à proposer pour cet emoji.
  ///
  /// La normalisation des variantes (teint de peau, sélecteur de style) est
  /// faite par le SERVEUR : 👍🏿 et 👍 doivent tomber sur les mêmes
  /// stickers, et refaire ce calcul ici créerait deux règles à tenir
  /// d'accord.
  Future<List<Sticker>> suggest(String emoji) async => _stickers(
    await _api.get(
      '/stickers/suggest?emoji=${Uri.encodeQueryComponent(emoji)}',
    ),
  );

  /// Bascule — la même route ajoute et retire. Rend l'état résultant.
  Future<bool> toggleFavorite(int stickerId) async {
    final response = await _api.post('/stickers/$stickerId/favorite');
    return (response as Map<String, dynamic>)['favorite'] == true;
  }

  /// Signale l'usage, à l'ENVOI. Appelé sans être attendu : un récent qui
  /// ne remonte pas est un désagrément, un envoi qui attend un aller-retour
  /// réseau pour partir est un défaut.
  Future<void> markUsed(int stickerId) =>
      _api.post('/stickers/$stickerId/used');

  Future<void> install(int packId) =>
      _api.post('/stickers/packs/$packId/install');

  Future<void> uninstall(int packId) =>
      _api.delete('/stickers/packs/$packId/install');

  Future<void> reorder(List<int> packIds) =>
      _api.put('/stickers/packs/order', body: {'pack_ids': packIds});

  Future<StickerPack> createPack(String name) async {
    final response = await _api.post('/stickers/packs', body: {'name': name});
    return StickerPack.fromJson(response as Map<String, dynamic>);
  }

  Future<Sticker> addToPack({
    required int packId,
    required int mediaAssetId,
    String emojiTags = '',
    String keywords = '',
  }) async {
    final response = await _api.post(
      '/stickers/packs/$packId/stickers',
      body: {
        'media_asset_id': mediaAssetId,
        'emoji_tags': emojiTags,
        'keywords': keywords,
      },
    );
    return Sticker.fromJson(response as Map<String, dynamic>);
  }

  /// Garde dans ses stickers celui qu'on vient de recevoir.
  ///
  /// On envoie l'identifiant du MÉDIA, pas celui du sticker : un message
  /// ne porte que son média, et faire chercher le sticker au client
  /// demanderait un aller-retour de plus pour une information que le
  /// serveur retrouve d'une requête.
  Future<Sticker> saveReceived(int mediaAssetId) async {
    final response = await _api.post(
      '/stickers/save',
      body: {'media_asset_id': mediaAssetId},
    );
    return Sticker.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deletePack(int packId) => _api.delete('/stickers/packs/$packId');
}
