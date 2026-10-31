"""Kory — cagnottes et cotisations, tenues comme un JOURNAL.

Pokou n'encaisse, ne transfère, ne séquestre ni ne reverse aucun fonds
(cahier des charges, BM-01). L'argent va du wallet de chaque membre à celui
du collecteur, hors de l'application ; Kory ne garde que la trace de qui a
déclaré quoi, et de ce que le collecteur a confirmé avoir reçu.

C'est ce qui distingue Kory de l'ancienne cagnotte de cérémonie
(`CeremonyFund`), où l'argent arrivait sur le compte marchand de Pokou :
celle-là fait de Pokou un intermédiaire financier, celle-ci non.
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from app.core.database import Base


class KoryPot(Base):
    """Une cagnotte (somme ponctuelle) ou une cotisation (somme récurrente).

    Un seul collecteur : c'est lui qui reçoit l'argent sur son wallet, et lui
    seul peut confirmer une contribution. La tontine en rotation — un
    collecteur différent à chaque tour — est réservée à Kory Plus (BM-13) et
    n'est pas ouverte par ce modèle.
    """
    __tablename__ = "kory_pots"

    id = Column(Integer, primary_key=True, index=True)
    #: Le groupe de discussion d'où vient la cagnotte (NAV-03). Facultatif :
    #: une cagnotte peut aussi se partager par code.
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True, index=True)
    organizer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    collector_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(12), nullable=False, default="CAGNOTTE")  # CAGNOTTE|COTISATION
    title = Column(String(120), nullable=False)
    description = Column(String(500), nullable=True)
    #: Objectif indicatif de la cagnotte, en FCFA.
    goal_amount = Column(Integer, nullable=True)
    #: Montant attendu de chaque membre par période, pour une cotisation.
    amount_per_member = Column(Integer, nullable=True)
    period = Column(String(8), nullable=True)  # WEEKLY|MONTHLY
    due_at = Column(DateTime, nullable=True)
    #: Code de partage, pour rejoindre sans être membre du groupe.
    join_code = Column(String(12), nullable=False, unique=True, index=True)
    status = Column(String(8), nullable=False, default="OPEN", index=True)  # OPEN|CLOSED
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    closed_at = Column(DateTime, nullable=True)


class KoryMember(Base):
    """Une personne qui a rejoint une cagnotte par son code.

    Les membres d'un groupe rattaché n'ont pas besoin de ligne ici : leur
    appartenance au groupe suffit, et suit ses arrivées et départs.
    """
    __tablename__ = "kory_members"

    id = Column(Integer, primary_key=True, index=True)
    pot_id = Column(Integer, ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class KoryEntry(Base):
    """Une contribution déclarée par un membre.

    Jamais supprimée : une déclaration refusée reste au journal avec son
    statut. Le total confirmé se recalcule à partir de ces lignes, il n'est
    pas tenu à part.
    """
    __tablename__ = "kory_entries"

    id = Column(Integer, primary_key=True, index=True)
    pot_id = Column(Integer, ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False, index=True)
    contributor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    amount = Column(Integer, nullable=False)
    #: Référence de la transaction mobile money, telle que le SMS de
    #: l'opérateur la donne. Aide le collecteur à rapprocher ; jamais vérifiée
    #: par Pokou, qui n'a pas accès aux wallets.
    wallet_reference = Column(String(64), nullable=True)
    #: Période couverte pour une cotisation (« 2026-11 », « 2026-W45 »).
    period_label = Column(String(12), nullable=True)
    note = Column(String(280), nullable=True)
    status = Column(String(10), nullable=False, default="DECLARED", index=True)  # DECLARED|CONFIRMED|REJECTED
    declared_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)
