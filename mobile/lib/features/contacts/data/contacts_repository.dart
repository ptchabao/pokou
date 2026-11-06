import '../../../core/api/api_client.dart';
import 'contact_model.dart';
import 'device_contacts_service.dart';

class ContactsRepository {
  ContactsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Les contacts tels que le serveur les envoie.
  ///
  /// Le JSON brut est ce qu'on met en cache pour le hors-ligne (voir
  /// core/sync/offline_list.dart) : le serveur compose et trie cette liste,
  /// la reconstruire côté client donnerait un autre ordre.
  Future<List<dynamic>> listRaw() async {
    final response = await _api.get('/contacts');
    return response['items'] as List;
  }

  Future<List<PokouContact>> list() async => (await listRaw())
      .cast<Map<String, dynamic>>()
      .map(PokouContact.fromJson)
      .toList();

  Future<PokouContact> add({
    required String phone,
    required String displayName,
  }) async {
    final response = await _api.post(
      '/contacts',
      body: {'phone': phone, 'display_name': displayName},
    );
    return PokouContact.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(int contactId) => _api.delete('/contacts/$contactId');

  /// Qui est derrière ce numéro ? — sans RIEN écrire dans le carnet.
  ///
  /// C'est ce qui permet d'écrire à quelqu'un sans l'enregistrer : on demande
  /// au serveur si le numéro correspond à un compte, et on ouvre la
  /// discussion. La route répond 200 même pour un numéro inconnu — ne pas
  /// être inscrit n'est pas une erreur, c'est le cas qui déclenche
  /// l'invitation.
  Future<PhoneLookup> lookup(String phone) async {
    final response = await _api.get(
      '/contacts/lookup?phone=${Uri.encodeQueryComponent(phone)}',
    );
    return PhoneLookup.fromJson(response as Map<String, dynamic>);
  }

  /// Mode Bouclier — BUSINESS/FOURNISSEUR/CLIENT/BOSS/AMI (voir PokouContact.priorityTag).
  Future<PokouContact> setPriorityTag(int contactId, String priorityTag) async {
    final response = await _api.put(
      '/contacts/$contactId',
      body: {'priority_tag': priorityTag},
    );
    return PokouContact.fromJson(response as Map<String, dynamic>);
  }

  /// Sends the device's address book (phone + name only) to the backend
  /// and returns the matches that are now in the user's Pokou contacts —
  /// the backend adds/updates them server-side; nothing is persisted for
  /// numbers that don't match a Pokou account.
  /// Par lots : le serveur refuse au-delà de [syncBatchSize] entrées par
  /// requête (422). Un répertoire de commerçant dépasse souvent 3 000
  /// numéros, et l'envoi en un bloc échouait EN ENTIER — personne
  /// n'apparaissait dans le carnet, sans aucun message.
  static const syncBatchSize = 1000;

  Future<List<PokouContact>> syncDevice(
    List<DeviceContactEntry> entries,
  ) async {
    final found = <PokouContact>[];
    for (var start = 0; start < entries.length; start += syncBatchSize) {
      final batch = entries.skip(start).take(syncBatchSize);
      final response = await _api.post(
        '/contacts/sync',
        body: {
          'contacts': [
            for (final e in batch)
              {
                'phone': e.phone,
                // Le serveur borne le nom à 255 caractères.
                'name': e.name.length > 255 ? e.name.substring(0, 255) : e.name,
              },
          ],
        },
      );
      final items = (response['items'] as List).cast<Map<String, dynamic>>();
      found.addAll(items.map(PokouContact.fromJson));
    }
    return found;
  }
}
