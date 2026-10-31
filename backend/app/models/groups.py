"""Groupes, invitations, sondages et messages de groupe."""
from datetime import datetime
import enum
import uuid

from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey, Text, Enum as SQLEnum, UniqueConstraint, Index, text
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.messaging import MessageType


class Group(Base):
    """Pokou — conversation de groupe. Construite EN PARALLÈLE de
    DirectMessage plutôt qu'en généralisant celui-ci : les deux ont des
    modèles d'autorisation différents (paire de contacts vs appartenance),
    une diffusion différente (un destinataire vs N) et des sémantiques
    d'accusé de lecture différentes (voir GroupMessage). Fusionner les deux
    en une table polymorphe imposerait `recipient_id`/`group_id` nullables +
    une contrainte de cohérence, et un branchement dans chaque requête."""
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    avatar_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    # Lien d'invitation. Nullable : un groupe n'en a que si un admin en a
    # demandé un, et le régénérer invalide l'ancien lien — c'est le seul
    # moyen de révoquer un lien déjà diffusé.
    invite_code = Column(String(32), unique=True, nullable=True, index=True)
    # Rattachement à une communauté. Nullable : la grande majorité des
    # groupes n'appartient à aucune.
    community_id = Column(
        Integer, ForeignKey("communities.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Groupe d'annonces de sa communauté : tous les membres y sont, seuls les
    # administrateurs y écrivent. Un drapeau plutôt qu'une table à part — il
    # ne change qu'une règle d'autorisation à l'envoi.
    is_announcement = Column(Boolean, default=False, nullable=False)
    # Messages éphémères — décidé pour TOUT le groupe par ses admins, à la
    # différence de l'archivage qui est personnel.
    disappearing_seconds = Column(Integer, nullable=True)
    # Réservé aux admins pour écrire (hors annonces, qui l'imposent déjà).
    admins_only_messages = Column(Boolean, default=False, nullable=False)
    # Mode preuve (Pokou certifié) : un message supprimé reste visible,
    # barré, pour TOUS les membres, et plus rien ne se modifie. Activé par un
    # administrateur certifié ou en essai.
    proof_mode = Column(Boolean, default=False, nullable=False)
    proof_mode_since = Column(DateTime, nullable=True)
    proof_mode_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    creator = relationship("User", foreign_keys=[created_by])
    avatar_media = relationship("MediaAsset")
    community = relationship("Community", back_populates="groups")
    members = relationship("GroupMember", back_populates="group", cascade="all, delete-orphan")


class GroupInvitationStatus(str, enum.Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"

    def __str__(self):
        return self.value


class GroupInvitation(Base):
    """Une invitation à rejoindre un groupe — pas encore une appartenance.

    ── Ce que ça change ─────────────────────────────────────────────────

    Ajouter quelqu'un à un groupe le rendait membre SUR-LE-CHAMP. On se
    retrouvait dans une conversation sans l'avoir demandé, avec ses
    notifications et son historique, et la seule sortie était de partir —
    c'est-à-dire d'annoncer publiquement qu'on était parti.

    Une invitation renverse ça : l'organisateur propose, la personne décide.

    ── Pourquoi une table, et pas un drapeau sur `GroupMember` ──────────

    Un membre « en attente » aurait été un membre pour toutes les requêtes
    qui comptent, listent ou diffusent — et chacune aurait dû se souvenir de
    l'exclure. La première oubliée aurait envoyé les messages du groupe à
    quelqu'un qui n'a rien accepté.

    Une table distincte rend l'oubli impossible : tant que l'invitation n'est
    pas acceptée, il n'y a AUCUNE ligne dans `group_members`.

    ── L'expiration se calcule, elle ne se balaie pas ───────────────────

    `expires_at` est lu à chaque consultation, et `PENDING` dont la date est
    passée se lit comme `EXPIRED` (voir group_invitation_service). Aucune
    tâche de fond : un balayage périodique aurait introduit une fenêtre
    pendant laquelle une invitation périmée reste acceptable, et un
    ordonnanceur de plus à surveiller — alors que la question « est-elle
    encore valable ? » a une réponse exacte à tout instant.

    Le statut est tout de même ÉCRIT lors d'une consultation, pour que la
    base reflète ce que l'utilisateur a vu et que l'historique reste lisible.
    """

    __tablename__ = "group_invitations"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id = Column(
        Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False, index=True
    )
    #: L'invité.
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    #: Qui a invité. Affiché à l'invité : « Kodjo vous invite » se décide
    #: autrement que « quelqu'un vous invite ».
    invited_by_id = Column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    status = Column(
        SQLEnum(GroupInvitationStatus, name="group_invitation_status"),
        default=GroupInvitationStatus.PENDING,
        nullable=False,
        index=True,
    )
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    #: Quand l'invité a tranché. Nul tant qu'il n'a rien fait, et laissé tel
    #: quel à l'expiration : « il n'a pas répondu » et « il a refusé » ne se
    #: confondent pas.
    responded_at = Column(DateTime, nullable=True)

    __table_args__ = (
        # UNE invitation en cours par personne et par groupe.
        #
        # Partielle et non globale : après un refus ou une expiration, une
        # nouvelle invitation doit pouvoir être créée — c'est explicitement
        # demandé, et une contrainte sur (group_id, user_id) seul l'aurait
        # interdit pour toujours.
        #
        # SQLite et PostgreSQL acceptent tous deux l'index partiel.
        Index(
            "ix_group_invitations_pending_unique",
            "group_id",
            "user_id",
            unique=True,
            sqlite_where=text("status = 'PENDING'"),
            postgresql_where=text("status = 'PENDING'"),
        ),
    )

    group = relationship("Group")
    user = relationship("User", foreign_keys=[user_id])
    invited_by = relationship("User", foreign_keys=[invited_by_id])


class GroupMember(Base):
    """Appartenance à un groupe. `role` reste une chaîne simple ('OWNER' |
    'ADMIN' | 'MEMBER') : le créateur est OWNER et ne peut pas être
    rétrogradé (sinon un groupe pourrait se retrouver sans personne pour le
    gérer) ; un ADMIN peut renommer le groupe, changer sa photo, gérer le
    lien d'invitation et retirer des membres ; seul l'OWNER nomme les
    admins."""
    __tablename__ = "group_members"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(10), default="MEMBER", nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    # Mêmes réglages de conversation que pour un contact (voir Contact) :
    # archiver, épingler et mettre en sourdine sont des choix PERSONNELS,
    # donc ils vivent sur l'appartenance, pas sur le groupe.
    is_archived = Column(Boolean, default=False, nullable=False)
    is_pinned = Column(Boolean, default=False, nullable=False)
    pinned_at = Column(DateTime, nullable=True)
    muted_until = Column(DateTime, nullable=True)

    group = relationship("Group", back_populates="members")
    user = relationship("User")

    __table_args__ = (UniqueConstraint("group_id", "user_id", name="uq_group_member"),)


class Poll(Base):
    """Pokou — sondage attaché à un message (direct ou de groupe).

    Table à part plutôt que des colonnes sur le message : un sondage a des
    options et des votes, donc ses propres lignes de toute façon. Le message
    le référence, ce qui permet de le citer, d'y réagir et de le supprimer
    comme n'importe quel autre message."""
    __tablename__ = "polls"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    question = Column(String(500), nullable=False)
    # Autoriser plusieurs réponses par personne.
    allows_multiple = Column(Boolean, default=False, nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    creator = relationship("User")
    options = relationship("PollOption", cascade="all, delete-orphan", backref="poll", order_by="PollOption.position")


class PollOption(Base):
    __tablename__ = "poll_options"

    id = Column(Integer, primary_key=True, index=True)
    poll_id = Column(String(36), ForeignKey("polls.id", ondelete="CASCADE"), nullable=False, index=True)
    text = Column(String(200), nullable=False)
    # Ordre d'affichage voulu par l'auteur — sans lui, les options
    # remonteraient dans l'ordre arbitraire de la base.
    position = Column(Integer, default=0, nullable=False)

    votes = relationship("PollVote", cascade="all, delete-orphan", backref="option")


class PollVote(Base):
    """Un vote = (option, votant). L'unicité porte sur ce couple et non sur
    (sondage, votant) : c'est ce qui permet le choix multiple, la limite à une
    seule réponse étant appliquée par la route quand `allows_multiple` est
    faux."""
    __tablename__ = "poll_votes"

    id = Column(Integer, primary_key=True, index=True)
    option_id = Column(Integer, ForeignKey("poll_options.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")

    __table_args__ = (UniqueConstraint("option_id", "user_id", name="uq_poll_vote"),)


class GroupMessageReaction(Base):
    """Pendant de MessageReaction pour un message de groupe — table séparée
    comme DirectMessage et GroupMessage le sont, plutôt qu'une table
    polymorphe avec deux clés étrangères nullables et une contrainte de
    cohérence."""
    __tablename__ = "group_message_reactions"

    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(
        String(36), ForeignKey("group_messages.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    emoji = Column(String(16), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")

    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_group_message_reaction"),)


class GroupMessageMention(Base):
    """Personne citée par @ dans un message de groupe.

    Une table et non une liste dans le texte : c'est ce qui permet de
    notifier précisément les personnes mentionnées même quand le groupe est
    par ailleurs silencieux, et de retrouver « les messages qui me
    mentionnent »."""
    __tablename__ = "group_message_mentions"

    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(
        String(36), ForeignKey("group_messages.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    user = relationship("User")

    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_group_message_mention"),)


class GroupMessage(Base):
    """Message de groupe — même forme que DirectMessage, moins `status` /
    `delivered_at` / `read_at`. Absence volontaire : un accusé par membre
    (« vu par X, Y ») demande une table (message_id, member_id) avec une
    ligne par membre et par message, une agrégation à chaque bulle affichée
    et une rafale d'événements WS vers l'expéditeur au fil des lectures.
    C'est une fonctionnalité à part entière (« accusés de lecture de
    groupe »), pas un prérequis de « créer un groupe et y discuter » — donc
    hors périmètre ici. L'ajouter plus tard reste purement additif : aucune
    colonne de statut existante avec laquelle entrer en conflit."""
    __tablename__ = "group_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    message_type = Column(SQLEnum(MessageType, name="message_type"), default=MessageType.TEXT, nullable=False)
    content = Column(Text, nullable=True)  # texte, ou légende pour un média
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    # Voir DirectMessage : SET NULL pour ne pas emporter les réponses avec le
    # message cité, et `edited_at` nul quand jamais modifié.
    reply_to_id = Column(
        String(36), ForeignKey("group_messages.id", ondelete="SET NULL"), nullable=True, index=True
    )
    edited_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True, index=True)
    # Renseignés seulement en mode preuve : hors mode preuve, une
    # suppression efface la ligne.
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    # La version d'origine d'un message modifié EN MODE PREUVE : elle reste
    # visible de tous, avec l'heure de la modification (maquette 14).
    original_content = Column(Text, nullable=True)
    poll_id = Column(String(36), ForeignKey("polls.id", ondelete="CASCADE"), nullable=True)
    payload = Column(JSON, nullable=True)

    group = relationship("Group")
    sender = relationship("User", foreign_keys=[sender_id])
    media_asset = relationship("MediaAsset")
    reply_to = relationship("GroupMessage", remote_side=[id], foreign_keys=[reply_to_id])
    poll = relationship("Poll")
    reactions = relationship("GroupMessageReaction", cascade="all, delete-orphan", backref="message")
    mentions = relationship("GroupMessageMention", cascade="all, delete-orphan", backref="message")
