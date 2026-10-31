"""Pokou Business — entreprises, bots, clés, consommation, factures.

Un bot est un compte Pokou (`User.is_bot`) rattaché à une ENTREPRISE, qui
l'administre depuis le portail Pokou Business et lui fait envoyer des
messages par l'API, facturés au message (voir services/pokou_business/).

Tout ce qui touche à l'argent est en FCFA entiers (XOF n'a pas de
centimes) : un solde en `Float` finit toujours par perdre un franc, et le
module SMS l'a montré — un tarif de 0,08 arrondi à l'entier débitait 0.
"""
from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class BusinessOrganization(Base):
    """L'entreprise cliente de Pokou Business.

    `status` dit ce que ses bots ont le droit de faire :

    - SANDBOX : inscription faite, rien de vérifié — les bots n'écrivent
      qu'aux numéros de test de l'entreprise ;
    - PENDING_REVIEW : dossier déposé, en attente de l'équipe ;
    - VERIFIED : production ouverte, bots marqués ✓ ;
    - REJECTED : dossier refusé (motif écrit), retour possible au dépôt ;
    - SUSPENDED : facture impayée ou abus — plus aucun envoi.
    """

    __tablename__ = "business_organizations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    legal_name = Column(String(200), nullable=True)
    country = Column(String(2), nullable=False, default="TG")
    rccm = Column(String(64), nullable=True)
    nif = Column(String(64), nullable=True)
    address = Column(String(255), nullable=True)
    billing_email = Column(String(255), nullable=True)
    phone = Column(String(32), nullable=True)

    status = Column(String(16), nullable=False, default="SANDBOX", index=True)
    rccm_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    identity_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    review_note = Column(String(500), nullable=True)
    reviewer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    submitted_at = Column(DateTime, nullable=True)
    verified_at = Column(DateTime, nullable=True)
    suspended_reason = Column(String(255), nullable=True)

    # PREPAID : le solde est débité à chaque message, envoi refusé à zéro.
    # POSTPAID : ouvert par l'équipe seulement — la consommation s'accumule
    # jusqu'à `postpaid_limit`, facturée en fin de mois.
    billing_mode = Column(String(16), nullable=False, default="PREPAID")
    credit_balance = Column(Integer, nullable=False, default=0)
    postpaid_limit = Column(Integer, nullable=False, default=0)
    payment_terms_days = Column(Integer, nullable=False, default=15)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    members = relationship("BusinessMember", back_populates="organization", cascade="all, delete-orphan")
    bots = relationship("Bot", back_populates="organization")


class BusinessMember(Base):
    """Qui agit pour l'entreprise. OWNER gère tout, y compris les membres ;
    DEVELOPER les bots, clés et webhooks ; BILLING les paiements et
    factures. Un rôle par personne et par entreprise."""

    __tablename__ = "business_organization_members"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(16), nullable=False, default="DEVELOPER")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    organization = relationship("BusinessOrganization", back_populates="members")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("organization_id", "user_id", name="uq_business_member"),)


class Bot(Base):
    """Un bot, et le compte Pokou qui parle en son nom.

    `user_id` est un `User` à `is_bot = True`, sans téléphone ni mot de
    passe : il ne peut pas se connecter, il ne fait que porter le nom,
    l'avatar et les conversations du bot — si bien que toute la messagerie
    (temps réel, push, liste des discussions) le traite sans cas particulier.
    """

    __tablename__ = "business_bots"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    handle = Column(String(32), nullable=False, unique=True, index=True)
    name = Column(String(80), nullable=False)
    description = Column(String(500), nullable=True)
    webhook_url = Column(String(500), nullable=True)
    webhook_secret = Column(String(64), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    organization = relationship("BusinessOrganization", back_populates="bots")
    user = relationship("User")


class BotApiKey(Base):
    """Clé d'API d'un bot. TEST n'écrit qu'aux numéros de test, et ne
    facture rien ; LIVE écrit en production et facture.

    Seule l'empreinte SHA-256 est gardée. Pas de bcrypt : la clé porte 256
    bits d'aléa, rien à deviner par force brute, et l'empreinte est vérifiée
    à CHAQUE envoi — bcrypt y ajouterait 100 ms.
    """

    __tablename__ = "business_api_keys"

    id = Column(Integer, primary_key=True, index=True)
    bot_id = Column(Integer, ForeignKey("business_bots.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(80), nullable=False)
    mode = Column(String(8), nullable=False, default="TEST")
    prefix = Column(String(24), nullable=False, index=True)
    key_hash = Column(String(64), nullable=False, unique=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_used_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)

    bot = relationship("Bot")


class BusinessTestNumber(Base):
    """Un numéro auquel les bots de l'entreprise peuvent écrire avant la
    vérification — ceux de l'équipe qui développe."""

    __tablename__ = "business_test_numbers"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    phone = Column(String(32), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("organization_id", "phone", name="uq_business_test_number"),)


class LedgerEntry(Base):
    """Un mouvement du solde prépayé. Le solde de l'entreprise est la somme
    de ses lignes ; `balance_after` permet de le vérifier ligne par ligne.

    RECHARGE (+), DEBIT (−), REFUND (+), ADJUSTMENT (±, par l'équipe).
    """

    __tablename__ = "business_ledger"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(16), nullable=False)
    amount = Column(Integer, nullable=False)
    balance_after = Column(Integer, nullable=False)
    reference = Column(String(120), nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class BotUsage(Base):
    """Un message envoyé par un bot, et ce qu'il coûte.

    `category` suit la fenêtre de 24 h : SERVICE quand le destinataire a
    écrit au bot dans les 24 dernières heures, INITIATED sinon. `invoice_id`
    rattache la ligne à la facture mensuelle d'une entreprise en postpayé.
    """

    __tablename__ = "business_usage"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False)
    bot_id = Column(Integer, ForeignKey("business_bots.id", ondelete="CASCADE"), nullable=False, index=True)
    message_id = Column(String(36), nullable=True)
    recipient_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    mode = Column(String(8), nullable=False, default="LIVE")
    category = Column(String(16), nullable=False)
    unit_price = Column(Integer, nullable=False)
    billing_mode = Column(String(16), nullable=False)
    invoice_id = Column(Integer, ForeignKey("business_invoices.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (Index("ix_business_usage_org_created", "organization_id", "created_at"),)


class Invoice(Base):
    """Une facture : une RECHARGE prépayée (payée d'avance), ou le relevé
    MONTHLY d'une entreprise en postpayé (à régler avant `due_at`).

    Le numéro est continu par année (VB-2026-000042) : une facture ne se
    renumérote jamais, et une facture annulée garde le sien (VOID)."""

    __tablename__ = "business_invoices"

    id = Column(Integer, primary_key=True, index=True)
    organization_id = Column(Integer, ForeignKey("business_organizations.id", ondelete="CASCADE"), nullable=False, index=True)
    number = Column(String(24), nullable=False, unique=True)
    kind = Column(String(16), nullable=False)
    status = Column(String(16), nullable=False, default="ISSUED", index=True)
    period_start = Column(DateTime, nullable=True)
    period_end = Column(DateTime, nullable=True)
    lines = Column(JSON, nullable=False, default=list)
    subtotal = Column(Integer, nullable=False, default=0)
    tax_rate_bp = Column(Integer, nullable=False, default=0)
    tax_amount = Column(Integer, nullable=False, default=0)
    total = Column(Integer, nullable=False, default=0)
    issued_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    due_at = Column(DateTime, nullable=True)
    paid_at = Column(DateTime, nullable=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id"), nullable=True)
    reminder_sent_at = Column(DateTime, nullable=True)


class WebhookDelivery(Base):
    """Un événement à remettre au serveur du développeur, et son sort.

    Une ligne PAR événement, relancée avec un délai croissant jusqu'à
    `MAX_ATTEMPTS` : un serveur qui redémarre ne doit pas faire perdre les
    messages reçus pendant ce temps."""

    __tablename__ = "business_webhook_deliveries"

    id = Column(Integer, primary_key=True, index=True)
    bot_id = Column(Integer, ForeignKey("business_bots.id", ondelete="CASCADE"), nullable=False, index=True)
    event_id = Column(String(36), nullable=False, unique=True)
    event_type = Column(String(40), nullable=False)
    payload = Column(JSON, nullable=False)
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    attempts = Column(Integer, nullable=False, default=0)
    next_attempt_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    last_status_code = Column(Integer, nullable=True)
    last_error = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    delivered_at = Column(DateTime, nullable=True)
