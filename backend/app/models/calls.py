"""Journal des appels audio/vidéo."""
from datetime import datetime
import uuid

from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey
from sqlalchemy.orm import relationship

from app.core.database import Base


class CallLog(Base):
    """Pokou — journal d'appels (Phase D+). Une ligne par tentative d'appel
    (1:1 ou de groupe), depuis la perspective de l'appelant. Le statut et
    ended_at sont mis à jour au fil des événements de signalisation
    (voir app/routes/calls.py) plutôt que suivis en direct depuis LiveKit —
    pas de webhook LiveKit configuré dans cette phase.

    `status` : ringing (en cours de sonnerie) -> ongoing (quelqu'un a
    décroché) -> ended, ou ringing -> missed/declined si personne ne
    décroche / que l'appel est refusé avant que quiconque réponde."""
    __tablename__ = "call_logs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    caller_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    room = Column(String(64), nullable=False, index=True)
    # Appel lancé depuis une conversation de groupe. Le salon reste éphémère
    # (un uuid par appel, cf. livekit_service.new_room_name) : c'est CETTE
    # colonne, pas le nom du salon, qui rattache l'appel au groupe. Un nom de
    # salon stable par groupe casserait la recherche `CallLog.room == room`
    # de calls.py (tous les appels du groupe partageraient la même ligne) et
    # ferait du nom une adresse partagée permanente.
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True, index=True)
    call_type = Column(String(10), nullable=False)  # "1:1" | "group"
    is_video = Column(Boolean, nullable=False, default=True)
    # Chiffré de bout en bout : chaque invité a reçu la clé du salon, scellée
    # pour lui (CallParticipant.sealed_key). Le serveur ne la voit jamais.
    e2ee = Column(Boolean, nullable=False, default=False)
    status = Column(String(12), nullable=False, default="ringing")  # ringing/ongoing/ended/missed/declined
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    ended_at = Column(DateTime, nullable=True)
    #: Le message déposé dans la conversation quand l'appel s'est terminé.
    #:
    #: Sa seule raison d'être est l'IDEMPOTENCE : un appel passe par
    #: plusieurs chemins pour atteindre son état final (refus de tous les
    #: invités, raccrochage, dernier participant qui quitte un appel de
    #: groupe), et sans cette marque le même appel déposerait deux bulles.
    #:
    #: Volontairement sans clé étrangère : la cible est un `DirectMessage`
    #: pour un appel à deux et un `GroupMessage` pour un appel de groupe.
    #: Une contrainte devrait choisir une table ; la marque, elle, n'a
    #: besoin que de répondre « déjà fait ».
    thread_message_id = Column(String(36), nullable=True)

    caller = relationship("User")
    group = relationship("Group")
    participants = relationship("CallParticipant", cascade="all, delete-orphan", backref="call_log")


class CallParticipant(Base):
    """Pokou — un invité d'un appel (CallLog) et sa réponse individuelle.
    Nécessaire pour les appels de groupe où chaque invité répond
    indépendamment ; pour un appel 1:1 il n'y en a qu'un seul."""
    __tablename__ = "call_participants"

    id = Column(Integer, primary_key=True, index=True)
    call_log_id = Column(String(36), ForeignKey("call_logs.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String(12), nullable=False, default="invited")  # invited/accepted/declined/missed
    responded_at = Column(DateTime, nullable=True)
    # Départ individuel, distinct de `status` (qui garde la RÉPONSE à
    # l'invitation, d'où se déduit la durée de l'appel). Dans un appel de
    # groupe, raccrocher ne termine que sa propre participation : l'appel
    # n'est clos que quand il ne reste plus personne (voir calls.py).
    left_at = Column(DateTime, nullable=True)
    # La clé de l'appel chiffrée de bout en bout POUR CET INVITÉ — même forme
    # qu'un message chiffré : {encryption, ciphertext, envelope}. Opaque pour
    # le serveur, qui ne fait que la rendre à l'invité quand il rejoint.
    sealed_key = Column(JSON, nullable=True)

    user = relationship("User")
