"""Centre de notifications (NOT-1) : ce que les SERVICES ont à dire.

Kory, Honam, Assimé, Pokou certifié, les invitations de groupe. Jamais le
contenu d'un message : les discussions restent dans Discussions, et elles
sont chiffrées de bout en bout — le serveur n'a rien à en afficher ici.
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class ServiceNotification(Base):
    __tablename__ = "service_notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #: Le service, pour l'icône et le libellé : kory|honam|assime|certified|groups.
    service = Column(String(16), nullable=False)
    title = Column(String(120), nullable=False)
    body = Column(String(280), nullable=False)
    #: Où mène un toucher : « kory/12 », « honam/order/34 »… lu par l'app.
    route = Column(String(120), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    read_at = Column(DateTime, nullable=True)
