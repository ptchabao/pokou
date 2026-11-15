import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../honam/data/honam_models.dart' show HonamOrderMessage;
import 'officine_models.dart';

/// Les appels de l'espace officine : ceux de l'application web
/// (`backend/app/officine/officine.js`), avec le même jeton que le reste de
/// l'application. Le serveur refuse (403) un compte qui n'est rattaché à
/// aucune officine.
class OfficineRepository {
  OfficineRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static const _base = '/honam/pharmacy';

  /// L'accueil de l'officine, ou `null` si le compte n'appartient à
  /// l'équipe d'aucune officine (ou si Honam est fermé dans le pays).
  Future<OfficineMe?> me() async {
    try {
      final json = await _api.get('$_base/me') as Map<String, dynamic>;
      return OfficineMe.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Sans [status] : la file en cours (nouvelles, devis, paiement,
  /// préparation, coursier). Avec : les commandes de cet état seulement.
  Future<List<OfficineOrder>> orders({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final json = await _api.get('$_base/orders$query') as Map<String, dynamic>;
    return [
      for (final o in (json['items'] as List? ?? const []))
        OfficineOrder.fromJson((o as Map).cast<String, dynamic>()),
    ];
  }

  Future<OfficineOrder> order(int id) async => OfficineOrder.fromJson(
    await _api.get('$_base/orders/$id') as Map<String, dynamic>,
  );

  /// Une action sur la commande : `quote`, `reject`, `confirm-payment`,
  /// `payment-not-received`, `ready`, `missing-product`…
  Future<OfficineOrder> act(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final json = await _api.post(
      '$_base/orders/$id/$action',
      body: body ?? const {},
    );
    final map = json as Map<String, dynamic>;
    // `courier-default` enveloppe la commande : {courier_suspended, order}.
    final order = map['order'] is Map ? map['order'] as Map : map;
    return OfficineOrder.fromJson(order.cast<String, dynamic>());
  }

  Future<OfficineOrder> sendQuote(
    int id, {
    required List<Map<String, dynamic>> items,
    required bool originalRequired,
  }) => act(
    id,
    'quote',
    body: {'items': items, 'original_required': originalRequired},
  );

  /// L'historique d'un mois (Officine 12) : les commandes closes —
  /// livrées, refusées, annulées, expirées — et les chiffres du mois.
  Future<OfficineHistory> history(DateTime month) async {
    final y = month.year.toString().padLeft(4, '0');
    final m = month.month.toString().padLeft(2, '0');
    return OfficineHistory.fromJson(
      await _api.get('$_base/history?month=$y-$m') as Map<String, dynamic>,
    );
  }

  /// Le prix de la course dans le pays, ajouté au devis par Honam : montré
  /// avant l'envoi pour que l'officine voie le total que paiera la patiente.
  Future<int?> deliveryPrice() async {
    final json = await _api.get('/honam/config') as Map<String, dynamic>;
    return (json['delivery_price'] as num?)?.toInt();
  }

  Future<void> setOnDuty(bool onDuty) =>
      _api.post('$_base/on-duty', body: {'on_duty': onDuty});

  /// Ouvre un paiement CashPay ; renvoie l'adresse de la page de paiement.
  Future<String?> subscribe(String plan) async {
    final json =
        await _api.post('$_base/subscribe', body: {'plan': plan})
            as Map<String, dynamic>;
    return json['payment_url'] as String?;
  }

  Future<String?> buyCredit(int amountHt) async {
    final json =
        await _api.post('$_base/credit', body: {'amount_ht': amountHt})
            as Map<String, dynamic>;
    return json['payment_url'] as String?;
  }

  Future<OfficineCouriers> couriers() async => OfficineCouriers.fromJson(
    await _api.get('$_base/couriers') as Map<String, dynamic>,
  );

  Future<AttachedCourier> attachCourier(String phone) async =>
      AttachedCourier.fromJson(
        await _api.post('$_base/couriers', body: {'phone': phone})
            as Map<String, dynamic>,
      );

  Future<void> detachCourier(int userId) =>
      _api.delete('$_base/couriers/$userId');

  // ── Discussion liée à la course (Officine 10) ─────────────────────────

  Future<List<HonamOrderMessage>> messages(int orderId) async {
    final json =
        await _api.get('/honam/orders/$orderId/messages')
            as Map<String, dynamic>;
    return [
      for (final m in (json['items'] as List? ?? const []))
        HonamOrderMessage.fromJson((m as Map).cast<String, dynamic>()),
    ];
  }

  Future<HonamOrderMessage> sendMessage(int orderId, String body) async =>
      HonamOrderMessage.fromJson(
        await _api.post('/honam/orders/$orderId/messages', body: {'body': body})
            as Map<String, dynamic>,
      );
}
