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
  });

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
  );
}

class QuoteItem {
  const QuoteItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.available,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final bool available;

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
    name: json['name'] as String,
    quantity: json['quantity'] as int? ?? 1,
    unitPrice: json['unit_price'] as int? ?? 0,
    available: json['available'] as bool? ?? true,
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
  });

  final int id;
  final int? senderId;
  final String? senderName;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  factory HonamOrderMessage.fromJson(Map<String, dynamic> json) =>
      HonamOrderMessage(
        id: json['id'] as int,
        senderId: json['sender_id'] as int?,
        senderName: json['sender_name'] as String?,
        senderRole: json['sender_role'] as String? ?? 'UNKNOWN',
        body: json['body'] as String,
        createdAt: tryParseServerTime(json['created_at']) ?? DateTime.now(),
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
  });

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
  });

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
  });

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
