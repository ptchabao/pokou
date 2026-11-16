"""HONAM — ordonnance, devis du pharmacien, paiement à l'officine, coursier.

Pokou ne touche jamais l'argent des médicaments ni des courses : le patient
paie l'officine de wallet à wallet, l'officine paie le coursier de la même
façon (BM-09). Pokou encaisse seulement ce que les professionnels lui
doivent — abonnement d'officine, crédit par commande, adhésion et packs des
coursiers — par CashPay.

Les officines sont présentées au format ANNUAIRE (BM-12) : mêmes champs pour
toutes, triées par distance, sans aucune mise en avant. Les Ordres des
pharmaciens du Togo et de Côte d'Ivoire n'autorisent pas autre chose.
"""
from datetime import datetime

from sqlalchemy import JSON, Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint

from app.core.database import Base


class Pharmacy(Base):
    __tablename__ = "honam_pharmacies"

    id = Column(Integer, primary_key=True, index=True)
    country = Column(String(2), nullable=False, index=True)
    name = Column(String(160), nullable=False)
    address = Column(String(255), nullable=False)
    phone = Column(String(32), nullable=False)
    #: Horaires lisibles tels que l'officine les donne (« Lun-Sam 8h-21h »).
    opening_hours = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    #: De garde : posé par l'officine ou par l'équipe selon le tour de garde.
    is_on_duty = Column(Boolean, default=False, nullable=False)
    #: Le wallet qui reçoit les paiements des patients. Vérifié par l'équipe
    #: (BM-02) : un wallet faux enverrait l'argent des patients ailleurs.
    wallet_phone = Column(String(32), nullable=True)
    wallet_verified = Column(Boolean, default=False, nullable=False)
    #: WETRI (mensuel) | EPE (annuel) — Wétri HONAM et ÉPÉ HONAM.
    subscription_plan = Column(String(8), nullable=True)
    subscription_until = Column(DateTime, nullable=True)
    #: Fin d'abonnement couverte par chaque relance, pour éviter de la
    #: renvoyer à chaque passage du scheduler.
    subscription_reminder_7d_for = Column(DateTime, nullable=True)
    subscription_reminder_1d_for = Column(DateTime, nullable=True)
    #: Crédit prépayé, en FCFA HT, décompté de 100 à chaque commande PAYÉE
    #: (BM-11).
    credit_balance = Column(Integer, default=0, nullable=False)
    #: Début du délai de 7 jours après épuisement du crédit.
    credit_exhausted_at = Column(DateTime, nullable=True)
    #: ACTIVE | SUSPENDED (remboursement ou course impayés, HON-35) | EXCLUDED
    status = Column(String(10), default="ACTIVE", nullable=False, index=True)
    suspension_reason = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PharmacyStaff(Base):
    """Le pharmacien titulaire et ses collaborateurs."""
    __tablename__ = "honam_pharmacy_staff"

    id = Column(Integer, primary_key=True, index=True)
    pharmacy_id = Column(Integer, ForeignKey("honam_pharmacies.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(12), default="COLLABORATEUR", nullable=False)  # TITULAIRE|COLLABORATEUR


class PharmacyApplication(Base):
    """« Référencer votre officine » (maquettes Officine 14 à 16).

    Le pharmacien remplit le dossier depuis l'application : nom, adresse,
    n° d'autorisation d'exercice, wallet de réception, arrêté d'autorisation
    d'ouverture, et la formule choisie. Le support vérifie l'autorisation et
    le wallet sous 48 h, comme un dossier Pokou certifié Pro ; l'officine
    n'est créée qu'à la validation, puis s'ouvre au paiement de la formule
    depuis l'espace officine.
    """
    __tablename__ = "honam_pharmacy_applications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    country = Column(String(2), nullable=False, index=True)
    name = Column(String(160), nullable=False)
    address = Column(String(255), nullable=False)
    #: Le n° d'autorisation d'exercice, « tel qu'il figure sur l'arrêté ».
    license_number = Column(String(64), nullable=False)
    wallet_phone = Column(String(32), nullable=False)
    #: L'arrêté d'autorisation d'ouverture (photo ou PDF). Visible du seul
    #: support, jamais renvoyé à l'application.
    authorization_media_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    #: WETRI | EPE : la formule payée une fois le dossier validé.
    plan = Column(String(8), nullable=False)
    #: La position du téléphone à l'envoi, si la personne l'a permise ; le
    #: support peut la corriger à la validation (l'annuaire en a besoin).
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    #: PENDING (en vérification) | APPROVED (officine créée) | REJECTED
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    review_note = Column(String(500), nullable=True)
    submitted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    #: L'engagement affiché : décision sous 48 h.
    review_due_at = Column(DateTime, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)
    reviewer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    pharmacy_id = Column(Integer, ForeignKey("honam_pharmacies.id", ondelete="SET NULL"), nullable=True)


class HonamOrder(Base):
    """Une commande, de l'ordonnance à la remise du colis.

    États (voir services/honam/order_flow.py pour les transitions permises) :
    SUBMITTED → QUOTED → ACCEPTED → PAID → READY → IN_DELIVERY → DELIVERED,
    avec REJECTED (ordonnance refusée), EXPIRED (devis sans réponse) et
    CANCELLED (avant paiement).
    """
    __tablename__ = "honam_orders"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    pharmacy_id = Column(Integer, ForeignKey("honam_pharmacies.id", ondelete="CASCADE"), nullable=False, index=True)
    courier_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    status = Column(String(12), default="SUBMITTED", nullable=False, index=True)
    prescription_media_id = Column(Integer, ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True)
    patient_note = Column(String(500), nullable=True)
    delivery_address = Column(String(255), nullable=False)
    #: Le repère qui aide le coursier à trouver la porte (« portail bleu face
    #: au kiosque ») — maquette Honam patient 1.
    delivery_landmark = Column(String(255), nullable=True)
    delivery_latitude = Column(Float, nullable=True)
    delivery_longitude = Column(Float, nullable=True)
    #: Le coursier doit rapporter l'ordonnance ORIGINALE à l'officine
    #: (médicaments soumis à prescription stricte).
    original_required = Column(Boolean, default=False, nullable=False)
    original_collected_at = Column(DateTime, nullable=True)
    #: L'officine confirme avoir récupéré l'original que le coursier a
    #: rapporté (maquette Coursiers 8, « Original à rapporter »).
    original_returned_at = Column(DateTime, nullable=True)
    #: [{"name", "quantity", "unit_price", "available"}] — jamais affiché
    #: hors du détail de la commande (HON-04).
    quote_items = Column(JSON, nullable=True)
    medicines_total = Column(Integer, nullable=True)
    delivery_price = Column(Integer, nullable=True)
    quote_expires_at = Column(DateTime, nullable=True)
    rejection_reason = Column(String(255), nullable=True)
    #: Code à 6 chiffres que le patient donne au coursier à la remise. En
    #: clair parce que le patient doit pouvoir le relire ; seul le patient
    #: le reçoit dans une réponse, jamais l'officine ni le coursier.
    delivery_code = Column(String(6), nullable=True)
    #: Codes faux saisis par le coursier : 5 au plus (maquette Coursiers 11).
    code_attempts = Column(Integer, default=0, nullable=False)
    #: Produit manquant, signalé PENDANT LA PRÉPARATION, avant tout appel de
    #: coursier : la patiente choisit de recevoir le reste (KEEP) ou de tout
    #: annuler (CANCEL). Tant qu'elle n'a pas choisi, la commande n'avance pas.
    missing_amount = Column(Integer, nullable=True)
    missing_reason = Column(String(255), nullable=True)
    missing_choice = Column(String(8), nullable=True)
    #: Début des 15 minutes laissées à la patiente pour choisir ; sans
    #: réponse, tout est annulé et remboursé (maquette Honam patient 6).
    missing_reported_at = Column(DateTime, nullable=True)
    #: Ce que l'officine doit rembourser, au seul numéro qui a payé, sous
    #: 2 heures à compter du choix (maquette « A2. Rembourser Afi »).
    refund_due = Column(Integer, default=0, nullable=False)
    refund_requested_at = Column(DateTime, nullable=True)
    refund_reason = Column(String(255), nullable=True)
    refund_confirmed_at = Column(DateTime, nullable=True)
    #: L'officine dit avoir remboursé (maquette A2) : quand, et la référence
    #: du transfert. La patiente confirme ensuite (refund_confirmed_at).
    refund_sent_at = Column(DateTime, nullable=True)
    refund_reference = Column(String(40), nullable=True)
    #: Le coursier confirme avoir reçu le prix de la course de l'officine.
    courier_paid_at = Column(DateTime, nullable=True)
    #: L'officine dit avoir payé la course (maquette 4b, « J'ai payé
    #: Kodjo ») ; le coursier confirme ensuite (courier_paid_at).
    courier_paid_declared_at = Column(DateTime, nullable=True)
    #: Le patient a signalé avoir payé ; l'officine confirme (PAID) ou
    #: répond « paiement non reçu ».
    patient_paid_declared_at = Column(DateTime, nullable=True)
    payment_not_received_at = Column(DateTime, nullable=True)
    #: La référence de la transaction, lue dans le SMS de l'opérateur
    #: (maquette Honam patient 4) : elle aide l'officine à retrouver l'envoi.
    payment_reference = Column(String(64), nullable=True)
    #: Un problème pendant la course (maquette Coursiers 19) : NO_ANSWER
    #: (patient injoignable), ADDRESS (adresse introuvable), CODE (code
    #: refusé) ou ACCIDENT (accident ou panne).
    incident_kind = Column(String(10), nullable=True)
    incident_at = Column(DateTime, nullable=True)
    #: Dernière position du coursier, envoyée toutes les 15 s PENDANT la
    #: course et effacée à la remise : jamais d'historique de trajet.
    courier_latitude = Column(Float, nullable=True)
    courier_longitude = Column(Float, nullable=True)
    courier_location_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    delivered_at = Column(DateTime, nullable=True)


class HonamOrderEvent(Base):
    """Le fil de suivi (NAV-04) : chaque transition, et qui l'a faite."""
    __tablename__ = "honam_order_events"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("honam_orders.id", ondelete="CASCADE"), nullable=False, index=True)
    actor_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    status = Column(String(12), nullable=False)
    note = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class HonamOrderMessage(Base):
    """Un message texte visible uniquement aux participants d'une commande."""
    __tablename__ = "honam_order_messages"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("honam_orders.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    sender_role = Column(String(12), nullable=False)
    #: patient (patiente ↔ officine) | coursier (officine ↔ coursier) |
    #: livraison (patiente ↔ coursier) — voir services/honam/channels.py.
    channel = Column(String(10), nullable=False, default="patient", server_default="patient", index=True)
    #: Pour les canaux du coursier : le coursier de la course au moment du
    #: message. Un coursier remplacé ne relit pas ce qui a suivi, ni l'autre.
    courier_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    body = Column(String(1000), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class CourierProfile(Base):
    """Le mode coursier d'un utilisateur Pokou (BM-08)."""
    __tablename__ = "honam_couriers"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    country = Column(String(2), nullable=False)
    #: PENDING (candidature à valider) | TRIAL (5 courses offertes, un mois)
    #: | MEMBER (Win Pokou) | ENDED (essai fini, pas d'adhésion) | SUSPENDED
    #: (3 défauts, BM-05)
    status = Column(String(10), default="PENDING", nullable=False, index=True)
    #: Candidature (maquettes Coursiers 3 à 6) : zones et créneaux, wallet
    #: qui reçoit le prix des courses, règles d'or acceptées.
    zones = Column(String(255), nullable=True)
    #: Les mêmes choix, structurés (maquette Coursiers 4) : quartiers, jours
    #: (« MON »…« SUN ») et moments (MORNING, NOON, AFTERNOON, EVENING).
    zones_list = Column(JSON, nullable=True)
    days = Column(JSON, nullable=True)
    moments = Column(JSON, nullable=True)
    #: Maquette Coursiers 2 : le mode coursier n'est ouvert qu'aux 18 ans et
    #: plus ; le moyen de transport règle la distance des courses proposées.
    birth_date = Column(Date, nullable=True)
    transport = Column(String(6), nullable=True)  # MOTO | VELO | PIED
    #: Maquette Coursiers 3 : la pièce (CNI | PASSPORT | VOTER), ses deux
    #: faces et un selfie. Supprimées 30 jours après la décision.
    id_doc_type = Column(String(10), nullable=True)
    id_front_media_id = Column(Integer, nullable=True)
    id_back_media_id = Column(Integer, nullable=True)
    selfie_media_id = Column(Integer, nullable=True)
    #: Candidature à compléter (maquette Coursiers 18) : ce qui est à
    #: reprendre (SELFIE | ID_FRONT | ID_BACK | WALLET) et pourquoi.
    incomplete_item = Column(String(10), nullable=True)
    incomplete_reason = Column(String(255), nullable=True)
    #: Le quiz des règles d'or réussi (maquette Coursiers 6).
    quiz_passed_at = Column(DateTime, nullable=True)
    #: Ville desservie où le coursier livre (configuration `honam_cities`).
    city = Column(String(80), nullable=True)
    wallet_phone = Column(String(32), nullable=True)
    #: Le numéro du wallet vérifié par un code SMS (maquette Coursiers 5).
    wallet_verified_at = Column(DateTime, nullable=True)
    rules_accepted_at = Column(DateTime, nullable=True)
    validated_at = Column(DateTime, nullable=True)
    trial_ends_at = Column(DateTime, nullable=True)
    membership_until = Column(DateTime, nullable=True)
    #: Le pack du mois : ABLAVI | POKOU_VI | OSEI_TUTU | QUEEN — non cumulable.
    current_pack = Column(String(10), nullable=True)
    pack_until = Column(DateTime, nullable=True)
    defaults_count = Column(Integer, default=0, nullable=False)
    suspended_at = Column(DateTime, nullable=True)
    #: Maquette Coursiers 21 : le coursier suspendu demande un réexamen.
    review_requested_at = Column(DateTime, nullable=True)
    #: Disponible : il reçoit les courses, même en dehors du mode coursier
    #: (maquettes Coursiers 8 et 27). Le bouton marche/arrêt le coupe.
    available = Column(Boolean, default=False, nullable=False)
    #: L'écran « Bienvenue chez les coursiers » a été vu (Coursiers 17).
    welcomed_at = Column(DateTime, nullable=True)
    #: Parrainage (maquette Coursiers 15) : code à partager, et le parrain
    #: de ce coursier. La récompense part à la première course livrée du
    #: filleul, une seule fois.
    referral_code = Column(String(12), nullable=True, unique=True, index=True)
    referred_by_id = Column(Integer, ForeignKey("honam_couriers.id", ondelete="SET NULL"), nullable=True)
    referral_rewarded_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PharmacyCourier(Base):
    """« Vos coursiers » (maquette Officine 6) : les livreurs habituels
    qu'une officine rattache. Ils voient ses courses avant les autres."""
    __tablename__ = "honam_pharmacy_couriers"

    id = Column(Integer, primary_key=True, index=True)
    pharmacy_id = Column(Integer, ForeignKey("honam_pharmacies.id", ondelete="CASCADE"), nullable=False, index=True)
    courier_id = Column(Integer, ForeignKey("honam_couriers.id", ondelete="CASCADE"), nullable=False, index=True)
    added_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("pharmacy_id", "courier_id", name="uq_pharmacy_courier"),)


class HonamWaitlistEntry(Base):
    """Liste d'attente d'une ville pas encore desservie (maquette Coursiers
    16) : on prévient la personne à l'ouverture, rien d'autre."""
    __tablename__ = "honam_waitlist"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    country = Column(String(2), nullable=False, index=True)
    city = Column(String(80), nullable=False, index=True)
    #: COURIER | PATIENT
    role = Column(String(8), nullable=False, default="COURIER")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    notified_at = Column(DateTime, nullable=True)

    __table_args__ = (UniqueConstraint("user_id", "role", name="uq_waitlist_user_role"),)


class CourierLedgerEntry(Base):
    """Registre des courses, en ÉCRITURE SEULE (BM-07).

    Le solde de courses n'est stocké nulle part : il se recalcule en
    sommant `rides` sur la période du pack. Une erreur se corrige par une
    écriture inverse, jamais en modifiant une ligne.
    """
    __tablename__ = "honam_courier_ledger"

    id = Column(Integer, primary_key=True, index=True)
    courier_id = Column(Integer, ForeignKey("honam_couriers.id", ondelete="CASCADE"), nullable=False, index=True)
    #: TRIAL | PURCHASE | UPGRADE | RIDE | LAUNCH (course de la période de
    #: lancement, non décomptée) | DEFAULT (défaut de livraison, 0 course)
    #: | GIFT (parrainage) | EXPIRY
    kind = Column(String(10), nullable=False)
    #: + courses ajoutées, − course décomptée. Un pack illimité porte 9999.
    rides = Column(Integer, nullable=False)
    pack = Column(String(10), nullable=True)
    order_id = Column(Integer, ForeignKey("honam_orders.id", ondelete="SET NULL"), nullable=True)
    payment_id = Column(Integer, nullable=True)
    #: Fin de validité du pack auquel la ligne appartient.
    period_end = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class CourierDefault(Base):
    """Un défaut de livraison signalé par une officine (maquettes Coursiers
    20 et 21) : daté, motivé, et contestable pendant 48 heures."""
    __tablename__ = "honam_courier_defaults"

    id = Column(Integer, primary_key=True, index=True)
    courier_id = Column(Integer, ForeignKey("honam_couriers.id", ondelete="CASCADE"), nullable=False, index=True)
    order_id = Column(Integer, ForeignKey("honam_orders.id", ondelete="SET NULL"), nullable=True)
    pharmacy_id = Column(Integer, ForeignKey("honam_pharmacies.id", ondelete="SET NULL"), nullable=True)
    #: Ce qu'a écrit l'officine.
    reason = Column(String(255), nullable=False)
    #: CONFIRMED | CONTESTED | CANCELLED (contestation acceptée par le support)
    status = Column(String(10), default="CONFIRMED", nullable=False)
    contest_until = Column(DateTime, nullable=False)
    contested_at = Column(DateTime, nullable=True)
    contest_note = Column(String(500), nullable=True)
    acknowledged_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class CourierWalletCheck(Base):
    """Un numéro de wallet dont la personne a prouvé la possession par un
    code SMS, pendant l'inscription coursier (maquette Coursiers 5)."""
    __tablename__ = "honam_wallet_checks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    phone = Column(String(32), nullable=False)
    verified_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class CourierOfferDismissal(Base):
    """« Ne plus me proposer » l'offre coursier (maquette Coursiers 0)."""
    __tablename__ = "honam_courier_offer_dismissals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    dismissed_at = Column(DateTime, default=datetime.utcnow, nullable=False)
