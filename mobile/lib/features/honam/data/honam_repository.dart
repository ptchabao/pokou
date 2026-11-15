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
    final json =
        await _api.get('/honam/pharmacies$query') as Map<String, dynamic>;
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

  Future<HonamOrder> order(int id) async => HonamOrder.fromJson(
    await _api.get('/honam/orders/$id') as Map<String, dynamic>,
  );

  Future<List<HonamOrderMessage>> orderMessages(int id) async {
    final json =
        await _api.get('/honam/orders/$id/messages') as Map<String, dynamic>;
    return [
      for (final item in (json['items'] as List? ?? const []))
        HonamOrderMessage.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<HonamOrderMessage> sendOrderMessage(int id, String body) async =>
      HonamOrderMessage.fromJson(
        await _api.post('/honam/orders/$id/messages', body: {'body': body})
            as Map<String, dynamic>,
      );

  Future<HonamOrder> submit({
    required int pharmacyId,
    required int prescriptionMediaId,
    required String address,
    double? lat,
    double? lng,
    String? note,
    String? landmark,
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
        if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      },
    );
    return HonamOrder.fromJson(json as Map<String, dynamic>);
  }

  Future<HonamOrder> action(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final json = await _api.post(
      '/honam/orders/$id/$action',
      body: body ?? const {},
    );
    return HonamOrder.fromJson(json as Map<String, dynamic>);
  }

  // ── Coursier ──────────────────────────────────────────────────────────

  /// La candidature (maquettes Coursiers 2 à 6).
  Future<CourierStatus> courierJoin({
    required String walletPhone,
    required List<String> zones,
    String? city,
    String? referralCode,
    DateTime? birthDate,
    String? transport,
    String? idDocType,
    int? idFrontMediaId,
    int? idBackMediaId,
    int? selfieMediaId,
    List<String> days = const [],
    List<String> moments = const [],
    bool quizPassed = false,
  }) async => CourierStatus.fromJson(
    await _api.post(
          '/honam/courier/join',
          body: {
            'zones_list': zones,
            'wallet_phone': walletPhone,
            'accept_rules': true,
            'quiz_passed': quizPassed,
            'city': ?city,
            if (referralCode != null && referralCode.isNotEmpty)
              'referral_code': referralCode,
            if (birthDate != null)
              'birth_date':
                  '${birthDate.year.toString().padLeft(4, '0')}-'
                  '${birthDate.month.toString().padLeft(2, '0')}-'
                  '${birthDate.day.toString().padLeft(2, '0')}',
            'transport': ?transport,
            'id_doc_type': ?idDocType,
            'id_front_media_id': ?idFrontMediaId,
            'id_back_media_id': ?idBackMediaId,
            'selfie_media_id': ?selfieMediaId,
            'days': days,
            'moments': moments,
          },
        )
        as Map<String, dynamic>,
  );

  Future<CourierOffer> courierOffer({String? code}) async =>
      CourierOffer.fromJson(
        await _api.get(
              code == null
                  ? '/honam/courier/offer'
                  : '/honam/courier/offer?code=${Uri.encodeQueryComponent(code)}',
            )
            as Map<String, dynamic>,
      );

  Future<void> dismissCourierOffer() =>
      _api.post('/honam/courier/offer/dismiss', body: const {});

  Future<void> walletSendCode(String phone) =>
      _api.post('/honam/courier/wallet/send-code', body: {'wallet_phone': phone});

  Future<void> walletVerify(String phone, String code) => _api.post(
    '/honam/courier/wallet/verify',
    body: {'wallet_phone': phone, 'code': code},
  );

  Future<CourierStatus> courierIdentity({int? selfie, int? front, int? back}) async =>
      CourierStatus.fromJson(
        await _api.post(
              '/honam/courier/identity',
              body: {
                'selfie_media_id': ?selfie,
                'id_front_media_id': ?front,
                'id_back_media_id': ?back,
              },
            )
            as Map<String, dynamic>,
      );

  Future<CourierStatus> courierPost(String path, {Map<String, dynamic>? body}) async =>
      CourierStatus.fromJson(
        await _api.post('/honam/courier/$path', body: body ?? const {})
            as Map<String, dynamic>,
      );

  Future<CourierEarnings> earnings({String? month}) async =>
      CourierEarnings.fromJson(
        await _api.get(
              month == null
                  ? '/honam/courier/earnings'
                  : '/honam/courier/earnings?month=$month',
            )
            as Map<String, dynamic>,
      );

  Future<List<CourierDefault>> defaults() async {
    final json = await _api.get('/honam/courier/defaults') as Map<String, dynamic>;
    return [
      for (final d in (json['items'] as List? ?? const []))
        CourierDefault.fromJson(d as Map<String, dynamic>),
    ];
  }

  Future<void> defaultAction(int id, String action, {String? note}) => _api.post(
    '/honam/courier/defaults/$id/$action',
    body: {'note': ?note},
  );

  Future<({String? code, List<({String? name, String state, int? gift})> items})>
  referrals() async {
    final json = await _api.get('/honam/courier/referrals') as Map<String, dynamic>;
    return (
      code: json['code'] as String?,
      items: [
        for (final i in (json['items'] as List? ?? const []))
          (
            name: (i as Map)['name'] as String?,
            state: i['state'] as String? ?? 'APPLYING',
            gift: i['gift_rides'] as int?,
          ),
      ],
    );
  }

  Future<int> waitlistCount(String city) async {
    final json =
        await _api.get('/honam/waitlist/count?city=${Uri.encodeQueryComponent(city)}')
            as Map<String, dynamic>;
    return json['count'] as int? ?? 0;
  }

  Future<HonamCities> cities() async => HonamCities.fromJson(
    await _api.get('/honam/cities') as Map<String, dynamic>,
  );

  Future<void> joinWaitlist(String city, {String role = 'COURIER'}) =>
      _api.post('/honam/waitlist', body: {'city': city, 'role': role});

  /// [asPharmacy] : le suivi de l'officine (Officine 7), sinon celui du
  /// patient.
  Future<CourierTracking> tracking(
    int orderId, {
    bool asPharmacy = false,
  }) async => CourierTracking.fromJson(
    await _api.get(
          asPharmacy
              ? '/honam/pharmacy/orders/$orderId/tracking'
              : '/honam/orders/$orderId/tracking',
        )
        as Map<String, dynamic>,
  );

  Future<void> sendLocation(int orderId, double latitude, double longitude) =>
      _api.post(
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

  Future<void> rideAction(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) => _api.post('/honam/courier/rides/$id/$action', body: body ?? const {});

  /// Ouvre un paiement CashPay ; renvoie l'adresse de la page de paiement.
  Future<String?> pay(String path, {Map<String, dynamic>? body}) async {
    final json =
        await _api.post(path, body: body ?? const {}) as Map<String, dynamic>;
    return json['payment_url'] as String?;
  }
}
