import '../../../core/api/api_client.dart';
import 'honam_models.dart';

class HonamRepository {
  HonamRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<Map<String, String>> emergencyNumbers() async {
    final json = await _api.get('/honam/config') as Map<String, dynamic>;
    return {
      for (final e in ((json['emergency_numbers'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    };
  }

  Future<List<Pharmacy>> pharmacies({double? lat, double? lng}) async {
    final query = lat != null && lng != null ? '?lat=$lat&lng=$lng' : '';
    final json = await _api.get('/honam/pharmacies$query') as Map<String, dynamic>;
    return [
      for (final p in (json['items'] as List? ?? const []))
        Pharmacy.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<List<HonamOrder>> orders() async {
    final json = await _api.get('/honam/orders') as Map<String, dynamic>;
    return [
      for (final o in (json['items'] as List? ?? const []))
        HonamOrder.fromJson(o as Map<String, dynamic>),
    ];
  }

  Future<HonamOrder> order(int id) async =>
      HonamOrder.fromJson(await _api.get('/honam/orders/$id') as Map<String, dynamic>);

  Future<HonamOrder> submit({
    required int pharmacyId,
    required int prescriptionMediaId,
    required String address,
    double? lat,
    double? lng,
    String? note,
  }) async {
    final json = await _api.post(
      '/honam/orders',
      body: {
        'pharmacy_id': pharmacyId,
        'prescription_media_id': prescriptionMediaId,
        'delivery_address': address,
        'delivery_latitude': ?lat,
        'delivery_longitude': ?lng,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return HonamOrder.fromJson(json as Map<String, dynamic>);
  }

  Future<HonamOrder> action(int id, String action, {Map<String, dynamic>? body}) async {
    final json = await _api.post('/honam/orders/$id/$action', body: body ?? const {});
    return HonamOrder.fromJson(json as Map<String, dynamic>);
  }

  // ── Coursier ──────────────────────────────────────────────────────────

  Future<CourierStatus> courierJoin({
    required String zones,
    required String walletPhone,
    String? city,
    String? referralCode,
  }) async => CourierStatus.fromJson(
    await _api.post(
      '/honam/courier/join',
      body: {
        'zones': zones,
        'wallet_phone': walletPhone,
        'accept_rules': true,
        'city': ?city,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
      },
    ) as Map<String, dynamic>,
  );

  Future<HonamCities> cities() async =>
      HonamCities.fromJson(await _api.get('/honam/cities') as Map<String, dynamic>);

  Future<void> joinWaitlist(String city, {String role = 'COURIER'}) =>
      _api.post('/honam/waitlist', body: {'city': city, 'role': role});

  /// [asPharmacy] : le suivi de l'officine (Officine 7), sinon celui du
  /// patient.
  Future<CourierTracking> tracking(int orderId, {bool asPharmacy = false}) async =>
      CourierTracking.fromJson(
        await _api.get(asPharmacy
            ? '/honam/pharmacy/orders/$orderId/tracking'
            : '/honam/orders/$orderId/tracking') as Map<String, dynamic>,
      );

  Future<void> sendLocation(int orderId, double latitude, double longitude) => _api.post(
    '/honam/courier/rides/$orderId/location',
    body: {'latitude': latitude, 'longitude': longitude},
  );

  Future<CourierStatus?> courierMe() async {
    try {
      return CourierStatus.fromJson(
        await _api.get('/honam/courier/me') as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<({List<HonamOrder> available, List<HonamOrder> mine})> rides() async {
    final json = await _api.get('/honam/courier/rides') as Map<String, dynamic>;
    List<HonamOrder> read(String key) => [
      for (final o in (json[key] as List? ?? const []))
        HonamOrder.fromJson(o as Map<String, dynamic>),
    ];
    return (available: read('available'), mine: read('mine'));
  }

  Future<void> rideAction(int id, String action, {Map<String, dynamic>? body}) =>
      _api.post('/honam/courier/rides/$id/$action', body: body ?? const {});

  /// Ouvre un paiement CashPay ; renvoie l'adresse de la page de paiement.
  Future<String?> pay(String path, {Map<String, dynamic>? body}) async {
    final json = await _api.post(path, body: body ?? const {}) as Map<String, dynamic>;
    return json['payment_url'] as String?;
  }
}
