"""Messages directs, réactions et listes de diffusion."""
from datetime import datetime
import enum
import uuid

from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey, Text, Enum as SQLEnum, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class MessageType(str, enum.Enum):
    TEXT = "TEXT"
    AUDIO = "AUDIO"
    DOCUMENT = "DOCUMENT"
    VIDEO = "VIDEO"
    IMAGE = "IMAGE"
    # Contenus sans pièce jointe : leur charge utile vit dans
    # `DirectMessage.payload` / `GroupMessage.payload` (JSON), et le sondage
    # dans sa propre table via `poll_id`.
    LOCATION = "LOCATION"
    CONTACT = "CONTACT"
    POLL = "POLL"
    # Sticker : une image, mais PAS un IMAGE.
    #
    # La distinction n'est pas cosmétique. Un sticker s'affiche sans cadre ni
    # fond, ne s'ouvre pas en plein écran, ne se télécharge pas dans la
    # galerie, et ne compte pas dans les « photos » d'une conversation. Le
    # ranger avec les images obligerait chaque écran à redécouvrir ces
    # règles à partir d'un drapeau, au lieu de les lire dans le type.
    STICKER = "STICKER"
    # Appel terminé, déposé dans le fil de la conversation.
    #
    # Un appel n'était visible que dans le journal d'appels, écran séparé :
    # l'histoire d'une relation se lisait donc à deux endroits, et rien dans
    # la conversation ne rappelait qu'on s'était parlé mardi.
    #
    # La charge utile porte un INSTANTANÉ — durée, issue, nombre de
    # participants — et pas seulement l'identifiant de l'appel. Même
    # raisonnement que la fiche produit ci-dessous : la bulle doit rester
    # lisible sans seconde requête, et sans dépendre d'une ligne de
    # `call_logs` qui pourrait être purgée un jour.
    CALL = "CALL"
    # Fiche produit partagée depuis la marketplace : la charge utile porte
    # un INSTANTANÉ (nom, prix, photo) et non seulement l'identifiant du
    # produit — la bulle doit rester lisible même si le vendeur retire
    # ensuite l'article de son catalogue.
    PRODUCT = "PRODUCT"

    def __str__(self):
        return self.value


class MessageStatus(str, enum.Enum):
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    READ = "READ"

    def __str__(self):
        return self.value


class DirectMessage(Base):
    """Pokou — message personne-à-personne entre deux utilisateurs Pokou."""
    __tablename__ = "direct_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    recipient_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    message_type = Column(SQLEnum(MessageType, name="message_type"), default=MessageType.TEXT, nullable=False)
    content = Column(Text, nullable=True)  # texte, ou légende pour un média — NULL si chiffré

    # ── Chiffrement de bout en bout ───────────────────────────────────────
    # Quand `encryption` vaut « v1 », `content` est NULL et le texte vit
    # uniquement dans `ciphertext`, illisible du serveur. Les deux colonnes
    # coexistent plutôt que l'une remplaçant l'autre, pour une raison
    # pratique : une conversation dont un seul côté a mis à jour son
    # application doit continuer de fonctionner en clair. Le chiffrement se
    # négocie par conversation, pas par déploiement.
    encryption = Column(String(8), nullable=True)
    ciphertext = Column(Text, nullable=True)
    #: En-tête nécessaire au déchiffrement : numéro dans la chaîne, vecteur
    #: d'initialisation, et — pour le premier message d'une session — les
    #: clés publiques éphémères. Public par nature : il ne révèle rien du
    #: contenu, et le destinataire ne peut pas déchiffrer sans lui.
    envelope = Column(JSON, nullable=True)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    status = Column(SQLEnum(MessageStatus, name="message_status"), default=MessageStatus.SENT, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    delivered_at = Column(DateTime, nullable=True)
    read_at = Column(DateTime, nullable=True)
    # Message cité. SET NULL et non CASCADE : supprimer le message d'origine
    # ne doit pas emporter les réponses qu'il a suscitées — elles perdent
    # seulement leur citation.
    reply_to_id = Column(
        String(36), ForeignKey("direct_messages.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Renseigné à la première modification. `null` distingue « jamais
    # modifié » de « modifié », ce qu'un booléen dirait moins bien puisqu'on
    # affiche aussi QUAND.
    edited_at = Column(DateTime, nullable=True)
    # Éphémère : date de disparition, figée à l'envoi d'après le réglage de
    # la conversation. Figée et non recalculée, sinon changer le réglage
    # réécrirait le passé.
    expires_at = Column(DateTime, nullable=True, index=True)
    # Média à vue unique : consultable une fois, puis plus jamais.
    view_once = Column(Boolean, default=False, nullable=False)
    viewed_at = Column(DateTime, nullable=True)
    poll_id = Column(String(36), ForeignKey("polls.id", ondelete="CASCADE"), nullable=True)
    # Position partagée et carte de visite : charge utile JSON plutôt qu'un
    # jeu de colonnes par type. Le TYPE du message dit comment la lire, et
    # ajouter un type demain n'imposera pas une migration de plus.
    payload = Column(JSON, nullable=True)

    sender = relationship("User", foreign_keys=[sender_id])
    recipient = relationship("User", foreign_keys=[recipient_id])
    reply_to = relationship("DirectMessage", remote_side=[id], foreign_keys=[reply_to_id])
    poll = relationship("Poll")
    reactions = relationship("MessageReaction", cascade="all, delete-orphan", backref="message")
    media_asset = relationship("MediaAsset")


class MessageReaction(Base):
    """Réaction emoji sur un message direct. Une seule par (message,
    personne) — WhatsApp remplace la précédente au lieu de les cumuler, et
    c'est ce que la contrainte d'unicité impose ici."""
    __tablename__ = "message_reactions"

    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(
        String(36), ForeignKey("direct_messages.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    # Un emoji, pas un identifiant de réaction : le jeu n'est pas figé côté
    # serveur, le client propose ce qu'il veut.
    emoji = Column(String(16), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")

    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_message_reaction"),)


class BroadcastList(Base):
    """Pokou — liste de diffusion façon WhatsApp.

    À ne PAS confondre avec un groupe, dont elle est l'exact contraire :

    - un groupe est un LIEU. Tout le monde y voit tout le monde, les réponses
      s'y adressent à tous, et il a une existence propre pour ses membres.
    - une liste de diffusion est un CARNET DE COPIE. Elle n'existe que pour
      celui qui l'a faite. Chaque destinataire reçoit un message individuel,
      dans sa conversation habituelle, et ne sait pas qu'il y en a eu
      d'autres. Sa réponse revient en privé, à l'expéditeur seul.

    C'est la différence qui compte pour l'usage visé — annoncer un arrivage à
    quarante clients sans les mettre en relation les uns avec les autres, ni
    leur laisser croire qu'ils peuvent se répondre entre eux.

    D'où l'absence de table de messages propre : ce qui part est un vrai
    DirectMessage par destinataire (voir broadcasts.py). Ce qu'on conserve
    ici n'est que la composition, pour que l'expéditeur retrouve ce qu'il a
    envoyé et à qui.
    """
    __tablename__ = "broadcast_lists"

    id = Column(Integer, primary_key=True, index=True)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    members = relationship(
        "BroadcastListMember", cascade="all, delete-orphan", back_populates="broadcast_list"
    )


class BroadcastListMember(Base):
    """Un destinataire d'une liste.

    Pointe vers le COMPTE et non vers la fiche du carnet : une fiche peut
    être supprimée ou renommée sans que la liste doive être refaite, et c'est
    le compte qu'il faut pour écrire. Le nom affiché se relit du carnet au
    moment de l'affichage.
    """
    __tablename__ = "broadcast_list_members"
    __table_args__ = (
        UniqueConstraint("broadcast_list_id", "user_id", name="uq_broadcast_member"),
    )

    id = Column(Integer, primary_key=True, index=True)
    broadcast_list_id = Column(
        Integer, ForeignKey("broadcast_lists.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    broadcast_list = relationship("BroadcastList", back_populates="members")
    user = relationship("User")


class BroadcastMessage(Base):
    """Ce qui a été composé une fois et envoyé à toute une liste.

    Sert uniquement à l'expéditeur : c'est ce qui lui permet de revoir un
    envoi comme UN envoi, au lieu de le retrouver éparpillé dans quarante
    conversations. Les destinataires, eux, n'ont jamais connaissance de cette
    ligne — chez eux il n'y a qu'un message ordinaire.
    """
    __tablename__ = "broadcast_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    broadcast_list_id = Column(
        Integer, ForeignKey("broadcast_lists.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    message_type = Column(SQLEnum(MessageType, name="message_type"), default=MessageType.TEXT, nullable=False)
    content = Column(Text, nullable=True)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    #: Nombre de destinataires effectivement servis — figé à l'envoi.
    #: Recompter plus tard donnerait un autre chiffre (une liste se modifie),
    #: et ce serait alors une réécriture de l'histoire.
    recipient_count = Column(Integer, nullable=False, default=0)

    media_asset = relationship("MediaAsset")
