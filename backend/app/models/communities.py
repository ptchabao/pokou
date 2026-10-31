"""Communautés et chaînes."""
from datetime import datetime
import uuid

from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class Community(Base):
    """Pokou — communauté façon WhatsApp : un contenant qui regroupe
    plusieurs groupes autour d'un même ensemble de personnes (une école, un
    marché, une entreprise).

    Ce n'est PAS un groupe géant : une communauté n'a pas de conversation à
    elle. Elle a un groupe d'annonces, créé avec elle, où seuls ses
    administrateurs écrivent et où tous ses membres lisent — c'est ce qui la
    distingue d'un simple dossier de groupes."""
    __tablename__ = "communities"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    avatar_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    invite_code = Column(String(32), unique=True, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    creator = relationship("User", foreign_keys=[created_by])
    avatar_media = relationship("MediaAsset")
    members = relationship("CommunityMember", back_populates="community", cascade="all, delete-orphan")
    groups = relationship("Group", back_populates="community")


class CommunityMember(Base):
    """Appartenance à une communauté. Mêmes rôles qu'un groupe ('OWNER' |
    'ADMIN' | 'MEMBER') et même raisonnement : seul le créateur nomme les
    administrateurs, qui gèrent le reste."""
    __tablename__ = "community_members"

    id = Column(Integer, primary_key=True, index=True)
    community_id = Column(
        Integer, ForeignKey("communities.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(10), default="MEMBER", nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    community = relationship("Community", back_populates="members")
    user = relationship("User")


class Channel(Base):
    """Chaîne de mises à jour, suivie indépendamment des contacts.

    ── Une chaîne n'est pas un groupe ───────────────────────────────────

    Dans un groupe, tout le monde parle. Dans une chaîne, le propriétaire et
    ses administrateurs PUBLIENT, les abonnés lisent et réagissent — jamais
    de réponse écrite. C'est ce qui justifie une table de publications
    distincte de `group_messages` : pas de destinataire, pas d'accusé de
    réception, pas de fil de réponses.

    ── Publique ou privée ──────────────────────────────────────────────

    Jusqu'ici toutes l'étaient : n'importe qui pouvait trouver une chaîne
    par la recherche, lire son fil sans s'abonner, et s'y abonner seul. Ce
    qui convient à un journal d'annonces ne convient pas à une équipe, à une
    coopérative, ni à une liste de prix réservée à des grossistes.

    `is_private` ferme trois portes d'un coup, et il faut les trois : sans
    l'une, les deux autres ne servent à rien.

    - **la recherche et les suggestions** ne la proposent plus ;
    - **le fil ne se lit pas** sans être abonné ;
    - **on ne s'abonne pas seul** : il faut le lien privé.

    Le lien d'invitation existait déjà (`invite_code`) et ne servait qu'à
    raccourcir le chemin vers une chaîne qu'on aurait de toute façon pu
    trouver. Sur une chaîne privée, il devient la SEULE porte — d'où la
    possibilité de le révoquer, qui existait déjà elle aussi.
    """
    __tablename__ = "channels"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    avatar_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    #: Privée : introuvable, illisible et inaccessible sans le lien.
    #:
    #: Le défaut reste `False`. Les chaînes existantes ont été créées
    #: publiques, et une migration qui les rendrait privées ferait
    #: disparaître du jour au lendemain des fils que des gens suivaient.
    is_private = Column(Boolean, default=False, nullable=False)
    invite_code = Column(String(32), unique=True, nullable=True, index=True)
    is_verified = Column(Boolean, default=False, nullable=False)
    verified_at = Column(DateTime, nullable=True)
    # La certification est un ABONNEMENT, pas un acquis : elle expire.
    #
    # Une date plutôt qu'une tâche de fond qui repasserait éteindre les
    # badges — la comparaison se fait à la lecture, et un badge périmé
    # cesse de s'afficher tout seul même si rien ne tourne côté serveur.
    verified_until = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    creator = relationship("User", foreign_keys=[created_by])
    avatar_media = relationship("MediaAsset")
    members = relationship("ChannelMember", back_populates="channel", cascade="all, delete-orphan")
    posts = relationship(
        "ChannelPost",
        back_populates="channel",
        cascade="all, delete-orphan",
        order_by="ChannelPost.created_at.desc()",
    )


class ChannelMember(Base):
    """Abonnement à une chaîne. Le propriétaire est son premier membre."""
    __tablename__ = "channel_members"

    id = Column(Integer, primary_key=True, index=True)
    channel_id = Column(Integer, ForeignKey("channels.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(10), default="FOLLOWER", nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    channel = relationship("Channel", back_populates="members")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("channel_id", "user_id", name="uq_channel_member"),)


class ChannelPost(Base):
    """Publication d'une chaîne — le contenu même d'une chaîne, à sens
    unique : les admins publient, les abonnés lisent et réagissent (jamais
    de réponse écrite, c'est ce qui distingue une chaîne d'un groupe).

    Table à part de GroupMessage plutôt qu'un type de message de plus : pas
    de destinataire, pas d'accusé de réception, pas de fil de réponses — et
    une chaîne se lit AVANT de s'y abonner, ce qui n'a pas d'équivalent
    dans une conversation."""
    __tablename__ = "channel_posts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    channel_id = Column(Integer, ForeignKey("channels.id", ondelete="CASCADE"), nullable=False, index=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    text_content = Column(Text, nullable=True)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    # Sondage porté par la publication — MÊME table `polls` que les sondages
    # de conversation (voir Poll) : question, options, votes et la route de
    # vote sont déjà écrits et éprouvés là-bas. Un second système de sondage
    # propre aux chaînes dupliquerait la règle du choix unique et la
    # mécanique de remplacement de vote, c'est-à-dire les deux endroits où se
    # logent les bugs.
    poll_id = Column(String(36), ForeignKey("polls.id", ondelete="CASCADE"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    edited_at = Column(DateTime, nullable=True)

    channel = relationship("Channel", back_populates="posts")
    author = relationship("User")
    media_asset = relationship("MediaAsset")
    poll = relationship("Poll")
    reactions = relationship("ChannelPostReaction", cascade="all, delete-orphan", backref="post")
    views = relationship("ChannelPostView", cascade="all, delete-orphan", backref="post")


class ChannelPostReaction(Base):
    """Réaction emoji à une publication. Unicité (publication, personne) :
    une réaction par personne, remplacée et non empilée — comme sur les
    messages (voir MessageReaction)."""
    __tablename__ = "channel_post_reactions"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(String(36), ForeignKey("channel_posts.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    emoji = Column(String(16), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")

    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_channel_post_reaction"),)


class ChannelPostView(Base):
    """Vue d'une publication — même motif que StatusView : c'est le compteur
    de vues qu'affiche une chaîne, et l'unicité par personne évite qu'un
    aller-retour dans le fil le gonfle."""
    __tablename__ = "channel_post_views"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(String(36), ForeignKey("channel_posts.id", ondelete="CASCADE"), nullable=False, index=True)
    viewer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    viewed_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("post_id", "viewer_id", name="uq_channel_post_view"),)


class ChannelCertificationApplication(Base):
    """Demande de certification d'une chaîne, examinée par l'équipe Pokou.

    Payer ne certifie PAS : le paiement ouvre un dossier, l'équipe tranche.
    C'est la même règle que pour la vérification vendeur, et pour la même
    raison — un badge qui s'achète sans regard ne vaut rien, et c'est
    précisément parce qu'il désigne ce qui est fiable qu'il doit être refusé
    quand il le faut. Un refus est remboursable, l'écran le dit.
    """
    __tablename__ = "channel_certification_applications"

    id = Column(Integer, primary_key=True, index=True)
    channel_id = Column(Integer, ForeignKey("channels.id", ondelete="CASCADE"), nullable=False, index=True)
    requested_by = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #: MONTHLY | ANNUAL — la durée accordée à l'approbation en découle.
    plan = Column(String(16), nullable=False, default="MONTHLY")
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="CASCADE"), nullable=False, unique=True)
    status = Column(String(16), nullable=False, default="PENDING", index=True)  # PENDING | APPROVED | REJECTED
    reviewer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    review_note = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)

    channel = relationship("Channel")
    requester = relationship("User", foreign_keys=[requested_by])
