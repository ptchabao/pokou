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

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

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
    #: WEEKLY | MONTHLY | QUARTERLY (cotisation, KOR-17) ; WEEKLY |
    #: BIWEEKLY | MONTHLY (tontine, KOR-23).
    period = Column(String(10), nullable=True)
    due_at = Column(DateTime, nullable=True)
    #: Code de partage, pour rejoindre sans être membre du groupe.
    join_code = Column(String(12), nullable=False, unique=True, index=True)
    #: OPEN|CLOSED|PENDING (tontine) ; FROZEN : gelée par l'équipe le temps
    #: d'une vérification — consultable, plus rien n'y bouge.
    status = Column(String(8), nullable=False, default="OPEN", index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    closed_at = Column(DateTime, nullable=True)
    #: Dernière prolongation de la date de fin par le collecteur (KOR-15).
    extended_at = Column(DateTime, nullable=True)
    #: KOR-6 : pour qui l'on collecte (« Akossiwa K. »). Un nom, pas un
    #: compte : le bénéficiaire ne reçoit rien de Pokou.
    beneficiary_name = Column(String(120), nullable=True)
    #: KOR-6 / 17 : les montants de chacun sont-ils visibles de tous ? Sinon
    #: seuls l'auteur et celui qui confirme les voient ; les totaux restent.
    amounts_visible = Column(Boolean, nullable=False, default=True)
    #: KOR-18 : une cotisation de groupe limitée à certains membres. Les
    #: membres concernés sont alors les lignes `KoryMember`, et un nouveau
    #: venu du groupe ne cotise pas d'office.
    members_selected = Column(Boolean, nullable=False, default=False)
    #: KOR-18 : co-organisateur qui confirme aussi les réceptions d'une
    #: cotisation ; KOR-24 : suppléant de l'administrateur d'une tontine.
    deputy_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    #: KOR-17 / 22 : dernière échéance d'une cotisation (sans date : sans fin).
    ends_at = Column(DateTime, nullable=True)
    #: KOR-22 : l'échéance sautée par une pause (« 2027-03 »).
    paused_period = Column(String(12), nullable=True)
    #: KOR-22 : nouveau montant par membre, à partir de l'échéance indiquée ;
    #: les échéances passées gardent leur montant.
    next_amount = Column(Integer, nullable=True)
    next_amount_from = Column(String(12), nullable=True)
    #: KOR-24 / 26 : ordre des tours tiré au sort par Pokou (DRAW) ou fixé
    #: par l'administrateur (FIXED). Le tirage est scellé : son empreinte
    #: est publiée et il ne se rejoue pas.
    draw_mode = Column(String(8), nullable=True)
    draw_seal = Column(String(16), nullable=True)
    drawn_at = Column(DateTime, nullable=True)
    #: KOR-30 : dissolution d'une tontine, avec son motif.
    dissolved_at = Column(DateTime, nullable=True)
    dissolve_reason = Column(String(280), nullable=True)
    #: Dernière relance envoyée par l'organisateur (KOR-8 / 20) : une par
    #: tranche de 12 h, pour ne pas harceler.
    reminded_at = Column(DateTime, nullable=True)


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
    #: Tontine (KOR-25) : l'invité accepte ou refuse d'entrer. La tontine ne
    #: démarre que lorsque tous les membres ont accepté.
    accepted_at = Column(DateTime, nullable=True)
    declined_at = Column(DateTime, nullable=True)
    #: Kory Plus (KOR-8 / 25) : frais d'ouverture réglés par ce membre. Payer
    #: vaut acceptation : c'est la confirmation du paiement qui pose aussi
    #: `accepted_at`.
    fee_paid_at = Column(DateTime, nullable=True)
    fee_payment_id = Column(Integer, nullable=True)
    #: Tontine (KOR-24) : la place voulue par l'administrateur quand il fixe
    #: l'ordre lui-même.
    position = Column(Integer, nullable=True)


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


class KoryInvite(Base):
    """KOR-11 : une personne ajoutée par son numéro, qui n'est pas (encore)
    sur Pokou. Elle reçoit un SMS et reste « Invitée » jusqu'à son
    inscription ; elle devient alors membre (voir otp_service)."""
    __tablename__ = "kory_invites"

    id = Column(Integer, primary_key=True, index=True)
    pot_id = Column(Integer, ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False, index=True)
    phone = Column(String(32), nullable=False, index=True)
    display_name = Column(String(120), nullable=True)
    invited_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    joined_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)


class KorySwap(Base):
    """KOR-28 : un échange de mois entre deux membres d'une tontine.

    Le demandeur propose, l'autre membre accepte, puis l'administrateur (ou
    son suppléant) valide : alors seulement les deux tours échangent leur
    bénéficiaire. Rien ne s'efface : une demande refusée reste avec son
    statut.
    """
    __tablename__ = "kory_swaps"

    id = Column(Integer, primary_key=True, index=True)
    pot_id = Column(Integer, ForeignKey("kory_pots.id", ondelete="CASCADE"), nullable=False, index=True)
    requester_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    requester_round = Column(Integer, nullable=False)
    target_round = Column(Integer, nullable=False)
    message = Column(String(280), nullable=True)
    #: PENDING (attend l'autre membre) | ACCEPTED (attend l'administrateur)
    #: | DONE | REFUSED
    status = Column(String(10), nullable=False, default="PENDING", index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    decided_at = Column(DateTime, nullable=True)
