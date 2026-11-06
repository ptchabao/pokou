"""Baba — l'assistant IA de Pokou, servi par l'API Pokou elle-même."""
import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.core.database import Base


class BabaMessage(Base):
    """Un message du fil entre un utilisateur et Baba.

    Ce fil est le SEUL contexte envoyé au modèle de langage : Baba ne lit pas
    les autres discussions (cahier v3.4, INS-4)."""

    __tablename__ = "baba_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    #: « in » : écrit par l'utilisateur ; « out » : répondu par Baba.
    direction = Column(String(3), nullable=False)
    body = Column(Text, nullable=False)
    #: Le fournisseur qui a répondu (gemini, groq…) ou « faq ».
    provider = Column(String(32), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
