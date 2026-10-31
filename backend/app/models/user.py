"""Comptes utilisateurs et vocabulaire de confidentialité."""
from datetime import datetime
import enum

from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship

from app.core.database import Base


class UserRole(str, enum.Enum):
    USER = "USER"
    ADMIN = "ADMIN"
    SUPER_ADMIN = "SUPER_ADMIN"
    AI_OPERATOR = "AI_OPERATOR"
    SUPPORT = "SUPPORT"
    VIEWER = "VIEWER"

    def __str__(self):
        return self.value


class PrivacyAudience(str, enum.Enum):
    """Le vocabulaire unique de toutes les règles de confidentialité.

    Trois valeurs, et pas une de plus. La tentation d'en ajouter une
    quatrième — « mes contacts sauf… » — est réelle, et elle est déjà
    satisfaite là où elle a du sens : les statuts ont leur propre table
    d'exceptions (`status_privacy_entries`), parce qu'une liste d'exclusion
    ne se stocke pas dans une colonne.

    Le reste s'en passe. Personne ne veut « montrer ma photo de profil à
    tout le monde sauf trois personnes » : on la montre, ou on la réserve à
    ses contacts, ou on la cache.
    """

    EVERYONE = "EVERYONE"
    CONTACTS = "CONTACTS"
    NOBODY = "NOBODY"

    def __str__(self):
        return self.value


class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    # Nullable — a Pokou (mobile) account created via phone+OTP has no email
    # or password at all. Every user has at least one of email/phone; that
    # invariant is enforced in application code (auth.py / otp_service.py),
    # not at the DB level.
    email = Column(String(255), unique=True, index=True, nullable=True)
    phone = Column(String(32), unique=True, index=True, nullable=True)
    full_name = Column(String(255), nullable=True)
    about = Column(String(140), nullable=True)  # Pokou profile bio, WhatsApp-style
    # use_alter : media_assets.uploader_id pointe aussi vers users, et ce
    # cycle empêcherait de créer l'une ou l'autre table en premier.
    avatar_media_id = Column(
        Integer,
        ForeignKey("media_assets.id", use_alter=True, name="fk_users_avatar_media_id"),
        nullable=True,
    )
    is_active = Column(Boolean, default=True)
    role = Column(SQLEnum(UserRole, name="userrole"), default=UserRole.USER, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    # back_populates des deux côtés : sans lui, SQLAlchemy avertit que cette
    # relation et MarketplaceProduct.seller écrivent la MÊME colonne
    # (marketplace_products.seller_id) sans se connaître, ce qui peut faire
    # perdre silencieusement une des deux écritures.
    marketplace_products = relationship(
        "MarketplaceProduct",
        back_populates="seller",
        foreign_keys="MarketplaceProduct.seller_id",
        cascade="all, delete-orphan",
    )

    # ── Pokou : présence et confidentialité ───────────────────────────────────
    # Dernière activité observée (WebSocket ouvert, requête authentifiée).
    last_seen_at = Column(DateTime, nullable=True)
    # « Vu à » visible par mes contacts. Réciprocité façon WhatsApp : le
    # masquer m'empêche AUSSI de voir celui des autres — c'est appliqué à la
    # lecture, pas seulement documenté.
    presence_visible = Column(Boolean, default=True, nullable=False)
    # Accusés de lecture. Même réciprocité : les désactiver me prive de ceux
    # des autres.
    read_receipts_enabled = Column(Boolean, default=True, nullable=False)

    # ── Confidentialité : qui peut voir quoi ─────────────────────────────
    #
    # Un SEUL vocabulaire pour toutes les règles — « tout le monde », « mes
    # contacts », « personne » — plutôt qu'un booléen ici, une énumération
    # là et un champ texte ailleurs. Ce n'est pas une préférence de style :
    # c'est ce qui permet à `privacy_service.peut_voir()` d'exister, donc à
    # chaque route de poser la question de la même façon.
    #
    # Le DÉFAUT de chacune reproduit exactement le comportement actuel. Une
    # migration de confidentialité qui change ce que les gens partagent, sans
    # qu'ils l'aient demandé, est une faute — dans un sens comme dans
    # l'autre.
    #
    # `presence_visible` et `read_receipts_enabled` ci-dessus RESTENT : ils
    # portent une réciprocité (masquer le sien prive de celui des autres) que
    # ces règles-ci n'ont pas, et les fondre ensemble aurait imposé cette
    # réciprocité à des règles qui n'en veulent pas — personne n'attend que
    # cacher sa photo de profil cache aussi celles des autres.
    privacy_last_seen = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    privacy_online = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    privacy_profile_photo = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    privacy_profile_info = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    #: Qui peut voir que je suis membre de tel groupe.
    #:
    #: À ne pas confondre avec ce que voient les MEMBRES d'un groupe : ils
    #: continuent de se connaître entre eux quoi qu'il arrive, sinon un
    #: groupe cesse de fonctionner. Cette règle porte sur la visibilité
    #: PUBLIQUE de l'appartenance — « dans quels groupes est cette
    #: personne ? » posé de l'extérieur.
    privacy_group_membership = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    #: Qui peut m'INVITER dans un groupe. Autoriser n'est pas accepter :
    #: même quand l'invitation est permise, elle reste une invitation.
    privacy_group_invites = Column(
        SQLEnum(PrivacyAudience, name="privacy_audience"),
        default=PrivacyAudience.CONTACTS,
        nullable=False,
    )
    # Compte vendeur certifié par l'équipe (marketplace) — même motif que
    # Channel.is_verified : posé uniquement par un rôle d'équipe, jamais par
    # le vendeur lui-même (voir routes/marketplace.py::certify_seller).
    # ── Deux certifications, et il ne faut jamais les confondre ──────────
    #
    # `is_verified` : l'IDENTITÉ DU COMPTE est certifiée par Pokou. C'est le
    # ✓ qui s'affiche à côté du nom dans les conversations, les groupes, les
    # statuts, les chaînes — partout où quelqu'un est désigné. Il répond à
    # « est-ce bien cette personne ? ».
    #
    # `is_certified_seller` : le VENDEUR est vérifié sur le marché. Payé
    # 5 000 FCFA, avec pièce d'identité examinée par l'équipe. Il répond à
    # « puis-je lui acheter quelque chose ? », et n'a de sens que sur une
    # annonce ou une fiche vendeur.
    #
    # Les deux ont failli n'en faire qu'un. Le ✓ à côté d'un nom dans une
    # conversation aurait alors voulu dire « vendeur payant » — ce que
    # personne ne devine, puisqu'un ✓ à côté d'un nom se lit universellement
    # comme « c'est bien cette personne ». Une seule colonne aurait aussi
    # rendu le changement impossible plus tard sans retirer le badge à des
    # comptes qui l'avaient déjà.
    is_verified = Column(Boolean, default=False, nullable=False)
    verified_at = Column(DateTime, nullable=True)
    # Compte d'un bot Pokou Business (voir models/pokou_business.py::Bot) :
    # ni téléphone ni mot de passe, il ne se connecte jamais — il ne fait
    # que porter le nom et les conversations du bot.
    is_bot = Column(Boolean, default=False, nullable=False)
    is_certified_seller = Column(Boolean, default=False, nullable=False)
    certified_seller_at = Column(DateTime, nullable=True)
    certified_seller_until = Column(DateTime, nullable=True)

    # Vérification en deux étapes du COMPTE (distincte du verrou d'app, qui
    # ne protège que l'écran de cet appareil) : exigée en plus de l'OTP à la
    # reconnexion sur un nouvel appareil.
    two_step_pin_hash = Column(String(255), nullable=True)
    # ── Consentements (cahier des charges, section 8.1) ────────────────
    terms_accepted_at = Column(DateTime, nullable=True)
    terms_version = Column(String(16), nullable=True)
    age_confirmed_at = Column(DateTime, nullable=True)
    #: Deux choix DISTINCTS, non cochés par défaut, révocables.
    consent_analytics = Column(Boolean, default=False, nullable=False)
    consent_marketing = Column(Boolean, default=False, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    avatar_media = relationship("MediaAsset", foreign_keys=[avatar_media_id])
    tokens = relationship("Token", back_populates="user", cascade="all, delete-orphan")
