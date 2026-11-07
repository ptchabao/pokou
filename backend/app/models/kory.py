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
    bénéficiaire différent à chaque tour — est réservée à Kory Plus (BM-13) :
    ses tours sont dans `KoryRound`, et `collector_id` y désigne le
    bénéficiaire du tour en cours.
    """
    __tablename__ = "kory_pots"

    id = Column(Integer, primary_key=True, index=True)
    #: Le groupe de discussion d'où vient la cagnotte (NAV-03). Facultatif :
    #: une cagnotte peut aussi se partager par code.
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True, index=True)
    organizer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    collector_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(12), nullable=False, default="CAGNOTTE")  # CAGNOTTE|COTISATION|TONTINE
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
    #: Dernière prolongation de la date de fin par le collecteur (KOR-15).
    extended_at = Column(DateTime, nullable=True)


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
    #: Engagement (KOR-12 à 14) : un montant de départ, plus éventuellement
    #: un montant par jour jusqu'à la date de fin. Modifiable 8 h après
    #: `pledged_at` (compté par le serveur), ferme ensuite ; seul le
    #: collecteur peut alors l'annuler (`pledge_cancelled_at`).
    pledge_base = Column(Integer, nullable=True)
    pledge_daily = Column(Integer, nullable=True)
    pledged_at = Column(DateTime, nullable=True)
    pledge_cancelled_at = Column(DateTime, nullable=True)


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
    #: Tontine (Kory Plus) : le tour auquel la contribution appartient. Elle
    #: est confirmée par le bénéficiaire de CE tour, pas par l'organisateur.
    round_number = Column(Integer, nullable=True, index=True)
    note = Column(String(280), nullable=True)
    status = Column(String(10), nullable=False, default="DECLARED", index=True)  # DECLARED|CONFIRMED|REJECTED
    declared_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)
    #: Pourquoi le collecteur n'a pas constaté l'envoi (KOR-5).
    review_reason = Column(String(280), nullable=True)
    #: Capture du SMS de l'opérateur ajoutée par le contributeur (KOR-5).
    proof_media_id = Column(Integer, nullable=True)


class KoryRound(Base):
    """Un tour de tontine (Kory Plus, BM-13, maquettes Kory 7 et 8).

    Chaque tour a son bénéficiaire, qui reçoit sur SON wallet les mises de
    tous les autres et confirme seul ce qu'il a reçu. L'ordre est fixé à
    l'ouverture et ne change plus : c'est la promesse faite à ceux qui
    reçoivent en dernier. Pokou ne touche toujours pas l'argent (BM-01).
    """
    __tablename__ = "kory_rounds"

    id = Column(Integer, primary_key=True, index=True)
    pot_id = Column(Integer, ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False, index=True)
    number = Column(Integer, nullable=False)
    beneficiary_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    due_at = Column(DateTime, nullable=True)
    #: UPCOMING | CURRENT | DONE
    status = Column(String(10), nullable=False, default="UPCOMING")
    closed_at = Column(DateTime, nullable=True)
