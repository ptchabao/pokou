import '../../../core/time/server_time.dart';

/// HONAM, côté application : l'annuaire, les commandes du patient et le
/// mode coursier. Les noms de médicaments ne sortent jamais du détail d'une
/// commande (HON-04) : l'accueil n'affiche que l'état.
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.isOnDuty,
    this.openingHours,
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  final double? latitude;
  final double? longitude;

  final int id;
  final String name;
  final String address;
  final String phone;
  final bool isOnDuty;
  final String? openingHours;
  final double? distanceKm;

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
    id: json['id'] as int,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    isOnDuty: json['is_on_duty'] as bool? ?? false,
    openingHours: json['opening_hours'] as String?,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

class QuoteItem {
  const QuoteItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.available,
    this.packaging,
    this.generic = false,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final bool available;

  /// Le conditionnement (« 12 gélules ») et le générique proposé à la
  /// place du princeps (maquette Honam patient 3).
  final String? packaging;
  final bool generic;

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
    name: json['name'] as String,
    quantity: json['quantity'] as int? ?? 1,
    unitPrice: json['unit_price'] as int? ?? 0,
    available: json['available'] as bool? ?? true,
    packaging: json['packaging'] as String?,
    generic: json['generic'] as bool? ?? false,
  );
}

class TimelineStep {
  const TimelineStep({required this.status, required this.at, this.note});

  final String status;
  final DateTime at;
  final String? note;

  factory TimelineStep.fromJson(Map<String, dynamic> json) => TimelineStep(
    status: json['status'] as String,
    at: tryParseServerTime(json['at']) ?? DateTime.now(),
    note: json['note'] as String?,
  );
}

class HonamOrderMessage {
  const HonamOrderMessage({
    required this.id,
    required this.body,
    required this.senderRole,
    required this.createdAt,
    this.senderId,
    this.senderName,
    this.readAt,
  });

  final int id;
  final int? senderId;
  final String? senderName;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  /// Lu par l'autre partie du canal (accusé « Lu »).
  final DateTime? readAt;

  factory HonamOrderMessage.fromJson(Map<String, dynamic> json) =>
      HonamOrderMessage(
        id: json['id'] as int,
        senderId: json['sender_id'] as int?,
        senderName: json['sender_name'] as String?,
        senderRole: json['sender_role'] as String? ?? 'UNKNOWN',
        body: json['body'] as String,
        createdAt: tryParseServerTime(json['created_at']) ?? DateTime.now(),
        readAt: tryParseServerTime(json['read_at']),
      );
}

class HonamOrder {
  const HonamOrder({
    required this.id,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
    this.pharmacy,
    this.quoteItems = const [],
    this.medicinesTotal,
    this.deliveryPrice,
    this.total,
    this.payToPhone,
    this.deliveryCode,
    this.originalRequired = false,
    this.rejectionReason,
    this.patientPaidDeclared = false,
    this.paymentNotReceived = false,
    this.missingAmount,
    this.missingReason,
    this.missingChoice,
    this.refundDue = 0,
    this.refundReason,
    this.refundConfirmed = false,
    this.courierName,
    this.courierPaid = false,
    this.timeline = const [],
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryLandmark,
    this.patientNote,
    this.paymentReference,
    this.paymentDeclaredAt,
    this.prescriptionMediaId,
    this.courierUserId,
    this.courierTransport,
    this.patientName,
    this.patientUserId,
    this.pickedUpAt,
    this.incidentKind,
    this.incidentAt,
    this.codeAttemptsLeft,
    this.priority = false,
    this.quoteExpiresAt,
    this.deliveredAt,
  });

  /// Le repère qui aide le coursier (maquette Honam patient 1).
  final String? deliveryLandmark;
  final String? patientNote;

  /// La référence de la transaction, lue dans le SMS de l'opérateur.
  final String? paymentReference;
  final DateTime? paymentDeclaredAt;
  final int? prescriptionMediaId;

  /// Pendant la course : de quoi appeler le coursier par Pokou (numéro
  /// masqué) et dire comment il vient.
  final int? courierUserId;
  final String? courierTransport;

  /// Côté coursier : le prénom du patient, et de quoi l'appeler par Pokou.
  final String? patientName;
  final int? patientUserId;
  final DateTime? pickedUpAt;
  final String? incidentKind;
  final DateTime? incidentAt;
  final int? codeAttemptsLeft;

  /// « Proposée d'abord à toi » (maquette Coursiers 9).
  final bool priority;
  final DateTime? quoteExpiresAt;
  final DateTime? deliveredAt;

  /// Le point de remise, envoyé au seul coursier : il navigue avec
  /// l'application de cartes de son téléphone, pas dans Pokou.
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  final int id;
  final String status;
  final Pharmacy? pharmacy;
  final String deliveryAddress;
  final DateTime createdAt;
  final List<QuoteItem> quoteItems;
  final int? medicinesTotal;
  final int? deliveryPrice;
  final int? total;
  final String? payToPhone;
  final String? deliveryCode;
  final bool originalRequired;
  final String? rejectionReason;
  final bool patientPaidDeclared;
  final bool paymentNotReceived;

  /// Produit manquant signalé pendant la préparation : en attente du choix
  /// de la patiente tant que [missingChoice] est nul.
  final int? missingAmount;
  final String? missingReason;
  final String? missingChoice;
  final int refundDue;
  final String? refundReason;

  bool get awaitsMissingChoice =>
      missingAmount != null && missingChoice == null;
  final bool refundConfirmed;
  final String? courierName;
  final bool courierPaid;
  final List<TimelineStep> timeline;

  bool get isFinished =>
      const {'DELIVERED', 'REJECTED', 'EXPIRED', 'CANCELLED'}.contains(status);

  factory HonamOrder.fromJson(Map<String, dynamic> json) => HonamOrder(
    id: json['id'] as int,
    status: json['status'] as String,
    pharmacy: json['pharmacy'] == null
        ? null
        : Pharmacy.fromJson(json['pharmacy'] as Map<String, dynamic>),
    deliveryAddress: json['delivery_address'] as String? ?? '',
    createdAt: tryParseServerTime(json['created_at']) ?? DateTime.now(),
    quoteItems: [
      for (final item in (json['quote_items'] as List? ?? const []))
        QuoteItem.fromJson(item as Map<String, dynamic>),
    ],
    medicinesTotal: json['medicines_total'] as int?,
    deliveryPrice: json['delivery_price'] as int?,
    total: json['total'] as int?,
    payToPhone: json['pay_to_phone'] as String?,
    deliveryCode: json['delivery_code'] as String?,
    originalRequired: json['original_required'] as bool? ?? false,
    rejectionReason: json['rejection_reason'] as String?,
    patientPaidDeclared: json['patient_paid_declared_at'] != null,
    paymentNotReceived: json['payment_not_received_at'] != null,
    deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
    deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
    missingAmount: json['missing_amount'] as int?,
    missingReason: json['missing_reason'] as String?,
    missingChoice: json['missing_choice'] as String?,
    refundDue: json['refund_due'] as int? ?? 0,
    refundReason: json['refund_reason'] as String?,
    refundConfirmed: json['refund_confirmed_at'] != null,
    courierName: json['courier_name'] as String?,
    courierPaid: json['courier_paid_at'] != null,
    deliveryLandmark: json['delivery_landmark'] as String?,
    patientNote: json['patient_note'] as String?,
    paymentReference: json['payment_reference'] as String?,
    paymentDeclaredAt: tryParseServerTime(json['patient_paid_declared_at']),
    prescriptionMediaId: json['prescription_media_id'] as int?,
    courierUserId: json['courier_user_id'] as int?,
    courierTransport: json['courier_transport'] as String?,
    patientName: json['patient_name'] as String?,
    patientUserId: json['patient_user_id'] as int?,
    pickedUpAt: tryParseServerTime(json['picked_up_at']),
    incidentKind: json['incident_kind'] as String?,
    incidentAt: tryParseServerTime(json['incident_at']),
    codeAttemptsLeft: json['code_attempts_left'] as int?,
    priority: json['priority'] as bool? ?? false,
    quoteExpiresAt: tryParseServerTime(json['quote_expires_at']),
    deliveredAt: tryParseServerTime(json['delivered_at']),
    timeline: [
      for (final step in (json['timeline'] as List? ?? const []))
        TimelineStep.fromJson(step as Map<String, dynamic>),
    ],
  );
}

class CourierPack {
  const CourierPack({
    required this.code,
    required this.label,
    required this.priceHt,
    required this.upgradePriceHt,
    this.rides,
  });

  final String code;
  final String label;
  final int? rides;
  final int priceHt;
  final int upgradePriceHt;

  factory CourierPack.fromJson(Map<String, dynamic> json) => CourierPack(
    code: json['code'] as String,
    label: json['label'] as String,
    rides: json['rides'] as int?,
    priceHt: json['price_ht'] as int,
    upgradePriceHt: json['upgrade_price_ht'] as int,
  );
}

class CourierStatus {
  const CourierStatus({
    required this.status,
    required this.ridesLeft,
    required this.unlimited,
    required this.membershipPriceHt,
    required this.packs,
    this.currentPack,
    this.launchPeriod = false,
    this.queenUnlocked = true,
    this.referralCode,
    this.referralsCount = 0,
    this.referralGiftRides = 0,
    this.recommendedPack,
    this.available = false,
    this.vatRate = 0,
    this.transport,
    this.zonesList = const [],
    this.days = const [],
    this.moments = const [],
    this.walletPhone,
    this.walletVerified = false,
    this.incompleteItem,
    this.incompleteReason,
    this.appliedAt,
    this.validatedAt,
    this.welcomed = false,
    this.trialRides = 5,
    this.trialEndsAt,
    this.packUntil,
    this.packRides,
    this.defaultsCount = 0,
    this.maxDefaults = 3,
    this.reviewRequested = false,
    this.invitedByPharmacy,
    this.city,
    this.monthEarnings = 0,
    this.monthPaidRides = 0,
    this.originalsToReturn = const [],
    this.unacknowledgedDefault,
  });

  /// Disponible : il reçoit les courses (maquettes Coursiers 8, 26, 27).
  final bool available;
  final double vatRate;
  final String? transport;
  final List<String> zonesList;
  final List<String> days;
  final List<String> moments;
  final String? walletPhone;
  final bool walletVerified;

  /// Candidature à compléter (maquette Coursiers 18).
  final String? incompleteItem;
  final String? incompleteReason;
  final DateTime? appliedAt;
  final DateTime? validatedAt;
  final bool welcomed;
  final int trialRides;
  final DateTime? trialEndsAt;
  final DateTime? packUntil;
  final int? packRides;
  final int defaultsCount;
  final int maxDefaults;
  final bool reviewRequested;
  final String? invitedByPharmacy;
  final String? city;

  /// Les gains du mois en cours : le prix des courses livrées.
  final int monthEarnings;
  final int monthPaidRides;
  final List<({int orderId, String? pharmacy, DateTime? dueAt})>
  originalsToReturn;
  final CourierDefault? unacknowledgedDefault;

  /// Parrainage (maquette Coursiers 15) : le code à partager, posé à la
  /// validation de la candidature.
  final String? referralCode;
  final int referralsCount;
  final int referralGiftRides;

  /// Fin d'essai (maquette Coursiers 12) : le pack qui couvre l'activité
  /// réelle.
  final String? recommendedPack;

  final bool launchPeriod;
  final bool queenUnlocked;

  final String status; // PENDING | TRIAL | MEMBER | ENDED | SUSPENDED
  final int ridesLeft;
  final bool unlimited;
  final int membershipPriceHt;
  final List<CourierPack> packs;
  final String? currentPack;

  factory CourierStatus.fromJson(Map<String, dynamic> json) => CourierStatus(
    status: json['status'] as String,
    ridesLeft: json['rides_left'] as int? ?? 0,
    unlimited: json['unlimited'] as bool? ?? false,
    membershipPriceHt: json['membership_price_ht'] as int? ?? 1000,
    currentPack: json['current_pack'] as String?,
    launchPeriod: json['launch_period'] as bool? ?? false,
    queenUnlocked: json['queen_unlocked'] as bool? ?? true,
    referralCode: json['referral_code'] as String?,
    referralsCount: json['referrals_count'] as int? ?? 0,
    referralGiftRides: json['referral_gift_rides'] as int? ?? 0,
    recommendedPack: json['recommended_pack'] as String?,
    packs: [
      for (final pack in (json['packs'] as List? ?? const []))
        CourierPack.fromJson(pack as Map<String, dynamic>),
    ],
    available: json['available'] as bool? ?? false,
    vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 0,
    transport: json['transport'] as String?,
    zonesList: _strings(json['zones_list']),
    days: _strings(json['days']),
    moments: _strings(json['moments']),
    walletPhone: json['wallet_phone'] as String?,
    walletVerified: json['wallet_verified'] as bool? ?? false,
    incompleteItem: json['incomplete_item'] as String?,
    incompleteReason: json['incomplete_reason'] as String?,
    appliedAt: tryParseServerTime(json['applied_at']),
    validatedAt: tryParseServerTime(json['validated_at']),
    welcomed: json['welcomed'] as bool? ?? false,
    trialRides: json['trial_rides'] as int? ?? 5,
    trialEndsAt: tryParseServerTime(json['trial_ends_at']),
    packUntil: tryParseServerTime(json['pack_until']),
    packRides: json['pack_rides'] as int?,
    defaultsCount: json['defaults_count'] as int? ?? 0,
    maxDefaults: json['max_defaults'] as int? ?? 3,
    reviewRequested: json['review_requested_at'] != null,
    invitedByPharmacy: json['invited_by_pharmacy'] as String?,
    city: json['city'] as String?,
    monthEarnings: (json['month'] as Map?)?['earnings'] as int? ?? 0,
    monthPaidRides: (json['month'] as Map?)?['paid_rides'] as int? ?? 0,
    originalsToReturn: [
      for (final o in (json['originals_to_return'] as List? ?? const []))
        (
          orderId: (o as Map)['order_id'] as int,
          pharmacy: o['pharmacy_name'] as String?,
          dueAt: tryParseServerTime(o['due_at']),
        ),
    ],
    unacknowledgedDefault: json['unacknowledged_default'] == null
        ? null
        : CourierDefault.fromJson(
            json['unacknowledged_default'] as Map<String, dynamic>,
          ),
  );
}

List<String> _strings(Object? raw) => [
  for (final item in (raw as List? ?? const [])) item as String,
];

/// Un défaut de livraison signalé par une officine (maquettes Coursiers 20
/// et 21) : daté, motivé, contestable 48 heures.
class CourierDefault {
  const CourierDefault({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.pharmacyName,
    this.orderDate,
    this.contestUntil,
    this.canContest = false,
  });

  final int id;
  final String reason;
  final String status; // CONFIRMED | CONTESTED | CANCELLED
  final DateTime createdAt;
  final String? pharmacyName;
  final DateTime? orderDate;
  final DateTime? contestUntil;
  final bool canContest;

  factory CourierDefault.fromJson(Map<String, dynamic> json) => CourierDefault(
    id: json['id'] as int,
    reason: json['reason'] as String? ?? '',
    status: json['status'] as String? ?? 'CONFIRMED',
    createdAt: tryParseServerTime(json['created_at']) ?? DateTime.now(),
    pharmacyName: json['pharmacy_name'] as String?,
    orderDate: tryParseServerTime(json['order_date']),
    contestUntil: tryParseServerTime(json['contest_until']),
    canContest: json['can_contest'] as bool? ?? false,
  );
}

/// L'offre « Livre pour Honam » (maquettes Coursiers 1 et 25).
class CourierOffer {
  const CourierOffer({
    required this.honamOpen,
    required this.servedCities,
    required this.trialRides,
    required this.membershipPriceTtc,
    required this.packs,
    required this.giftRides,
    this.deliveryPrice,
    this.launchPeriod = false,
    this.inviterName,
    this.inviterCode,
    this.transports = const {},
    this.dismissed = false,
  });

  /// « Ne plus me proposer » : l'offre ne s'affiche plus d'elle-même.
  final bool dismissed;

  final bool honamOpen;
  final List<String> servedCities;
  final int? deliveryPrice;
  final bool launchPeriod;
  final int trialRides;
  final int membershipPriceTtc;
  final List<({String code, String label, int? rides, int priceTtc})> packs;
  final int giftRides;
  final String? inviterName;
  final String? inviterCode;

  /// La portée des courses par moyen de transport, en km.
  final Map<String, double> transports;

  factory CourierOffer.fromJson(Map<String, dynamic> json) => CourierOffer(
    honamOpen: json['honam_open'] as bool? ?? false,
    servedCities: _strings(json['served_cities']),
    deliveryPrice: json['delivery_price'] as int?,
    launchPeriod: json['launch_period'] as bool? ?? false,
    trialRides: json['trial_rides'] as int? ?? 5,
    membershipPriceTtc: json['membership_price_ttc'] as int? ?? 0,
    giftRides: json['referral_gift_rides'] as int? ?? 0,
    packs: [
      for (final p in (json['packs'] as List? ?? const []))
        (
          code: (p as Map)['code'] as String,
          label: p['label'] as String,
          rides: p['rides'] as int?,
          priceTtc: p['price_ttc'] as int? ?? 0,
        ),
    ],
    inviterName: (json['inviter'] as Map?)?['name'] as String?,
    inviterCode: (json['inviter'] as Map?)?['code'] as String?,
    dismissed: json['dismissed'] as bool? ?? false,
    transports: {
      for (final e in ((json['transports'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
  );
}

/// « Mes courses et gains » (maquette Coursiers 22), pour un mois.
class CourierEarnings {
  const CourierEarnings({
    required this.month,
    required this.months,
    required this.rides,
    required this.earnings,
    required this.defaults,
    required this.maxDefaults,
    required this.items,
    this.currentPack,
    this.ridesLeft = 0,
    this.packRides,
    this.walletPhone,
  });

  final String month;
  final List<String> months;
  final int rides;
  final int earnings;
  final int defaults;
  final int maxDefaults;
  final String? currentPack;
  final int ridesLeft;
  final int? packRides;
  final String? walletPhone;
  final List<
    ({
      String? pharmacy,
      String address,
      DateTime deliveredAt,
      int amount,
      bool paid,
    })
  >
  items;

  factory CourierEarnings.fromJson(Map<String, dynamic> json) =>
      CourierEarnings(
        month: json['month'] as String,
        months: _strings(json['months']),
        rides: json['rides'] as int? ?? 0,
        earnings: json['earnings'] as int? ?? 0,
        defaults: json['defaults'] as int? ?? 0,
        maxDefaults: json['max_defaults'] as int? ?? 3,
        currentPack: json['current_pack'] as String?,
        ridesLeft: json['rides_left'] as int? ?? 0,
        packRides: json['pack_rides'] as int?,
        walletPhone: json['wallet_phone'] as String?,
        items: [
          for (final i in (json['items'] as List? ?? const []))
            (
              pharmacy: (i as Map)['pharmacy_name'] as String?,
              address: i['delivery_address'] as String? ?? '',
              deliveredAt:
                  tryParseServerTime(i['delivered_at']) ?? DateTime.now(),
              amount: i['amount'] as int? ?? 0,
              paid: i['paid'] as bool? ?? false,
            ),
        ],
      );
}

/// Où en est la course, vu du patient ou de l'officine. La même chose sert
/// au suivi sans carte et au suivi sur la carte : c'est l'écran qui choisit.
class CourierTracking {
  const CourierTracking({
    required this.active,
    this.courierName,
    this.latitude,
    this.longitude,
    this.at,
    this.stale = false,
    this.distanceKm,
    this.etaMinutes,
    this.pharmacyLatitude,
    this.pharmacyLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.courierUserId,
    this.courierTransport,
    this.courierVerified = false,
    this.pickedUp = false,
  });

  /// Une estimation (distance et allure du moyen de transport), pas une
  /// promesse ; nulle avant le retrait du colis.
  final int? etaMinutes;
  final double? pharmacyLatitude;
  final double? pharmacyLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final int? courierUserId;
  final String? courierTransport;
  final bool courierVerified;
  final bool pickedUp;

  final bool active;
  final String? courierName;
  final double? latitude;
  final double? longitude;
  final DateTime? at;
  final bool stale;
  final double? distanceKm;

  bool get hasPosition => latitude != null && longitude != null;

  factory CourierTracking.fromJson(Map<String, dynamic> json) =>
      CourierTracking(
        active: json['active'] as bool? ?? false,
        courierName: json['courier_name'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        at: json['at'] != null ? parseServerTime(json['at'] as String) : null,
        stale: json['stale'] as bool? ?? false,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        etaMinutes: json['eta_minutes'] as int?,
        pharmacyLatitude: (json['pharmacy_latitude'] as num?)?.toDouble(),
        pharmacyLongitude: (json['pharmacy_longitude'] as num?)?.toDouble(),
        deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
        courierUserId: json['courier_user_id'] as int?,
        courierTransport: json['courier_transport'] as String?,
        courierVerified: json['courier_verified'] as bool? ?? false,
        pickedUp: json['picked_up'] as bool? ?? false,
      );
}

/// Les villes où Honam livre, et l'inscription de la personne sur la liste
/// d'attente, s'il y en a une.
class HonamCities {
  const HonamCities({required this.served, this.waitlistCity});

  final List<String> served;
  final String? waitlistCity;

  factory HonamCities.fromJson(Map<String, dynamic> json) => HonamCities(
    served: [
      for (final c in (json['served_cities'] as List? ?? const [])) c as String,
    ],
    waitlistCity: (json['waitlist'] as Map?)?['city'] as String?,
  );
}
