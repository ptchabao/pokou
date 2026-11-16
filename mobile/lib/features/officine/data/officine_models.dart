import '../../../core/time/server_time.dart';
import '../../honam/data/honam_models.dart' show QuoteItem, TimelineStep;

/// L'espace officine, côté application : ce que lit l'équipe d'une officine
/// rattachée à Honam (`/honam/pharmacy/...`, les mêmes appels que
/// l'application web `/officine`).
///
/// Une commande vue par l'officine porte l'ordonnance et le nom de la
/// patiente, mais jamais le code de remise : il ne part qu'au patient.

DateTime? _at(Object? value) => tryParseServerTime(value);

/// L'officine elle-même, telle que la renvoie `/honam/pharmacy/me`.
class OfficinePharmacy {
  const OfficinePharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.isOnDuty,
    required this.status,
    this.openingHours,
    this.walletPhone,
    this.walletVerified = false,
    this.suspensionReason,
    this.walletPhonePending,
    this.nextDutyOn,
    this.temporarilyClosed = false,
  });

  final int id;
  final String name;
  final String address;
  final String phone;
  final String? openingHours;
  final bool isOnDuty;
  final String? walletPhone;
  final bool walletVerified;

  /// ACTIVE | SUSPENDED | EXCLUDED
  final String status;
  final String? suspensionReason;

  /// Le nouveau wallet demandé, en attente de vérification par l'équipe :
  /// l'ancien reçoit les paiements jusque-là.
  final String? walletPhonePending;

  /// « Prochaine garde » (Officine 13).
  final DateTime? nextDutyOn;

  /// « Fermer temporairement » : les patients ne la voient plus.
  final bool temporarilyClosed;

  factory OfficinePharmacy.fromJson(Map<String, dynamic> json) =>
      OfficinePharmacy(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        openingHours: json['opening_hours'] as String?,
        isOnDuty: json['is_on_duty'] as bool? ?? false,
        walletPhone: json['wallet_phone'] as String?,
        walletVerified: json['wallet_verified'] as bool? ?? false,
        status: json['status'] as String? ?? 'ACTIVE',
        suspensionReason: json['suspension_reason'] as String?,
        walletPhonePending: json['wallet_phone_pending'] as String?,
        nextDutyOn: DateTime.tryParse(json['next_duty_on'] as String? ?? ''),
        temporarilyClosed: json['temporarily_closed'] as bool? ?? false,
      );
}

/// L'accueil de l'espace officine : l'officine, sa visibilité, son
/// abonnement, son crédit et les chiffres du mois.
class OfficineMe {
  const OfficineMe({
    required this.pharmacy,
    required this.visible,
    required this.pricesHt,
    required this.vatRate,
    required this.creditBalanceHt,
    required this.ordersLeft,
    required this.received,
    required this.paid,
    required this.delivered,
    required this.rejected,
    this.plan,
    this.subscriptionUntil,
    this.staffRole,
    this.ringOnOrder = true,
    this.phonesCount = 1,
  });

  final OfficinePharmacy pharmacy;

  /// Ce téléphone du comptoir : TITULAIRE ou COLLABORATEUR. Seul le
  /// titulaire change le wallet et les téléphones du comptoir.
  final String? staffRole;

  /// « Sonnerie à chaque ordonnance », propre à ce téléphone.
  final bool ringOnOrder;
  final int phonesCount;

  bool get isTitulaire => staffRole == 'TITULAIRE';

  /// Visible des patients : active, wallet vérifié, abonnement et crédit.
  final bool visible;

  /// WETRI (mois) | EPE (an), ou rien.
  final String? plan;
  final DateTime? subscriptionUntil;
  final Map<String, int> pricesHt;
  final double vatRate;
  final int creditBalanceHt;
  final int ordersLeft;
  final int received;
  final int paid;
  final int delivered;
  final int rejected;

  bool get subscribed =>
      subscriptionUntil != null && subscriptionUntil!.isAfter(DateTime.now());

  int ttc(int ht) => (ht * (1 + vatRate)).round();

  factory OfficineMe.fromJson(Map<String, dynamic> json) {
    final sub = (json['subscription'] as Map?)?.cast<String, dynamic>() ?? {};
    final credit = (json['credit'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats = (json['stats_month'] as Map?)?.cast<String, dynamic>() ?? {};
    final prices = (sub['prices_ht'] as Map?)?.cast<String, dynamic>() ?? {};
    final staff = (json['staff'] as Map?)?.cast<String, dynamic>() ?? {};
    return OfficineMe(
      staffRole: staff['role'] as String?,
      ringOnOrder: staff['ring_on_order'] as bool? ?? true,
      phonesCount: (json['phones_count'] as num?)?.toInt() ?? 1,
      pharmacy: OfficinePharmacy.fromJson(
        (json['pharmacy'] as Map).cast<String, dynamic>(),
      ),
      visible: json['visible'] as bool? ?? false,
      plan: sub['plan'] as String?,
      subscriptionUntil: _at(sub['until']),
      pricesHt: {
        for (final e in prices.entries) e.key: (e.value as num?)?.toInt() ?? 0,
      },
      vatRate: (sub['vat_rate'] as num?)?.toDouble() ?? 0,
      creditBalanceHt: (credit['balance_ht'] as num?)?.toInt() ?? 0,
      ordersLeft: (credit['orders_left'] as num?)?.toInt() ?? 0,
      received: (stats['received'] as num?)?.toInt() ?? 0,
      paid: (stats['paid'] as num?)?.toInt() ?? 0,
      delivered: (stats['delivered'] as num?)?.toInt() ?? 0,
      rejected: (stats['rejected'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Une commande, vue de l'officine.
class OfficineOrder {
  const OfficineOrder({
    required this.id,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
    this.updatedAt,
    this.patientName,
    this.patientNote,
    this.prescriptionMediaId,
    this.quoteItems = const [],
    this.medicinesTotal,
    this.deliveryPrice,
    this.total,
    this.quoteExpiresAt,
    this.originalRequired = false,
    this.originalCollectedAt,
    this.originalReturnedAt,
    this.rejectionReason,
    this.patientPaidDeclaredAt,
    this.paymentNotReceivedAt,
    this.missingAmount,
    this.missingReason,
    this.missingChoice,
    this.refundDue = 0,
    this.refundReason,
    this.refundToPhone,
    this.refundRequestedAt,
    this.refundSentAt,
    this.refundReference,
    this.refundConfirmedAt,
    this.courierName,
    this.courierPaidAt,
    this.courierPaidDeclaredAt,
    this.courierWalletPhone,
    this.deliveredAt,
    this.timeline = const [],
    this.courierUserId,
    this.courierChatClosesAt,
    this.pickupProposedAt,
    this.pickupAtPharmacy = false,
    this.deliveryDistanceKm,
    this.dispatch,
  });

  final int id;
  final String status;
  final String deliveryAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? patientName;
  final String? patientNote;
  final int? prescriptionMediaId;
  final List<QuoteItem> quoteItems;
  final int? medicinesTotal;
  final int? deliveryPrice;
  final int? total;
  final DateTime? quoteExpiresAt;

  /// L'officine a demandé l'ordonnance originale au devis (écran 2b) : le
  /// coursier la récupère à la remise et la rapporte.
  final bool originalRequired;
  final DateTime? originalCollectedAt;
  final DateTime? originalReturnedAt;
  final String? rejectionReason;
  final DateTime? patientPaidDeclaredAt;
  final DateTime? paymentNotReceivedAt;
  final int? missingAmount;
  final String? missingReason;

  /// KEEP (recevoir le reste) | CANCEL (tout annuler) | rien : en attente.
  final String? missingChoice;
  final int refundDue;
  final String? refundReason;

  /// Le seul numéro sur lequel rembourser : celui qui a payé.
  final String? refundToPhone;

  /// Le début du délai de 2 h pour rembourser.
  final DateTime? refundRequestedAt;
  final DateTime? refundSentAt;
  final String? refundReference;
  final DateTime? refundConfirmedAt;
  final String? courierName;

  /// Le coursier a confirmé avoir reçu le prix de la course.
  final DateTime? courierPaidAt;

  /// L'officine a déclaré avoir payé la course.
  final DateTime? courierPaidDeclaredAt;

  /// Le wallet du coursier, pour lui payer la course après la livraison.
  final String? courierWalletPhone;
  final DateTime? deliveredAt;
  final List<TimelineStep> timeline;

  /// Le coursier, pour un appel relayé par Pokou : jamais son numéro. Rien
  /// quand la discussion avec lui est fermée.
  final int? courierUserId;

  /// 24 h après la livraison, la discussion avec le coursier se ferme.
  final DateTime? courierChatClosesAt;

  /// Le retrait à l'officine proposé à la patiente (Officine 9), puis
  /// accepté : la commande se remet alors au comptoir.
  final DateTime? pickupProposedAt;
  final bool pickupAtPharmacy;

  /// De l'officine à l'adresse de livraison (« 5,8 km »).
  final double? deliveryDistanceKm;

  /// La recherche d'un coursier, tant qu'elle dure (Officine 8 et 9).
  final OfficineDispatch? dispatch;

  bool get courierChatClosed =>
      courierChatClosesAt != null &&
      courierChatClosesAt!.isBefore(DateTime.now().toUtc());

  bool get isFinished =>
      const {'DELIVERED', 'REJECTED', 'EXPIRED', 'CANCELLED'}.contains(status);

  bool get awaitsMissingChoice =>
      missingAmount != null && missingChoice == null;

  /// La file « À traiter » : ce qui attend un geste de l'officine.
  bool get needsAction =>
      status == 'SUBMITTED' ||
      (status == 'ACCEPTED' && patientPaidDeclaredAt != null) ||
      status == 'PAID';

  String get patientLabel => (patientName ?? '').trim();

  /// Encaissé auprès de la patiente : médicaments et course.
  int get collected => (medicinesTotal ?? 0) + (deliveryPrice ?? 0);

  DateTime? stepTime(String status) {
    final steps = timeline.where((s) => s.status == status);
    return steps.isEmpty ? null : steps.last.at;
  }

  factory OfficineOrder.fromJson(Map<String, dynamic> json) => OfficineOrder(
    id: json['id'] as int,
    status: json['status'] as String,
    deliveryAddress: json['delivery_address'] as String? ?? '',
    createdAt: _at(json['created_at']) ?? DateTime.now(),
    updatedAt: _at(json['updated_at']),
    patientName: json['patient_name'] as String?,
    patientNote: json['patient_note'] as String?,
    prescriptionMediaId: json['prescription_media_id'] as int?,
    quoteItems: [
      for (final item in (json['quote_items'] as List? ?? const []))
        QuoteItem.fromJson((item as Map).cast<String, dynamic>()),
    ],
    medicinesTotal: json['medicines_total'] as int?,
    deliveryPrice: json['delivery_price'] as int?,
    total: json['total'] as int?,
    quoteExpiresAt: _at(json['quote_expires_at']),
    originalRequired: json['original_required'] as bool? ?? false,
    originalCollectedAt: _at(json['original_collected_at']),
    originalReturnedAt: _at(json['original_returned_at']),
    rejectionReason: json['rejection_reason'] as String?,
    patientPaidDeclaredAt: _at(json['patient_paid_declared_at']),
    paymentNotReceivedAt: _at(json['payment_not_received_at']),
    missingAmount: json['missing_amount'] as int?,
    missingReason: json['missing_reason'] as String?,
    missingChoice: json['missing_choice'] as String?,
    refundDue: json['refund_due'] as int? ?? 0,
    refundReason: json['refund_reason'] as String?,
    refundToPhone: json['refund_to_phone'] as String?,
    refundRequestedAt: _at(json['refund_requested_at']),
    refundSentAt: _at(json['refund_sent_at']),
    refundReference: json['refund_reference'] as String?,
    refundConfirmedAt: _at(json['refund_confirmed_at']),
    courierName: json['courier_name'] as String?,
    courierPaidAt: _at(json['courier_paid_at']),
    courierPaidDeclaredAt: _at(json['courier_paid_declared_at']),
    courierWalletPhone: json['courier_wallet_phone'] as String?,
    deliveredAt: _at(json['delivered_at']),
    timeline: [
      for (final step in (json['timeline'] as List? ?? const []))
        TimelineStep.fromJson((step as Map).cast<String, dynamic>()),
    ],
    courierUserId: json['courier_user_id'] as int?,
    courierChatClosesAt: _at(json['courier_chat_closes_at']),
    pickupProposedAt: _at(json['pickup_proposed_at']),
    pickupAtPharmacy: json['pickup_at_pharmacy'] as bool? ?? false,
    deliveryDistanceKm: (json['delivery_distance_km'] as num?)?.toDouble(),
    dispatch: json['dispatch'] is Map
        ? OfficineDispatch.fromJson(
            (json['dispatch'] as Map).cast<String, dynamic>(),
          )
        : null,
  );
}

/// La recherche d'un coursier, telle que le serveur la mène : proposée
/// d'abord aux livreurs habituels, puis aux coursiers de la zone, dans un
/// rayon autour de l'officine.
class OfficineDispatch {
  const OfficineDispatch({
    required this.radiusKm,
    required this.wideRadiusKm,
    required this.availableCount,
    this.startedAt,
    this.cancelledAt,
    this.attachedCount = 0,
    this.unanswered = const [],
    this.priorityMinutes = 5,
    this.noCourierMinutes = 10,
    this.area,
  });

  /// Début de la recherche, remis à zéro à chaque relance.
  final DateTime? startedAt;

  /// L'officine a annulé la demande : la course n'est plus proposée.
  final DateTime? cancelledAt;
  final double radiusKm;
  final double wideRadiusKm;

  /// Les coursiers disponibles dans le rayon.
  final int availableCount;
  final int attachedCount;

  /// Les livreurs habituels qui n'ont pas pris la course pendant leur
  /// avance (« Kodjo n'a pas répondu »).
  final List<String> unanswered;
  final int priorityMinutes;
  final int noCourierMinutes;

  /// Le quartier de l'officine (« autour de Tokoin »).
  final String? area;

  bool get cancelled => cancelledAt != null;
  bool get canWiden => radiusKm < wideRadiusKm;

  factory OfficineDispatch.fromJson(Map<String, dynamic> json) =>
      OfficineDispatch(
        startedAt: _at(json['started_at']),
        cancelledAt: _at(json['cancelled_at']),
        radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 5,
        wideRadiusKm: (json['wide_radius_km'] as num?)?.toDouble() ?? 8,
        availableCount: (json['available_count'] as num?)?.toInt() ?? 0,
        attachedCount: (json['attached_count'] as num?)?.toInt() ?? 0,
        unanswered: [
          for (final name in (json['unanswered'] as List? ?? const [])) '$name',
        ],
        priorityMinutes: (json['priority_minutes'] as num?)?.toInt() ?? 5,
        noCourierMinutes: (json['no_courier_minutes'] as num?)?.toInt() ?? 10,
        area: json['area'] as String?,
      );
}

/// Un téléphone du comptoir : le compte Pokou d'un membre de l'équipe,
/// numéro masqué.
class CounterPhone {
  const CounterPhone({
    required this.id,
    required this.role,
    this.name,
    this.phoneMasked,
    this.me = false,
  });

  final int id;
  final String? name;
  final String? phoneMasked;

  /// TITULAIRE | COLLABORATEUR
  final String role;

  /// Ce téléphone-ci.
  final bool me;

  factory CounterPhone.fromJson(Map<String, dynamic> json) => CounterPhone(
    id: json['id'] as int,
    name: json['name'] as String?,
    phoneMasked: json['phone_masked'] as String?,
    role: json['role'] as String? ?? 'COLLABORATEUR',
    me: json['me'] as bool? ?? false,
  );
}

/// Un livreur habituel rattaché à l'officine (Officine 6).
class AttachedCourier {
  const AttachedCourier({
    required this.userId,
    required this.status,
    this.name,
    this.phone,
    this.zones,
    this.deliveredCount = 0,
    this.unpaidCount = 0,
    this.defaultsCount = 0,
  });

  final int userId;
  final String? name;
  final String? phone;

  /// TRIAL | MEMBER | ENDED | SUSPENDED
  final String status;
  final String? zones;
  final int deliveredCount;
  final int unpaidCount;
  final int defaultsCount;

  factory AttachedCourier.fromJson(Map<String, dynamic> json) =>
      AttachedCourier(
        userId: json['user_id'] as int,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'TRIAL',
        zones: json['zones'] as String?,
        deliveredCount: json['delivered_count'] as int? ?? 0,
        unpaidCount: json['unpaid_count'] as int? ?? 0,
        defaultsCount: json['defaults_count'] as int? ?? 0,
      );
}

/// La liste des livreurs habituels, et l'avance qu'ils ont sur les autres.
class OfficineCouriers {
  const OfficineCouriers({required this.items, required this.priorityMinutes});

  final List<AttachedCourier> items;
  final int priorityMinutes;

  factory OfficineCouriers.fromJson(Map<String, dynamic> json) =>
      OfficineCouriers(
        items: [
          for (final c in (json['items'] as List? ?? const []))
            AttachedCourier.fromJson((c as Map).cast<String, dynamic>()),
        ],
        priorityMinutes: json['priority_minutes'] as int? ?? 5,
      );
}

/// Un mois d'historique : les commandes closes et ses chiffres.
class OfficineHistory {
  const OfficineHistory({
    required this.items,
    required this.delivered,
    required this.collected,
    required this.cancelled,
  });

  final List<OfficineOrder> items;
  final int delivered;

  /// Encaissé sur les commandes livrées : médicaments et courses.
  final int collected;

  /// Refusées, annulées ou expirées.
  final int cancelled;

  factory OfficineHistory.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    return OfficineHistory(
      items: [
        for (final o in (json['items'] as List? ?? const []))
          OfficineOrder.fromJson((o as Map).cast<String, dynamic>()),
      ],
      delivered: (stats['delivered'] as num?)?.toInt() ?? 0,
      collected: (stats['collected'] as num?)?.toInt() ?? 0,
      cancelled: (stats['cancelled'] as num?)?.toInt() ?? 0,
    );
  }
}
