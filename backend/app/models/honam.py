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

from sqlalchemy import JSON, Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint

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
    delivery_latitude = Column(Float, nullable=True)
    delivery_longitude = Column(Float, nullable=True)
    #: Le coursier doit rapporter l'ordonnance ORIGINALE à l'officine
    #: (médicaments soumis à prescription stricte).
    original_required = Column(Boolean, default=False, nullable=False)
    original_collected_at = Column(DateTime, nullable=True)
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
    #: Produit manquant, signalé PENDANT LA PRÉPARATION, avant tout appel de
    #: coursier : la patiente choisit de recevoir le reste (KEEP) ou de tout
    #: annuler (CANCEL). Tant qu'elle n'a pas choisi, la commande n'avance pas.
    missing_amount = Column(Integer, nullable=True)
    missing_reason = Column(String(255), nullable=True)
    missing_choice = Column(String(8), nullable=True)
    #: Ce que l'officine doit rembourser, au seul numéro qui a payé, sous
    #: 2 heures à compter du choix (maquette « A2. Rembourser Afi »).
    refund_due = Column(Integer, default=0, nullable=False)
    refund_requested_at = Column(DateTime, nullable=True)
    refund_reason = Column(String(255), nullable=True)
    refund_confirmed_at = Column(DateTime, nullable=True)
    #: Le coursier confirme avoir reçu le prix de la course de l'officine.
    courier_paid_at = Column(DateTime, nullable=True)
    #: Le patient a signalé avoir payé ; l'officine confirme (PAID) ou
    #: répond « paiement non reçu ».
    patient_paid_declared_at = Column(DateTime, nullable=True)
    payment_not_received_at = Column(DateTime, nullable=True)
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
    #: Ville desservie où le coursier livre (configuration `honam_cities`).
    city = Column(String(80), nullable=True)
    wallet_phone = Column(String(32), nullable=True)
    rules_accepted_at = Column(DateTime, nullable=True)
    validated_at = Column(DateTime, nullable=True)
    trial_ends_at = Column(DateTime, nullable=True)
    membership_until = Column(DateTime, nullable=True)
    #: Le pack du mois : ABLAVI | POKOU_VI | OSEI_TUTU | QUEEN — non cumulable.
    current_pack = Column(String(10), nullable=True)
    pack_until = Column(DateTime, nullable=True)
    defaults_count = Column(Integer, default=0, nullable=False)
    suspended_at = Column(DateTime, nullable=True)
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
