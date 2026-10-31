"""Le transactional outbox : les évènements métier en attente de Kafka.

Un évènement s'écrit dans la MÊME transaction que la donnée qu'il décrit.
Publier directement vers Kafka depuis la route ferait courir deux risques
opposés : une cagnotte enregistrée dont l'évènement est perdu (Kafka
injoignable), ou un évènement publié pour une écriture annulée ensuite. Le
relais (`app/workers/outbox_relay.py`) lit cette table et publie, au moins
une fois, dans l'ordre d'insertion.
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String, Text

from app.core.database import Base


class OutboxEvent(Base):
    __tablename__ = "outbox_events"

    id = Column(Integer, primary_key=True, index=True)
    #: Nom logique, sans préfixe d'environnement (« kory.events »).
    topic = Column(String(120), nullable=False)
    #: Clé de partition : tous les évènements d'une même cagnotte vont dans
    #: la même partition, donc restent ordonnés pour les consommateurs.
    key = Column(String(120), nullable=True)
    #: Type d'évènement (« kory.entry.confirmed »), aussi dans `payload`.
    event_type = Column(String(80), nullable=False)
    payload = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    published_at = Column(DateTime, nullable=True, index=True)
    attempts = Column(Integer, nullable=False, default=0)
    last_error = Column(String(500), nullable=True)
