"""Re-livraison d'un message que le destinataire n'a pas pu déchiffrer.

Le chiffrement de bout en bout a une faiblesse connue : une clé de message
ne sert qu'une fois. Une réinstallation, un cache effacé, deux traitements
concurrents — et le destinataire se retrouve avec un chiffré qu'il ne peut
plus ouvrir. Signal et WhatsApp y répondent par un « reçu de nouvel essai » :
le destinataire le demande, l'expéditeur — qui a toujours le clair de ce
qu'il a envoyé — le rescelle POUR LUI SEUL, par leur session à deux.

Le serveur ne voit que du chiffré, dans les deux sens.
"""
import uuid
from datetime import datetime

from sqlalchemy import JSON, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint

from app.core.database import Base


class E2EERetry(Base):
    __tablename__ = "e2ee_retries"
    __table_args__ = (
        UniqueConstraint("kind", "message_id", "requester_id", name="uq_e2ee_retry"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    #: « direct » ou « group ».
    kind = Column(String(8), nullable=False)
    message_id = Column(String(64), nullable=False, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=True)
    requester_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #: PENDING (en attente de l'expéditeur), DELIVERED (rescellé), DONE
    #: (ouvert par le destinataire), UNAVAILABLE (l'expéditeur n'a plus le clair).
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    encryption = Column(String(16), nullable=True)
    ciphertext = Column(Text, nullable=True)
    envelope = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
